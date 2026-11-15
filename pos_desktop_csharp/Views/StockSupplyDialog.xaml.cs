using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using DilkashPos.Models;

namespace DilkashPos.Views
{
    public partial class StockSupplyDialog : Window
    {
        private readonly List<Ingredient> _ingredients;
        private readonly List<Supplier> _suppliers;
        private readonly List<SupplyItemRowControl> _rows = new();

        public int? SelectedSupplierId
        {
            get
            {
                if (SupplierCombo.SelectedItem is Supplier s && s.Id > 0)
                    return s.Id;
                return null;
            }
        }

        public string SelectedPaymentStatus => (PaymentStatusCombo.SelectedItem as ComboBoxItem)?.Tag as string ?? "paid";

        public decimal PaidAmount
        {
            get
            {
                var text = PaidAmountBox.Text.Trim().Replace(" ", "").Replace(",", ".");
                return decimal.TryParse(text, NumberStyles.Any, CultureInfo.InvariantCulture, out var v) ? v : 0m;
            }
        }

        public string Notes => NotesBox.Text.Trim();

        public List<(int IngredientId, string IngredientName, decimal Quantity, decimal UnitPrice)> ResultItems { get; } = new();

        public StockSupplyDialog(List<Ingredient> ingredients, List<Supplier> suppliers)
        {
            InitializeComponent();
            _ingredients = ingredients.OrderBy(i => i.Name).ToList();
            _suppliers = suppliers.OrderBy(s => s.Name).ToList();

            var supChoices = new List<Supplier>
            {
                new Supplier { Id = 0, Name = "Umumiy bozor / Tanlanmagan" }
            };
            supChoices.AddRange(_suppliers);
            SupplierCombo.ItemsSource = supChoices;
            SupplierCombo.SelectedIndex = 0;

            // Add first empty row
            AddRow();
        }

        private void OnCancelClick(object sender, RoutedEventArgs e)
        {
            DialogResult = false;
            Close();
        }

        private void OnAddRowClick(object sender, RoutedEventArgs e)
        {
            AddRow();
        }

        private void AddRow()
        {
            var row = new SupplyItemRowControl(_ingredients, OnRowChanged, OnRowRemoved);
            _rows.Add(row);
            ItemsStackPanel.Children.Add(row);
            RecalculateTotals();
        }

        private void OnRowRemoved(SupplyItemRowControl row)
        {
            if (_rows.Count <= 1) return; // Keep at least one row
            _rows.Remove(row);
            ItemsStackPanel.Children.Remove(row);
            RecalculateTotals();
        }

        private void OnRowChanged()
        {
            RecalculateTotals();
        }

        private void RecalculateTotals()
        {
            decimal totalCost = 0;
            int count = 0;
            foreach (var r in _rows)
            {
                if (r.SelectedIngredientId > 0 && r.Quantity > 0)
                {
                    totalCost += r.TotalPrice;
                    count++;
                }
            }
            TotalItemsCountText.Text = $"{count} ta xomashyo";
            TotalCostText.Text = $"{totalCost:N0} soʻm";

            if (SelectedPaymentStatus == "paid")
            {
                PaidAmountBox.Text = totalCost.ToString("N0", CultureInfo.InvariantCulture).Replace(",", " ");
            }
        }

        private void OnPaymentStatusChanged(object sender, SelectionChangedEventArgs e)
        {
            if (!IsLoaded) return;
            RecalculateTotals();
        }

