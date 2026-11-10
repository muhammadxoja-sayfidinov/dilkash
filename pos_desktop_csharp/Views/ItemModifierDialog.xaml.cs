using System;
using System.Collections.Generic;
using System.Linq;
using System.Windows;
using System.Windows.Controls.Primitives;

namespace DilkashPos.Views
{
    public partial class ItemModifierDialog : Window
    {
        private bool _syncing;

        public string Notes => NotesBox.Text.Trim();

        public ItemModifierDialog(string productName, string currentNotes = "")
        {
            InitializeComponent();
            Chrome.Title = productName;
            NotesBox.Text = currentNotes ?? "";
            SyncChipsFromNotes();
        }

        private void SyncChipsFromNotes()
        {
            _syncing = true;
            var tokens = NotesBox.Text
                .Split(',', StringSplitOptions.RemoveEmptyEntries)
                .Select(t => t.Trim())
                .ToHashSet(StringComparer.OrdinalIgnoreCase);

            foreach (var child in QuickChipsPanel.Children)
            {
                if (child is ToggleButton tb && tb.Tag is string tag)
                {
                    tb.IsChecked = tokens.Contains(tag) ||
                                   NotesBox.Text.Contains(tag, StringComparison.OrdinalIgnoreCase);
                }
            }
            _syncing = false;
        }

        private void OnQuickChipToggle(object sender, RoutedEventArgs e)
        {
            if (_syncing || sender is not ToggleButton tb || tb.Tag is not string tag) return;

            var parts = NotesBox.Text
                .Split(',', StringSplitOptions.RemoveEmptyEntries)
                .Select(p => p.Trim())
                .Where(p => !string.IsNullOrEmpty(p))
                .ToList();

            if (tb.IsChecked == true)
            {
                if (!parts.Any(p => string.Equals(p, tag, StringComparison.OrdinalIgnoreCase)))
                {
                    parts.Add(tag);
                }
            }
            else
            {
                parts.RemoveAll(p => string.Equals(p, tag, StringComparison.OrdinalIgnoreCase));
            }

            _syncing = true;
            NotesBox.Text = string.Join(", ", parts);
            _syncing = false;
        }

        private void OnNotesTextChanged(object sender, System.Windows.Controls.TextChangedEventArgs e)
        {
            if (!_syncing)
            {
                SyncChipsFromNotes();
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
