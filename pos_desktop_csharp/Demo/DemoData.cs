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
                new Category { Id = 6, Name = "Choy va ichimliklar", Department = "bar", Icon = "coffee" },
                new Category { Id = 7, Name = "Shirinliklar", Department = "bar", Icon = "coffee" }
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

                // Choy va ichimliklar
                new Product { Id = 601, CategoryId = 6, CategoryName = "Choy va ichimliklar", Department = "bar", Name = "Koʻk choy limon bilan (choynak)", Price = 10000, IsAvailable = true },
                new Product { Id = 602, CategoryId = 6, CategoryName = "Choy va ichimliklar", Department = "bar", Name = "Qora choy togʻ giyohlari bilan", Price = 12000, IsAvailable = true },
                new Product { Id = 603, CategoryId = 6, CategoryName = "Choy va ichimliklar", Department = "bar", Name = "Yangi siqilgan apelsin sharbati", Price = 25000, IsAvailable = true },
                new Product { Id = 604, CategoryId = 6, CategoryName = "Choy va ichimliklar", Department = "bar", Name = "Moxito qulupnayli sovuq", Price = 22000, IsAvailable = true },
                new Product { Id = 605, CategoryId = 6, CategoryName = "Choy va ichimliklar", Department = "bar", Name = "Coca-Cola 1.5L shisha", Price = 16000, IsAvailable = true },
                new Product { Id = 606, CategoryId = 6, CategoryName = "Choy va ichimliklar", Department = "bar", Name = "Americano qahva", Price = 18000, IsAvailable = true },
                new Product { Id = 607, CategoryId = 6, CategoryName = "Choy va ichimliklar", Department = "bar", Name = "Cappuccino koʻpikli", Price = 22000, IsAvailable = true },

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
    }
}

