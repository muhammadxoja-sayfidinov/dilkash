using System.Windows;
using DilkashPos.Models;

namespace DilkashPos.Views
{
    public partial class HallEditDialog : Window
    {
        public int HallId { get; }
        public string HallName => NameBox.Text.Trim();
        public string HallDescription => DescriptionBox.Text.Trim();
        public int HallSortOrder { get; private set; } = 1;
        public bool IsHallActive => IsActiveCheck.IsChecked == true;

        public HallEditDialog(Hall? existing = null, int suggestedOrder = 1)
        {
            InitializeComponent();
            HallId = existing?.Id ?? 0;

            if (existing != null)
            {
                Chrome.Title = "Zalni tahrirlash";
                Chrome.Subtitle = existing.Name;
                NameBox.Text = existing.Name;
                DescriptionBox.Text = existing.Description;
                SortOrderBox.Text = existing.SortOrder.ToString();
                IsActiveCheck.IsChecked = existing.IsActive;
            }
            else
            {
                SortOrderBox.Text = suggestedOrder.ToString();
            }
        }

        private void OnConfirmClick(object sender, RoutedEventArgs e)
        {
            if (string.IsNullOrWhiteSpace(HallName))
            {
                ErrorBanner.Text = "Zal nomini kiriting.";
                ErrorBanner.Visibility = Visibility.Visible;
                return;
            }
            if (!int.TryParse(SortOrderBox.Text.Trim(), out int order) || order < 0)
            {
                order = 1;
            }
            HallSortOrder = order;
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
