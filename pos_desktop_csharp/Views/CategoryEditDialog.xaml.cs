using System;
using System.Windows;
using System.Windows.Controls;
using DilkashPos.Models;

namespace DilkashPos.Views
{
    public partial class CategoryEditDialog : Window
    {
        public int CategoryId { get; }
        public string CategoryName => NameBox.Text.Trim();
        public string SelectedDepartment => (DepartmentCombo.SelectedItem as ComboBoxItem)?.Tag as string ?? "kitchen";
        public string CategoryDescription => DescriptionBox.Text.Trim();
        public bool IsCategoryActive => IsActiveCheck.IsChecked == true;

        public CategoryEditDialog(Category? existing = null)
        {
            InitializeComponent();
            CategoryId = existing?.Id ?? 0;

            if (existing != null)
            {
                Chrome.Title = "Guruhni tahrirlash";
                Chrome.Subtitle = existing.Name;
                NameBox.Text = existing.Name;
                DescriptionBox.Text = existing.Description;
                IsActiveCheck.IsChecked = existing.IsActive;

                foreach (var item in DepartmentCombo.Items)
                {
                    if (item is ComboBoxItem cbi && string.Equals(cbi.Tag as string, existing.Department, StringComparison.OrdinalIgnoreCase))
                    {
                        DepartmentCombo.SelectedItem = cbi;
                        break;
                    }
                }
            }
        }

        private void OnConfirmClick(object sender, RoutedEventArgs e)
        {
            if (string.IsNullOrWhiteSpace(CategoryName))
            {
                ErrorBanner.Text = "Guruh nomini kiriting.";
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
