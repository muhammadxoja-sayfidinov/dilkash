using System;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;

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
            TitleText.Text = string.IsNullOrEmpty(tableName) ? $"Stol #{tableNumber} Ochish" : $"{tableName} Ochish";
            WaiterNameBox.Text = defaultWaiter;

            PopulateGuestButtons();
        }

        private void PopulateGuestButtons()
        {
            GuestButtonsPanel.Children.Clear();
            int[] counts = { 1, 2, 3, 4, 5, 6, 7, 8, 10, 12 };

            foreach (var count in counts)
            {
                var btn = new Button
                {
                    Content = $"{count}",
                    Width = 60,
                    Height = 52,
                    Margin = new Thickness(4),
                    FontSize = 18,
                    FontWeight = FontWeights.Bold,
                    Foreground = Brushes.White,
                    Background = count == SelectedGuestsCount ? (Brush)FindResource("BrandPrimaryBrush") : (Brush)FindResource("CardDarkBrush"),
                    BorderThickness = new Thickness(1),
                    BorderBrush = new SolidColorBrush(Color.FromRgb(51, 65, 85)),
                    Tag = count
                };

                btn.Click += (s, e) =>
                {
                    SelectedGuestsCount = (int)((Button)s).Tag;
                    SelectedGuestCountText.Text = $"{SelectedGuestsCount} kishi";

                    // Ranglarni yangilash
                    foreach (Button b in GuestButtonsPanel.Children)
                    {
                        int c = (int)b.Tag;
                        b.Background = c == SelectedGuestsCount ? (Brush)FindResource("BrandPrimaryBrush") : (Brush)FindResource("CardDarkBrush");
                    }
                };

                GuestButtonsPanel.Children.Add(btn);
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

