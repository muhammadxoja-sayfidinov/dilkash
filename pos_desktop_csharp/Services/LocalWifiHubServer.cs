using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Net;
using System.Net.NetworkInformation;
using System.Net.Sockets;
using System.Text;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;
using DilkashPos.Data;
using DilkashPos.Models;

namespace DilkashPos.Services
{
    public class HubWaiterOrderEventArgs : EventArgs
    {
        public RestaurantTable Table { get; set; } = new();
        public List<OrderItem> NewlyAddedItems { get; set; } = new();
    }

    public class HubOrderPaidEventArgs : EventArgs
    {
        public Order PaidOrder { get; set; } = new();
        public RestaurantTable Table { get; set; } = new();
    }

    public class HubWaiterCallEventArgs : EventArgs
    {
        public string TableNumber { get; set; } = "";
        public string Reason { get; set; } = "";
    }

    /// <summary>
    /// Embedded Local Wi-Fi Hub Server inside Dilkash POS Desktop.
    /// Runs without Administrator rights via TcpListener (HTTP :8088) and UdpClient (Discovery :8089).
    /// Waiter mobile apps connect EXCLUSIVELY to this Hub on restaurant Wi-Fi, even with zero internet.
    /// </summary>
    public class LocalWifiHubServer : IDisposable
    {
        public const int DefaultHttpPort = 8088;
        public const int DefaultDiscoveryPort = 8089;

        private readonly int _httpPort;
        private readonly int _discoveryPort;
        private readonly LocalDatabase _db;
        private readonly object _stateLock;
        private readonly Func<List<RestaurantTable>> _getTables;
        private readonly Func<List<Category>> _getCategories;
        private readonly Func<List<Product>> _getProducts;
        private readonly Func<PosSettings> _getSettings;
        private readonly Func<bool> _getCloudOnline;
        private readonly Action? _onRequestImmediateSync;

        private TcpListener? _tcpListener;
        private UdpClient? _udpClient;
        private CancellationTokenSource? _cts;
        private int _localItemSeq = 100000;

        private static readonly JsonSerializerOptions _snakeJson = new()
        {
            PropertyNamingPolicy = JsonNamingPolicy.SnakeCaseLower,
            PropertyNameCaseInsensitive = true,
        };

        public bool IsRunning { get; private set; }
        public int HttpPort => _httpPort;
        public int DiscoveryPort => _discoveryPort;

        public event EventHandler? HubStateChanged;
        public event EventHandler<HubWaiterOrderEventArgs>? WaiterOrderReceived;
        public event EventHandler<HubOrderPaidEventArgs>? WaiterOrderPaid;
        public event EventHandler<HubWaiterCallEventArgs>? WaiterCallCreated;

        public LocalWifiHubServer(
            LocalDatabase db,
            object stateLock,
            Func<List<RestaurantTable>> getTables,
            Func<List<Category>> getCategories,
            Func<List<Product>> getProducts,
            Func<PosSettings> getSettings,
            Func<bool> getCloudOnline,
            Action? onRequestImmediateSync = null,
            int httpPort = DefaultHttpPort,
            int discoveryPort = DefaultDiscoveryPort)
        {
            _db = db;
            _stateLock = stateLock;
            _getTables = getTables;
            _getCategories = getCategories;
            _getProducts = getProducts;
            _getSettings = getSettings;
            _getCloudOnline = getCloudOnline;
            _onRequestImmediateSync = onRequestImmediateSync;
            _httpPort = httpPort;
            _discoveryPort = discoveryPort;
        }

        public static List<string> GetLocalLanUrls(int port = DefaultHttpPort)
        {
            var urls = new List<string>();
            try
            {
                foreach (var ni in NetworkInterface.GetAllNetworkInterfaces())
                {
                    if (ni.OperationalStatus != OperationalStatus.Up) continue;
                    if (ni.NetworkInterfaceType == NetworkInterfaceType.Loopback) continue;
                    var desc = (ni.Description + " " + ni.Name).ToLowerInvariant();
                    if (desc.Contains("virtual") || desc.Contains("vmware") || desc.Contains("hyper-v") || desc.Contains("vethernet"))
                        continue;

                    foreach (var ua in ni.GetIPProperties().UnicastAddresses)
                    {
                        if (ua.Address.AddressFamily == AddressFamily.InterNetwork && !IPAddress.IsLoopback(ua.Address))
                        {
                            urls.Add($"http://{ua.Address}:{port}");
                        }
                    }
                }
            }
            catch { }

            if (urls.Count == 0)
            {
                urls.Add($"http://127.0.0.1:{port}");
            }
            return urls.Distinct().ToList();
        }

        public void Start()
        {
            if (IsRunning) return;
            _cts = new CancellationTokenSource();

            _tcpListener = new TcpListener(IPAddress.Any, _httpPort);
            _tcpListener.Server.SetSocketOption(SocketOptionLevel.Socket, SocketOptionName.ReuseAddress, true);
            _tcpListener.Start(64);

            try
            {
                _udpClient = new UdpClient();
                _udpClient.Client.SetSocketOption(SocketOptionLevel.Socket, SocketOptionName.ReuseAddress, true);
                _udpClient.Client.Bind(new IPEndPoint(IPAddress.Any, _discoveryPort));
                _udpClient.EnableBroadcast = true;
            }
            catch (SocketException)
            {
                try { _udpClient?.Dispose(); } catch { }
                _udpClient = null;
            }

            IsRunning = true;

            _ = Task.Run(() => AcceptHttpLoopAsync(_cts.Token));
            if (_udpClient != null)
            {
                _ = Task.Run(() => UdpDiscoveryLoopAsync(_cts.Token));
            }
        }

