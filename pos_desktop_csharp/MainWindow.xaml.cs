using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.Globalization;
using System.Linq;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Controls.Primitives;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Media.Effects;
using System.Windows.Threading;
using DilkashPos.Data;
using DilkashPos.Models;
using DilkashPos.Services;
using DilkashPos.Utils;
using DilkashPos.ViewModels;
using DilkashPos.Views;

namespace DilkashPos
{
    public partial class MainWindow : Window
    {
        private readonly LocalDatabase _db;
        private readonly ApiService _api;
        private readonly EscPosPrinterService _printer;
        private readonly SyncEngine _syncEngine;
        private readonly DispatcherTimer _clockTimer;

        // Xotiradagi asosiy ma'lumotlar
        private List<Department> _departments = new();
        private List<Category> _categories = new();
        private List<Product> _products = new();
        private List<RestaurantTable> _tables = new();
        private PosSettings _settings = new();
        private List<Order> _onlineOrders = new();
        private ShiftReport _currentShift = new();

        // Savatcha va Tanlangan elementlar
        private Order _currentCart = new() { ServiceType = "pickup" };
        private Category? _selectedCategory;
        private RestaurantTable? _activeTableContext;
        private string _currentTableFilter = "all";
        private readonly HashSet<string> _selectedTableStatuses = new();
        private readonly ObservableCollection<TableZoneSectionVM> _tableZoneSections = new();
        private readonly Dictionary<int, TableCardVM> _tableCardVMs = new();
        private int _tableColumns = 4;
        private bool _isLoadingTables = false;
        private string _activeTabTag = "tables";
        private bool _isDemoMode = false;

        public MainWindow()
        {
            InitializeComponent();

            _db = new LocalDatabase();
            _api = new ApiService("http://127.0.0.1:8000");
            _printer = new EscPosPrinterService();
            _syncEngine = new SyncEngine(_api, _db, _printer);

            TableZonesItemsControl.ItemsSource = _tableZoneSections;

            Dialogs.RegisterScrimHandler(visible => ModalScrim.Visibility = visible ? Visibility.Visible : Visibility.Collapsed);
            Toast.RegisterHost(MainToastHost);

            UpdateClockDisplay();
            _clockTimer = new DispatcherTimer { Interval = TimeSpan.FromSeconds(1) };
            _clockTimer.Tick += (s, e) => UpdateClockDisplay();
            _clockTimer.Start();

            TopConnectionPill.Update(true, 0, DateTime.Now);

            _syncEngine.SyncStatusUpdated += OnSyncStatusUpdated;
            _syncEngine.OnlineOrdersReceived += OnOnlineOrdersReceived;
        }

        private void UpdateClockDisplay()
        {
            var now = DateTime.Now;
            ClockText.Text = UzbekDateFormatter.FormatTime24(now);
            DateText.Text = UzbekDateFormatter.FormatDate(now);

            var openedAt = _currentShift.OpenedAt == default ? DateTime.Today.AddHours(8).AddMinutes(30) : _currentShift.OpenedAt;
            var elapsed = now - openedAt;
            if (elapsed < TimeSpan.Zero) elapsed = TimeSpan.Zero;
            ShiftChipText.Text = $"Smena: {openedAt:HH:mm} · {UzbekDateFormatter.FormatDuration(elapsed)}";
        }

        private void OnWindowSizeChanged(object sender, SizeChangedEventArgs e)
        {
            UpdateShellLayoutForWidth(e.NewSize.Width);
        }

        public void UpdateShellLayoutForWidth(double width)
        {
            RailColumn.Width = new GridLength(width < 1366 ? 80 : 88);

            int newCols = width >= 2200 ? 5 : width >= 1550 ? 4 : 3;
            if (newCols != _tableColumns)
            {
                _tableColumns = newCols;
                TablesLoadingGrid.Columns = newCols;
                foreach (var sec in _tableZoneSections)
                {
                    sec.Columns = newCols;
                }
            }
        }

        private async void OnWindowLoaded(object sender, RoutedEventArgs e)
        {
            if (!_isDemoMode)
            {
                await LoadDataAsync();
            }
        }

        private void OnWindowKeyDown(object sender, KeyEventArgs e)
        {
            if (e.Key == Key.F12)
            {
                OnPayCartClick(sender, new RoutedEventArgs());
                e.Handled = true;
            }
            else if (e.Key == Key.F11)
            {
                OnToggleKioskClick(sender, new RoutedEventArgs());
                e.Handled = true;
            }
            else if (e.Key == Key.F2)
            {
                SwitchToTab("quick_pos");
                e.Handled = true;
            }
            else if (e.Key == Key.F1)
            {
                SwitchToTab("tables");
                e.Handled = true;
            }
            else if (e.Key == Key.F5)
            {
                OnRefreshOnlineOrdersClick(sender, new RoutedEventArgs());
                e.Handled = true;
            }
            else if (e.Key == Key.F4 && _activeTabTag == "quick_pos")
            {
                OnDiscountPillClick(sender, new RoutedEventArgs());
                e.Handled = true;
            }
        }

        private async Task LoadDataAsync()
        {
            _isLoadingTables = true;
            UpdateTablesLoadingAndEmptyStates();

            // 1. Lokal SQLite keshidan o'qish (Darhol yuklanadi)
            _products = await _db.GetCachedProductsAsync();
            _categories = await _db.GetCachedCategoriesAsync();
            _tables = await _db.GetCachedTablesAsync();

            if (_tables.Count == 0)
            {
                // Standart 12 ta stol (Zal, Terrasa, VIP)
                for (int i = 1; i <= 6; i++)
                    _tables.Add(new RestaurantTable { Id = i, Number = i, Name = $"Stol #{i}", Zone = "Zal", Capacity = 4 });
                for (int i = 7; i <= 9; i++)
                    _tables.Add(new RestaurantTable { Id = i, Number = i, Name = $"Terrasa #{i - 6}", Zone = "Terrasa", Capacity = 6 });
                for (int i = 10; i <= 12; i++)
                    _tables.Add(new RestaurantTable { Id = i, Number = i, Name = $"VIP Xona #{i - 9}", Zone = "VIP", Capacity = 10 });
            }

            _isLoadingTables = false;
            RenderTables();
            RenderCategories();
            RenderProducts();
            RenderStopList();
            UpdateCartUI();
            UpdateShiftReportUI();

            // 2. Server bilan sinxronlash
            var bootstrap = await _api.GetBootstrapAsync();
            if (bootstrap != null && bootstrap.Status == "ok")
            {
                _departments = bootstrap.Departments;
                _categories = bootstrap.Categories;
                _products = bootstrap.Products;
                _tables = bootstrap.Tables;

                // Zonalar biriktirish
                foreach (var t in _tables)
                {
                    if (t.Number <= 6) t.Zone = "Zal";
                    else if (t.Number <= 9) t.Zone = "Terrasa";
                    else t.Zone = "VIP";
                }

                if (bootstrap.Settings != null)
                {
                    _settings = bootstrap.Settings;
                    ApplySettingsToUI();
                }

                await _db.SaveBootstrapCacheAsync(_departments, _categories, _products, _tables);

                RenderTables();
                RenderCategories();
                RenderProducts();
                RenderStopList();
            }
        }

