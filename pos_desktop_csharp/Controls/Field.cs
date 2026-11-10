using System.Windows;
using System.Windows.Controls;

namespace DilkashPos.Controls
{
    public class Field : ContentControl
    {
        static Field()
        {
            DefaultStyleKeyProperty.OverrideMetadata(typeof(Field), new FrameworkPropertyMetadata(typeof(Field)));
        }

        public static readonly DependencyProperty LabelProperty =
            DependencyProperty.Register(nameof(Label), typeof(string), typeof(Field), new PropertyMetadata(""));

        public static readonly DependencyProperty HelperTextProperty =
            DependencyProperty.Register(nameof(HelperText), typeof(string), typeof(Field), new PropertyMetadata("", OnErrorOrContentChanged));

        public static readonly DependencyProperty ErrorTextProperty =
            DependencyProperty.Register(nameof(ErrorText), typeof(string), typeof(Field), new PropertyMetadata("", OnErrorOrContentChanged));

        public static readonly DependencyProperty HasErrorProperty =
            DependencyProperty.Register(nameof(HasError), typeof(bool), typeof(Field), new PropertyMetadata(false));

        public static readonly DependencyProperty DisplayMessageProperty =
            DependencyProperty.Register(nameof(DisplayMessage), typeof(string), typeof(Field), new PropertyMetadata(""));

        public string Label
        {
            get => (string)GetValue(LabelProperty);
            set => SetValue(LabelProperty, value);
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

        public bool HasError
        {
            get => (bool)GetValue(HasErrorProperty);
            private set => SetValue(HasErrorProperty, value);
        }

        public string DisplayMessage
        {
            get => (string)GetValue(DisplayMessageProperty);
            private set => SetValue(DisplayMessageProperty, value);
        }

        protected override void OnContentChanged(object oldContent, object newContent)
        {
            base.OnContentChanged(oldContent, newContent);
            SyncErrorFlag();
        }

        private static void OnErrorOrContentChanged(DependencyObject d, DependencyPropertyChangedEventArgs e)
        {
            if (d is Field f)
            {
                f.SyncErrorFlag();
            }
        }

        private void SyncErrorFlag()
        {
            bool hasError = !string.IsNullOrWhiteSpace(ErrorText);
            HasError = hasError;
            DisplayMessage = hasError ? ErrorText : HelperText;

            if (Content is DependencyObject depObj)
            {
                ControlAssist.SetHasError(depObj, hasError);
            }
        }
    }
}
