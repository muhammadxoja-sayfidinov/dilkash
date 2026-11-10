using System;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using System.Windows.Media.Animation;
using DilkashPos.ViewModels;

namespace DilkashPos.Controls
{
    public partial class CartLine : UserControl
    {
        private int _lastQty = -1;

        public CartLine()
        {
            InitializeComponent();
            DataContextChanged += OnDataContextChanged;
        }

        public event EventHandler<CartLineVM>? IncrementClicked;
        public event EventHandler<CartLineVM>? DecrementClicked;
        public event EventHandler<CartLineVM>? EditNoteClicked;

        private CartLineVM? CurrentVM => DataContext as CartLineVM;

        private void OnDataContextChanged(object sender, DependencyPropertyChangedEventArgs e)
        {
            if (e.OldValue is CartLineVM oldVm)
            {
                oldVm.PropertyChanged -= OnVmPropertyChanged;
            }
            if (e.NewValue is CartLineVM newVm)
            {
                _lastQty = newVm.Quantity;
                newVm.PropertyChanged += OnVmPropertyChanged;
            }
        }

        private void OnVmPropertyChanged(object? sender, System.ComponentModel.PropertyChangedEventArgs e)
        {
            if (e.PropertyName == nameof(CartLineVM.Quantity) && CurrentVM != null && CurrentVM.Quantity != _lastQty)
            {
                _lastQty = CurrentVM.Quantity;
                BumpStepperQuantity();
            }
        }

        private void BumpStepperQuantity()
        {
            if (DialogChrome.DisableAnimationsForTests) return;

            LineStepper.QuantityText.RenderTransformOrigin = new Point(0.5, 0.5);
            if (LineStepper.QuantityText.RenderTransform is not ScaleTransform st)
            {
                st = new ScaleTransform(1, 1);
                LineStepper.QuantityText.RenderTransform = st;
            }

            var anim = new DoubleAnimation(1.22, 1.0, new Duration(TimeSpan.FromMilliseconds(140)))
            {
                EasingFunction = new CubicEase { EasingMode = EasingMode.EaseOut }
            };
            st.BeginAnimation(ScaleTransform.ScaleXProperty, anim);
            st.BeginAnimation(ScaleTransform.ScaleYProperty, anim);
        }

        private void OnIncrementClick(object? sender, EventArgs e)
        {
            if (CurrentVM != null) IncrementClicked?.Invoke(this, CurrentVM);
        }

        private void OnDecrementClick(object? sender, EventArgs e)
        {
            if (CurrentVM != null) DecrementClicked?.Invoke(this, CurrentVM);
        }

        private void OnEditNoteClick(object sender, RoutedEventArgs e)
        {
            if (CurrentVM != null) EditNoteClicked?.Invoke(this, CurrentVM);
        }
    }
}
