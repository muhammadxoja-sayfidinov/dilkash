using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using DilkashPos.Data;
using DilkashPos.Models;

namespace DilkashPos.Views
{
    public partial class RecipeEditDialog : Window
    {
        private readonly Product _product;
        private readonly List<Ingredient> _ingredients;
        private readonly List<RecipeItemRowControl> _rows = new();

        public List<RecipeItem> ResultRecipes { get; } = new();

        public RecipeEditDialog(Product product, List<RecipeItem> currentRecipes, List<Ingredient> ingredients)
        {
            InitializeComponent();
            _product = product;
            _ingredients = ingredients.OrderBy(i => i.Name).ToList();

            DishNameText.Text = product.Name;
            DishCategoryText.Text = product.CategoryName;
            DishPriceText.Text = product.FormattedPrice;

            if (currentRecipes.Count > 0)
            {
                foreach (var rec in currentRecipes)
                {
                    AddRow(rec.IngredientId, rec.Quantity, rec.Unit, rec.Notes);
                }
            }
            else
            {
                AddRow();
            }
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

        private void AddRow(int preselectIngId = 0, decimal initialQty = 0, string initialUnit = "kg", string initialNotes = "")
        {
            var row = new RecipeItemRowControl(_ingredients, preselectIngId, initialQty, initialUnit, initialNotes, OnRowChanged, OnRowRemoved);
            _rows.Add(row);
            ItemsStackPanel.Children.Add(row);
            RecalculateTotals();
        }

        private void OnRowRemoved(RecipeItemRowControl row)
        {
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
                    totalCost += r.CalculatedCost;
                    count++;
                }
            }

            decimal price = _product.Price;
            decimal profit = price - totalCost;
            decimal marginPercent = price > 0 ? (profit / price) * 100m : 0m;

            RecipeItemsCountText.Text = $"{count} ta xomashyo";
            TotalCostText.Text = $"{totalCost:N0} soʻm";
            ProfitMarginText.Text = $"{profit:N0} soʻm";
            ProfitMarginText.Foreground = profit >= 0
                ? Application.Current.FindResource("BrushPrimaryBright") as Brush
                : Application.Current.FindResource("BrushError") as Brush;

            MarginPercentText.Text = $"{marginPercent:0.#}%";
            MarginPercentText.Foreground = marginPercent >= 20
                ? Application.Current.FindResource("BrushPrimaryBright") as Brush
                : Application.Current.FindResource("BrushAmberBright") as Brush;
        }

