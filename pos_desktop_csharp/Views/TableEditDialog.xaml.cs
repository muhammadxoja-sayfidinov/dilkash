using System;
using System.Collections.Generic;
using System.Linq;
using System.Windows;
using DilkashPos.Models;

namespace DilkashPos.Views
{
    public partial class TableEditDialog : Window
    {
        public int TableId { get; }
        public int TableNumber { get; private set; }
        public int TableCapacity { get; private set; } = 4;
        public string TableName => string.IsNullOrWhiteSpace(NameBox.Text) ? $"Stol #{TableNumber}" : NameBox.Text.Trim();
        public Hall? SelectedHall => HallCombo.SelectedItem as Hall;
        public bool IsTableActive => IsActiveCheck.IsChecked == true;

        public TableEditDialog(RestaurantTable? existing = null, int suggestedNextNum = 13, List<Hall>? halls = null)
        {
            InitializeComponent();
            TableId = existing?.Id ?? 0;

            var hallChoices = (halls != null && halls.Count > 0)
                ? halls.Where(h => h.IsActive || (existing != null && h.Id == existing.HallId)).ToList()
                : new List<Hall>
                {
                    new Hall { Id = 1, Name = "Zal", SortOrder = 1 },
                    new Hall { Id = 2, Name = "Terrasa", SortOrder = 2 },
                    new Hall { Id = 3, Name = "VIP", SortOrder = 3 },
                };
            if (hallChoices.Count == 0 && halls != null) hallChoices = halls;
            HallCombo.ItemsSource = hallChoices;

            if (existing != null)
            {
                Chrome.Title = "Stolni tahrirlash";
                Chrome.Subtitle = existing.Name;
                NumberBox.Text = existing.Number.ToString();
                CapacityBox.Text = existing.Capacity.ToString();
                NameBox.Text = existing.Name;
                IsActiveCheck.IsChecked = existing.IsActive;

                var matchHall = (existing.HallId.HasValue ? hallChoices.FirstOrDefault(h => h.Id == existing.HallId.Value) : null)
                    ?? hallChoices.FirstOrDefault(h => string.Equals(h.Name, existing.Zone, StringComparison.OrdinalIgnoreCase));
                if (matchHall != null) HallCombo.SelectedItem = matchHall;
                else if (hallChoices.Count > 0) HallCombo.SelectedIndex = 0;
            }
            else
            {
                NumberBox.Text = suggestedNextNum.ToString();
                NameBox.Text = $"Stol #{suggestedNextNum}";
                CapacityBox.Text = "6";
                if (hallChoices.Count > 0)
                {
                    var vipMatch = hallChoices.FirstOrDefault(h => h.Name.Contains("VIP", StringComparison.OrdinalIgnoreCase));
                    HallCombo.SelectedItem = vipMatch ?? hallChoices[0];
                }
            }
        }

        private void OnConfirmClick(object sender, RoutedEventArgs e)
        {
            if (!int.TryParse(NumberBox.Text.Trim(), out int num) || num <= 0)
            {
                ErrorBanner.Text = "Stol raqami musbat son boʻlishi shart.";
                ErrorBanner.Visibility = Visibility.Visible;
                return;
            }
            if (!int.TryParse(CapacityBox.Text.Trim(), out int cap) || cap <= 0)
            {
                ErrorBanner.Text = "Oʻrinlar soni kamida 1 boʻlishi kerak.";
                ErrorBanner.Visibility = Visibility.Visible;
                return;
            }
            TableNumber = num;
            TableCapacity = cap;
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