        public void Stop()
        {
            IsRunning = false;
            try { _cts?.Cancel(); } catch { }
            try { _tcpListener?.Stop(); } catch { }
            try { _udpClient?.Close(); } catch { }
            _tcpListener = null;
            _udpClient = null;
        }

        public void Dispose()
        {
            Stop();
            _cts?.Dispose();
        }

        private async Task UdpDiscoveryLoopAsync(CancellationToken ct)
        {
            try
            {
                if (_udpClient == null) return;

                while (!ct.IsCancellationRequested)
                {
                    var result = await _udpClient.ReceiveAsync(ct);
                    var msg = Encoding.UTF8.GetString(result.Buffer).Trim();
                    if (msg.StartsWith("DILKASH_DISCOVER", StringComparison.OrdinalIgnoreCase))
                    {
                        var payload = JsonSerializer.Serialize(new
                        {
                            service = "dilkash-pos-hub",
                            version = "1.0",
                            port = _httpPort,
                            machine = Environment.MachineName,
                            urls = GetLocalLanUrls(_httpPort),
                        }, _snakeJson);
                        var reply = Encoding.UTF8.GetBytes(payload);
                        await _udpClient.SendAsync(reply, reply.Length, result.RemoteEndPoint);
                    }
                }
            }
            catch (OperationCanceledException) { }
            catch (SocketException)
            {
                // Port 8089 may already be bound in multi-instance test setups; HTTP still serves requests.
            }
            catch { }
        }

        private async Task AcceptHttpLoopAsync(CancellationToken ct)
        {
            while (!ct.IsCancellationRequested && _tcpListener != null)
            {
                try
                {
                    var client = await _tcpListener.AcceptTcpClientAsync(ct);
                    _ = Task.Run(() => HandleTcpClientAsync(client, ct), ct);
                }
                catch (OperationCanceledException)
                {
                    break;
                }
                catch
                {
                    if (!IsRunning) break;
                }
            }
        }

        private async Task HandleTcpClientAsync(TcpClient client, CancellationToken ct)
        {
            using (client)
            {
                client.ReceiveTimeout = 8000;
                client.SendTimeout = 8000;
                try
                {
                    using var stream = client.GetStream();
                    var req = await ReadHttpRequestAsync(stream, ct);
                    if (req == null) return;

                    if (string.Equals(req.Method, "OPTIONS", StringComparison.OrdinalIgnoreCase))
                    {
                        await WriteHttpResponseAsync(stream, 204, "No Content", "");
                        return;
                    }

                    var (statusCode, jsonBody) = await RouteRequestAsync(req.Method, req.Path, req.Body);
                    await WriteHttpResponseAsync(stream, statusCode, statusCode == 200 ? "OK" : "Error", jsonBody);
                }
                catch
                {
                    // Ignore aborted client sockets cleanly
                }
            }
        }

        private sealed class HttpRequestData
        {
            public string Method { get; init; } = "GET";
            public string Path { get; init; } = "/";
            public string Body { get; init; } = "";
        }

        private static async Task<HttpRequestData?> ReadHttpRequestAsync(NetworkStream stream, CancellationToken ct)
        {
            var headerBytes = new List<byte>(2048);
            var singleByte = new byte[1];
            int matchState = 0;

            while (headerBytes.Count < 32768)
            {
                int read = await stream.ReadAsync(singleByte, 0, 1, ct);
                if (read == 0)
                {
                    if (headerBytes.Count == 0) return null;
                    break;
                }
                byte b = singleByte[0];
                headerBytes.Add(b);
                if ((matchState == 0 && b == '\r') ||
                    (matchState == 1 && b == '\n') ||
                    (matchState == 2 && b == '\r') ||
                    (matchState == 3 && b == '\n'))
                {
                    matchState++;
                    if (matchState == 4) break;
                }
                else
                {
                    matchState = (b == '\r') ? 1 : 0;
                }
            }

            var headerText = Encoding.UTF8.GetString(headerBytes.ToArray());
            var lines = headerText.Split(new[] { "\r\n" }, StringSplitOptions.RemoveEmptyEntries);
            if (lines.Length == 0) return null;

            var reqLineParts = lines[0].Split(' ', StringSplitOptions.RemoveEmptyEntries);
            if (reqLineParts.Length < 2) return null;

            var method = reqLineParts[0].ToUpperInvariant();
            var rawTarget = reqLineParts[1];
            var qIdx = rawTarget.IndexOf('?');
            var path = qIdx >= 0 ? rawTarget[..qIdx] : rawTarget;

            int contentLength = 0;
            foreach (var line in lines.Skip(1))
            {
                var colon = line.IndexOf(':');
                if (colon > 0)
                {
                    var name = line[..colon].Trim();
                    var val = line[(colon + 1)..].Trim();
                    if (string.Equals(name, "Content-Length", StringComparison.OrdinalIgnoreCase))
                    {
                        int.TryParse(val, out contentLength);
                    }
                }
            }

            string body = "";
            if (contentLength > 0 && contentLength <= 2_000_000)
            {
                var buf = new byte[contentLength];
                int offset = 0;
                while (offset < contentLength)
                {
                    int n = await stream.ReadAsync(buf, offset, contentLength - offset, ct);
                    if (n == 0) break;
                    offset += n;
                }
                body = Encoding.UTF8.GetString(buf, 0, offset);
            }

            return new HttpRequestData { Method = method, Path = path, Body = body };
        }

