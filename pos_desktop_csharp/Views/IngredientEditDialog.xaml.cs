using System;
using System.Globalization;
using System.Windows;
using System.Windows.Controls;
using DilkashPos.Models;

namespace DilkashPos.Views
{
    public partial class IngredientEditDialog : Window
    {
        public int IngredientId { get; }
        public string IngredientName => NameBox.Text.Trim();
        public string SelectedCategory => (CategoryCombo.SelectedItem as ComboBoxItem)?.Tag as string ?? "groceries";
        public string SelectedUnit => (UnitCombo.SelectedItem as ComboBoxItem)?.Tag as string ?? "kg";
        public decimal CurrentStock
        {
            get
            {
                var text = CurrentStockBox.Text.Trim().Replace(',', '.');
                return decimal.TryParse(text, NumberStyles.Any, CultureInfo.InvariantCulture, out var v) ? v : 0m;
            }
        }
        public decimal MinStockAlert
        {
            get
            {
                var text = MinAlertBox.Text.Trim().Replace(',', '.');
                return decimal.TryParse(text, NumberStyles.Any, CultureInfo.InvariantCulture, out var v) ? v : 5m;
            }
        }
        public decimal CostPrice
        {
            get
            {
                var text = CostPriceBox.Text.Trim().Replace(" ", "").Replace(",", ".");
                return decimal.TryParse(text, NumberStyles.Any, CultureInfo.InvariantCulture, out var v) ? v : 0m;
            }
        }
        public string IngredientDescription => DescriptionBox.Text.Trim();
        public bool IsIngredientActive => IsActiveCheck.IsChecked == true;

        public IngredientEditDialog(Ingredient? existing = null)
        {
            InitializeComponent();
            IngredientId = existing?.Id ?? 0;

            if (existing != null)
            {
                Chrome.Title = "Xomashyoni tahrirlash";
                Chrome.Subtitle = existing.Name;
                NameBox.Text = existing.Name;
                CurrentStockBox.Text = existing.CurrentStock.ToString("0.###", CultureInfo.InvariantCulture);
                MinAlertBox.Text = existing.MinStockAlert.ToString("0.###", CultureInfo.InvariantCulture);
                CostPriceBox.Text = existing.CostPrice.ToString("0.##", CultureInfo.InvariantCulture);
                DescriptionBox.Text = existing.Description;
                IsActiveCheck.IsChecked = existing.IsActive;

                foreach (var item in CategoryCombo.Items)
                {
                    if (item is ComboBoxItem cbi && string.Equals(cbi.Tag as string, existing.Category, StringComparison.OrdinalIgnoreCase))
                    {
                        CategoryCombo.SelectedItem = cbi;
                        break;
                    }
                }
                foreach (var item in UnitCombo.Items)
                {
                    if (item is ComboBoxItem cbi && string.Equals(cbi.Tag as string, existing.Unit, StringComparison.OrdinalIgnoreCase))
                    {
                        UnitCombo.SelectedItem = cbi;
                        break;
                    }
                }
            }

            Loaded += (_, _) => NameBox.Focus();
        }

        private void OnCancelClick(object sender, RoutedEventArgs e)
        {
            DialogResult = false;
            Close();
        }

        private void OnSaveClick(object sender, RoutedEventArgs e)
        {
            if (string.IsNullOrWhiteSpace(IngredientName))
            {
                ShowError("Xomashyo nomini kiriting");
                NameBox.Focus();
                return;
            }
            if (CostPrice < 0)
            {
                ShowError("Tan narxi manfiy boʻlishi mumkin emas");
                CostPriceBox.Focus();
                return;
            }
            if (MinStockAlert < 0)
            {
                ShowError("Ogohlantirish chegarasi 0 yoki undan katta boʻlishi kerak");
                MinAlertBox.Focus();
                return;
            }

            DialogResult = true;
            Close();
        }

        private void ShowError(string msg)
        {
            ErrorBanner.Text = msg;
            ErrorBanner.Visibility = Visibility.Visible;
        }
    }
}
