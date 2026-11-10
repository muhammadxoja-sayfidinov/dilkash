using System;
using System.Windows;
using DilkashPos.Controls;

namespace DilkashPos.Utils
{
    public enum ToastTone
    {
        Info,
        Success,
        Warning,
        Error
    }

    public static class Toast
    {
        private static ToastHost? _registeredHost;

        public static void RegisterHost(ToastHost host)
        {
            _registeredHost = host;
        }

        public static void Show(string message, ToastTone tone = ToastTone.Info, string? actionLabel = null, Action? onAction = null, bool autoHide = true)
        {
            var host = _registeredHost;
            if (host == null && Application.Current?.MainWindow is MainWindow mw)
            {
                host = mw.FindName("MainToastHost") as ToastHost;
            }

            if (host == null) return;

            if (host.Dispatcher.CheckAccess())
            {
                host.ShowToast(message, tone, actionLabel, onAction, autoHide);
            }
            else
            {
                host.Dispatcher.Invoke(() => host.ShowToast(message, tone, actionLabel, onAction, autoHide));
            }
        }
    }
}
