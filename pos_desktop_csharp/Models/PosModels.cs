using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Runtime.CompilerServices;

namespace DilkashPos.Models
{
    public class BaseModel : INotifyPropertyChanged
    {
        public event PropertyChangedEventHandler? PropertyChanged;
        protected void OnPropertyChanged([CallerMemberName] string? propertyName = null)
        {
            PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(propertyName));
        }
    }

    public class Department
    {
        public string Code { get; set; } = "";
        public string Name { get; set; } = "";
        public string Title { get; set; } = "";
        public string Subtitle { get; set; } = "";
        public string Icon { get; set; } = "🧾";
        public string PrinterIp { get; set; } = "";
        public string BadgeColor { get; set; } = "#10b981";
    }

    public class Category
    {
        public int Id { get; set; }
        public string Name { get; set; } = "";
        public string Department { get; set; } = "kitchen";
        public string Description { get; set; } = "";
    }

    public class Product : BaseModel
    {
        private bool _isAvailable = true;

        public int Id { get; set; }
        public string Name { get; set; } = "";
        public decimal Price { get; set; }
        public int CategoryId { get; set; }
        public string CategoryName { get; set; } = "";
        public string Department { get; set; } = "kitchen";
        public string DepartmentName { get; set; } = "";
        public string Description { get; set; } = "";
        public string? ImageUrl { get; set; }

        public bool IsAvailable
        {
            get => _isAvailable;
            set
            {
                if (_isAvailable != value)
                {
                    _isAvailable = value;
                    OnPropertyChanged();
                    OnPropertyChanged(nameof(StatusBadge));
                    OnPropertyChanged(nameof(StatusColor));
                }
            }
        }

        public string StatusBadge => IsAvailable ? "Mavjud" : "STOP-LIST";
        public string StatusColor => IsAvailable ? "#10b981" : "#ef4444";
        public string FormattedPrice => $"{Price:N0} so'm";
    }

    public class RestaurantTable : BaseModel
    {
        private bool _isOccupied;
        private int _guestsCount;
        private Order? _activeOrder;

        public int Id { get; set; }
        public int Number { get; set; }
        public string Name { get; set; } = "";
        public int Capacity { get; set; } = 4;
        public string? AssignedWaiter { get; set; }
        public string? OpenedAt { get; set; }

        public int GuestsCount
        {
            get => _guestsCount;
            set { _guestsCount = value; OnPropertyChanged(); }
        }

        public bool IsOccupied
        {
            get => _isOccupied;
            set
            {
                _isOccupied = value;
                OnPropertyChanged();
                OnPropertyChanged(nameof(StatusText));
                OnPropertyChanged(nameof(StatusColor));
            }
        }

        public Order? ActiveOrder
        {
            get => _activeOrder;
            set
            {
                _activeOrder = value;
                OnPropertyChanged();
                OnPropertyChanged(nameof(TotalSumFormatted));
                OnPropertyChanged(nameof(ElapsedMinutesFormatted));
            }
        }

        public string StatusText => IsOccupied ? "BAND" : "BO'SH";
        public string StatusColor => IsOccupied ? "#ef4444" : "#10b981";
        public string TotalSumFormatted => ActiveOrder != null ? $"{ActiveOrder.TotalAmount:N0} so'm" : "0 so'm";
        public string ElapsedMinutesFormatted => ActiveOrder != null ? $"{ActiveOrder.ElapsedMinutes} daq" : "";
    }

    public class OrderItem : BaseModel
    {
        private int _quantity = 1;

        public int Id { get; set; }
        public int ProductId { get; set; }
        public string ProductName { get; set; } = "";
        public decimal Price { get; set; }
        public string Department { get; set; } = "kitchen";
        public string CategoryName { get; set; } = "";

        public int Quantity
        {
            get => _quantity;
            set
            {
                _quantity = value;
                OnPropertyChanged();
                OnPropertyChanged(nameof(Total));
                OnPropertyChanged(nameof(FormattedTotal));
            }
        }

        public decimal Total => Quantity * Price;
        public string FormattedPrice => $"{Price:N0} so'm";
        public string FormattedTotal => $"{Total:N0} so'm";
    }

    public class Order : BaseModel
    {
        public int Id { get; set; }
        public string OrderNumber { get; set; } = "";
        public string? OfflineId { get; set; }
        public string Status { get; set; } = "yangi";
        public string ServiceType { get; set; } = "pickup"; // 'dine_in', 'pickup', 'delivery'
        public string? TableNumber { get; set; }
        public int GuestsCount { get; set; } = 1;
        public string CustomerName { get; set; } = "Mijoz";
        public string CustomerPhone { get; set; } = "";
        public string? WaiterName { get; set; }
        public string? CourierName { get; set; }
        public string Notes { get; set; } = "";
        public bool IsPaid { get; set; }
        public string PaymentMethod { get; set; } = "naqd";
        public decimal ProductsTotal { get; set; }
        public decimal ServiceFeeAmount { get; set; }
        public decimal DeliveryCost { get; set; }
        public decimal TotalAmount { get; set; }
        public string? CreatedAt { get; set; }
        public int ElapsedMinutes { get; set; }
        public List<OrderItem> Items { get; set; } = new();

        public string FormattedTotal => $"{TotalAmount:N0} so'm";
        public string FormattedProductsTotal => $"{ProductsTotal:N0} so'm";
        public string FormattedServiceFee => $"{ServiceFeeAmount:N0} so'm";
    }

    public class PosSettings
    {
        public string ServiceFeeType { get; set; } = "percent"; // 'percent', 'per_person', 'none'
        public decimal ServiceFeePercent { get; set; } = 10.0m;
        public decimal ServiceFeePerPerson { get; set; } = 5000.0m;
        public bool AutoPrintNetwork { get; set; } = false;
        public decimal DeliveryBaseCost { get; set; } = 5000.0m;
        public Dictionary<string, string> Printers { get; set; } = new();
        public string ServerUrl { get; set; } = "http://127.0.0.1:8000";
    }
}

