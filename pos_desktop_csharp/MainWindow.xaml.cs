using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Threading;
using DilkashPos.Data;
using DilkashPos.Models;
using DilkashPos.Services;
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
        private string _activeTabTag = "tables";
        private bool _isDemoMode = false;

        public MainWindow()
        {
            InitializeComponent();

            _db = new LocalDatabase();
            _api = new ApiService("http://127.0.0.1:8000");
            _printer = new EscPosPrinterService();
            _syncEngine = new SyncEngine(_api, _db, _printer);

            _clockTimer = new DispatcherTimer { Interval = TimeSpan.FromSeconds(1) };
            _clockTimer.Tick += (s, e) =>
            {
                var now = DateTime.Now;
                ClockText.Text = now.ToString("HH:mm:ss");
                DateText.Text = now.ToString("dddd, d MMMM yyyy", new CultureInfo("uz-Latn-UZ"));
            };
            _clockTimer.Start();

            _syncEngine.SyncStatusUpdated += OnSyncStatusUpdated;
            _syncEngine.OnlineOrdersReceived += OnOnlineOrdersReceived;
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
            // 1. Lokal SQLite keshidan o'qish (Darhol yuklanadi)
            _products = await _db.GetCachedProductsAsync();
            _categories = await _db.GetCachedCategoriesAsync();
            _tables = await _db.GetCachedTablesAsync();

            if (_tables.Count == 0)
            {
                // Standart 12 ta stol (Zal, Terrasa, VIP)
                for (int i = 1; i <= 6; i++)
                    _tables.Add(new RestaurantTable { Number = i, Name = $"Stol #{i}", Zone = "Zal", Capacity = 4 });
                for (int i = 7; i <= 9; i++)
                    _tables.Add(new RestaurantTable { Number = i, Name = $"Terrasa #{i - 6}", Zone = "Terrasa", Capacity = 6 });
                for (int i = 10; i <= 12; i++)
                    _tables.Add(new RestaurantTable { Number = i, Name = $"VIP Xona #{i - 9}", Zone = "VIP", Capacity = 10 });
            }

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
                if (e.IsOnline)
                {
                    StatusBadgeBorder.Background = (Brush)FindResource("SuccessGreenBrush");
                    StatusBadgeText.Text = "● REST API ONLINE";
                }
                else
                {
                    StatusBadgeBorder.Background = (Brush)FindResource("DangerRedBrush");
                    StatusBadgeText.Text = "● OFFLINE (SQLITE KESH)";
                }

                if (e.PendingOfflineOrdersCount > 0)
                {
                    QueueBadgeBorder.Visibility = Visibility.Visible;
                    QueueBadgeText.Text = $"⏳ Navbat: {e.PendingOfflineOrdersCount} ta";
                }
                else
                {
                    QueueBadgeBorder.Visibility = Visibility.Collapsed;
                }

                NavOnlineBadgeText.Text = e.OnlineOrdersCount.ToString();
                NavOnlineBadgeBorder.Visibility = e.OnlineOrdersCount > 0 ? Visibility.Visible : Visibility.Collapsed;
            });
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
            if (sender is Button btn && btn.Tag is string tag)
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

            var activeBrush = (Brush)FindResource("BrandPrimaryBrush");
            var inactiveBrush = (Brush)FindResource("CardDarkBrush");

            NavTablesBtn.Background = tag == "tables" ? activeBrush : inactiveBrush;
            NavQuickPosBtn.Background = tag == "quick_pos" ? activeBrush : inactiveBrush;
            NavStopListBtn.Background = tag == "stop_list" ? activeBrush : inactiveBrush;
            NavOnlineBtn.Background = tag == "online" ? activeBrush : inactiveBrush;
            NavShiftBtn.Background = tag == "shift" ? activeBrush : inactiveBrush;
            NavSettingsBtn.Background = tag == "settings" ? activeBrush : inactiveBrush;

            if (tag == "quick_pos" && _activeTableContext == null)
            {
                _currentCart = new Order { ServiceType = "pickup" };
                CartTitleText.Text = "⚡ TEZKOR SABOY (OLIB KETISH)";
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
            var res = MessageBox.Show("Kassa ekranini qulflaysizmi?", "Kassani Qulflash", MessageBoxButton.YesNo, MessageBoxImage.Question);
            if (res == MessageBoxResult.Yes)
            {
                MessageBox.Show("Kassa qulflandi. Kassir parolini kiritib davom eting.", "Qulflangan", MessageBoxButton.OK, MessageBoxImage.Information);
            }
        }
        #endregion

        #region 1. Stollar Xaritasi (1920x1080 Full HD Tables Map)
        private void RenderTables()
        {
            TablesWrapPanel.Children.Clear();
            var list = _tables;

            if (_currentTableFilter == "zal") list = list.Where(t => t.Zone == "Zal").ToList();
            else if (_currentTableFilter == "terrasa") list = list.Where(t => t.Zone == "Terrasa").ToList();
            else if (_currentTableFilter == "vip") list = list.Where(t => t.Zone == "VIP").ToList();

            int emptyCount = _tables.Count(t => !t.IsOccupied && t.Status != "bill_printed");
            int occCount = _tables.Count(t => t.IsOccupied && t.Status != "bill_printed");
            int billCount = _tables.Count(t => t.Status == "bill_printed");

            EmptyTablesCountText.Text = emptyCount.ToString();
            OccupiedTablesCountText.Text = occCount.ToString();
            BillPrintedCountText.Text = billCount.ToString();
            NavTablesCountBadge.Text = $"{occCount} band";

            foreach (var tbl in list)
            {
                // Keng 380x215px stol kartasi (1920x1080 da 4 ta ustun hosil qiladi)
                var card = new Border
                {
                    Width = 380,
                    Height = 215,
                    Margin = new Thickness(10),
                    CornerRadius = new CornerRadius(14),
                    Background = tbl.IsOccupied 
                        ? new SolidColorBrush(Color.FromRgb(30, 41, 59)) // #1E293B
                        : new SolidColorBrush(Color.FromRgb(15, 27, 30)),
                    BorderThickness = new Thickness(2),
                    BorderBrush = tbl.Status == "bill_printed" ? (Brush)FindResource("AccentGoldBrush") :
                                 tbl.IsOccupied ? (Brush)FindResource("DangerRedBrush") : (Brush)FindResource("BrandPrimaryBrush"),
                    Padding = new Thickness(16),
                    Cursor = Cursors.Hand,
                    Tag = tbl
                };

                var grid = new Grid();
                grid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
                grid.RowDefinitions.Add(new RowDefinition { Height = new GridLength(1, GridUnitType.Star) });
                grid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });

                // 1. Qator: Stol nomi, Zonasi va Holat Pill
                var headerGrid = new Grid();
                var leftStack = new StackPanel { Orientation = Orientation.Horizontal };
                leftStack.Children.Add(new TextBlock { Text = tbl.Zone == "VIP" ? "👑 " : "🍽 ", FontSize = 20, VerticalAlignment = VerticalAlignment.Center });
                leftStack.Children.Add(new TextBlock { Text = tbl.Name, FontSize = 20, FontWeight = FontWeights.ExtraBold, Foreground = Brushes.White, VerticalAlignment = VerticalAlignment.Center });

                var zoneBorder = new Border
                {
                    Background = new SolidColorBrush(Color.FromRgb(51, 65, 85)),
                    CornerRadius = new CornerRadius(6),
                    Padding = new Thickness(8, 2, 8, 2),
                    Margin = new Thickness(10, 0, 0, 0),
                    VerticalAlignment = VerticalAlignment.Center
                };
                zoneBorder.Child = new TextBlock { Text = tbl.Zone, FontSize = 11, FontWeight = FontWeights.Bold, Foreground = Brushes.White };
                leftStack.Children.Add(zoneBorder);

                var badgeBorder = new Border
                {
                    HorizontalAlignment = HorizontalAlignment.Right,
                    CornerRadius = new CornerRadius(8),
                    Background = tbl.Status == "bill_printed" ? (Brush)FindResource("AccentGoldBrush") :
                                 tbl.IsOccupied ? (Brush)FindResource("DangerRedBrush") : (Brush)FindResource("SuccessGreenBrush"),
                    Padding = new Thickness(10, 4, 10, 4),
                    VerticalAlignment = VerticalAlignment.Center
                };
                badgeBorder.Child = new TextBlock { Text = tbl.StatusBadge, FontSize = 12, FontWeight = FontWeights.Black, Foreground = Brushes.White };

                headerGrid.Children.Add(leftStack);
                headerGrid.Children.Add(badgeBorder);
                Grid.SetRow(headerGrid, 0);

                // 2. Qator: Stol tanasi (Ma'lumotlar)
                var bodyStack = new StackPanel { VerticalAlignment = VerticalAlignment.Center, Margin = new Thickness(0, 10, 0, 10) };
                if (!tbl.IsOccupied)
                {
                    bodyStack.Children.Add(new TextBlock
                    {
                        Text = $"👥 Sig'imi: {tbl.Capacity} kishilik qulay stol",
                        FontSize = 14,
                        Foreground = new SolidColorBrush(Color.FromRgb(148, 163, 184))
                    });
                    bodyStack.Children.Add(new TextBlock
                    {
                        Text = "✨ Mehmonlarni kutib olishga to'liq tayyor",
                        FontSize = 13,
                        Foreground = new SolidColorBrush(Color.FromRgb(16, 185, 129)),
                        Margin = new Thickness(0, 4, 0, 0)
                    });
                }
                else
                {
                    string waiter = tbl.ActiveOrder?.WaiterName ?? tbl.AssignedWaiter ?? "Jasur";
                    int mins = tbl.ActiveOrder?.ElapsedMinutes ?? 0;
                    int itemsCount = tbl.ActiveOrder?.Items.Sum(i => i.Quantity) ?? 0;

                    var infoGrid = new Grid();
                    infoGrid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
                    infoGrid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });

                    var col1 = new StackPanel();
                    col1.Children.Add(new TextBlock { Text = $"👤 {tbl.GuestsCount} kishi (sig'im: {tbl.Capacity})", FontSize = 13, FontWeight = FontWeights.SemiBold, Foreground = Brushes.White });
                    col1.Children.Add(new TextBlock { Text = $"🤵 Ofitsiant: {waiter}", FontSize = 13, Foreground = new SolidColorBrush(Color.FromRgb(148, 163, 184)), Margin = new Thickness(0, 2, 0, 0) });

                    var col2 = new StackPanel();
                    col2.Children.Add(new TextBlock { Text = $"⏱ {mins} daqiqadan beri", FontSize = 13, FontWeight = FontWeights.Bold, Foreground = (Brush)FindResource("AccentGoldBrush") });
                    col2.Children.Add(new TextBlock { Text = $"🍲 {itemsCount} ta taom buyurtmada", FontSize = 13, Foreground = Brushes.White, Margin = new Thickness(0, 2, 0, 0) });

                    infoGrid.Children.Add(col1);
                    Grid.SetColumn(col2, 1);
                    infoGrid.Children.Add(col2);
                    bodyStack.Children.Add(infoGrid);
                }
                Grid.SetRow(bodyStack, 1);

                // 3. Qator: Jami summa va Katta sensorli amallar
                var footerGrid = new Grid();
                if (!tbl.IsOccupied)
                {
                    var openBtn = new Button
                    {
                        Content = "➕ STOLNI OCHISH",
                        Height = 44,
                        FontSize = 14,
                        FontWeight = FontWeights.Black,
                        Style = (Style)FindResource("TouchButtonStyle"),
                        Background = (Brush)FindResource("BrandPrimaryBrush"),
                        Tag = tbl
                    };
                    openBtn.Click += (s, e) => OnTableCardClicked((RestaurantTable)((Button)s).Tag);
                    footerGrid.Children.Add(openBtn);
                }
                else
                {
                    footerGrid.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
                    footerGrid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });

                    var sumStack = new StackPanel { VerticalAlignment = VerticalAlignment.Center };
                    sumStack.Children.Add(new TextBlock { Text = "HISOB SUMMASI:", FontSize = 10, FontWeight = FontWeights.Bold, Foreground = new SolidColorBrush(Color.FromRgb(148, 163, 184)) });
                    sumStack.Children.Add(new TextBlock { Text = tbl.TotalSumFormatted, FontSize = 20, FontWeight = FontWeights.Black, Foreground = (Brush)FindResource("SuccessGreenBrush") });
                    Grid.SetColumn(sumStack, 0);

                    var actionsStack = new StackPanel { Orientation = Orientation.Horizontal, HorizontalAlignment = HorizontalAlignment.Right, VerticalAlignment = VerticalAlignment.Center };

                    var addFoodBtn = new Button { Content = "📝 Taom", Height = 40, Padding = new Thickness(10, 0, 10, 0), FontSize = 12, FontWeight = FontWeights.Bold, Style = (Style)FindResource("TouchSecondaryButton"), Margin = new Thickness(0, 0, 6, 0), Tag = tbl };
                    var prechekBtn = new Button { Content = "📄 Pre-chek", Height = 40, Padding = new Thickness(10, 0, 10, 0), FontSize = 12, FontWeight = FontWeights.Bold, Style = (Style)FindResource("TouchGoldButton"), Margin = new Thickness(0, 0, 6, 0), Tag = tbl };
                    var payBtn = new Button { Content = "💳 To'lov", Height = 40, Padding = new Thickness(12, 0, 12, 0), FontSize = 12, FontWeight = FontWeights.Black, Style = (Style)FindResource("TouchButtonStyle"), Background = (Brush)FindResource("SuccessGreenBrush"), Tag = tbl };

                    addFoodBtn.Click += (s, e) => OpenTableOrderInQuickPos((RestaurantTable)((Button)s).Tag);
                    prechekBtn.Click += async (s, e) =>
                    {
                        var t = (RestaurantTable)((Button)s).Tag;
                        if (t.ActiveOrder != null && t.ActiveOrder.Items.Count > 0)
                        {
                            string kassaIp = IpKassaBox.Text.Trim();
                            await _printer.PrintPreChekAsync(t.ActiveOrder, kassaIp);
                            t.Status = "bill_printed";
                            RenderTables();
                            MessageBox.Show($"{t.Name} uchun hisob pre-cheki chiqarildi!", "Pre-Chek", MessageBoxButton.OK, MessageBoxImage.Information);
                        }
                    };
                    payBtn.Click += (s, e) =>
                    {
                        var t = (RestaurantTable)((Button)s).Tag;
                        OpenTableOrderInQuickPos(t);
                        OnPayCartClick(s, e);
                    };

                    actionsStack.Children.Add(addFoodBtn);
                    actionsStack.Children.Add(prechekBtn);
                    actionsStack.Children.Add(payBtn);
                    Grid.SetColumn(actionsStack, 1);

                    footerGrid.Children.Add(sumStack);
                    footerGrid.Children.Add(actionsStack);
                }
                Grid.SetRow(footerGrid, 2);

                grid.Children.Add(headerGrid);
                grid.Children.Add(bodyStack);
                grid.Children.Add(footerGrid);
                card.Child = grid;

                card.MouseLeftButtonUp += (s, e) =>
                {
                    // Agar tugma bosilmagan bo'lsa, stol kartasining o'zi bosilganda
                    if (e.OriginalSource is not Button)
                    {
                        OnTableCardClicked((RestaurantTable)((Border)s).Tag);
                    }
                };

                TablesWrapPanel.Children.Add(card);
            }
        }

        private async void OnTableCardClicked(RestaurantTable table)
        {
            if (!table.IsOccupied)
            {
                var dialog = new OpenTableDialog(table.Number, table.Name, _settings.CashierName);
                if (dialog.ShowDialog() == true)
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

                    RenderTables();
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

            CartTitleText.Text = $"🍽 {table.Name.ToUpper()} ({table.Zone})";
            CartSubtitleText.Text = $"Ofitsiant: {_currentCart.WaiterName} • Mehmon: {_currentCart.GuestsCount} kishi";
            SwitchToTab("quick_pos");
            UpdateCartUI();
        }

        private void OnTableFilterAll(object sender, RoutedEventArgs e) { _currentTableFilter = "all"; HighlightFilterBtn(FilterAllBtn); RenderTables(); }
        private void OnTableFilterZal(object sender, RoutedEventArgs e) { _currentTableFilter = "zal"; HighlightFilterBtn(FilterZalBtn); RenderTables(); }
        private void OnTableFilterTerrasa(object sender, RoutedEventArgs e) { _currentTableFilter = "terrasa"; HighlightFilterBtn(FilterTerrasaBtn); RenderTables(); }
        private void OnTableFilterVip(object sender, RoutedEventArgs e) { _currentTableFilter = "vip"; HighlightFilterBtn(FilterVipBtn); RenderTables(); }

        private void HighlightFilterBtn(Button active)
        {
            var secondaryBrush = (Brush)FindResource("CardDarkBrush");
            FilterAllBtn.Background = secondaryBrush;
            FilterZalBtn.Background = secondaryBrush;
            FilterTerrasaBtn.Background = secondaryBrush;
            FilterVipBtn.Background = secondaryBrush;
            active.Background = (Brush)FindResource("BrandPrimaryBrush");
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
                    if (dlg.ShowDialog() == true)
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
            if (dlg.ShowDialog() == true)
            {
                _currentCart.DiscountPercent = dlg.DiscountPercent;
                UpdateCartUI();
            }
        }

        private async void OnSendToKitchenClick(object sender, RoutedEventArgs e)
        {
            if (_currentCart.Items.Count == 0)
            {
                MessageBox.Show("Oshxonaga yuborish uchun savatchaga taom qo'shing!", "Ogohlantirish", MessageBoxButton.OK, MessageBoxImage.Warning);
                return;
            }

            await _api.CreateOrUpdateOrderAsync(_currentCart);
            await PrintOrderKitchenSlipsAsync(_currentCart);

            MessageBox.Show("Buyurtma barcha bo'lim printerlariga (Shashlik, Somsa, Oshxona, Fast-food, Bar) yuborildi!", "Oshxonaga Yuborildi", MessageBoxButton.OK, MessageBoxImage.Information);
        }

        private async void OnPrintPreChekClick(object sender, RoutedEventArgs e)
        {
            if (_currentCart.Items.Count == 0)
            {
                MessageBox.Show("Hisob cheki chiqarish uchun savatchaga taom qo'shing!", "Ogohlantirish", MessageBoxButton.OK, MessageBoxImage.Warning);
                return;
            }

            string kassaIp = IpKassaBox.Text.Trim();
            if (string.IsNullOrEmpty(kassaIp))
            {
                MessageBox.Show("Kassa printeri IP manzili kiritilmagan!", "Xatolik", MessageBoxButton.OK, MessageBoxImage.Warning);
                return;
            }

            var res = await _printer.PrintPreChekAsync(_currentCart, kassaIp);
            if (res.Success)
            {
                if (_activeTableContext != null)
                {
                    _activeTableContext.Status = "bill_printed";
                    RenderTables();
                }
                MessageBox.Show("Mijoz uchun hisob pre-cheki chop etildi!", "Pre-Chek", MessageBoxButton.OK, MessageBoxImage.Information);
            }
            else
            {
                MessageBox.Show(res.Message, "Printer Xatosi", MessageBoxButton.OK, MessageBoxImage.Warning);
            }
        }

        private async void OnPayCartClick(object sender, RoutedEventArgs e)
        {
            if (_currentCart.Items.Count == 0)
            {
                MessageBox.Show("Savatcha bo'sh! To'lov uchun taom tanlang.", "Ogohlantirish", MessageBoxButton.OK, MessageBoxImage.Information);
                return;
            }

            var dialog = new PaymentDialog(_currentCart.TotalAmount, _currentCart.OrderNumber ?? "YANGI", _currentCart.TableNumber, _currentCart.GuestsCount);
            if (dialog.ShowDialog() == true)
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
                    _activeTableContext.IsOccupied = false;
                    _activeTableContext.Status = "empty";
                    _activeTableContext.ActiveOrder = null;
                    _activeTableContext = null;
                    RenderTables();
                }

                _currentCart = new Order { ServiceType = "pickup" };
                CartTitleText.Text = "⚡ TEZKOR SABOY (OLIB KETISH)";
                CartSubtitleText.Text = "Kassir: " + _settings.CashierName;
                UpdateCartUI();
                RenderProducts();

                MessageBox.Show("To'lov muvaffaqiyatli qabul qilindi va kassa cheki chop etildi!", "To'lov Yakunlandi", MessageBoxButton.OK, MessageBoxImage.Information);
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
                    MessageBox.Show($"Buyurtma #{ord.OrderNumber} qabul qilindi va barcha oshxona bo'limlariga tarqatildi!", "Qabul Qilindi", MessageBoxButton.OK, MessageBoxImage.Information);
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
                MessageBox.Show("Kassa printeri IP manzili kiritilmagan!", "Xatolik", MessageBoxButton.OK, MessageBoxImage.Warning);
                return;
            }

            var res = await _printer.PrintShiftReportAsync(_currentShift, false, kassaIp);
            if (res.Success)
            {
                MessageBox.Show("Oraliq X-Hisobot kassa printerida chop etildi!", "X-Hisobot", MessageBoxButton.OK, MessageBoxImage.Information);
            }
            else
            {
                MessageBox.Show(res.Message, "Printer Xatosi", MessageBoxButton.OK, MessageBoxImage.Warning);
            }
        }

        private async void OnCloseShiftDirect(object sender, RoutedEventArgs e)
        {
            var conf = MessageBox.Show("Haqiqatan ham kassa smenasini yopib, Z-Hisobot chiqarmoqchimisiz?", "Smenani Yopish", MessageBoxButton.YesNo, MessageBoxImage.Question);
            if (conf == MessageBoxResult.Yes)
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
                MessageBox.Show("Kassa smenasi muvaffaqiyatli yopildi va Z-Hisobot chop etildi!", "Smena Yopildi", MessageBoxButton.OK, MessageBoxImage.Information);
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
                MessageBox.Show(res.Message, "Printer Tekshiruvi", MessageBoxButton.OK, MessageBoxImage.Information);
            }
            else
            {
                MessageBox.Show(res.Message, "Printer Tekshiruvi Xatosi", MessageBoxButton.OK, MessageBoxImage.Warning);
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
            MessageBox.Show("Barcha sozlamalar muvaffaqiyatli saqlandi!", "Sozlamalar", MessageBoxButton.OK, MessageBoxImage.Information);
        }
        #endregion

        #region Demo va Test Yordamchilari
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
        }

        public void SwitchToTabPublic(string tag)
        {
            SwitchToTab(tag);
        }
        #endregion
    }
}
