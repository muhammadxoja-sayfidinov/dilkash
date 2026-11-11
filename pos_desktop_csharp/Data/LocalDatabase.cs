using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using System.Threading.Tasks;
using Microsoft.Data.Sqlite;
using DilkashPos.Models;
using DilkashPos.Services;

namespace DilkashPos.Data
{
    public class LocalDatabase
    {
        private readonly string _connectionString;
        private static readonly object _lock = new();

        public LocalDatabase(string? dbPath = null)
        {
            var folder = AppDomain.CurrentDomain.BaseDirectory;
            var file = dbPath ?? Path.Combine(folder, "pos_local.db");
            _connectionString = $"Data Source={file};Mode=ReadWriteCreate;";
            InitializeDatabase();
        }

        private void InitializeDatabase()
        {
            lock (_lock)
            {
                using var conn = new SqliteConnection(_connectionString);
                conn.Open();

                var cmd = conn.CreateCommand();
                cmd.CommandText = @"
                    CREATE TABLE IF NOT EXISTS cache_products (
                        id INTEGER PRIMARY KEY,
                        name TEXT NOT NULL,
                        price REAL NOT NULL,
                        category_id INTEGER,
                        category_name TEXT,
                        department TEXT,
                        is_available INTEGER NOT NULL,
                        description TEXT,
                        image_url TEXT
                    );

                    CREATE TABLE IF NOT EXISTS cache_categories (
                        id INTEGER PRIMARY KEY,
                        name TEXT NOT NULL,
                        department TEXT,
                        description TEXT
                    );

                    CREATE TABLE IF NOT EXISTS cache_departments (
                        code TEXT PRIMARY KEY,
                        name TEXT NOT NULL,
                        printer_ip TEXT,
                        badge_color TEXT
                    );

                    CREATE TABLE IF NOT EXISTS cache_tables (
                        number INTEGER PRIMARY KEY,
                        name TEXT,
                        zone TEXT DEFAULT 'Zal',
                        capacity INTEGER,
                        guests_count INTEGER,
                        is_occupied INTEGER,
                        status TEXT DEFAULT 'empty',
                        assigned_waiter TEXT,
                        opened_at TEXT,
                        order_status TEXT,
                        active_order_json TEXT,
                        active_call_json TEXT
                    );

                    CREATE TABLE IF NOT EXISTS cache_staff (
                        id INTEGER NOT NULL,
                        role TEXT NOT NULL,
                        name TEXT NOT NULL,
                        phone TEXT,
                        pin_hash TEXT NOT NULL,
                        staff_code TEXT,
                        token TEXT,
                        vehicle_info TEXT,
                        is_active INTEGER NOT NULL DEFAULT 1,
                        telegram_id INTEGER,
                        PRIMARY KEY (role, id)
                    );

                    CREATE TABLE IF NOT EXISTS pending_admin_actions (
                        id INTEGER PRIMARY KEY AUTOINCREMENT,
                        endpoint TEXT NOT NULL,
                        payload_json TEXT NOT NULL,
                        created_at TEXT NOT NULL
                    );

                    CREATE TABLE IF NOT EXISTS cache_waiter_calls (
                        id INTEGER PRIMARY KEY,
                        table_number TEXT NOT NULL,
                        reason TEXT NOT NULL,
                        created_at TEXT NOT NULL,
                        is_resolved INTEGER NOT NULL DEFAULT 0
                    );

                    CREATE TABLE IF NOT EXISTS pending_call_dismissals (
                        call_id INTEGER PRIMARY KEY,
                        created_at TEXT NOT NULL
                    );

                    CREATE TABLE IF NOT EXISTS sync_queue (
                        offline_id TEXT PRIMARY KEY,
                        order_json TEXT NOT NULL,
                        status TEXT NOT NULL, -- 'pending', 'synced'
                        created_at TEXT NOT NULL
                    );

                    CREATE TABLE IF NOT EXISTS app_settings (
                        key TEXT PRIMARY KEY,
                        value TEXT NOT NULL
                    );
                ";
                cmd.ExecuteNonQuery();

                EnsureColumnExists(conn, "cache_tables", "zone", "TEXT DEFAULT 'Zal'");
                EnsureColumnExists(conn, "cache_tables", "status", "TEXT DEFAULT 'empty'");
                EnsureColumnExists(conn, "cache_tables", "opened_at", "TEXT");
                EnsureColumnExists(conn, "cache_tables", "order_status", "TEXT");
                EnsureColumnExists(conn, "cache_tables", "active_order_json", "TEXT");
                EnsureColumnExists(conn, "cache_tables", "active_call_json", "TEXT");
                EnsureColumnExists(conn, "cache_categories", "is_active", "INTEGER NOT NULL DEFAULT 1");
                EnsureColumnExists(conn, "cache_categories", "products_count", "INTEGER NOT NULL DEFAULT 0");
                EnsureColumnExists(conn, "cache_staff", "is_active", "INTEGER NOT NULL DEFAULT 1");
                EnsureColumnExists(conn, "cache_staff", "telegram_id", "INTEGER");
            }
        }

        private static void EnsureColumnExists(SqliteConnection conn, string tableName, string columnName, string columnDef)
        {
            var existing = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            using (var pragma = conn.CreateCommand())
            {
                pragma.CommandText = $"PRAGMA table_info({tableName});";
                using var r = pragma.ExecuteReader();
                while (r.Read())
                {
                    if (!r.IsDBNull(1)) existing.Add(r.GetString(1));
                }
            }
            if (!existing.Contains(columnName))
            {
                using var alter = conn.CreateCommand();
                alter.CommandText = $"ALTER TABLE {tableName} ADD COLUMN {columnName} {columnDef};";
                alter.ExecuteNonQuery();
            }
        }

