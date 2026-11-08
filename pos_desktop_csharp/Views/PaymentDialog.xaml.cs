using System;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;

namespace DilkashPos.Views
{
    public partial class PaymentDialog : Window
    {
        public decimal TotalAmount { get; }
        public string SelectedPaymentMethod { get; private set; } = "naqd";
        public decimal PaidCash { get; private set; }
        public decimal PaidCard { get; private set; }
        public decimal ChangeAmount { get; private set; }

        private string _inputBuffer = "0";

        public PaymentDialog(decimal totalAmount, string orderNumber, string? tableNumber = null, int guestsCount = 1)
        {
            InitializeComponent();
            TotalAmount = totalAmount;

            OrderInfoText.Text = $"Buyurtma #{orderNumber}";
            TableInfoText.Text = string.IsNullOrEmpty(tableNumber) ? "Xizmat turi: TEZKOR SABOY" : $"Stol: #{tableNumber} | Mehmonlar: {guestsCount}";
            TotalSumText.Text = $"{TotalAmount:N0} so'm";

            // Sukut bo'yicha berilgan naqd pul aniq summaga teng
            PaidCash = TotalAmount;
            _inputBuffer = ((long)TotalAmount).ToString();
            UpdateCalculations();
        }

        private void OnMethodSelected(object sender, RoutedEventArgs e)
        {
            if (sender is Button btn && btn.Tag is string method)
            {
                SelectedPaymentMethod = method;

                BtnCash.Background = method == "naqd" ? (Brush)FindResource("BrandPrimaryBrush") : (Brush)FindResource("CardDarkBrush");
                BtnCard.Background = method == "karta" ? (Brush)FindResource("BrandPrimaryBrush") : (Brush)FindResource("CardDarkBrush");
                BtnSplit.Background = method == "aralash" ? (Brush)FindResource("BrandPrimaryBrush") : (Brush)FindResource("CardDarkBrush");

                if (method == "karta")
                {
                    PaidCard = TotalAmount;
                    PaidCash = 0;
                    _inputBuffer = "0";
                }
                else if (method == "naqd")
                {
                    PaidCard = 0;
                    PaidCash = TotalAmount;
                    _inputBuffer = ((long)TotalAmount).ToString();
                }

                UpdateCalculations();
            }
        }

        private void OnNumpadDigitClick(object sender, RoutedEventArgs e)
        {
            if (sender is Button btn && btn.Tag is string digit)
            {
                if (_inputBuffer == "0")
                    _inputBuffer = digit;
                else
                    _inputBuffer += digit;

                if (decimal.TryParse(_inputBuffer, out decimal val))
                {
                    PaidCash = val;
                }
                UpdateCalculations();
            }
        }

        private void OnNumpadClearClick(object sender, RoutedEventArgs e)
        {
            _inputBuffer = "0";
            PaidCash = 0;
            UpdateCalculations();
        }

        private void OnQuickExactClick(object sender, RoutedEventArgs e)
        {
            PaidCash = TotalAmount;
            _inputBuffer = ((long)TotalAmount).ToString();
            UpdateCalculations();
        }

        private void OnQuickCashClick(object sender, RoutedEventArgs e)
        {
            if (sender is Button btn && btn.Tag is string s && decimal.TryParse(s, out decimal amt))
            {
                PaidCash = amt;
                _inputBuffer = ((long)amt).ToString();
                UpdateCalculations();
            }
        }

        private void UpdateCalculations()
        {
            NumpadDisplayText.Text = $"{PaidCash:N0}";
            GivenCashText.Text = $"{PaidCash:N0} so'm";

            if (SelectedPaymentMethod == "naqd")
            {
                ChangeAmount = Math.Max(0, PaidCash - TotalAmount);
                ChangeText.Text = $"{ChangeAmount:N0} so'm";
            }
            else if (SelectedPaymentMethod == "aralash")
            {
                PaidCard = Math.Max(0, TotalAmount - PaidCash);
                ChangeAmount = Math.Max(0, PaidCash - TotalAmount);
                ChangeText.Text = $"Karta: {PaidCard:N0} | Qaytim: {ChangeAmount:N0} so'm";
            }
            else // karta
            {
                ChangeAmount = 0;
                ChangeText.Text = "0 so'm (Karta to'liq)";
            }
        }

        private void OnPayConfirmClick(object sender, RoutedEventArgs e)
        {
            if (SelectedPaymentMethod == "naqd" && PaidCash < TotalAmount)
            {
                MessageBox.Show("Berilgan naqd pul to'lov summasidan kam!", "To'lov xatosi", MessageBoxButton.OK, MessageBoxImage.Warning);
                return;
            }

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

