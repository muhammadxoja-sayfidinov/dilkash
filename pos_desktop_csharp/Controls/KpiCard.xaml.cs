using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;

namespace DilkashPos.Controls
{
    public partial class KpiCard : UserControl
    {
        public KpiCard()
        {
            InitializeComponent();
        }

        public static readonly DependencyProperty LabelProperty =
            DependencyProperty.Register(nameof(Label), typeof(string), typeof(KpiCard), new PropertyMetadata("", OnPropsChanged));

        public static readonly DependencyProperty ValueProperty =
            DependencyProperty.Register(nameof(Value), typeof(string), typeof(KpiCard), new PropertyMetadata("0", OnPropsChanged));

        public static readonly DependencyProperty SubtitleProperty =
            DependencyProperty.Register(nameof(Subtitle), typeof(string), typeof(KpiCard), new PropertyMetadata("", OnPropsChanged));

        public static readonly DependencyProperty IconDataProperty =
            DependencyProperty.Register(nameof(IconData), typeof(Geometry), typeof(KpiCard), new PropertyMetadata(null, OnPropsChanged));

        public static readonly DependencyProperty IconForegroundProperty =
            DependencyProperty.Register(nameof(IconForeground), typeof(Brush), typeof(KpiCard), new PropertyMetadata(null, OnPropsChanged));

        public string Label
        {
            get => (string)GetValue(LabelProperty);
            set => SetValue(LabelProperty, value);
        }

        public string Value
        {
            get => (string)GetValue(ValueProperty);
            set => SetValue(ValueProperty, value);
        }

        public string Subtitle
        {
            get => (string)GetValue(SubtitleProperty);
            set => SetValue(SubtitleProperty, value);
        }

        public Geometry? IconData
        {
            get => (Geometry?)GetValue(IconDataProperty);
            set => SetValue(IconDataProperty, value);
        }

        public Brush? IconForeground
        {
            get => (Brush?)GetValue(IconForegroundProperty);
            set => SetValue(IconForegroundProperty, value);
        }

        private static void OnPropsChanged(DependencyObject d, DependencyPropertyChangedEventArgs e)
        {
            if (d is KpiCard c)
            {
                c.LabelBlock.Text = c.Label;
                c.ValueBlock.Text = c.Value;
                c.SubtitleBlock.Text = c.Subtitle;
                c.SubtitleBlock.Visibility = string.IsNullOrWhiteSpace(c.Subtitle) ? Visibility.Collapsed : Visibility.Visible;
                c.CardIcon.Data = c.IconData;
                if (c.IconForeground != null)
                {
                    c.CardIcon.Foreground = c.IconForeground;
                }
            }
        }
    }
}