        private void OnSyncStatusUpdated(object? sender, SyncStatusEventArgs e)
        {
            Dispatcher.Invoke(() =>
            {
                ApplySyncStatusUI(e.IsOnline, e.PendingOfflineOrdersCount, e.OnlineOrdersCount, e.LastSyncTime);
            });
        }

        private void ApplySyncStatusUI(bool isOnline, int pendingCount, int onlineOrdersCount, DateTime lastSync)
        {
            TopConnectionPill.Update(isOnline, pendingCount, lastSync);

            OfflineStrip.Visibility = isOnline ? Visibility.Collapsed : Visibility.Visible;
            OfflineStripQueueText.Text = pendingCount > 0 ? $"Navbat: {pendingCount} ta" : "Kesh faol";
            OfflineStripQueueText.Visibility = Visibility.Visible;

            NavOnlineBadgeText.Text = onlineOrdersCount.ToString();
            NavOnlineBadgeBorder.Visibility = onlineOrdersCount > 0 ? Visibility.Visible : Visibility.Collapsed;
        }

        private void OnOnlineOrdersReceived(object? sender, List<Order> orders)
        {
            Dispatcher.Invoke(() =>
            {
                _onlineOrders = orders;
                NavOnlineBadgeText.Text = orders.Count.ToString();
                NavOnlineBadgeBorder.Visibility = orders.Count > 0 ? Visibility.Visible : Visibility.Collapsed;
                RenderOnlineOrders();
            });
        }

        #region Navigatsiya va Kiosk
        private void OnNavClicked(object sender, RoutedEventArgs e)
        {
            if (sender is System.Windows.Controls.Primitives.ToggleButton btn && btn.Tag is string tag)
            {
                SwitchToTab(tag);
            }
        }

        private void SwitchToTab(string tag)
        {
            _activeTabTag = tag;

            TablesTab.Visibility = tag == "tables" ? Visibility.Visible : Visibility.Collapsed;
            QuickPosTab.Visibility = tag == "quick_pos" ? Visibility.Visible : Visibility.Collapsed;
            StopListTab.Visibility = tag == "stop_list" ? Visibility.Visible : Visibility.Collapsed;
            OnlineTab.Visibility = tag == "online" ? Visibility.Visible : Visibility.Collapsed;
            ShiftReportTab.Visibility = tag == "shift" ? Visibility.Visible : Visibility.Collapsed;
            SettingsTab.Visibility = tag == "settings" ? Visibility.Visible : Visibility.Collapsed;

            NavTablesBtn.IsChecked = tag == "tables";
            NavQuickPosBtn.IsChecked = tag == "quick_pos";
            NavStopListBtn.IsChecked = tag == "stop_list";
            NavOnlineBtn.IsChecked = tag == "online";
            NavShiftBtn.IsChecked = tag == "shift";
            NavSettingsBtn.IsChecked = tag == "settings";

            ScreenTitleText.Text = tag switch
            {
                "tables" => "Stollar",
                "quick_pos" => "Tezkor savdo",
                "stop_list" => "Stop-list",
                "online" => "Onlayn buyurtmalar",
                "shift" => "Smena",
                "settings" => "Sozlamalar",
                _ => "Dilkash POS"
            };

            if (tag == "quick_pos" && _activeTableContext == null)
            {
                _currentCart = new Order { ServiceType = "pickup" };
                CartTitleText.Text = "Tezkor savdo (Saboy)";
                CartSubtitleText.Text = "Kassir: " + _settings.CashierName;
                UpdateCartUI();
            }
            else if (tag == "shift")
            {
                UpdateShiftReportUI();
            }
        }

        private void OnToggleKioskClick(object sender, RoutedEventArgs e)
        {
            if (WindowStyle == WindowStyle.None)
            {
                WindowStyle = WindowStyle.SingleBorderWindow;
                WindowState = WindowState.Normal;
            }
            else
            {
                WindowStyle = WindowStyle.None;
                WindowState = WindowState.Maximized;
            }
        }

        private void OnLockAppClick(object sender, RoutedEventArgs e)
        {
            SetLockedState(true);
        }

        private void OnUnlockAppClick(object sender, RoutedEventArgs e)
        {
            SetLockedState(false);
        }

        public void SetLockedState(bool locked)
        {
            LockCashierNameText.Text = _settings.CashierName;
            LockOverlay.Visibility = locked ? Visibility.Visible : Visibility.Collapsed;
            WorkspaceShellGrid.Effect = locked ? new BlurEffect { Radius = 10 } : null;
        }
        #endregion

        #region 1. Stollar Xaritasi (Responsive Zone-Sectioned Tables Map)
        private static string GetTableStatusKey(RestaurantTable tbl)
        {
            if (tbl.Status == "bill_printed") return "bill_printed";
            if (tbl.Status == "reserved") return "reserved";
            if (tbl.IsOccupied || tbl.Status == "occupied") return "occupied";
            return "empty";
        }

        private void UpdateTableCounts()
        {
            int allCount = _tables.Count;
            int zalCount = _tables.Count(t => t.Zone == "Zal");
            int terrasaCount = _tables.Count(t => t.Zone == "Terrasa");
            int vipCount = _tables.Count(t => t.Zone == "VIP");

            FilterAllBtn.Content = $"Barchasi ({allCount})";
            FilterZalBtn.Content = $"Asosiy zal ({zalCount})";
            FilterTerrasaBtn.Content = $"Terrasa ({terrasaCount})";
            FilterVipBtn.Content = $"VIP ({vipCount})";

            int emptyCount = _tables.Count(t => GetTableStatusKey(t) == "empty");
            int occCount = _tables.Count(t => GetTableStatusKey(t) == "occupied");
            int billCount = _tables.Count(t => GetTableStatusKey(t) == "bill_printed");
            int reservedCount = _tables.Count(t => GetTableStatusKey(t) == "reserved");

            EmptyChipLabel.Text = $"Boʻsh ({emptyCount})";
            OccupiedChipLabel.Text = $"Band ({occCount})";
            BillChipLabel.Text = $"Hisob berildi ({billCount})";
            ReservedChipLabel.Text = $"Bron ({reservedCount})";

            int activeTablesCount = occCount + billCount;
            NavTablesCountBadge.Text = activeTablesCount.ToString();
            NavTablesCountBorder.Visibility = activeTablesCount > 0 ? Visibility.Visible : Visibility.Collapsed;
        }

        private void RenderTables()
        {
            UpdateTableCounts();
            _tableZoneSections.Clear();
            _tableCardVMs.Clear();

            var filtered = _tables.AsEnumerable();
            if (_currentTableFilter == "zal") filtered = filtered.Where(t => t.Zone == "Zal");
            else if (_currentTableFilter == "terrasa") filtered = filtered.Where(t => t.Zone == "Terrasa");
            else if (_currentTableFilter == "vip") filtered = filtered.Where(t => t.Zone == "VIP");

            if (_selectedTableStatuses.Count > 0)
            {
                filtered = filtered.Where(t => _selectedTableStatuses.Contains(GetTableStatusKey(t)));
            }

            var filteredList = filtered.ToList();
            var zoneOrder = new[]
            {
                ("Zal", "ASOSIY ZAL"),
                ("Terrasa", "TERRASA"),
                ("VIP", "VIP XONALAR")
            };

            foreach (var (zoneKey, zoneHeader) in zoneOrder)
            {
                var zoneTables = filteredList.Where(t => t.Zone == zoneKey).ToList();
                if (zoneTables.Count == 0) continue;

                int busyInZone = zoneTables.Count(t => GetTableStatusKey(t) is "occupied" or "bill_printed");
                var sec = new TableZoneSectionVM
                {
                    ZoneKey = zoneKey,
                    ZoneTitle = zoneHeader,
                    ZoneSummary = busyInZone > 0 ? $"{zoneTables.Count} ta stol · {busyInZone} band" : $"{zoneTables.Count} ta stol",
                    Columns = _tableColumns
                };

                foreach (var tbl in zoneTables)
                {
                    var vm = new TableCardVM(tbl);
                    _tableCardVMs[tbl.Number] = vm;
                    sec.Tables.Add(vm);
                }

                _tableZoneSections.Add(sec);
            }

            UpdateTablesLoadingAndEmptyStates();
        }

