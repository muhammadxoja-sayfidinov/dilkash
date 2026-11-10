using System;
using System.Linq;
using System.Windows;
using System.Windows.Media;

namespace DilkashPos.Utils
{
    public static class FontHelper
    {
        private const int UzbekTurnedCommaCodePoint = 0x02BB; // ʻ

        public static string VerifyBundledFontGlyphs()
        {
            try
            {
                var uri = new Uri("pack://application:,,,/Resources/Fonts/", UriKind.Absolute);
                var families = Fonts.GetFontFamilies(uri).ToList();
                var interFamily = families.FirstOrDefault();

                if (interFamily == null)
                {
                    FallbackToSegoe("Bundled Inter font not found in pack://application:,,,/Resources/Fonts/.");
                    return "Fallback: Segoe UI Variable (Inter not found)";
                }

                var typeface = new Typeface(interFamily, FontStyles.Normal, FontWeights.Regular, FontStretches.Normal);
                if (typeface.TryGetGlyphTypeface(out var glyphTypeface))
                {
                    if (glyphTypeface.CharacterToGlyphMap.ContainsKey(UzbekTurnedCommaCodePoint))
                    {
                        Console.WriteLine($"[FontHelper] Bundled font '{interFamily.Source}' verified for U+02BB (ʻ).");
                        return $"Verified: {interFamily.Source} (U+02BB supported)";
                    }
                    else
                    {
                        // Inter v4 supports U+02BB, but if a font doesn't map it cleanly, fall back
                        FallbackToSegoe($"Bundled font '{interFamily.Source}' does not map U+02BB (ʻ).");
                        return "Fallback: Segoe UI Variable (Missing U+02BB)";
                    }
                }
            }
            catch (Exception ex)
            {
                FallbackToSegoe($"Font inspection failed: {ex.Message}");
                return $"Fallback: Segoe UI Variable ({ex.Message})";
            }

            return "Verified: Inter";
        }

        private static void FallbackToSegoe(string reason)
        {
            Console.WriteLine($"[FontHelper] WARNING: {reason} Switching FontFamilyBase to Segoe UI Variable, Segoe UI.");
            if (Application.Current != null && Application.Current.Resources.Contains("FontFamilyBase"))
            {
                Application.Current.Resources["FontFamilyBase"] = new FontFamily("Segoe UI Variable, Segoe UI");
            }
        }
    }
}
