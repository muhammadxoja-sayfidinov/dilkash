using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Windows;
using DilkashPos.Models;
using Microsoft.Win32;

namespace DilkashPos.Views
{
    public partial class ProductEditDialog : Window
    {
        public int ProductId { get; }
        public string ProductName => NameBox.Text.Trim();
        public decimal ProductPrice { get; private set; }
        public Category? SelectedCategory => CategoryCombo.SelectedItem as Category;
        public string ProductDescription => DescriptionBox.Text.Trim();
        public bool IsProductAvailable => IsAvailableCheck.IsChecked == true;
        public string? SelectedImageBase64 { get; private set; }
        public string? SelectedImageFilename { get; private set; }

        public ProductEditDialog(List<Category> categories, Product? existing = null)
        {
            InitializeComponent();
            ProductId = existing?.Id ?? 0;

            var usableCats = categories.Where(c => c.IsActive || (existing != null && c.Id == existing.CategoryId)).ToList();
            if (usableCats.Count == 0) usableCats = categories;
            CategoryCombo.ItemsSource = usableCats;

            if (existing != null)
            {
                Chrome.Title = "Taomni tahrirlash";
                Chrome.Subtitle = existing.Name;
                NameBox.Text = existing.Name;
                PriceBox.Text = existing.Price.ToString("0", CultureInfo.InvariantCulture);
                DescriptionBox.Text = existing.Description;
                IsAvailableCheck.IsChecked = existing.IsAvailable;
                if (!string.IsNullOrWhiteSpace(existing.ImageUrl))
                    ImageFileText.Text = "Mavjud rasm saqlangan (oʻzgartirish uchun tanlang)";

                var match = usableCats.FirstOrDefault(c => c.Id == existing.CategoryId)
                    ?? usableCats.FirstOrDefault(c => string.Equals(c.Name, existing.CategoryName, StringComparison.OrdinalIgnoreCase));
                if (match != null) CategoryCombo.SelectedItem = match;
            }
            else if (usableCats.Count > 0)
            {
                CategoryCombo.SelectedIndex = 0;
            }
        }

        private void OnPickImageClick(object sender, RoutedEventArgs e)
        {
            var dlg = new OpenFileDialog
            {
                Filter = "Rasmlar (*.jpg;*.jpeg;*.png;*.webp)|*.jpg;*.jpeg;*.png;*.webp",
                Title = "Taom rasmini tanlang"
            };
            if (dlg.ShowDialog(this) == true)
            {
                var info = new FileInfo(dlg.FileName);
                if (info.Length > 3 * 1024 * 1024)
                {
                    ErrorBanner.Text = "Rasm hajmi 3 MB dan oshmasligi kerak.";
                    ErrorBanner.Visibility = Visibility.Visible;
                    return;
                }
                SelectedImageBase64 = Convert.ToBase64String(File.ReadAllBytes(dlg.FileName));
                SelectedImageFilename = info.Name;
                ImageFileText.Text = info.Name;
                ErrorBanner.Visibility = Visibility.Collapsed;
            }
        }

        private void OnConfirmClick(object sender, RoutedEventArgs e)
        {
            if (string.IsNullOrWhiteSpace(ProductName))
            {
                ErrorBanner.Text = "Taom nomini kiriting.";
                ErrorBanner.Visibility = Visibility.Visible;
                return;
            }
            if (SelectedCategory == null)
            {
                ErrorBanner.Text = "Avval kategoriya (guruh) tanlang.";
                ErrorBanner.Visibility = Visibility.Visible;
                return;
            }
            var rawPrice = PriceBox.Text.Trim().Replace(" ", "").Replace(",", "");
            if (!decimal.TryParse(rawPrice, NumberStyles.Number, CultureInfo.InvariantCulture, out var parsed) || parsed < 0)
            {
                ErrorBanner.Text = "Narxni toʻgʻri kiriting (masalan: 35000).";
                ErrorBanner.Visibility = Visibility.Visible;
                return;
            }
            ProductPrice = parsed;
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
