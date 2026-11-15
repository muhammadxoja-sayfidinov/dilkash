using System;
using System.Collections.Generic;
using System.Net.Http;
using System.Net.Http.Json;
using System.Text.Json;
using System.Threading.Tasks;
using DilkashPos.Models;

namespace DilkashPos.Services
{
    public class BootstrapResponse
    {
        public string Status { get; set; } = "";
        public string ServerTime { get; set; } = "";
        public PosSettings? Settings { get; set; }
        public List<Department> Departments { get; set; } = new();
        public List<Category> Categories { get; set; } = new();
        public List<Product> Products { get; set; } = new();
        public List<int> StopList { get; set; } = new();
        public List<RestaurantTable> Tables { get; set; } = new();
        public List<Hall> Halls { get; set; } = new();
        public List<PosPrinter> Printers { get; set; } = new();
        public CashierProfile? CashierProfile { get; set; }
        public List<CashierProfile> Cashiers { get; set; } = new();
        public List<WaiterCall> WaiterCalls { get; set; } = new();
        public List<StaffAccount> Staff { get; set; } = new();
        public List<Ingredient> Ingredients { get; set; } = new();
        public List<Supplier> Suppliers { get; set; } = new();
        public List<RecipeItem> Recipes { get; set; } = new();
        public InventoryKpiSummary? InventorySummary { get; set; }
    }

    public class SyncPushResponse
    {
        public string Status { get; set; } = "";
        public int SyncedCount { get; set; }
        public List<string> SyncedIds { get; set; } = new();
        public Dictionary<string, int> ServerIdMap { get; set; } = new();
        public string ServerTime { get; set; } = "";
    }

    public class ApiService
    {
        private static readonly JsonSerializerOptions _jsonOptions = new()
        {
            PropertyNameCaseInsensitive = true,
            PropertyNamingPolicy = JsonNamingPolicy.SnakeCaseLower,
        };

        private readonly HttpClient _http;
        private string _baseUrl;

        public bool IsOnline { get; private set; } = false;
        public string BaseUrl => _baseUrl;
        public event EventHandler<bool>? ConnectivityChanged;

        public ApiService(string baseUrl = "https://dilkash-django-production.up.railway.app")
        {
            _baseUrl = baseUrl.TrimEnd('/');
            ImageCacheService.ActiveBaseUrl = _baseUrl;
            _http = new HttpClient { Timeout = TimeSpan.FromSeconds(8) };
        }

        public async Task<SyncPushResponse?> PushSyncStateAsync(
            List<Order> orders,
            List<int>? dismissedCallIds = null,
            List<string>? billRequestedTables = null)
        {
            try
            {
                var payload = new
                {
                    orders = orders,
                    dismissed_call_ids = dismissedCallIds ?? new List<int>(),
                    bill_requested_tables = billRequestedTables ?? new List<string>(),
                };
                var json = System.Text.Json.JsonSerializer.Serialize(payload, _jsonOptions);
                using var content = new StringContent(json, System.Text.Encoding.UTF8, "application/json");
                using var resp = await _http.PostAsync($"{_baseUrl}/api/pos/sync/push/", content);
                if (!resp.IsSuccessStatusCode) return null;
                var body = await resp.Content.ReadAsStringAsync();
                UpdateStatus(true);
                return System.Text.Json.JsonSerializer.Deserialize<SyncPushResponse>(body, _jsonOptions);
            }
            catch
            {
                UpdateStatus(false);
                return null;
            }
        }

        public async Task<bool> DismissWaiterCallAsync(int callId)
        {
            try
            {
                using var content = new StringContent("{}", System.Text.Encoding.UTF8, "application/json");
                using var resp = await _http.PostAsync($"{_baseUrl}/api/pos/waiter-calls/{callId}/dismiss/", content);
                return resp.IsSuccessStatusCode;
            }
            catch
            {
                return false;
            }
        }

