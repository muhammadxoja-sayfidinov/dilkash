using System;
using System.Linq;
using DilkashPos.Models;
using DilkashPos.Utils;

namespace DilkashPos.ViewModels
{
    public enum TableVisualState
    {
        Free,
        Occupied,
        BillPrinted,
        Reserved
    }

    public enum TimerUrgency
    {
        Normal,
        Warning,
        Overdue
    }

    public class TableCardVM : ObservableObject
    {
        private readonly RestaurantTable _table;
        private readonly int _attentionThresholdMinutes;

        public TableCardVM(RestaurantTable table, int attentionThresholdMinutes = 60)
        {
            _table = table;
            _attentionThresholdMinutes = attentionThresholdMinutes;
        }

        public RestaurantTable Model => _table;
        public int Id => _table.Id;
        public int Number => _table.Number;
        public string Name => _table.Name;
        public string Zone => _table.Zone;
        public int Capacity => _table.Capacity;

        public TableVisualState VisualState
        {
            get
            {
                if (_table.Status == "bill_printed") return TableVisualState.BillPrinted;
                if (_table.Status == "reserved") return TableVisualState.Reserved;
                if (_table.IsOccupied || _table.Status == "occupied") return TableVisualState.Occupied;
                return TableVisualState.Free;
            }
        }

        public bool IsFree => VisualState == TableVisualState.Free;
        public bool IsOccupiedOrBill => VisualState == TableVisualState.Occupied || VisualState == TableVisualState.BillPrinted;
        public bool IsReserved => VisualState == TableVisualState.Reserved;
        public bool IsBillPrinted => VisualState == TableVisualState.BillPrinted;

        public string StatusLabel => VisualState switch
        {
            TableVisualState.Occupied => "Band",
            TableVisualState.BillPrinted => "Hisob berildi",
            TableVisualState.Reserved => "Bron",
            _ => "Boʻsh"
        };

        public string CapacityText => $"{_table.Capacity} oʻrin";
        public string GuestsText => $"{Math.Max(1, _table.GuestsCount)} mehmon";
        public string WaiterText => string.IsNullOrWhiteSpace(_table.AssignedWaiter)
            ? (_table.ActiveOrder?.WaiterName ?? "Kassir")
            : _table.AssignedWaiter!;

        public int ElapsedMinutes => _table.ActiveOrder?.ElapsedMinutes ?? 0;

        public string ElapsedText
        {
            get
            {
                int mins = ElapsedMinutes;
                if (mins < 60) return $"{mins} daq";
                return $"{mins / 60} s {mins % 60:D2} d";
            }
        }

        public TimerUrgency Urgency
        {
            get
            {
                int mins = ElapsedMinutes;
                if (mins > _attentionThresholdMinutes) return TimerUrgency.Overdue;
                if (mins >= Math.Max(30, _attentionThresholdMinutes - 20)) return TimerUrgency.Warning;
                return TimerUrgency.Normal;
            }
        }

        public int ItemsCount => _table.ActiveOrder?.Items.Sum(i => i.Quantity) ?? 0;
        public string ItemsCountText => $"{ItemsCount} taom";
        public decimal TotalAmount => _table.ActiveOrder?.TotalAmount ?? 0;
        public string TotalFormatted => MoneyFormatter.Format(TotalAmount);
        public bool HasActiveCall => _table.HasActiveCall;
        public string ActiveCallText => _table.ActiveCall?.Reason ?? "Chaqiruv";

        public void Refresh()
        {
            OnPropertyChanged(string.Empty);
        }
    }
}
