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
        private readonly ObservableCollection<CategoryChipVM> _categoryChips = new();
        private readonly ObservableCollection<ProductTileVM> _visibleProductTiles = new();
        private readonly Dictionary<int, ProductTileVM> _productTileMap = new();
        private readonly ObservableCollection<CartLineVM> _cartLines = new();
        private readonly ObservableCollection<StopListItemVM> _stopListVMs = new();
        private readonly ObservableCollection<OnlineOrderCardVM> _onlineOrderVMs = new();
        private readonly ObservableCollection<PrinterCardVM> _printerCardVMs = new();
        private string _stopListFilter = "all";
        private bool _isApplyingSettings = false;
        private bool _settingsDirty = false;
        private int _tableColumns = 4;
        private bool _isLoadingTables = false;
        private string _activeTabTag = "tables";
        private bool _isDemoMode = false;

        public static readonly DependencyProperty ProductColumnsProperty =
            DependencyProperty.Register(nameof(ProductColumns), typeof(int), typeof(MainWindow), new PropertyMetadata(4));

        public int ProductColumns
        {
            get => (int)GetValue(ProductColumnsProperty);
            set => SetValue(ProductColumnsProperty, value);
        }

        public static readonly DependencyProperty StopListColumnsProperty =
            DependencyProperty.Register(nameof(StopListColumns), typeof(int), typeof(MainWindow), new PropertyMetadata(3));

        public int StopListColumns
        {
            get => (int)GetValue(StopListColumnsProperty);
            set => SetValue(StopListColumnsProperty, value);
        }

        public MainWindow()
        {
            InitializeComponent();

            _db = new LocalDatabase();
            _api = new ApiService("http://127.0.0.1:8000");
            _printer = new EscPosPrinterService();
            _syncEngine = new SyncEngine(_api, _db, _printer);

            TableZonesItemsControl.ItemsSource = _tableZoneSections;
            CategoryChipsItemsControl.ItemsSource = _categoryChips;
            ProductsItemsControl.ItemsSource = _visibleProductTiles;
            CartLinesItemsControl.ItemsSource = _cartLines;
            StopListItemsControl.ItemsSource = _stopListVMs;
            OnlineOrdersItemsControl.ItemsSource = _onlineOrderVMs;
            PrintersItemsControl.ItemsSource = _printerCardVMs;

            Dialogs.RegisterScrimHandler(visible => ModalScrim.Visibility = visible ? Visibility.Visible : Visibility.Collapsed);
            Toast.RegisterHost(MainToastHost);

            UpdateClockDisplay();
            _clockTimer = new DispatcherTimer { Interval = TimeSpan.FromSeconds(1) };
            _clockTimer.Tick += (s, e) => UpdateClockDisplay();
            _clockTimer.Start();

            TopConnectionPill.Update(true, 0, DateTime.Now);

            _syncEngine.SyncStatusUpdated += OnSyncStatusUpdated;
            _syncEngine.OnlineOrdersReceived += OnOnlineOrdersReceived;

            UpdateThemeToggleVisuals(ThemeManager.IsDark);
            ThemeManager.ThemeChanged += OnThemeManagerChanged;
            Closed += (_, _) => ThemeManager.ThemeChanged -= OnThemeManagerChanged;
        }

        private void OnThemeManagerChanged(object? sender, bool isDark)
        {
            Dispatcher.Invoke(() => UpdateThemeToggleVisuals(isDark));
        }

        private void UpdateThemeToggleVisuals(bool isDark)
        {
            ThemeToggleIcon.Data = (Geometry)FindResource(isDark ? "IconSun" : "IconMoon");
            ThemeToggleText.Text = isDark ? "Kun" : "Tun";
        }

        private void OnToggleThemeClick(object sender, RoutedEventArgs e)
        {
            ThemeManager.Toggle();
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
            RailColumn.Width = new GridLength(84);
            CartColumn.Width = new GridLength(width >= 1550 ? 400 : 356);

            int newProductCols = width >= 2200 ? 6 : width >= 1800 ? 5 : width >= 1500 ? 4 : 3;
            if (newProductCols != ProductColumns)
            {
                ProductColumns = newProductCols;
            }

            int newStopCols = width >= 2200 ? 4 : width >= 1500 ? 3 : 2;
            if (newStopCols != StopListColumns)
            {
                StopListColumns = newStopCols;
                StopListLoadingGrid.Columns = newStopCols;
            }

            int newCols = width >= 2200 ? 5 : width >= 1500 ? 4 : 3;
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
            if (LockOverlay.Visibility == Visibility.Visible)
            {
                return;
            }

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
            ApplySettingsToUI();

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
                if (_currentCart.ServiceType != "pickup" && !_isDemoMode)
                {
                    _currentCart = new Order { ServiceType = "pickup" };
                }
                CartTitleText.Text = "Saboy";
                CartSubtitleText.Text = "Kassir: " + _settings.CashierName;
                SyncProductInCartQuantities();
                UpdateCartUI();
            }
            else if (tag == "quick_pos" && _activeTableContext != null)
            {
                CartTitleText.Text = $"{_activeTableContext.Name} · {_activeTableContext.Zone}";
                CartSubtitleText.Text = $"Ofitsiant: {_currentCart.WaiterName} · {_currentCart.GuestsCount} mehmon";
                SyncProductInCartQuantities();
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
                string kassaIp = GetPrinterIpForDept("kassa");
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
            SyncProductInCartQuantities();
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

        #region 2. Tezkor Savdo & Buyurtma Qabul Qilish (2-Column Responsive POS)
        private void RenderCategories()
        {
            _categoryChips.Clear();
            _categoryChips.Add(new CategoryChipVM(0, "Barchasi", "all", _products.Count, _selectedCategory == null));

            foreach (var cat in _categories)
            {
                int pCount = _products.Count(p => p.CategoryId == cat.Id);
                _categoryChips.Add(new CategoryChipVM(cat.Id, cat.Name, cat.Department, pCount, _selectedCategory?.Id == cat.Id));
            }
        }

        private void OnCategoryChipClicked(object sender, RoutedEventArgs e)
        {
            if (sender is RadioButton rb && rb.Tag is CategoryChipVM chip)
            {
                _selectedCategory = chip.Id == 0 ? null : _categories.FirstOrDefault(c => c.Id == chip.Id);
                foreach (var c in _categoryChips)
                {
                    c.IsSelected = c.Id == chip.Id;
                }
                RenderProducts(ProductSearchBox.Text);
            }
        }

        private void EnsureProductTileMap()
        {
            if (_productTileMap.Count == _products.Count && _products.All(p => _productTileMap.ContainsKey(p.Id)))
            {
                return;
            }

            _productTileMap.Clear();
            foreach (var prod in _products)
            {
                int inCartQty = _currentCart.Items.FirstOrDefault(i => i.ProductId == prod.Id)?.Quantity ?? 0;
                _productTileMap[prod.Id] = new ProductTileVM(prod, inCartQty);
            }
        }

        private void SyncProductInCartQuantities()
        {
            EnsureProductTileMap();
            foreach (var kv in _productTileMap)
            {
                int qty = _currentCart.Items.FirstOrDefault(i => i.ProductId == kv.Key)?.Quantity ?? 0;
                kv.Value.InCartQty = qty;
            }
        }

        private void SyncSingleProductTileQty(int productId)
        {
            if (_productTileMap.TryGetValue(productId, out var tile))
            {
                tile.InCartQty = _currentCart.Items.FirstOrDefault(i => i.ProductId == productId)?.Quantity ?? 0;
            }
        }

        private void RenderProducts(string? query = null)
        {
            EnsureProductTileMap();
            _visibleProductTiles.Clear();

            IEnumerable<Product> list = _products;
            if (_selectedCategory != null)
                list = list.Where(p => p.CategoryId == _selectedCategory.Id);

            if (!string.IsNullOrWhiteSpace(query))
                list = list.Where(p => p.Name.Contains(query, StringComparison.OrdinalIgnoreCase));

            foreach (var prod in list)
            {
                if (_productTileMap.TryGetValue(prod.Id, out var vm))
                {
                    int qty = _currentCart.Items.FirstOrDefault(i => i.ProductId == prod.Id)?.Quantity ?? 0;
                    vm.InCartQty = qty;
                    vm.SyncAvailabilityFromModel();
                    _visibleProductTiles.Add(vm);
                }
            }

            bool isEmpty = _visibleProductTiles.Count == 0;
            ProductsScrollViewer.Visibility = isEmpty ? Visibility.Collapsed : Visibility.Visible;
            ProductsEmptyState.Visibility = isEmpty ? Visibility.Visible : Visibility.Collapsed;
        }

        private void OnProductTileClicked(object? sender, ProductTileVM tile)
        {
            AddProductToCart(tile.Model);
        }

        private void AddProductToCart(Product prod)
        {
            var existing = _currentCart.Items.FirstOrDefault(i => i.ProductId == prod.Id);
            if (existing != null)
            {
                existing.Quantity++;
                var lineVm = _cartLines.FirstOrDefault(l => l.ProductId == prod.Id);
                lineVm?.SyncFromModel();
            }
            else
            {
                var newItem = new OrderItem
                {
                    ProductId = prod.Id,
                    ProductName = prod.Name,
                    Price = prod.Price,
                    Quantity = 1,
                    Department = prod.Department,
                    CategoryName = prod.CategoryName
                };
                _currentCart.Items.Add(newItem);
                _cartLines.Add(new CartLineVM(newItem));
            }

            // Update ONLY the tapped tile without rebuilding the product grid!
            SyncSingleProductTileQty(prod.Id);
            RecalculateAndDisplayCartSummary();
        }

        private void OnCartLineIncrement(object? sender, CartLineVM line)
        {
            line.Quantity++;
            SyncSingleProductTileQty(line.ProductId);
            RecalculateAndDisplayCartSummary();
        }

        private void OnCartLineDecrement(object? sender, CartLineVM line)
        {
            if (line.Quantity > 1)
            {
                line.Quantity--;
            }
            else
            {
                _currentCart.Items.Remove(line.Model);
                _cartLines.Remove(line);
            }

            SyncSingleProductTileQty(line.ProductId);
            RecalculateAndDisplayCartSummary();
        }

        private void OnCartLineEditNote(object? sender, CartLineVM line)
        {
            var dlg = new ItemModifierDialog(line.ProductName, line.Notes);
            if (Dialogs.ShowModal(dlg, this) == true)
            {
                line.Notes = dlg.Notes;
            }
        }

        private void UpdateCartUI()
        {
            _cartLines.Clear();
            foreach (var item in _currentCart.Items)
            {
                _cartLines.Add(new CartLineVM(item));
            }

            RecalculateAndDisplayCartSummary();
        }

        private void RecalculateAndDisplayCartSummary()
        {
            bool hasLines = _cartLines.Count > 0;
            CartLinesScrollViewer.Visibility = hasLines ? Visibility.Visible : Visibility.Collapsed;
            CartEmptyHint.Visibility = hasLines ? Visibility.Collapsed : Visibility.Visible;

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

            CartSubtotalText.Text = MoneyFormatter.Format(subtotal);
            DiscountBtnLabelText.Text = $"Chegirma: {_currentCart.DiscountPercent:0}%";
            CartDiscountText.Text = MoneyFormatter.FormatDiscount(_currentCart.DiscountAmount);
            ServiceFeeLabelText.Text = $"Xizmat haqi ({(_settings.ServiceFeeType == "percent" ? $"{_settings.ServiceFeePercent:0}%" : "Odam boshiga")})";
            CartServiceFeeText.Text = MoneyFormatter.Format(serviceFee);
            CartTotalText.Text = MoneyFormatter.Format(_currentCart.TotalAmount);
            PayButtonText.Text = $"Toʻlov · {MoneyFormatter.Format(_currentCart.TotalAmount)}";
        }

        private void OnDiscountPillClick(object sender, RoutedEventArgs e)
        {
            var dlg = new DiscountDialog(_currentCart.DiscountPercent, _currentCart.ProductsTotal);
            if (Dialogs.ShowModal(dlg, this) == true)
            {
                _currentCart.DiscountPercent = dlg.DiscountPercent;
                RecalculateAndDisplayCartSummary();
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

            string kassaIp = GetPrinterIpForDept("kassa");
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
                string kassaIp = GetPrinterIpForDept("kassa");
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
                CartTitleText.Text = "Saboy";
                CartSubtitleText.Text = "Kassir: " + _settings.CashierName;
                SyncProductInCartQuantities();
                UpdateCartUI();

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
            string code = (dept ?? "").ToLowerInvariant() switch
            {
                "kassa" => "kassa",
                "shashlik" => "shashlik",
                "somsa" => "somsa",
                "kitchen" => "kitchen",
                "fastfood" => "fastfood",
                "bar" => "bar",
                _ => "kitchen"
            };

            var card = _printerCardVMs.FirstOrDefault(p => string.Equals(p.Code, code, StringComparison.OrdinalIgnoreCase));
            if (card != null)
            {
                return (card.PrinterIp ?? "").Trim();
            }

            return _settings.Printers.TryGetValue(code, out var ip) ? (ip ?? "").Trim() : "";
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
            SyncProductInCartQuantities();
            UpdateCartUI();
        }

        private void OnProductSearchChanged(object sender, TextChangedEventArgs e)
        {
            RenderProducts(ProductSearchBox.Text);
        }

        private void OnResetProductFilter(object? sender, EventArgs e)
        {
            _selectedCategory = null;
            foreach (var c in _categoryChips)
            {
                c.IsSelected = c.Id == 0;
            }
            ProductSearchBox.Text = "";
            RenderProducts();
        }
        #endregion

        #region 3. Stop-List Boshqaruvi
        private void UpdateStopListCountsAndBadge()
        {
            int total = _products.Count;
            int stopped = _products.Count(p => !p.IsAvailable);
            int available = total - stopped;

            StopFilterAllBtn.Content = $"Hammasi ({total})";
            StopFilterAvailableBtn.Content = $"Mavjud ({available})";
            StopFilterStoppedBtn.Content = $"Stop-listda ({stopped})";

            NavStopListCountBadge.Text = stopped.ToString();
            NavStopListBadgeBorder.Visibility = stopped > 0 ? Visibility.Visible : Visibility.Collapsed;
        }

        private void UpdateStopListVisualStates(bool isLoading)
        {
            if (isLoading)
            {
                StopListLoadingGrid.Visibility = Visibility.Visible;
                StopListScrollViewer.Visibility = Visibility.Collapsed;
                StopListEmptyState.Visibility = Visibility.Collapsed;
            }
            else if (_stopListVMs.Count == 0)
            {
                StopListLoadingGrid.Visibility = Visibility.Collapsed;
                StopListScrollViewer.Visibility = Visibility.Collapsed;
                StopListEmptyState.Visibility = Visibility.Visible;
            }
            else
            {
                StopListLoadingGrid.Visibility = Visibility.Collapsed;
                StopListScrollViewer.Visibility = Visibility.Visible;
                StopListEmptyState.Visibility = Visibility.Collapsed;
            }
        }

        private void RenderStopList(string? query = null)
        {
            query ??= StopListSearchBox?.Text;
            UpdateStopListCountsAndBadge();

            IEnumerable<Product> filtered = _products;
            if (_stopListFilter == "available")
            {
                filtered = filtered.Where(p => p.IsAvailable);
            }
            else if (_stopListFilter == "stopped")
            {
                filtered = filtered.Where(p => !p.IsAvailable);
            }

            if (!string.IsNullOrWhiteSpace(query))
            {
                string q = query.Trim();
                filtered = filtered.Where(p =>
                    p.Name.Contains(q, StringComparison.OrdinalIgnoreCase) ||
                    p.CategoryName.Contains(q, StringComparison.OrdinalIgnoreCase));
            }

            _stopListVMs.Clear();
            foreach (var prod in filtered)
            {
                _stopListVMs.Add(new StopListItemVM(prod));
            }

            UpdateStopListVisualStates(isLoading: false);
        }

        private void OnStopListSearchChanged(object sender, TextChangedEventArgs e)
        {
            RenderStopList(StopListSearchBox.Text);
        }

        private void OnStopListFilterClick(object sender, RoutedEventArgs e)
        {
            if (sender is RadioButton rb && rb.Tag is string filter)
            {
                _stopListFilter = filter;
                RenderStopList(StopListSearchBox.Text);
            }
        }

        private async void OnStopListToggleClicked(object sender, RoutedEventArgs e)
        {
            if (sender is CheckBox cb && cb.Tag is StopListItemVM vm)
            {
                bool newAvail = cb.IsChecked == true;
                vm.IsAvailable = newAvail;
                var p = vm.Model;

                await _db.UpdateProductAvailabilityAsync(p.Id, newAvail);
                await _api.ToggleStopListAsync(p.Id, newAvail);

                if (_productTileMap.TryGetValue(p.Id, out var tile))
                {
                    tile.SyncAvailabilityFromModel();
                }

                if (_stopListFilter != "all")
                {
                    RenderStopList(StopListSearchBox.Text);
                }
                else
                {
                    UpdateStopListCountsAndBadge();
                }
            }
        }

        private void OnResetStopListFilter(object? sender, EventArgs e)
        {
            _stopListFilter = "all";
            StopFilterAllBtn.IsChecked = true;
            StopListSearchBox.Text = "";
            RenderStopList();
        }
        #endregion

        #region 4. Online Buyurtmalar (Live Kitchen Dispatcher)
        private void UpdateOnlineVisualStates(bool isLoading)
        {
            if (isLoading)
            {
                OnlineLoadingStack.Visibility = Visibility.Visible;
                OnlineScrollViewer.Visibility = Visibility.Collapsed;
                OnlineEmptyState.Visibility = Visibility.Collapsed;
            }
            else if (_onlineOrderVMs.Count == 0)
            {
                OnlineLoadingStack.Visibility = Visibility.Collapsed;
                OnlineScrollViewer.Visibility = Visibility.Collapsed;
                OnlineEmptyState.Visibility = Visibility.Visible;
            }
            else
            {
                OnlineLoadingStack.Visibility = Visibility.Collapsed;
                OnlineScrollViewer.Visibility = Visibility.Visible;
                OnlineEmptyState.Visibility = Visibility.Collapsed;
            }
        }

        private void RenderOnlineOrders()
        {
            _onlineOrderVMs.Clear();
            foreach (var order in _onlineOrders)
            {
                _onlineOrderVMs.Add(new OnlineOrderCardVM(order));
            }

            NavOnlineBadgeText.Text = _onlineOrders.Count.ToString();
            NavOnlineBadgeBorder.Visibility = _onlineOrders.Count > 0 ? Visibility.Visible : Visibility.Collapsed;

            UpdateOnlineVisualStates(isLoading: false);
        }

        private async void OnAcceptOnlineOrderClicked(object? sender, OnlineOrderCardVM vm)
        {
            var ord = vm.Model;
            await PrintOrderKitchenSlipsAsync(ord);
            string kassaIp = GetPrinterIpForDept("kassa");
            if (!string.IsNullOrEmpty(kassaIp))
            {
                await _printer.PrintKassaReceiptAsync(ord, kassaIp, ord.TotalAmount, 0, 0);
            }

            _onlineOrders.Remove(ord);
            RenderOnlineOrders();
            Toast.Show($"Buyurtma #{ord.OrderNumber} qabul qilindi va boʻlimlarga yuborildi", ToastTone.Success);
        }

        private async void OnRefreshOnlineOrdersClick(object sender, RoutedEventArgs e)
        {
            UpdateOnlineVisualStates(isLoading: true);
            _onlineOrders = await _api.GetOnlineOrdersAsync();
            RenderOnlineOrders();
        }

        private void OnRefreshOnlineOrdersEmptyAction(object? sender, EventArgs e)
        {
            OnRefreshOnlineOrdersClick(this, new RoutedEventArgs());
        }
        #endregion

        #region 5. Smena va Z-Hisobot (Analytics & Shift Management)
        private void UpdateShiftVisualStates(bool isLoading)
        {
            if (isLoading)
            {
                ShiftLoadingState.Visibility = Visibility.Visible;
                ShiftContentGrid.Visibility = Visibility.Collapsed;
                ShiftEmptyState.Visibility = Visibility.Collapsed;
            }
            else if (_currentShift.TotalOrdersCount == 0 && _currentShift.TotalRevenue == 0)
            {
                ShiftLoadingState.Visibility = Visibility.Collapsed;
                ShiftContentGrid.Visibility = Visibility.Collapsed;
                ShiftEmptyState.Visibility = Visibility.Visible;
            }
            else
            {
                ShiftLoadingState.Visibility = Visibility.Collapsed;
                ShiftContentGrid.Visibility = Visibility.Visible;
                ShiftEmptyState.Visibility = Visibility.Collapsed;
            }
        }

        private void UpdateShiftReportUI()
        {
            string cashier = string.IsNullOrWhiteSpace(_settings.CashierName) ? _currentShift.CashierName : _settings.CashierName;
            var openedAt = _currentShift.OpenedAt == default ? DateTime.Today.AddHours(8).AddMinutes(30) : _currentShift.OpenedAt;

            SidebarCashierNameText.Text = cashier;
            ShiftHeaderInfoText.Text = $"Smena ochiq · {openedAt:HH:mm} dan · Kassir: {cashier}";

            ShiftTotalRevenueText.Text = MoneyFormatter.Format(_currentShift.TotalRevenue);
            KpiCashCard.Value = MoneyFormatter.Format(_currentShift.CashRevenue);
            KpiCardCard.Value = MoneyFormatter.Format(_currentShift.CardRevenue);
            KpiOnlineCard.Value = MoneyFormatter.Format(_currentShift.OnlineRevenue);

            ShiftOrdersCountText.Text = $"{_currentShift.TotalOrdersCount} ta";
            ShiftServiceFeeText.Text = MoneyFormatter.Format(_currentShift.ServiceFeesCollected);
            ShiftDiscountsText.Text = MoneyFormatter.Format(_currentShift.DiscountsGiven);

            decimal avgCheck = _currentShift.TotalOrdersCount > 0
                ? Math.Round(_currentShift.TotalRevenue / _currentShift.TotalOrdersCount, 0)
                : 0m;
            ShiftAvgCheckText.Text = MoneyFormatter.Format(avgCheck);

            decimal payTotal = _currentShift.CashRevenue + _currentShift.CardRevenue + _currentShift.OnlineRevenue;
            if (payTotal > 0)
            {
                int cashPct = (int)Math.Round(_currentShift.CashRevenue * 100m / payTotal);
                int cardPct = (int)Math.Round(_currentShift.CardRevenue * 100m / payTotal);
                int onlinePct = Math.Max(0, 100 - cashPct - cardPct);
                ShiftPaymentMixLabel.Text = $"Naqd {cashPct}% · Karta {cardPct}% · Onlayn {onlinePct}%";
                ShiftCashShareCol.Width = new GridLength(Math.Max(0.5, (double)_currentShift.CashRevenue), GridUnitType.Star);
                ShiftCardShareCol.Width = new GridLength(Math.Max(0.5, (double)_currentShift.CardRevenue), GridUnitType.Star);
                ShiftOnlineShareCol.Width = new GridLength(Math.Max(0.5, (double)_currentShift.OnlineRevenue), GridUnitType.Star);
            }
            else
            {
                ShiftPaymentMixLabel.Text = "Naqd 0% · Karta 0% · Onlayn 0%";
                ShiftCashShareCol.Width = new GridLength(1, GridUnitType.Star);
                ShiftCardShareCol.Width = new GridLength(1, GridUnitType.Star);
                ShiftOnlineShareCol.Width = new GridLength(1, GridUnitType.Star);
            }

            ShiftDineInText.Text = MoneyFormatter.Format(_currentShift.DineInRevenue);
            ShiftTakeawayText.Text = MoneyFormatter.Format(_currentShift.TakeawayRevenue);

            UpdateShiftVisualStates(isLoading: false);
            UpdateClockDisplay();
        }

        private async void OnPrintXReportDirect(object sender, RoutedEventArgs e)
        {
            string kassaIp = GetPrinterIpForDept("kassa");
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
                string kassaIp = GetPrinterIpForDept("kassa");
                if (!string.IsNullOrEmpty(kassaIp))
                {
                    await _printer.PrintShiftReportAsync(_currentShift, true, kassaIp);
                }

                // Smena maʼlumotlarini nolga tushirish
                _currentShift.TotalOrdersCount = 0;
                _currentShift.TotalRevenue = 0;
                _currentShift.CashRevenue = 0;
                _currentShift.CardRevenue = 0;
                _currentShift.OnlineRevenue = 0;
                _currentShift.DineInRevenue = 0;
                _currentShift.TakeawayRevenue = 0;
                _currentShift.ServiceFeesCollected = 0;
                _currentShift.DiscountsGiven = 0;

                UpdateShiftReportUI();
                Toast.Show("Kassa smenasi yopildi va Z-hisobot chop etildi", ToastTone.Success);
            }
        }

        private void OnShiftEmptyAction(object? sender, EventArgs e)
        {
            SwitchToTab("quick_pos");
        }
        #endregion

        #region 6. Printerlar va Sozlamalar
        private void UpdateSettingsVisualStates(bool isLoading)
        {
            SettingsLoadingState.Visibility = isLoading ? Visibility.Visible : Visibility.Collapsed;
            SettingsScrollViewer.Visibility = isLoading ? Visibility.Collapsed : Visibility.Visible;
            SettingsDirtyBar.Visibility = (!isLoading && _settingsDirty) ? Visibility.Visible : Visibility.Collapsed;
        }

        private void SetSettingsDirty(bool dirty)
        {
            _settingsDirty = dirty;
            if (SettingsDirtyBar != null && SettingsLoadingState != null)
            {
                SettingsDirtyBar.Visibility = (dirty && SettingsLoadingState.Visibility != Visibility.Visible)
                    ? Visibility.Visible
                    : Visibility.Collapsed;
            }
        }

        private void MarkSettingsDirty()
        {
            if (_isApplyingSettings || !IsLoaded)
            {
                return;
            }
            SetSettingsDirty(true);
        }

        private void ApplySettingsToUI()
        {
            _isApplyingSettings = true;
            try
            {
                _printerCardVMs.Clear();
                var defaults = new (string Code, string Name, string Subtitle, string Icon)[]
                {
                    ("kassa", "Kassa hisob printeri", "Mijoz cheki, X/Z hisobot", "receipt"),
                    ("shashlik", "Shashlikxona", "Mangal boʻlimi", "grill"),
                    ("somsa", "Somsaxona", "Tandir boʻlimi", "chef"),
                    ("kitchen", "Issiq oshxona", "Milliy issiq taomlar", "bowl"),
                    ("fastfood", "Fast-food", "Burger va lavash", "burger"),
                    ("bar", "Bar va ichimliklar", "Choy, qahva, desertlar", "coffee")
                };

                foreach (var def in defaults)
                {
                    var dept = _departments.FirstOrDefault(d => string.Equals(d.Code, def.Code, StringComparison.OrdinalIgnoreCase));
                    string ip = _settings.Printers.TryGetValue(def.Code, out var savedIp) && !string.IsNullOrWhiteSpace(savedIp)
                        ? savedIp
                        : (dept?.PrinterIp ?? "");
                    bool isOnline = dept?.IsOnline ?? !string.IsNullOrWhiteSpace(ip);
                    string name = !string.IsNullOrWhiteSpace(dept?.Name) ? dept!.Name : def.Name;
                    string subtitle = !string.IsNullOrWhiteSpace(dept?.Subtitle) ? dept!.Subtitle : def.Subtitle;
                    string icon = !string.IsNullOrWhiteSpace(dept?.Icon) ? dept!.Icon : def.Icon;

                    _printerCardVMs.Add(new PrinterCardVM(def.Code, name, subtitle, icon, ip, isOnline));
                }

                foreach (var obj in ServiceFeeTypeCombo.Items)
                {
                    if (obj is ComboBoxItem cbi && string.Equals(cbi.Tag as string, _settings.ServiceFeeType, StringComparison.OrdinalIgnoreCase))
                    {
                        ServiceFeeTypeCombo.SelectedItem = cbi;
                        break;
                    }
                }

                ServiceFeeValueBox.Text = _settings.ServiceFeeType == "per_person"
                    ? _settings.ServiceFeePerPerson.ToString("0")
                    : _settings.ServiceFeeType == "none"
                        ? "0"
                        : _settings.ServiceFeePercent.ToString("0");
                ServiceFeeValueBox.IsEnabled = _settings.ServiceFeeType != "none";

                ServerUrlBox.Text = _settings.ServerUrl;
                CashierNameBox.Text = _settings.CashierName;
                SidebarCashierNameText.Text = _settings.CashierName;
                LockCashierNameText.Text = _settings.CashierName;
                AutoPrintCheck.IsChecked = _settings.AutoPrintNetwork;

                SetSettingsDirty(false);
                UpdateSettingsVisualStates(isLoading: false);
            }
            finally
            {
                _isApplyingSettings = false;
            }
        }

        private async void OnPrinterCardTestClick(object? sender, PrinterCardVM vm)
        {
            await TestPrintAsync(vm.Name, vm.PrinterIp);
        }

        private void OnSettingsInputChanged(object? sender, EventArgs e)
        {
            MarkSettingsDirty();
        }

        private void OnSettingsCheckChanged(object sender, RoutedEventArgs e)
        {
            MarkSettingsDirty();
        }

        private void OnSettingsTextChanged(object sender, TextChangedEventArgs e)
        {
            if (sender is TextBox tb && !tb.IsKeyboardFocusWithin) return;
            MarkSettingsDirty();
        }

        private void OnSettingsComboChanged(object sender, SelectionChangedEventArgs e)
        {
            if (ServiceFeeValueBox != null && ServiceFeeTypeCombo.SelectedItem is ComboBoxItem item && item.Tag is string tag)
            {
                ServiceFeeValueBox.IsEnabled = tag != "none";
            }
            if (sender is ComboBox cb && !cb.IsDropDownOpen && !cb.IsKeyboardFocusWithin) return;
            MarkSettingsDirty();
        }

        private void OnDiscardSettingsClick(object sender, RoutedEventArgs e)
        {
            ApplySettingsToUI();
            Toast.Show("Oʻzgarishlar bekor qilindi", ToastTone.Info);
        }

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

            foreach (var card in _printerCardVMs)
            {
                _settings.Printers[card.Code] = (card.PrinterIp ?? "").Trim();
            }

            if (ServiceFeeTypeCombo.SelectedItem is ComboBoxItem item && item.Tag is string feeType)
            {
                _settings.ServiceFeeType = feeType;
                if (decimal.TryParse(ServiceFeeValueBox.Text.Trim(), out decimal val))
                {
                    if (feeType == "percent") _settings.ServiceFeePercent = val;
                    else if (feeType == "per_person") _settings.ServiceFeePerPerson = val;
                }
            }

            SidebarCashierNameText.Text = _settings.CashierName;
            LockCashierNameText.Text = _settings.CashierName;
            UpdateShiftReportUI();
            UpdateCartUI();
            SetSettingsDirty(false);
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
            _activeTableContext = _tables.FirstOrDefault(t => t.Number.ToString() == _currentCart.TableNumber);

            _stopListFilter = "all";
            StopFilterAllBtn.IsChecked = true;
            StopListSearchBox.Text = "";

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

        public void SetDemoQuickPosEmpty(bool empty)
        {
            if (empty)
            {
                ProductSearchBox.Text = "Mavjud boʻlmagan taom";
                RenderProducts(ProductSearchBox.Text);
            }
            else
            {
                ProductSearchBox.Text = "";
                RenderProducts();
            }
        }

        public void SetDemoStopListState(bool isLoading, bool forceEmpty)
        {
            if (isLoading)
            {
                UpdateStopListVisualStates(isLoading: true);
            }
            else if (forceEmpty)
            {
                _stopListVMs.Clear();
                UpdateStopListVisualStates(isLoading: false);
            }
            else
            {
                RenderStopList(StopListSearchBox.Text);
            }
        }

        public void SetDemoOnlineState(bool isLoading, bool forceEmpty)
        {
            if (isLoading)
            {
                UpdateOnlineVisualStates(isLoading: true);
            }
            else if (forceEmpty)
            {
                _onlineOrderVMs.Clear();
                UpdateOnlineVisualStates(isLoading: false);
            }
            else
            {
                RenderOnlineOrders();
            }
        }

        public void SetDemoShiftState(bool isLoading, bool forceEmpty)
        {
            if (isLoading)
            {
                UpdateShiftVisualStates(isLoading: true);
            }
            else if (forceEmpty)
            {
                ShiftLoadingState.Visibility = Visibility.Collapsed;
                ShiftContentGrid.Visibility = Visibility.Collapsed;
                ShiftEmptyState.Visibility = Visibility.Visible;
            }
            else
            {
                UpdateShiftReportUI();
            }
        }

        public void SetDemoSettingsState(bool isLoading, bool forceDirty)
        {
            UpdateSettingsVisualStates(isLoading);
            if (!isLoading)
            {
                if (forceDirty)
                {
                    _isApplyingSettings = true;
                    CashierNameBox.Text = "Jasur Rahimov (Tahrir)";
                    _isApplyingSettings = false;
                    SetSettingsDirty(true);
                }
                else
                {
                    ApplySettingsToUI();
                }
            }
        }

        public void SwitchToTabPublic(string tag)
        {
            SwitchToTab(tag);
        }

        public void SetDemoTheme(bool isDark)
        {
            ThemeManager.ApplyTheme(isDark);
            UpdateThemeToggleVisuals(isDark);
        }
        #endregion
    }
}
