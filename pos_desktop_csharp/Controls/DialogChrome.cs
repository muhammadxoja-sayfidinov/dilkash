using System;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using System.Windows.Media.Animation;

namespace DilkashPos.Controls
{
    public class DialogChrome : ContentControl
    {
        static DialogChrome()
        {
            DefaultStyleKeyProperty.OverrideMetadata(typeof(DialogChrome), new FrameworkPropertyMetadata(typeof(DialogChrome)));
        }

        public static readonly DependencyProperty TitleProperty =
            DependencyProperty.Register(nameof(Title), typeof(string), typeof(DialogChrome), new PropertyMetadata(""));

        public static readonly DependencyProperty SubtitleProperty =
            DependencyProperty.Register(nameof(Subtitle), typeof(string), typeof(DialogChrome), new PropertyMetadata(""));

        public static readonly DependencyProperty FooterContentProperty =
            DependencyProperty.Register(nameof(FooterContent), typeof(object), typeof(DialogChrome), new PropertyMetadata(null));

        public static readonly DependencyProperty ShowCloseButtonProperty =
            DependencyProperty.Register(nameof(ShowCloseButton), typeof(bool), typeof(DialogChrome), new PropertyMetadata(true));

        public string Title
        {
            get => (string)GetValue(TitleProperty);
            set => SetValue(TitleProperty, value);
        }

        public string Subtitle
        {
            get => (string)GetValue(SubtitleProperty);
            set => SetValue(SubtitleProperty, value);
        }

        public object? FooterContent
        {
            get => GetValue(FooterContentProperty);
            set => SetValue(FooterContentProperty, value);
        }

        public bool ShowCloseButton
        {
            get => (bool)GetValue(ShowCloseButtonProperty);
            set => SetValue(ShowCloseButtonProperty, value);
        }

        public static bool DisableAnimationsForTests { get; set; } = false;

        public event EventHandler? CloseRequested;

        public override void OnApplyTemplate()
        {
            base.OnApplyTemplate();

            if (GetTemplateChild("PART_CloseBtn") is Button closeBtn)
            {
                closeBtn.Click -= OnCloseBtnClick;
                closeBtn.Click += OnCloseBtnClick;
            }

            Loaded -= OnChromeLoaded;
            Loaded += OnChromeLoaded;
        }

        private void OnChromeLoaded(object sender, RoutedEventArgs e)
        {
            if (GetTemplateChild("PART_ChromeRoot") is Border root &&
                GetTemplateChild("PART_ChromeScale") is ScaleTransform scale)
            {
                if (DisableAnimationsForTests)
                {
                    root.Opacity = 1.0;
                    scale.ScaleX = 1.0;
                    scale.ScaleY = 1.0;
                    return;
                }

                var duration = new Duration(TimeSpan.FromMilliseconds(220));
                var ease = new CubicEase { EasingMode = EasingMode.EaseOut };

                root.BeginAnimation(OpacityProperty, new DoubleAnimation(0.0, 1.0, duration) { EasingFunction = ease });
                scale.BeginAnimation(ScaleTransform.ScaleXProperty, new DoubleAnimation(0.98, 1.0, duration) { EasingFunction = ease });
                scale.BeginAnimation(ScaleTransform.ScaleYProperty, new DoubleAnimation(0.98, 1.0, duration) { EasingFunction = ease });
            }
        }

        private void OnCloseBtnClick(object sender, RoutedEventArgs e)
        {
            if (CloseRequested != null)
            {
                CloseRequested.Invoke(this, EventArgs.Empty);
                return;
            }

            if (Window.GetWindow(this) is Window win)
            {
                try { win.DialogResult = false; } catch { }
                win.Close();
            }
        }
    }
}