        private static async Task UpsertTableRowAsync(SqliteConnection conn, SqliteTransaction? trans, RestaurantTable t)
        {
            using var cmd = conn.CreateCommand();
            if (trans != null) cmd.Transaction = trans;
            cmd.CommandText = @"
                INSERT OR REPLACE INTO cache_tables (
                    number, name, zone, capacity, guests_count, is_occupied,
                    status, assigned_waiter, opened_at, order_status, active_order_json, active_call_json
                ) VALUES (
                    @num, @name, @zone, @cap, @guests, @occ,
                    @status, @waiter, @opened, @ostatus, @orderJson, @callJson
                );";
            cmd.Parameters.AddWithValue("@num", t.Number);
            cmd.Parameters.AddWithValue("@name", t.Name);
            cmd.Parameters.AddWithValue("@zone", string.IsNullOrWhiteSpace(t.Zone) ? "Zal" : t.Zone);
            cmd.Parameters.AddWithValue("@cap", t.Capacity);
            cmd.Parameters.AddWithValue("@guests", t.GuestsCount);
            cmd.Parameters.AddWithValue("@occ", t.IsOccupied ? 1 : 0);
            cmd.Parameters.AddWithValue("@status", string.IsNullOrWhiteSpace(t.Status) ? "empty" : t.Status);
            cmd.Parameters.AddWithValue("@waiter", (object?)t.AssignedWaiter ?? DBNull.Value);
            cmd.Parameters.AddWithValue("@opened", (object?)t.OpenedAt ?? DBNull.Value);
            cmd.Parameters.AddWithValue("@ostatus", (object?)t.OrderStatus ?? DBNull.Value);
            cmd.Parameters.AddWithValue("@orderJson", t.ActiveOrder != null ? JsonSerializer.Serialize(t.ActiveOrder) : DBNull.Value);
            cmd.Parameters.AddWithValue("@callJson", t.ActiveCall != null ? JsonSerializer.Serialize(t.ActiveCall) : DBNull.Value);
            await cmd.ExecuteNonQueryAsync();
        }

        public async Task<List<Product>> GetCachedProductsAsync()
        {
            var list = new List<Product>();
            using var conn = new SqliteConnection(_connectionString);
            await conn.OpenAsync();

            var cmd = conn.CreateCommand();
            cmd.CommandText = "SELECT id, name, price, category_id, category_name, department, is_available, description, image_url FROM cache_products ORDER BY category_name, name;";
            using var reader = await cmd.ExecuteReaderAsync();
            while (await reader.ReadAsync())
            {
                list.Add(new Product
                {
                    Id = reader.GetInt32(0),
                    Name = reader.GetString(1),
                    Price = (decimal)reader.GetDouble(2),
                    CategoryId = reader.GetInt32(3),
                    CategoryName = reader.GetString(4),
                    Department = reader.GetString(5),
                    IsAvailable = reader.GetInt32(6) == 1,
                    Description = reader.GetString(7),
                    ImageUrl = reader.IsDBNull(8) ? null : reader.GetString(8),
                });
            }
            return list;
        }

        public async Task<List<Category>> GetCachedCategoriesAsync()
        {
            var list = new List<Category>();
            using var conn = new SqliteConnection(_connectionString);
            await conn.OpenAsync();

            var cmd = conn.CreateCommand();
            cmd.CommandText = "SELECT id, name, department, description, COALESCE(is_active, 1), COALESCE(products_count, 0) FROM cache_categories ORDER BY name;";
            using var reader = await cmd.ExecuteReaderAsync();
            while (await reader.ReadAsync())
            {
                list.Add(new Category
                {
                    Id = reader.GetInt32(0),
                    Name = reader.GetString(1),
                    Department = reader.IsDBNull(2) ? "kitchen" : reader.GetString(2),
                    Description = reader.IsDBNull(3) ? "" : reader.GetString(3),
                    IsActive = reader.GetInt32(4) == 1,
                    ProductsCount = reader.GetInt32(5),
                });
            }
            return list;
        }

        public async Task<List<RestaurantTable>> GetCachedTablesAsync()
        {
            var list = new List<RestaurantTable>();
            using var conn = new SqliteConnection(_connectionString);
            await conn.OpenAsync();

            var cmd = conn.CreateCommand();
            cmd.CommandText = @"
                SELECT number, name, zone, capacity, guests_count, is_occupied, status,
                       assigned_waiter, opened_at, order_status, active_order_json, active_call_json
                FROM cache_tables ORDER BY number;";
            using var reader = await cmd.ExecuteReaderAsync();
            while (await reader.ReadAsync())
            {
                Order? activeOrder = null;
                if (!reader.IsDBNull(10))
                {
                    try { activeOrder = JsonSerializer.Deserialize<Order>(reader.GetString(10)); } catch { }
                }
                WaiterCall? activeCall = null;
                if (!reader.IsDBNull(11))
                {
                    try { activeCall = JsonSerializer.Deserialize<WaiterCall>(reader.GetString(11)); } catch { }
                }
                list.Add(new RestaurantTable
                {
                    Number = reader.GetInt32(0),
                    Name = reader.IsDBNull(1) ? $"Stol #{reader.GetInt32(0)}" : reader.GetString(1),
                    Zone = reader.IsDBNull(2) ? "Zal" : reader.GetString(2),
                    Capacity = reader.IsDBNull(3) ? 4 : reader.GetInt32(3),
                    GuestsCount = reader.IsDBNull(4) ? 0 : reader.GetInt32(4),
                    IsOccupied = !reader.IsDBNull(5) && reader.GetInt32(5) == 1,
                    Status = reader.IsDBNull(6) ? "empty" : reader.GetString(6),
                    AssignedWaiter = reader.IsDBNull(7) ? null : reader.GetString(7),
                    OpenedAt = reader.IsDBNull(8) ? null : reader.GetString(8),
                    OrderStatus = reader.IsDBNull(9) ? null : reader.GetString(9),
                    ActiveOrder = activeOrder,
                    ActiveCall = activeCall,
                });
            }
            return list;
        }