        private void OnSaveClick(object sender, RoutedEventArgs e)
        {
            ResultItems.Clear();
            foreach (var r in _rows)
            {
                if (r.SelectedIngredientId > 0 && r.Quantity > 0)
                {
                    if (r.UnitPrice < 0)
                    {
                        ShowError("Tan narxi manfiy boʻlishi mumkin emas");
                        return;
                    }
                    ResultItems.Add((r.SelectedIngredientId, r.SelectedIngredientName, r.Quantity, r.UnitPrice));
                }
            }

            if (ResultItems.Count == 0)
            {
                ShowError("Kamida bitta xomashyo va uning miqdorini kiriting");
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

    public class SupplyItemRowControl : Border
    {
        private readonly ComboBox _ingCombo;
        private readonly TextBox _qtyBox;
        private readonly TextBox _priceBox;
        private readonly TextBlock _totalText;
        private readonly Action _onChanged;

        public int SelectedIngredientId => (_ingCombo.SelectedItem as Ingredient)?.Id ?? 0;
        public string SelectedIngredientName => (_ingCombo.SelectedItem as Ingredient)?.Name ?? "";

        public decimal Quantity
        {
            get
            {
                var text = _qtyBox.Text.Trim().Replace(',', '.');
                return decimal.TryParse(text, NumberStyles.Any, CultureInfo.InvariantCulture, out var v) ? v : 0m;
            }
        }

        public decimal UnitPrice
        {
            get
            {
                var text = _priceBox.Text.Trim().Replace(" ", "").Replace(",", ".");
                return decimal.TryParse(text, NumberStyles.Any, CultureInfo.InvariantCulture, out var v) ? v : 0m;
            }
        }

        public decimal TotalPrice => Math.Round(Quantity * UnitPrice, 2);

        public SupplyItemRowControl(List<Ingredient> ingredients, Action onChanged, Action<SupplyItemRowControl> onRemove)
        {
            _onChanged = onChanged;
            Background = Application.Current.FindResource("BrushSurface") as Brush;
            CornerRadius = new CornerRadius(6);
            Padding = new Thickness(8, 6, 8, 6);
            Margin = new Thickness(0, 0, 0, 6);

            var grid = new Grid();
            grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(2.2, GridUnitType.Star) }); // Ingredient
            grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(8) });
            grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1.1, GridUnitType.Star) }); // Qty
            grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(8) });
            grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1.3, GridUnitType.Star) }); // Unit Price
            grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(8) });
            grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1.3, GridUnitType.Star) }); // Total
            grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(32) }); // Remove

            _qtyBox = new TextBox { Text = "1", VerticalContentAlignment = VerticalAlignment.Center };
            _qtyBox.TextChanged += (_, _) => { UpdateSubtotal(); _onChanged(); };

            _priceBox = new TextBox { Text = "0", VerticalContentAlignment = VerticalAlignment.Center };
            _priceBox.TextChanged += (_, _) => { UpdateSubtotal(); _onChanged(); };

            _totalText = new TextBlock
            {
                Text = "0 soʻm",
                VerticalAlignment = VerticalAlignment.Center,
                FontWeight = FontWeights.SemiBold,
                Foreground = Application.Current.FindResource("BrushPrimary") as Brush
            };

            _ingCombo = new ComboBox
            {
                ItemsSource = ingredients,
                DisplayMemberPath = "Name",
                SelectedValuePath = "Id"
            };
            _ingCombo.SelectionChanged += (_, _) =>
            {
                if (_ingCombo.SelectedItem is Ingredient ing)
                {
                    if (UnitPrice == 0 && ing.CostPrice > 0)
                        _priceBox.Text = ing.CostPrice.ToString("0.##", CultureInfo.InvariantCulture);
                }
                UpdateSubtotal();
                _onChanged();
            };

            var removeBtn = new Button
            {
                Content = "✕",
                Width = 28,
                Height = 28,
                Padding = new Thickness(0),
                Foreground = Application.Current.FindResource("BrushError") as Brush,
                Style = Application.Current.FindResource("GhostButton") as Style
            };
            removeBtn.Click += (_, _) => onRemove(this);

            Grid.SetColumn(_ingCombo, 0);
            Grid.SetColumn(_qtyBox, 2);
            Grid.SetColumn(_priceBox, 4);
            Grid.SetColumn(_totalText, 6);
            Grid.SetColumn(removeBtn, 7);

            grid.Children.Add(_ingCombo);
            grid.Children.Add(_qtyBox);
            grid.Children.Add(_priceBox);
            grid.Children.Add(_totalText);
            grid.Children.Add(removeBtn);

            Child = grid;

            if (ingredients.Count > 0)
            {
                _ingCombo.SelectedIndex = 0;
            }
        }

        private void UpdateSubtotal()
        {
            _totalText.Text = $"{TotalPrice:N0} soʻm";
        }
    }
}