        private static async Task WriteHttpResponseAsync(NetworkStream stream, int statusCode, string reason, string jsonBody)
        {
            var bodyBytes = Encoding.UTF8.GetBytes(jsonBody);
            var headers = new StringBuilder();
            headers.Append($"HTTP/1.1 {statusCode} {reason}\r\n");
            headers.Append("Content-Type: application/json; charset=utf-8\r\n");
            headers.Append($"Content-Length: {bodyBytes.Length}\r\n");
            headers.Append("Access-Control-Allow-Origin: *\r\n");
            headers.Append("Access-Control-Allow-Methods: GET, POST, OPTIONS\r\n");
            headers.Append("Access-Control-Allow-Headers: Content-Type, Authorization\r\n");
            headers.Append("Connection: close\r\n\r\n");

            var headerBytes = Encoding.ASCII.GetBytes(headers.ToString());
            await stream.WriteAsync(headerBytes, 0, headerBytes.Length);
            if (bodyBytes.Length > 0)
                await stream.WriteAsync(bodyBytes, 0, bodyBytes.Length);
            await stream.FlushAsync();
        }

        private static string JsonError(string message) =>
            JsonSerializer.Serialize(new { success = false, message, error = message });

        private async Task<(int StatusCode, string Body)> RouteRequestAsync(string method, string path, string bodyText)
        {
            var normPath = "/" + path.Trim('/');
            if (normPath != "/") normPath += "/";

            try
            {
                if (method == "GET" && (normPath == "/" || normPath == "/health/"))
                {
                    int tblCount;
                    lock (_stateLock) tblCount = _getTables().Count;
                    return (200, JsonSerializer.Serialize(new
                    {
                        status = "ok",
                        service = "dilkash-pos-hub",
                        cloud_online = _getCloudOnline(),
                        tables_count = tblCount,
                        lan_urls = GetLocalLanUrls(_httpPort),
                        server_time = DateTime.UtcNow.ToString("o"),
                    }));
                }

                if (method == "POST" && normPath == "/api/mobile/staff/login/")
                    return await HandleStaffLoginAsync(bodyText);

                if (method == "GET" && normPath == "/api/mobile/customer/menu/")
                    return HandleCustomerMenu();

                if (method == "GET" && normPath == "/api/waiter/floor-status/")
                    return await HandleWaiterFloorStatusAsync();

                if (method == "POST" && normPath.StartsWith("/api/waiter/table/") && normPath.EndsWith("/assign/"))
                {
                    var seg = normPath["/api/waiter/table/".Length..^"/assign/".Length].Trim('/');
                    return await HandleAssignTableAsync(seg, bodyText);
                }

                if (method == "POST" && normPath == "/api/waiter/order/create/")
                    return await HandleWaiterCreateOrderAsync(bodyText);

                if (method == "POST" && normPath.StartsWith("/api/table/order/item/") && normPath.EndsWith("/update/"))
                {
                    var seg = normPath["/api/table/order/item/".Length..^"/update/".Length].Trim('/');
                    if (int.TryParse(seg, out int itemId))
                        return await HandleUpdateOrderItemAsync(itemId, bodyText);
                }

                if (method == "POST" && normPath.StartsWith("/api/waiter/bill-request/"))
                {
                    var seg = normPath["/api/waiter/bill-request/".Length..].Trim('/');
                    return await HandleBillRequestAsync(seg);
                }

                if (method == "POST" && (normPath.StartsWith("/api/waiter/call/") || normPath.StartsWith("/api/pos/waiter-calls/")) && normPath.EndsWith("/dismiss/"))
                {
                    var prefix = normPath.StartsWith("/api/waiter/call/") ? "/api/waiter/call/" : "/api/pos/waiter-calls/";
                    var seg = normPath[prefix.Length..^"/dismiss/".Length].Trim('/');
                    if (int.TryParse(seg, out int callId))
                        return await HandleDismissCallAsync(callId);
                }

                if (method == "POST" && normPath.StartsWith("/api/waiter/order/") && normPath.EndsWith("/deliver/"))
                {
                    var seg = normPath["/api/waiter/order/".Length..^"/deliver/".Length].Trim('/');
                    if (int.TryParse(seg, out int orderId))
                        return await HandleDeliverOrderAsync(orderId);
                }

                if (method == "POST" && normPath.StartsWith("/api/waiter/order/") && normPath.EndsWith("/close/"))
                {
                    var seg = normPath["/api/waiter/order/".Length..^"/close/".Length].Trim('/');
                    if (int.TryParse(seg, out int orderId))
                        return await HandleCloseOrderAsync(orderId, bodyText);
                }

                return (404, JsonError($"Endpoint topilmadi: {method} {normPath}"));
            }
            catch (Exception ex)
            {
                return (500, JsonError($"POS Hub xatoligi: {ex.Message}"));
            }
        }

