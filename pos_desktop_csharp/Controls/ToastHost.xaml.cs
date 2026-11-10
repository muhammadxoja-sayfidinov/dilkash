using System;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using System.Windows.Media.Animation;
using System.Windows.Threading;
using DilkashPos.Utils;

namespace DilkashPos.Controls
{
    public partial class ToastHost : UserControl
    {
        private readonly DispatcherTimer _hideTimer;
        private Action? _onAction;

        public ToastHost()
        {
            InitializeComponent();
            _hideTimer = new DispatcherTimer { Interval = TimeSpan.FromSeconds(3) };
            _hideTimer.Tick += (s, e) =>
            {
                _hideTimer.Stop();
                HideToast();
            };
        }

        public void ShowToast(string message, ToastTone tone = ToastTone.Info, string? actionLabel = null, Action? onAction = null, bool autoHide = true)
        {
            _hideTimer.Stop();
            _onAction = onAction;

            MessageText.Text = message;

            if (!string.IsNullOrWhiteSpace(actionLabel) && onAction != null)
            {
                ActionBtn.Content = actionLabel;
                ActionBtn.Visibility = Visibility.Visible;
            }
            else
            {
                ActionBtn.Visibility = Visibility.Collapsed;
            }

            (string bgKey, string borderKey, string fgKey, string iconKey) = tone switch
            {
                ToastTone.Success => ("BrushPrimaryTint", "BrushPrimary", "BrushPrimaryBright", "IconCheck"),
                ToastTone.Warning => ("BrushAmberTintSoft", "BrushAmber", "BrushAmberBright", "IconAlert"),
                ToastTone.Error => ("BrushErrorTintSoft", "BrushError", "BrushErrorBright", "IconAlert"),
                _ => ("BrushSurface", "BrushBorder", "BrushPrimaryBright", "IconReceipt")
            };

            ToastCard.SetResourceReference(Border.BorderBrushProperty, borderKey);
            ToneBadge.SetResourceReference(Border.BackgroundProperty, bgKey);
            ToneIcon.Data = (Geometry)FindResource(iconKey);
            ToneIcon.SetResourceReference(Icon.ForegroundProperty, fgKey);

            ToastCard.Visibility = Visibility.Visible;

            if (DialogChrome.DisableAnimationsForTests || !autoHide)
            {
                ToastCard.BeginAnimation(OpacityProperty, null);
                ToastSlide.BeginAnimation(TranslateTransform.YProperty, null);
                ToastCard.Opacity = 1.0;
                ToastSlide.Y = 0.0;
            }
            else
            {
                var duration = new Duration(TimeSpan.FromMilliseconds(220));
                var ease = new CubicEase { EasingMode = EasingMode.EaseOut };

                ToastCard.BeginAnimation(OpacityProperty, new DoubleAnimation(1.0, duration) { EasingFunction = ease });
                ToastSlide.BeginAnimation(TranslateTransform.YProperty, new DoubleAnimation(0.0, duration) { EasingFunction = ease });
            }

            if (autoHide)
            {
                _hideTimer.Start();
            }
        }

        public void HideToast()
        {
            var duration = new Duration(TimeSpan.FromMilliseconds(160));
            var anim = new DoubleAnimation(0.0, duration);
            anim.Completed += (s, e) =>
            {
                if (ToastCard.Opacity <= 0.05)
                {
                    ToastCard.Visibility = Visibility.Collapsed;
                }
            };
            ToastCard.BeginAnimation(OpacityProperty, anim);
        }

        private void OnActionClick(object sender, RoutedEventArgs e)
        {
            _hideTimer.Stop();
            var cb = _onAction;
            _onAction = null;
            HideToast();
            cb?.Invoke();
        }
    }
}
