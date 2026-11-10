using System;
using System.Windows;
using DilkashPos.Models;
using DilkashPos.Services;
using DilkashPos.Utils;

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
                Toast.Show("Kassa printeri IP manzili sozlanmagan", ToastTone.Warning);
                return;
            }

            var res = await _printer.PrintShiftReportAsync(_report, isZReport: false, _kassaPrinterIp);
            if (res.Success)
            {
                Toast.Show("X-hisobot kassa printeriga chop etildi", ToastTone.Success);
            }
            else
            {
                Toast.Show(res.Message, ToastTone.Warning);
            }
        }

        private async void OnPrintZReportClick(object sender, RoutedEventArgs e)
        {
            bool confirmed = Dialogs.Confirm(
                "Z-hisobot tasdigʻi",
                "Z-hisobot chop etilgach smena yopiladi va yangi kun hisobi boshlanadi. Davom etasizmi?",
                "Smenani yopish",
                "Bekor qilish",
                isDestructive: true,
                owner: this);

            if (!confirmed) return;

            if (!string.IsNullOrEmpty(_kassaPrinterIp))
            {
                await _printer.PrintShiftReportAsync(_report, isZReport: true, _kassaPrinterIp);
            }

            Toast.Show("Smena yopildi va Z-hisobot chop etildi", ToastTone.Success);
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

