using System;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Threading;
using DilkashPos.Utils;

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
        private DispatcherTimer? _autoCloseTimer;

        public PaymentDialog(decimal totalAmount, string orderNumber, string? tableNumber = null, int guestsCount = 1)
        {
            InitializeComponent();
            TotalAmount = totalAmount;

            Chrome.Subtitle = $"Buyurtma #{orderNumber}";
            TableInfoText.Text = string.IsNullOrEmpty(tableNumber)
                ? "Saboy (Olib ketish)"
                : $"Stol #{tableNumber} · {guestsCount} mehmon";
            TotalSumText.Text = MoneyFormatter.Format(TotalAmount);

            // Default received cash equals exact total
            PaidCash = TotalAmount;
            _inputBuffer = ((long)TotalAmount).ToString();
            UpdateCalculations();
        }

        private void OnMethodSelected(object sender, RoutedEventArgs e)
        {
            if (sender is RadioButton rb && rb.Tag is string method)
            {
                ApplyMethod(method);
            }
        }

        public void SetDemoMethod(string method)
        {
            BtnCash.IsChecked = method == "naqd";
            BtnCard.IsChecked = method == "karta";
            BtnSplit.IsChecked = method == "aralash";
            ApplyMethod(method);

            if (method == "aralash" && TotalAmount >= 100000)
            {
                PaidCash = 100000;
                _inputBuffer = "100000";
                UpdateCalculations();
            }
        }

        public void SetDemoSuccessState()
        {
            if (SelectedPaymentMethod == "naqd" && PaidCash <= TotalAmount)
            {
                PaidCash = TotalAmount + 15000;
                _inputBuffer = ((long)PaidCash).ToString();
                UpdateCalculations();
            }
            ShowSuccessView(autoClose: false);
        }

        private void ApplyMethod(string method)
        {
            SelectedPaymentMethod = method;

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
            else // aralash
            {
                if (PaidCash <= 0 || PaidCash >= TotalAmount)
                {
                    PaidCash = Math.Floor(TotalAmount / 2m);
                    _inputBuffer = ((long)PaidCash).ToString();
                }
            }

            bool allowCashEntry = method != "karta";
            NumpadGrid.IsEnabled = allowCashEntry;
            QuickBillsPanel.IsEnabled = allowCashEntry;

            UpdateCalculations();
        }

        private void OnNumpadDigitClick(object sender, RoutedEventArgs e)
        {
            if (SelectedPaymentMethod == "karta") return;

            if (sender is Button btn && btn.Tag is string digit)
            {
                if (_inputBuffer == "0")
                    _inputBuffer = digit == "000" ? "0" : digit;
                else if (_inputBuffer.Length < 10)
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
            if (SelectedPaymentMethod == "karta") return;

            _inputBuffer = "0";
            PaidCash = 0;
            UpdateCalculations();
        }

        private void OnQuickExactClick(object sender, RoutedEventArgs e)
        {
            if (SelectedPaymentMethod == "karta") return;

            PaidCash = TotalAmount;
            _inputBuffer = ((long)TotalAmount).ToString();
            UpdateCalculations();
        }

        private void OnQuickCashClick(object sender, RoutedEventArgs e)
        {
            if (SelectedPaymentMethod == "karta") return;

            if (sender is Button btn && btn.Tag is string s && decimal.TryParse(s, out decimal amt))
            {
                PaidCash = amt;
                _inputBuffer = ((long)amt).ToString();
                UpdateCalculations();
            }
        }

        private void UpdateCalculations()
        {
            ErrorHintText.Visibility = Visibility.Collapsed;

            if (SelectedPaymentMethod == "karta")
            {
                NumpadDisplayText.Text = MoneyFormatter.FormatNumberOnly(TotalAmount);
                GivenLabelText.Text = "Karta orqali";
                GivenCashText.Text = MoneyFormatter.Format(TotalAmount);
                ChangeLabelText.Text = "Qaytim";
                ChangeAmount = 0;
                ChangeText.Text = $"0\u00A0so\u02BBm";
            }
            else if (SelectedPaymentMethod == "aralash")
            {
                NumpadDisplayText.Text = MoneyFormatter.FormatNumberOnly(PaidCash);
                GivenLabelText.Text = "Naqd qismi";
                GivenCashText.Text = MoneyFormatter.Format(PaidCash);

                PaidCard = Math.Max(0, TotalAmount - PaidCash);
                ChangeAmount = Math.Max(0, PaidCash - TotalAmount);

                if (ChangeAmount > 0)
                {
                    ChangeLabelText.Text = "Qaytim";
                    ChangeText.Text = MoneyFormatter.Format(ChangeAmount);
                }
                else
                {
                    ChangeLabelText.Text = "Karta qismi";
                    ChangeText.Text = MoneyFormatter.Format(PaidCard);
                }
            }
            else // naqd
            {
                NumpadDisplayText.Text = MoneyFormatter.FormatNumberOnly(PaidCash);
                GivenLabelText.Text = "Qabul qilingan";
                GivenCashText.Text = MoneyFormatter.Format(PaidCash);
                ChangeLabelText.Text = "Qaytim";
                ChangeAmount = Math.Max(0, PaidCash - TotalAmount);
                ChangeText.Text = MoneyFormatter.Format(ChangeAmount);
            }
        }

        private void OnPayConfirmClick(object sender, RoutedEventArgs e)
        {
            if (SelectedPaymentMethod == "naqd" && PaidCash < TotalAmount)
            {
                ErrorHintText.Text = "Berilgan naqd pul toʻlov summasidan kam";
                ErrorHintText.Visibility = Visibility.Visible;
                Toast.Show("Berilgan naqd pul toʻlov summasidan kam", ToastTone.Warning);
                return;
            }

            ShowSuccessView(autoClose: true);
        }

        private void ShowSuccessView(bool autoClose)
        {
            PaymentEntryGrid.Visibility = Visibility.Collapsed;
            EntryFooterGrid.Visibility = Visibility.Collapsed;

            PaymentSuccessView.Visibility = Visibility.Visible;
            SuccessFooterGrid.Visibility = Visibility.Visible;
            Chrome.ShowCloseButton = false;

            string methodLabel = SelectedPaymentMethod switch
            {
                "karta" => "Karta",
                "aralash" => $"Aralash ({MoneyFormatter.Format(PaidCash)} + {MoneyFormatter.Format(PaidCard)})",
                _ => "Naqd"
            };
            SuccessSummaryText.Text = $"{methodLabel} · {MoneyFormatter.Format(TotalAmount)}";

            if (ChangeAmount > 0)
            {
                SuccessChangeBadge.Visibility = Visibility.Visible;
                SuccessChangeAmountText.Text = MoneyFormatter.Format(ChangeAmount);
            }
            else
            {
                SuccessChangeBadge.Visibility = Visibility.Collapsed;
            }

            if (autoClose)
            {
                _autoCloseTimer = new DispatcherTimer { Interval = TimeSpan.FromMilliseconds(850) };
                _autoCloseTimer.Tick += (s, args) =>
                {
                    _autoCloseTimer.Stop();
                    DialogResult = true;
                    Close();
                };
                _autoCloseTimer.Start();
            }
        }

        private void OnSuccessDoneClick(object sender, RoutedEventArgs e)
        {
            _autoCloseTimer?.Stop();
            DialogResult = true;
            Close();
        }

        private void OnCancelClick(object sender, RoutedEventArgs e)
        {
            _autoCloseTimer?.Stop();
            DialogResult = false;
            Close();
        }
    }
}
