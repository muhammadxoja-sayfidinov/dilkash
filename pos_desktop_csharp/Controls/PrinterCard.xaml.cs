using System;
using System.Windows;
using System.Windows.Controls;
using DilkashPos.ViewModels;

namespace DilkashPos.Controls
{
    public partial class PrinterCard : UserControl
    {
        public PrinterCard()
        {
            InitializeComponent();
        }

        public event EventHandler<PrinterCardVM>? TestPrintClicked;
        public event EventHandler? IpChanged;

        private void OnTestPrintClick(object sender, RoutedEventArgs e)
        {
            if (DataContext is PrinterCardVM vm)
            {
                TestPrintClicked?.Invoke(this, vm);
            }
        }

        private void OnIpTextChanged(object sender, TextChangedEventArgs e)
        {
            if (!IsLoaded) return;
            if (sender is TextBox tb && !tb.IsKeyboardFocusWithin) return;
            IpChanged?.Invoke(this, EventArgs.Empty);
        }
    }
}
