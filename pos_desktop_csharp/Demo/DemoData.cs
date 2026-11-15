using System;
using System.Collections.Generic;
using DilkashPos.Models;

namespace DilkashPos.Demo
{
    public static class DemoData
    {
        public static (List<Department> Departments, List<Category> Categories, List<Product> Products, List<RestaurantTable> Tables, List<Order> OnlineOrders, ShiftReport Shift, PosSettings Settings) GetDemoDataset()
        {
            var departments = new List<Department>
            {
                new Department { Code = "kassa", Name = "Kassa", Title = "Bosh kassa", Subtitle = "Mijoz hisob-kitob cheki", Icon = "receipt", PrinterIp = "192.168.1.100:9100", IsOnline = true },
                new Department { Code = "shashlik", Name = "Shashlikxona", Title = "Mangal boʻlimi", Subtitle = "Shashlik va kaboblar", Icon = "grill", PrinterIp = "192.168.1.101:9100", IsOnline = true },
                new Department { Code = "somsa", Name = "Somsaxona", Title = "Tandir boʻlimi", Subtitle = "Issiq tandir somsalar", Icon = "chef", PrinterIp = "192.168.1.102:9100", IsOnline = true },
                new Department { Code = "kitchen", Name = "Issiq oshxona", Title = "Oshxona boʻlimi", Subtitle = "Milliy issiq taomlar", Icon = "bowl", PrinterIp = "192.168.1.103:9100", IsOnline = true },
                new Department { Code = "fastfood", Name = "Fast-food", Title = "Burger va lavash", Subtitle = "Tezkor taomlar", Icon = "burger", PrinterIp = "192.168.1.104:9100", IsOnline = false }, // offline demo
                new Department { Code = "bar", Name = "Bar va ichimliklar", Title = "Bar boʻlimi", Subtitle = "Choy, qahva, salqin ichimliklar", Icon = "coffee", PrinterIp = "192.168.1.105:9100", IsOnline = false } // offline demo
            };

            var categories = new List<Category>
            {
                new Category { Id = 1, Name = "Shashliklar", Department = "shashlik", Icon = "grill" },
                new Category { Id = 2, Name = "Tandir somsalar", Department = "somsa", Icon = "chef" },
                new Category { Id = 3, Name = "Issiq taomlar", Department = "kitchen", Icon = "bowl" },
                new Category { Id = 4, Name = "Fast-food", Department = "fastfood", Icon = "burger" },
                new Category { Id = 5, Name = "Salatlar va gazaklar", Department = "kitchen", Icon = "bowl" },
                new Category { Id = 6, Name = "Choy va ichimliklar", Department = "bar", Icon = "coffee", SubcategoriesCount = 2 },
                new Category { Id = 7, Name = "Shirinliklar", Department = "bar", Icon = "coffee" },
                new Category { Id = 8, Name = "Issiq choy va qahva", Department = "bar", Icon = "coffee", ParentId = 6 },
                new Category { Id = 9, Name = "Salqin ichimliklar", Department = "bar", Icon = "coffee", ParentId = 6 }
            };

            var products = new List<Product>
            {
                // Shashliklar
                new Product { Id = 101, CategoryId = 1, CategoryName = "Shashliklar", Department = "shashlik", Name = "Qoʻy goʻshti shashlik", Price = 28000, IsAvailable = true },
                new Product { Id = 102, CategoryId = 1, CategoryName = "Shashliklar", Department = "shashlik", Name = "Mol goʻshti qiyma shashlik", Price = 24000, IsAvailable = true },
                new Product { Id = 103, CategoryId = 1, CategoryName = "Shashliklar", Department = "shashlik", Name = "Tovuq goʻshti shashlik", Price = 22000, IsAvailable = true },
                new Product { Id = 104, CategoryId = 1, CategoryName = "Shashliklar", Department = "shashlik", Name = "Jigar va dumba shashlik", Price = 25000, IsAvailable = true },
                new Product { Id = 105, CategoryId = 1, CategoryName = "Shashliklar", Department = "shashlik", Name = "Qovurgʻa shashlik", Price = 32000, IsAvailable = true },
                new Product { Id = 106, CategoryId = 1, CategoryName = "Shashliklar", Department = "shashlik", Name = "Uch panja shashlik", Price = 35000, IsAvailable = true },
                new Product { Id = 107, CategoryId = 1, CategoryName = "Shashliklar", Department = "shashlik", Name = "Qoʻgʻirgoq shashlik", Price = 27000, IsAvailable = false }, // Stop-listed!
                new Product { Id = 108, CategoryId = 1, CategoryName = "Shashliklar", Department = "shashlik", Name = "Baliq lahm shashlik", Price = 30000, IsAvailable = true },

                // Somsalar
                new Product { Id = 201, CategoryId = 2, CategoryName = "Tandir somsalar", Department = "somsa", Name = "Tandir goʻshtli somsa", Price = 12000, IsAvailable = true },
                new Product { Id = 202, CategoryId = 2, CategoryName = "Tandir somsalar", Department = "somsa", Name = "Qatlama qovoqli somsa", Price = 9000, IsAvailable = true },
                new Product { Id = 203, CategoryId = 2, CategoryName = "Tandir somsalar", Department = "somsa", Name = "Tovuqli somsa", Price = 10000, IsAvailable = true },
                new Product { Id = 204, CategoryId = 2, CategoryName = "Tandir somsalar", Department = "somsa", Name = "Pishloqli mini somsa (5 dona)", Price = 18000, IsAvailable = true },
                new Product { Id = 205, CategoryId = 2, CategoryName = "Tandir somsalar", Department = "somsa", Name = "Jizzaxcha katta somsa", Price = 16000, IsAvailable = true },

                // Issiq taomlar
                new Product { Id = 301, CategoryId = 3, CategoryName = "Issiq taomlar", Department = "kitchen", Name = "Toshkent toʻy oshi", Price = 38000, IsAvailable = true },
                new Product { Id = 302, CategoryId = 3, CategoryName = "Issiq taomlar", Department = "kitchen", Name = "Qozon kabob qoʻzichoq goʻshti", Price = 65000, IsAvailable = true },
                new Product { Id = 303, CategoryId = 3, CategoryName = "Issiq taomlar", Department = "kitchen", Name = "Lagʻmon choʻzma anʼanaviy", Price = 34000, IsAvailable = true },
                new Product { Id = 304, CategoryId = 3, CategoryName = "Issiq taomlar", Department = "kitchen", Name = "Shoʻrva qoʻy goʻshtli", Price = 32000, IsAvailable = true },
                new Product { Id = 305, CategoryId = 3, CategoryName = "Issiq taomlar", Department = "kitchen", Name = "Mastava maxsus qatiq bilan", Price = 28000, IsAvailable = true },
                new Product { Id = 306, CategoryId = 3, CategoryName = "Issiq taomlar", Department = "kitchen", Name = "Manti goʻshtli (5 dona)", Price = 35000, IsAvailable = true },
                new Product { Id = 307, CategoryId = 3, CategoryName = "Issiq taomlar", Department = "kitchen", Name = "Chuchvara qaymoq bilan", Price = 30000, IsAvailable = true },
                new Product { Id = 308, CategoryId = 3, CategoryName = "Issiq taomlar", Department = "kitchen", Name = "Norin ot goʻshti bilan", Price = 42000, IsAvailable = true },
                new Product { Id = 309, CategoryId = 3, CategoryName = "Issiq taomlar", Department = "kitchen", Name = "Koʻza shoʻrva tandirda", Price = 45000, IsAvailable = false }, // Stop-listed!
                new Product { Id = 310, CategoryId = 3, CategoryName = "Issiq taomlar", Department = "kitchen", Name = "Tabaka joʻja qovurilgan kartoshka bilan", Price = 55000, IsAvailable = true },
                // Very long name as required by §11:
                new Product { Id = 311, CategoryId = 3, CategoryName = "Issiq taomlar", Department = "kitchen", Name = "Dilkash maxsus shohona goʻshtli assorti tovoq 4 kishilik katta garnir bilan", Price = 180000, IsAvailable = true },

                // Fast-Food
                new Product { Id = 401, CategoryId = 4, CategoryName = "Fast-food", Department = "fastfood", Name = "Dilkash Burger Double Cheese", Price = 36000, IsAvailable = true },
                new Product { Id = 402, CategoryId = 4, CategoryName = "Fast-food", Department = "fastfood", Name = "Lavash mol goʻshti standart", Price = 32000, IsAvailable = true },
                new Product { Id = 403, CategoryId = 4, CategoryName = "Fast-food", Department = "fastfood", Name = "Lavash mol goʻshti achchiq", Price = 33000, IsAvailable = true },
                new Product { Id = 404, CategoryId = 4, CategoryName = "Fast-food", Department = "fastfood", Name = "Shaurma tovuqli sous bilan", Price = 28000, IsAvailable = true },
                new Product { Id = 405, CategoryId = 4, CategoryName = "Fast-food", Department = "fastfood", Name = "Hot-dog korolevskiy pishloqli", Price = 24000, IsAvailable = true },
                new Product { Id = 406, CategoryId = 4, CategoryName = "Fast-food", Department = "fastfood", Name = "Kartoshka fri xurram", Price = 18000, IsAvailable = true },
                new Product { Id = 407, CategoryId = 4, CategoryName = "Fast-food", Department = "fastfood", Name = "Qishloqcha kartoshka tillarang", Price = 20000, IsAvailable = true },

                // Salatlar
                new Product { Id = 501, CategoryId = 5, CategoryName = "Salatlar va gazaklar", Department = "kitchen", Name = "Achchiq-chuchuk pomidor piyoz", Price = 14000, IsAvailable = true },
                new Product { Id = 502, CategoryId = 5, CategoryName = "Salatlar va gazaklar", Department = "kitchen", Name = "Suzma koʻkatlar bilan", Price = 12000, IsAvailable = true },
                new Product { Id = 503, CategoryId = 5, CategoryName = "Salatlar va gazaklar", Department = "kitchen", Name = "Sezar salat tovuqli", Price = 32000, IsAvailable = true },
                new Product { Id = 504, CategoryId = 5, CategoryName = "Salatlar va gazaklar", Department = "kitchen", Name = "Grecheskiy zaytunli salat", Price = 29000, IsAvailable = true },

                // Choy va ichimliklar (subkategoriyalar: Issiq choy va qahva / Salqin ichimliklar)
                new Product { Id = 601, CategoryId = 8, CategoryName = "Issiq choy va qahva", Department = "bar", Name = "Koʻk choy limon bilan (choynak)", Price = 10000, IsAvailable = true },
                new Product { Id = 602, CategoryId = 8, CategoryName = "Issiq choy va qahva", Department = "bar", Name = "Qora choy togʻ giyohlari bilan", Price = 12000, IsAvailable = true },
                new Product { Id = 603, CategoryId = 9, CategoryName = "Salqin ichimliklar", Department = "bar", Name = "Yangi siqilgan apelsin sharbati", Price = 25000, IsAvailable = true },
                new Product { Id = 604, CategoryId = 9, CategoryName = "Salqin ichimliklar", Department = "bar", Name = "Moxito qulupnayli sovuq", Price = 22000, IsAvailable = true },
                new Product { Id = 605, CategoryId = 9, CategoryName = "Salqin ichimliklar", Department = "bar", Name = "Coca-Cola 1.5L shisha", Price = 16000, IsAvailable = true },
                new Product { Id = 606, CategoryId = 8, CategoryName = "Issiq choy va qahva", Department = "bar", Name = "Americano qahva", Price = 18000, IsAvailable = true },
                new Product { Id = 607, CategoryId = 8, CategoryName = "Issiq choy va qahva", Department = "bar", Name = "Cappuccino koʻpikli", Price = 22000, IsAvailable = true },

                // Shirinliklar
                new Product { Id = 701, CategoryId = 7, CategoryName = "Shirinliklar", Department = "bar", Name = "Medovik anʼanaviy asal torti", Price = 24000, IsAvailable = true },
                new Product { Id = 702, CategoryId = 7, CategoryName = "Shirinliklar", Department = "bar", Name = "Chizkeyk Nyu-York qulupnayli", Price = 28000, IsAvailable = true },
                new Product { Id = 703, CategoryId = 7, CategoryName = "Shirinliklar", Department = "bar", Name = "Turkcha paxlava pista bilan", Price = 26000, IsAvailable = true },
                new Product { Id = 704, CategoryId = 7, CategoryName = "Shirinliklar", Department = "bar", Name = "Mavsumiy mevali assorti", Price = 45000, IsAvailable = true }
            };

            // 12 ta stollar barcha holatlarda: free, occupied with 3m and 75m timer, bill printed, reserved
            var tables = new List<RestaurantTable>
            {
                // Zal
                new RestaurantTable { Id = 1, Number = 1, Name = "Stol #1", Zone = "Zal", Capacity = 4, IsOccupied = false, Status = "empty" },
                new RestaurantTable
                {
                    Id = 2, Number = 2, Name = "Stol #2", Zone = "Zal", Capacity = 4, IsOccupied = true, Status = "occupied",
                    AssignedWaiter = "Sardor", GuestsCount = 3,
                    ActiveOrder = new Order
                    {
                        Id = 201, OrderNumber = "D-201", TableNumber = "2", GuestsCount = 3, WaiterName = "Sardor", ServiceType = "dine_in", ElapsedMinutes = 3,
                        Items = new List<OrderItem>
                        {
                            new OrderItem { ProductId = 101, ProductName = "Qoʻy goʻshti shashlik", Price = 28000, Quantity = 3, Department = "shashlik" },
                            new OrderItem { ProductId = 501, ProductName = "Achchiq-chuchuk pomidor piyoz", Price = 14000, Quantity = 2, Department = "kitchen" },
                            new OrderItem { ProductId = 601, ProductName = "Koʻk choy limon bilan", Price = 10000, Quantity = 1, Department = "bar" }
                        }
                    }
                },
                new RestaurantTable
                {
                    Id = 3, Number = 3, Name = "Stol #3", Zone = "Zal", Capacity = 4, IsOccupied = true, Status = "occupied",
                    AssignedWaiter = "Nodir", GuestsCount = 4,
                    ActiveOrder = new Order
                    {
                        Id = 202, OrderNumber = "D-202", TableNumber = "3", GuestsCount = 4, WaiterName = "Nodir", ServiceType = "dine_in", ElapsedMinutes = 75, // >60m attention!
                        Items = new List<OrderItem>
                        {
                            new OrderItem { ProductId = 301, ProductName = "Toshkent toʻy oshi", Price = 38000, Quantity = 4, Department = "kitchen" },
                            new OrderItem { ProductId = 101, ProductName = "Qoʻy goʻshti shashlik", Price = 28000, Quantity = 4, Department = "shashlik" },
                            new OrderItem { ProductId = 201, ProductName = "Tandir goʻshtli somsa", Price = 12000, Quantity = 4, Department = "somsa" },
                            new OrderItem { ProductId = 605, ProductName = "Coca-Cola 1.5L shisha", Price = 16000, Quantity = 2, Department = "bar" }
                        }
                    }
                },
                new RestaurantTable
                {
                    Id = 4, Number = 4, Name = "Stol #4", Zone = "Zal", Capacity = 6, IsOccupied = true, Status = "bill_printed", // bill requested
                    AssignedWaiter = "Jasur", GuestsCount = 5,
                    ActiveOrder = new Order
                    {
                        Id = 203, OrderNumber = "D-203", TableNumber = "4", GuestsCount = 5, WaiterName = "Jasur", ServiceType = "dine_in", ElapsedMinutes = 48,
                        Items = new List<OrderItem>
                        {
                            new OrderItem { ProductId = 302, ProductName = "Qozon kabob qoʻzichoq goʻshti", Price = 65000, Quantity = 4, Department = "kitchen" },
                            new OrderItem { ProductId = 106, ProductName = "Uch panja shashlik", Price = 35000, Quantity = 3, Department = "shashlik" },
                            new OrderItem { ProductId = 503, ProductName = "Sezar salat tovuqli", Price = 32000, Quantity = 2, Department = "kitchen" },
                            new OrderItem { ProductId = 603, ProductName = "Yangi siqilgan apelsin sharbati", Price = 25000, Quantity = 3, Department = "bar" }
                        }
                    }
                },
                new RestaurantTable { Id = 5, Number = 5, Name = "Stol #5", Zone = "Zal", Capacity = 4, IsOccupied = false, Status = "empty" },
                new RestaurantTable { Id = 6, Number = 6, Name = "Stol #6", Zone = "Zal", Capacity = 4, IsOccupied = false, Status = "empty" },

                // Terrasa
                new RestaurantTable
                {
                    Id = 7, Number = 7, Name = "Terrasa #1", Zone = "Terrasa", Capacity = 6, IsOccupied = true, Status = "occupied",
                    AssignedWaiter = "Aziz", GuestsCount = 6,
                    ActiveOrder = new Order
                    {
                        Id = 204, OrderNumber = "D-204", TableNumber = "7", GuestsCount = 6, WaiterName = "Aziz", ServiceType = "dine_in", ElapsedMinutes = 25,
                        Items = new List<OrderItem>
                        {
                            new OrderItem { ProductId = 105, ProductName = "Qovurgʻa shashlik", Price = 32000, Quantity = 6, Department = "shashlik" },
                            new OrderItem { ProductId = 406, ProductName = "Kartoshka fri xurram", Price = 18000, Quantity = 3, Department = "fastfood" },
                            new OrderItem { ProductId = 605, ProductName = "Coca-Cola 1.5L shisha", Price = 16000, Quantity = 2, Department = "bar" }
                        }
                    }
                },
                new RestaurantTable { Id = 8, Number = 8, Name = "Terrasa #2", Zone = "Terrasa", Capacity = 6, IsOccupied = false, Status = "empty" },
                new RestaurantTable
                {
                    Id = 9, Number = 9, Name = "Terrasa #3", Zone = "Terrasa", Capacity = 6, IsOccupied = true, Status = "bill_printed",
                    AssignedWaiter = "Sardor", GuestsCount = 4,
                    ActiveOrder = new Order
                    {
                        Id = 205, OrderNumber = "D-205", TableNumber = "9", GuestsCount = 4, WaiterName = "Sardor", ServiceType = "dine_in", ElapsedMinutes = 52,
                        Items = new List<OrderItem>
                        {
                            new OrderItem { ProductId = 303, ProductName = "Lagʻmon choʻzma anʼanaviy", Price = 34000, Quantity = 4, Department = "kitchen" },
                            new OrderItem { ProductId = 201, ProductName = "Tandir goʻshtli somsa", Price = 12000, Quantity = 4, Department = "somsa" }
                        }
                    }
                },

                // VIP Xonalar
                new RestaurantTable { Id = 10, Number = 10, Name = "VIP Xona #1", Zone = "VIP", Capacity = 10, IsOccupied = false, Status = "reserved" }, // Reserved!
                new RestaurantTable
                {
                    Id = 11, Number = 11, Name = "VIP Xona #2", Zone = "VIP", Capacity = 10, IsOccupied = true, Status = "occupied",
                    AssignedWaiter = "Jasur", GuestsCount = 8,
                    ActiveOrder = new Order
                    {
                        Id = 206, OrderNumber = "D-206", TableNumber = "11", GuestsCount = 8, WaiterName = "Jasur", ServiceType = "dine_in", ElapsedMinutes = 88, // attention
                        Items = new List<OrderItem>
                        {
                            new OrderItem { ProductId = 311, ProductName = "Dilkash maxsus shohona goʻshtli assorti tovoq 4 kishilik katta garnir bilan", Price = 180000, Quantity = 2, Department = "kitchen" },
                            new OrderItem { ProductId = 106, ProductName = "Uch panja shashlik", Price = 35000, Quantity = 6, Department = "shashlik" },
                            new OrderItem { ProductId = 704, ProductName = "Mavsumiy mevali assorti", Price = 45000, Quantity = 2, Department = "bar" },
                            new OrderItem { ProductId = 603, ProductName = "Yangi siqilgan apelsin sharbati", Price = 25000, Quantity = 5, Department = "bar" }
                        }
                    }
                },
                new RestaurantTable { Id = 12, Number = 12, Name = "VIP Xona #3", Zone = "VIP", Capacity = 12, IsOccupied = false, Status = "empty" }
            };

            foreach (var t in tables)
            {
                if (t.ActiveOrder != null)
                {
                    t.ActiveOrder.RecalculateTotals();
                }
            }

            // 3 ta online buyurtmalar
            var onlineOrders = new List<Order>
            {
                new Order
                {
                    Id = 801, OrderNumber = "TL-801", ServiceType = "delivery", CustomerName = "Alisher Usmonov", CustomerPhone = "+998 90 123 45 67",
                    CreatedAt = "2 daqiqa oldin", TotalAmount = 245000,
                    Items = new List<OrderItem>
                    {
                        new OrderItem { ProductName = "Toshkent toʻy oshi", Price = 38000, Quantity = 3, Department = "kitchen" },
                        new OrderItem { ProductName = "Qoʻy goʻshti shashlik", Price = 28000, Quantity = 4, Department = "shashlik" },
                        new OrderItem { ProductName = "Coca-Cola 1.5L", Price = 16000, Quantity = 1, Department = "bar" }
                    }
                },
                new Order
                {
                    Id = 802, OrderNumber = "AP-802", ServiceType = "pickup", CustomerName = "Malika Karimova", CustomerPhone = "+998 97 765 43 21",
                    CreatedAt = "6 daqiqa oldin", TotalAmount = 98000,
                    Items = new List<OrderItem>
                    {
                        new OrderItem { ProductName = "Dilkash Burger Double Cheese", Price = 36000, Quantity = 2, Department = "fastfood" },
                        new OrderItem { ProductName = "Kartoshka fri xurram", Price = 18000, Quantity = 1, Department = "fastfood" },
                        new OrderItem { ProductName = "Moxito qulupnayli", Price = 22000, Quantity = 1, Department = "bar" }
                    }
                },
                new Order
                {
                    Id = 803, OrderNumber = "TL-803", ServiceType = "delivery", CustomerName = "Bobur Mirzayev", CustomerPhone = "+998 93 555 88 99",
                    CreatedAt = "9 daqiqa oldin", TotalAmount = 385000,
                    Items = new List<OrderItem>
                    {
                        new OrderItem { ProductName = "Qozon kabob qoʻzichoq", Price = 65000, Quantity = 3, Department = "kitchen" },
                        new OrderItem { ProductName = "Tandir goʻshtli somsa", Price = 12000, Quantity = 6, Department = "somsa" },
                        new OrderItem { ProductName = "Sezar salat tovuqli", Price = 32000, Quantity = 2, Department = "kitchen" }
                    }
                }
            };

            var shift = new ShiftReport
            {
                OpenedAt = DateTime.Today.AddHours(8).AddMinutes(30),
                CashierName = "Jasur Rahimov",
                TotalOrdersCount = 48,
                TotalRevenue = 14650000,
                CashRevenue = 8900000,
                CardRevenue = 4250000,
                OnlineRevenue = 1500000,
                DineInRevenue = 11200000,
                TakeawayRevenue = 3450000,
                ServiceFeesCollected = 1465000,
                DiscountsGiven = 450000
            };

            var settings = new PosSettings
            {
                ServerUrl = "http://127.0.0.1:8000",
                CashierName = "Jasur Rahimov",
                ServiceFeeType = "percent",
                ServiceFeePercent = 10,
                AutoPrintNetwork = true,
                Printers = new Dictionary<string, string>
                {
                    { "kassa", "192.168.1.100:9100" },
                    { "shashlik", "192.168.1.101:9100" },
                    { "somsa", "192.168.1.102:9100" },
                    { "kitchen", "192.168.1.103:9100" },
                    { "fastfood", "192.168.1.104:9100" },
                    { "bar", "192.168.1.105:9100" }
                }
            };

            return (departments, categories, products, tables, onlineOrders, shift, settings);
        }

