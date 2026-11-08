using System;
using System.Collections.Generic;
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
        private readonly ShiftReport _currentShift = new();

        // Savatcha va Tanlangan elementlar
        private Order _currentCart = new() { ServiceType = "pickup" };
        private Category? _selectedCategory;
        private RestaurantTable? _activeTableContext;
        private string _currentTableFilter = "all";

        public MainWindow()
        {
            InitializeComponent();

            _db = new LocalDatabase();
            _api = new ApiService("http://127.0.0.1:8000");
            _printer = new EscPosPrinterService();
            _syncEngine = new SyncEngine(_api, _db, _printer);

            _clockTimer = new DispatcherTimer { Interval = TimeSpan.FromSeconds(1) };
            _clockTimer.Tick += (s, e) => ClockText.Text = DateTime.Now.ToString("HH:mm:ss");
            _clockTimer.Start();

            _syncEngine.SyncStatusUpdated += OnSyncStatusUpdated;
            _syncEngine.OnlineOrdersReceived += OnOnlineOrdersReceived;
        }

        private async void OnWindowLoaded(object sender, RoutedEventArgs e)
        {
            await LoadDataAsync();
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
                    StatusBadgeText.Text = "● ONLINE (REST API)";
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

                NavOnlineBtn.Content = e.OnlineOrdersCount > 0
                    ? $"📲 ONLINE BUYURTMALAR ({e.OnlineOrdersCount})"
                    : "📲 ONLINE BUYURTMALAR";
            });
        }

        private void OnOnlineOrdersReceived(object? sender, List<Order> orders)
        {
            Dispatcher.Invoke(() =>
            {
                _onlineOrders = orders;
                RenderOnlineOrders();
            });
        }

        #region Navigatsiya va Kiosk
        private void OnNavClicked(object sender, RoutedEventArgs e)
        {
            if (sender is Button btn && btn.Tag is string tag)
            {
                TablesTab.Visibility = tag == "tables" ? Visibility.Visible : Visibility.Collapsed;
                QuickPosTab.Visibility = tag == "quick_pos" ? Visibility.Visible : Visibility.Collapsed;
                StopListTab.Visibility = tag == "stop_list" ? Visibility.Visible : Visibility.Collapsed;
                OnlineTab.Visibility = tag == "online" ? Visibility.Visible : Visibility.Collapsed;
                SettingsTab.Visibility = tag == "settings" ? Visibility.Visible : Visibility.Collapsed;

                NavTablesBtn.Background = tag == "tables" ? (Brush)FindResource("BrandPrimaryBrush") : (Brush)FindResource("CardDarkBrush");
                NavQuickPosBtn.Background = tag == "quick_pos" ? (Brush)FindResource("BrandPrimaryBrush") : (Brush)FindResource("CardDarkBrush");
                NavStopListBtn.Background = tag == "stop_list" ? (Brush)FindResource("BrandPrimaryBrush") : (Brush)FindResource("CardDarkBrush");
                NavOnlineBtn.Background = tag == "online" ? (Brush)FindResource("BrandPrimaryBrush") : (Brush)FindResource("CardDarkBrush");
                NavSettingsBtn.Background = tag == "settings" ? (Brush)FindResource("BrandPrimaryBrush") : (Brush)FindResource("CardDarkBrush");

                if (tag == "quick_pos" && _activeTableContext == null)
                {
                    _currentCart = new Order { ServiceType = "pickup" };
                    CartTitleText.Text = "TEZKOR SABOY (OLIB KETISH)";
                    CartSubtitleText.Text = "Kassir: " + _settings.CashierName;
                    UpdateCartUI();
                }
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

        private void OnShiftReportClick(object sender, RoutedEventArgs e)
        {
            string kassaIp = IpKassaBox.Text.Trim();
            var dlg = new ShiftReportDialog(_currentShift, _printer, kassaIp);
            dlg.ShowDialog();
        }
        #endregion

        #region 1. Stollar Xaritasi (Tables Map)
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

            foreach (var tbl in list)
            {
                var card = new Border
                {
                    Width = 230,
                    Height = 175,
                    Margin = new Thickness(8),
                    CornerRadius = new CornerRadius(12),
                    Background = tbl.IsOccupied ? (Brush)FindResource("CardDarkBrush") : new SolidColorBrush(Color.FromRgb(15, 30, 25)),
                    BorderThickness = new Thickness(2),
                    BorderBrush = tbl.Status == "bill_printed" ? (Brush)FindResource("AccentGoldBrush") :
                                 tbl.IsOccupied ? (Brush)FindResource("DangerRedBrush") : (Brush)FindResource("BrandPrimaryBrush"),
                    Padding = new Thickness(14),
                    Cursor = Cursors.Hand,
                    Tag = tbl
                };

                var grid = new Grid();
                grid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
                grid.RowDefinitions.Add(new RowDefinition { Height = new GridLength(1, GridUnitType.Star) });
                grid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });

                // 1. Qator: Stol nomi va Holat Badge
                var headerGrid = new Grid();
                var nameStack = new StackPanel { Orientation = Orientation.Horizontal };
                nameStack.Children.Add(new TextBlock { Text = tbl.Zone == "VIP" ? "👑 " : "🍽 ", FontSize = 16 });
                nameStack.Children.Add(new TextBlock { Text = tbl.Name, FontSize = 17, FontWeight = FontWeights.ExtraBold, Foreground = Brushes.White });

                var badgeBorder = new Border
                {
                    HorizontalAlignment = HorizontalAlignment.Right,
                    CornerRadius = new CornerRadius(6),
                    Background = tbl.Status == "bill_printed" ? (Brush)FindResource("AccentGoldBrush") :
                                 tbl.IsOccupied ? (Brush)FindResource("DangerRedBrush") : (Brush)FindResource("SuccessGreenBrush"),
                    Padding = new Thickness(8, 3, 8, 3)
                };
                badgeBorder.Child = new TextBlock { Text = tbl.StatusBadge, FontSize = 11, FontWeight = FontWeights.ExtraBold, Foreground = Brushes.White };

                headerGrid.Children.Add(nameStack);
                headerGrid.Children.Add(badgeBorder);
                Grid.SetRow(headerGrid, 0);

                // 2. Qator: Mehmonlar, Ofitsiant va Vaqt
                var bodyStack = new StackPanel { VerticalAlignment = VerticalAlignment.Center, Margin = new Thickness(0, 6, 0, 6) };
                bodyStack.Children.Add(new TextBlock { Text = $"👤 {tbl.GuestsCount} kishi (sig'im: {tbl.Capacity})", FontSize = 13, Foreground = new SolidColorBrush(Color.FromRgb(148, 163, 184)) });

                if (tbl.IsOccupied)
                {
                    string waiter = tbl.ActiveOrder?.WaiterName ?? tbl.AssignedWaiter ?? "Jasur";
                    bodyStack.Children.Add(new TextBlock { Text = $"🤵 {waiter}", FontSize = 13, Foreground = Brushes.White, Margin = new Thickness(0, 2, 0, 0) });

                    int mins = tbl.ActiveOrder?.ElapsedMinutes ?? 0;
                    bodyStack.Children.Add(new TextBlock { Text = $"⏱ {mins} daqiqadan beri", FontSize = 12, FontWeight = FontWeights.SemiBold, Foreground = (Brush)FindResource("AccentGoldBrush"), Margin = new Thickness(0, 2, 0, 0) });
                }
                Grid.SetRow(bodyStack, 1);

                // 3. Qator: Jami summa va Amallar
                var footerGrid = new Grid();
                var sumText = new TextBlock
                {
                    Text = tbl.TotalSumFormatted,
                    FontSize = 17,
                    FontWeight = FontWeights.ExtraBold,
                    Foreground = tbl.IsOccupied ? (Brush)FindResource("SuccessGreenBrush") : new SolidColorBrush(Color.FromRgb(148, 163, 184)),
                    VerticalAlignment = VerticalAlignment.Center
                };

                footerGrid.Children.Add(sumText);
                Grid.SetRow(footerGrid, 2);

                grid.Children.Add(headerGrid);
                grid.Children.Add(bodyStack);
                grid.Children.Add(footerGrid);
                card.Child = grid;

                card.MouseLeftButtonUp += (s, e) => OnTableCardClicked((RestaurantTable)((Border)s).Tag);
                TablesWrapPanel.Children.Add(card);
            }
        }

        private async void OnTableCardClicked(RestaurantTable table)
        {
            if (!table.IsOccupied)
            {
                // Bo'sh stol -> Ochish dialogi
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

            CartTitleText.Text = $"STOL #{table.Number} ({table.Name})";
            CartSubtitleText.Text = $"Ofitsiant: {_currentCart.WaiterName} | Mehmon: {_currentCart.GuestsCount} kishi";
            OnNavClicked(NavQuickPosBtn, new RoutedEventArgs());
            UpdateCartUI();
        }

        private void OnTableFilterAll(object sender, RoutedEventArgs e) { _currentTableFilter = "all"; HighlightFilterBtn(FilterAllBtn); RenderTables(); }
        private void OnTableFilterZal(object sender, RoutedEventArgs e) { _currentTableFilter = "zal"; HighlightFilterBtn(FilterZalBtn); RenderTables(); }
        private void OnTableFilterTerrasa(object sender, RoutedEventArgs e) { _currentTableFilter = "terrasa"; HighlightFilterBtn(FilterTerrasaBtn); RenderTables(); }
        private void OnTableFilterVip(object sender, RoutedEventArgs e) { _currentTableFilter = "vip"; HighlightFilterBtn(FilterVipBtn); RenderTables(); }

        private void HighlightFilterBtn(Button active)
        {
            FilterAllBtn.Background = new SolidColorBrush(Color.FromRgb(51, 65, 85));
            FilterZalBtn.Background = new SolidColorBrush(Color.FromRgb(51, 65, 85));
            FilterTerrasaBtn.Background = new SolidColorBrush(Color.FromRgb(51, 65, 85));
            FilterVipBtn.Background = new SolidColorBrush(Color.FromRgb(51, 65, 85));
            active.Background = (Brush)FindResource("BrandPrimaryBrush");
        }
        #endregion

        #region 2. Tezkor Saboy & Buyurtma Qabul Qilish
        private void RenderCategories()
        {
            CategoriesStackPanel.Children.Clear();
            var allBtn = new Button
            {
                Content = "🍽 Barcha Taomlar",
                Height = 52,
                Margin = new Thickness(0, 0, 0, 8),
                FontSize = 14,
                FontWeight = FontWeights.Bold,
                Style = (Style)FindResource("TouchButtonStyle"),
                Background = _selectedCategory == null ? (Brush)FindResource("BrandPrimaryBrush") : (Brush)FindResource("CardDarkBrush")
            };
            allBtn.Click += (s, e) =>
            {
                _selectedCategory = null;
                RenderCategories();
                RenderProducts();
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

                var btn = new Button
                {
                    Content = $"{icon} {cat.Name}",
                    Height = 50,
                    Margin = new Thickness(0, 0, 0, 6),
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
                    RenderProducts();
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
                var card = new Border
                {
                    Width = 190,
                    Height = 125,
                    Margin = new Thickness(6),
                    CornerRadius = new CornerRadius(10),
                    Background = prod.IsAvailable ? (Brush)FindResource("CardDarkBrush") : new SolidColorBrush(Color.FromRgb(45, 20, 20)),
                    BorderThickness = new Thickness(1.5),
                    BorderBrush = prod.IsAvailable ? new SolidColorBrush(Color.FromRgb(51, 65, 85)) : (Brush)FindResource("DangerRedBrush"),
                    Padding = new Thickness(12),
                    Cursor = prod.IsAvailable ? Cursors.Hand : Cursors.No,
                    Tag = prod,
                    Opacity = prod.IsAvailable ? 1.0 : 0.65
                };

                var grid = new Grid();
                grid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
                grid.RowDefinitions.Add(new RowDefinition { Height = new GridLength(1, GridUnitType.Star) });
                grid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });

                // Department pill
                var deptPill = new TextBlock
                {
                    Text = prod.CategoryName.ToUpper(),
                    FontSize = 10,
                    FontWeight = FontWeights.Bold,
                    Foreground = new SolidColorBrush(Color.FromRgb(148, 163, 184))
                };
                Grid.SetRow(deptPill, 0);

                // Dish Name
                var nameBlock = new TextBlock
                {
                    Text = prod.Name,
                    FontSize = 15,
                    FontWeight = FontWeights.Bold,
                    Foreground = Brushes.White,
                    TextWrapping = TextWrapping.Wrap,
                    Margin = new Thickness(0, 4, 0, 4)
                };
                Grid.SetRow(nameBlock, 1);

                // Bottom row: Price and Status
                var bottomGrid = new Grid();
                var priceText = new TextBlock
                {
                    Text = prod.FormattedPrice,
                    FontSize = 15,
                    FontWeight = FontWeights.ExtraBold,
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
                        CornerRadius = new CornerRadius(4),
                        Padding = new Thickness(6, 2, 6, 2)
                    };
                    stopPill.Child = new TextBlock { Text = "TUGAGAN", FontSize = 10, FontWeight = FontWeights.Bold, Foreground = Brushes.White };
                    bottomGrid.Children.Add(stopPill);
                }
                Grid.SetRow(bottomGrid, 2);

                grid.Children.Add(deptPill);
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
        }

        private void UpdateCartUI()
        {
            CartItemsStackPanel.Children.Clear();

            foreach (var item in _currentCart.Items)
            {
                var border = new Border
                {
                    Background = new SolidColorBrush(Color.FromRgb(15, 23, 42)),
                    CornerRadius = new CornerRadius(8),
                    Padding = new Thickness(10),
                    Margin = new Thickness(0, 0, 0, 8)
                };

                var grid = new Grid();
                grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
                grid.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });

                // Chap: Nomi, Izohi va Narxi
                var leftStack = new StackPanel();
                leftStack.Children.Add(new TextBlock { Text = item.ProductName, FontSize = 15, FontWeight = FontWeights.Bold, Foreground = Brushes.White });
                leftStack.Children.Add(new TextBlock { Text = $"{item.Price:N0} so'm x {item.Quantity} = {item.Total:N0} so'm", FontSize = 12, Foreground = new SolidColorBrush(Color.FromRgb(148, 163, 184)) });

                if (!string.IsNullOrEmpty(item.Notes))
                {
                    leftStack.Children.Add(new TextBlock { Text = $"💬 {item.Notes}", FontSize = 11, FontWeight = FontWeights.SemiBold, Foreground = (Brush)FindResource("AccentGoldBrush"), Margin = new Thickness(0, 2, 0, 0) });
                }
                Grid.SetColumn(leftStack, 0);

                // O'ng: Stepper (- / +) va Izoh tugmasi
                var rightStack = new StackPanel { Orientation = Orientation.Horizontal, VerticalAlignment = VerticalAlignment.Center };

                var noteBtn = new Button { Content = "✎", Width = 34, Height = 34, FontSize = 14, Margin = new Thickness(0, 0, 6, 0), Style = (Style)FindResource("TouchButtonStyle"), Background = new SolidColorBrush(Color.FromRgb(51, 65, 85)), Tag = item };
                var minusBtn = new Button { Content = "-", Width = 36, Height = 36, FontSize = 18, FontWeight = FontWeights.Bold, Margin = new Thickness(2, 0, 2, 0), Style = (Style)FindResource("TouchButtonStyle"), Background = new SolidColorBrush(Color.FromRgb(51, 65, 85)), Tag = item };
                var qtyBlock = new TextBlock { Text = item.Quantity.ToString(), Width = 30, TextAlignment = TextAlignment.Center, FontSize = 16, FontWeight = FontWeights.ExtraBold, Foreground = Brushes.White, VerticalAlignment = VerticalAlignment.Center };
                var plusBtn = new Button { Content = "+", Width = 36, Height = 36, FontSize = 18, FontWeight = FontWeights.Bold, Margin = new Thickness(2, 0, 0, 0), Style = (Style)FindResource("TouchButtonStyle"), Background = new SolidColorBrush(Color.FromRgb(51, 65, 85)), Tag = item };

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
                };

                plusBtn.Click += (s, e) =>
                {
                    var it = (OrderItem)((Button)s).Tag;
                    it.Quantity++;
                    UpdateCartUI();
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

            // Xizmat haqi va chegirma hisobi
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
            DiscountPillBtn.Content = $"🏷 Chegirma: {_currentCart.DiscountPercent:0}%";
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

            // Buyurtmani serverga saqlash
            await _api.CreateOrUpdateOrderAsync(_currentCart);

            // Bo'lim printerlariga chiqarish
            await PrintOrderKitchenSlipsAsync(_currentCart);

            MessageBox.Show("Buyurtma bo'lim printerlariga (Shashlik, Somsa, Oshxona, Fast-food, Bar) yuborildi!", "Oshxonaga Yuborildi", MessageBoxButton.OK, MessageBoxImage.Information);
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

                // 1. Serverga saqlash yoki Offline navbatga qo'yish
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

                // 2. Kassa va Bo'lim printerlariga yuborish
                await PrintOrderKitchenSlipsAsync(_currentCart);
                string kassaIp = IpKassaBox.Text.Trim();
                if (!string.IsNullOrEmpty(kassaIp))
                {
                    await _printer.PrintKassaReceiptAsync(_currentCart, kassaIp, dialog.PaidCash, dialog.PaidCard, dialog.ChangeAmount);
                }

                // 3. Smena statistikasini yangilash
                _currentShift.TotalOrdersCount++;
                _currentShift.TotalRevenue += _currentCart.TotalAmount;
                if (dialog.SelectedPaymentMethod == "naqd") _currentShift.CashRevenue += _currentCart.TotalAmount;
                else if (dialog.SelectedPaymentMethod == "karta") _currentShift.CardRevenue += _currentCart.TotalAmount;
                else _currentShift.CashRevenue += dialog.PaidCash; _currentShift.CardRevenue += dialog.PaidCard;

                _currentShift.ServiceFeesCollected += _currentCart.ServiceFeeAmount;
                _currentShift.DiscountsGiven += _currentCart.DiscountAmount;

                // 4. Stol kontekstini tozalash
                if (_activeTableContext != null)
                {
                    _activeTableContext.IsOccupied = false;
                    _activeTableContext.Status = "empty";
                    _activeTableContext.ActiveOrder = null;
                    _activeTableContext = null;
                    RenderTables();
                }

                _currentCart = new Order { ServiceType = "pickup" };
                CartTitleText.Text = "TEZKOR SABOY (OLIB KETISH)";
                CartSubtitleText.Text = "Kassir: " + _settings.CashierName;
                UpdateCartUI();

                MessageBox.Show("To'lov muvaffaqiyatli amalga oshirildi va chek chiqarildi!", "Muvaffaqiyatli", MessageBoxButton.OK, MessageBoxImage.Information);
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
        }

        private void OnProductSearchChanged(object sender, TextChangedEventArgs e)
        {
            RenderProducts(ProductSearchBox.Text);
        }

        private void OnClearSearchClick(object sender, RoutedEventArgs e)
        {
            ProductSearchBox.Text = "";
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

            foreach (var prod in list)
            {
                var card = new Border
                {
                    Width = 270,
                    Height = 90,
                    Margin = new Thickness(6),
                    CornerRadius = new CornerRadius(10),
                    Background = (Brush)FindResource("CardDarkBrush"),
                    BorderThickness = new Thickness(2),
                    BorderBrush = prod.IsAvailable ? (Brush)FindResource("SuccessGreenBrush") : (Brush)FindResource("DangerRedBrush"),
                    Padding = new Thickness(14)
                };

                var grid = new Grid();
                grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
                grid.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });

                var leftStack = new StackPanel { VerticalAlignment = VerticalAlignment.Center };
                leftStack.Children.Add(new TextBlock { Text = prod.Name, FontSize = 15, FontWeight = FontWeights.Bold, Foreground = Brushes.White });
                leftStack.Children.Add(new TextBlock { Text = $"{prod.CategoryName} • {prod.FormattedPrice}", FontSize = 12, Foreground = new SolidColorBrush(Color.FromRgb(148, 163, 184)), Margin = new Thickness(0, 2, 0, 0) });
                Grid.SetColumn(leftStack, 0);

                var toggleBtn = new Button
                {
                    Content = prod.IsAvailable ? "MAVJUD" : "STOP-LIST",
                    Width = 96,
                    Height = 46,
                    FontSize = 12,
                    FontWeight = FontWeights.ExtraBold,
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
                OnlineOrdersStackPanel.Children.Add(new TextBlock
                {
                    Text = "Hozircha yangi online buyurtmalar kelmadi",
                    FontSize = 16,
                    Foreground = new SolidColorBrush(Color.FromRgb(148, 163, 184)),
                    Margin = new Thickness(0, 30, 0, 0)
                });
                return;
            }

            foreach (var order in _onlineOrders)
            {
                var card = new Border
                {
                    Background = (Brush)FindResource("CardDarkBrush"),
                    CornerRadius = new CornerRadius(12),
                    Padding = new Thickness(18),
                    Margin = new Thickness(0, 0, 0, 14),
                    BorderThickness = new Thickness(2),
                    BorderBrush = (Brush)FindResource("AccentGoldBrush")
                };

                var grid = new Grid();
                grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
                grid.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });

                var leftStack = new StackPanel();
                var headerStack = new StackPanel { Orientation = Orientation.Horizontal };
                headerStack.Children.Add(new TextBlock { Text = order.ServiceType == "delivery" ? "🚴 DOSTAVKA " : "🛍 SABOY ", FontSize = 18, FontWeight = FontWeights.ExtraBold, Foreground = (Brush)FindResource("AccentGoldBrush") });
                headerStack.Children.Add(new TextBlock { Text = $"#{order.OrderNumber}", FontSize = 18, FontWeight = FontWeights.ExtraBold, Foreground = Brushes.White });
                leftStack.Children.Add(headerStack);

                leftStack.Children.Add(new TextBlock { Text = $"Mijoz: {order.CustomerName} | Tel: {order.CustomerPhone}", FontSize = 14, Foreground = new SolidColorBrush(Color.FromRgb(148, 163, 184)), Margin = new Thickness(0, 4, 0, 8) });

                foreach (var it in order.Items)
                {
                    leftStack.Children.Add(new TextBlock { Text = $"• {it.Quantity}x {it.ProductName} — {it.Total:N0} so'm", FontSize = 14, Foreground = Brushes.White });
                }

                leftStack.Children.Add(new TextBlock { Text = $"Jami summa: {order.TotalAmount:N0} so'm", FontSize = 17, FontWeight = FontWeights.ExtraBold, Foreground = (Brush)FindResource("SuccessGreenBrush"), Margin = new Thickness(0, 8, 0, 0) });
                Grid.SetColumn(leftStack, 0);

                var rightStack = new StackPanel { VerticalAlignment = VerticalAlignment.Center };
                var acceptBtn = new Button
                {
                    Content = "✅ QABUL QILISH VA CHEK CHIQARISH",
                    Height = 56,
                    Padding = new Thickness(18, 10, 18, 10),
                    FontSize = 14,
                    FontWeight = FontWeights.Bold,
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
            RenderOnlineOrders();
        }
        #endregion

        #region 5. Sozlamalar va Printer Testlari
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

            MessageBox.Show("Barcha sozlamalar muvaffaqiyatli saqlandi!", "Sozlamalar", MessageBoxButton.OK, MessageBoxImage.Information);
        }
        #endregion
    }
}