        public void SetBaseUrl(string url)
        {
            _baseUrl = url.TrimEnd('/');
            ImageCacheService.ActiveBaseUrl = _baseUrl;
        }

        private void UpdateStatus(bool online)
        {
            if (IsOnline != online)
            {
                IsOnline = online;
                ConnectivityChanged?.Invoke(this, online);
            }
        }

        public async Task<BootstrapResponse?> GetBootstrapAsync()
        {
            try
            {
                var url = $"{_baseUrl}/api/pos/bootstrap/";
                var res = await _http.GetFromJsonAsync<BootstrapResponse>(url, _jsonOptions);
                UpdateStatus(true);
                return res;
            }
            catch
            {
                UpdateStatus(false);
                return null;
            }
        }

        public async Task<List<Order>> GetOnlineOrdersAsync()
        {
            try
            {
                var url = $"{_baseUrl}/api/pos/online-orders/";
                var doc = await _http.GetFromJsonAsync<JsonElement>(url, _jsonOptions);
                UpdateStatus(true);
                if (doc.TryGetProperty("orders", out var ordersElem))
                {
                    var orders = JsonSerializer.Deserialize<List<Order>>(ordersElem.GetRawText(), _jsonOptions);
                    return orders ?? new List<Order>();
                }
            }
            catch
            {
                UpdateStatus(false);
            }
            return new List<Order>();
        }

        public async Task<Order?> CreateOrUpdateOrderAsync(Order order)
        {
            try
            {
                var url = $"{_baseUrl}/api/pos/orders/";
                var payload = new
                {
                    id = order.Id > 0 ? (int?)order.Id : null,
                    offline_id = order.OfflineId,
                    service_type = order.ServiceType,
                    table_number = order.TableNumber,
                    guests_count = order.GuestsCount,
                    waiter_name = order.WaiterName,
                    payment_method = order.PaymentMethod,
                    is_paid = order.IsPaid,
                    discount_percent = order.DiscountPercent,
                    discount_amount = order.DiscountAmount,
                    notes = order.Notes,
                    customer_name = order.CustomerName,
                    customer_phone = order.CustomerPhone,
                    items = order.Items.ConvertAll(i => new
                    {
                        product_id = i.ProductId,
                        quantity = i.Quantity,
                        price = i.Price
                    })
                };

                var res = await _http.PostAsJsonAsync(url, payload, _jsonOptions);
                if (res.IsSuccessStatusCode)
                {
                    UpdateStatus(true);
                    var doc = await res.Content.ReadFromJsonAsync<JsonElement>();
                    if (doc.TryGetProperty("order", out var oElem))
                    {
                        return JsonSerializer.Deserialize<Order>(oElem.GetRawText(), _jsonOptions);
                    }
                }
            }
            catch
            {
                UpdateStatus(false);
            }
            return null;
        }

        public async Task<Order?> PayOrderAsync(int orderId, string paymentMethod, decimal paidCash, decimal paidCard)
        {
            try
            {
                var url = $"{_baseUrl}/api/pos/orders/{orderId}/pay/";
                var payload = new
                {
                    payment_method = paymentMethod,
                    paid_cash = paidCash,
                    paid_card = paidCard
                };

                var res = await _http.PostAsJsonAsync(url, payload, _jsonOptions);
                if (res.IsSuccessStatusCode)
                {
                    UpdateStatus(true);
                    var doc = await res.Content.ReadFromJsonAsync<JsonElement>();
                    if (doc.TryGetProperty("order", out var oElem))
                    {
                        return JsonSerializer.Deserialize<Order>(oElem.GetRawText(), _jsonOptions);
                    }
                }
            }
            catch
            {
                UpdateStatus(false);
            }
            return null;
        }

