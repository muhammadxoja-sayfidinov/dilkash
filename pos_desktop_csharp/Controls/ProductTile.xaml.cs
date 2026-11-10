using System;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media.Imaging;
using DilkashPos.ViewModels;

namespace DilkashPos.Controls
{
    public partial class ProductTile : UserControl
    {
        public ProductTile()
        {
            InitializeComponent();
            DataContextChanged += OnDataContextChanged;
        }

        public event EventHandler<ProductTileVM>? TileClicked;

        private void OnDataContextChanged(object sender, DependencyPropertyChangedEventArgs e)
        {
            if (e.NewValue is ProductTileVM vm && !string.IsNullOrWhiteSpace(vm.ImageUrl))
            {
                try
                {
                    var bmp = new BitmapImage();
                    bmp.BeginInit();
                    bmp.UriSource = new Uri(vm.ImageUrl, UriKind.RelativeOrAbsolute);
                    bmp.CacheOption = BitmapCacheOption.OnLoad;
                    bmp.EndInit();
                    ProductImage.Source = bmp;
                    ProductImage.Visibility = Visibility.Visible;
                }
                catch
                {
                    ProductImage.Visibility = Visibility.Collapsed;
                }
            }
            else
            {
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
