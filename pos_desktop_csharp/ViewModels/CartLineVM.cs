using DilkashPos.Models;
using DilkashPos.Utils;

namespace DilkashPos.ViewModels
{
    public class CartLineVM : ObservableObject
    {
        private readonly OrderItem _item;
        private int _quantity;
        private string _notes;

        public CartLineVM(OrderItem item)
        {
            _item = item;
            _quantity = item.Quantity;
            _notes = item.Notes ?? "";
        }

        public OrderItem Model => _item;
        public int ProductId => _item.ProductId;
        public string ProductName => _item.ProductName;
        public string UnitPriceFormatted => MoneyFormatter.Format(_item.Price);

        public int Quantity
        {
            get => _quantity;
            set
            {
                if (SetProperty(ref _quantity, value))
                {
                    _item.Quantity = value;
                    OnPropertyChanged(nameof(LineTotalFormatted));
                }
            }
        }

        public string Notes
        {
            get => _notes;
            set
            {
                if (SetProperty(ref _notes, value))
                {
                    _item.Notes = value;
                    OnPropertyChanged(nameof(HasNotes));
                }
            }
        }

        public bool HasNotes => !string.IsNullOrWhiteSpace(_notes);
        public string LineTotalFormatted => MoneyFormatter.Format(_item.Total);

        public void SyncFromModel()
        {
            Quantity = _item.Quantity;
            Notes = _item.Notes ?? "";
            OnPropertyChanged(nameof(LineTotalFormatted));
        }
    }
}
