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
        public int? ParentId { get; set; }
        public string Name { get; set; } = "";
        public string Department { get; set; } = "kitchen";
        public string Description { get; set; } = "";
        public string Icon { get; set; } = "🍽";
        public int ProductsCount { get; set; }
        public int SubcategoriesCount { get; set; }
        public bool IsActive { get; set; } = true;
    }

    public class Product : BaseModel
    {
        private bool _isAvailable = true;
        private string? _imageUrl;
        private string? _imageLocalPath;
        private string? _imageHash;

        public int Id { get; set; }
        public string Name { get; set; } = "";
        public decimal Price { get; set; }
        public int CategoryId { get; set; }
        public string CategoryName { get; set; } = "";
        public string Department { get; set; } = "kitchen";
        public string DepartmentName { get; set; } = "";
        public string Description { get; set; } = "";

        public string? ImageUrl
        {
            get => _imageUrl;
            set
            {
                if (_imageUrl != value)
                {
                    _imageUrl = value;
                    OnPropertyChanged();
                }
            }
        }

        public string? ImageLocalPath
        {
            get => _imageLocalPath;
            set
            {
                if (_imageLocalPath != value)
                {
                    _imageLocalPath = value;
                    OnPropertyChanged();
                }
            }
        }

        public string? ImageHash
        {
            get => _imageHash;
            set
            {
                if (_imageHash != value)
                {
                    _imageHash = value;
                    OnPropertyChanged();
                }
            }
        }

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
        private WaiterCall? _activeCall;
        private string _status = "empty"; // 'empty', 'occupied', 'bill_printed', 'reserved'

        public int Id { get; set; }
        public int Number { get; set; }
        public string Name { get; set; } = "";
        public int? HallId { get; set; }
        public string Zone { get; set; } = "Zal"; // Zal nomi
        public int Capacity { get; set; } = 4;
        public bool IsActive { get; set; } = true;
        public string? AssignedWaiter { get; set; }
        public string? OpenedAt { get; set; }
        public string? OrderStatus { get; set; }

        public WaiterCall? ActiveCall
        {
            get => _activeCall;
            set
            {
                _activeCall = value;
                OnPropertyChanged();
                OnPropertyChanged(nameof(HasActiveCall));
            }
        }

        public bool HasActiveCall => ActiveCall != null && !ActiveCall.IsResolved;

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
        private List<OrderItem> _items = new();

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
            set
            {
                if (_discountPercent == value) return;
                _discountPercent = value;
                OnPropertyChanged();
                if (_items.Count > 0) RecalculateTotals();
            }
        }

        public decimal DiscountAmount
        {
            get => _discountAmount;
            set
            {
                if (_discountAmount == value) return;
                _discountAmount = value;
                OnPropertyChanged();
                if (_items.Count > 0) RecalculateTotals();
            }
        }

        public decimal TotalAmount { get; set; }
        public string? CreatedAt { get; set; }
        public int ElapsedMinutes { get; set; }

        public List<OrderItem> Items
        {
            get => _items;
            set
            {
                _items = value ?? new();
                if (ProductsTotal == 0 && _items.Count > 0) RecalculateTotals();
            }
        }

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

    public class WaiterCall
    {
        public int Id { get; set; }
        public string TableNumber { get; set; } = "";
        public string Reason { get; set; } = "";
        public string CreatedAt { get; set; } = "";
        public bool IsResolved { get; set; }
    }

    public class StaffAccount
    {
        public int Id { get; set; }
        public string Role { get; set; } = "waiter"; // 'waiter' | 'courier'
        public string Name { get; set; } = "";
        public string Phone { get; set; } = "";
        public string PinHash { get; set; } = "";
        public string StaffCode { get; set; } = "";
        public string Token { get; set; } = "";
        public string VehicleInfo { get; set; } = "";
        public bool IsActive { get; set; } = true;
        public long? TelegramId { get; set; }

        public string RoleLabel => Role == "courier" ? "Kuryer" : "Ofitsiant";
        public string StatusLabel => IsActive ? "Faol" : "Nofaol";
    }

    public class PosSettings
    {
        public string ServiceFeeType { get; set; } = "percent"; // 'percent', 'per_person', 'none'
        public decimal ServiceFeePercent { get; set; } = 10.0m;
        public decimal ServiceFeePerPerson { get; set; } = 5000.0m;
        public bool AutoPrintNetwork { get; set; } = true;
        public string ServiceStartTime { get; set; } = "10:00";
        public string ServiceEndTime { get; set; } = "22:00";
        public decimal DeliveryBaseCost { get; set; } = 5000.0m;
        public decimal DeliveryCostPerExtraKmBlock { get; set; } = 6000.0m;
        public double DeliveryMaxRadiusKm { get; set; } = 10.0;
        public string BroadcastMessageText { get; set; } = "";
        public string ClickServiceId { get; set; } = "";
        public string ClickMerchantId { get; set; } = "";
        public string ClickSecretKey { get; set; } = "";
        public string PaymeMerchantId { get; set; } = "";
        public string PaymeSecretKey { get; set; } = "";
        public bool HasClickSecret { get; set; }
        public bool HasPaymeSecret { get; set; }
        public Dictionary<string, string> Printers { get; set; } = new();
        public string ServerUrl { get; set; } = "https://dilkash-django-production.up.railway.app";
        public string CashierName { get; set; } = "Jasur Rahimov";
        public bool KioskMode { get; set; } = true;
    }

    public class Hall : BaseModel
    {
        public int Id { get; set; }
        public string Name { get; set; } = "";
        public string Description { get; set; } = "";
        public int SortOrder { get; set; } = 1;
        public bool IsActive { get; set; } = true;
        public int TablesCount { get; set; }
    }

    public class PosPrinter : BaseModel
    {
        public int Id { get; set; }
        public string Name { get; set; } = "";
        public string Department { get; set; } = "kitchen";
        public string IpAddress { get; set; } = "";
        public int Port { get; set; } = 9100;
        public int PaperWidth { get; set; } = 80;
        public string Subtitle { get; set; } = "";
        public bool IsActive { get; set; } = true;
        public int SortOrder { get; set; } = 1;

        public string EffectiveAddress
        {
            get
            {
                var ip = (IpAddress ?? "").Trim();
                if (string.IsNullOrEmpty(ip)) return "";
                return ip.Contains(':') ? ip : $"{ip}:{(Port > 0 ? Port : 9100)}";
            }
        }

        public bool IsOnline => IsActive && !string.IsNullOrWhiteSpace(IpAddress);
    }

    public class CashierProfile : BaseModel
    {
        public int Id { get; set; }
        public string Name { get; set; } = "Jasur Rahimov";
        public string Phone { get; set; } = "+998901112233";
        public string RoleTitle { get; set; } = "Bosh kassir";
        public string PinHash { get; set; } = "";
        public bool HasPin { get; set; } = true;
        public string AvatarColor { get; set; } = "#10B981";
        public bool RequirePinOnUnlock { get; set; }
        public bool NotificationSound { get; set; } = true;
        public bool IsActive { get; set; } = true;
        public bool IsPrimary { get; set; } = true;

        public string Initials
        {
            get
            {
                var parts = (Name ?? "").Split(' ', StringSplitOptions.RemoveEmptyEntries);
                if (parts.Length == 0) return "K";
                if (parts.Length == 1) return parts[0][..Math.Min(2, parts[0].Length)].ToUpperInvariant();
                return $"{char.ToUpperInvariant(parts[0][0])}{char.ToUpperInvariant(parts[1][0])}";
            }
        }
    }

    public class Ingredient : BaseModel
    {
        private decimal _currentStock;
        private decimal _costPrice;
        private bool _isLowStock;
        private decimal _totalValuation;

        public int Id { get; set; }
        public string Name { get; set; } = "";
        public string Category { get; set; } = "groceries";
        public string CategoryDisplay { get; set; } = "";
        public string Unit { get; set; } = "kg";
        public string UnitDisplay { get; set; } = "";
        public decimal MinStockAlert { get; set; } = 5m;
        public string Description { get; set; } = "";
        public bool IsActive { get; set; } = true;

        public decimal CurrentStock
        {
            get => _currentStock;
            set
            {
                if (_currentStock != value)
                {
                    _currentStock = value;
                    OnPropertyChanged();
                    OnPropertyChanged(nameof(FormattedStock));
                    IsLowStock = _currentStock <= MinStockAlert;
                    TotalValuation = Math.Round(_currentStock * CostPrice, 2);
                }
            }
        }

        public decimal CostPrice
        {
            get => _costPrice;
            set
            {
                if (_costPrice != value)
                {
                    _costPrice = value;
                    OnPropertyChanged();
                    OnPropertyChanged(nameof(FormattedCost));
                    TotalValuation = Math.Round(CurrentStock * _costPrice, 2);
                }
            }
        }

        public bool IsLowStock
        {
            get => _isLowStock;
            set
            {
                if (_isLowStock != value)
                {
                    _isLowStock = value;
                    OnPropertyChanged();
                    OnPropertyChanged(nameof(StockStatusBadge));
                    OnPropertyChanged(nameof(StockStatusColor));
                }
            }
        }

        public decimal TotalValuation
        {
            get => _totalValuation;
            set
            {
                if (_totalValuation != value)
                {
                    _totalValuation = value;
                    OnPropertyChanged();
                    OnPropertyChanged(nameof(FormattedValuation));
                }
            }
        }

        public string FormattedStock => $"{CurrentStock:0.###} {Unit}";
        public string FormattedCost => $"{CostPrice:N0} soʻm";
        public string FormattedValuation => $"{TotalValuation:N0} soʻm";
        public string StockStatusBadge => IsLowStock ? "KAM QOLGAN" : "YETARLI";
        public string StockStatusColor => IsLowStock ? "#EF4444" : "#10B981";
    }

    public class Supplier : BaseModel
    {
        private decimal _balance;

        public int Id { get; set; }
        public string Name { get; set; } = "";
        public string Phone { get; set; } = "";
        public string ContactPerson { get; set; } = "";
        public string Address { get; set; } = "";
        public string Notes { get; set; } = "";
        public bool IsActive { get; set; } = true;

        public decimal Balance
        {
            get => _balance;
            set
            {
                if (_balance != value)
                {
                    _balance = value;
                    OnPropertyChanged();
                    OnPropertyChanged(nameof(FormattedBalance));
                }
            }
        }

        public string FormattedBalance => Balance > 0 ? $"{Balance:N0} soʻm (qarz)" : "0 soʻm";
    }

    public class RecipeItem : BaseModel
    {
        public int Id { get; set; }
        public int ProductId { get; set; }
        public string ProductName { get; set; } = "";
        public int IngredientId { get; set; }
        public string IngredientName { get; set; } = "";
        public string IngredientUnit { get; set; } = "kg";
        public decimal Quantity { get; set; }
        public string Unit { get; set; } = "kg";
        public decimal Cost { get; set; }
        public string Notes { get; set; } = "";

        public string FormattedQuantity => $"{Quantity:0.###} {Unit}";
        public string FormattedCost => $"{Cost:N0} soʻm";
    }

    public class InventoryKpiSummary : BaseModel
    {
        public int TotalIngredients { get; set; }
        public int LowStockCount { get; set; }
        public decimal TotalValuation { get; set; }
        public decimal TodaySuppliesTotal { get; set; }
        public decimal TodayWriteoffsTotal { get; set; }
        public int SuppliersCount { get; set; }

        public string FormattedValuation => $"{TotalValuation:N0} soʻm";
        public string FormattedTodaySupplies => $"{TodaySuppliesTotal:N0} soʻm";
    }

    public class StockSupply : BaseModel
    {
        public int Id { get; set; }
        public string DocNumber { get; set; } = "";
        public int? SupplierId { get; set; }
        public string SupplierName { get; set; } = "";
        public DateTime Date { get; set; } = DateTime.Now;
        public decimal TotalCost { get; set; }
        public string PaymentStatus { get; set; } = "paid";
        public string PaymentStatusDisplay { get; set; } = "Toʻlangan";
        public decimal PaidAmount { get; set; }
        public string Notes { get; set; } = "";
        public string CreatedBy { get; set; } = "Kassir";
        public int ItemsCount { get; set; }
        public List<StockSupplyItem> Items { get; set; } = new();

        public string FormattedTotal => $"{TotalCost:N0} soʻm";
        public string FormattedDate => Date.ToString("dd.MM.yyyy HH:mm");
    }

    public class StockSupplyItem : BaseModel
    {
        public int Id { get; set; }
        public int IngredientId { get; set; }
        public string IngredientName { get; set; } = "";
        public string IngredientUnit { get; set; } = "kg";
        public decimal Quantity { get; set; }
        public decimal UnitPrice { get; set; }
        public decimal TotalPrice { get; set; }

        public string FormattedQuantity => $"{Quantity:0.###} {IngredientUnit}";
        public string FormattedPrice => $"{UnitPrice:N0} soʻm";
        public string FormattedTotal => $"{TotalPrice:N0} soʻm";
    }

    public class StockWriteOff : BaseModel
    {
        public int Id { get; set; }
        public string DocNumber { get; set; } = "";
        public DateTime Date { get; set; } = DateTime.Now;
        public string Reason { get; set; } = "spoilage";
        public string ReasonDisplay { get; set; } = "Yaroqsiz / Aynigan";
        public decimal TotalCost { get; set; }
        public string Notes { get; set; } = "";
        public string CreatedBy { get; set; } = "Kassir";
        public int ItemsCount { get; set; }
        public List<StockWriteOffItem> Items { get; set; } = new();

        public string FormattedTotal => $"{TotalCost:N0} soʻm";
        public string FormattedDate => Date.ToString("dd.MM.yyyy HH:mm");
    }

    public class StockWriteOffItem : BaseModel
    {
        public int Id { get; set; }
        public int IngredientId { get; set; }
        public string IngredientName { get; set; } = "";
        public string IngredientUnit { get; set; } = "kg";
        public decimal Quantity { get; set; }
        public decimal UnitCost { get; set; }
        public decimal TotalCost { get; set; }

        public string FormattedQuantity => $"{Quantity:0.###} {IngredientUnit}";
        public string FormattedCost => $"{UnitCost:N0} soʻm";
        public string FormattedTotal => $"{TotalCost:N0} soʻm";
    }

    public class StockMovementLogItem : BaseModel
    {
        public int Id { get; set; }
        public DateTime CreatedAt { get; set; }
        public string CreatedAtDisplay { get; set; } = "";
        public int IngredientId { get; set; }
        public string IngredientName { get; set; } = "";
        public string IngredientUnit { get; set; } = "kg";
        public string MovementType { get; set; } = "supply";
        public string MovementTypeDisplay { get; set; } = "Kirim";
        public decimal QuantityDelta { get; set; }
        public decimal StockBefore { get; set; }
        public decimal StockAfter { get; set; }
        public decimal UnitCost { get; set; }
        public int? RelatedOrderId { get; set; }
        public string Notes { get; set; } = "";

        public string FormattedDelta => $"{(QuantityDelta > 0 ? "+" : "")}{QuantityDelta:0.###} {IngredientUnit}";
        public string DeltaColor => QuantityDelta > 0 ? "#10B981" : "#EF4444";
    }

    public class WaiterFeedbackItem : BaseModel
    {
        public int Id { get; set; }
        public int WaiterId { get; set; }
        public string WaiterName { get; set; } = "";
        public string TableNumber { get; set; } = "";
        public int Rating { get; set; } = 5;
        public string StarsDisplay { get; set; } = "★★★★★";
        public string Comment { get; set; } = "";
        public string CreatedAt { get; set; } = "";
    }

    public class DishFeedbackItem : BaseModel
    {
        public int Id { get; set; }
        public int ProductId { get; set; }
        public string ProductName { get; set; } = "";
        public string TableNumber { get; set; } = "";
        public int Rating { get; set; } = 5;
        public string StarsDisplay { get; set; } = "★★★★★";
        public string Comment { get; set; } = "";
        public string CreatedAt { get; set; } = "";
    }

    public class WaiterRatingSummary : BaseModel
    {
        public int WaiterId { get; set; }
        public string Name { get; set; } = "";
        public string Phone { get; set; } = "";
        public double AvgRating { get; set; } = 5.0;
        public int ReviewsCount { get; set; }
        public string StarsDisplay { get; set; } = "★★★★★";
    }

    public class DishRatingSummary : BaseModel
    {
        public int ProductId { get; set; }
        public string Name { get; set; } = "";
        public string Category { get; set; } = "";
        public double AvgRating { get; set; } = 5.0;
        public int ReviewsCount { get; set; }
        public string StarsDisplay { get; set; } = "★★★★★";
    }
}