        public async Task<bool> ToggleStopListAsync(int productId, bool? isAvailable = null)
        {
            try
            {
                var url = $"{_baseUrl}/api/pos/products/{productId}/toggle-stop/";
                object payload = isAvailable.HasValue ? new { is_available = isAvailable.Value } : new { };
                var res = await _http.PostAsJsonAsync(url, payload, _jsonOptions);
                if (res.IsSuccessStatusCode)
                {
                    UpdateStatus(true);
                    return true;
                }
            }
            catch
            {
                UpdateStatus(false);
            }
            return false;
        }

        public async Task<Order?> OpenTableAsync(int tableNumber, int guestsCount, string waiterName)
        {
            try
            {
                var url = $"{_baseUrl}/api/pos/tables/";
                var payload = new
                {
                    action = "open",
                    table_number = tableNumber.ToString(),
                    guests_count = guestsCount,
                    waiter_name = waiterName
                };

                var res = await _http.PostAsJsonAsync(url, payload, _jsonOptions);
                if (res.IsSuccessStatusCode)
                {
                    UpdateStatus(true);
                    var doc = await res.Content.ReadFromJsonAsync<JsonElement>();
                    if (doc.TryGetProperty("order", out var oElem))
                    {
                        return JsonSerializer.Deserialize<Order>(oElem.GetRawText(), _jsonOptions);
                    }
                }
            }
            catch
            {
                UpdateStatus(false);
            }
            return null;
        }

        public async Task<bool> AcceptOnlineOrderAsync(int orderId)
        {
            try
            {
                var url = $"{_baseUrl}/api/pos/online-orders/{orderId}/action/";
                var payload = new { action = "accept" };
                var res = await _http.PostAsJsonAsync(url, payload, _jsonOptions);
                if (res.IsSuccessStatusCode)
                {
                    UpdateStatus(true);
                    return true;
                }
            }
            catch
            {
                UpdateStatus(false);
            }
            return false;
        }

        public async Task<(bool NetworkOk, bool Success, JsonElement Doc, string Error)> PostAdminAsync(string path, object payload)
        {
            try
            {
                var json = System.Text.Json.JsonSerializer.Serialize(payload, _jsonOptions);
                using var content = new StringContent(json, System.Text.Encoding.UTF8, "application/json");
                using var resp = await _http.PostAsync($"{_baseUrl}{path}", content);
                var bodyText = await resp.Content.ReadAsStringAsync();
                UpdateStatus(true);

                JsonElement doc = default;
                if (!string.IsNullOrWhiteSpace(bodyText))
                {
                    try { doc = System.Text.Json.JsonSerializer.Deserialize<JsonElement>(bodyText); } catch { }
                }

                if (resp.IsSuccessStatusCode)
                {
                    return (true, true, doc, "");
                }

                string err = $"Server xatoligi ({(int)resp.StatusCode})";
                if (doc.ValueKind == JsonValueKind.Object)
                {
                    if (doc.TryGetProperty("error", out var e1)) err = e1.GetString() ?? err;
                    else if (doc.TryGetProperty("message", out var e2)) err = e2.GetString() ?? err;
                }
                return (true, false, doc, err);
            }
            catch
            {
                UpdateStatus(false);
                return (false, false, default, "Internet / Server bilan aloqa yo'q");
            }
        }

        public async Task<bool> ReplayPendingAdminActionAsync(string endpoint, string rawJson)
        {
            try
            {
                using var content = new StringContent(rawJson, System.Text.Encoding.UTF8, "application/json");
                using var resp = await _http.PostAsync($"{_baseUrl}{endpoint}", content);
                UpdateStatus(true);
                return (int)resp.StatusCode < 500;
            }
            catch
            {
                UpdateStatus(false);
                return false;
            }
        }

        public async Task<(bool NetworkOk, bool Success, Category? Category, string Error)> SaveCategoryAsync(object payload)
        {
            var (net, ok, doc, err) = await PostAdminAsync("/api/pos/categories/save/", payload);
            Category? cat = null;
            if (ok && doc.ValueKind == JsonValueKind.Object && doc.TryGetProperty("category", out var el))
            {
                cat = System.Text.Json.JsonSerializer.Deserialize<Category>(el.GetRawText(), _jsonOptions);
            }
            return (net, ok, cat, err);
        }