        private async Task<(int, string)> HandleStaffLoginAsync(string bodyText)
        {
            using var doc = ParseJsonBody(bodyText);
            var phone = GetString(doc, "phone") ?? "";
            var pin = GetString(doc, "pin") ?? "";

            var matches = await _db.VerifyStaffLoginOfflineAsync(phone, pin);
            if (matches.Count == 0)
            {
                return (401, JsonError("Telefon raqam yoki PIN kod noto'g'ri"));
            }

            var waiter = matches.FirstOrDefault(m => m.Role == "waiter");
            var courier = matches.FirstOrDefault(m => m.Role == "courier");
            var roles = matches.Select(m => m.Role).Distinct().ToList();
            var primary = waiter ?? courier ?? matches[0];

            var payload = new
            {
                status = "success",
                success = true,
                role = roles[0],
                assigned_roles = roles,
                user = new
                {
                    id = primary.Id,
                    waiter_id = waiter?.Id,
                    courier_id = courier?.Id,
                    name = primary.Name,
                    phone = primary.Phone,
                    staff_code = string.IsNullOrWhiteSpace(primary.StaffCode) ? $"DIL-{primary.Id}" : primary.StaffCode,
                    token = primary.Token,
                    waiter_token = waiter?.Token,
                    courier_token = courier?.Token,
                    assigned_roles = roles,
                    active_role = roles[0],
                    vehicle_info = courier?.VehicleInfo ?? "",
                },
                waiter = waiter == null ? null : new { id = waiter.Id, name = waiter.Name, phone = waiter.Phone, token = waiter.Token },
                courier = courier == null ? null : new { id = courier.Id, name = courier.Name, phone = courier.Phone, token = courier.Token, vehicle_info = courier.VehicleInfo },
            };
            return (200, JsonSerializer.Serialize(payload));
        }

        private (int, string) HandleCustomerMenu()
        {
            List<Category> cats;
            List<Product> prods;
            lock (_stateLock)
            {
                cats = _getCategories().Select(c => new Category { Id = c.Id, Name = c.Name, Department = c.Department, Description = c.Description }).ToList();
                prods = _getProducts().Select(p => new Product
                {
                    Id = p.Id,
                    Name = p.Name,
                    Price = p.Price,
                    CategoryId = p.CategoryId,
                    CategoryName = p.CategoryName,
                    Department = p.Department,
                    IsAvailable = p.IsAvailable,
                    Description = p.Description,
                    ImageUrl = p.ImageUrl,
                }).ToList();
            }

            var grouped = cats.Select(c => new
            {
                id = c.Id,
                name = c.Name,
                description = c.Description,
                department = c.Department,
                products = prods.Where(p => p.CategoryId == c.Id || string.Equals(p.CategoryName, c.Name, StringComparison.OrdinalIgnoreCase))
                    .Select(p => new
                    {
                        id = p.Id,
                        name = p.Name,
                        price = (double)p.Price,
                        description = p.Description,
                        is_available = p.IsAvailable,
                        image_url = p.ImageUrl,
                    }).ToList()
            }).ToList();

            return (200, JsonSerializer.Serialize(new { success = true, categories = grouped }));
        }