        private void RefreshSingleTableCard(RestaurantTable tbl)
        {
            UpdateTableCounts();
            if (_selectedTableStatuses.Count > 0)
            {
                RenderTables();
                return;
            }

            if (_tableCardVMs.TryGetValue(tbl.Number, out var vm))
            {
                vm.Refresh();
                var sec = _tableZoneSections.FirstOrDefault(s => s.ZoneKey == tbl.Zone);
                if (sec != null)
                {
                    int busyInZone = sec.Tables.Count(t => t.IsOccupiedOrBill);
                    sec.ZoneSummary = busyInZone > 0 ? $"{sec.Tables.Count} ta stol · {busyInZone} band" : $"{sec.Tables.Count} ta stol";
                }
            }
            else
            {
                RenderTables();
            }
        }

        private void UpdateTablesLoadingAndEmptyStates()
        {
            if (_isLoadingTables)
            {
                TablesLoadingGrid.Visibility = Visibility.Visible;
                TablesScrollViewer.Visibility = Visibility.Collapsed;
                TablesEmptyState.Visibility = Visibility.Collapsed;
            }
            else if (_tableZoneSections.Count == 0)
            {
                TablesLoadingGrid.Visibility = Visibility.Collapsed;
                TablesScrollViewer.Visibility = Visibility.Collapsed;
                TablesEmptyState.Visibility = Visibility.Visible;
            }
            else
            {
                TablesLoadingGrid.Visibility = Visibility.Collapsed;
                TablesScrollViewer.Visibility = Visibility.Visible;
                TablesEmptyState.Visibility = Visibility.Collapsed;
            }
        }

        private void OnTableCardControlClicked(object? sender, TableCardVM vm)
        {
            OnTableCardClicked(vm.Model);
        }

        private async void OnTablePreChekClicked(object? sender, TableCardVM vm)
        {
            var t = vm.Model;
            if (t.ActiveOrder != null && t.ActiveOrder.Items.Count > 0)
            {
                string kassaIp = IpKassaBox.Text.Trim();
                await _printer.PrintPreChekAsync(t.ActiveOrder, kassaIp);
                t.Status = "bill_printed";
                RefreshSingleTableCard(t);
                Toast.Show($"{t.Name} uchun hisob pre-cheki chop etildi", ToastTone.Success);
            }
        }

        private void OnTablePayClicked(object? sender, TableCardVM vm)
        {
            var t = vm.Model;
            OpenTableOrderInQuickPos(t);
            OnPayCartClick(this, new RoutedEventArgs());
        }

        private async void OnTableCardClicked(RestaurantTable table)
        {
            if (!table.IsOccupied)
            {
                var dialog = new OpenTableDialog(table.Number, table.Name, _settings.CashierName);
                if (Dialogs.ShowModal(dialog, this) == true)
                {
                    table.IsOccupied = true;
                    table.GuestsCount = dialog.SelectedGuestsCount;
                    table.AssignedWaiter = dialog.WaiterName;

                    var order = await _api.OpenTableAsync(table.Number, table.GuestsCount, dialog.WaiterName);
                    if (order != null)
                    {
                        table.ActiveOrder = order;
                    }
                    else
                    {
                        table.ActiveOrder = new Order
                        {
                            ServiceType = "dine_in",
                            TableNumber = table.Number.ToString(),
                            GuestsCount = table.GuestsCount,
                            WaiterName = dialog.WaiterName,
                            OfflineId = Guid.NewGuid().ToString("N")
                        };
                    }

                    RefreshSingleTableCard(table);
                    OpenTableOrderInQuickPos(table);
                }
            }
            else
            {
                OpenTableOrderInQuickPos(table);
            }
        }

        private void OpenTableOrderInQuickPos(RestaurantTable table)
        {
            _activeTableContext = table;
            _currentCart = table.ActiveOrder ?? new Order
            {
                ServiceType = "dine_in",
                TableNumber = table.Number.ToString(),
                GuestsCount = table.GuestsCount,
                WaiterName = table.AssignedWaiter ?? _settings.CashierName
            };

            CartTitleText.Text = $"{table.Name} · {table.Zone}";
            CartSubtitleText.Text = $"Ofitsiant: {_currentCart.WaiterName} · {_currentCart.GuestsCount} mehmon";
            SwitchToTab("quick_pos");
            UpdateCartUI();
        }

        private void OnTableFilterAll(object sender, RoutedEventArgs e) { _currentTableFilter = "all"; RenderTables(); }
        private void OnTableFilterZal(object sender, RoutedEventArgs e) { _currentTableFilter = "zal"; RenderTables(); }
        private void OnTableFilterTerrasa(object sender, RoutedEventArgs e) { _currentTableFilter = "terrasa"; RenderTables(); }
        private void OnTableFilterVip(object sender, RoutedEventArgs e) { _currentTableFilter = "vip"; RenderTables(); }

        private void OnStatusFilterChipClick(object sender, RoutedEventArgs e)
        {
            if (sender is ToggleButton tb && tb.Tag is string statusKey)
            {
                if (tb.IsChecked == true)
                    _selectedTableStatuses.Add(statusKey);
                else
                    _selectedTableStatuses.Remove(statusKey);

                RenderTables();
            }
        }

        private void OnResetTableFilters(object? sender, EventArgs e)
        {
            _currentTableFilter = "all";
            FilterAllBtn.IsChecked = true;
            _selectedTableStatuses.Clear();
            StatusFilterEmptyChip.IsChecked = false;
            StatusFilterOccupiedChip.IsChecked = false;
            StatusFilterBillChip.IsChecked = false;
            StatusFilterReservedChip.IsChecked = false;
            RenderTables();
        }
        #endregion