        public Task<(bool NetworkOk, bool Success, JsonElement Doc, string Error)> DeleteCategoryAsync(int categoryId) =>
            PostAdminAsync($"/api/pos/categories/{categoryId}/delete/", new { });

        public async Task<(bool NetworkOk, bool Success, Product? Product, string Error)> SaveProductAsync(object payload)
        {
            var (net, ok, doc, err) = await PostAdminAsync("/api/pos/products/save/", payload);
            Product? prod = null;
            if (ok && doc.ValueKind == JsonValueKind.Object && doc.TryGetProperty("product", out var el))
            {
                prod = System.Text.Json.JsonSerializer.Deserialize<Product>(el.GetRawText(), _jsonOptions);
            }
            return (net, ok, prod, err);
        }

        public Task<(bool NetworkOk, bool Success, JsonElement Doc, string Error)> DeleteProductAsync(int productId) =>
            PostAdminAsync($"/api/pos/products/{productId}/delete/", new { });

        public async Task<(bool NetworkOk, bool Success, StaffAccount? Staff, string Error)> SaveStaffAsync(object payload)
        {
            var (net, ok, doc, err) = await PostAdminAsync("/api/pos/staff/save/", payload);
            StaffAccount? st = null;
            if (ok && doc.ValueKind == JsonValueKind.Object && doc.TryGetProperty("staff", out var el))
            {
                st = System.Text.Json.JsonSerializer.Deserialize<StaffAccount>(el.GetRawText(), _jsonOptions);
            }
            return (net, ok, st, err);
        }

        public Task<(bool NetworkOk, bool Success, JsonElement Doc, string Error)> ToggleStaffAsync(string role, int staffId) =>
            PostAdminAsync($"/api/pos/staff/{role}/{staffId}/toggle/", new { });

        public Task<(bool NetworkOk, bool Success, JsonElement Doc, string Error)> DeleteStaffAsync(string role, int staffId) =>
            PostAdminAsync($"/api/pos/staff/{role}/{staffId}/delete/", new { });

        public async Task<(bool NetworkOk, bool Success, RestaurantTable? Table, string Error)> SaveTableAsync(object payload)
        {
            var (net, ok, doc, err) = await PostAdminAsync("/api/pos/tables/save/", payload);
            RestaurantTable? tbl = null;
            if (ok && doc.ValueKind == JsonValueKind.Object && doc.TryGetProperty("table", out var el))
            {
                tbl = System.Text.Json.JsonSerializer.Deserialize<RestaurantTable>(el.GetRawText(), _jsonOptions);
            }
            return (net, ok, tbl, err);
        }

        public Task<(bool NetworkOk, bool Success, JsonElement Doc, string Error)> DeleteTableAsync(int tableId) =>
            PostAdminAsync($"/api/pos/tables/{tableId}/delete/", new { });

        public async Task<byte[]?> DownloadBytesAsync(string url)
        {
            try
            {
                using var resp = await _http.GetAsync(url);
                if (!resp.IsSuccessStatusCode) return null;
                return await resp.Content.ReadAsByteArrayAsync();
            }
            catch
            {
                return null;
            }
        }

        public async Task<(bool NetworkOk, bool Success, Hall? Hall, string Error)> SaveHallAsync(object payload)
        {
            var (net, ok, doc, err) = await PostAdminAsync("/api/pos/halls/save/", payload);
            Hall? hall = null;
            if (ok && doc.ValueKind == JsonValueKind.Object && doc.TryGetProperty("hall", out var el))
            {
                hall = JsonSerializer.Deserialize<Hall>(el.GetRawText(), _jsonOptions);
            }
            return (net, ok, hall, err);
        }