        private async Task<(int, string)> HandleWaiterFloorStatusAsync()
        {
            var activeCalls = await _db.GetCachedWaiterCallsAsync(includeResolved: false);
            var callByTable = activeCalls
                .GroupBy(c => LocalDatabase.NormalizeTableNumber(c.TableNumber))
                .ToDictionary(g => g.Key, g => g.First());

            List<object> tablePayloads = new();
            PosSettings settings;
            lock (_stateLock)
            {
                settings = _getSettings();
                foreach (var t in _getTables().OrderBy(x => x.Number))
                {
                    var normNum = t.Number.ToString();
                    var call = t.ActiveCall != null && !t.ActiveCall.IsResolved
                        ? t.ActiveCall
                        : (callByTable.TryGetValue(normNum, out var dbCall) ? dbCall : null);

                    var ord = t.ActiveOrder;
                    if (ord != null)
                    {
                        foreach (var item in ord.Items)
                        {
                            if (item.Id <= 0)
                                item.Id = Interlocked.Increment(ref _localItemSeq);
                        }
                    }

                    string stage = "free";
                    if (t.Status == "bill_printed" || (call != null && (call.Reason.Contains("Hisob", StringComparison.OrdinalIgnoreCase) || call.Reason.Contains("Chek", StringComparison.OrdinalIgnoreCase))))
                        stage = "billRequested";
                    else if (ord != null)
                        stage = ord.Status == "tayor" ? "ready" : "occupied";

                    object? callObj = call == null ? null : new
                    {
                        id = call.Id,
                        table_number = normNum,
                        reason = call.Reason,
                        created_at = call.CreatedAt,
                    };

                    int effectiveOrderId = ord == null ? 0 : (ord.Id > 0 ? ord.Id : 900000 + t.Number);
                    object? orderObj = ord == null ? null : new
                    {
                        id = effectiveOrderId,
                        order_number = string.IsNullOrWhiteSpace(ord.OrderNumber) ? $"POS-{t.Number}" : ord.OrderNumber,
                        offline_id = ord.OfflineId,
                        status = ord.Status,
                        guests_count = ord.GuestsCount,
                        products_total = (double)ord.ProductsTotal,
                        service_fee_amount = (double)ord.ServiceFeeAmount,
                        total_amount = (double)ord.TotalAmount,
                        waiter_name = ord.WaiterName ?? t.AssignedWaiter,
                        items = ord.Items.Select(it => new
                        {
                            id = it.Id,
                            product_id = it.ProductId,
                            dish_name = it.ProductName,
                            name = it.ProductName,
                            quantity = it.Quantity,
                            price = (double)it.Price,
                            total = (double)it.Total,
                            status = ord.Status == "tayor" ? "ready" : "cooking",
                        }).ToList(),
                    };

                    tablePayloads.Add(new
                    {
                        id = t.Id > 0 ? t.Id : t.Number,
                        number = t.Number,
                        table_number = normNum,
                        name = string.IsNullOrWhiteSpace(t.Name) ? $"Stol #{t.Number}" : t.Name,
                        zone = t.Zone,
                        capacity = t.Capacity,
                        guests_count = ord?.GuestsCount ?? t.GuestsCount,
                        is_occupied = t.IsOccupied || ord != null,
                        status = t.Status,
                        stage,
                        assigned_waiter_name = t.AssignedWaiter,
                        call = callObj,
                        order = orderObj,
                    });
                }
            }

            var allCallPayloads = activeCalls.Select(c => new
            {
                id = c.Id,
                table_number = LocalDatabase.NormalizeTableNumber(c.TableNumber),
                reason = c.Reason,
                created_at = c.CreatedAt,
            }).ToList();

            return (200, JsonSerializer.Serialize(new
            {
                success = true,
                source = "pos_local_hub",
                cloud_online = _getCloudOnline(),
                service_fee_percent = (double)settings.ServiceFeePercent,
                tables = tablePayloads,
                waiter_calls = allCallPayloads,
            }));
        }

        private async Task<(int, string)> HandleAssignTableAsync(string rawTableNum, string bodyText)
        {
            var norm = LocalDatabase.NormalizeTableNumber(rawTableNum);
            using var doc = ParseJsonBody(bodyText);
            var waiterName = GetString(doc, "waiter_name");

            if (string.IsNullOrWhiteSpace(waiterName))
            {
                var waiterId = GetInt(doc, "waiter_id");
                if (waiterId.HasValue)
                {
                    var staff = await _db.GetCachedStaffAsync();
                    waiterName = staff.FirstOrDefault(s => s.Role == "waiter" && s.Id == waiterId.Value)?.Name;
                }
            }

            RestaurantTable? tableCopy = null;
            lock (_stateLock)
            {
                var tbl = FindTableLocked(norm);
                if (tbl == null) return (404, JsonError($"Stol #{norm} topilmadi"));
                if (!string.IsNullOrWhiteSpace(waiterName))
                    tbl.AssignedWaiter = waiterName;
                tableCopy = tbl;
            }

            await _db.SaveTableStateAsync(tableCopy);
            HubStateChanged?.Invoke(this, EventArgs.Empty);

            return (200, JsonSerializer.Serialize(new
            {
                success = true,
                table_number = norm,
                assigned_waiter_name = tableCopy.AssignedWaiter,
            }));
        }