        public async Task EnqueueOfflineOrderAsync(Order order)
        {
            if (string.IsNullOrEmpty(order.OfflineId))
            {
                order.OfflineId = Guid.NewGuid().ToString("N");
            }

            var json = JsonSerializer.Serialize(order);
            using var conn = new SqliteConnection(_connectionString);
            await conn.OpenAsync();

            var cmd = conn.CreateCommand();
            cmd.CommandText = @"
                INSERT OR REPLACE INTO sync_queue (offline_id, order_json, status, created_at)
                VALUES (@id, @json, 'pending', @created);
            ";
            cmd.Parameters.AddWithValue("@id", order.OfflineId);
            cmd.Parameters.AddWithValue("@json", json);
            cmd.Parameters.AddWithValue("@created", DateTime.UtcNow.ToString("o"));
            await cmd.ExecuteNonQueryAsync();
        }

        public async Task<List<(string OfflineId, Order Order)>> GetPendingSyncOrdersAsync()
        {
            var list = new List<(string, Order)>();
            using var conn = new SqliteConnection(_connectionString);
            await conn.OpenAsync();

            var cmd = conn.CreateCommand();
            cmd.CommandText = "SELECT offline_id, order_json FROM sync_queue WHERE status = 'pending' ORDER BY created_at ASC;";
            using var reader = await cmd.ExecuteReaderAsync();
            while (await reader.ReadAsync())
            {
                var id = reader.GetString(0);
                var json = reader.GetString(1);
                try
                {
                    var order = JsonSerializer.Deserialize<Order>(json);
                    if (order != null)
                    {
                        list.Add((id, order));
                    }
                }
                catch { }
            }
            return list;
        }

        public async Task MarkOrdersSyncedAsync(List<string> offlineIds)
        {
            if (offlineIds.Count == 0) return;
            using var conn = new SqliteConnection(_connectionString);
            await conn.OpenAsync();

            foreach (var id in offlineIds)
            {
                var cmd = conn.CreateCommand();
                cmd.CommandText = "UPDATE sync_queue SET status = 'synced' WHERE offline_id = @id;";
                cmd.Parameters.AddWithValue("@id", id);
                await cmd.ExecuteNonQueryAsync();
            }
        }

        public async Task UpdateProductAvailabilityAsync(int productId, bool isAvailable)
        {
            using var conn = new SqliteConnection(_connectionString);
            await conn.OpenAsync();

            var cmd = conn.CreateCommand();
            cmd.CommandText = "UPDATE cache_products SET is_available = @avail WHERE id = @id;";
            cmd.Parameters.AddWithValue("@avail", isAvailable ? 1 : 0);
            cmd.Parameters.AddWithValue("@id", productId);
            await cmd.ExecuteNonQueryAsync();
        }

        public static string ComputeSha256Hex(string input)
        {
            var bytes = SHA256.HashData(Encoding.UTF8.GetBytes(input ?? ""));
            var sb = new StringBuilder(bytes.Length * 2);
            foreach (var b in bytes)
                sb.Append(b.ToString("x2"));
            return sb.ToString();
        }

        public static string NormalizePhoneLast9(string? phone)
        {
            if (string.IsNullOrWhiteSpace(phone)) return "";
            var digits = new string(phone.Where(char.IsDigit).ToArray());
            return digits.Length >= 9 ? digits.Substring(digits.Length - 9) : digits;
        }

        public static string NormalizeTableNumber(string? raw)
        {
            var s = (raw ?? "").Trim().ToUpperInvariant();
            if (s.StartsWith("T-")) s = s[2..];
            s = s.TrimStart('#').Trim();
            return int.TryParse(s, out var n) ? n.ToString() : s;
        }

        public async Task SaveSettingAsync(string key, string value)
        {
            using var conn = new SqliteConnection(_connectionString);
            await conn.OpenAsync();
            var cmd = conn.CreateCommand();
            cmd.CommandText = "INSERT OR REPLACE INTO app_settings (key, value) VALUES (@k, @v);";
            cmd.Parameters.AddWithValue("@k", key);
            cmd.Parameters.AddWithValue("@v", value ?? "");
            await cmd.ExecuteNonQueryAsync();
        }

        public async Task<string?> GetSettingAsync(string key, string? defaultValue = null)
        {
            using var conn = new SqliteConnection(_connectionString);
            await conn.OpenAsync();
            var cmd = conn.CreateCommand();
            cmd.CommandText = "SELECT value FROM app_settings WHERE key = @k LIMIT 1;";
            cmd.Parameters.AddWithValue("@k", key);
            var res = await cmd.ExecuteScalarAsync();
            return res == null || res == DBNull.Value ? defaultValue : Convert.ToString(res);
        }

