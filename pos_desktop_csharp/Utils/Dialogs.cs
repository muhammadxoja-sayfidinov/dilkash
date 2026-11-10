using System;
using System.Windows;
using System.Windows.Media;
using DilkashPos.Views;

namespace DilkashPos.Utils
{
    public static class Dialogs
    {
        private static Action<bool>? _scrimSetter;

        public static void RegisterScrimHandler(Action<bool> scrimSetter)
        {
            _scrimSetter = scrimSetter;
        }

        public static bool? ShowModal(Window dialog, Window? owner = null)
        {
            var resolvedOwner = owner ?? Application.Current?.MainWindow;
            if (resolvedOwner != null && resolvedOwner != dialog && resolvedOwner.IsVisible)
            {
                dialog.Owner = resolvedOwner;
                dialog.WindowStartupLocation = WindowStartupLocation.CenterOwner;
            }
            else
            {
                dialog.WindowStartupLocation = WindowStartupLocation.CenterScreen;
            }

            dialog.ShowInTaskbar = false;
            dialog.WindowStyle = WindowStyle.None;
            dialog.AllowsTransparency = true;
            dialog.Background = Brushes.Transparent;

            _scrimSetter?.Invoke(true);
            try
            {
                return dialog.ShowDialog();
            }
            finally
            {
                _scrimSetter?.Invoke(false);
            }
        }

        public static bool Confirm(
            string title,
            string message,
            string confirmLabel = "Tasdiqlash",
            string cancelLabel = "Bekor qilish",
            bool isDestructive = false,
            Window? owner = null)
        {
            var dlg = new ConfirmDialog(title, message, confirmLabel, cancelLabel, isDestructive);
            return ShowModal(dlg, owner) == true;
        }
    }
}
