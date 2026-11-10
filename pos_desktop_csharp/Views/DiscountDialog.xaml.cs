using System;
using System.Windows;
using System.Windows.Controls;
using DilkashPos.Utils;

namespace DilkashPos.Views
{
    public partial class DiscountDialog : Window
    {
        private readonly decimal _orderSubtotal;
        private string _buffer = "";

        public decimal DiscountPercent { get; private set; } = 0;

        public DiscountDialog(decimal initialPercent = 0, decimal orderSubtotal = 0)
        {
            InitializeComponent();
            _orderSubtotal = orderSubtotal;
            DiscountPercent = Math.Clamp(initialPercent, 0, 100);
            _buffer = DiscountPercent > 0 ? ((int)DiscountPercent).ToString() : "0";
            UpdateVisuals();
        }

        private void OnPresetClick(object sender, RoutedEventArgs e)
        {
            if (sender is RadioButton rb && rb.Tag is string s && decimal.TryParse(s, out decimal pct))
            {
                DiscountPercent = pct;
                _buffer = ((int)pct).ToString();
                UpdateVisuals();
            }
        }

        private void OnNumpadDigitClick(object sender, RoutedEventArgs e)
        {
            if (sender is Button btn && btn.Tag is string digit)
            {
                string next = _buffer == "0" ? digit : _buffer + digit;
                if (decimal.TryParse(next, out decimal pct))
                {
                    pct = Math.Clamp(pct, 0, 100);
                    DiscountPercent = pct;
                    _buffer = ((int)pct).ToString();
                    UpdateVisuals();
                }
            }
        }

        private void OnNumpadClearClick(object sender, RoutedEventArgs e)
        {
            DiscountPercent = 0;
            _buffer = "0";
            UpdateVisuals();
        }

        private void OnNumpadBackspaceClick(object sender, RoutedEventArgs e)
        {
            if (_buffer.Length <= 1)
            {
                _buffer = "0";
                DiscountPercent = 0;
            }
            else
            {
                _buffer = _buffer[..^1];
                DiscountPercent = decimal.TryParse(_buffer, out decimal pct) ? Math.Clamp(pct, 0, 100) : 0;
            }
            UpdateVisuals();
        }

        private void UpdateVisuals()
        {
            SelectedPercentText.Text = $"{DiscountPercent:0}%";

            if (_orderSubtotal > 0)
            {
                decimal discountAmt = _orderSubtotal * (DiscountPercent / 100m);
                DiscountPreviewAmountText.Text = discountAmt > 0 ? MoneyFormatter.FormatDiscount(discountAmt) : $"0\u00A0so\u02BBm";
            }
            else
            {
                DiscountPreviewAmountText.Text = $"{DiscountPercent:0}% chegirma";
            }

            Seg0.IsChecked = DiscountPercent == 0;
            Seg5.IsChecked = DiscountPercent == 5;
            Seg10.IsChecked = DiscountPercent == 10;
            Seg15.IsChecked = DiscountPercent == 15;
        }

        private void OnApplyClick(object sender, RoutedEventArgs e)
        {
            DialogResult = true;
            Close();
        }

        private void OnCancelClick(object sender, RoutedEventArgs e)
        {
            DialogResult = false;
            Close();
        }
    }
}
