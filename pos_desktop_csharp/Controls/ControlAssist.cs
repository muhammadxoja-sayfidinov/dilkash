using System.Windows;

namespace DilkashPos.Controls
{
    /// <summary>
    /// Attached state properties for consistent control states (loading, error, forced focus preview).
    /// </summary>
    public static class ControlAssist
    {
        public static readonly DependencyProperty IsLoadingProperty =
            DependencyProperty.RegisterAttached(
                "IsLoading",
                typeof(bool),
                typeof(ControlAssist),
                new FrameworkPropertyMetadata(false, FrameworkPropertyMetadataOptions.Inherits));

        public static bool GetIsLoading(DependencyObject obj) => (bool)obj.GetValue(IsLoadingProperty);
        public static void SetIsLoading(DependencyObject obj, bool value) => obj.SetValue(IsLoadingProperty, value);

        public static readonly DependencyProperty HasErrorProperty =
            DependencyProperty.RegisterAttached(
                "HasError",
                typeof(bool),
                typeof(ControlAssist),
                new FrameworkPropertyMetadata(false));

        public static bool GetHasError(DependencyObject obj) => (bool)obj.GetValue(HasErrorProperty);
        public static void SetHasError(DependencyObject obj, bool value) => obj.SetValue(HasErrorProperty, value);

        public static readonly DependencyProperty KeycapProperty =
            DependencyProperty.RegisterAttached(
                "Keycap",
                typeof(string),
                typeof(ControlAssist),
                new FrameworkPropertyMetadata(string.Empty));

        public static string GetKeycap(DependencyObject obj) => (string)obj.GetValue(KeycapProperty);
        public static void SetKeycap(DependencyObject obj, string value) => obj.SetValue(KeycapProperty, value);
    }
}