        private async Task<(int, string)> HandleWaiterCreateOrderAsync(string bodyText)
        {
            using var doc = ParseJsonBody(bodyText);
            var norm = LocalDatabase.NormalizeTableNumber(GetString(doc, "table_number"));
            if (string.IsNullOrWhiteSpace(norm)) norm = "1";
            var notes = GetString(doc, "notes") ?? "";
            var waiterName = GetString(doc, "waiter_name");
            var guests = GetInt(doc, "guests_count") ?? 2;

            if (string.IsNullOrWhiteSpace(waiterName))
            {
                var waiterId = GetInt(doc, "waiter_id");
                if (waiterId.HasValue)
                {
                    var staff = await _db.GetCachedStaffAsync();
                    waiterName = staff.FirstOrDefault(s => s.Role == "waiter" && s.Id == waiterId.Value)?.Name;
                }
            }

            var requestedProducts = ParseProductsList(doc);
            if (requestedProducts.Count == 0)
                return (400, JsonError("Kamida bitta taom tanlang"));

            RestaurantTable? tblRef = null;
            Order? orderToQueue = null;
            var addedItems = new List<OrderItem>();
            string? rejectReason = null;

            lock (_stateLock)
            {
                var tbl = FindTableLocked(norm);
                if (tbl == null)
                {
                    return (404, JsonError($"Stol #{norm} topilmadi"));
                }

                var products = _getProducts();
                var settings = _getSettings();

                var order = tbl.ActiveOrder;
                if (order == null)
                {
                    order = new Order
                    {
                        Id = 0,
                        OfflineId = Guid.NewGuid().ToString("N"),
                        OrderNumber = $"POS-{norm}-{DateTime.Now:HHmmss}",
                        ServiceType = "dine_in",
                        TableNumber = norm,
                        GuestsCount = Math.Max(1, guests),
                        WaiterName = string.IsNullOrWhiteSpace(waiterName) ? tbl.AssignedWaiter : waiterName,
                        Status = "yangi",
                        Notes = notes,
                        CreatedAt = DateTime.UtcNow.ToString("o"),
                        Items = new List<OrderItem>(),
                    };
                    tbl.ActiveOrder = order;
                    tbl.OpenedAt ??= DateTime.UtcNow.ToString("o");
                }
                else
                {
                    if (string.IsNullOrWhiteSpace(order.OfflineId))
                        order.OfflineId = order.Id > 0 ? $"srv-{order.Id}-{Guid.NewGuid():N}" : Guid.NewGuid().ToString("N");
                    if (!string.IsNullOrWhiteSpace(notes))
                        order.Notes = string.IsNullOrWhiteSpace(order.Notes) ? notes : $"{order.Notes} | {notes}";
                    if (!string.IsNullOrWhiteSpace(waiterName))
                        order.WaiterName = waiterName;
                }

                foreach (var (idOrName, qty) in requestedProducts)
                {
                    if (qty <= 0) continue;
                    Product? prod = null;
                    if (int.TryParse(idOrName, out int pid))
                        prod = products.FirstOrDefault(p => p.Id == pid);
                    prod ??= products.FirstOrDefault(p => string.Equals(p.Name, idOrName, StringComparison.OrdinalIgnoreCase));

                    if (prod == null)
                    {
                        rejectReason = $"Mahsulot topilmadi: {idOrName}";
                        break;
                    }
                    if (!prod.IsAvailable)
                    {
                        rejectReason = $"'{prod.Name}' hozir Stop-listda (tugagan)";
                        break;
                    }

                    var existingItem = order.Items.FirstOrDefault(i => i.ProductId == prod.Id);
                    if (existingItem != null)
                    {
                        existingItem.Quantity += qty;
                    }
                    else
                    {
                        var newItem = new OrderItem
                        {
                            Id = Interlocked.Increment(ref _localItemSeq),
                            ProductId = prod.Id,
                            ProductName = prod.Name,
                            Price = prod.Price,
                            Department = string.IsNullOrWhiteSpace(prod.Department) ? "kitchen" : prod.Department,
                            CategoryName = prod.CategoryName,
                            Quantity = qty,
                        };
                        order.Items.Add(newItem);
                    }

                    addedItems.Add(new OrderItem
                    {
                        ProductId = prod.Id,
                        ProductName = prod.Name,
                        Price = prod.Price,
                        Department = string.IsNullOrWhiteSpace(prod.Department) ? "kitchen" : prod.Department,
                        CategoryName = prod.CategoryName,
                        Quantity = qty,
                    });
                }

                if (rejectReason != null)
                    return (400, JsonError(rejectReason));

                RecalculateOrderTotalsWithSettings(order, settings);
                tbl.IsOccupied = true;
                tbl.Status = "occupied";
                tbl.OrderStatus = order.Status;
                tbl.GuestsCount = order.GuestsCount;
                if (!string.IsNullOrWhiteSpace(order.WaiterName))
                    tbl.AssignedWaiter = order.WaiterName;

                tblRef = tbl;
                orderToQueue = order;
            }

            await _db.SaveTableStateAsync(tblRef!);
            await _db.UpsertPendingSyncOrderAsync(orderToQueue!);

            WaiterOrderReceived?.Invoke(this, new HubWaiterOrderEventArgs
            {
                Table = tblRef!,
                NewlyAddedItems = addedItems,
            });
            HubStateChanged?.Invoke(this, EventArgs.Empty);
            _onRequestImmediateSync?.Invoke();

            int effectiveOrderId = orderToQueue!.Id > 0 ? orderToQueue.Id : 900000 + tblRef!.Number;
            return (200, JsonSerializer.Serialize(new
            {
                success = true,
                order_id = effectiveOrderId,
                offline_id = orderToQueue.OfflineId,
                table_number = norm,
                total_amount = (double)orderToQueue.TotalAmount,
            }));
        }

        private async Task<(int, string)> HandleUpdateOrderItemAsync(int itemId, string bodyText)
        {
            using var doc = ParseJsonBody(bodyText);
            var action = (GetString(doc, "action") ?? "remove").ToLowerInvariant();

            RestaurantTable? updatedTable = null;
            Order? queueOrder = null;
            decimal newTotal = 0;

            lock (_stateLock)
            {
                foreach (var tbl in _getTables())
                {
                    var ord = tbl.ActiveOrder;
                    if (ord == null) continue;
                    var item = ord.Items.FirstOrDefault(i => i.Id == itemId);
                    if (item == null) continue;

                    if (string.IsNullOrWhiteSpace(ord.OfflineId))
                        ord.OfflineId = ord.Id > 0 ? $"srv-{ord.Id}-{Guid.NewGuid():N}" : Guid.NewGuid().ToString("N");

                    if (action == "remove" || (action == "decrease" && item.Quantity <= 1))
                        ord.Items.Remove(item);
                    else if (action == "decrease")
                        item.Quantity -= 1;
                    else if (action == "increase")
                        item.Quantity += 1;

                    if (ord.Items.Count == 0)
                    {
                        ord.Status = "bekor_qilingan";
                        ord.ProductsTotal = 0;
                        ord.ServiceFeeAmount = 0;
                        ord.TotalAmount = 0;
                        newTotal = 0;
                        queueOrder = ord;
                        tbl.ActiveOrder = null;
                        tbl.ActiveCall = null;
                        tbl.IsOccupied = false;
                        tbl.Status = "empty";
                        tbl.OrderStatus = null;
                        tbl.GuestsCount = 0;
                        tbl.AssignedWaiter = null;
                        tbl.OpenedAt = null;
                    }
                    else
                    {
                        RecalculateOrderTotalsWithSettings(ord, _getSettings());
                        newTotal = ord.TotalAmount;
                        queueOrder = ord;
                    }

                    updatedTable = tbl;
                    break;
                }
            }

            if (updatedTable == null || queueOrder == null)
                return (404, JsonError($"Buyurtma taomi (#{itemId}) topilmadi"));

            await _db.SaveTableStateAsync(updatedTable);
            await _db.UpsertPendingSyncOrderAsync(queueOrder);
            HubStateChanged?.Invoke(this, EventArgs.Empty);
            _onRequestImmediateSync?.Invoke();

            return (200, JsonSerializer.Serialize(new
            {
                success = true,
                new_total = (double)newTotal,
                table_number = updatedTable.Number.ToString(),
            }));
        }