        private void OnSaveClick(object sender, RoutedEventArgs e)
        {
            ResultRecipes.Clear();
            var seenIngredients = new HashSet<int>();

            foreach (var r in _rows)
            {
                if (r.SelectedIngredientId > 0 && r.Quantity > 0)
                {
                    if (seenIngredients.Contains(r.SelectedIngredientId))
                    {
                        ShowError($"'{r.SelectedIngredientName}' xomashyosi takrorlandi. Birlashtirib bitta qatorda kiriting");
                        return;
                    }
                    seenIngredients.Add(r.SelectedIngredientId);

                    ResultRecipes.Add(new RecipeItem
                    {
                        ProductId = _product.Id,
                        ProductName = _product.Name,
                        IngredientId = r.SelectedIngredientId,
                        IngredientName = r.SelectedIngredientName,
                        IngredientUnit = r.IngredientBaseUnit,
                        Quantity = r.Quantity,
                        Unit = r.SelectedUnit,
                        Cost = r.CalculatedCost,
                        Notes = r.Notes
                    });
                }
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

    public class RecipeItemRowControl : Border
    {
        private readonly ComboBox _ingCombo;
        private readonly TextBox _qtyBox;
        private readonly ComboBox _unitCombo;
        private readonly TextBlock _costText;
        private readonly TextBox _notesBox;
        private readonly Action _onChanged;

        public int SelectedIngredientId => (_ingCombo.SelectedItem as Ingredient)?.Id ?? 0;
        public string SelectedIngredientName => (_ingCombo.SelectedItem as Ingredient)?.Name ?? "";
        public string IngredientBaseUnit => (_ingCombo.SelectedItem as Ingredient)?.Unit ?? "kg";
        public decimal IngredientCostPrice => (_ingCombo.SelectedItem as Ingredient)?.CostPrice ?? 0m;

        public decimal Quantity
        {
            get
            {
                var text = _qtyBox.Text.Trim().Replace(',', '.');
                return decimal.TryParse(text, NumberStyles.Any, CultureInfo.InvariantCulture, out var v) ? v : 0m;
            }
        }

        public string SelectedUnit => (_unitCombo.SelectedItem as ComboBoxItem)?.Tag as string ?? "kg";
        public string Notes => _notesBox.Text.Trim();

        public decimal CalculatedCost
        {
            get
            {
                decimal convertedQty = LocalDatabase.ConvertUnitQuantity(Quantity, SelectedUnit, IngredientBaseUnit);
                return Math.Round(convertedQty * IngredientCostPrice, 2);
            }
        }

        public RecipeItemRowControl(List<Ingredient> ingredients, int preselectId, decimal initQty, string initUnit, string initNotes, Action onChanged, Action<RecipeItemRowControl> onRemove)
        {
            _onChanged = onChanged;
            Background = Application.Current.FindResource("BrushSurface") as Brush;
            CornerRadius = new CornerRadius(6);
            Padding = new Thickness(8, 6, 8, 6);
            Margin = new Thickness(0, 0, 0, 6);

            var grid = new Grid();
            grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(2.4, GridUnitType.Star) }); // Ingredient
            grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(8) });
            grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1.1, GridUnitType.Star) }); // Qty
            grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(8) });
            grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1.1, GridUnitType.Star) }); // Unit
            grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(8) });
            grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1.3, GridUnitType.Star) }); // Cost
            grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(8) });
            grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1.4, GridUnitType.Star) }); // Notes
            grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(32) }); // Remove

            _ingCombo = new ComboBox
            {
                ItemsSource = ingredients,
                DisplayMemberPath = "Name",
                SelectedValuePath = "Id"
            };
            _ingCombo.SelectionChanged += (_, _) =>
            {
                UpdateSubtotal();
                _onChanged();
            };

            _qtyBox = new TextBox { Text = initQty > 0 ? initQty.ToString("0.###", CultureInfo.InvariantCulture) : "0.2", VerticalContentAlignment = VerticalAlignment.Center };
            _qtyBox.TextChanged += (_, _) => { UpdateSubtotal(); _onChanged(); };

            _unitCombo = new ComboBox();
            _unitCombo.Items.Add(new ComboBoxItem { Content = "Gramm (g)", Tag = "g" });
            _unitCombo.Items.Add(new ComboBoxItem { Content = "Kilogramm (kg)", Tag = "kg" });
            _unitCombo.Items.Add(new ComboBoxItem { Content = "Millilitr (ml)", Tag = "ml" });
            _unitCombo.Items.Add(new ComboBoxItem { Content = "Litr (l)", Tag = "l" });
            _unitCombo.Items.Add(new ComboBoxItem { Content = "Dona (dona)", Tag = "dona" });
            _unitCombo.Items.Add(new ComboBoxItem { Content = "Pachka (pachka)", Tag = "pachka" });
            _unitCombo.SelectionChanged += (_, _) => { UpdateSubtotal(); _onChanged(); };

            _costText = new TextBlock
            {
                Text = "0 soʻm",
                VerticalAlignment = VerticalAlignment.Center,
                FontWeight = FontWeights.SemiBold,
                Foreground = Application.Current.FindResource("BrushTextPrimary") as Brush
            };

            _notesBox = new TextBox { Text = initNotes, VerticalContentAlignment = VerticalAlignment.Center };

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
            Grid.SetColumn(_unitCombo, 4);
            Grid.SetColumn(_costText, 6);
            Grid.SetColumn(_notesBox, 8);
            Grid.SetColumn(removeBtn, 9);

            grid.Children.Add(_ingCombo);
            grid.Children.Add(_qtyBox);
            grid.Children.Add(_unitCombo);
            grid.Children.Add(_costText);
            grid.Children.Add(_notesBox);
            grid.Children.Add(removeBtn);

            Child = grid;

            // Selection
            if (preselectId > 0)
            {
                var match = ingredients.FirstOrDefault(i => i.Id == preselectId);
                if (match != null) _ingCombo.SelectedItem = match;
            }
            else if (ingredients.Count > 0)
            {
                _ingCombo.SelectedIndex = 0;
            }

            // Unit selection
            bool unitMatched = false;
            foreach (var item in _unitCombo.Items)
            {
                if (item is ComboBoxItem cbi && string.Equals(cbi.Tag as string, initUnit, StringComparison.OrdinalIgnoreCase))
                {
                    _unitCombo.SelectedItem = cbi;
                    unitMatched = true;
                    break;
                }
            }
            if (!unitMatched) _unitCombo.SelectedIndex = 0;

            UpdateSubtotal();
        }

        private void UpdateSubtotal()
        {
            _costText.Text = $"{CalculatedCost:N0} soʻm";
        }
    }
}
