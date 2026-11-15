using System;
using System.Windows;
using DilkashPos.Models;

namespace DilkashPos.Views
{
    public partial class SupplierEditDialog : Window
    {
        public int SupplierId { get; }
        public string SupplierName => NameBox.Text.Trim();
        public string SupplierPhone => PhoneBox.Text.Trim();
        public string ContactPerson => ContactPersonBox.Text.Trim();
        public string Address => AddressBox.Text.Trim();
        public string Notes => NotesBox.Text.Trim();
        public bool IsSupplierActive => IsActiveCheck.IsChecked == true;

        public SupplierEditDialog(Supplier? existing = null)
        {
            InitializeComponent();
            SupplierId = existing?.Id ?? 0;

            if (existing != null)
            {
                Chrome.Title = "Taʼminotchini tahrirlash";
                Chrome.Subtitle = existing.Name;
                NameBox.Text = existing.Name;
                PhoneBox.Text = existing.Phone;
                ContactPersonBox.Text = existing.ContactPerson;
                AddressBox.Text = existing.Address;
                NotesBox.Text = existing.Notes;
                IsActiveCheck.IsChecked = existing.IsActive;
            }

            Loaded += (_, _) => NameBox.Focus();
        }

        private void OnCancelClick(object sender, RoutedEventArgs e)
        {
            DialogResult = false;
            Close();
        }

        private void OnSaveClick(object sender, RoutedEventArgs e)
        {
            if (string.IsNullOrWhiteSpace(SupplierName))
            {
                ShowError("Taʼminotchi nomini kiriting");
                NameBox.Focus();
                return;
            }

            DialogResult = true;
            Close();
        }

        private void ShowError(string msg)
        {
            ErrorBanner.Text = msg;
            ErrorBanner.Visibility = Visibility.Visible;
        }
    }
}