        private async Task<(int, string)> HandleBillRequestAsync(string rawTableNum)
        {
            var norm = LocalDatabase.NormalizeTableNumber(rawTableNum);
            RestaurantTable? tblCopy = null;

            var call = new WaiterCall
            {
                Id = 0,
                TableNumber = norm,
                Reason = "Hisob (Pre-chek) so'raldi",
                CreatedAt = DateTime.Now.ToString("HH:mm"),
                IsResolved = false,
            };
            await _db.UpsertWaiterCallAsync(call);

            lock (_stateLock)
            {
                var tbl = FindTableLocked(norm);
                if (tbl == null) return (404, JsonError($"Stol #{norm} topilmadi"));
                tbl.Status = "bill_printed";
                tbl.ActiveCall = call;
                tblCopy = tbl;
            }

            await _db.SaveTableStateAsync(tblCopy!);
            WaiterCallCreated?.Invoke(this, new HubWaiterCallEventArgs { TableNumber = norm, Reason = call.Reason });
            HubStateChanged?.Invoke(this, EventArgs.Empty);
            _onRequestImmediateSync?.Invoke();

            return (200, JsonSerializer.Serialize(new { success = true, table_number = norm, call_id = call.Id }));
        }

        private async Task<(int, string)> HandleDismissCallAsync(int callId)
        {
            await _db.DismissWaiterCallOfflineAsync(callId);
            var touchedTables = new List<RestaurantTable>();

            lock (_stateLock)
            {
                foreach (var t in _getTables())
                {
                    if (t.ActiveCall != null && t.ActiveCall.Id == callId)
                    {
                        t.ActiveCall = null;
                        if (t.Status == "bill_printed")
                            t.Status = (t.IsOccupied || t.ActiveOrder != null) ? "occupied" : "empty";
                        touchedTables.Add(t);
                    }
                }
            }

            foreach (var t in touchedTables)
                await _db.SaveTableStateAsync(t);

            HubStateChanged?.Invoke(this, EventArgs.Empty);
            _onRequestImmediateSync?.Invoke();

            return (200, JsonSerializer.Serialize(new { success = true, call_id = callId }));
        }

        private async Task<(int, string)> HandleDeliverOrderAsync(int orderId)
        {
            RestaurantTable? tblRef = null;
            Order? orderRef = null;

            lock (_stateLock)
            {
                var (tbl, ord) = FindOrderLocked(orderId);
                if (tbl == null || ord == null)
                    return (404, JsonError($"Buyurtma #{orderId} topilmadi"));

                if (string.IsNullOrWhiteSpace(ord.OfflineId))
                    ord.OfflineId = ord.Id > 0 ? $"srv-{ord.Id}-{Guid.NewGuid():N}" : Guid.NewGuid().ToString("N");
                ord.Status = "yetkazildi";
                tbl.OrderStatus = "yetkazildi";
                tblRef = tbl;
                orderRef = ord;
            }

            await _db.SaveTableStateAsync(tblRef!);
            await _db.UpsertPendingSyncOrderAsync(orderRef!);
            HubStateChanged?.Invoke(this, EventArgs.Empty);
            _onRequestImmediateSync?.Invoke();

            return (200, JsonSerializer.Serialize(new { success = true, order_id = orderId }));
        }