        public static Order GetDemoCart()
        {
            var cart = new Order
            {
                OrderNumber = "D-2026",
                ServiceType = "dine_in",
                TableNumber = "4",
                GuestsCount = 4,
                WaiterName = "Sardor",
                DiscountPercent = 10,
                Items = new List<OrderItem>
                {
                    new OrderItem { ProductId = 101, ProductName = "Qoʻy goʻshti shashlik", Price = 28000, Quantity = 4, Department = "shashlik", Notes = "Piyozi koʻproq boʻlsin" },
                    new OrderItem { ProductId = 106, ProductName = "Uch panja shashlik", Price = 35000, Quantity = 2, Department = "shashlik", Notes = "Achchiq boʻlsin" },
                    new OrderItem { ProductId = 201, ProductName = "Tandir goʻshtli somsa", Price = 12000, Quantity = 4, Department = "somsa" },
                    new OrderItem { ProductId = 301, ProductName = "Toshkent toʻy oshi", Price = 38000, Quantity = 2, Department = "kitchen" },
                    new OrderItem { ProductId = 501, ProductName = "Achchiq-chuchuk pomidor piyoz", Price = 14000, Quantity = 2, Department = "kitchen" },
                    new OrderItem { ProductId = 601, ProductName = "Koʻk choy limon bilan", Price = 10000, Quantity = 2, Department = "bar" },
                    new OrderItem { ProductId = 605, ProductName = "Coca-Cola 1.5L shisha", Price = 16000, Quantity = 1, Department = "bar" },
                    new OrderItem { ProductId = 701, ProductName = "Medovik anʼanaviy asal torti", Price = 24000, Quantity = 2, Department = "bar" }
                }
            };
            cart.ServiceFeeAmount = 32800;
            cart.RecalculateTotals();
            return cart;
        }