        public async Task<List<Department>> GetCachedDepartmentsAsync()
        {
            var list = new List<Department>();
            using var conn = new SqliteConnection(_connectionString);
            await conn.OpenAsync();
            var cmd = conn.CreateCommand();
            cmd.CommandText = "SELECT code, name, printer_ip, badge_color FROM cache_departments ORDER BY rowid;";
            using var reader = await cmd.ExecuteReaderAsync();
            while (await reader.ReadAsync())
            {
                list.Add(new Department
                {
                    Code = reader.GetString(0),
                    Name = reader.GetString(1),
                    PrinterIp = reader.IsDBNull(2) ? "" : reader.GetString(2),
                    BadgeColor = reader.IsDBNull(3) ? "#10b981" : reader.GetString(3),
                });
            }
            return list;
        }

        public async Task<HashSet<string>> GetPendingTableNumbersAsync()
        {
            var set = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            var pending = await GetPendingSyncOrdersAsync();
            foreach (var (_, order) in pending)
            {
                if (string.Equals(order.ServiceType, "dine_in", StringComparison.OrdinalIgnoreCase))
                {
                    var norm = NormalizeTableNumber(order.TableNumber);
                    if (!string.IsNullOrEmpty(norm)) set.Add(norm);
                }
            }
            return set;
        }

        public async Task<string> UpsertPendingSyncOrderAsync(Order order)
        {
            await EnqueueOfflineOrderAsync(order);
            return order.OfflineId!;
        }

        public async Task SaveTableStateAsync(RestaurantTable t)
        {
            using var conn = new SqliteConnection(_connectionString);
            await conn.OpenAsync();
            await UpsertTableRowAsync(conn, null, t);
        }

