using System;
using System.Windows;
using System.Windows.Controls;
using DilkashPos.ViewModels;

namespace DilkashPos.Controls
{
    public partial class TableCard : UserControl
    {
        public TableCard()
        {
            InitializeComponent();
        }

        public event EventHandler<TableCardVM>? CardClicked;
        public event EventHandler<TableCardVM>? PreChekClicked;
        public event EventHandler<TableCardVM>? PayClicked;

        private TableCardVM? CurrentVM => DataContext as TableCardVM;

        private void OnCardBodyClick(object sender, RoutedEventArgs e)
        {
            if (CurrentVM != null)
            {
                CardClicked?.Invoke(this, CurrentVM);
            }
        }

        private void OnPreChekClick(object sender, RoutedEventArgs e)
        {
            e.Handled = true;
            if (CurrentVM != null)
            {
                PreChekClicked?.Invoke(this, CurrentVM);
            }
        }

        private void OnPayClick(object sender, RoutedEventArgs e)
        {
            e.Handled = true;
            if (CurrentVM != null)
            {
                PayClicked?.Invoke(this, CurrentVM);
            }
        }
    }
}