        public static List<Hall> GetDemoHalls() => new()
        {
            new Hall { Id = 1, Name = "Zal", Description = "Asosiy zal", SortOrder = 1, IsActive = true },
            new Hall { Id = 2, Name = "Terrasa", Description = "Yozgi ochiq ayvon", SortOrder = 2, IsActive = true },
            new Hall { Id = 3, Name = "VIP", Description = "Alohida kabinalar", SortOrder = 3, IsActive = true }
        };

        public static List<PosPrinter> GetDemoPrinters() => new()
        {
            new PosPrinter { Id = 1, Name = "Kassa hisob printeri", Department = "kassa", IpAddress = "192.168.1.100", Port = 9100, PaperWidth = 80, Subtitle = "Mijoz hisob-kitob cheki", IsActive = true, SortOrder = 1 },
            new PosPrinter { Id = 2, Name = "Shashlikxona", Department = "shashlik", IpAddress = "192.168.1.101", Port = 9100, PaperWidth = 80, Subtitle = "Mangal boʻlimi", IsActive = true, SortOrder = 2 },
            new PosPrinter { Id = 3, Name = "Somsaxona", Department = "somsa", IpAddress = "192.168.1.102", Port = 9100, PaperWidth = 80, Subtitle = "Tandir boʻlimi", IsActive = true, SortOrder = 3 },
            new PosPrinter { Id = 4, Name = "Issiq oshxona", Department = "kitchen", IpAddress = "192.168.1.103", Port = 9100, PaperWidth = 80, Subtitle = "Oshxona boʻlimi", IsActive = true, SortOrder = 4 },
            new PosPrinter { Id = 5, Name = "Fast-food (58mm)", Department = "fastfood", IpAddress = "192.168.1.104", Port = 9100, PaperWidth = 58, Subtitle = "Burger va lavash", IsActive = true, SortOrder = 5 },
            new PosPrinter { Id = 6, Name = "Bar va ichimliklar", Department = "bar", IpAddress = "192.168.1.105", Port = 9100, PaperWidth = 80, Subtitle = "Choy, qahva, salqin ichimliklar", IsActive = false, SortOrder = 6 }
        };