        public async Task SaveBootstrapStateAsync(BootstrapResponse boot, HashSet<string>? preserveTableNums = null)
        {
            var preserve = preserveTableNums ?? await GetPendingTableNumbersAsync();
            var dismissedIds = new HashSet<int>(await GetPendingCallDismissalsAsync());
            var existingTables = (await GetCachedTablesAsync()).ToDictionary(t => t.Number, t => t);

            using var conn = new SqliteConnection(_connectionString);
            await conn.OpenAsync();
            using var trans = conn.BeginTransaction();

            try
            {
                // Departments
                if (boot.Departments.Count > 0)
                {
                    using var delD = conn.CreateCommand();
                    delD.Transaction = trans;
                    delD.CommandText = "DELETE FROM cache_departments;";
                    await delD.ExecuteNonQueryAsync();

                    foreach (var d in boot.Departments)
                    {
                        using var insD = conn.CreateCommand();
                        insD.Transaction = trans;
                        insD.CommandText = "INSERT INTO cache_departments (code, name, printer_ip, badge_color) VALUES (@c, @n, @ip, @bg);";
                        insD.Parameters.AddWithValue("@c", d.Code);
                        insD.Parameters.AddWithValue("@n", d.Name);
                        insD.Parameters.AddWithValue("@ip", d.PrinterIp ?? "");
                        insD.Parameters.AddWithValue("@bg", d.BadgeColor ?? "#10b981");
                        await insD.ExecuteNonQueryAsync();
                    }
                }

                // Products
                using (var delP = conn.CreateCommand())
                {
                    delP.Transaction = trans;
                    delP.CommandText = "DELETE FROM cache_products;";
                    await delP.ExecuteNonQueryAsync();
                }
                foreach (var p in boot.Products)
                {
                    using var cmdP = conn.CreateCommand();
                    cmdP.Transaction = trans;
                    cmdP.CommandText = @"
                        INSERT INTO cache_products (id, name, price, category_id, category_name, department, is_available, description, image_url)
                        VALUES (@id, @name, @price, @cat_id, @cat_name, @dept, @avail, @desc, @img);";
                    cmdP.Parameters.AddWithValue("@id", p.Id);
                    cmdP.Parameters.AddWithValue("@name", p.Name);
                    cmdP.Parameters.AddWithValue("@price", (double)p.Price);
                    cmdP.Parameters.AddWithValue("@cat_id", p.CategoryId);
                    cmdP.Parameters.AddWithValue("@cat_name", p.CategoryName);
                    cmdP.Parameters.AddWithValue("@dept", p.Department);
                    cmdP.Parameters.AddWithValue("@avail", p.IsAvailable ? 1 : 0);
                    cmdP.Parameters.AddWithValue("@desc", p.Description);
                    cmdP.Parameters.AddWithValue("@img", (object?)p.ImageUrl ?? DBNull.Value);
                    await cmdP.ExecuteNonQueryAsync();
                }

                // Categories
                using (var delC = conn.CreateCommand())
                {
                    delC.Transaction = trans;
                    delC.CommandText = "DELETE FROM cache_categories;";
                    await delC.ExecuteNonQueryAsync();
                }
                foreach (var c in boot.Categories)
                {
                    using var cmdC = conn.CreateCommand();
                    cmdC.Transaction = trans;
                    cmdC.CommandText = @"
                        INSERT INTO cache_categories (id, name, department, description, is_active, products_count)
                        VALUES (@id, @name, @dept, @desc, @act, @cnt);";
                    cmdC.Parameters.AddWithValue("@id", c.Id);
                    cmdC.Parameters.AddWithValue("@name", c.Name);
                    cmdC.Parameters.AddWithValue("@dept", c.Department);
                    cmdC.Parameters.AddWithValue("@desc", c.Description);
                    cmdC.Parameters.AddWithValue("@act", c.IsActive ? 1 : 0);
                    cmdC.Parameters.AddWithValue("@cnt", c.ProductsCount);
                    await cmdC.ExecuteNonQueryAsync();
                }

                // Staff accounts (hashed PIN only)
                if (boot.Staff.Count > 0)
                {
                    using var delS = conn.CreateCommand();
                    delS.Transaction = trans;
                    delS.CommandText = "DELETE FROM cache_staff;";
                    await delS.ExecuteNonQueryAsync();

                    foreach (var s in boot.Staff)
                    {
                        using var cmdS = conn.CreateCommand();
                        cmdS.Transaction = trans;
                        cmdS.CommandText = @"
                            INSERT OR REPLACE INTO cache_staff (id, role, name, phone, pin_hash, staff_code, token, vehicle_info, is_active, telegram_id)
                            VALUES (@id, @role, @name, @phone, @pinh, @code, @tok, @veh, @act, @tg);";
                        cmdS.Parameters.AddWithValue("@id", s.Id);
                        cmdS.Parameters.AddWithValue("@role", s.Role);
                        cmdS.Parameters.AddWithValue("@name", s.Name);
                        cmdS.Parameters.AddWithValue("@phone", s.Phone ?? "");
                        cmdS.Parameters.AddWithValue("@pinh", s.PinHash);
                        cmdS.Parameters.AddWithValue("@code", s.StaffCode ?? $"DIL-{s.Id}");
                        cmdS.Parameters.AddWithValue("@tok", s.Token ?? "");
                        cmdS.Parameters.AddWithValue("@veh", s.VehicleInfo ?? "");
                        cmdS.Parameters.AddWithValue("@act", s.IsActive ? 1 : 0);
                        cmdS.Parameters.AddWithValue("@tg", s.TelegramId.HasValue ? s.TelegramId.Value : DBNull.Value);
                        await cmdS.ExecuteNonQueryAsync();
                    }
                }

                // Waiter Calls (keep negative offline calls that haven't been dismissed; ignore cloud calls pending dismissal)
                using (var delW = conn.CreateCommand())
                {
                    delW.Transaction = trans;
                    delW.CommandText = "DELETE FROM cache_waiter_calls WHERE id > 0;";
                    await delW.ExecuteNonQueryAsync();
                }
                foreach (var call in boot.WaiterCalls)
                {
                    if (dismissedIds.Contains(call.Id)) continue;
                    using var cmdW = conn.CreateCommand();
                    cmdW.Transaction = trans;
                    cmdW.CommandText = @"
                        INSERT OR REPLACE INTO cache_waiter_calls (id, table_number, reason, created_at, is_resolved)
                        VALUES (@id, @tbl, @rsn, @cat, @res);";
                    cmdW.Parameters.AddWithValue("@id", call.Id);
                    cmdW.Parameters.AddWithValue("@tbl", NormalizeTableNumber(call.TableNumber));
                    cmdW.Parameters.AddWithValue("@rsn", call.Reason);
                    cmdW.Parameters.AddWithValue("@cat", call.CreatedAt);
                    cmdW.Parameters.AddWithValue("@res", call.IsResolved ? 1 : 0);
                    await cmdW.ExecuteNonQueryAsync();
                }

                // Tables (merge while preserving local pending tables)
                using (var delT = conn.CreateCommand())
                {
                    delT.Transaction = trans;
                    delT.CommandText = "DELETE FROM cache_tables;";
                    await delT.ExecuteNonQueryAsync();
                }
                foreach (var srvT in boot.Tables)
                {
                    var key = srvT.Number.ToString();
                    var t = srvT;
                    if (preserve.Contains(key) && existingTables.TryGetValue(srvT.Number, out var localT))
                    {
                        t = localT;
                    }
                    else if (t.ActiveCall != null && dismissedIds.Contains(t.ActiveCall.Id))
                    {
                        t.ActiveCall = null;
                        if (t.Status == "bill_printed")
                            t.Status = t.IsOccupied ? "occupied" : "empty";
                    }

                    await UpsertTableRowAsync(conn, trans, t);
                }

                trans.Commit();
            }
            catch
            {
                trans.Rollback();
                throw;
            }
        }

        public async Task<List<StaffAccount>> GetCachedStaffAsync()
        {
            var list = new List<StaffAccount>();
            using var conn = new SqliteConnection(_connectionString);
            await conn.OpenAsync();
            var cmd = conn.CreateCommand();
            cmd.CommandText = "SELECT id, role, name, phone, pin_hash, staff_code, token, vehicle_info, COALESCE(is_active, 1), telegram_id FROM cache_staff ORDER BY is_active DESC, role, name, id;";
            using var r = await cmd.ExecuteReaderAsync();
            while (await r.ReadAsync())
            {
                list.Add(new StaffAccount
                {
                    Id = r.GetInt32(0),
                    Role = r.GetString(1),
                    Name = r.GetString(2),
                    Phone = r.IsDBNull(3) ? "" : r.GetString(3),
                    PinHash = r.GetString(4),
                    StaffCode = r.IsDBNull(5) ? "" : r.GetString(5),
                    Token = r.IsDBNull(6) ? "" : r.GetString(6),
                    VehicleInfo = r.IsDBNull(7) ? "" : r.GetString(7),
                    IsActive = r.IsDBNull(8) || r.GetInt32(8) == 1,
                    TelegramId = r.IsDBNull(9) ? null : r.GetInt64(9),
                });
            }
            return list;
        }

