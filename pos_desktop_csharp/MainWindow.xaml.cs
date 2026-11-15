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
        private readonly LocalWifiHubServer _localHub;
        private readonly object _stateLock = new();
        private readonly HashSet<int> _notifiedCallIds = new();
        private readonly DispatcherTimer _clockTimer;

        // Xotiradagi asosiy ma'lumotlar
        private List<Department> _departments = new();
        private List<Category> _categories = new();
        private List<Product> _products = new();
        private List<RestaurantTable> _tables = new();
        private List<Hall> _halls = new();
        private List<PosPrinter> _printers = new();
        private CashierProfile _cashierProfile = new();
        private List<StaffAccount> _staffAccounts = new();
        private PosSettings _settings = new();
        private List<Order> _onlineOrders = new();
        private ShiftReport _currentShift = new();

        // Savatcha va Tanlangan elementlar
        private Order _currentCart = new() { ServiceType = "pickup" };
        private readonly List<Category> _categoryNavStack = new();
        private RestaurantTable? _activeTableContext;
        private string _currentTableFilter = "__all__";
        private readonly HashSet<string> _selectedTableStatuses = new() { "occupied" };
        private readonly ObservableCollection<HallFilterVM> _hallFilters = new();
        private readonly ObservableCollection<TableZoneSectionVM> _tableZoneSections = new();
        private readonly Dictionary<int, TableCardVM> _tableCardVMs = new();
        private readonly ObservableCollection<CategoryTileVM> _categoryTiles = new();
        private readonly ObservableCollection<CategoryBreadcrumbVM> _categoryBreadcrumbs = new();
        private readonly ObservableCollection<ProductTileVM> _visibleProductTiles = new();
        private readonly Dictionary<int, ProductTileVM> _productTileMap = new();
        private readonly ObservableCollection<CartLineVM> _cartLines = new();
        private readonly ObservableCollection<StopListItemVM> _stopListVMs = new();
        private readonly ObservableCollection<OnlineOrderCardVM> _onlineOrderVMs = new();
        private readonly ObservableCollection<PrinterCardVM> _printerCardVMs = new();
        private string _stopListFilter = "all";
        private string _activeSettingsSection = "profile";
        private string _pendingAvatarColor = "#10B981";
        private bool _isApplyingSettings = false;
        private bool _settingsDirty = false;
        private int _tableColumns = 4;
        private bool _isLoadingTables = false;
        private string _activeTabTag = "tables";
        private bool _isDemoMode = false;

        // Omborxona va Tex-karta (Inventory & Recipes)
        private List<Ingredient> _ingredients = new();
        private List<Supplier> _suppliers = new();
        private List<RecipeItem> _recipes = new();
        private List<StockSupply> _supplies = new();
        private List<StockWriteOff> _writeOffs = new();
        private List<StockMovementLogItem> _movements = new();
        private InventoryKpiSummary _inventoryKpi = new();
        private string _activeInventorySubTab = "stock";
        private bool _filterLowStockOnly = false;

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
            _api = new ApiService("https://dilkash-django-production.up.railway.app");
            _printer = new EscPosPrinterService();
            _syncEngine = new SyncEngine(_api, _db, _printer);
            _localHub = new LocalWifiHubServer(
                _db,
                _stateLock,
                () => _tables,
                () => _categories,
                () => _products,
                () => _settings,
                () => _api.IsOnline,
                () => _syncEngine.TriggerImmediateSync()
            );

            HallFilterItemsControl.ItemsSource = _hallFilters;
            TableZonesItemsControl.ItemsSource = _tableZoneSections;
            CategoryTilesItemsControl.ItemsSource = _categoryTiles;
            CategoryBreadcrumbItemsControl.ItemsSource = _categoryBreadcrumbs;
            ProductsItemsControl.ItemsSource = _visibleProductTiles;
            CartLinesItemsControl.ItemsSource = _cartLines;
            StopListItemsControl.ItemsSource = _stopListVMs;
            OnlineOrdersItemsControl.ItemsSource = _onlineOrderVMs;
            PrintersItemsControl.ItemsSource = _printerCardVMs;
            InitializeManagementLists();

            Dialogs.RegisterScrimHandler(visible => ModalScrim.Visibility = visible ? Visibility.Visible : Visibility.Collapsed);
            Toast.RegisterHost(MainToastHost);

            UpdateClockDisplay();
            _clockTimer = new DispatcherTimer { Interval = TimeSpan.FromSeconds(1) };
            _clockTimer.Tick += (s, e) => UpdateClockDisplay();
            _clockTimer.Start();

            TopConnectionPill.Update(true, 0, DateTime.Now);

            _syncEngine.SyncStatusUpdated += OnSyncStatusUpdated;
            _syncEngine.OnlineOrdersReceived += OnOnlineOrdersReceived;
            _syncEngine.BootstrapSynced += OnBootstrapSynced;
            _syncEngine.ProductImagesSynced += OnProductImagesSynced;

            _localHub.HubStateChanged += OnHubStateChanged;
            _localHub.WaiterOrderReceived += OnHubWaiterOrderReceived;
            _localHub.WaiterOrderPaid += OnHubWaiterOrderPaid;
            _localHub.WaiterCallCreated += OnHubWaiterCallCreated;

            try
            {
                _localHub.Start();
            }
            catch (Exception ex)
            {
                Toast.Show($"Wi-Fi Hub ishga tushmadi: {ex.Message}", ToastTone.Warning);
            }

            UpdateThemeToggleVisuals(ThemeManager.IsDark);
            ThemeManager.ThemeChanged += OnThemeManagerChanged;
            Closed += (_, _) =>
            {
                ThemeManager.ThemeChanged -= OnThemeManagerChanged;
                _localHub.Dispose();
                _syncEngine.Dispose();
            };
        }

        private void OnThemeManagerChanged(object? sender, bool isDark)
        {
            Dispatcher.Invoke(() => UpdateThemeToggleVisuals(isDark));
        }

        private void UpdateThemeToggleVisuals(bool isDark)
        {
            ThemeToggleIcon.Data = (Geometry)FindResource(isDark ? "IconSun" : "IconMoon");
            ThemeToggleText.Text = isDark ? "Kun" : "Tun";
            if (ProfileThemeToggleCheck != null)
            {
                bool prev = _isApplyingSettings;
                _isApplyingSettings = true;
                try
                {
                    ProfileThemeToggleCheck.IsChecked = isDark;
                }
                finally
                {
                    _isApplyingSettings = prev;
                }
            }
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
            else if (e.Key == Key.Escape && _activeTabTag == "quick_pos" && _categoryNavStack.Count > 0)
            {
                OnQuickPosBackClick(sender, new RoutedEventArgs());
                e.Handled = true;
            }
        }

        private async Task LoadDataAsync()
        {
            _isLoadingTables = true;
            UpdateTablesLoadingAndEmptyStates();

            // 1. Saqlangan lokal sozlamalarni o'qish (Cloud URL, Kassir, Bot & Yetkazish)
            var savedFullSettings = await _db.LoadFullSettingsLocalAsync();
            if (savedFullSettings != null)
            {
                _settings = savedFullSettings;
            }
            var savedServerUrl = await _db.GetSettingAsync("server_url", "https://dilkash-django-production.up.railway.app");
            if (!string.IsNullOrWhiteSpace(savedServerUrl))
            {
                _settings.ServerUrl = savedServerUrl;
                _api.SetBaseUrl(savedServerUrl);
            }
            var savedCashier = await _db.GetSettingAsync("cashier_name");
            if (!string.IsNullOrWhiteSpace(savedCashier))
            {
                _settings.CashierName = savedCashier;
            }

            // 2. Lokal SQLite keshidan o'qish (Darhol, internetsiz ham yuklanadi)
            var cachedDepts = await _db.GetCachedDepartmentsAsync();
            var cachedProds = await _db.GetCachedProductsAsync();
            var cachedCats = await _db.GetCachedCategoriesAsync();
            var cachedTables = await _db.GetCachedTablesAsync();
            var cachedStaff = await _db.GetCachedStaffAsync();
            var cachedHalls = await _db.GetCachedHallsAsync();
            var cachedPrinters = await _db.GetCachedPrintersAsync();
            var cachedCashier = await _db.GetCachedCashierProfileAsync();
            var cachedIngredients = await _db.GetCachedIngredientsAsync();
            var cachedSuppliers = await _db.GetCachedSuppliersAsync();
            var cachedRecipes = await _db.GetCachedRecipesAsync();

            if (cachedHalls.Count == 0)
            {
                cachedHalls = new List<Hall>
                {
                    new Hall { Id = 1, Name = "Zal", Description = "Asosiy zal", SortOrder = 1, IsActive = true },
                    new Hall { Id = 2, Name = "Terrasa", Description = "Ochiq havo terrasa", SortOrder = 2, IsActive = true },
                    new Hall { Id = 3, Name = "VIP", Description = "VIP kabinalar", SortOrder = 3, IsActive = true },
                };
            }

            if (cachedTables.Count == 0)
            {
                for (int i = 1; i <= 6; i++)
                    cachedTables.Add(new RestaurantTable { Id = i, Number = i, Name = $"Stol #{i}", HallId = 1, Zone = "Zal", Capacity = 4 });
                for (int i = 7; i <= 9; i++)
                    cachedTables.Add(new RestaurantTable { Id = i, Number = i, Name = $"Terrasa #{i - 6}", HallId = 2, Zone = "Terrasa", Capacity = 6 });
                for (int i = 10; i <= 12; i++)
                    cachedTables.Add(new RestaurantTable { Id = i, Number = i, Name = $"VIP Xona #{i - 9}", HallId = 3, Zone = "VIP", Capacity = 10 });
            }
            AssignTableZones(cachedTables);

            if (cachedPrinters.Count == 0)
            {
                cachedPrinters = BuildDefaultPrintersFromSettings(_settings, cachedDepts);
            }

            if (cachedCashier == null)
            {
                cachedCashier = new CashierProfile
                {
                    Id = 1,
                    Name = string.IsNullOrWhiteSpace(_settings.CashierName) ? "Jasur Rahimov" : _settings.CashierName,
                    Phone = "+998901112233",
                    RoleTitle = "Bosh kassir",
                    PinHash = LocalDatabase.ComputeSha256Hex("1234"),
                    AvatarColor = "#10B981",
                    RequirePinOnUnlock = false,
                    NotificationSound = true,
                    IsActive = true,
                    IsPrimary = true
                };
            }

            // Fayl keshidan yo'qolgan rasmlarni SQLite blob dan tiklash
            foreach (var p in cachedProds)
            {
                if (!string.IsNullOrWhiteSpace(p.ImageUrl) && (string.IsNullOrWhiteSpace(p.ImageLocalPath) || !System.IO.File.Exists(p.ImageLocalPath)))
                {
                    var (_, blob) = await _db.GetProductImageBlobAsync(p.Id);
                    if (blob != null && blob.Length > 0)
                    {
                        var (loc, h) = ImageCacheService.SaveBytesToCache(p.Id, blob, p.ImageHash);
                        p.ImageLocalPath = loc;
                        p.ImageHash = h;
                    }
                }
            }

            lock (_stateLock)
            {
                if (cachedDepts.Count > 0) _departments = cachedDepts;
                _products = cachedProds;
                _categories = cachedCats;
                _tables = cachedTables;
                _halls = cachedHalls;
                _printers = cachedPrinters;
                _cashierProfile = cachedCashier;
                _staffAccounts = cachedStaff;
                _ingredients = cachedIngredients;
                _suppliers = cachedSuppliers;
                _recipes = cachedRecipes;
            }

            _isLoadingTables = false;
            RenderTables();
            RenderQuickPosLevel();
            RenderStopList();
            RenderManageTab();
            UpdateInventoryLowStockBadge();
            UpdateCartUI();
            UpdateShiftReportUI();
            ApplySettingsToUI();
            ApplyCashierProfileToUI();
            UpdateSyncStatusSummaryText();

            // 3. Server bilan sinxronlash (Avval SyncEngine offline navbatni yuklaydi, keyin bootstrap oladi)
            await _syncEngine.RunSyncCycleAsync();
        }

        private static void AssignTableZones(List<RestaurantTable> tables, List<Hall>? halls = null)
        {
            foreach (var t in tables)
            {
                if (halls != null && t.HallId.HasValue)
                {
                    var match = halls.FirstOrDefault(h => h.Id == t.HallId.Value);
                    if (match != null)
                    {
                        t.Zone = match.Name;
                        continue;
                    }
                }
                if (string.IsNullOrWhiteSpace(t.Zone))
                {
                    if (t.Number <= 6) t.Zone = "Zal";
                    else if (t.Number <= 9) t.Zone = "Terrasa";
                    else t.Zone = "VIP";
                }
            }
        }

        private async void OnBootstrapSynced(object? sender, BootstrapResponse bootstrap)
        {
            var preserveNums = await _db.GetPendingTableNumbersAsync();
            var activeCalls = await _db.GetCachedWaiterCallsAsync(includeResolved: false);

            Dispatcher.Invoke(() =>
            {
                bool activeCartUpdatedFromServer = false;
                lock (_stateLock)
                {
                    if (bootstrap.Departments.Count > 0) _departments = bootstrap.Departments;
                    if (bootstrap.Categories.Count > 0) _categories = bootstrap.Categories;
                    if (bootstrap.Halls.Count > 0) _halls = bootstrap.Halls;
                    if (bootstrap.Printers.Count > 0) _printers = bootstrap.Printers;
                    if (bootstrap.Products.Count > 0)
                    {
                        var existingLocalById = _products
                            .Where(p => !string.IsNullOrWhiteSpace(p.ImageLocalPath))
                            .ToDictionary(p => p.Id, p => (p.ImageLocalPath, p.ImageHash, p.ImageUrl));
                        foreach (var srvP in bootstrap.Products)
                        {
                            if (string.IsNullOrWhiteSpace(srvP.ImageLocalPath) &&
                                existingLocalById.TryGetValue(srvP.Id, out var prevImg) &&
                                string.Equals(prevImg.ImageUrl, srvP.ImageUrl, StringComparison.OrdinalIgnoreCase))
                            {
                                srvP.ImageLocalPath = prevImg.ImageLocalPath;
                            }
                        }
                        _products = bootstrap.Products;
                        _productTileMap.Clear();
                    }
                    if (bootstrap.Staff.Count > 0) _staffAccounts = bootstrap.Staff;
                    if (bootstrap.CashierProfile != null && (!_settingsDirty || _activeSettingsSection != "profile"))
                    {
                        _cashierProfile = bootstrap.CashierProfile;
                        _settings.CashierName = bootstrap.CashierProfile.Name;
                    }

                    AssignTableZones(bootstrap.Tables, _halls);
                    var existingByNum = _tables.ToDictionary(t => t.Number, t => t);
                    var merged = new List<RestaurantTable>();

                    foreach (var srvT in bootstrap.Tables)
                    {
                        if (preserveNums.Contains(srvT.Number.ToString()) && existingByNum.TryGetValue(srvT.Number, out var localT))
                        {
                            merged.Add(localT);
                        }
                        else
                        {
                            var matchCall = activeCalls.FirstOrDefault(c => c.TableNumber == srvT.Number.ToString());
                            if (matchCall != null && srvT.ActiveCall == null)
                                srvT.ActiveCall = matchCall;
                            else if (srvT.ActiveCall != null && !activeCalls.Any(c => c.Id == srvT.ActiveCall.Id))
                                srvT.ActiveCall = null;
                            merged.Add(srvT);
                        }
                    }

                    if (merged.Count > 0)
                    {
                        _tables = merged;
                        if (_activeTableContext != null)
                        {
                            var updatedCtx = _tables.FirstOrDefault(t => t.Number == _activeTableContext.Number);
                            if (updatedCtx != null)
                            {
                                _activeTableContext = updatedCtx;
                                if (updatedCtx.ActiveOrder != null && string.IsNullOrWhiteSpace(_currentCart.OfflineId))
                                {
                                    _currentCart = updatedCtx.ActiveOrder;
                                    activeCartUpdatedFromServer = true;
                                }
                            }
                        }
                    }

                    if (bootstrap.Ingredients.Count > 0) _ingredients = bootstrap.Ingredients;
                    if (bootstrap.Suppliers.Count > 0) _suppliers = bootstrap.Suppliers;
                    if (bootstrap.Recipes.Count > 0) _recipes = bootstrap.Recipes;
                    if (bootstrap.InventorySummary != null) _inventoryKpi = bootstrap.InventorySummary;

                    if (bootstrap.Settings != null)
                    {
                        var keepServerUrl = _settings.ServerUrl;
                        var keepCashier = _settings.CashierName;
                        _settings = bootstrap.Settings;
                        if (!string.IsNullOrWhiteSpace(keepServerUrl)) _settings.ServerUrl = keepServerUrl;
                        if (!string.IsNullOrWhiteSpace(keepCashier)) _settings.CashierName = keepCashier;
                    }
                }

                UpdateInventoryLowStockBadge();
                RenderTables();
                RenderQuickPosLevel();
                RenderStopList();
                if (_activeTabTag == "manage")
                {
                    RenderManageTab();
                }
                else if (_activeTabTag == "inventory")
                {
                    RenderInventoryTab();
                }
                if (!_settingsDirty && _activeTabTag != "settings")
                {
                    ApplySettingsToUI();
                    ApplyCashierProfileToUI();
                }
                else
                {
                    RenderSettingsHallsList();
                }
                UpdateSyncStatusSummaryText();
                if (activeCartUpdatedFromServer)
                {
                    SyncProductInCartQuantities();
                    UpdateCartUI();
                }

                foreach (var call in activeCalls)
                {
                    if (call.Id > 0 && _notifiedCallIds.Add(call.Id))
                    {
                        Toast.Show($"Stol #{call.TableNumber}: {call.Reason}", ToastTone.Warning);
                    }
                }
            });
        }

        private void OnProductImagesSynced(object? sender, EventArgs e)
        {
            Dispatcher.Invoke(() =>
            {
                foreach (var prod in _products)
                {
                    if (_productTileMap.TryGetValue(prod.Id, out var tile))
                    {
                        tile.NotifyImageChanged();
                    }
                }
                if (_activeTabTag == "manage" && _activeManageSubTab == "products")
                {
                    RenderManageTab();
                }
                UpdateSyncStatusSummaryText();
            });
        }

        private void OnHubStateChanged(object? sender, EventArgs e)
        {
            Dispatcher.Invoke(() =>
            {
                RenderTables();
                UpdateShiftReportUI();
            });
        }

        private async void OnHubWaiterOrderReceived(object? sender, HubWaiterOrderEventArgs e)
        {
            Dispatcher.Invoke(() =>
            {
                Toast.Show($"Stol #{e.Table.Number}: Ofitsiantdan yangi buyurtma ({e.NewlyAddedItems.Sum(i => i.Quantity)} ta)", ToastTone.Info);
            });

            if (_settings.AutoPrintNetwork && e.NewlyAddedItems.Count > 0)
            {
                var slipOrder = new Order
                {
                    OrderNumber = e.Table.ActiveOrder?.OrderNumber ?? $"POS-{e.Table.Number}",
                    ServiceType = "dine_in",
                    TableNumber = e.Table.Number.ToString(),
                    WaiterName = e.Table.AssignedWaiter,
                    GuestsCount = e.Table.GuestsCount,
                    Items = e.NewlyAddedItems,
                };
                await PrintOrderKitchenSlipsAsync(slipOrder);
            }
        }

        private void OnHubWaiterOrderPaid(object? sender, HubOrderPaidEventArgs e)
        {
            Dispatcher.Invoke(() =>
            {
                _currentShift.TotalOrdersCount++;
                _currentShift.TotalRevenue += e.PaidOrder.TotalAmount;
                if (e.PaidOrder.PaymentMethod == "naqd") _currentShift.CashRevenue += e.PaidOrder.TotalAmount;
                else if (e.PaidOrder.PaymentMethod == "karta") _currentShift.CardRevenue += e.PaidOrder.TotalAmount;
                else _currentShift.CashRevenue += e.PaidOrder.TotalAmount;

                _currentShift.ServiceFeesCollected += e.PaidOrder.ServiceFeeAmount;
                _currentShift.DiscountsGiven += e.PaidOrder.DiscountAmount;
                UpdateShiftReportUI();

                if (_activeTableContext != null && _activeTableContext.Number == e.Table.Number)
                {
                    _activeTableContext = null;
                    _currentCart = new Order { ServiceType = "pickup" };
                    CartTitleText.Text = "Saboy";
                    CartSubtitleText.Text = "Kassir: " + _settings.CashierName;
                    SyncProductInCartQuantities();
                    UpdateCartUI();
                }

                Toast.Show($"Stol #{e.Table.Number} ofitsiant tomonidan yopildi ({e.PaidOrder.PaymentMethod})", ToastTone.Success);
            });
        }

        private void OnHubWaiterCallCreated(object? sender, HubWaiterCallEventArgs e)
        {
            Dispatcher.Invoke(() =>
            {
                Toast.Show($"Stol #{e.TableNumber}: {e.Reason}", ToastTone.Warning);
            });
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

            UpdateSyncStatusSummaryText(lastSync);
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
            ManageTab.Visibility = tag == "manage" ? Visibility.Visible : Visibility.Collapsed;
            InventoryTab.Visibility = tag == "inventory" ? Visibility.Visible : Visibility.Collapsed;
            SettingsTab.Visibility = tag == "settings" ? Visibility.Visible : Visibility.Collapsed;

            NavTablesBtn.IsChecked = tag == "tables";
            NavQuickPosBtn.IsChecked = tag == "quick_pos";
            NavStopListBtn.IsChecked = tag == "stop_list";
            NavOnlineBtn.IsChecked = tag == "online";
            NavShiftBtn.IsChecked = tag == "shift";
            NavManageBtn.IsChecked = tag == "manage";
            NavInventoryBtn.IsChecked = tag == "inventory";
            NavSettingsBtn.IsChecked = tag == "settings";

            ScreenTitleText.Text = tag switch
            {
                "tables" => "Stollar · Band",
                "quick_pos" => "Tezkor savdo",
                "stop_list" => "Stop-list",
                "online" => "Onlayn buyurtmalar",
                "shift" => "Smena",
                "manage" => "Boshqaruv",
                "inventory" => "Omborxona & Tex-karta",
                "settings" => "Sozlamalar",
                _ => "Dilkash POS"
            };

            if (tag == "manage")
            {
                RenderManageTab();
            }
            else if (tag == "inventory")
            {
                RenderInventoryTab();
            }
            else if (tag == "settings")
            {
                ApplyCashierProfileToUI();
                RenderSettingsHallsList();
                UpdateSyncStatusSummaryText();
            }

            if (tag == "quick_pos" && _activeTableContext == null)
            {
                if (_currentCart.ServiceType != "pickup" && !_isDemoMode)
                {
                    _currentCart = new Order { ServiceType = "pickup" };
                }
                CartTitleText.Text = "Saboy";
                CartSubtitleText.Text = "Kassir: " + GetActiveCashierName();
                RenderQuickPosLevel();
                SyncProductInCartQuantities();
                UpdateCartUI();
            }
            else if (tag == "quick_pos" && _activeTableContext != null)
            {
                CartTitleText.Text = $"{_activeTableContext.Name} · {_activeTableContext.Zone}";
                CartSubtitleText.Text = $"Ofitsiant: {_currentCart.WaiterName} · {_currentCart.GuestsCount} mehmon";
                RenderQuickPosLevel();
                SyncProductInCartQuantities();
                UpdateCartUI();
            }
            else if (tag == "shift")
            {
                UpdateShiftReportUI();
            }
        }

        private string GetActiveCashierName() =>
            !string.IsNullOrWhiteSpace(_cashierProfile.Name)
                ? _cashierProfile.Name
                : (!string.IsNullOrWhiteSpace(_settings.CashierName) ? _settings.CashierName : "Jasur Rahimov");

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
            if (_cashierProfile.RequirePinOnUnlock)
            {
                var entered = LockPinBox.Password.Trim();
                var enteredHash = LocalDatabase.ComputeSha256Hex(entered);
                var expectedHash = string.IsNullOrWhiteSpace(_cashierProfile.PinHash)
                    ? LocalDatabase.ComputeSha256Hex("1234")
                    : _cashierProfile.PinHash;
                if (!string.Equals(enteredHash, expectedHash, StringComparison.OrdinalIgnoreCase))
                {
                    LockPinErrorText.Visibility = Visibility.Visible;
                    LockPinBox.Password = "";
                    LockPinBox.Focus();
                    return;
                }
            }
            SetLockedState(false);
        }

        private void OnLockPinKeyDown(object sender, KeyEventArgs e)
        {
            if (e.Key == Key.Enter)
            {
                OnUnlockAppClick(sender, new RoutedEventArgs());
                e.Handled = true;
            }
        }

        public void SetLockedState(bool locked)
        {
            LockCashierNameText.Text = GetActiveCashierName();
            LockPinErrorText.Visibility = Visibility.Collapsed;
            LockPinBox.Password = "";
            if (locked && _cashierProfile.RequirePinOnUnlock)
            {
                LockPinPanel.Visibility = Visibility.Visible;
                LockSubtitleText.Text = "Davom ettirish uchun kassir PIN-kodini kiriting";
            }
            else
            {
                LockPinPanel.Visibility = Visibility.Collapsed;
                LockSubtitleText.Text = "Ishni davom ettirish uchun Ochish tugmasini bosing";
            }
            LockOverlay.Visibility = locked ? Visibility.Visible : Visibility.Collapsed;
            WorkspaceShellGrid.Effect = locked ? new BlurEffect { Radius = 10 } : null;
            if (locked && _cashierProfile.RequirePinOnUnlock)
            {
                Dispatcher.InvokeAsync(() => LockPinBox.Focus());
            }
        }
        #endregion

        #region 1. Stollar Xaritasi (Responsive Dynamic Zone-Sectioned Tables Map)
        private static string GetTableStatusKey(RestaurantTable tbl)
        {
            if (tbl.Status == "bill_printed") return "bill_printed";
            if (tbl.Status == "reserved") return "reserved";
            if (tbl.IsOccupied || tbl.Status == "occupied") return "occupied";
            return "empty";
        }

        private List<Hall> GetEffectiveOrderedHalls()
        {
            var result = new List<Hall>();
            var seen = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            foreach (var h in _halls.Where(x => x.IsActive).OrderBy(x => x.SortOrder).ThenBy(x => x.Id))
            {
                if (seen.Add(h.Name)) result.Add(h);
            }
            foreach (var t in _tables)
            {
                var z = string.IsNullOrWhiteSpace(t.Zone) ? "Zal" : t.Zone;
                if (seen.Add(z))
                {
                    result.Add(new Hall { Id = 0, Name = z, SortOrder = 999, IsActive = true });
                }
            }
            return result;
        }

        private void UpdateTableCounts()
        {
            var halls = GetEffectiveOrderedHalls();
            if (_currentTableFilter != "__all__" && !halls.Any(h => string.Equals(h.Name, _currentTableFilter, StringComparison.OrdinalIgnoreCase)))
            {
                _currentTableFilter = "__all__";
            }

            _hallFilters.Clear();
            _hallFilters.Add(new HallFilterVM("__all__", "Barchasi", _tables.Count, _currentTableFilter == "__all__"));
            foreach (var h in halls)
            {
                int cnt = _tables.Count(t => t.HallId == h.Id || string.Equals(t.Zone, h.Name, StringComparison.OrdinalIgnoreCase));
                _hallFilters.Add(new HallFilterVM(h.Name, h.Name, cnt, string.Equals(_currentTableFilter, h.Name, StringComparison.OrdinalIgnoreCase)));
            }

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
            if (_currentTableFilter != "__all__")
            {
                filtered = filtered.Where(t => string.Equals(t.Zone, _currentTableFilter, StringComparison.OrdinalIgnoreCase));
            }

            if (_selectedTableStatuses.Count > 0)
            {
                filtered = filtered.Where(t => _selectedTableStatuses.Contains(GetTableStatusKey(t)));
            }

            var filteredList = filtered.ToList();
            var orderedHalls = GetEffectiveOrderedHalls();

            foreach (var hall in orderedHalls)
            {
                var zoneTables = filteredList.Where(t =>
                    (hall.Id > 0 && t.HallId == hall.Id) ||
                    string.Equals(t.Zone, hall.Name, StringComparison.OrdinalIgnoreCase)).ToList();
                if (zoneTables.Count == 0) continue;

                int busyInZone = zoneTables.Count(t => GetTableStatusKey(t) is "occupied" or "bill_printed");
                var sec = new TableZoneSectionVM
                {
                    ZoneKey = hall.Name,
                    ZoneTitle = hall.Name.ToUpperInvariant(),
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
                var sec = _tableZoneSections.FirstOrDefault(s => string.Equals(s.ZoneKey, tbl.Zone, StringComparison.OrdinalIgnoreCase));
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
                if (_selectedTableStatuses.Count == 1 && _selectedTableStatuses.Contains("occupied"))
                {
                    TablesEmptyState.Title = "Hozircha band stollar yoʻq";
                    TablesEmptyState.Subtitle = "Yangi stol ochish uchun 'Boʻsh' filtrini bosing yoki barcha stollarni koʻring.";
                    TablesEmptyState.ActionLabel = "Barcha stollarni koʻrish";
                }
                else
                {
                    TablesEmptyState.Title = "Bu filtr boʻyicha stollar topilmadi";
                    TablesEmptyState.Subtitle = "Boshqa zal yoki holat filtrini tanlab koʻring.";
                    TablesEmptyState.ActionLabel = "Filtrni tozalash";
                }
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
                var kassaTargets = GetPrinterTargetsForDept("kassa");
                foreach (var target in kassaTargets)
                    await _printer.PrintPreChekAsync(t.ActiveOrder, target);
                t.Status = "bill_printed";
                await _db.SaveTableStateAsync(t);
                RefreshSingleTableCard(t);
                Toast.Show($"{t.Name} uchun hisob pre-cheki belgilandi", ToastTone.Success);
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
                var dialog = new OpenTableDialog(table.Number, table.Name, GetActiveCashierName());
                if (Dialogs.ShowModal(dialog, this) == true)
                {
                    lock (_stateLock)
                    {
                        table.IsOccupied = true;
                        table.Status = "occupied";
                        table.OpenedAt ??= DateTime.UtcNow.ToString("o");
                        table.GuestsCount = dialog.SelectedGuestsCount;
                        table.AssignedWaiter = dialog.WaiterName;
                        table.ActiveOrder = new Order
                        {
                            ServiceType = "dine_in",
                            TableNumber = table.Number.ToString(),
                            GuestsCount = table.GuestsCount,
                            WaiterName = dialog.WaiterName,
                            Status = "yangi",
                            OfflineId = Guid.NewGuid().ToString("N"),
                            CreatedAt = DateTime.UtcNow.ToString("o"),
                        };
                    }

                    await _db.SaveTableStateAsync(table);
                    _syncEngine.TriggerImmediateSync();

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
                WaiterName = table.AssignedWaiter ?? GetActiveCashierName()
            };

            _categoryNavStack.Clear();
            if (ProductSearchBox != null) ProductSearchBox.Text = "";
            CartTitleText.Text = $"{table.Name} · {table.Zone}";
            CartSubtitleText.Text = $"Ofitsiant: {_currentCart.WaiterName} · {_currentCart.GuestsCount} mehmon";
            SwitchToTab("quick_pos");
            SyncProductInCartQuantities();
            UpdateCartUI();
        }

        private void OnHallFilterClicked(object sender, RoutedEventArgs e)
        {
            if (sender is RadioButton rb && rb.Tag is HallFilterVM hf)
            {
                _currentTableFilter = hf.Key;
                foreach (var item in _hallFilters)
                {
                    item.IsSelected = string.Equals(item.Key, hf.Key, StringComparison.OrdinalIgnoreCase);
                }
                RenderTables();
            }
        }

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
            _currentTableFilter = "__all__";
            _selectedTableStatuses.Clear();
            StatusFilterEmptyChip.IsChecked = false;
            StatusFilterOccupiedChip.IsChecked = false;
            StatusFilterBillChip.IsChecked = false;
            StatusFilterReservedChip.IsChecked = false;
            RenderTables();
        }
        #endregion

        #region 2. Tezkor Savdo & Buyurtma Qabul Qilish (Katak Kategoriya Drill-Down + Savatcha)
        private int CountProductsRecursive(int categoryId)
        {
            int count = _products.Count(p => p.CategoryId == categoryId);
            foreach (var child in _categories.Where(c => c.IsActive && c.ParentId == categoryId))
            {
                count += CountProductsRecursive(child.Id);
            }
            return count;
        }

        private void RenderQuickPosLevel()
        {
            if (CategoryTilesItemsControl == null || ProductsItemsControl == null) return;
            EnsureProductTileMap();

            // Clean stale stack entries if categories changed after sync
            for (int i = _categoryNavStack.Count - 1; i >= 0; i--)
            {
                var matched = _categories.FirstOrDefault(c => c.Id == _categoryNavStack[i].Id && c.IsActive);
                if (matched == null)
                {
                    _categoryNavStack.RemoveAt(i);
                }
                else
                {
                    _categoryNavStack[i] = matched;
                }
            }

            _categoryBreadcrumbs.Clear();
            for (int i = 0; i < _categoryNavStack.Count; i++)
            {
                _categoryBreadcrumbs.Add(new CategoryBreadcrumbVM(_categoryNavStack[i].Id, _categoryNavStack[i].Name, i == _categoryNavStack.Count - 1));
            }
            QuickPosBackBtn.Visibility = _categoryNavStack.Count > 0 ? Visibility.Visible : Visibility.Collapsed;

            _categoryTiles.Clear();
            _visibleProductTiles.Clear();

            string query = (ProductSearchBox?.Text ?? "").Trim();
            if (!string.IsNullOrWhiteSpace(query))
            {
                foreach (var prod in _products.Where(p => p.Name.Contains(query, StringComparison.OrdinalIgnoreCase)))
                {
                    if (_productTileMap.TryGetValue(prod.Id, out var vm))
                    {
                        vm.InCartQty = _currentCart.Items.FirstOrDefault(i => i.ProductId == prod.Id)?.Quantity ?? 0;
                        vm.SyncAvailabilityFromModel();
                        _visibleProductTiles.Add(vm);
                    }
                }
                CategoryTilesItemsControl.Visibility = Visibility.Collapsed;
                ProductsItemsControl.Visibility = _visibleProductTiles.Count > 0 ? Visibility.Visible : Visibility.Collapsed;
                QuickPosLevelCountText.Text = $"{_visibleProductTiles.Count} ta natija";

                bool searchEmpty = _visibleProductTiles.Count == 0;
                ProductsScrollViewer.Visibility = searchEmpty ? Visibility.Collapsed : Visibility.Visible;
                ProductsEmptyState.Title = "Taom topilmadi";
                ProductsEmptyState.Subtitle = "Qidiruv soʻzini oʻzgartiring yoki kategoriyalarga qayting.";
                ProductsEmptyState.ActionLabel = "Qidiruvni tozalash";
                ProductsEmptyState.Visibility = searchEmpty ? Visibility.Visible : Visibility.Collapsed;
                return;
            }

            int? parentId = _categoryNavStack.Count > 0 ? _categoryNavStack[^1].Id : null;
            var childCats = _categories
                .Where(c => c.IsActive && (parentId.HasValue ? c.ParentId == parentId.Value : (!c.ParentId.HasValue || c.ParentId.Value <= 0)))
                .OrderBy(c => c.Name)
                .ToList();

            foreach (var cat in childCats)
            {
                int directProds = _products.Count(p => p.CategoryId == cat.Id);
                int subCats = _categories.Count(c => c.IsActive && c.ParentId == cat.Id);
                int totalProds = CountProductsRecursive(cat.Id);
                _categoryTiles.Add(new CategoryTileVM(cat, directProds, subCats, totalProds));
            }

            if (parentId.HasValue)
            {
                foreach (var prod in _products.Where(p => p.CategoryId == parentId.Value))
                {
                    if (_productTileMap.TryGetValue(prod.Id, out var vm))
                    {
                        vm.InCartQty = _currentCart.Items.FirstOrDefault(i => i.ProductId == prod.Id)?.Quantity ?? 0;
                        vm.SyncAvailabilityFromModel();
                        _visibleProductTiles.Add(vm);
                    }
                }
            }

            CategoryTilesItemsControl.Visibility = _categoryTiles.Count > 0 ? Visibility.Visible : Visibility.Collapsed;
            ProductsItemsControl.Visibility = _visibleProductTiles.Count > 0 ? Visibility.Visible : Visibility.Collapsed;

            if (parentId.HasValue)
            {
                if (_categoryTiles.Count > 0 && _visibleProductTiles.Count > 0)
                    QuickPosLevelCountText.Text = $"{_categoryTiles.Count} boʻlim · {_visibleProductTiles.Count} taom";
                else if (_categoryTiles.Count > 0)
                    QuickPosLevelCountText.Text = $"{_categoryTiles.Count} ta ichki boʻlim";
                else
                    QuickPosLevelCountText.Text = $"{_visibleProductTiles.Count} ta taom";
            }
            else
            {
                QuickPosLevelCountText.Text = $"{_categoryTiles.Count} ta kategoriya";
            }

            bool isEmpty = _categoryTiles.Count == 0 && _visibleProductTiles.Count == 0;
            ProductsScrollViewer.Visibility = isEmpty ? Visibility.Collapsed : Visibility.Visible;
            if (isEmpty)
            {
                ProductsEmptyState.Title = parentId.HasValue ? "Bu kategoriyada taom yoʻq" : "Kategoriyalar topilmadi";
                ProductsEmptyState.Subtitle = parentId.HasValue
                    ? "Boshqa kategoriyani tanlang yoki Boshqaruvdan taom qoʻshing."
                    : "Boshqaruv boʻlimidan yangi kategoriya qoʻshing.";
                ProductsEmptyState.ActionLabel = "Kategoriyalarga qaytish";
                ProductsEmptyState.Visibility = Visibility.Visible;
            }
            else
            {
                ProductsEmptyState.Visibility = Visibility.Collapsed;
            }
        }

        private void OnCategoryTileClicked(object? sender, CategoryTileVM vm)
        {
            _categoryNavStack.Add(vm.Model);
            RenderQuickPosLevel();
        }

        private void OnQuickPosBackClick(object sender, RoutedEventArgs e)
        {
            if (_categoryNavStack.Count > 0)
            {
                _categoryNavStack.RemoveAt(_categoryNavStack.Count - 1);
                RenderQuickPosLevel();
            }
        }

        private void OnQuickPosBreadcrumbRootClick(object sender, RoutedEventArgs e)
        {
            _categoryNavStack.Clear();
            if (!string.IsNullOrWhiteSpace(ProductSearchBox?.Text))
                ProductSearchBox.Text = "";
            else
                RenderQuickPosLevel();
        }

        private void OnQuickPosBreadcrumbItemClick(object sender, RoutedEventArgs e)
        {
            if (sender is Button btn && btn.Tag is CategoryBreadcrumbVM crumb)
            {
                int idx = _categoryNavStack.FindIndex(c => c.Id == crumb.Id);
                if (idx >= 0 && idx < _categoryNavStack.Count - 1)
                {
                    _categoryNavStack.RemoveRange(idx + 1, _categoryNavStack.Count - idx - 1);
                    RenderQuickPosLevel();
                }
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

            lock (_stateLock)
            {
                if (string.IsNullOrWhiteSpace(_currentCart.OfflineId))
                {
                    _currentCart.OfflineId = _currentCart.Id > 0
                        ? $"srv-{_currentCart.Id}-{Guid.NewGuid():N}"
                        : Guid.NewGuid().ToString("N");
                }
                if (string.IsNullOrWhiteSpace(_currentCart.OrderNumber))
                {
                    _currentCart.OrderNumber = $"POS-{DateTime.Now:HHmmss}";
                }
                if (_activeTableContext != null)
                {
                    _activeTableContext.ActiveOrder = _currentCart;
                    _activeTableContext.IsOccupied = true;
                    _activeTableContext.Status = _activeTableContext.Status == "bill_printed" ? "bill_printed" : "occupied";
                    _activeTableContext.OrderStatus = _currentCart.Status;
                    _activeTableContext.GuestsCount = Math.Max(1, _currentCart.GuestsCount);
                    if (string.IsNullOrWhiteSpace(_activeTableContext.AssignedWaiter))
                        _activeTableContext.AssignedWaiter = _currentCart.WaiterName ?? _settings.CashierName;
                }
            }

            if (_activeTableContext != null)
            {
                await _db.SaveTableStateAsync(_activeTableContext);
                RefreshSingleTableCard(_activeTableContext);
            }
            await _db.UpsertPendingSyncOrderAsync(_currentCart);
            await PrintOrderKitchenSlipsAsync(_currentCart);
            _syncEngine.TriggerImmediateSync();

            Toast.Show("Buyurtma saqlandi, boʻlimlarga va ofitsiantlarga yuborildi", ToastTone.Success);
        }

        private async void OnPrintPreChekClick(object sender, RoutedEventArgs e)
        {
            if (_currentCart.Items.Count == 0)
            {
                Toast.Show("Hisob cheki chiqarish uchun savatchaga taom qoʻshing", ToastTone.Warning);
                return;
            }

            if (_activeTableContext != null)
            {
                _activeTableContext.Status = "bill_printed";
                await _db.SaveTableStateAsync(_activeTableContext);
                RefreshSingleTableCard(_activeTableContext);
            }

            string kassaIp = GetPrinterIpForDept("kassa");
            if (string.IsNullOrEmpty(kassaIp))
            {
                Toast.Show("Stol hisob holatiga oʻtdi (Kassa printeri IP kiritilmagan)", ToastTone.Info);
                return;
            }

            var res = await _printer.PrintPreChekAsync(_currentCart, kassaIp);
            Toast.Show(res.Success ? "Mijoz uchun hisob pre-cheki chop etildi" : res.Message, res.Success ? ToastTone.Success : ToastTone.Warning);
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
                _currentCart.Status = _currentCart.ServiceType == "dine_in" ? "yetkazildi" : "olib_ketildi";
                if (string.IsNullOrWhiteSpace(_currentCart.OfflineId))
                {
                    _currentCart.OfflineId = _currentCart.Id > 0
                        ? $"srv-{_currentCart.Id}-{Guid.NewGuid():N}"
                        : Guid.NewGuid().ToString("N");
                }

                await _db.UpsertPendingSyncOrderAsync(_currentCart);
                await _db.DeductInventoryForOrderLocalAsync(_currentCart);
                _ingredients = await _db.GetCachedIngredientsAsync();
                UpdateInventoryLowStockBadge();
                if (_activeTabTag == "inventory")
                {
                    RenderInventoryTab();
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
                    RestaurantTable closed;
                    int? activeCallId = null;
                    lock (_stateLock)
                    {
                        closed = _activeTableContext;
                        if (closed.ActiveCall != null) activeCallId = closed.ActiveCall.Id;
                        closed.IsOccupied = false;
                        closed.Status = "empty";
                        closed.OrderStatus = null;
                        closed.GuestsCount = 0;
                        closed.AssignedWaiter = null;
                        closed.OpenedAt = null;
                        closed.ActiveOrder = null;
                        closed.ActiveCall = null;
                        _activeTableContext = null;
                    }
                    if (activeCallId.HasValue)
                        await _db.DismissWaiterCallOfflineAsync(activeCallId.Value);
                    await _db.SaveTableStateAsync(closed);
                    RefreshSingleTableCard(closed);
                }

                _currentCart = new Order { ServiceType = "pickup" };
                CartTitleText.Text = "Saboy";
                CartSubtitleText.Text = "Kassir: " + _settings.CashierName;
                SyncProductInCartQuantities();
                UpdateCartUI();
                _syncEngine.TriggerImmediateSync();

                Toast.Show("Toʻlov qabul qilindi va kassa cheki chop etildi", ToastTone.Success);
            }
        }

        private async Task PrintOrderKitchenSlipsAsync(Order order)
        {
            var distinctDepts = order.Items.Select(i => i.Department).Distinct();
            foreach (var dept in distinctDepts)
            {
                string name = GetDepartmentName(dept);
                foreach (string ip in GetPrinterTargetsForDept(dept))
                {
                    await _printer.PrintDepartmentSlipAsync(order, dept, name, ip);
                }
            }
        }

        private List<string> GetPrinterTargetsForDept(string dept)
        {
            string code = (dept ?? "").ToLowerInvariant() switch
            {
                "kassa" => "kassa",
                "shashlik" => "shashlik",
                "somsa" => "somsa",
                "kitchen" => "kitchen",
                "fastfood" => "fastfood",
                "bar" => "bar",
                _ => (dept ?? "kitchen").ToLowerInvariant()
            };

            var targets = _printerCardVMs
                .Where(p => p.IsActive && string.Equals(p.Code, code, StringComparison.OrdinalIgnoreCase) && !string.IsNullOrWhiteSpace(p.PrinterIp))
                .Select(p => p.PrinterIp.Trim())
                .Distinct()
                .ToList();

            if (targets.Count == 0 && _settings.Printers.TryGetValue(code, out var fallbackIp) && !string.IsNullOrWhiteSpace(fallbackIp))
            {
                targets.Add(fallbackIp.Trim());
            }
            return targets;
        }

        private string GetPrinterIpForDept(string dept) => GetPrinterTargetsForDept(dept).FirstOrDefault() ?? "";

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
            RenderQuickPosLevel();
        }

        private void OnResetProductFilter(object? sender, EventArgs e)
        {
            if (!string.IsNullOrWhiteSpace(ProductSearchBox.Text))
            {
                ProductSearchBox.Text = "";
            }
            else
            {
                _categoryNavStack.Clear();
            }
            RenderQuickPosLevel();
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
            if (ord.Id > 0)
            {
                await _api.AcceptOnlineOrderAsync(ord.Id);
            }
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
            string cashier = !string.IsNullOrWhiteSpace(_cashierProfile.Name)
                ? _cashierProfile.Name
                : (string.IsNullOrWhiteSpace(_settings.CashierName) ? _currentShift.CashierName : _settings.CashierName);
            var openedAt = _currentShift.OpenedAt == default ? DateTime.Today.AddHours(8).AddMinutes(30) : _currentShift.OpenedAt;

            SidebarCashierNameText.Text = cashier;
            ShiftHeaderInfoText.Text = $"Smena ochiq · {openedAt:HH:mm} dan · Kassir: {cashier}";
            if (ProfileShiftSummaryText != null)
            {
                ProfileShiftSummaryText.Text = $"Joriy smena: {_currentShift.TotalOrdersCount} ta chek · {MoneyFormatter.Format(_currentShift.TotalRevenue)}";
            }

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
        private readonly HashSet<PrinterCardVM> _dirtyPrinterCards = new();

        private void OnTopBarCashierProfileClick(object sender, RoutedEventArgs e)
        {
            SwitchToTab("settings");
            SwitchSettingsSection("profile");
        }

        private void OnSettingsSectionClick(object sender, RoutedEventArgs e)
        {
            if (sender is RadioButton rb && rb.Tag is string tag)
            {
                SwitchSettingsSection(tag);
            }
        }

        private void SwitchSettingsSection(string tag)
        {
            if (string.IsNullOrWhiteSpace(tag)) tag = "profile";
            _activeSettingsSection = tag;

            if (SettingsSectionProfile != null) SettingsSectionProfile.Visibility = tag == "profile" ? Visibility.Visible : Visibility.Collapsed;
            if (SettingsSectionPrinters != null) SettingsSectionPrinters.Visibility = tag == "printers" ? Visibility.Visible : Visibility.Collapsed;
            if (SettingsSectionHalls != null) SettingsSectionHalls.Visibility = tag == "halls" ? Visibility.Visible : Visibility.Collapsed;
            if (SettingsSectionServer != null) SettingsSectionServer.Visibility = tag == "server" ? Visibility.Visible : Visibility.Collapsed;
            if (SettingsSectionPayments != null) SettingsSectionPayments.Visibility = tag == "payments" ? Visibility.Visible : Visibility.Collapsed;
            if (SettingsSectionBot != null) SettingsSectionBot.Visibility = tag == "bot" ? Visibility.Visible : Visibility.Collapsed;

            if (SettingsNavProfileBtn != null) SettingsNavProfileBtn.IsChecked = tag == "profile";
            if (SettingsNavPrintersBtn != null) SettingsNavPrintersBtn.IsChecked = tag == "printers";
            if (SettingsNavHallsBtn != null) SettingsNavHallsBtn.IsChecked = tag == "halls";
            if (SettingsNavServerBtn != null) SettingsNavServerBtn.IsChecked = tag == "server";
            if (SettingsNavPaymentsBtn != null) SettingsNavPaymentsBtn.IsChecked = tag == "payments";
            if (SettingsNavBotBtn != null) SettingsNavBotBtn.IsChecked = tag == "bot";

            if (tag == "profile") ApplyCashierProfileToUI();
            else if (tag == "halls") RenderSettingsHallsList();
            else if (tag == "server") UpdateSyncStatusSummaryText();
        }

        private static List<PosPrinter> BuildDefaultPrintersFromSettings(PosSettings settings, List<Department> depts)
        {
            var defaults = new (string Code, string Name, string Subtitle, int Order)[]
            {
                ("kassa", "Kassa hisob printeri", "Mijoz cheki, X/Z hisobot", 1),
                ("shashlik", "Shashlikxona", "Mangal boʻlimi", 2),
                ("somsa", "Somsaxona", "Tandir boʻlimi", 3),
                ("kitchen", "Issiq oshxona", "Milliy issiq taomlar", 4),
                ("fastfood", "Fast-food", "Burger va lavash", 5),
                ("bar", "Bar va ichimliklar", "Choy, qahva, desertlar", 6)
            };

            var list = new List<PosPrinter>();
            foreach (var def in defaults)
            {
                var dept = depts.FirstOrDefault(d => string.Equals(d.Code, def.Code, StringComparison.OrdinalIgnoreCase));
                string rawIp = settings.Printers.TryGetValue(def.Code, out var savedIp) && !string.IsNullOrWhiteSpace(savedIp)
                    ? savedIp
                    : (dept?.PrinterIp ?? "");

                string ip = rawIp.Trim();
                int port = 9100;
                if (ip.Contains(':'))
                {
                    var parts = ip.Split(':', 2);
                    ip = parts[0].Trim();
                    if (int.TryParse(parts[1].Trim(), out int parsedPort) && parsedPort > 0)
                        port = parsedPort;
                }

                list.Add(new PosPrinter
                {
                    Name = !string.IsNullOrWhiteSpace(dept?.Name) ? dept!.Name : def.Name,
                    Department = def.Code,
                    Subtitle = !string.IsNullOrWhiteSpace(dept?.Subtitle) ? dept!.Subtitle : def.Subtitle,
                    IpAddress = ip,
                    Port = port,
                    PaperWidth = 80,
                    IsActive = true,
                    SortOrder = def.Order
                });
            }
            return list;
        }

        private void RebuildPrinterCards()
        {
            List<PosPrinter> snap;
            lock (_stateLock)
            {
                snap = _printers.OrderBy(p => p.SortOrder).ThenBy(p => p.Id).ToList();
            }

            _dirtyPrinterCards.Clear();
            _printerCardVMs.Clear();
            foreach (var pr in snap)
            {
                _printerCardVMs.Add(new PrinterCardVM(pr, pr.IsOnline));
            }
        }

        private void SyncPrintersToSettingsDict()
        {
            List<PosPrinter> snap;
            lock (_stateLock) snap = _printers.ToList();

            var keys = new HashSet<string>(StringComparer.OrdinalIgnoreCase)
            {
                "kassa", "shashlik", "somsa", "kitchen", "fastfood", "bar"
            };
            foreach (var p in snap)
            {
                if (!string.IsNullOrWhiteSpace(p.Department))
                    keys.Add(p.Department.Trim().ToLowerInvariant());
            }

            foreach (var dept in keys)
            {
                var firstActive = snap
                    .Where(p => string.Equals(p.Department, dept, StringComparison.OrdinalIgnoreCase)
                                && p.IsActive
                                && !string.IsNullOrWhiteSpace(p.IpAddress))
                    .OrderBy(p => p.SortOrder)
                    .ThenBy(p => p.Id)
                    .FirstOrDefault();
                _settings.Printers[dept] = firstActive?.EffectiveAddress ?? "";
            }
        }

        private void UpdateCashierVisuals(string name, string roleTitle, string phone, string avatarHex)
        {
            string displayName = string.IsNullOrWhiteSpace(name) ? "Jasur Rahimov" : name.Trim();
            string displayRole = string.IsNullOrWhiteSpace(roleTitle) ? "Kassir" : roleTitle.Trim();

            var parts = displayName.Split(' ', StringSplitOptions.RemoveEmptyEntries);
            string initials = parts.Length == 0
                ? "K"
                : parts.Length == 1
                    ? parts[0][..Math.Min(2, parts[0].Length)].ToUpperInvariant()
                    : $"{char.ToUpperInvariant(parts[0][0])}{char.ToUpperInvariant(parts[1][0])}";

            if (TopBarCashierInitialsText != null) TopBarCashierInitialsText.Text = initials;
            if (SidebarCashierNameText != null) SidebarCashierNameText.Text = displayName;
            if (TopBarCashierRoleText != null) TopBarCashierRoleText.Text = displayRole;
            if (LockCashierNameText != null) LockCashierNameText.Text = displayName;

            if (ProfileAvatarInitials != null) ProfileAvatarInitials.Text = initials;
            if (ProfileHeaderNameText != null) ProfileHeaderNameText.Text = displayName;
            if (ProfileHeaderRoleText != null) ProfileHeaderRoleText.Text = displayRole;
            if (ProfileHeaderPhoneText != null)
            {
                ProfileHeaderPhoneText.Text = string.IsNullOrWhiteSpace(phone) ? "Telefon kiritilmagan" : phone.Trim();
            }
            if (ProfileShiftSummaryText != null)
            {
                ProfileShiftSummaryText.Text = $"Joriy smena: {_currentShift.TotalOrdersCount} ta chek · {MoneyFormatter.Format(_currentShift.TotalRevenue)}";
            }

            try
            {
                if (ColorConverter.ConvertFromString(avatarHex) is Color c)
                {
                    var solid = new SolidColorBrush(c);
                    var tint = new SolidColorBrush(Color.FromArgb(38, c.R, c.G, c.B));
                    if (ProfileAvatarBorder != null)
                    {
                        ProfileAvatarBorder.BorderBrush = solid;
                        ProfileAvatarBorder.Background = tint;
                    }
                    if (ProfileAvatarInitials != null) ProfileAvatarInitials.Foreground = solid;
                    if (TopBarCashierAvatarBorder != null)
                    {
                        TopBarCashierAvatarBorder.BorderBrush = solid;
                        TopBarCashierAvatarBorder.Background = tint;
                    }
                    if (TopBarCashierInitialsText != null) TopBarCashierInitialsText.Foreground = solid;
                }
            }
            catch { }
        }

        private void ApplyCashierProfileToUI()
        {
            bool prev = _isApplyingSettings;
            _isApplyingSettings = true;
            try
            {
                string name = !string.IsNullOrWhiteSpace(_cashierProfile.Name)
                    ? _cashierProfile.Name
                    : (!string.IsNullOrWhiteSpace(_settings.CashierName) ? _settings.CashierName : "Jasur Rahimov");
                string phone = _cashierProfile.Phone ?? "";
                string role = string.IsNullOrWhiteSpace(_cashierProfile.RoleTitle) ? "Bosh kassir" : _cashierProfile.RoleTitle;
                _pendingAvatarColor = string.IsNullOrWhiteSpace(_cashierProfile.AvatarColor) ? "#10B981" : _cashierProfile.AvatarColor;

                if (CashierNameBox != null) CashierNameBox.Text = name;
                if (CashierPhoneBox != null) CashierPhoneBox.Text = phone;
                if (CashierRoleBox != null) CashierRoleBox.Text = role;
                if (CashierPinBox != null) CashierPinBox.Password = "";
                if (CashierPinConfirmBox != null) CashierPinConfirmBox.Password = "";
                if (RequirePinOnUnlockCheck != null) RequirePinOnUnlockCheck.IsChecked = _cashierProfile.RequirePinOnUnlock;
                if (NotificationSoundCheck != null) NotificationSoundCheck.IsChecked = _cashierProfile.NotificationSound;
                if (ProfileThemeToggleCheck != null) ProfileThemeToggleCheck.IsChecked = ThemeManager.IsDark;

                UpdateCashierVisuals(name, role, phone, _pendingAvatarColor);
            }
            finally
            {
                _isApplyingSettings = prev;
            }
        }

        private void UpdateSyncStatusSummaryText(DateTime? lastSyncOverride = null)
        {
            if (SyncImagesStatusText == null || SyncLastTimeText == null) return;

            List<Product> prodsSnap;
            lock (_stateLock) prodsSnap = _products.ToList();

            int withUrl = prodsSnap.Count(p => !string.IsNullOrWhiteSpace(p.ImageUrl));
            int cached = prodsSnap.Count(p => !string.IsNullOrWhiteSpace(p.ImageLocalPath) && System.IO.File.Exists(p.ImageLocalPath));

            SyncImagesStatusText.Text = withUrl > 0
                ? $"Rasmlar keshi: {cached}/{withUrl} ta taom rasmi lokal bazada tayyor"
                : "Hozircha taom rasmlari kiritilmagan";

            var syncTime = lastSyncOverride ?? _syncEngine.LastSyncTime;
            SyncLastTimeText.Text = syncTime > DateTime.MinValue
                ? $"Oxirgi sinxron: {syncTime:HH:mm:ss}"
                : "Oxirgi sinxron: kutilmoqda...";
        }

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
                RebuildPrinterCards();
                RenderSettingsHallsList();

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
                LocalHubInfoBox.Text = string.Join("  |  ", LocalWifiHubServer.GetLocalLanUrls());
                AutoPrintCheck.IsChecked = _settings.AutoPrintNetwork;

                ServiceStartTimeBox.Text = string.IsNullOrWhiteSpace(_settings.ServiceStartTime) ? "10:00" : _settings.ServiceStartTime;
                ServiceEndTimeBox.Text = string.IsNullOrWhiteSpace(_settings.ServiceEndTime) ? "22:00" : _settings.ServiceEndTime;
                DeliveryBaseCostBox.Text = _settings.DeliveryBaseCost.ToString("0");
                DeliveryExtraKmCostBox.Text = _settings.DeliveryCostPerExtraKmBlock.ToString("0");
                DeliveryMaxRadiusBox.Text = _settings.DeliveryMaxRadiusKm.ToString("0.#", CultureInfo.InvariantCulture);
                BroadcastTextBox.Text = _settings.BroadcastMessageText ?? "";

                ClickServiceIdBox.Text = _settings.ClickServiceId ?? "";
                ClickMerchantIdBox.Text = _settings.ClickMerchantId ?? "";
                ClickSecretBox.Text = "";
                ClickSecretField.HelperText = _settings.HasClickSecret ? "Saqlangan (oʻzgartirish uchun yangi kalit kiriting)" : "Kalit hali kiritilmagan";
                PaymeMerchantIdBox.Text = _settings.PaymeMerchantId ?? "";
                PaymeSecretBox.Text = "";
                PaymeSecretField.HelperText = _settings.HasPaymeSecret ? "Saqlangan" : "Kiritilmagan";

                ApplyCashierProfileToUI();
                UpdateSyncStatusSummaryText();
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
            if (sender is Controls.PrinterCard card && card.DataContext is PrinterCardVM vm)
            {
                _dirtyPrinterCards.Add(vm);
            }
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

        private void OnSettingsPasswordChanged(object sender, RoutedEventArgs e)
        {
            if (_isApplyingSettings) return;
            if (sender is PasswordBox pb && !pb.IsKeyboardFocusWithin) return;
            MarkSettingsDirty();
        }

        private void OnSelectAvatarColorClick(object sender, RoutedEventArgs e)
        {
            if (sender is Button btn && btn.Tag is string hex && !string.IsNullOrWhiteSpace(hex))
            {
                _pendingAvatarColor = hex;
                UpdateCashierVisuals(CashierNameBox.Text, CashierRoleBox.Text, CashierPhoneBox.Text, _pendingAvatarColor);
                MarkSettingsDirty();
            }
        }

        private void OnProfileThemeToggleClick(object sender, RoutedEventArgs e)
        {
            if (_isApplyingSettings) return;
            ThemeManager.ApplyTheme(ProfileThemeToggleCheck.IsChecked == true);
        }

        private void OnProfileOpenShiftClick(object sender, RoutedEventArgs e)
        {
            SwitchToTab("shift");
        }

        private async void OnSaveProfileQuickClick(object sender, RoutedEventArgs e)
        {
            await SaveCashierProfileAsync(showToast: true);
        }

        private async void OnManualSyncNowClick(object sender, RoutedEventArgs e)
        {
            _syncEngine.TriggerImmediateSync();
            Toast.Show("Baza va taom rasmlari sinxronizatsiyasi boshlandi...", ToastTone.Info);
            await Task.Delay(500);
            UpdateSyncStatusSummaryText();
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

        private async Task<bool> SaveCashierProfileAsync(bool showToast)
        {
            string name = (CashierNameBox?.Text ?? "").Trim();
            if (string.IsNullOrWhiteSpace(name))
            {
                Toast.Show("Kassir ismini kiriting", ToastTone.Warning);
                return false;
            }

            string pin = (CashierPinBox?.Password ?? "").Trim();
            string pinConfirm = (CashierPinConfirmBox?.Password ?? "").Trim();
            if (!string.IsNullOrEmpty(pin))
            {
                if (pin.Length < 4)
                {
                    Toast.Show("PIN-kod kamida 4 ta belgidan iborat boʻlsin", ToastTone.Warning);
                    return false;
                }
                if (!string.Equals(pin, pinConfirm, StringComparison.Ordinal))
                {
                    Toast.Show("Kiritilgan PIN-kodlar mos kelmadi", ToastTone.Warning);
                    return false;
                }
            }

            _cashierProfile.Name = name;
            _cashierProfile.Phone = (CashierPhoneBox?.Text ?? "").Trim();
            _cashierProfile.RoleTitle = string.IsNullOrWhiteSpace(CashierRoleBox?.Text) ? "Bosh kassir" : CashierRoleBox!.Text.Trim();
            _cashierProfile.AvatarColor = string.IsNullOrWhiteSpace(_pendingAvatarColor) ? "#10B981" : _pendingAvatarColor;
            _cashierProfile.RequirePinOnUnlock = RequirePinOnUnlockCheck?.IsChecked == true;
            _cashierProfile.NotificationSound = NotificationSoundCheck?.IsChecked != false;
            if (!string.IsNullOrEmpty(pin))
            {
                _cashierProfile.PinHash = LocalDatabase.ComputeSha256Hex(pin);
                _cashierProfile.HasPin = true;
            }

            _settings.CashierName = _cashierProfile.Name;
            await _db.SaveSettingAsync("cashier_name", _settings.CashierName);
            await _db.SaveLocalCashierProfileAsync(_cashierProfile, string.IsNullOrEmpty(pin) ? null : pin);

            var payload = new
            {
                id = _cashierProfile.Id > 0 ? (int?)_cashierProfile.Id : null,
                name = _cashierProfile.Name,
                phone = _cashierProfile.Phone,
                role_title = _cashierProfile.RoleTitle,
                pin = pin,
                avatar_color = _cashierProfile.AvatarColor,
                require_pin_on_unlock = _cashierProfile.RequirePinOnUnlock,
                notification_sound = _cashierProfile.NotificationSound,
                is_active = true,
                is_primary = true,
            };

            var (netOk, ok, serverProfile, err) = await _api.SaveCashierProfileAsync(payload);
            if (!netOk)
            {
                await _db.EnqueueAdminActionAsync(
                    "/api/pos/cashier-profile/save/",
                    System.Text.Json.JsonSerializer.Serialize(payload)
                );
            }
            else if (!ok)
            {
                Toast.Show(err, ToastTone.Warning);
                return false;
            }
            else if (serverProfile != null)
            {
                _cashierProfile.Id = serverProfile.Id;
                if (!string.IsNullOrWhiteSpace(serverProfile.PinHash))
                {
                    _cashierProfile.PinHash = serverProfile.PinHash;
                }
                _cashierProfile.HasPin = serverProfile.HasPin;
                await _db.SaveLocalCashierProfileAsync(_cashierProfile);
            }

            ApplyCashierProfileToUI();
            UpdateShiftReportUI();
            if (showToast)
            {
                SetSettingsDirty(false);
                Toast.Show(netOk ? "Kassir profili saqlandi" : "Kassir profili lokal saqlandi", ToastTone.Success);
            }
            return true;
        }

        private async void OnSaveSettingsClick(object sender, RoutedEventArgs e)
        {
            if (!await SaveCashierProfileAsync(showToast: false))
            {
                return;
            }

            var newServerUrl = ServerUrlBox.Text.Trim();
            _api.SetBaseUrl(newServerUrl);
            _settings.ServerUrl = newServerUrl;
            _settings.AutoPrintNetwork = AutoPrintCheck.IsChecked == true;

            await _db.SaveSettingAsync("server_url", newServerUrl);
            await _db.SaveSettingAsync("cashier_name", _settings.CashierName);

            foreach (var dirtyVm in _dirtyPrinterCards.ToList())
            {
                var pr = dirtyVm.Model;
                await _db.UpsertLocalPrinterAsync(pr);
                var prPayload = new
                {
                    id = pr.Id > 0 ? (int?)pr.Id : null,
                    name = pr.Name,
                    department = pr.Department,
                    ip_address = pr.IpAddress,
                    port = pr.Port,
                    paper_width = pr.PaperWidth,
                    subtitle = pr.Subtitle,
                    is_active = pr.IsActive,
                    sort_order = pr.SortOrder,
                };
                var (pNet, _, _, _) = await _api.SavePrinterAsync(prPayload);
                if (!pNet)
                {
                    await _db.EnqueueAdminActionAsync(
                        "/api/pos/printers/save/",
                        System.Text.Json.JsonSerializer.Serialize(prPayload));
                }
            }
            _dirtyPrinterCards.Clear();

            SyncPrintersToSettingsDict();

            if (ServiceFeeTypeCombo.SelectedItem is ComboBoxItem item && item.Tag is string feeType)
            {
                _settings.ServiceFeeType = feeType;
                if (decimal.TryParse(ServiceFeeValueBox.Text.Trim(), out decimal val))
                {
                    if (feeType == "percent") _settings.ServiceFeePercent = val;
                    else if (feeType == "per_person") _settings.ServiceFeePerPerson = val;
                }
            }

            _settings.ServiceStartTime = string.IsNullOrWhiteSpace(ServiceStartTimeBox.Text) ? "10:00" : ServiceStartTimeBox.Text.Trim();
            _settings.ServiceEndTime = string.IsNullOrWhiteSpace(ServiceEndTimeBox.Text) ? "22:00" : ServiceEndTimeBox.Text.Trim();
            if (decimal.TryParse(DeliveryBaseCostBox.Text.Trim(), out decimal baseCost)) _settings.DeliveryBaseCost = baseCost;
            if (decimal.TryParse(DeliveryExtraKmCostBox.Text.Trim(), out decimal extraCost)) _settings.DeliveryCostPerExtraKmBlock = extraCost;
            if (double.TryParse(DeliveryMaxRadiusBox.Text.Trim().Replace(',', '.'), NumberStyles.Float, CultureInfo.InvariantCulture, out double radius))
                _settings.DeliveryMaxRadiusKm = radius;
            _settings.BroadcastMessageText = BroadcastTextBox.Text.Trim();

            _settings.ClickServiceId = ClickServiceIdBox.Text.Trim();
            _settings.ClickMerchantId = ClickMerchantIdBox.Text.Trim();
            _settings.ClickSecretKey = ClickSecretBox.Text.Trim();
            _settings.PaymeMerchantId = PaymeMerchantIdBox.Text.Trim();
            _settings.PaymeSecretKey = PaymeSecretBox.Text.Trim();

            await _db.SaveFullSettingsLocalAsync(_settings);
            var (netOk, ok, err) = await _api.SaveFullSettingsAsync(_settings);
            if (!netOk)
            {
                await _db.EnqueueAdminActionAsync(
                    "/api/pos/settings/save/",
                    System.Text.Json.JsonSerializer.Serialize(ApiService.BuildSettingsSavePayload(_settings))
                );
            }
            else if (!ok)
            {
                Toast.Show(err, ToastTone.Warning);
                return;
            }
            else
            {
                if (!string.IsNullOrWhiteSpace(_settings.ClickSecretKey)) _settings.HasClickSecret = true;
                if (!string.IsNullOrWhiteSpace(_settings.PaymeSecretKey)) _settings.HasPaymeSecret = true;
                _settings.ClickSecretKey = "";
                _settings.PaymeSecretKey = "";
                ApplySettingsToUI();
            }

            UpdateShiftReportUI();
            UpdateCartUI();
            SetSettingsDirty(false);
            _syncEngine.TriggerImmediateSync();
            Toast.Show(netOk ? "Barcha sozlamalar Django va POS ga saqlandi" : "Sozlamalar lokal saqlandi (internet qaytganda yuklanadi)", ToastTone.Success);
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
            _halls = Demo.DemoData.GetDemoHalls();
            _printers = Demo.DemoData.GetDemoPrinters();
            _cashierProfile = Demo.DemoData.GetDemoCashierProfile();
            _ingredients = Demo.DemoData.GetDemoIngredients();
            _suppliers = Demo.DemoData.GetDemoSuppliers();
            _recipes = Demo.DemoData.GetDemoRecipes();
            _inventoryKpi = Demo.DemoData.GetDemoInventoryKpi(_ingredients);
            _supplies = Demo.DemoData.GetDemoSupplies();
            _movements = Demo.DemoData.GetDemoMovements();
            AssignTableZones(_tables, _halls);

            _currentCart = Demo.DemoData.GetDemoCart();
            _activeTableContext = _tables.FirstOrDefault(t => t.Number.ToString() == _currentCart.TableNumber);

            _selectedTableStatuses.Clear();
            _selectedTableStatuses.Add("occupied");
            if (StatusFilterEmptyChip != null) StatusFilterEmptyChip.IsChecked = false;
            if (StatusFilterOccupiedChip != null) StatusFilterOccupiedChip.IsChecked = true;
            if (StatusFilterBillChip != null) StatusFilterBillChip.IsChecked = false;
            if (StatusFilterReservedChip != null) StatusFilterReservedChip.IsChecked = false;

            _categoryNavStack.Clear();
            _stopListFilter = "all";
            StopFilterAllBtn.IsChecked = true;
            StopListSearchBox.Text = "";

            RenderTables();
            RenderQuickPosLevel();
            RenderStopList();
            RenderOnlineOrders();
            UpdateCartUI();
            UpdateShiftReportUI();
            ApplySettingsToUI();
            RenderManageTab();
            UpdateInventoryLowStockBadge();
            RenderInventoryTab();

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
            _categoryNavStack.Clear();
            ProductSearchBox.Text = empty ? "Mavjud boʻlmagan taom" : "";
            RenderQuickPosLevel();
        }

        public void SetDemoSettingsSection(string sectionTag)
        {
            SwitchSettingsSection(sectionTag);
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
