using System;
using System.Windows;
using DilkashPos.Models;
using DilkashPos.Services;

namespace DilkashPos.Views
{
    public partial class ShiftReportDialog : Window
    {
        private readonly ShiftReport _report;
        private readonly EscPosPrinterService _printer;
        private readonly string _kassaPrinterIp;

        public ShiftReportDialog(ShiftReport report, EscPosPrinterService printer, string kassaPrinterIp)
        {
            InitializeComponent();
            _report = report;
            _printer = printer;
            _kassaPrinterIp = kassaPrinterIp;

            ShiftTimeText.Text = $"Smena: {_report.OpenedAt:dd.MM.yyyy HH:mm} | Kassir: {_report.CashierName}";
            TotalRevenueText.Text = $"{_report.TotalRevenue:N0} so'm";
            TotalOrdersCountText.Text = $"Jami buyurtmalar: {_report.TotalOrdersCount} ta";

            CashRevenueText.Text = $"{_report.CashRevenue:N0} so'm";
            CardRevenueText.Text = $"{_report.CardRevenue:N0} so'm";
            OnlineRevenueText.Text = $"{_report.OnlineRevenue:N0} so'm";

            ServiceFeeText.Text = $"{_report.ServiceFeesCollected:N0} so'm";
            DiscountText.Text = $"{_report.DiscountsGiven:N0} so'm";
        }

        private async void OnPrintXReportClick(object sender, RoutedEventArgs e)
        {
            if (string.IsNullOrEmpty(_kassaPrinterIp))
            {
                MessageBox.Show("Kassa printeri IP manzili sozlanmagan!", "Xatolik", MessageBoxButton.OK, MessageBoxImage.Warning);
                return;
            }

            var res = await _printer.PrintShiftReportAsync(_report, isZReport: false, _kassaPrinterIp);
            if (res.Success)
            {
                MessageBox.Show("X-Hisobot kassa printeriga muvaffaqiyatli chop etildi!", "X-Hisobot", MessageBoxButton.OK, MessageBoxImage.Information);
            }
            else
            {
                MessageBox.Show(res.Message, "Printer Xatosi", MessageBoxButton.OK, MessageBoxImage.Warning);
            }
        }

        private async void OnPrintZReportClick(object sender, RoutedEventArgs e)
        {
            var confirm = MessageBox.Show("Diqqat! Z-Hisobot chop etilgach smena yopiladi va yangi kun hisobi boshlanadi. Davom ettirasizmi?",
                "Z-Hisobot Tasdig'i", MessageBoxButton.YesNo, MessageBoxImage.Question);

            if (confirm != MessageBoxResult.Yes) return;

            if (!string.IsNullOrEmpty(_kassaPrinterIp))
            {
                await _printer.PrintShiftReportAsync(_report, isZReport: true, _kassaPrinterIp);
            }

            MessageBox.Show("Smena muvaffaqiyatli yopildi va Z-Hisobot chop etildi!", "Smena Yopildi", MessageBoxButton.OK, MessageBoxImage.Information);
            DialogResult = true;
            Close();
        }

        private void OnCloseClick(object sender, RoutedEventArgs e)
        {
            DialogResult = false;
            Close();
        }
    }
}

