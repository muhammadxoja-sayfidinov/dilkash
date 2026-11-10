using System.Windows;
using System.Windows.Controls;
using System.Windows.Markup;

namespace DilkashPos.Controls
{
    [ContentProperty(nameof(FieldContent))]
    public partial class Field : UserControl
    {
        public Field()
        {
            InitializeComponent();
        }

        public static readonly DependencyProperty LabelProperty =
            DependencyProperty.Register(nameof(Label), typeof(string), typeof(Field), new PropertyMetadata(""));

        public static readonly DependencyProperty FieldContentProperty =
            DependencyProperty.Register(nameof(FieldContent), typeof(object), typeof(Field), new PropertyMetadata(null, OnHelperChanged));

        public static readonly DependencyProperty HelperTextProperty =
            DependencyProperty.Register(nameof(HelperText), typeof(string), typeof(Field), new PropertyMetadata("", OnHelperChanged));

        public static readonly DependencyProperty ErrorTextProperty =
            DependencyProperty.Register(nameof(ErrorText), typeof(string), typeof(Field), new PropertyMetadata("", OnHelperChanged));

        public string Label
        {
            get => (string)GetValue(LabelProperty);
            set => SetValue(LabelProperty, value);
        }

        public object? FieldContent
        {
            get => GetValue(FieldContentProperty);
            set => SetValue(FieldContentProperty, value);
        }

        public string HelperText
        {
            get => (string)GetValue(HelperTextProperty);
            set => SetValue(HelperTextProperty, value);
        }

        public string ErrorText
        {
            get => (string)GetValue(ErrorTextProperty);
            set => SetValue(ErrorTextProperty, value);
        }

        private static void OnHelperChanged(DependencyObject d, DependencyPropertyChangedEventArgs e)
        {
            if (d is Field field)
            {
                field.UpdateHelperVisuals();
            }
        }

        private void UpdateHelperVisuals()
        {
            bool hasError = !string.IsNullOrWhiteSpace(ErrorText);
            if (FieldContent is DependencyObject depObj)
            {
                ControlAssist.SetHasError(depObj, hasError);
            }

            if (hasError)
            {
                HelperTextBlock.Text = ErrorText;
                HelperTextBlock.SetResourceReference(TextBlock.ForegroundProperty, "BrushErrorBright");
                HelperTextBlock.Visibility = Visibility.Visible;
            }
            else if (!string.IsNullOrWhiteSpace(HelperText))
            {
                HelperTextBlock.Text = HelperText;
                HelperTextBlock.SetResourceReference(TextBlock.ForegroundProperty, "BrushTextMuted");
                HelperTextBlock.Visibility = Visibility.Visible;
            }
            else
            {
                HelperTextBlock.Visibility = Visibility.Collapsed;
            }
        }
    }
}
