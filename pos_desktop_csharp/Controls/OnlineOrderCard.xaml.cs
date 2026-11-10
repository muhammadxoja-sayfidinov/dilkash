using System;
using System.Windows;
using System.Windows.Controls;
using DilkashPos.ViewModels;

namespace DilkashPos.Controls
{
    public partial class OnlineOrderCard : UserControl
    {
        public OnlineOrderCard()
        {
            InitializeComponent();
        }

        public event EventHandler<OnlineOrderCardVM>? AcceptClicked;

        private void OnAcceptClick(object sender, RoutedEventArgs e)
        {
            if (DataContext is OnlineOrderCardVM vm)
            {
                AcceptClicked?.Invoke(this, vm);
            }
        }
    }
}
