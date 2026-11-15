using System;
using System.Collections.Generic;
using System.Linq;
using System.Windows;
using System.Windows.Controls;
using DilkashPos.Models;

namespace DilkashPos.Views
{
    public partial class CategoryEditDialog : Window
    {
        public int CategoryId { get; }
        public string CategoryName => NameBox.Text.Trim();
        public int? SelectedParentId
        {
            get
            {
                if (ParentCategoryCombo.SelectedItem is Category c && c.Id > 0)
                    return c.Id;
                return null;
            }
        }
        public string SelectedDepartment => (DepartmentCombo.SelectedItem as ComboBoxItem)?.Tag as string ?? "kitchen";
        public string CategoryDescription => DescriptionBox.Text.Trim();
        public bool IsCategoryActive => IsActiveCheck.IsChecked == true;

        public CategoryEditDialog(Category? existing = null, List<Category>? allCategories = null)
        {
            InitializeComponent();
            CategoryId = existing?.Id ?? 0;

            var parentChoices = new List<Category>
            {
                new Category { Id = 0, Name = "Yoʻq (Asosiy kategoriya)" }
            };
            if (allCategories != null)
            {
                var excluded = new HashSet<int>();
                if (existing != null && existing.Id > 0)
                {
                    excluded.Add(existing.Id);
                    CollectDescendantIds(existing.Id, allCategories, excluded);
                }
                foreach (var c in allCategories.Where(c => c.Id > 0 && !excluded.Contains(c.Id)).OrderBy(c => c.Name))
                {
                    parentChoices.Add(c);
                }
            }
            ParentCategoryCombo.ItemsSource = parentChoices;
            ParentCategoryCombo.SelectedIndex = 0;

            if (existing != null)
            {
                Chrome.Title = "Guruhni tahrirlash";
                Chrome.Subtitle = existing.Name;
                NameBox.Text = existing.Name;
                DescriptionBox.Text = existing.Description;
                IsActiveCheck.IsChecked = existing.IsActive;

                if (existing.ParentId.HasValue && existing.ParentId.Value > 0)
                {
                    var matchParent = parentChoices.FirstOrDefault(p => p.Id == existing.ParentId.Value);
                    if (matchParent != null) ParentCategoryCombo.SelectedItem = matchParent;
                }

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

        private static void CollectDescendantIds(int parentId, List<Category> all, HashSet<int> result)
        {
            foreach (var c in all.Where(x => x.ParentId == parentId))
            {
                if (result.Add(c.Id))
                    CollectDescendantIds(c.Id, all, result);
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
