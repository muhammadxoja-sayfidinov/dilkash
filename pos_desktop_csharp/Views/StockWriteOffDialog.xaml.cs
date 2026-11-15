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
    public partial class StockWriteOffDialog : Window
    {
        private readonly List<Ingredient> _ingredients;
        private readonly List<WriteOffItemRowControl> _rows = new();

        public string SelectedReason => (ReasonCombo.SelectedItem as ComboBoxItem)?.Tag as string ?? "spoilage";
        public string Notes => NotesBox.Text.Trim();
        public List<(int IngredientId, string IngredientName, decimal Quantity)> ResultItems { get; } = new();

        public StockWriteOffDialog(List<Ingredient> ingredients)
        {
            InitializeComponent();
            _ingredients = ingredients.OrderBy(i => i.Name).ToList();

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
            var row = new WriteOffItemRowControl(_ingredients, OnRowChanged, OnRowRemoved);
            _rows.Add(row);
            ItemsStackPanel.Children.Add(row);
            RecalculateTotals();
        }

        private void OnRowRemoved(WriteOffItemRowControl row)
        {
            if (_rows.Count <= 1) return;
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
                    totalCost += r.TotalCost;
                    count++;
                }
            }
            TotalItemsCountText.Text = $"{count} ta xomashyo";
            TotalCostText.Text = $"{totalCost:N0} soʻm";
        }

        private void OnSaveClick(object sender, RoutedEventArgs e)
        {
            ResultItems.Clear();
            foreach (var r in _rows)
            {
                if (r.SelectedIngredientId > 0 && r.Quantity > 0)
                {
                    ResultItems.Add((r.SelectedIngredientId, r.SelectedIngredientName, r.Quantity));
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

    public class WriteOffItemRowControl : Border
    {
        private readonly ComboBox _ingCombo;
        private readonly TextBox _qtyBox;
        private readonly TextBlock _unitText;
        private readonly TextBlock _costText;
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

        public decimal UnitCost => (_ingCombo.SelectedItem as Ingredient)?.CostPrice ?? 0m;
        public decimal TotalCost => Math.Round(Quantity * UnitCost, 2);

        public WriteOffItemRowControl(List<Ingredient> ingredients, Action onChanged, Action<WriteOffItemRowControl> onRemove)
        {
            _onChanged = onChanged;
            Background = Application.Current.FindResource("BrushSurface") as Brush;
            CornerRadius = new CornerRadius(6);
            Padding = new Thickness(8, 6, 8, 6);
            Margin = new Thickness(0, 0, 0, 6);

            var grid = new Grid();
            grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(3, GridUnitType.Star) }); // Ingredient
            grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(8) });
            grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1.3, GridUnitType.Star) }); // Qty
            grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(8) });
            grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(0.8, GridUnitType.Star) }); // Unit
            grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(8) });
            grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1.6, GridUnitType.Star) }); // Total Cost
            grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(32) }); // Remove

            _unitText = new TextBlock
            {
                Text = "kg",
                VerticalAlignment = VerticalAlignment.Center,
                Foreground = Application.Current.FindResource("BrushTextSecondary") as Brush
            };

            _qtyBox = new TextBox { Text = "1", VerticalContentAlignment = VerticalAlignment.Center };
            _qtyBox.TextChanged += (_, _) => { UpdateSubtotal(); _onChanged(); };

            _costText = new TextBlock
            {
                Text = "0 soʻm",
                VerticalAlignment = VerticalAlignment.Center,
                FontWeight = FontWeights.SemiBold,
                Foreground = Application.Current.FindResource("BrushError") as Brush
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
                    _unitText.Text = ing.Unit;
                }
                UpdateSubtotal();
                _onChanged();
            };

            _qtyBox = new TextBox { Text = "1", VerticalContentAlignment = VerticalAlignment.Center };
            _qtyBox.TextChanged += (_, _) => { UpdateSubtotal(); _onChanged(); };

            _unitText = new TextBlock
            {
                Text = "kg",
                VerticalAlignment = VerticalAlignment.Center,
                Foreground = Application.Current.FindResource("BrushTextSecondary") as Brush
            };

            _costText = new TextBlock
            {
                Text = "0 soʻm",
                VerticalAlignment = VerticalAlignment.Center,
                FontWeight = FontWeights.SemiBold,
                Foreground = Application.Current.FindResource("BrushError") as Brush
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
            Grid.SetColumn(_unitText, 4);
            Grid.SetColumn(_costText, 6);
            Grid.SetColumn(removeBtn, 7);

            grid.Children.Add(_ingCombo);
            grid.Children.Add(_qtyBox);
            grid.Children.Add(_unitText);
            grid.Children.Add(_costText);
            grid.Children.Add(removeBtn);

            Child = grid;

            if (ingredients.Count > 0)
            {
                _ingCombo.SelectedIndex = 0;
                _unitText.Text = ingredients[0].Unit;
            }
        }

        private void UpdateSubtotal()
        {
            _costText.Text = $"{TotalCost:N0} soʻm";
        }
    }
}
