using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;

namespace DilkashPos.Controls
{
    public enum PillTone
    {
        Neutral,
        Primary,
        Success,
        Warning,
        Error,
        Info,
        Reserved
    }

    public partial class StatusPill : UserControl
    {
        public StatusPill()
        {
            InitializeComponent();
        }

        public static readonly DependencyProperty TextProperty =
            DependencyProperty.Register(nameof(Text), typeof(string), typeof(StatusPill), new PropertyMetadata("", OnAppearanceChanged));

        public static readonly DependencyProperty IconDataProperty =
            DependencyProperty.Register(nameof(IconData), typeof(Geometry), typeof(StatusPill), new PropertyMetadata(null, OnAppearanceChanged));

        public static readonly DependencyProperty ToneProperty =
            DependencyProperty.Register(nameof(Tone), typeof(PillTone), typeof(StatusPill), new PropertyMetadata(PillTone.Primary, OnAppearanceChanged));

        public string Text
        {
            get => (string)GetValue(TextProperty);
            set => SetValue(TextProperty, value);
        }

        public Geometry? IconData
        {
            get => (Geometry?)GetValue(IconDataProperty);
            set => SetValue(IconDataProperty, value);
        }

        public PillTone Tone
        {
            get => (PillTone)GetValue(ToneProperty);
            set => SetValue(ToneProperty, value);
        }

        private static void OnAppearanceChanged(DependencyObject d, DependencyPropertyChangedEventArgs e)
        {
            if (d is StatusPill pill)
            {
                pill.UpdateVisuals();
            }
        }

        private void UpdateVisuals()
        {
            PillText.Text = Text;

            if (IconData != null)
            {
                PillIcon.Data = IconData;
                PillIcon.Visibility = Visibility.Visible;
            }
            else
            {
                PillIcon.Visibility = Visibility.Collapsed;
            }

            (string bgKey, string borderKey, string fgKey) = Tone switch
            {
                PillTone.Neutral => ("BrushSurfaceElevated", "BrushBorder", "BrushTextSecondary"),
                PillTone.Primary => ("BrushPrimaryTint", "BrushPrimary", "BrushPrimaryBright"),
                PillTone.Success => ("BrushPrimaryTint", "BrushSuccess", "BrushPrimaryBright"),
                PillTone.Warning => ("BrushAmberTintSoft", "BrushAmber", "BrushAmberBright"),
                PillTone.Error => ("BrushErrorTintSoft", "BrushError", "BrushErrorBright"),
                PillTone.Info => ("BrushSurfaceElevated", "BrushInfo", "BrushTextPrimary"),
                PillTone.Reserved => ("BrushReservedTint", "BrushReserved", "BrushReservedText"),
                _ => ("BrushPrimaryTint", "BrushPrimary", "BrushPrimaryBright")
            };

            PillBorder.SetResourceReference(Border.BackgroundProperty, bgKey);
            PillBorder.SetResourceReference(Border.BorderBrushProperty, borderKey);
            PillText.SetResourceReference(TextBlock.ForegroundProperty, fgKey);
            PillIcon.SetResourceReference(Icon.ForegroundProperty, fgKey);
        }
    }
}