        public static CashierProfile GetDemoCashierProfile() => new()
        {
            Id = 1,
            Name = "Jasur Rahimov",
            Phone = "+998901112233",
            RoleTitle = "Bosh kassir",
            AvatarColor = "#10B981",
            RequirePinOnUnlock = false,
            NotificationSound = true,
            HasPin = true,
            IsActive = true,
            IsPrimary = true
        };

        public static List<Ingredient> GetDemoIngredients() => new()
        {
            new Ingredient { Id = 1, Name = "Mol goʻshti (lahm)", Category = "meat", CategoryDisplay = "Goʻsht mahsulotlari", Unit = "kg", UnitDisplay = "kg", CurrentStock = 45.5m, MinStockAlert = 10m, CostPrice = 90000m, IsActive = true, IsLowStock = false, TotalValuation = 45.5m * 90000m },
            new Ingredient { Id = 2, Name = "Qoʻy goʻshti (lahm)", Category = "meat", CategoryDisplay = "Goʻsht mahsulotlari", Unit = "kg", UnitDisplay = "kg", CurrentStock = 28.0m, MinStockAlert = 8m, CostPrice = 98000m, IsActive = true, IsLowStock = false, TotalValuation = 28.0m * 98000m },
            new Ingredient { Id = 3, Name = "Qoʻy dumbasi", Category = "meat", CategoryDisplay = "Goʻsht mahsulotlari", Unit = "kg", UnitDisplay = "kg", CurrentStock = 14.2m, MinStockAlert = 5m, CostPrice = 85000m, IsActive = true, IsLowStock = false, TotalValuation = 14.2m * 85000m },
            new Ingredient { Id = 4, Name = "Tovuq goʻshti (file)", Category = "meat", CategoryDisplay = "Goʻsht mahsulotlari", Unit = "kg", UnitDisplay = "kg", CurrentStock = 32.0m, MinStockAlert = 10m, CostPrice = 42000m, IsActive = true, IsLowStock = false, TotalValuation = 32.0m * 42000m },
            new Ingredient { Id = 5, Name = "Devzira guruch", Category = "grains", CategoryDisplay = "Don, guruch va un", Unit = "kg", UnitDisplay = "kg", CurrentStock = 60.0m, MinStockAlert = 15m, CostPrice = 32000m, IsActive = true, IsLowStock = false, TotalValuation = 60.0m * 32000m },
            new Ingredient { Id = 6, Name = "Lazer guruch", Category = "grains", CategoryDisplay = "Don, guruch va un", Unit = "kg", UnitDisplay = "kg", CurrentStock = 85.0m, MinStockAlert = 20m, CostPrice = 26000m, IsActive = true, IsLowStock = false, TotalValuation = 85.0m * 26000m },
            new Ingredient { Id = 7, Name = "Oliy navli un", Category = "grains", CategoryDisplay = "Don, guruch va un", Unit = "kg", UnitDisplay = "kg", CurrentStock = 120.0m, MinStockAlert = 25m, CostPrice = 7500m, IsActive = true, IsLowStock = false, TotalValuation = 120.0m * 7500m },
            new Ingredient { Id = 8, Name = "Sabzi sariq", Category = "vegetables", CategoryDisplay = "Sabzavot va koʻkatlar", Unit = "kg", UnitDisplay = "kg", CurrentStock = 4.5m, MinStockAlert = 10m, CostPrice = 4000m, IsActive = true, IsLowStock = true, TotalValuation = 4.5m * 4000m }, // Low stock!
            new Ingredient { Id = 9, Name = "Piyoz", Category = "vegetables", CategoryDisplay = "Sabzavot va koʻkatlar", Unit = "kg", UnitDisplay = "kg", CurrentStock = 55.0m, MinStockAlert = 15m, CostPrice = 3500m, IsActive = true, IsLowStock = false, TotalValuation = 55.0m * 3500m },
            new Ingredient { Id = 10, Name = "Pomidor", Category = "vegetables", CategoryDisplay = "Sabzavot va koʻkatlar", Unit = "kg", UnitDisplay = "kg", CurrentStock = 3.2m, MinStockAlert = 8m, CostPrice = 18000m, IsActive = true, IsLowStock = true, TotalValuation = 3.2m * 18000m }, // Low stock!
            new Ingredient { Id = 11, Name = "Paxta yogʻi", Category = "dairy_oil", CategoryDisplay = "Yogʻ va sut mahsulotlari", Unit = "l", UnitDisplay = "l", CurrentStock = 40.0m, MinStockAlert = 10m, CostPrice = 18000m, IsActive = true, IsLowStock = false, TotalValuation = 40.0m * 18000m },
            new Ingredient { Id = 12, Name = "Zira xushboʻy", Category = "spices", CategoryDisplay = "Ziravorlar va souslar", Unit = "kg", UnitDisplay = "kg", CurrentStock = 2.5m, MinStockAlert = 1m, CostPrice = 120000m, IsActive = true, IsLowStock = false, TotalValuation = 2.5m * 120000m },
            new Ingredient { Id = 13, Name = "Coca-Cola 1.5L shisha", Category = "drinks", CategoryDisplay = "Qadoqlangan ichimliklar", Unit = "dona", UnitDisplay = "dona", CurrentStock = 48m, MinStockAlert = 12m, CostPrice = 11500m, IsActive = true, IsLowStock = false, TotalValuation = 48m * 11500m },
            new Ingredient { Id = 14, Name = "Koʻk choy (quruq)", Category = "spices", CategoryDisplay = "Ziravorlar va souslar", Unit = "kg", UnitDisplay = "kg", CurrentStock = 6.0m, MinStockAlert = 2m, CostPrice = 65000m, IsActive = true, IsLowStock = false, TotalValuation = 6.0m * 65000m }
        };