        public Task<(bool NetworkOk, bool Success, JsonElement Doc, string Error)> DeleteHallAsync(int hallId) =>
            PostAdminAsync($"/api/pos/halls/{hallId}/delete/", new { });

        public async Task<(bool NetworkOk, bool Success, PosPrinter? Printer, string Error)> SavePrinterAsync(object payload)
        {
            var (net, ok, doc, err) = await PostAdminAsync("/api/pos/printers/save/", payload);
            PosPrinter? pr = null;
            if (ok && doc.ValueKind == JsonValueKind.Object && doc.TryGetProperty("printer", out var el))
            {
                pr = JsonSerializer.Deserialize<PosPrinter>(el.GetRawText(), _jsonOptions);
            }
            return (net, ok, pr, err);
        }

        public Task<(bool NetworkOk, bool Success, JsonElement Doc, string Error)> DeletePrinterAsync(int printerId) =>
            PostAdminAsync($"/api/pos/printers/{printerId}/delete/", new { });

        public async Task<(bool NetworkOk, bool Success, CashierProfile? Profile, string Error)> SaveCashierProfileAsync(object payload)
        {
            var (net, ok, doc, err) = await PostAdminAsync("/api/pos/cashier-profile/save/", payload);
            CashierProfile? cp = null;
            if (ok && doc.ValueKind == JsonValueKind.Object && doc.TryGetProperty("cashier_profile", out var el))
            {
                cp = JsonSerializer.Deserialize<CashierProfile>(el.GetRawText(), _jsonOptions);
            }
            return (net, ok, cp, err);
        }

        public async Task<(bool NetworkOk, bool Success, string Error)> SaveFullSettingsAsync(PosSettings settings)
        {
            var payload = BuildSettingsSavePayload(settings);
            var (net, ok, _, err) = await PostAdminAsync("/api/pos/settings/save/", payload);
            return (net, ok, err);
        }

        public static object BuildSettingsSavePayload(PosSettings settings) => new
        {
            service_fee_type = settings.ServiceFeeType,
            service_fee_percent = settings.ServiceFeePercent,
            service_fee_per_person = settings.ServiceFeePerPerson,
            auto_print_network = settings.AutoPrintNetwork,
            service_start_time = settings.ServiceStartTime,
            service_end_time = settings.ServiceEndTime,
            delivery_base_cost = settings.DeliveryBaseCost,
            delivery_cost_per_extra_km_block = settings.DeliveryCostPerExtraKmBlock,
            delivery_max_radius_km = settings.DeliveryMaxRadiusKm,
            broadcast_message_text = settings.BroadcastMessageText,
            click_service_id = settings.ClickServiceId,
            click_merchant_id = settings.ClickMerchantId,
            click_secret_key = settings.ClickSecretKey,
            payme_merchant_id = settings.PaymeMerchantId,
            payme_secret_key = settings.PaymeSecretKey,
            printers = settings.Printers,
        };

        // ==============================================================================
        // OMBORXONA VA KALKULYATSIYA API METODLARI
        // ==============================================================================

        public async Task<(bool NetworkOk, bool Success, Ingredient? Ingredient, string Error)> SaveIngredientAsync(object payload)
        {
            var (net, ok, doc, err) = await PostAdminAsync("/api/pos/inventory/ingredients/save/", payload);
            Ingredient? ing = null;
            if (ok && doc.ValueKind == JsonValueKind.Object && doc.TryGetProperty("ingredient", out var el))
            {
                ing = JsonSerializer.Deserialize<Ingredient>(el.GetRawText(), _jsonOptions);
            }
            return (net, ok, ing, err);
        }

        public Task<(bool NetworkOk, bool Success, JsonElement Doc, string Error)> DeleteIngredientAsync(int ingredientId) =>
            PostAdminAsync($"/api/pos/inventory/ingredients/{ingredientId}/delete/", new { });

