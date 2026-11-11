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
        public bool IsTableActive => IsActiveCheck.IsChecked == true;

        public TableEditDialog(RestaurantTable? existing = null, int suggestedNextNum = 13)
        {
            InitializeComponent();
            TableId = existing?.Id ?? 0;

            if (existing != null)
            {
                Chrome.Title = "Stolni tahrirlash";
                Chrome.Subtitle = existing.Name;
                NumberBox.Text = existing.Number.ToString();
                CapacityBox.Text = existing.Capacity.ToString();
                NameBox.Text = existing.Name;
                IsActiveCheck.IsChecked = existing.IsActive;
            }
            else
            {
                NumberBox.Text = suggestedNextNum.ToString();
                NameBox.Text = $"VIP Xona #{suggestedNextNum}";
                CapacityBox.Text = "6";
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
