using System;
using System.Collections.Generic;
using System.IO;
using System.Text.Json;
using System.Threading.Tasks;
using Microsoft.Data.Sqlite;
using DilkashPos.Models;

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
                        capacity INTEGER,
                        guests_count INTEGER,
                        is_occupied INTEGER,
                        assigned_waiter TEXT
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
            }
        }

        public async Task SaveBootstrapCacheAsync(
            List<Department> departments,
            List<Category> categories,
            List<Product> products,
            List<RestaurantTable> tables)
        {
            using var conn = new SqliteConnection(_connectionString);
            await conn.OpenAsync();
            using var trans = conn.BeginTransaction();

            try
            {
                // Products
                var cmdDelP = conn.CreateCommand();
                cmdDelP.Transaction = trans;
                cmdDelP.CommandText = "DELETE FROM cache_products;";
                await cmdDelP.ExecuteNonQueryAsync();

                foreach (var p in products)
                {
                    var cmdP = conn.CreateCommand();
                    cmdP.Transaction = trans;
                    cmdP.CommandText = @"
                        INSERT INTO cache_products (id, name, price, category_id, category_name, department, is_available, description, image_url)
                        VALUES (@id, @name, @price, @cat_id, @cat_name, @dept, @avail, @desc, @img);
                    ";
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
                var cmdDelC = conn.CreateCommand();
                cmdDelC.Transaction = trans;
                cmdDelC.CommandText = "DELETE FROM cache_categories;";
                await cmdDelC.ExecuteNonQueryAsync();

                foreach (var c in categories)
                {
                    var cmdC = conn.CreateCommand();
                    cmdC.Transaction = trans;
                    cmdC.CommandText = "INSERT INTO cache_categories (id, name, department, description) VALUES (@id, @name, @dept, @desc);";
                    cmdC.Parameters.AddWithValue("@id", c.Id);
                    cmdC.Parameters.AddWithValue("@name", c.Name);
                    cmdC.Parameters.AddWithValue("@dept", c.Department);
                    cmdC.Parameters.AddWithValue("@desc", c.Description);
                    await cmdC.ExecuteNonQueryAsync();
                }

                // Tables
                var cmdDelT = conn.CreateCommand();
                cmdDelT.Transaction = trans;
                cmdDelT.CommandText = "DELETE FROM cache_tables;";
                await cmdDelT.ExecuteNonQueryAsync();

                foreach (var t in tables)
                {
                    var cmdT = conn.CreateCommand();
                    cmdT.Transaction = trans;
                    cmdT.CommandText = "INSERT INTO cache_tables (number, name, capacity, guests_count, is_occupied, assigned_waiter) VALUES (@num, @name, @cap, @guests, @occ, @waiter);";
                    cmdT.Parameters.AddWithValue("@num", t.Number);
                    cmdT.Parameters.AddWithValue("@name", t.Name);
                    cmdT.Parameters.AddWithValue("@cap", t.Capacity);
                    cmdT.Parameters.AddWithValue("@guests", t.GuestsCount);
                    cmdT.Parameters.AddWithValue("@occ", t.IsOccupied ? 1 : 0);
                    cmdT.Parameters.AddWithValue("@waiter", (object?)t.AssignedWaiter ?? DBNull.Value);
                    await cmdT.ExecuteNonQueryAsync();
                }

                trans.Commit();
            }
            catch
            {
                trans.Rollback();
                throw;
            }
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
            cmd.CommandText = "SELECT id, name, department, description FROM cache_categories ORDER BY name;";
            using var reader = await cmd.ExecuteReaderAsync();
            while (await reader.ReadAsync())
            {
                list.Add(new Category
                {
                    Id = reader.GetInt32(0),
                    Name = reader.GetString(1),
                    Department = reader.GetString(2),
                    Description = reader.GetString(3),
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
            cmd.CommandText = "SELECT number, name, capacity, guests_count, is_occupied, assigned_waiter FROM cache_tables ORDER BY number;";
            using var reader = await cmd.ExecuteReaderAsync();
            while (await reader.ReadAsync())
            {
                list.Add(new RestaurantTable
                {
                    Number = reader.GetInt32(0),
                    Name = reader.GetString(1),
                    Capacity = reader.GetInt32(2),
                    GuestsCount = reader.GetInt32(3),
                    IsOccupied = reader.GetInt32(4) == 1,
                    AssignedWaiter = reader.IsDBNull(5) ? null : reader.GetString(5),
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
    }
}

