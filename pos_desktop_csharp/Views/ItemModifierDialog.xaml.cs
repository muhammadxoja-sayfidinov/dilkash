using System;
using System.Windows;
using System.Windows.Controls;

namespace DilkashPos.Views
{
    public partial class ItemModifierDialog : Window
    {
        public string Notes => NotesBox.Text.Trim();

        public ItemModifierDialog(string productName, string currentNotes = "")
        {
            InitializeComponent();
            ItemTitleText.Text = $"Taom: {productName}";
            NotesBox.Text = currentNotes;
        }

        private void OnQuickTagClick(object sender, RoutedEventArgs e)
        {
            if (sender is Button btn && btn.Tag is string tag)
            {
                if (string.IsNullOrWhiteSpace(NotesBox.Text))
                    NotesBox.Text = tag;
                else if (!NotesBox.Text.Contains(tag))
                    NotesBox.Text += $", {tag}";
            }
        }

        private void OnSaveClick(object sender, RoutedEventArgs e)
        {
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
