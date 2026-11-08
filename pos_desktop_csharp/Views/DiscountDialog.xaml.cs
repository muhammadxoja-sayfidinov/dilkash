using System;
using System.Windows;
using System.Windows.Controls;

namespace DilkashPos.Views
{
    public partial class DiscountDialog : Window
    {
        public decimal DiscountPercent { get; private set; } = 0;

        public DiscountDialog(decimal initialPercent = 0)
        {
            InitializeComponent();
            DiscountPercent = initialPercent;
            SelectedPercentText.Text = $"{DiscountPercent:0}%";
            CustomPercentBox.Text = DiscountPercent > 0 ? DiscountPercent.ToString("0") : "";
        }

        private void OnPercentClick(object sender, RoutedEventArgs e)
        {
            if (sender is Button btn && btn.Tag is string s && decimal.TryParse(s, out decimal pct))
            {
                DiscountPercent = pct;
                SelectedPercentText.Text = $"{DiscountPercent:0}%";
                CustomPercentBox.Text = pct.ToString("0");
            }
        }

        private void OnCustomPercentChanged(object sender, TextChangedEventArgs e)
        {
            if (decimal.TryParse(CustomPercentBox.Text.Trim(), out decimal pct))
            {
                DiscountPercent = Math.Clamp(pct, 0, 100);
                SelectedPercentText.Text = $"{DiscountPercent:0}%";
            }
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
