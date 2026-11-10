using System;
using System.Windows;
using System.Windows.Controls;

namespace DilkashPos.Controls
{
    public partial class Stepper : UserControl
    {
        public Stepper()
        {
            InitializeComponent();
        }

        public static readonly DependencyProperty ValueProperty =
            DependencyProperty.Register(nameof(Value), typeof(int), typeof(Stepper), new PropertyMetadata(1, OnValueChanged));

        public int Value
        {
            get => (int)GetValue(ValueProperty);
            set => SetValue(ValueProperty, value);
        }

        public event EventHandler? IncrementClicked;
        public event EventHandler? DecrementClicked;

        private static void OnValueChanged(DependencyObject d, DependencyPropertyChangedEventArgs e)
        {
            if (d is Stepper s && e.NewValue is int v)
            {
                s.QuantityText.Text = v.ToString();
            }
        }

        private void OnDecrementClick(object sender, RoutedEventArgs e)
        {
            DecrementClicked?.Invoke(this, EventArgs.Empty);
        }

        private void OnIncrementClick(object sender, RoutedEventArgs e)
        {
            IncrementClicked?.Invoke(this, EventArgs.Empty);
        }
    }
}