        #region 2. Tezkor Saboy & Buyurtma Qabul Qilish (3-Column POS)
        private void RenderCategories()
        {
            CategoriesStackPanel.Children.Clear();
            var allBtn = new Button
            {
                Content = $"🍽 Barcha Taomlar ({_products.Count})",
                Height = 56,
                Margin = new Thickness(0, 0, 0, 8),
                FontSize = 15,
                FontWeight = FontWeights.Bold,
                Style = (Style)FindResource("TouchButtonStyle"),
                Background = _selectedCategory == null ? (Brush)FindResource("BrandPrimaryBrush") : (Brush)FindResource("CardDarkBrush")
            };
            allBtn.Click += (s, e) =>
            {
                _selectedCategory = null;
                RenderCategories();
                RenderProducts(ProductSearchBox.Text);
            };
            CategoriesStackPanel.Children.Add(allBtn);

            foreach (var cat in _categories)
            {
                string icon = cat.Department switch
                {
                    "shashlik" => "🥩",
                    "somsa" => "🥟",
                    "fastfood" => "🍔",
                    "bar" => "☕",
                    _ => "🍲"
                };

                int pCount = _products.Count(p => p.CategoryId == cat.Id);

                var btn = new Button
                {
                    Content = $"{icon} {cat.Name} ({pCount})",
                    Height = 54,
                    Margin = new Thickness(0, 0, 0, 8),
                    FontSize = 14,
                    FontWeight = FontWeights.SemiBold,
                    Style = (Style)FindResource("TouchButtonStyle"),
                    Background = _selectedCategory?.Id == cat.Id ? (Brush)FindResource("BrandPrimaryBrush") : (Brush)FindResource("CardDarkBrush"),
                    Tag = cat
                };
                btn.Click += (s, e) =>
                {
                    _selectedCategory = (Category)((Button)s).Tag;
                    RenderCategories();
                    RenderProducts(ProductSearchBox.Text);
                };
                CategoriesStackPanel.Children.Add(btn);
            }
        }

        private void RenderProducts(string? query = null)
        {
            ProductsWrapPanel.Children.Clear();
            var list = _products;

            if (_selectedCategory != null)
                list = list.Where(p => p.CategoryId == _selectedCategory.Id).ToList();

            if (!string.IsNullOrWhiteSpace(query))
                list = list.Where(p => p.Name.Contains(query, StringComparison.OrdinalIgnoreCase)).ToList();

            foreach (var prod in list)
            {
                int inCartQty = _currentCart.Items.FirstOrDefault(i => i.ProductId == prod.Id)?.Quantity ?? 0;

                // Katta sensorli taom kartasi (220x165px)
                var card = new Border
                {
                    Width = 220,
                    Height = 165,
                    Margin = new Thickness(8),
                    CornerRadius = new CornerRadius(12),
                    Background = prod.IsAvailable ? (Brush)FindResource("CardDarkBrush") : new SolidColorBrush(Color.FromRgb(45, 20, 20)),
                    BorderThickness = new Thickness(2),
                    BorderBrush = !prod.IsAvailable ? (Brush)FindResource("DangerRedBrush") :
                                 inCartQty > 0 ? (Brush)FindResource("AccentGoldBrush") : new SolidColorBrush(Color.FromRgb(51, 65, 85)),
                    Padding = new Thickness(14),
                    Cursor = prod.IsAvailable ? Cursors.Hand : Cursors.No,
                    Tag = prod,
                    Opacity = prod.IsAvailable ? 1.0 : 0.65
                };

                var grid = new Grid();
                grid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
                grid.RowDefinitions.Add(new RowDefinition { Height = new GridLength(1, GridUnitType.Star) });
                grid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });

                // 1. Toifa va Savatdagi soni badge
                var topGrid = new Grid();
                var deptPill = new TextBlock
                {
                    Text = prod.CategoryName.ToUpper(),
                    FontSize = 11,
                    FontWeight = FontWeights.Bold,
                    Foreground = new SolidColorBrush(Color.FromRgb(148, 163, 184)),
                    VerticalAlignment = VerticalAlignment.Center
                };
                topGrid.Children.Add(deptPill);

                if (inCartQty > 0)
                {
                    var qtyBadge = new Border
                    {
                        HorizontalAlignment = HorizontalAlignment.Right,
                        Background = (Brush)FindResource("AccentGoldBrush"),
                        CornerRadius = new CornerRadius(6),
                        Padding = new Thickness(8, 2, 8, 2)
                    };
                    qtyBadge.Child = new TextBlock { Text = $"x{inCartQty}", FontSize = 12, FontWeight = FontWeights.Black, Foreground = Brushes.White };
                    topGrid.Children.Add(qtyBadge);
                }
                Grid.SetRow(topGrid, 0);

                // 2. Taom Nomi
                var nameBlock = new TextBlock
                {
                    Text = prod.Name,
                    FontSize = 16,
                    FontWeight = FontWeights.ExtraBold,
                    Foreground = Brushes.White,
                    TextWrapping = TextWrapping.Wrap,
                    Margin = new Thickness(0, 6, 0, 6),
                    VerticalAlignment = VerticalAlignment.Center
                };
                Grid.SetRow(nameBlock, 1);

                // 3. Pastki Narx va Status
                var bottomGrid = new Grid();
                var priceText = new TextBlock
                {
                    Text = prod.FormattedPrice,
                    FontSize = 17,
                    FontWeight = FontWeights.Black,
                    Foreground = (Brush)FindResource("SuccessGreenBrush"),
                    VerticalAlignment = VerticalAlignment.Center
                };
                bottomGrid.Children.Add(priceText);

                if (!prod.IsAvailable)
                {
                    var stopPill = new Border
                    {
                        HorizontalAlignment = HorizontalAlignment.Right,
                        Background = (Brush)FindResource("DangerRedBrush"),
                        CornerRadius = new CornerRadius(6),
                        Padding = new Thickness(8, 3, 8, 3)
                    };
                    stopPill.Child = new TextBlock { Text = "STOP-LIST", FontSize = 11, FontWeight = FontWeights.Black, Foreground = Brushes.White };
                    bottomGrid.Children.Add(stopPill);
                }
                Grid.SetRow(bottomGrid, 2);

                grid.Children.Add(topGrid);
                grid.Children.Add(nameBlock);
                grid.Children.Add(bottomGrid);
                card.Child = grid;

                if (prod.IsAvailable)
                {
                    card.MouseLeftButtonUp += (s, e) => AddProductToCart((Product)((Border)s).Tag);
                }

