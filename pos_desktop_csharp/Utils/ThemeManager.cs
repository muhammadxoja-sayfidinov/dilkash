using System;
using System.Windows;

namespace DilkashPos.Utils
{
    public static class ThemeManager
    {
        private const string LightUri = "Resources/Theme/Tokens.Light.xaml";
        private const string DarkUri = "Resources/Theme/Tokens.Dark.xaml";

        public static bool IsDark { get; private set; }
        public static event EventHandler<bool>? ThemeChanged;

        public static void ApplyTheme(bool isDark)
        {
            if (Application.Current == null) return;

            var merged = Application.Current.Resources.MergedDictionaries;
            string targetUri = isDark ? DarkUri : LightUri;

            int themeIdx = -1;
            for (int i = 0; i < merged.Count; i++)
            {
                string src = merged[i].Source?.OriginalString ?? "";
                if (src.Contains("Tokens.Light.xaml", StringComparison.OrdinalIgnoreCase) ||
                    src.Contains("Tokens.Dark.xaml", StringComparison.OrdinalIgnoreCase))
                {
                    themeIdx = i;
                    break;
                }
            }

            var nextDict = new ResourceDictionary { Source = new Uri(targetUri, UriKind.Relative) };
            if (themeIdx >= 0)
            {
                merged[themeIdx] = nextDict;
            }
            else
            {
                merged.Insert(0, nextDict);
            }

            IsDark = isDark;
            ThemeChanged?.Invoke(null, isDark);
        }

        public static void Toggle()
        {
            ApplyTheme(!IsDark);
        }
    }
}
