using System;
using System.Windows;
using System.Windows.Controls;
using DilkashPos.ViewModels;

namespace DilkashPos.Controls
{
    public partial class CategoryTile : UserControl
    {
        public CategoryTile()
        {
            InitializeComponent();
        }

        public event EventHandler<CategoryTileVM>? CategoryClicked;

        private void OnTileClick(object sender, RoutedEventArgs e)
        {
            if (DataContext is CategoryTileVM vm)
            {
                CategoryClicked?.Invoke(this, vm);
            }
        }
    }
}