        public static List<Supplier> GetDemoSuppliers() => new()
        {
            new Supplier { Id = 1, Name = "Chorsu Goʻsht Markazi", Phone = "+998901234567", ContactPerson = "Alisher aka", Address = "Toshkent, Chorsu bozori, 4-rastaxona", Balance = 1250000m, IsActive = true },
            new Supplier { Id = 2, Name = "Qoʻyliq Sabzavot Ulgurji", Phone = "+998912345678", ContactPerson = "Bobur aka", Address = "Qoʻyliq dehqon bozori, 12-ombor", Balance = 0m, IsActive = true },
            new Supplier { Id = 3, Name = "Voha Guruch va Don Savdosi", Phone = "+998933456789", ContactPerson = "Rustam aka", Address = "Chilonzor 19-mavze", Balance = 450000m, IsActive = true },
            new Supplier { Id = 4, Name = "Coca-Cola Bottlers Uzbekistan", Phone = "+998712005555", ContactPerson = "Menejer Sardor", Address = "Toshkent sh., Yashnobod tumani", Balance = 0m, IsActive = true }
        };

        public static List<RecipeItem> GetDemoRecipes() => new()
        {
            // Osh (301)
            new RecipeItem { Id = 1, ProductId = 301, ProductName = "Toshkent toʻy oshi", IngredientId = 1, IngredientName = "Mol goʻshti (lahm)", Quantity = 150m, Unit = "g", IngredientUnit = "kg", Cost = 13500m },
            new RecipeItem { Id = 2, ProductId = 301, ProductName = "Toshkent toʻy oshi", IngredientId = 6, IngredientName = "Lazer guruch", Quantity = 200m, Unit = "g", IngredientUnit = "kg", Cost = 5200m },
            new RecipeItem { Id = 3, ProductId = 301, ProductName = "Toshkent toʻy oshi", IngredientId = 8, IngredientName = "Sabzi sariq", Quantity = 250m, Unit = "g", IngredientUnit = "kg", Cost = 1000m },
            new RecipeItem { Id = 4, ProductId = 301, ProductName = "Toshkent toʻy oshi", IngredientId = 9, IngredientName = "Piyoz", Quantity = 80m, Unit = "g", IngredientUnit = "kg", Cost = 280m },
            new RecipeItem { Id = 5, ProductId = 301, ProductName = "Toshkent toʻy oshi", IngredientId = 11, IngredientName = "Paxta yogʻi", Quantity = 50m, Unit = "ml", IngredientUnit = "l", Cost = 900m },
            new RecipeItem { Id = 6, ProductId = 301, ProductName = "Toshkent toʻy oshi", IngredientId = 12, IngredientName = "Zira xushboʻy", Quantity = 5m, Unit = "g", IngredientUnit = "kg", Cost = 600m },

            // Shashlik (101)
            new RecipeItem { Id = 7, ProductId = 101, ProductName = "Qoʻy goʻshti shashlik", IngredientId = 2, IngredientName = "Qoʻy goʻshti (lahm)", Quantity = 160m, Unit = "g", IngredientUnit = "kg", Cost = 15680m },
            new RecipeItem { Id = 8, ProductId = 101, ProductName = "Qoʻy goʻshti shashlik", IngredientId = 3, IngredientName = "Qoʻy dumbasi", Quantity = 40m, Unit = "g", IngredientUnit = "kg", Cost = 3400m },
            new RecipeItem { Id = 9, ProductId = 101, ProductName = "Qoʻy goʻshti shashlik", IngredientId = 9, IngredientName = "Piyoz", Quantity = 50m, Unit = "g", IngredientUnit = "kg", Cost = 175m },

            // Tandir somsa (201)
            new RecipeItem { Id = 10, ProductId = 201, ProductName = "Tandir goʻshtli somsa", IngredientId = 1, IngredientName = "Mol goʻshti (lahm)", Quantity = 60m, Unit = "g", IngredientUnit = "kg", Cost = 5400m },
            new RecipeItem { Id = 11, ProductId = 201, ProductName = "Tandir goʻshtli somsa", IngredientId = 3, IngredientName = "Qoʻy dumbasi", Quantity = 20m, Unit = "g", IngredientUnit = "kg", Cost = 1700m },
            new RecipeItem { Id = 12, ProductId = 201, ProductName = "Tandir goʻshtli somsa", IngredientId = 7, IngredientName = "Oliy navli un", Quantity = 70m, Unit = "g", IngredientUnit = "kg", Cost = 525m },
            new RecipeItem { Id = 13, ProductId = 201, ProductName = "Tandir goʻshtli somsa", IngredientId = 9, IngredientName = "Piyoz", Quantity = 40m, Unit = "g", IngredientUnit = "kg", Cost = 140m },

            // Choy (601)
            new RecipeItem { Id = 14, ProductId = 601, ProductName = "Koʻk choy limon bilan (choynak)", IngredientId = 14, IngredientName = "Koʻk choy (quruq)", Quantity = 15m, Unit = "g", IngredientUnit = "kg", Cost = 975m }
        };