        public async Task<List<StaffAccount>> VerifyStaffLoginOfflineAsync(string phone, string pin)
        {
            var staff = await GetCachedStaffAsync();
            if (staff.Count == 0)
            {
                // Cold-boot emergency fallback ONLY when SQLite has zero synced staff records yet
                staff = new List<StaffAccount>
                {
                    new() { Id = 1, Role = "waiter", Name = "Jasur Rahimov", Phone = "+998901112233", PinHash = "03ac674216f3e15c761ee1a5e255f067953623c8b388b4459e13f978d7c846f4", StaffCode = "DIL-1", Token = "local_w1", IsActive = true },
                    new() { Id = 1, Role = "courier", Name = "Jasur Rahimov", Phone = "+998901112233", PinHash = "03ac674216f3e15c761ee1a5e255f067953623c8b388b4459e13f978d7c846f4", StaffCode = "DIL-1", Token = "local_c1", IsActive = true },
                    new() { Id = 2, Role = "waiter", Name = "Sardor Alimov", Phone = "+998902223344", PinHash = "38083c7ee9121e17401883566a148aa5c2e2d55dc53bc4a94a026517dbff3c6b", StaffCode = "DIL-2", Token = "local_w2", IsActive = true },
                    new() { Id = 3, Role = "waiter", Name = "Nodir Karimov", Phone = "+998903334455", PinHash = "ceaa28bba4caba687dc31b1bbe79eca3c70c33f871f1ce8f528cf9ab5cfd76dd", StaffCode = "DIL-3", Token = "local_w3", IsActive = true },
                };
            }

            var targetPhone = NormalizePhoneLast9(phone);
            var targetPinHash = ComputeSha256Hex(pin.Trim());

            return staff
                .Where(s => s.IsActive && NormalizePhoneLast9(s.Phone) == targetPhone && string.Equals(s.PinHash, targetPinHash, StringComparison.OrdinalIgnoreCase))
                .ToList();
        }

        public async Task<int> UpsertWaiterCallAsync(WaiterCall call)
        {
            using var conn = new SqliteConnection(_connectionString);
            await conn.OpenAsync();
            if (call.Id == 0)
            {
                // Generate negative ID for local offline waiter/bill call so it won't collide with Django DB PKs
                using var minCmd = conn.CreateCommand();
                minCmd.CommandText = "SELECT COALESCE(MIN(id), 0) FROM cache_waiter_calls WHERE id < 0;";
                var minVal = Convert.ToInt32(await minCmd.ExecuteScalarAsync());
                call.Id = minVal - 1;
            }
            var cmd = conn.CreateCommand();
            cmd.CommandText = @"
                INSERT OR REPLACE INTO cache_waiter_calls (id, table_number, reason, created_at, is_resolved)
                VALUES (@id, @tbl, @rsn, @cat, @res);";
            cmd.Parameters.AddWithValue("@id", call.Id);
            cmd.Parameters.AddWithValue("@tbl", NormalizeTableNumber(call.TableNumber));
            cmd.Parameters.AddWithValue("@rsn", call.Reason);
            cmd.Parameters.AddWithValue("@cat", string.IsNullOrWhiteSpace(call.CreatedAt) ? DateTime.Now.ToString("HH:mm") : call.CreatedAt);
            cmd.Parameters.AddWithValue("@res", call.IsResolved ? 1 : 0);
            await cmd.ExecuteNonQueryAsync();
            return call.Id;
        }

        public async Task<List<WaiterCall>> GetCachedWaiterCallsAsync(bool includeResolved = false)
        {
            var list = new List<WaiterCall>();
            using var conn = new SqliteConnection(_connectionString);
            await conn.OpenAsync();
            var cmd = conn.CreateCommand();
            cmd.CommandText = includeResolved
                ? "SELECT id, table_number, reason, created_at, is_resolved FROM cache_waiter_calls ORDER BY rowid DESC;"
                : "SELECT id, table_number, reason, created_at, is_resolved FROM cache_waiter_calls WHERE is_resolved = 0 ORDER BY rowid DESC;";
            using var r = await cmd.ExecuteReaderAsync();
            while (await r.ReadAsync())
            {
                list.Add(new WaiterCall
                {
                    Id = r.GetInt32(0),
                    TableNumber = r.GetString(1),
                    Reason = r.GetString(2),
                    CreatedAt = r.GetString(3),
                    IsResolved = r.GetInt32(4) == 1,
                });
            }
            return list;
        }

        public async Task DismissWaiterCallOfflineAsync(int callId)
        {
            using var conn = new SqliteConnection(_connectionString);
            await conn.OpenAsync();
            using var upd = conn.CreateCommand();
            upd.CommandText = "UPDATE cache_waiter_calls SET is_resolved = 1 WHERE id = @id;";
            upd.Parameters.AddWithValue("@id", callId);
            await upd.ExecuteNonQueryAsync();

            if (callId > 0)
            {
                using var ins = conn.CreateCommand();
                ins.CommandText = "INSERT OR IGNORE INTO pending_call_dismissals (call_id, created_at) VALUES (@id, @cat);";
                ins.Parameters.AddWithValue("@id", callId);
                ins.Parameters.AddWithValue("@cat", DateTime.UtcNow.ToString("o"));
                await ins.ExecuteNonQueryAsync();
            }
        }

