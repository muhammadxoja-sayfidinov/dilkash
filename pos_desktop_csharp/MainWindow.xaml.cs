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

        // Xotiradagi joriy ma'lumotlar
        private List<Department> _departments = new();
        private List<Category> _categories = new();
        private List<Product> _products = new();
        private List<RestaurantTable> _tables = new();
        private PosSettings _settings = new();
        private List<Order> _onlineOrders = new();

        // Tezkor Saboy uchun joriy savatcha
        private Order _currentCart = new() { ServiceType = "pickup" };
        private Category? _selectedCategory;
        private RestaurantTable? _activeTableContext;

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

        private async Task LoadDataAsync()
        {
            // 1. Birinchi navbatda lokal bazadan ma'lumotlarni o'qiymiz (darhol tez ochilishi uchun)
            _products = await _db.GetCachedProductsAsync();
            _categories = await _db.GetCachedCategoriesAsync();
            _tables = await _db.GetCachedTablesAsync();

            if (_tables.Count == 0)
            {
                // Standart stollar generatsiyasi
                for (int i = 1; i <= 12; i++)
                {
                    _tables.Add(new RestaurantTable { Number = i, Name = i > 8 ? $"VIP #{i - 8}" : $"Stol #{i}", Capacity = i > 8 ? 8 : 4 });
                }
            }

            RenderTables();
            RenderCategories();
            RenderProducts();
            RenderStopList();
            UpdateCartUI();

            // 2. Serverdan yangilanishlarni olamiz
            var bootstrap = await _api.GetBootstrapAsync();
            if (bootstrap != null && bootstrap.Status == "ok")
            {
                _departments = bootstrap.Departments;
                _categories = bootstrap.Categories;
                _products = bootstrap.Products;
                _tables = bootstrap.Tables;
                if (bootstrap.Settings != null)
                {
                    _settings = bootstrap.Settings;
                    ApplySettingsToUI();
                }

                // Lokal bazaga keshlab qo'yish
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
                    StatusBadgeText.Text = "● SERVER ULANGAN";
                }
                else
                {
                    StatusBadgeBorder.Background = (Brush)FindResource("DangerRedBrush");
                    StatusBadgeText.Text = "● OFFLINE REJIM";
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
        #endregion

        #region 1. Stollar Xaritasi
        private void RenderTables(string? filter = null)
        {
            TablesWrapPanel.Children.Clear();
            int total = _tables.Count;
            int occupied = _tables.Count(t => t.IsOccupied);
            TablesSummaryText.Text = $"Jami: {total} ta | Band: {occupied} ta | Bo'sh: {total - occupied} ta";

            var list = _tables;
            if (filter == "zal") list = _tables.Where(t => t.Number <= 8).ToList();
            else if (filter == "vip") list = _tables.Where(t => t.Number > 8).ToList();

            foreach (var tbl in list)
            {
                var border = new Border
                {
                    Width = 220,
                    Height = 150,
                    Margin = new Thickness(8),
                    CornerRadius = new CornerRadius(10),
                    Background = tbl.IsOccupied ? (Brush)FindResource("CardDarkBrush") : new SolidColorBrush(Color.FromRgb(26, 46, 38)),
                    BorderThickness = new Thickness(2),
                    BorderBrush = tbl.IsOccupied ? (Brush)FindResource("DangerRedBrush") : (Brush)FindResource("BrandPrimaryBrush"),
                    Padding = new Thickness(14),
                    Cursor = Cursors.Hand,
                    Tag = tbl
                };

                var grid = new Grid();
                grid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
                grid.RowDefinitions.Add(new RowDefinition { Height = new GridLength(1, GridUnitType.Star) });
                grid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });

                // Top: Stol nomi va Holati
                var topGrid = new Grid();
                var tblNameText = new TextBlock { Text = tbl.Name, FontSize = 18, FontWeight = FontWeights.Bold, Foreground = Brushes.White };
                var badgeBorder = new Border
                {
                    HorizontalAlignment = HorizontalAlignment.Right,
                    CornerRadius = new CornerRadius(6),
                    Background = tbl.IsOccupied ? (Brush)FindResource("DangerRedBrush") : (Brush)FindResource("SuccessGreenBrush"),
                    Padding = new Thickness(6, 2, 6, 2)
                };
                badgeBorder.Child = new TextBlock { Text = tbl.StatusText, FontSize = 11, FontWeight = FontWeights.Bold, Foreground = Brushes.White };
                topGrid.Children.Add(tblNameText);
                topGrid.Children.Add(badgeBorder);
                Grid.SetRow(topGrid, 0);

                // Middle: Mehmonlar va Vaqt
                var midPanel = new StackPanel { VerticalAlignment = VerticalAlignment.Center };
                midPanel.Children.Add(new TextBlock { Text = $"O'rin: {tbl.Capacity} kishilik | Mehmon: {tbl.GuestsCount}", FontSize = 13, Foreground = new SolidColorBrush(Color.FromRgb(148, 163, 184)) });
                if (tbl.IsOccupied && tbl.ActiveOrder != null)
                {
                    midPanel.Children.Add(new TextBlock { Text = $"Vaqt: {tbl.ActiveOrder.ElapsedMinutes} daqiqadan beri", FontSize = 12, Foreground = new SolidColorBrush(Color.FromRgb(217, 119, 6)) });
                }
                Grid.SetRow(midPanel, 1);

                // Bottom: Jami Summa
                var bottomText = new TextBlock
                {
                    Text = tbl.TotalSumFormatted,
                    FontSize = 16,
                    FontWeight = FontWeights.Bold,
                    Foreground = tbl.IsOccupied ? (Brush)FindResource("SuccessGreenBrush") : Brushes.White,
                    HorizontalAlignment = HorizontalAlignment.Right
                };
                Grid.SetRow(bottomText, 2);

                grid.Children.Add(topGrid);
                grid.Children.Add(midPanel);
                grid.Children.Add(bottomText);
                border.Child = grid;

                border.MouseLeftButtonUp += (s, e) => OnTableCardClicked((RestaurantTable)((Border)s).Tag);
                TablesWrapPanel.Children.Add(border);
            }
        }

        private async void OnTableCardClicked(RestaurantTable table)
        {
            if (!table.IsOccupied)
            {
                // Bo'sh stol -> Ochish dialogi
                var dialog = new OpenTableDialog(table.Number, table.Name);
                if (dialog.ShowDialog() == true)
                {
                    table.IsOccupied = true;
                    table.GuestsCount = dialog.SelectedGuestsCount;

                    var order = await _api.OpenTableAsync(table.Number, table.GuestsCount, dialog.WaiterName);
                    if (order != null)
                    {
                        table.ActiveOrder = order;
                    }
                    else
                    {
                        // Offline rejimda stol ochish
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
                // Band stol -> Buyurtmaga o'tish
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
                GuestsCount = table.GuestsCount
            };

            CartTitleText.Text = $"{table.Name} (Mehmon: {_currentCart.GuestsCount})";
            OnNavClicked(NavQuickPosBtn, new RoutedEventArgs());
            UpdateCartUI();
        }

        private void OnTableFilterAll(object sender, RoutedEventArgs e) => RenderTables();
        private void OnTableFilterZal(object sender, RoutedEventArgs e) => RenderTables("zal");
        private void OnTableFilterVip(object sender, RoutedEventArgs e) => RenderTables("vip");
        #endregion

        #region 2. Tezkor Saboy & Savatcha
        private void RenderCategories()
        {
            CategoriesStackPanel.Children.Clear();
            var allBtn = new Button
            {
                Content = "🍽 Barcha Taomlar",
                Height = 48,
                Margin = new Thickness(0, 0, 0, 6),
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
                var btn = new Button
                {
                    Content = cat.Name,
                    Height = 48,
                    Margin = new Thickness(0, 0, 0, 6),
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
                var border = new Border
                {
                    Width = 175,
                    Height = 110,
                    Margin = new Thickness(6),
                    CornerRadius = new CornerRadius(8),
                    Background = prod.IsAvailable ? (Brush)FindResource("CardDarkBrush") : new SolidColorBrush(Color.FromRgb(40, 20, 20)),
                    BorderThickness = new Thickness(1),
                    BorderBrush = prod.IsAvailable ? new SolidColorBrush(Color.FromRgb(51, 65, 85)) : (Brush)FindResource("DangerRedBrush"),
                    Padding = new Thickness(10),
                    Cursor = prod.IsAvailable ? Cursors.Hand : Cursors.No,
                    Tag = prod,
                    Opacity = prod.IsAvailable ? 1.0 : 0.6
                };

                var grid = new Grid();
                grid.RowDefinitions.Add(new RowDefinition { Height = new GridLength(1, GridUnitType.Star) });
                grid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });

                var nameBlock = new TextBlock
                {
                    Text = prod.Name,
                    FontSize = 14,
                    FontWeight = FontWeights.SemiBold,
                    Foreground = Brushes.White,
                    TextWrapping = TextWrapping.Wrap
                };
                Grid.SetRow(nameBlock, 0);

                var bottomStack = new StackPanel { Orientation = Orientation.Horizontal, HorizontalAlignment = HorizontalAlignment.Right };
                if (!prod.IsAvailable)
                {
                    bottomStack.Children.Add(new TextBlock
                    {
                        Text = "STOP ",
                        FontSize = 12,
                        FontWeight = FontWeights.Bold,
                        Foreground = (Brush)FindResource("DangerRedBrush")
                    });
                }
                bottomStack.Children.Add(new TextBlock
                {
                    Text = prod.FormattedPrice,
                    FontSize = 13,
                    FontWeight = FontWeights.Bold,
                    Foreground = (Brush)FindResource("SuccessGreenBrush")
                });
                Grid.SetRow(bottomStack, 1);

                grid.Children.Add(nameBlock);
                grid.Children.Add(bottomStack);
                border.Child = grid;

                if (prod.IsAvailable)
                {
                    border.MouseLeftButtonUp += (s, e) => AddProductToCart((Product)((Border)s).Tag);
                }

                ProductsWrapPanel.Children.Add(border);
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

            decimal subtotal = 0;
            foreach (var item in _currentCart.Items)
            {
                subtotal += item.Total;

                var itemBorder = new Border
                {
                    Background = new SolidColorBrush(Color.FromRgb(15, 23, 42)),
                    CornerRadius = new CornerRadius(6),
                    Padding = new Thickness(8),
                    Margin = new Thickness(0, 0, 0, 6)
                };

                var itemGrid = new Grid();
                itemGrid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
                itemGrid.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });

                var leftStack = new StackPanel();
                leftStack.Children.Add(new TextBlock { Text = item.ProductName, FontSize = 14, FontWeight = FontWeights.SemiBold, Foreground = Brushes.White });
                leftStack.Children.Add(new TextBlock { Text = $"{item.Quantity} x {item.Price:N0} = {item.Total:N0} so'm", FontSize = 12, Foreground = new SolidColorBrush(Color.FromRgb(148, 163, 184)) });
                Grid.SetColumn(leftStack, 0);

                var rightStack = new StackPanel { Orientation = Orientation.Horizontal };
                var minusBtn = new Button { Content = "-", Width = 32, Height = 32, FontSize = 16, FontWeight = FontWeights.Bold, Margin = new Thickness(2, 0, 2, 0), Style = (Style)FindResource("TouchButtonStyle"), Background = new SolidColorBrush(Color.FromRgb(51, 65, 85)), Tag = item };
                var plusBtn = new Button { Content = "+", Width = 32, Height = 32, FontSize = 16, FontWeight = FontWeights.Bold, Margin = new Thickness(2, 0, 2, 0), Style = (Style)FindResource("TouchButtonStyle"), Background = new SolidColorBrush(Color.FromRgb(51, 65, 85)), Tag = item };
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
                rightStack.Children.Add(minusBtn);
                rightStack.Children.Add(plusBtn);
                Grid.SetColumn(rightStack, 1);

                itemGrid.Children.Add(leftStack);
                itemGrid.Children.Add(rightStack);
                itemBorder.Child = itemGrid;

                CartItemsStackPanel.Children.Add(itemBorder);
            }

            _currentCart.ProductsTotal = subtotal;

            // Xizmat haqini hisoblash
            decimal serviceFee = 0;
            if (_currentCart.ServiceType == "dine_in")
            {
                if (_settings.ServiceFeeType == "percent")
                    serviceFee = subtotal * (_settings.ServiceFeePercent / 100m);
                else if (_settings.ServiceFeeType == "per_person")
                    serviceFee = _currentCart.GuestsCount * _settings.ServiceFeePerPerson;
            }

            _currentCart.ServiceFeeAmount = serviceFee;
            _currentCart.TotalAmount = subtotal + serviceFee;

            CartSubtotalText.Text = $"{subtotal:N0} so'm";
            CartServiceFeeText.Text = $"{serviceFee:N0} so'm";
            CartTotalText.Text = $"{_currentCart.TotalAmount:N0} so'm";
        }

        private void OnClearCartClick(object sender, RoutedEventArgs e)
        {
            _currentCart.Items.Clear();
            UpdateCartUI();
        }

        private async void OnPayCartClick(object sender, RoutedEventArgs e)
        {
            if (_currentCart.Items.Count == 0)
            {
                MessageBox.Show("Savatcha bo'sh! To'lov uchun taom qo'shing.", "Ogohlantirish", MessageBoxButton.OK, MessageBoxImage.Information);
                return;
            }

            var dialog = new PaymentDialog(_currentCart.TotalAmount, _currentCart.OrderNumber ?? "YANGI", _currentCart.TableNumber, _currentCart.GuestsCount);
            if (dialog.ShowDialog() == true)
            {
                _currentCart.IsPaid = true;
                _currentCart.PaymentMethod = dialog.SelectedPaymentMethod;

                // 1. Buyurtmani serverga yuborish yoki Offline saqlash
                var savedOrder = await _api.CreateOrUpdateOrderAsync(_currentCart);
                if (savedOrder != null)
                {
                    _currentCart = savedOrder;
                    await _api.PayOrderAsync(savedOrder.Id, dialog.SelectedPaymentMethod, dialog.PaidCash, dialog.PaidCard);
                }
                else
                {
                    // Offline navbatga qo'yish
                    await _db.EnqueueOfflineOrderAsync(_currentCart);
                }

                // 2. Tarmoq printerlariga yuborish
                await PrintOrderAsync(_currentCart, dialog.PaidCash, dialog.PaidCard, dialog.ChangeAmount);

                // 3. Agar stol bo'lsa, stolni bo'shatamiz
                if (_activeTableContext != null)
                {
                    _activeTableContext.IsOccupied = false;
                    _activeTableContext.ActiveOrder = null;
                    _activeTableContext = null;
                    RenderTables();
                }

                // Yangi savatcha
                _currentCart = new Order { ServiceType = "pickup" };
                CartTitleText.Text = "TEZKOR SABOY (OLIB KETISH)";
                UpdateCartUI();

                MessageBox.Show("To'lov muvaffaqiyatli qabul qilindi va cheklar printerga yuborildi!", "Muvaffaqiyatli", MessageBoxButton.OK, MessageBoxImage.Information);
            }
        }

        private async Task PrintOrderAsync(Order order, decimal paidCash, decimal paidCard, decimal change)
        {
            // A) Oshxona / Shashlik / Somsa / Fast-food bo'limlariga
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

            // B) Kassa hisob cheki
            string kassaIp = IpKassaBox.Text.Trim();
            if (!string.IsNullOrEmpty(kassaIp))
            {
                await _printer.PrintKassaReceiptAsync(order, kassaIp, paidCash, paidCard, change);
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

        private void OnProductSearchChanged(object sender, TextChangedEventArgs e)
        {
            RenderProducts(ProductSearchBox.Text);
        }
        #endregion

        #region 3. Stop-List Boshqaruvi
        private void RenderStopList(string? query = null)
        {
            StopListWrapPanel.Children.Clear();
            var list = _products;
            if (!string.IsNullOrWhiteSpace(query))
                list = list.Where(p => p.Name.Contains(query, StringComparison.OrdinalIgnoreCase)).ToList();

            foreach (var prod in list)
            {
                var border = new Border
                {
                    Width = 260,
                    Height = 84,
                    Margin = new Thickness(6),
                    CornerRadius = new CornerRadius(8),
                    Background = (Brush)FindResource("CardDarkBrush"),
                    BorderThickness = new Thickness(2),
                    BorderBrush = prod.IsAvailable ? (Brush)FindResource("SuccessGreenBrush") : (Brush)FindResource("DangerRedBrush"),
                    Padding = new Thickness(12)
                };

                var grid = new Grid();
                grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
                grid.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });

                var leftStack = new StackPanel { VerticalAlignment = VerticalAlignment.Center };
                leftStack.Children.Add(new TextBlock { Text = prod.Name, FontSize = 14, FontWeight = FontWeights.Bold, Foreground = Brushes.White });
                leftStack.Children.Add(new TextBlock { Text = prod.FormattedPrice, FontSize = 12, Foreground = new SolidColorBrush(Color.FromRgb(148, 163, 184)) });
                Grid.SetColumn(leftStack, 0);

                var toggleBtn = new Button
                {
                    Content = prod.IsAvailable ? "MAVJUD" : "STOP-LIST",
                    Width = 90,
                    Height = 44,
                    FontSize = 12,
                    FontWeight = FontWeights.Bold,
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
                border.Child = grid;

                StopListWrapPanel.Children.Add(border);
            }
        }

        private void OnStopListSearchChanged(object sender, TextChangedEventArgs e)
        {
            RenderStopList(StopListSearchBox.Text);
        }
        #endregion

        #region 4. Online Buyurtmalar
        private void RenderOnlineOrders()
        {
            OnlineOrdersStackPanel.Children.Clear();
            if (_onlineOrders.Count == 0)
            {
                OnlineOrdersStackPanel.Children.Add(new TextBlock
                {
                    Text = "Hozircha yangi online buyurtmalar yo'q",
                    FontSize = 16,
                    Foreground = new SolidColorBrush(Color.FromRgb(148, 163, 184)),
                    Margin = new Thickness(0, 20, 0, 0)
                });
                return;
            }

            foreach (var order in _onlineOrders)
            {
                var border = new Border
                {
                    Background = (Brush)FindResource("CardDarkBrush"),
                    CornerRadius = new CornerRadius(10),
                    Padding = new Thickness(16),
                    Margin = new Thickness(0, 0, 0, 12),
                    BorderThickness = new Thickness(1),
                    BorderBrush = (Brush)FindResource("AccentGoldBrush")
                };

                var grid = new Grid();
                grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
                grid.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });

                var leftStack = new StackPanel();
                leftStack.Children.Add(new TextBlock { Text = $"Buyurtma #{order.OrderNumber} ({order.ServiceType.ToUpper()})", FontSize = 18, FontWeight = FontWeights.Bold, Foreground = Brushes.White });
                leftStack.Children.Add(new TextBlock { Text = $"Mijoz: {order.CustomerName} ({order.CustomerPhone})", FontSize = 14, Foreground = new SolidColorBrush(Color.FromRgb(148, 163, 184)), Margin = new Thickness(0, 2, 0, 6) });

                foreach (var it in order.Items)
                {
                    leftStack.Children.Add(new TextBlock { Text = $"• {it.Quantity}x {it.ProductName} ({it.Total:N0} so'm)", FontSize = 13, Foreground = Brushes.White });
                }

                leftStack.Children.Add(new TextBlock { Text = $"Jami: {order.TotalAmount:N0} so'm", FontSize = 16, FontWeight = FontWeights.Bold, Foreground = (Brush)FindResource("SuccessGreenBrush"), Margin = new Thickness(0, 6, 0, 0) });
                Grid.SetColumn(leftStack, 0);

                var rightStack = new StackPanel { VerticalAlignment = VerticalAlignment.Center };
                var acceptBtn = new Button
                {
                    Content = "QABUL QILISH VA CHEK CHIQARISH",
                    Height = 52,
                    Padding = new Thickness(16, 8, 16, 8),
                    Style = (Style)FindResource("TouchButtonStyle"),
                    Background = (Brush)FindResource("SuccessGreenBrush"),
                    Tag = order
                };
                acceptBtn.Click += async (s, e) =>
                {
                    var ord = (Order)((Button)s).Tag;
                    await PrintOrderAsync(ord, ord.TotalAmount, 0, 0);
                    _onlineOrders.Remove(ord);
                    RenderOnlineOrders();
                    MessageBox.Show($"Buyurtma #{ord.OrderNumber} qabul qilindi va oshxonaga yuborildi!", "Muvaffaqiyatli", MessageBoxButton.OK, MessageBoxImage.Information);
                };
                rightStack.Children.Add(acceptBtn);
                Grid.SetColumn(rightStack, 1);

                grid.Children.Add(leftStack);
                grid.Children.Add(rightStack);
                border.Child = grid;

                OnlineOrdersStackPanel.Children.Add(border);
            }
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

            ServiceFeePercentBox.Text = _settings.ServiceFeePercent.ToString("0");
            ServerUrlBox.Text = _settings.ServerUrl;
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
            if (decimal.TryParse(ServiceFeePercentBox.Text.Trim(), out decimal pct))
            {
                _settings.ServiceFeePercent = pct;
            }
            MessageBox.Show("Sozlamalar saqlandi!", "Sozlamalar", MessageBoxButton.OK, MessageBoxImage.Information);
        }
        #endregion
    }
}
