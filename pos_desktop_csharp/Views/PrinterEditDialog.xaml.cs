using System;
using System.Windows;
using System.Windows.Controls;
using DilkashPos.Models;

namespace DilkashPos.Views
{
    public partial class PrinterEditDialog : Window
    {
        public int PrinterId { get; }
        public string PrinterName => NameBox.Text.Trim();
        public string SelectedDepartment => (DepartmentCombo.SelectedItem as ComboBoxItem)?.Tag as string ?? "kitchen";
        public string IpAddress { get; private set; } = "";
        public int Port { get; private set; } = 9100;
        public int PaperWidth => int.TryParse((PaperWidthCombo.SelectedItem as ComboBoxItem)?.Tag as string, out int pw) ? pw : 80;
        public string PrinterSubtitle => SubtitleBox.Text.Trim();
        public bool IsPrinterActive => IsActiveCheck.IsChecked == true;
        public int SortOrder { get; }

        public PrinterEditDialog(PosPrinter? existing = null, int suggestedOrder = 1)
        {
            InitializeComponent();
            PrinterId = existing?.Id ?? 0;
            SortOrder = existing?.SortOrder > 0 ? existing.SortOrder : suggestedOrder;

            if (existing != null)
            {
                Chrome.Title = "Printerni tahrirlash";
                Chrome.Subtitle = existing.Name;
                NameBox.Text = existing.Name;
                SubtitleBox.Text = existing.Subtitle;
                IsActiveCheck.IsChecked = existing.IsActive;

                var ip = (existing.IpAddress ?? "").Trim();
                int port = existing.Port > 0 ? existing.Port : 9100;
                if (ip.Contains(':'))
                {
                    var parts = ip.Split(':', 2);
                    ip = parts[0].Trim();
                    if (int.TryParse(parts[1].Trim(), out int parsedPort) && parsedPort > 0)
                        port = parsedPort;
                }
                IpBox.Text = ip;
                PortBox.Text = port.ToString();

                foreach (var item in DepartmentCombo.Items)
                {
                    if (item is ComboBoxItem cbi && string.Equals(cbi.Tag as string, existing.Department, StringComparison.OrdinalIgnoreCase))
                    {
                        DepartmentCombo.SelectedItem = cbi;
                        break;
                    }
                }

                string targetWidth = existing.PaperWidth == 58 ? "58" : "80";
                foreach (var item in PaperWidthCombo.Items)
                {
                    if (item is ComboBoxItem cbi && string.Equals(cbi.Tag as string, targetWidth, StringComparison.OrdinalIgnoreCase))
                    {
                        PaperWidthCombo.SelectedItem = cbi;
                        break;
                    }
                }
            }
        }

        private void OnConfirmClick(object sender, RoutedEventArgs e)
        {
            if (string.IsNullOrWhiteSpace(PrinterName))
            {
                ErrorBanner.Text = "Printer nomini kiriting.";
                ErrorBanner.Visibility = Visibility.Visible;
                return;
            }

            var rawIp = IpBox.Text.Trim();
            int port = 9100;
            if (rawIp.Contains(':'))
            {
                var parts = rawIp.Split(':', 2);
                rawIp = parts[0].Trim();
                if (int.TryParse(parts[1].Trim(), out int p)) port = p;
            }
            if (int.TryParse(PortBox.Text.Trim(), out int boxPort) && boxPort > 0 && boxPort <= 65535)
            {
                port = boxPort;
            }

            IpAddress = rawIp;
            Port = port;
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
