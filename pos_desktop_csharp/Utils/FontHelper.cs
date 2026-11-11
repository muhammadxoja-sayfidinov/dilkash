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
            string primaryFont = "Segoe UI Variable / Segoe UI";
            try
            {
                var uri = new Uri("pack://application:,,,/Resources/Fonts/", UriKind.Absolute);
                var families = Fonts.GetFontFamilies(uri).ToList();
                var interFamily = families.FirstOrDefault();

                if (interFamily != null)
                {
                    var typeface = new Typeface(interFamily, FontStyles.Normal, FontWeights.Regular, FontStretches.Normal);
                    if (typeface.TryGetGlyphTypeface(out var glyphTypeface) &&
                        glyphTypeface.CharacterToGlyphMap.ContainsKey(UzbekTurnedCommaCodePoint))
                    {
                        return $"{primaryFont} (ClearType Display · U+02BB + Inter fallback tayyor)";
                    }
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[FontHelper] Note: {ex.Message}");
            }

            return $"{primaryFont} (ClearType Display)";
        }
    }
}