                ProductsWrapPanel.Children.Add(card);
            }
        }

        private void AddProductToCart(Product prod)
        {
            var existing = _currentCart.Items.FirstOrDefault(i => i.ProductId == prod.Id);
            if (existing != null)
            {
                existing.Quantity++;
            }
            else
            {
                _currentCart.Items.Add(new OrderItem
                {
                    ProductId = prod.Id,
                    ProductName = prod.Name,
                    Price = prod.Price,
                    Quantity = 1,
                    Department = prod.Department,
                    CategoryName = prod.CategoryName
                });
            }
            UpdateCartUI();
            RenderProducts(ProductSearchBox.Text);
        }

        private void UpdateCartUI()
        {
            CartItemsStackPanel.Children.Clear();

            foreach (var item in _currentCart.Items)
            {
                var border = new Border
                {
                    Background = new SolidColorBrush(Color.FromRgb(15, 23, 42)),
                    CornerRadius = new CornerRadius(10),
                    Padding = new Thickness(12),
                    Margin = new Thickness(0, 0, 0, 10),
                    BorderBrush = new SolidColorBrush(Color.FromRgb(30, 41, 59)),
                    BorderThickness = new Thickness(1)
                };

                var grid = new Grid();
                grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
                grid.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });

                // Chap: Taom nomi, Izohi va Hisobi
                var leftStack = new StackPanel();
                leftStack.Children.Add(new TextBlock { Text = item.ProductName, FontSize = 16, FontWeight = FontWeights.Bold, Foreground = Brushes.White });
                leftStack.Children.Add(new TextBlock { Text = $"{item.Price:N0} so'm × {item.Quantity} = {item.Total:N0} so'm", FontSize = 13, Foreground = new SolidColorBrush(Color.FromRgb(148, 163, 184)), Margin = new Thickness(0, 2, 0, 0) });

                if (!string.IsNullOrEmpty(item.Notes))
                {
                    leftStack.Children.Add(new TextBlock { Text = $"💬 {item.Notes}", FontSize = 12, FontWeight = FontWeights.SemiBold, Foreground = (Brush)FindResource("AccentGoldBrush"), Margin = new Thickness(0, 4, 0, 0) });
                }
                Grid.SetColumn(leftStack, 0);

                // O'ng: Sensorli Katta Stepper (- / +) va Izoh tugmasi
                var rightStack = new StackPanel { Orientation = Orientation.Horizontal, VerticalAlignment = VerticalAlignment.Center };

                var noteBtn = new Button { Content = "✎ Izoh", Height = 40, Padding = new Thickness(10, 0, 10, 0), FontSize = 12, FontWeight = FontWeights.SemiBold, Margin = new Thickness(0, 0, 8, 0), Style = (Style)FindResource("TouchSecondaryButton"), Tag = item };
                var minusBtn = new Button { Content = "—", Width = 40, Height = 40, FontSize = 18, FontWeight = FontWeights.Black, Margin = new Thickness(2, 0, 2, 0), Style = (Style)FindResource("TouchSecondaryButton"), Tag = item };
                var qtyBlock = new TextBlock { Text = item.Quantity.ToString(), Width = 34, TextAlignment = TextAlignment.Center, FontSize = 17, FontWeight = FontWeights.Black, Foreground = Brushes.White, VerticalAlignment = VerticalAlignment.Center };
                var plusBtn = new Button { Content = "+", Width = 40, Height = 40, FontSize = 18, FontWeight = FontWeights.Black, Margin = new Thickness(2, 0, 0, 0), Style = (Style)FindResource("TouchSecondaryButton"), Tag = item };

                noteBtn.Click += (s, e) =>
                {
                    var it = (OrderItem)((Button)s).Tag;
                    var dlg = new ItemModifierDialog(it.ProductName, it.Notes);
                    if (Dialogs.ShowModal(dlg, this) == true)
                    {
                        it.Notes = dlg.Notes;
                        UpdateCartUI();
                    }
                };

                minusBtn.Click += (s, e) =>
                {
                    var it = (OrderItem)((Button)s).Tag;
                    it.Quantity--;
                    if (it.Quantity <= 0) _currentCart.Items.Remove(it);
                    UpdateCartUI();
                    RenderProducts(ProductSearchBox.Text);
                };

                plusBtn.Click += (s, e) =>
                {
                    var it = (OrderItem)((Button)s).Tag;
                    it.Quantity++;
                    UpdateCartUI();
                    RenderProducts(ProductSearchBox.Text);
                };

                rightStack.Children.Add(noteBtn);
                rightStack.Children.Add(minusBtn);
                rightStack.Children.Add(qtyBlock);
                rightStack.Children.Add(plusBtn);
                Grid.SetColumn(rightStack, 1);

                grid.Children.Add(leftStack);
                grid.Children.Add(rightStack);
                border.Child = grid;

                CartItemsStackPanel.Children.Add(border);
            }

            // Moliyaviy hisob-kitoblar
            decimal subtotal = _currentCart.Items.Sum(i => i.Total);
            _currentCart.ProductsTotal = subtotal;

            decimal serviceFee = 0;
            if (_currentCart.ServiceType == "dine_in")
            {
                if (_settings.ServiceFeeType == "percent")
                    serviceFee = subtotal * (_settings.ServiceFeePercent / 100m);
                else if (_settings.ServiceFeeType == "per_person")
                    serviceFee = _currentCart.GuestsCount * _settings.ServiceFeePerPerson;
            }
            _currentCart.ServiceFeeAmount = serviceFee;
            _currentCart.RecalculateTotals();

            CartSubtotalText.Text = $"{subtotal:N0} so'm";
            DiscountPillBtn.Content = $"🏷 Chegirma: {_currentCart.DiscountPercent:0}% (F4)";
            CartDiscountText.Text = $"-{_currentCart.DiscountAmount:N0} so'm";
            ServiceFeeLabelText.Text = $"Xizmat haqi ({(_settings.ServiceFeeType == "percent" ? $"{_settings.ServiceFeePercent:0}%" : "Odam boshiga")}):";
            CartServiceFeeText.Text = $"{serviceFee:N0} so'm";
            CartTotalText.Text = $"{_currentCart.TotalAmount:N0} so'm";
        }

        private void OnDiscountPillClick(object sender, RoutedEventArgs e)
        {
            var dlg = new DiscountDialog(_currentCart.DiscountPercent);
            if (Dialogs.ShowModal(dlg, this) == true)
            {
                _currentCart.DiscountPercent = dlg.DiscountPercent;
                UpdateCartUI();
            }
        }

        private async void OnSendToKitchenClick(object sender, RoutedEventArgs e)
        {
            if (_currentCart.Items.Count == 0)
            {
                Toast.Show("Oshxonaga yuborish uchun savatchaga taom qoʻshing", ToastTone.Warning);
                return;
            }

            await _api.CreateOrUpdateOrderAsync(_currentCart);
            await PrintOrderKitchenSlipsAsync(_currentCart);

            Toast.Show("Buyurtma barcha boʻlim printerlariga yuborildi", ToastTone.Success);
        }

        private async void OnPrintPreChekClick(object sender, RoutedEventArgs e)
        {
            if (_currentCart.Items.Count == 0)
            {
                Toast.Show("Hisob cheki chiqarish uchun savatchaga taom qoʻshing", ToastTone.Warning);
                return;
            }

            string kassaIp = IpKassaBox.Text.Trim();
            if (string.IsNullOrEmpty(kassaIp))
            {
                Toast.Show("Kassa printeri IP manzili kiritilmagan", ToastTone.Warning);
                return;
            }

            var res = await _printer.PrintPreChekAsync(_currentCart, kassaIp);
            if (res.Success)
            {
                if (_activeTableContext != null)
                {
                    _activeTableContext.Status = "bill_printed";
                    RefreshSingleTableCard(_activeTableContext);
                }
                Toast.Show("Mijoz uchun hisob pre-cheki chop etildi", ToastTone.Success);
            }
            else
            {
                Toast.Show(res.Message, ToastTone.Warning);
            }
        }

        private async void OnPayCartClick(object sender, RoutedEventArgs e)
        {
            if (_currentCart.Items.Count == 0)
            {
                Toast.Show("Savatcha boʻsh. Toʻlov uchun taom tanlang", ToastTone.Info);
                return;
            }

            var dialog = new PaymentDialog(_currentCart.TotalAmount, _currentCart.OrderNumber ?? "YANGI", _currentCart.TableNumber, _currentCart.GuestsCount);
            if (Dialogs.ShowModal(dialog, this) == true)
            {
                _currentCart.IsPaid = true;
                _currentCart.PaymentMethod = dialog.SelectedPaymentMethod;

                var savedOrder = await _api.CreateOrUpdateOrderAsync(_currentCart);
                if (savedOrder != null)
                {
                    _currentCart = savedOrder;
                    await _api.PayOrderAsync(savedOrder.Id, dialog.SelectedPaymentMethod, dialog.PaidCash, dialog.PaidCard);
                }
                else
                {
                    await _db.EnqueueOfflineOrderAsync(_currentCart);
                }

                await PrintOrderKitchenSlipsAsync(_currentCart);
                string kassaIp = IpKassaBox.Text.Trim();
                if (!string.IsNullOrEmpty(kassaIp))
                {
                    await _printer.PrintKassaReceiptAsync(_currentCart, kassaIp, dialog.PaidCash, dialog.PaidCard, dialog.ChangeAmount);
                }

                // Smena hisoboti yangilash
                _currentShift.TotalOrdersCount++;
                _currentShift.TotalRevenue += _currentCart.TotalAmount;
                if (dialog.SelectedPaymentMethod == "naqd") _currentShift.CashRevenue += _currentCart.TotalAmount;
                else if (dialog.SelectedPaymentMethod == "karta") _currentShift.CardRevenue += _currentCart.TotalAmount;
                else { _currentShift.CashRevenue += dialog.PaidCash; _currentShift.CardRevenue += dialog.PaidCard; }

                _currentShift.ServiceFeesCollected += _currentCart.ServiceFeeAmount;
                _currentShift.DiscountsGiven += _currentCart.DiscountAmount;
                UpdateShiftReportUI();

                if (_activeTableContext != null)
                {
                    var closed = _activeTableContext;
                    closed.IsOccupied = false;
                    closed.Status = "empty";
                    closed.ActiveOrder = null;
                    _activeTableContext = null;
                    RefreshSingleTableCard(closed);
                }

                _currentCart = new Order { ServiceType = "pickup" };
                CartTitleText.Text = "Tezkor savdo (Saboy)";
                CartSubtitleText.Text = "Kassir: " + _settings.CashierName;
                UpdateCartUI();
                RenderProducts();

                Toast.Show("Toʻlov qabul qilindi va kassa cheki chop etildi", ToastTone.Success);
            }
        }

        private async Task PrintOrderKitchenSlipsAsync(Order order)
        {
            var distinctDepts = order.Items.Select(i => i.Department).Distinct();
            foreach (var dept in distinctDepts)
            {
                string ip = GetPrinterIpForDept(dept);
                if (!string.IsNullOrEmpty(ip))
                {
                    string name = GetDepartmentName(dept);
                    await _printer.PrintDepartmentSlipAsync(order, dept, name, ip);
                }
            }
        }

        private string GetPrinterIpForDept(string dept)
        {
            return dept.ToLower() switch
            {
                "shashlik" => IpShashlikBox.Text.Trim(),
                "somsa" => IpSomsaBox.Text.Trim(),
                "kitchen" => IpKitchenBox.Text.Trim(),
                "fastfood" => IpFastfoodBox.Text.Trim(),
                "bar" => IpBarBox.Text.Trim(),
                _ => IpKitchenBox.Text.Trim()
            };
        }

        private string GetDepartmentName(string dept)
        {
            return dept.ToLower() switch
            {
                "shashlik" => "Shashlikxona / Mangal",
                "somsa" => "Somsaxona / Tandir",
                "kitchen" => "Issiq Oshxona",
                "fastfood" => "Fast-Food",
                "bar" => "Bar & Desert",
                _ => "Oshxona"
            };
        }

        private void OnClearCartClick(object sender, RoutedEventArgs e)
        {
            _currentCart.Items.Clear();
            _currentCart.DiscountPercent = 0;
            _currentCart.DiscountAmount = 0;
            UpdateCartUI();
            RenderProducts(ProductSearchBox.Text);
        }

        private void OnProductSearchChanged(object sender, TextChangedEventArgs e)
        {
            RenderProducts(ProductSearchBox.Text);
        }

        private void OnClearSearchClick(object sender, RoutedEventArgs e)
        {
            ProductSearchBox.Text = "";
            RenderProducts();
        }
        #endregion

        #region 3. Stop-List Boshqaruvi
        private void RenderStopList(string? query = null)
        {
            StopListWrapPanel.Children.Clear();
            var list = _products;
            if (!string.IsNullOrWhiteSpace(query))
                list = list.Where(p => p.Name.Contains(query, StringComparison.OrdinalIgnoreCase)).ToList();

            int total = _products.Count;
            int stopped = _products.Count(p => !p.IsAvailable);
            StopListSummaryText.Text = $"Jami: {total} ta | Mavjud: {total - stopped} ta | Stop-listda: {stopped} ta";

            NavStopListCountBadge.Text = stopped.ToString();
            NavStopListBadgeBorder.Visibility = stopped > 0 ? Visibility.Visible : Visibility.Collapsed;

            foreach (var prod in list)
            {
                // Keng 380x100px Stop-list kartasi
                var card = new Border
                {
                    Width = 380,
                    Height = 100,
                    Margin = new Thickness(8),
                    CornerRadius = new CornerRadius(12),
                    Background = (Brush)FindResource("CardDarkBrush"),
                    BorderThickness = new Thickness(2),
                    BorderBrush = prod.IsAvailable ? (Brush)FindResource("SuccessGreenBrush") : (Brush)FindResource("DangerRedBrush"),
                    Padding = new Thickness(16)
                };

                var grid = new Grid();
                grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
                grid.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });

                var leftStack = new StackPanel { VerticalAlignment = VerticalAlignment.Center };
                leftStack.Children.Add(new TextBlock { Text = prod.Name, FontSize = 16, FontWeight = FontWeights.Bold, Foreground = Brushes.White });
                leftStack.Children.Add(new TextBlock { Text = $"{prod.CategoryName} • {prod.FormattedPrice}", FontSize = 13, Foreground = new SolidColorBrush(Color.FromRgb(148, 163, 184)), Margin = new Thickness(0, 3, 0, 0) });
                Grid.SetColumn(leftStack, 0);

                var toggleBtn = new Button
                {
                    Content = prod.IsAvailable ? "🟢 MAVJUD" : "🛑 STOP",
                    Width = 110,
                    Height = 50,
                    FontSize = 13,
                    FontWeight = FontWeights.Black,
                    Style = (Style)FindResource("TouchButtonStyle"),
                    Background = prod.IsAvailable ? (Brush)FindResource("SuccessGreenBrush") : (Brush)FindResource("DangerRedBrush"),
                    Tag = prod
                };
                toggleBtn.Click += async (s, e) =>
                {
                    var p = (Product)((Button)s).Tag;
                    p.IsAvailable = !p.IsAvailable;
                    await _db.UpdateProductAvailabilityAsync(p.Id, p.IsAvailable);
                    await _api.ToggleStopListAsync(p.Id, p.IsAvailable);
                    RenderStopList(StopListSearchBox.Text);
                    RenderProducts();
                };
                Grid.SetColumn(toggleBtn, 1);

                grid.Children.Add(leftStack);
                grid.Children.Add(toggleBtn);
                card.Child = grid;

                StopListWrapPanel.Children.Add(card);
            }
        }

        private void OnStopListSearchChanged(object sender, TextChangedEventArgs e)
        {
            RenderStopList(StopListSearchBox.Text);
        }
        #endregion

        #region 4. Online Buyurtmalar (Live Kitchen Dispatcher)
        private void RenderOnlineOrders()
        {
            OnlineOrdersStackPanel.Children.Clear();
            if (_onlineOrders.Count == 0)
            {
                var emptyCard = new Border
                {
                    Background = (Brush)FindResource("CardDarkBrush"),
                    CornerRadius = new CornerRadius(14),
                    Padding = new Thickness(30),
                    Margin = new Thickness(0, 20, 0, 0)
                };
                var emptyStack = new StackPanel { HorizontalAlignment = HorizontalAlignment.Center };
                emptyStack.Children.Add(new TextBlock { Text = "📲", FontSize = 48, HorizontalAlignment = HorizontalAlignment.Center });
                emptyStack.Children.Add(new TextBlock { Text = "Hozircha yangi online buyurtmalar yo'q", FontSize = 18, FontWeight = FontWeights.Bold, Foreground = Brushes.White, HorizontalAlignment = HorizontalAlignment.Center, Margin = new Thickness(0, 10, 0, 0) });
                emptyStack.Children.Add(new TextBlock { Text = "Telegram bot yoki mobil ilovadan yangi buyurtma tushganda shu yerda avtomatik ko'rinadi.", FontSize = 14, Foreground = new SolidColorBrush(Color.FromRgb(148, 163, 184)), HorizontalAlignment = HorizontalAlignment.Center, Margin = new Thickness(0, 4, 0, 0) });
                emptyCard.Child = emptyStack;
                OnlineOrdersStackPanel.Children.Add(emptyCard);
                return;
            }

            foreach (var order in _onlineOrders)
            {
                var card = new Border
                {
                    Background = (Brush)FindResource("CardDarkBrush"),
                    CornerRadius = new CornerRadius(14),
                    Padding = new Thickness(20),
                    Margin = new Thickness(0, 0, 0, 16),
                    BorderThickness = new Thickness(2),
                    BorderBrush = (Brush)FindResource("AccentGoldBrush")
                };

                var grid = new Grid();
                grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
                grid.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });

                var leftStack = new StackPanel();
                var headerStack = new StackPanel { Orientation = Orientation.Horizontal };
                headerStack.Children.Add(new TextBlock { Text = order.ServiceType == "delivery" ? "🚴 DOSTAVKA " : "🛍 SABOY ", FontSize = 20, FontWeight = FontWeights.Black, Foreground = (Brush)FindResource("AccentGoldBrush") });
                headerStack.Children.Add(new TextBlock { Text = $"#{order.OrderNumber}", FontSize = 20, FontWeight = FontWeights.Black, Foreground = Brushes.White });
                leftStack.Children.Add(headerStack);

                leftStack.Children.Add(new TextBlock { Text = $"👤 Mijoz: {order.CustomerName} | 📞 Tel: {order.CustomerPhone}", FontSize = 15, Foreground = new SolidColorBrush(Color.FromRgb(148, 163, 184)), Margin = new Thickness(0, 6, 0, 10) });

                foreach (var it in order.Items)
                {
                    leftStack.Children.Add(new TextBlock { Text = $"• {it.Quantity}x {it.ProductName} — {it.Total:N0} so'm", FontSize = 15, Foreground = Brushes.White, Margin = new Thickness(0, 1, 0, 1) });
                }

                leftStack.Children.Add(new TextBlock { Text = $"JAMI SUMMA: {order.TotalAmount:N0} SO'M", FontSize = 19, FontWeight = FontWeights.Black, Foreground = (Brush)FindResource("SuccessGreenBrush"), Margin = new Thickness(0, 10, 0, 0) });
                Grid.SetColumn(leftStack, 0);

                var rightStack = new StackPanel { VerticalAlignment = VerticalAlignment.Center };
                var acceptBtn = new Button
                {
                    Content = "✅ QABUL QILISH VA CHOP ETISH",
                    Height = 60,
                    Padding = new Thickness(22, 10, 22, 10),
                    FontSize = 15,
                    FontWeight = FontWeights.Black,
                    Style = (Style)FindResource("TouchButtonStyle"),
                    Background = (Brush)FindResource("SuccessGreenBrush"),
                    Tag = order
                };
                acceptBtn.Click += async (s, e) =>
                {
                    var ord = (Order)((Button)s).Tag;
                    await PrintOrderKitchenSlipsAsync(ord);
                    string kassaIp = IpKassaBox.Text.Trim();
                    if (!string.IsNullOrEmpty(kassaIp))
                    {
                        await _printer.PrintKassaReceiptAsync(ord, kassaIp, ord.TotalAmount, 0, 0);
                    }
                    _onlineOrders.Remove(ord);
                    NavOnlineBadgeText.Text = _onlineOrders.Count.ToString();
                    NavOnlineBadgeBorder.Visibility = _onlineOrders.Count > 0 ? Visibility.Visible : Visibility.Collapsed;
                    RenderOnlineOrders();
                    Toast.Show($"Buyurtma #{ord.OrderNumber} qabul qilindi va boʻlimlarga yuborildi", ToastTone.Success);
                };

                rightStack.Children.Add(acceptBtn);
                Grid.SetColumn(rightStack, 1);

                grid.Children.Add(leftStack);
                grid.Children.Add(rightStack);
                card.Child = grid;

                OnlineOrdersStackPanel.Children.Add(card);
            }
        }

        private async void OnRefreshOnlineOrdersClick(object sender, RoutedEventArgs e)
        {
            _onlineOrders = await _api.GetOnlineOrdersAsync();
            NavOnlineBadgeText.Text = _onlineOrders.Count.ToString();
            NavOnlineBadgeBorder.Visibility = _onlineOrders.Count > 0 ? Visibility.Visible : Visibility.Collapsed;
            RenderOnlineOrders();
        }
        #endregion

        #region 5. Smena va Z-Hisobot (Analytics & Shift Management)
        private void UpdateShiftReportUI()
        {
            SidebarCashierNameText.Text = _settings.CashierName;
            ShiftHeaderInfoText.Text = $"Smena ochiq • Kassir: {_settings.CashierName} • Boshlanish: Bugun 08:30";

            ShiftTotalRevenueText.Text = $"{_currentShift.TotalRevenue:N0} so'm";
            ShiftCashRevenueText.Text = $"{_currentShift.CashRevenue:N0} so'm";
            ShiftCardRevenueText.Text = $"{_currentShift.CardRevenue:N0} so'm";
            ShiftOrdersCountText.Text = $"{_currentShift.TotalOrdersCount} ta";

            ShiftServiceFeeText.Text = $"{_currentShift.ServiceFeesCollected:N0} so'm";
            ShiftDiscountsText.Text = $"{_currentShift.DiscountsGiven:N0} so'm";
        }

        private async void OnPrintXReportDirect(object sender, RoutedEventArgs e)
        {
            string kassaIp = IpKassaBox.Text.Trim();
            if (string.IsNullOrEmpty(kassaIp))
            {
                Toast.Show("Kassa printeri IP manzili kiritilmagan", ToastTone.Warning);
                return;
            }

            var res = await _printer.PrintShiftReportAsync(_currentShift, false, kassaIp);
            if (res.Success)
            {
                Toast.Show("Oraliq X-hisobot kassa printerida chop etildi", ToastTone.Success);
            }
            else
            {
                Toast.Show(res.Message, ToastTone.Warning);
            }
        }

        private async void OnCloseShiftDirect(object sender, RoutedEventArgs e)
        {
            bool confirmed = Dialogs.Confirm(
                "Smenani yopish",
                "Kassa smenasini yopib, Z-hisobot chiqarmoqchimisiz?",
                "Smenani yopish",
                "Bekor qilish",
                isDestructive: true,
                owner: this);

            if (confirmed)
            {
                string kassaIp = IpKassaBox.Text.Trim();
                if (!string.IsNullOrEmpty(kassaIp))
                {
                    await _printer.PrintShiftReportAsync(_currentShift, true, kassaIp);
                }

                // Smena ma'lumotlarini nolga tushirish
                _currentShift.TotalOrdersCount = 0;
                _currentShift.TotalRevenue = 0;
                _currentShift.CashRevenue = 0;
                _currentShift.CardRevenue = 0;
                _currentShift.ServiceFeesCollected = 0;
                _currentShift.DiscountsGiven = 0;

                UpdateShiftReportUI();
                Toast.Show("Kassa smenasi yopildi va Z-hisobot chop etildi", ToastTone.Success);
            }
        }
        #endregion

        #region 6. Printerlar va Sozlamalar
        private void ApplySettingsToUI()
        {
            if (_settings.Printers.TryGetValue("kassa", out var kassa)) IpKassaBox.Text = kassa;
            if (_settings.Printers.TryGetValue("shashlik", out var shashlik)) IpShashlikBox.Text = shashlik;
            if (_settings.Printers.TryGetValue("somsa", out var somsa)) IpSomsaBox.Text = somsa;
            if (_settings.Printers.TryGetValue("kitchen", out var kitchen)) IpKitchenBox.Text = kitchen;
            if (_settings.Printers.TryGetValue("fastfood", out var fastfood)) IpFastfoodBox.Text = fastfood;
            if (_settings.Printers.TryGetValue("bar", out var bar)) IpBarBox.Text = bar;

            ServiceFeeValueBox.Text = _settings.ServiceFeeType == "percent"
                ? _settings.ServiceFeePercent.ToString("0")
                : _settings.ServiceFeePerPerson.ToString("0");

            ServerUrlBox.Text = _settings.ServerUrl;
            CashierNameBox.Text = _settings.CashierName;
            SidebarCashierNameText.Text = _settings.CashierName;
            AutoPrintCheck.IsChecked = _settings.AutoPrintNetwork;
        }

        private async void OnTestPrintKassa(object sender, RoutedEventArgs e) => await TestPrintAsync("Kassa Hisob Printeri", IpKassaBox.Text);
        private async void OnTestPrintShashlik(object sender, RoutedEventArgs e) => await TestPrintAsync("Shashlikxona Printeri", IpShashlikBox.Text);
        private async void OnTestPrintSomsa(object sender, RoutedEventArgs e) => await TestPrintAsync("Somsaxona Printeri", IpSomsaBox.Text);
        private async void OnTestPrintKitchen(object sender, RoutedEventArgs e) => await TestPrintAsync("Issiq Oshxona Printeri", IpKitchenBox.Text);
        private async void OnTestPrintFastfood(object sender, RoutedEventArgs e) => await TestPrintAsync("Fast-Food Printeri", IpFastfoodBox.Text);
        private async void OnTestPrintBar(object sender, RoutedEventArgs e) => await TestPrintAsync("Desert & Bar Printeri", IpBarBox.Text);

        private async Task TestPrintAsync(string title, string ip)
        {
            var res = await _printer.PrintTestSlipAsync(title, ip);
            if (res.Success)
            {
                Toast.Show(res.Message, ToastTone.Success);
            }
            else
            {
                Toast.Show(res.Message, ToastTone.Warning);
            }
        }

        private void OnSaveSettingsClick(object sender, RoutedEventArgs e)
        {
            _api.SetBaseUrl(ServerUrlBox.Text.Trim());
            _settings.ServerUrl = ServerUrlBox.Text.Trim();
            _settings.CashierName = CashierNameBox.Text.Trim();
            _settings.AutoPrintNetwork = AutoPrintCheck.IsChecked == true;

            _settings.Printers["kassa"] = IpKassaBox.Text.Trim();
            _settings.Printers["shashlik"] = IpShashlikBox.Text.Trim();
            _settings.Printers["somsa"] = IpSomsaBox.Text.Trim();
            _settings.Printers["kitchen"] = IpKitchenBox.Text.Trim();
            _settings.Printers["fastfood"] = IpFastfoodBox.Text.Trim();
            _settings.Printers["bar"] = IpBarBox.Text.Trim();

            if (ServiceFeeTypeCombo.SelectedItem is ComboBoxItem item && item.Tag is string feeType)
            {
                _settings.ServiceFeeType = feeType;
                if (decimal.TryParse(ServiceFeeValueBox.Text.Trim(), out decimal val))
                {
                    if (feeType == "percent") _settings.ServiceFeePercent = val;
                    else _settings.ServiceFeePerPerson = val;
                }
            }

            SidebarCashierNameText.Text = _settings.CashierName;
            LockCashierNameText.Text = _settings.CashierName;
            Toast.Show("Barcha sozlamalar saqlandi", ToastTone.Success);
        }
        #endregion

        #region Demo va Test Yordamchilari
        public void PrepareDemoMode()
        {
            _isDemoMode = true;
        }

        public void LoadDemoData()
        {
            _isDemoMode = true;
            var (depts, cats, prods, tbls, online, shift, setts) = Demo.DemoData.GetDemoDataset();
            _departments = depts;
            _categories = cats;
            _products = prods;
            _tables = tbls;
            _onlineOrders = online;
            _currentShift = shift;
            _settings = setts;
            _currentCart = Demo.DemoData.GetDemoCart();

            RenderTables();
            RenderCategories();
            RenderProducts();
            RenderStopList();
            RenderOnlineOrders();
            UpdateCartUI();
            UpdateShiftReportUI();
            ApplySettingsToUI();

            ApplySyncStatusUI(true, 0, _onlineOrders.Count, DateTime.Now);
            UpdateClockDisplay();
        }

        public void SetDemoSyncState(bool isOnline, int pendingCount)
        {
            ApplySyncStatusUI(isOnline, pendingCount, _onlineOrders.Count, DateTime.Now.AddMinutes(-2));
        }

        public void ShowDemoToast(string message, ToastTone tone, string? actionLabel = null)
        {
            MainToastHost.ShowToast(message, tone, actionLabel, actionLabel != null ? () => { } : null, autoHide: false);
        }

        public void ShowDemoScrim(bool visible)
        {
            ModalScrim.Visibility = visible ? Visibility.Visible : Visibility.Collapsed;
        }

        public void SetDemoTablesState(bool isLoading, bool forceEmpty)
        {
            _isLoadingTables = isLoading;
            if (forceEmpty)
            {
                _tableZoneSections.Clear();
            }
            else if (!isLoading && _tableZoneSections.Count == 0)
            {
                RenderTables();
            }
            UpdateTablesLoadingAndEmptyStates();
        }

        public void SwitchToTabPublic(string tag)
        {
            SwitchToTab(tag);
        }
        #endregion
    }
}
