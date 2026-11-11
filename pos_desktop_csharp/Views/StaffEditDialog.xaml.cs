using System;
using System.Windows;
using System.Windows.Controls;
using DilkashPos.Models;

namespace DilkashPos.Views
{
    public partial class StaffEditDialog : Window
    {
        private readonly bool _isEdit;
        public int StaffId { get; }
        public string SelectedRole => (RoleCombo.SelectedItem as ComboBoxItem)?.Tag as string ?? "waiter";
        public string StaffName => NameBox.Text.Trim();
        public string StaffPhone => PhoneBox.Text.Trim();
        public string StaffPin => PinBox.Text.Trim();
        public string StaffVehicle => VehicleBox.Text.Trim();
        public bool IsStaffActive => IsActiveCheck.IsChecked == true;

        public StaffEditDialog(StaffAccount? existing = null)
        {
            InitializeComponent();
            _isEdit = existing != null;
            StaffId = existing?.Id ?? 0;

            if (existing != null)
            {
                Chrome.Title = "Xodimni tahrirlash";
                Chrome.Subtitle = $"{existing.Name} ({existing.RoleLabel})";
                NameBox.Text = existing.Name;
                PhoneBox.Text = string.IsNullOrWhiteSpace(existing.Phone) ? "+998" : existing.Phone;
                PinBox.Text = "";
                PinField.HelperText = "Oʻzgartirmaslik uchun boʻsh qoldiring";
                VehicleBox.Text = existing.VehicleInfo;
                IsActiveCheck.IsChecked = existing.IsActive;
                RoleCombo.IsEnabled = false;

                foreach (var item in RoleCombo.Items)
                {
                    if (item is ComboBoxItem cbi && string.Equals(cbi.Tag as string, existing.Role, StringComparison.OrdinalIgnoreCase))
                    {
                        RoleCombo.SelectedItem = cbi;
                        break;
                    }
                }
            }
            UpdateVehicleVisibility();
        }

        private void OnRoleChanged(object sender, SelectionChangedEventArgs e)
        {
            UpdateVehicleVisibility();
        }

        private void UpdateVehicleVisibility()
        {
            if (VehicleField != null)
                VehicleField.Visibility = SelectedRole == "courier" ? Visibility.Visible : Visibility.Collapsed;
        }

        private void OnConfirmClick(object sender, RoutedEventArgs e)
        {
            if (string.IsNullOrWhiteSpace(StaffName) || string.IsNullOrWhiteSpace(StaffPhone))
            {
                ErrorBanner.Text = "Xodim ismi va telefon raqami kiritilishi shart.";
                ErrorBanner.Visibility = Visibility.Visible;
                return;
            }
            if (!_isEdit && StaffPin.Length < 4)
            {
                ErrorBanner.Text = "Yangi xodim uchun kamida 4 xonali PIN-kod kiriting.";
                ErrorBanner.Visibility = Visibility.Visible;
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
