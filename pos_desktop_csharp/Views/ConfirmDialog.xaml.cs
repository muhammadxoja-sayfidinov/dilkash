using System.Windows;
using System.Windows.Controls;
using DilkashPos.Controls;

namespace DilkashPos.Views
{
    public partial class ConfirmDialog : Window
    {
        public ConfirmDialog(string title, string message, string confirmLabel = "Tasdiqlash", string cancelLabel = "Bekor qilish", bool isDestructive = false)
        {
            InitializeComponent();
            Title = title;
            Chrome.Title = title;
            MessageText.Text = message;
            ConfirmBtn.Content = confirmLabel;
            CancelBtn.Content = cancelLabel;

            if (isDestructive)
            {
                ConfirmBtn.Style = (Style)FindResource("DangerButton");
                IconBadge.SetResourceReference(Border.BackgroundProperty, "BrushErrorTintSoft");
                IconBadge.SetResourceReference(Border.BorderBrushProperty, "BrushError");
                DialogIcon.SetResourceReference(Controls.Icon.ForegroundProperty, "BrushErrorBright");
            }
        }

        private void OnConfirmClick(object sender, RoutedEventArgs e)
        {
            DialogResult = true;
            Close();
        }

        private void OnCancelClick(object sender, RoutedEventArgs e)
        {
            DialogResult = false;
            Close();
        }
    }
}