        public async Task<List<int>> GetPendingCallDismissalsAsync()
        {
            var list = new List<int>();
            using var conn = new SqliteConnection(_connectionString);
            await conn.OpenAsync();
            var cmd = conn.CreateCommand();
            cmd.CommandText = "SELECT call_id FROM pending_call_dismissals ORDER BY call_id;";
            using var r = await cmd.ExecuteReaderAsync();
            while (await r.ReadAsync())
            {
                list.Add(r.GetInt32(0));
            }
            return list;
        }

        public async Task MarkCallDismissalsSyncedAsync(List<int> callIds)
        {
            if (callIds.Count == 0) return;
            using var conn = new SqliteConnection(_connectionString);
            await conn.OpenAsync();
            foreach (var id in callIds)
            {
                using var del = conn.CreateCommand();
                del.CommandText = "DELETE FROM pending_call_dismissals WHERE call_id = @id;";
                del.Parameters.AddWithValue("@id", id);
                await del.ExecuteNonQueryAsync();
            }
        }

        public async Task EnqueueAdminActionAsync(string endpoint, string payloadJson)
        {
            using var conn = new SqliteConnection(_connectionString);
            await conn.OpenAsync();
            var cmd = conn.CreateCommand();
            cmd.CommandText = "INSERT INTO pending_admin_actions (endpoint, payload_json, created_at) VALUES (@ep, @pl, @cat);";
            cmd.Parameters.AddWithValue("@ep", endpoint);
            cmd.Parameters.AddWithValue("@pl", payloadJson ?? "{}");
            cmd.Parameters.AddWithValue("@cat", DateTime.UtcNow.ToString("o"));
            await cmd.ExecuteNonQueryAsync();
        }

        public async Task<List<(long Id, string Endpoint, string PayloadJson)>> GetPendingAdminActionsAsync()
        {
            var list = new List<(long, string, string)>();
            using var conn = new SqliteConnection(_connectionString);
            await conn.OpenAsync();
            var cmd = conn.CreateCommand();
            cmd.CommandText = "SELECT id, endpoint, payload_json FROM pending_admin_actions ORDER BY id ASC;";
            using var r = await cmd.ExecuteReaderAsync();
            while (await r.ReadAsync())
            {
                list.Add((r.GetInt64(0), r.GetString(1), r.GetString(2)));
            }
            return list;
        }

        public async Task DeletePendingAdminActionAsync(long actionId)
        {
            using var conn = new SqliteConnection(_connectionString);
            await conn.OpenAsync();
            var cmd = conn.CreateCommand();
            cmd.CommandText = "DELETE FROM pending_admin_actions WHERE id = @id;";
            cmd.Parameters.AddWithValue("@id", actionId);
            await cmd.ExecuteNonQueryAsync();
        }

        public async Task<int> UpsertLocalCategoryAsync(Category c)
        {
            using var conn = new SqliteConnection(_connectionString);
            await conn.OpenAsync();
            if (c.Id == 0)
            {
                using var minCmd = conn.CreateCommand();
                minCmd.CommandText = "SELECT COALESCE(MIN(id), 0) FROM cache_categories WHERE id < 0;";
                c.Id = Convert.ToInt32(await minCmd.ExecuteScalarAsync()) - 1;
            }
            using var cmd = conn.CreateCommand();
            cmd.CommandText = @"
                INSERT OR REPLACE INTO cache_categories (id, name, department, description, is_active, products_count)
                VALUES (@id, @n, @d, @ds, @act, @cnt);";
            cmd.Parameters.AddWithValue("@id", c.Id);
            cmd.Parameters.AddWithValue("@n", c.Name);
            cmd.Parameters.AddWithValue("@d", c.Department ?? "kitchen");
            cmd.Parameters.AddWithValue("@ds", c.Description ?? "");
            cmd.Parameters.AddWithValue("@act", c.IsActive ? 1 : 0);
            cmd.Parameters.AddWithValue("@cnt", c.ProductsCount);
            await cmd.ExecuteNonQueryAsync();
            return c.Id;
        }

        public async Task DeleteLocalCategoryAsync(int catId)
        {
            using var conn = new SqliteConnection(_connectionString);
            await conn.OpenAsync();
            using var cmd = conn.CreateCommand();
            cmd.CommandText = "DELETE FROM cache_categories WHERE id = @id;";
            cmd.Parameters.AddWithValue("@id", catId);
            await cmd.ExecuteNonQueryAsync();
        }

        public async Task<int> UpsertLocalProductAsync(Product p)
        {
            using var conn = new SqliteConnection(_connectionString);
            await conn.OpenAsync();
            if (p.Id == 0)
            {
                using var minCmd = conn.CreateCommand();
                minCmd.CommandText = "SELECT COALESCE(MIN(id), 0) FROM cache_products WHERE id < 0;";
                p.Id = Convert.ToInt32(await minCmd.ExecuteScalarAsync()) - 1;
            }
            using var cmd = conn.CreateCommand();
            cmd.CommandText = @"
                INSERT OR REPLACE INTO cache_products (id, name, price, category_id, category_name, department, is_available, description, image_url)
                VALUES (@id, @n, @pr, @cid, @cn, @dept, @av, @ds, @img);";
            cmd.Parameters.AddWithValue("@id", p.Id);
            cmd.Parameters.AddWithValue("@n", p.Name);
            cmd.Parameters.AddWithValue("@pr", (double)p.Price);
            cmd.Parameters.AddWithValue("@cid", p.CategoryId);
            cmd.Parameters.AddWithValue("@cn", p.CategoryName ?? "");
            cmd.Parameters.AddWithValue("@dept", p.Department ?? "kitchen");
            cmd.Parameters.AddWithValue("@av", p.IsAvailable ? 1 : 0);
            cmd.Parameters.AddWithValue("@ds", p.Description ?? "");
            cmd.Parameters.AddWithValue("@img", (object?)p.ImageUrl ?? DBNull.Value);
            await cmd.ExecuteNonQueryAsync();
            return p.Id;
        }

