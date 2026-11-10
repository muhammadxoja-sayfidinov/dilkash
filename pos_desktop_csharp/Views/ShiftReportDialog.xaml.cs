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

            Chrome.Subtitle = $"Smena: {_report.OpenedAt:dd.MM.yyyy HH:mm} · Kassir: {_report.CashierName}";
            TotalRevenueText.Text = MoneyFormatter.Format(_report.TotalRevenue);
            TotalOrdersCountText.Text = $"{_report.TotalOrdersCount} ta chek";

            CashRevenueText.Text = MoneyFormatter.Format(_report.CashRevenue);
            CardRevenueText.Text = MoneyFormatter.Format(_report.CardRevenue);
            OnlineRevenueText.Text = MoneyFormatter.Format(_report.OnlineRevenue);

            ServiceFeeText.Text = MoneyFormatter.Format(_report.ServiceFeesCollected);
            DiscountText.Text = MoneyFormatter.Format(_report.DiscountsGiven);

            decimal splitTotal = _report.CashRevenue + _report.CardRevenue + _report.OnlineRevenue;
            if (splitTotal > 0)
            {
                CashBarCol.Width = new GridLength((double)Math.Max(0.5m, _report.CashRevenue), GridUnitType.Star);
                CardBarCol.Width = new GridLength((double)Math.Max(0.5m, _report.CardRevenue), GridUnitType.Star);
                OnlineBarCol.Width = new GridLength((double)Math.Max(0.5m, _report.OnlineRevenue), GridUnitType.Star);
            }
            else
            {
                CashBarCol.Width = new GridLength(1, GridUnitType.Star);
                CardBarCol.Width = new GridLength(1, GridUnitType.Star);
                OnlineBarCol.Width = new GridLength(1, GridUnitType.Star);
            }
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
                Toast.Show("X-hisobot kassa printerida chop etildi", ToastTone.Success);
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
                "Z-hisobot chop etilgach smena yopiladi va yangi hisob boshlanadi. Davom etasizmi?",
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
    }
}
