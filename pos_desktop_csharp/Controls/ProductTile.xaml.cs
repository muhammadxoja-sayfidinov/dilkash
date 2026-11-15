using System;
using System.ComponentModel;
using System.Windows;
using System.Windows.Controls;
using DilkashPos.Services;
using DilkashPos.ViewModels;

namespace DilkashPos.Controls
{
    public partial class ProductTile : UserControl
    {
        private ProductTileVM? _subscribedVm;

        public ProductTile()
        {
            InitializeComponent();
            DataContextChanged += OnDataContextChanged;
            Unloaded += (_, _) => UnsubscribeVm();
        }

        public event EventHandler<ProductTileVM>? TileClicked;

        private void UnsubscribeVm()
        {
            if (_subscribedVm != null)
            {
                _subscribedVm.PropertyChanged -= OnVmPropertyChanged;
                _subscribedVm = null;
            }
        }

        private void OnDataContextChanged(object sender, DependencyPropertyChangedEventArgs e)
        {
            UnsubscribeVm();
            if (e.NewValue is ProductTileVM vm)
            {
                _subscribedVm = vm;
                vm.PropertyChanged += OnVmPropertyChanged;
                ApplyProductImage(vm);
            }
            else
            {
                ProductImage.Source = null;
                ProductImage.Visibility = Visibility.Collapsed;
            }
        }

        private void OnVmPropertyChanged(object? sender, PropertyChangedEventArgs e)
        {
            if (e.PropertyName is nameof(ProductTileVM.ImageLocalPath) or nameof(ProductTileVM.ImageUrl) or nameof(ProductTileVM.HasImage))
            {
                if (_subscribedVm != null)
                {
                    Dispatcher.InvokeAsync(() => ApplyProductImage(_subscribedVm));
                }
            }
        }

        private void ApplyProductImage(ProductTileVM vm)
        {
            var bmp = ImageCacheService.LoadBitmap(vm.ImageLocalPath, vm.ImageUrl, ImageCacheService.ActiveBaseUrl);
            if (bmp != null)
            {
                ProductImage.Source = bmp;
                ProductImage.Visibility = Visibility.Visible;
            }
            else
            {
                ProductImage.Source = null;
                ProductImage.Visibility = Visibility.Collapsed;
            }
        }

        private void OnImageFailed(object? sender, ExceptionRoutedEventArgs e)
        {
            ProductImage.Visibility = Visibility.Collapsed;
        }

        private void OnTileClick(object sender, RoutedEventArgs e)
        {
            if (DataContext is ProductTileVM vm && vm.IsAvailable)
            {
                TileClicked?.Invoke(this, vm);
            }
        }
    }
}
