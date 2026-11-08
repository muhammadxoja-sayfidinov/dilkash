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

    public class Department : BaseModel
    {
        private bool _isOnline = true;

        public string Code { get; set; } = "";
        public string Name { get; set; } = "";
        public string Title { get; set; } = "";
        public string Subtitle { get; set; } = "";
        public string Icon { get; set; } = "🧾";
        public string PrinterIp { get; set; } = "";
        public string BadgeColor { get; set; } = "#10b981";

        public bool IsOnline
        {
            get => _isOnline;
            set { _isOnline = value; OnPropertyChanged(); }
        }
    }

    public class Category : BaseModel
    {
        public int Id { get; set; }
        public string Name { get; set; } = "";
        public string Department { get; set; } = "kitchen";
        public string Description { get; set; } = "";
        public string Icon { get; set; } = "🍽";
        public int ProductsCount { get; set; }
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

        public string StatusBadge => IsAvailable ? "MAVJUD" : "STOP-LIST";
        public string StatusColor => IsAvailable ? "#10B981" : "#EF4444";
        public string FormattedPrice => $"{Price:N0} so'm";
    }

    public class RestaurantTable : BaseModel
    {
        private bool _isOccupied;
        private int _guestsCount;
        private Order? _activeOrder;
        private string _status = "empty"; // 'empty', 'occupied', 'bill_printed', 'reserved'

        public int Id { get; set; }
        public int Number { get; set; }
        public string Name { get; set; } = "";
        public string Zone { get; set; } = "Zal"; // 'Zal', 'Terrasa', 'VIP'
        public int Capacity { get; set; } = 4;
        public string? AssignedWaiter { get; set; }
        public string? OpenedAt { get; set; }

        public string Status
        {
            get => _status;
            set
            {
                _status = value;
                OnPropertyChanged();
                OnPropertyChanged(nameof(StatusBadge));
                OnPropertyChanged(nameof(StatusColor));
            }
        }

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
                Status = value ? "occupied" : "empty";
                OnPropertyChanged();
                OnPropertyChanged(nameof(StatusBadge));
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
                OnPropertyChanged(nameof(ItemsCountFormatted));
            }
        }

        public string StatusBadge => Status switch
        {
            "occupied" => "BAND",
            "bill_printed" => "HISOB BERILDI",
            "reserved" => "BRON",
            _ => "BO'SH"
        };

        public string StatusColor => Status switch
        {
            "occupied" => "#EF4444",
            "bill_printed" => "#F59E0B",
            "reserved" => "#8B5CF6",
            _ => "#10B981"
        };

        public string TotalSumFormatted => ActiveOrder != null ? $"{ActiveOrder.TotalAmount:N0} so'm" : "0 so'm";
        public string ElapsedMinutesFormatted => ActiveOrder != null ? $"{ActiveOrder.ElapsedMinutes} daq" : "";
        public string ItemsCountFormatted => ActiveOrder != null ? $"{ActiveOrder.ItemsCount} ta taom" : "";
    }

    public class OrderItem : BaseModel
    {
        private int _quantity = 1;
        private string _notes = "";

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

        public string Notes
        {
            get => _notes;
            set { _notes = value; OnPropertyChanged(); }
        }

        public decimal Total => Quantity * Price;
        public string FormattedPrice => $"{Price:N0} so'm";
        public string FormattedTotal => $"{Total:N0} so'm";
    }

    public class Order : BaseModel
    {
        private decimal _discountPercent;
        private decimal _discountAmount;

        public int Id { get; set; }
        public string OrderNumber { get; set; } = "";
        public string? OfflineId { get; set; }
        public string Status { get; set; } = "yangi";
        public string ServiceType { get; set; } = "pickup"; // 'dine_in', 'pickup', 'delivery'
        public string? TableNumber { get; set; }
        public int GuestsCount { get; set; } = 1;
        public string CustomerName { get; set; } = "Kassadan Mijoz";
        public string CustomerPhone { get; set; } = "";
        public string? WaiterName { get; set; }
        public string? CourierName { get; set; }
        public string Notes { get; set; } = "";
        public bool IsPaid { get; set; }
        public string PaymentMethod { get; set; } = "naqd";
        public decimal ProductsTotal { get; set; }
        public decimal ServiceFeeAmount { get; set; }
        public decimal DeliveryCost { get; set; }

        public decimal DiscountPercent
        {
            get => _discountPercent;
            set { _discountPercent = value; OnPropertyChanged(); RecalculateTotals(); }
        }

        public decimal DiscountAmount
        {
            get => _discountAmount;
            set { _discountAmount = value; OnPropertyChanged(); RecalculateTotals(); }
        }

        public decimal TotalAmount { get; set; }
        public string? CreatedAt { get; set; }
        public int ElapsedMinutes { get; set; }
        public List<OrderItem> Items { get; set; } = new();

        public int ItemsCount => Items.Sum(i => i.Quantity);
        public string FormattedTotal => $"{TotalAmount:N0} so'm";
        public string FormattedProductsTotal => $"{ProductsTotal:N0} so'm";
        public string FormattedServiceFee => $"{ServiceFeeAmount:N0} so'm";
        public string FormattedDiscount => $"{DiscountAmount:N0} so'm";

        public void RecalculateTotals()
        {
            ProductsTotal = Items.Sum(i => i.Total);
            if (DiscountPercent > 0)
            {
                _discountAmount = ProductsTotal * (DiscountPercent / 100m);
            }
            TotalAmount = Math.Max(0, (ProductsTotal - _discountAmount) + ServiceFeeAmount + DeliveryCost);
            OnPropertyChanged(nameof(DiscountAmount));
            OnPropertyChanged(nameof(ProductsTotal));
            OnPropertyChanged(nameof(TotalAmount));
            OnPropertyChanged(nameof(FormattedTotal));
            OnPropertyChanged(nameof(FormattedProductsTotal));
            OnPropertyChanged(nameof(FormattedDiscount));
        }
    }

    public class ShiftReport
    {
        public DateTime OpenedAt { get; set; } = DateTime.Now;
        public string CashierName { get; set; } = "Kassir (Boshliq)";
        public int TotalOrdersCount { get; set; }
        public decimal TotalRevenue { get; set; }
        public decimal CashRevenue { get; set; }
        public decimal CardRevenue { get; set; }
        public decimal OnlineRevenue { get; set; }
        public decimal DineInRevenue { get; set; }
        public decimal TakeawayRevenue { get; set; }
        public decimal ServiceFeesCollected { get; set; }
        public decimal DiscountsGiven { get; set; }
    }

    public class PosSettings
    {
        public string ServiceFeeType { get; set; } = "percent"; // 'percent', 'per_person', 'none'
        public decimal ServiceFeePercent { get; set; } = 10.0m;
        public decimal ServiceFeePerPerson { get; set; } = 5000.0m;
        public bool AutoPrintNetwork { get; set; } = true;
        public decimal DeliveryBaseCost { get; set; } = 5000.0m;
        public Dictionary<string, string> Printers { get; set; } = new();
        public string ServerUrl { get; set; } = "http://127.0.0.1:8000";
        public string CashierName { get; set; } = "Jasur Rahimov";
        public bool KioskMode { get; set; } = true;
    }
}
