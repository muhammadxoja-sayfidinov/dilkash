using System;
using System.Windows;
using System.Windows.Controls;

namespace DilkashPos.Controls
{
    public partial class SearchBox : UserControl
    {
        public SearchBox()
        {
            InitializeComponent();
        }

        public static readonly DependencyProperty TextProperty =
            DependencyProperty.Register(nameof(Text), typeof(string), typeof(SearchBox),
                new FrameworkPropertyMetadata("", FrameworkPropertyMetadataOptions.BindsTwoWayByDefault, OnTextDependencyChanged));

        public static readonly DependencyProperty PlaceholderProperty =
            DependencyProperty.Register(nameof(Placeholder), typeof(string), typeof(SearchBox), new PropertyMetadata("Qidirish..."));

        public string Text
        {
            get => (string)GetValue(TextProperty);
            set => SetValue(TextProperty, value);
        }

        public string Placeholder
        {
            get => (string)GetValue(PlaceholderProperty);
            set => SetValue(PlaceholderProperty, value);
        }

        public event TextChangedEventHandler? TextChanged;

        private static void OnTextDependencyChanged(DependencyObject d, DependencyPropertyChangedEventArgs e)
        {
            if (d is SearchBox sb && e.NewValue is string val)
            {
                if (sb.InputBox.Text != val)
                {
                    sb.InputBox.Text = val;
                }
                sb.UpdateClearAndPlaceholder(val);
            }
        }

        private void OnInputTextChanged(object sender, TextChangedEventArgs e)
        {
            string val = InputBox.Text;
            if (Text != val)
            {
                Text = val;
            }
            UpdateClearAndPlaceholder(val);
            TextChanged?.Invoke(this, e);
        }

        private void UpdateClearAndPlaceholder(string val)
        {
            bool hasText = !string.IsNullOrEmpty(val);
            PlaceholderText.Visibility = hasText ? Visibility.Collapsed : Visibility.Visible;
            ClearBtn.Visibility = hasText ? Visibility.Visible : Visibility.Collapsed;
        }

        private void OnClearClick(object sender, RoutedEventArgs e)
        {
            InputBox.Text = "";
            InputBox.Focus();
        }
    }
}
