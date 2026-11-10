using System;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;

namespace DilkashPos.Controls
{
    public partial class EmptyState : UserControl
    {
        public EmptyState()
        {
            InitializeComponent();
        }

        public static readonly DependencyProperty IconDataProperty =
            DependencyProperty.Register(nameof(IconData), typeof(Geometry), typeof(EmptyState), new PropertyMetadata(null, OnPropsChanged));

        public static readonly DependencyProperty TitleProperty =
            DependencyProperty.Register(nameof(Title), typeof(string), typeof(EmptyState), new PropertyMetadata("Maʻlumot topilmadi", OnPropsChanged));

        public static readonly DependencyProperty SubtitleProperty =
            DependencyProperty.Register(nameof(Subtitle), typeof(string), typeof(EmptyState), new PropertyMetadata("", OnPropsChanged));

        public static readonly DependencyProperty ActionLabelProperty =
            DependencyProperty.Register(nameof(ActionLabel), typeof(string), typeof(EmptyState), new PropertyMetadata("", OnPropsChanged));

        public Geometry? IconData
        {
            get => (Geometry?)GetValue(IconDataProperty);
            set => SetValue(IconDataProperty, value);
        }

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

        public string ActionLabel
        {
            get => (string)GetValue(ActionLabelProperty);
            set => SetValue(ActionLabelProperty, value);
        }

        public event EventHandler? ActionClicked;

        private static void OnPropsChanged(DependencyObject d, DependencyPropertyChangedEventArgs e)
        {
            if (d is EmptyState es)
            {
                es.StateIcon.Data = es.IconData;
                es.TitleBlock.Text = es.Title;
                es.SubtitleBlock.Text = es.Subtitle;
                es.SubtitleBlock.Visibility = string.IsNullOrWhiteSpace(es.Subtitle) ? Visibility.Collapsed : Visibility.Visible;

                if (!string.IsNullOrWhiteSpace(es.ActionLabel))
                {
                    es.ActionBtn.Content = es.ActionLabel;
                    es.ActionBtn.Visibility = Visibility.Visible;
                }
                else
                {
                    es.ActionBtn.Visibility = Visibility.Collapsed;
                }
            }
        }

        private void OnActionClick(object sender, RoutedEventArgs e)
        {
            ActionClicked?.Invoke(this, EventArgs.Empty);
        }
    }
}
