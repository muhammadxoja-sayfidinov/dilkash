using System.Windows;
using System.Windows.Controls;

namespace DilkashPos.Controls
{
    public partial class SectionHeader : UserControl
    {
        public SectionHeader()
        {
            InitializeComponent();
        }

        public static readonly DependencyProperty TitleProperty =
            DependencyProperty.Register(nameof(Title), typeof(string), typeof(SectionHeader), new PropertyMetadata(""));

        public static readonly DependencyProperty SubtitleProperty =
            DependencyProperty.Register(nameof(Subtitle), typeof(string), typeof(SectionHeader), new PropertyMetadata("", OnSubtitleChanged));

        public static readonly DependencyProperty RightContentProperty =
            DependencyProperty.Register(nameof(RightContent), typeof(object), typeof(SectionHeader), new PropertyMetadata(null));

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

        public object? RightContent
        {
            get => GetValue(RightContentProperty);
            set => SetValue(RightContentProperty, value);
        }

        private static void OnSubtitleChanged(DependencyObject d, DependencyPropertyChangedEventArgs e)
        {
            if (d is SectionHeader sh && e.NewValue is string sub)
            {
                sh.SubtitleBlock.Visibility = string.IsNullOrWhiteSpace(sub) ? Visibility.Collapsed : Visibility.Visible;
            }
        }
    }
}
