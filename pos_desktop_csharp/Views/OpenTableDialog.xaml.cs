using System.Windows;
using System.Windows.Controls;

namespace DilkashPos.Views
{
    public partial class OpenTableDialog : Window
    {
        public int TableNumber { get; }
        public int SelectedGuestsCount { get; private set; } = 2;
        public string WaiterName => WaiterNameBox.Text.Trim();

        public OpenTableDialog(int tableNumber, string tableName, string defaultWaiter = "Jasur")
        {
            InitializeComponent();
            TableNumber = tableNumber;
            Chrome.Title = string.IsNullOrWhiteSpace(tableName) ? $"Stol #{tableNumber}" : tableName;
            WaiterNameBox.Text = defaultWaiter;
            SelectedGuestCountText.Text = $"{SelectedGuestsCount} kishi";

            PopulateGuestButtons();
        }

        private void PopulateGuestButtons()
        {
            GuestButtonsGrid.Children.Clear();
            var segStyle = (Style)FindResource("SegmentedItem");

            for (int count = 1; count <= 12; count++)
            {
                var chip = new RadioButton
                {
                    GroupName = "GuestCountChips",
                    Content = count.ToString(),
                    MinWidth = 52,
                    MinHeight = 48,
                    Height = 48,
                    Margin = new Thickness(4),
                    Padding = new Thickness(0),
                    FontSize = 15,
                    FontWeight = FontWeights.SemiBold,
                    Style = segStyle,
                    IsChecked = count == SelectedGuestsCount,
                    Tag = count
                };
                chip.SetResourceReference(BackgroundProperty, "BrushInput");
                chip.SetResourceReference(BorderBrushProperty, "BrushBorder");

                chip.Checked += (s, e) =>
                {
                    if (s is RadioButton rb && rb.Tag is int c)
                    {
                        SelectedGuestsCount = c;
                        SelectedGuestCountText.Text = $"{SelectedGuestsCount} kishi";
                    }
                };

                GuestButtonsGrid.Children.Add(chip);
            }
        }

        private void OnConfirmClick(object sender, RoutedEventArgs e)
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
