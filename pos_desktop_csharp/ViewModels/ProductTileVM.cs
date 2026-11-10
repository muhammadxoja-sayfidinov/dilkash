using DilkashPos.Models;
using DilkashPos.Utils;

namespace DilkashPos.ViewModels
{
    public class ProductTileVM : ObservableObject
    {
        private readonly Product _product;
        private int _inCartQty;
        private bool _isAvailable;

        public ProductTileVM(Product product, int inCartQty = 0)
        {
            _product = product;
            _isAvailable = product.IsAvailable;
            _inCartQty = inCartQty;
        }

        public Product Model => _product;
        public int Id => _product.Id;
        public int CategoryId => _product.CategoryId;
        public string Name => _product.Name;
        public string CategoryName => _product.CategoryName;
        public string Department => _product.Department;
        public string? ImageUrl => _product.ImageUrl;
        public bool HasImage => !string.IsNullOrWhiteSpace(_product.ImageUrl);
        public string PriceFormatted => MoneyFormatter.Format(_product.Price);

        public bool IsAvailable
        {
            get => _isAvailable;
            set
            {
                if (SetProperty(ref _isAvailable, value))
                {
                    OnPropertyChanged(nameof(IsStopListed));
                }
            }
        }

        public bool IsStopListed => !_isAvailable;

        public int InCartQty
        {
            get => _inCartQty;
            set
            {
                if (SetProperty(ref _inCartQty, value))
                {
                    OnPropertyChanged(nameof(HasInCartQty));
                    OnPropertyChanged(nameof(InCartBadgeText));
                }
            }
        }

        public bool HasInCartQty => _inCartQty > 0;
        public string InCartBadgeText => _inCartQty.ToString();

        public string DepartmentIconKey => _product.Department.ToLowerInvariant() switch
        {
            "shashlik" => "IconGrill",
            "somsa" => "IconChef",
            "fastfood" => "IconBurger",
            "bar" => "IconCoffee",
            _ => "IconBowl"
        };

        public void SyncAvailabilityFromModel()
        {
            IsAvailable = _product.IsAvailable;
        }
    }
}