        public static InventoryKpiSummary GetDemoInventoryKpi(List<Ingredient>? ings = null)
        {
            var list = ings ?? GetDemoIngredients();
            var totalVal = list.Sum(i => i.TotalValuation);
            var lowCount = list.Count(i => i.IsLowStock);
            return new InventoryKpiSummary
            {
                TotalIngredients = list.Count,
                LowStockCount = lowCount,
                TotalValuation = totalVal,
                TodaySuppliesTotal = 3450000m,
                TodayWriteoffsTotal = 85000m,
                SuppliersCount = 4
            };
        }

        public static List<StockSupply> GetDemoSupplies() => new()
        {
            new StockSupply
            {
                Id = 1,
                DocNumber = "KIR-20261115-001",
                SupplierId = 1,
                SupplierName = "Chorsu Goʻsht Markazi",
                Date = DateTime.Now.AddHours(-3),
                TotalCost = 3450000m,
                PaymentStatus = "paid",
                PaymentStatusDisplay = "Toʻlangan",
                PaidAmount = 3450000m,
                Notes = "Mol va qoʻy goʻshti yangi partiya",
                CreatedBy = "Jasur Rahimov",
                ItemsCount = 2,
                Items = new List<StockSupplyItem>
                {
                    new StockSupplyItem { Id = 1, IngredientId = 1, IngredientName = "Mol goʻshti (lahm)", IngredientUnit = "kg", Quantity = 25m, UnitPrice = 90000m, TotalPrice = 2250000m },
                    new StockSupplyItem { Id = 2, IngredientId = 2, IngredientName = "Qoʻy goʻshti (lahm)", IngredientUnit = "kg", Quantity = 12m, UnitPrice = 100000m, TotalPrice = 1200000m }
                }
            }
        };

