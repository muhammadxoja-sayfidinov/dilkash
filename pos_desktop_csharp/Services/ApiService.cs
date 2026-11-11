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
        public List<WaiterCall> WaiterCalls { get; set; } = new();
        public List<StaffAccount> Staff { get; set; } = new();
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
            _http = new HttpClient { Timeout = TimeSpan.FromSeconds(8) };
        }

        public void UpdateBaseUrl(string baseUrl)
        {
            if (string.IsNullOrWhiteSpace(baseUrl)) return;
            _baseUrl = baseUrl.Trim().TrimEnd('/');
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

        public async Task<List<string>> PushOfflineOrdersAsync(List<Order> orders)
        {
            var syncedIds = new List<string>();
            try
            {
                var url = $"{_baseUrl}/api/pos/sync/push/";
                var payload = new { orders };
                var res = await _http.PostAsJsonAsync(url, payload, _jsonOptions);
                if (res.IsSuccessStatusCode)
                {
                    UpdateStatus(true);
                    var doc = await res.Content.ReadFromJsonAsync<JsonElement>();
                    if (doc.TryGetProperty("synced_ids", out var idsElem) && idsElem.ValueKind == JsonValueKind.Array)
                    {
                        foreach (var el in idsElem.EnumerateArray())
                        {
                            var s = el.GetString();
                            if (!string.IsNullOrEmpty(s)) syncedIds.Add(s);
                        }
                    }
                }
            }
            catch
            {
                UpdateStatus(false);
            }
            return syncedIds;
        }
    }
}

