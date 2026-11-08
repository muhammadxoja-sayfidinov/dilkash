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
    }

    public class ApiService
    {
        private readonly HttpClient _http;
        private string _baseUrl;

        public bool IsOnline { get; private set; } = false;
        public event EventHandler<bool>? ConnectivityChanged;

        public ApiService(string baseUrl = "http://127.0.0.1:8000")
        {
            _baseUrl = baseUrl.TrimEnd('/');
            _http = new HttpClient { Timeout = TimeSpan.FromSeconds(3.5) };
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
                var res = await _http.GetFromJsonAsync<BootstrapResponse>(url, new JsonSerializerOptions
                {
                    PropertyNameCaseInsensitive = true
                });
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
                var doc = await _http.GetFromJsonAsync<JsonElement>(url);
                UpdateStatus(true);
                if (doc.TryGetProperty("orders", out var ordersElem))
                {
                    var orders = JsonSerializer.Deserialize<List<Order>>(ordersElem.GetRawText(), new JsonSerializerOptions
                    {
                        PropertyNameCaseInsensitive = true
                    });
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
                    payment_method = order.PaymentMethod,
                    is_paid = order.IsPaid,
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

                var res = await _http.PostAsJsonAsync(url, payload);
                if (res.IsSuccessStatusCode)
                {
                    UpdateStatus(true);
                    var doc = await res.Content.ReadFromJsonAsync<JsonElement>();
                    if (doc.TryGetProperty("order", out var oElem))
                    {
                        return JsonSerializer.Deserialize<Order>(oElem.GetRawText(), new JsonSerializerOptions
                        {
                            PropertyNameCaseInsensitive = true
                        });
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

                var res = await _http.PostAsJsonAsync(url, payload);
                if (res.IsSuccessStatusCode)
                {
                    UpdateStatus(true);
                    var doc = await res.Content.ReadFromJsonAsync<JsonElement>();
                    if (doc.TryGetProperty("order", out var oElem))
                    {
                        return JsonSerializer.Deserialize<Order>(oElem.GetRawText(), new JsonSerializerOptions
                        {
                            PropertyNameCaseInsensitive = true
                        });
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
                var res = await _http.PostAsJsonAsync(url, payload);
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

                var res = await _http.PostAsJsonAsync(url, payload);
                if (res.IsSuccessStatusCode)
                {
                    UpdateStatus(true);
                    var doc = await res.Content.ReadFromJsonAsync<JsonElement>();
                    if (doc.TryGetProperty("order", out var oElem))
                    {
                        return JsonSerializer.Deserialize<Order>(oElem.GetRawText(), new JsonSerializerOptions
                        {
                            PropertyNameCaseInsensitive = true
                        });
                    }
                }
            }
            catch
            {
                UpdateStatus(false);
            }
            return null;
        }

        public async Task<List<string>> PushOfflineOrdersAsync(List<Order> orders)
        {
            var syncedIds = new List<string>();
            try
            {
                var url = $"{_baseUrl}/api/pos/sync/push/";
                var payload = new { orders };
                var res = await _http.PostAsJsonAsync(url, payload);
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