        private async Task<(int, string)> HandleCloseOrderAsync(int orderId, string bodyText)
        {
            using var doc = ParseJsonBody(bodyText);
            var payMethod = GetString(doc, "payment_method") ?? "naqd";

            RestaurantTable? tblRef = null;
            Order? paidOrder = null;
            var callIdsToDismiss = new List<int>();

            lock (_stateLock)
            {
                var (tbl, ord) = FindOrderLocked(orderId);
                if (tbl == null || ord == null)
                    return (404, JsonError($"Faol buyurtma #{orderId} topilmadi"));

                if (string.IsNullOrWhiteSpace(ord.OfflineId))
                    ord.OfflineId = ord.Id > 0 ? $"srv-{ord.Id}-{Guid.NewGuid():N}" : Guid.NewGuid().ToString("N");

                ord.IsPaid = true;
                ord.PaymentMethod = payMethod;
                ord.Status = "yetkazildi";
                paidOrder = ord;

                if (tbl.ActiveCall != null)
                {
                    callIdsToDismiss.Add(tbl.ActiveCall.Id);
                    tbl.ActiveCall = null;
                }

                tbl.ActiveOrder = null;
                tbl.IsOccupied = false;
                tbl.Status = "empty";
                tbl.OrderStatus = null;
                tbl.GuestsCount = 0;
                tbl.AssignedWaiter = null;
                tbl.OpenedAt = null;
                tblRef = tbl;
            }

            foreach (var cid in callIdsToDismiss)
                await _db.DismissWaiterCallOfflineAsync(cid);

            await _db.SaveTableStateAsync(tblRef!);
            await _db.UpsertPendingSyncOrderAsync(paidOrder!);

            WaiterOrderPaid?.Invoke(this, new HubOrderPaidEventArgs { PaidOrder = paidOrder!, Table = tblRef! });
            HubStateChanged?.Invoke(this, EventArgs.Empty);
            _onRequestImmediateSync?.Invoke();

            return (200, JsonSerializer.Serialize(new
            {
                success = true,
                payment_method = payMethod,
                total = (double)paidOrder!.TotalAmount,
                table_number = tblRef!.Number.ToString(),
            }));
        }

        private RestaurantTable? FindTableLocked(string normTableNum)
        {
            var tables = _getTables();
            if (int.TryParse(normTableNum, out int n))
            {
                return tables.FirstOrDefault(t => t.Number == n);
            }
            return tables.FirstOrDefault(t => string.Equals(t.Number.ToString(), normTableNum, StringComparison.OrdinalIgnoreCase));
        }

        private (RestaurantTable?, Order?) FindOrderLocked(int orderId)
        {
            foreach (var t in _getTables())
            {
                var ord = t.ActiveOrder;
                if (ord == null) continue;
                int effectiveId = ord.Id > 0 ? ord.Id : 900000 + t.Number;
                if (ord.Id == orderId || effectiveId == orderId)
                    return (t, ord);
            }
            return (null, null);
        }

        private static void RecalculateOrderTotalsWithSettings(Order order, PosSettings settings)
        {
            order.ProductsTotal = order.Items.Sum(i => i.Total);
            order.ServiceFeeAmount = settings.ServiceFeeType switch
            {
                "percent" => Math.Round(order.ProductsTotal * (settings.ServiceFeePercent / 100m), 0),
                "per_person" => order.GuestsCount * settings.ServiceFeePerPerson,
                _ => 0m,
            };
            order.RecalculateTotals();
        }

        private static JsonDocument ParseJsonBody(string bodyText)
        {
            if (string.IsNullOrWhiteSpace(bodyText))
                return JsonDocument.Parse("{}");
            try
            {
                return JsonDocument.Parse(bodyText);
            }
            catch
            {
                return JsonDocument.Parse("{}");
            }
        }

        private static string? GetString(JsonDocument doc, string prop)
        {
            if (doc.RootElement.ValueKind != JsonValueKind.Object) return null;
            if (!doc.RootElement.TryGetProperty(prop, out var el)) return null;
            return el.ValueKind == JsonValueKind.Null ? null : el.ToString();
        }

        private static int? GetInt(JsonDocument doc, string prop)
        {
            if (doc.RootElement.ValueKind != JsonValueKind.Object) return null;
            if (!doc.RootElement.TryGetProperty(prop, out var el)) return null;
            if (el.ValueKind == JsonValueKind.Number && el.TryGetInt32(out int v)) return v;
            if (el.ValueKind == JsonValueKind.String && int.TryParse(el.GetString(), out int v2)) return v2;
            return null;
        }

        private static List<(string IdOrName, int Qty)> ParseProductsList(JsonDocument doc)
        {
            var result = new List<(string, int)>();
            if (doc.RootElement.ValueKind != JsonValueKind.Object) return result;
            if (!doc.RootElement.TryGetProperty("products", out var el) || el.ValueKind != JsonValueKind.Array)
                return result;

            foreach (var entry in el.EnumerateArray())
            {
                if (entry.ValueKind == JsonValueKind.Array)
                {
                    var items = entry.EnumerateArray().ToList();
                    if (items.Count >= 1)
                    {
                        string idOrName = items[0].ToString();
                        int qty = items.Count >= 2 && items[1].TryGetInt32(out int q) ? q : 1;
                        result.Add((idOrName, qty));
                    }
                }
                else if (entry.ValueKind == JsonValueKind.Object)
                {
                    string idOrName = "";
                    if (entry.TryGetProperty("product_id", out var pEl)) idOrName = pEl.ToString();
                    else if (entry.TryGetProperty("id", out var idEl)) idOrName = idEl.ToString();
                    else if (entry.TryGetProperty("name", out var nEl)) idOrName = nEl.ToString();
                    int qty = entry.TryGetProperty("quantity", out var qEl) && qEl.TryGetInt32(out int q) ? q : 1;
                    if (!string.IsNullOrWhiteSpace(idOrName)) result.Add((idOrName, qty));
                }
            }
            return result;
        }
    }
}
