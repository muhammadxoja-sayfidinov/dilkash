using System;
using System.Collections.Generic;
using System.Linq;
using DilkashPos.Models;
using DilkashPos.Utils;

namespace DilkashPos.ViewModels
{
    public enum OrderAgeUrgency
    {
        Normal,
        Warning, // >= 3 min
        Urgent   // >= 7 min
    }

    public class OnlineOrderCardVM : ObservableObject
    {
        public OnlineOrderCardVM(Order order)
        {
            Model = order;
            AgeMinutes = ParseAgeMinutes(order.CreatedAt, order.ElapsedMinutes);
        }

        public Order Model { get; }
        public string OrderNumber => $"#{Model.OrderNumber}";
        public bool IsDelivery => Model.ServiceType == "delivery";
        public string ServiceTypeLabel => IsDelivery ? "Yetkazib berish" : "Olib ketish (Saboy)";
        public string SourceLabel => string.IsNullOrWhiteSpace(Model.Notes) ? "Telegram bot" : "Mobil ilova";
        public string CustomerInfo => string.IsNullOrWhiteSpace(Model.CustomerPhone)
            ? Model.CustomerName
            : $"{Model.CustomerName} · {Model.CustomerPhone}";

        public int AgeMinutes { get; }
        public string AgeText
        {
            get
            {
                if (string.IsNullOrWhiteSpace(Model.CreatedAt)) return $"{AgeMinutes} daq";
                if (DateTimeOffset.TryParse(Model.CreatedAt, out var dt))
                {
                    var local = dt.ToLocalTime();
                    return $"{AgeMinutes} daq · {local:HH:mm}";
                }
                return Model.CreatedAt!;
            }
        }

        public OrderAgeUrgency AgeUrgency => AgeMinutes >= 7
            ? OrderAgeUrgency.Urgent
            : AgeMinutes >= 3
                ? OrderAgeUrgency.Warning
                : OrderAgeUrgency.Normal;

        public List<string> PreviewLines => Model.Items
            .Take(3)
            .Select(i => $"{i.Quantity}× {i.ProductName} — {MoneyFormatter.Format(i.Total)}")
            .ToList();

        public int ExtraItemsCount => Math.Max(0, Model.Items.Count - 3);
        public bool HasExtraItems => ExtraItemsCount > 0;
        public string ExtraItemsText => $"+{ExtraItemsCount} yana";
        public string TotalFormatted => MoneyFormatter.Format(Model.TotalAmount);

        private static int ParseAgeMinutes(string? createdAt, int elapsed)
        {
            if (elapsed > 0) return elapsed;
            if (string.IsNullOrWhiteSpace(createdAt)) return 1;
            var parts = createdAt.Split(' ', StringSplitOptions.RemoveEmptyEntries);
            if (parts.Length > 0 && int.TryParse(parts[0], out int mins)) return mins;
            return 1;
        }
    }
}