        public async Task DeleteLocalProductAsync(int prodId)
        {
            using var conn = new SqliteConnection(_connectionString);
            await conn.OpenAsync();
            using var cmd = conn.CreateCommand();
            cmd.CommandText = "DELETE FROM cache_products WHERE id = @id;";
            cmd.Parameters.AddWithValue("@id", prodId);
            await cmd.ExecuteNonQueryAsync();
        }

        public async Task<int> UpsertLocalStaffAsync(StaffAccount s, string? plainPin = null)
        {
            using var conn = new SqliteConnection(_connectionString);
            await conn.OpenAsync();
            if (s.Id == 0)
            {
                using var minCmd = conn.CreateCommand();
                minCmd.CommandText = "SELECT COALESCE(MIN(id), 0) FROM cache_staff WHERE id < 0;";
                s.Id = Convert.ToInt32(await minCmd.ExecuteScalarAsync()) - 1;
            }
            if (!string.IsNullOrWhiteSpace(plainPin))
            {
                s.PinHash = ComputeSha256Hex(plainPin.Trim());
            }
            if (string.IsNullOrWhiteSpace(s.PinHash))
            {
                s.PinHash = ComputeSha256Hex("1234");
            }
            using var cmd = conn.CreateCommand();
            cmd.CommandText = @"
                INSERT OR REPLACE INTO cache_staff (id, role, name, phone, pin_hash, staff_code, token, vehicle_info, is_active, telegram_id)
                VALUES (@id, @r, @n, @ph, @pinh, @sc, @tok, @veh, @act, @tg);";
            cmd.Parameters.AddWithValue("@id", s.Id);
            cmd.Parameters.AddWithValue("@r", s.Role);
            cmd.Parameters.AddWithValue("@n", s.Name);
            cmd.Parameters.AddWithValue("@ph", s.Phone ?? "");
            cmd.Parameters.AddWithValue("@pinh", s.PinHash);
            cmd.Parameters.AddWithValue("@sc", string.IsNullOrWhiteSpace(s.StaffCode) ? $"DIL-{Math.Abs(s.Id)}" : s.StaffCode);
            cmd.Parameters.AddWithValue("@tok", string.IsNullOrWhiteSpace(s.Token) ? $"loc_{s.Role}_{Math.Abs(s.Id)}" : s.Token);
            cmd.Parameters.AddWithValue("@veh", s.VehicleInfo ?? "");
            cmd.Parameters.AddWithValue("@act", s.IsActive ? 1 : 0);
            cmd.Parameters.AddWithValue("@tg", s.TelegramId.HasValue ? s.TelegramId.Value : DBNull.Value);
            await cmd.ExecuteNonQueryAsync();
            return s.Id;
        }

        public async Task ToggleLocalStaffAsync(string role, int staffId)
        {
            using var conn = new SqliteConnection(_connectionString);
            await conn.OpenAsync();
            using var cmd = conn.CreateCommand();
            cmd.CommandText = "UPDATE cache_staff SET is_active = CASE WHEN COALESCE(is_active, 1) = 1 THEN 0 ELSE 1 END WHERE role = @r AND id = @id;";
            cmd.Parameters.AddWithValue("@r", role);
            cmd.Parameters.AddWithValue("@id", staffId);
            await cmd.ExecuteNonQueryAsync();
        }

        public async Task DeleteLocalStaffAsync(string role, int staffId)
        {
            using var conn = new SqliteConnection(_connectionString);
            await conn.OpenAsync();
            using var cmd = conn.CreateCommand();
            cmd.CommandText = "DELETE FROM cache_staff WHERE role = @r AND id = @id;";
            cmd.Parameters.AddWithValue("@r", role);
            cmd.Parameters.AddWithValue("@id", staffId);
            await cmd.ExecuteNonQueryAsync();
        }

        public async Task DeleteLocalTableByNumberAsync(int tableNumber)
        {
            using var conn = new SqliteConnection(_connectionString);
            await conn.OpenAsync();
            using var cmd = conn.CreateCommand();
            cmd.CommandText = "DELETE FROM cache_tables WHERE number = @num;";
            cmd.Parameters.AddWithValue("@num", tableNumber);
            await cmd.ExecuteNonQueryAsync();
        }

        public async Task SaveFullSettingsLocalAsync(PosSettings settings)
        {
            var json = JsonSerializer.Serialize(settings);
            await SaveSettingAsync("full_settings_json", json);
            await SaveSettingAsync("server_url", settings.ServerUrl ?? "");
            await SaveSettingAsync("cashier_name", settings.CashierName ?? "");
        }

        public async Task<PosSettings?> LoadFullSettingsLocalAsync()
        {
            var raw = await GetSettingAsync("full_settings_json");
            if (string.IsNullOrWhiteSpace(raw)) return null;
            try
            {
                return JsonSerializer.Deserialize<PosSettings>(raw);
            }
            catch
            {
                return null;
            }
        }
    }
}