        public async Task<(bool NetworkOk, bool Success, Supplier? Supplier, string Error)> SaveSupplierAsync(object payload)
        {
            var (net, ok, doc, err) = await PostAdminAsync("/api/pos/inventory/suppliers/save/", payload);
            Supplier? sup = null;
            if (ok && doc.ValueKind == JsonValueKind.Object && doc.TryGetProperty("supplier", out var el))
            {
                sup = JsonSerializer.Deserialize<Supplier>(el.GetRawText(), _jsonOptions);
            }
            return (net, ok, sup, err);
        }

        public Task<(bool NetworkOk, bool Success, JsonElement Doc, string Error)> DeleteSupplierAsync(int supplierId) =>
            PostAdminAsync($"/api/pos/inventory/suppliers/{supplierId}/delete/", new { });

        public async Task<(bool NetworkOk, bool Success, StockSupply? Supply, string Error)> CreateSupplyAsync(object payload)
        {
            var (net, ok, doc, err) = await PostAdminAsync("/api/pos/inventory/supplies/create/", payload);
            StockSupply? supply = null;
            if (ok && doc.ValueKind == JsonValueKind.Object && doc.TryGetProperty("supply", out var el))
            {
                supply = JsonSerializer.Deserialize<StockSupply>(el.GetRawText(), _jsonOptions);
            }
            return (net, ok, supply, err);
        }

        public async Task<(bool NetworkOk, bool Success, StockWriteOff? WriteOff, string Error)> CreateWriteOffAsync(object payload)
        {
            var (net, ok, doc, err) = await PostAdminAsync("/api/pos/inventory/write-offs/create/", payload);
            StockWriteOff? wo = null;
            if (ok && doc.ValueKind == JsonValueKind.Object && doc.TryGetProperty("write_off", out var el))
            {
                wo = JsonSerializer.Deserialize<StockWriteOff>(el.GetRawText(), _jsonOptions);
            }
            return (net, ok, wo, err);
        }

        public async Task<(bool NetworkOk, bool Success, List<RecipeItem> Recipes, string Error)> SaveRecipeAsync(int productId, object payload)
        {
            var (net, ok, doc, err) = await PostAdminAsync($"/api/pos/inventory/recipes/{productId}/save/", payload);
            var list = new List<RecipeItem>();
            if (ok && doc.ValueKind == JsonValueKind.Object && doc.TryGetProperty("recipes", out var el) && el.ValueKind == JsonValueKind.Array)
            {
                list = JsonSerializer.Deserialize<List<RecipeItem>>(el.GetRawText(), _jsonOptions) ?? new();
            }
            return (net, ok, list, err);
        }

        public async Task<(bool NetworkOk, bool Success, List<StockMovementLogItem> Movements, string Error)> GetMovementsAsync(int? ingredientId = null, string? type = null, int limit = 50)
        {
            string url = $"/api/pos/inventory/movements/?limit={limit}";
            if (ingredientId.HasValue) url += $"&ingredient_id={ingredientId.Value}";
            if (!string.IsNullOrWhiteSpace(type)) url += $"&type={type}";

            var list = new List<StockMovementLogItem>();
            try
            {
                var resp = await _http.GetAsync($"{_baseUrl}{url}");
                if (!resp.IsSuccessStatusCode)
                {
                    return (true, false, list, $"Server xatosi: {resp.StatusCode}");
                }
                var doc = await resp.Content.ReadFromJsonAsync<JsonElement>();
                if (doc.ValueKind == JsonValueKind.Object && doc.TryGetProperty("movements", out var el) && el.ValueKind == JsonValueKind.Array)
                {
                    list = JsonSerializer.Deserialize<List<StockMovementLogItem>>(el.GetRawText(), _jsonOptions) ?? new();
                }
                return (true, true, list, "");
            }
            catch (Exception ex)
            {
                return (false, false, list, ex.Message);
            }
        }
    }
}

