using DilkashPos.Models;
using DilkashPos.Utils;

namespace DilkashPos.ViewModels
{
    public class StopListItemVM : ObservableObject
    {
        private readonly Product _product;
        private bool _isAvailable;

        public StopListItemVM(Product product)
        {
            _product = product;
            _isAvailable = product.IsAvailable;
        }

        public Product Model => _product;
        public int Id => _product.Id;
        public string Name => _product.Name;
        public string CategoryName => _product.CategoryName;
        public string Department => _product.Department;
        public string PriceFormatted => MoneyFormatter.Format(_product.Price);

        public bool IsAvailable
        {
            get => _isAvailable;
            set
            {
                if (SetProperty(ref _isAvailable, value))
                {
                    _product.IsAvailable = value;
                    OnPropertyChanged(nameof(IsStopListed));
                    OnPropertyChanged(nameof(StatusText));
                }
            }
        }

        public bool IsStopListed => !_isAvailable;
        public string StatusText => _isAvailable ? "Mavjud" : "Stop-list";
    }
}