        public static List<StockMovementLogItem> GetDemoMovements() => new()
        {
            new StockMovementLogItem { Id = 1, CreatedAt = DateTime.Now.AddMinutes(-15), CreatedAtDisplay = "Bugun 14:45", IngredientId = 1, IngredientName = "Mol goʻshti (lahm)", IngredientUnit = "kg", MovementType = "order_deduction", MovementTypeDisplay = "Savdo (Avto chegirish)", QuantityDelta = -0.300m, StockBefore = 45.8m, StockAfter = 45.5m, UnitCost = 90000m, Notes = "Stol #3 toʻlovidan avtomatik chegirildi" },
            new StockMovementLogItem { Id = 2, CreatedAt = DateTime.Now.AddMinutes(-40), CreatedAtDisplay = "Bugun 14:20", IngredientId = 6, IngredientName = "Lazer guruch", IngredientUnit = "kg", MovementType = "order_deduction", MovementTypeDisplay = "Savdo (Avto chegirish)", QuantityDelta = -0.400m, StockBefore = 85.4m, StockAfter = 85.0m, UnitCost = 26000m, Notes = "Saboy buyurtmasidan avtomatik chegirildi" },
            new StockMovementLogItem { Id = 3, CreatedAt = DateTime.Now.AddHours(-2), CreatedAtDisplay = "Bugun 13:00", IngredientId = 8, IngredientName = "Sabzi sariq", IngredientUnit = "kg", MovementType = "write_off", MovementTypeDisplay = "Chiqim (Spisaniye)", QuantityDelta = -2.5m, StockBefore = 7.0m, StockAfter = 4.5m, UnitCost = 4000m, Notes = "Aynigan sabzavotlar hisobdan chiqarildi" },
            new StockMovementLogItem { Id = 4, CreatedAt = DateTime.Now.AddHours(-3), CreatedAtDisplay = "Bugun 12:00", IngredientId = 1, IngredientName = "Mol goʻshti (lahm)", IngredientUnit = "kg", MovementType = "supply", MovementTypeDisplay = "Kirim (Prihod)", QuantityDelta = 25m, StockBefore = 20.8m, StockAfter = 45.8m, UnitCost = 90000m, Notes = "KIR-20261115-001 partiyasi qabul qilindi" }
        };
    }
}

