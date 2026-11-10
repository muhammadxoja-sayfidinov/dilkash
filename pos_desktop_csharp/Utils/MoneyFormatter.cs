using System;
using System.Globalization;

namespace DilkashPos.Utils
{
    public static class MoneyFormatter
    {
        private const char NonBreakingSpace = '\u00A0';
        private const string SomSuffix = "\u00A0so\u02BBm";

        private static readonly NumberFormatInfo Nfi = new()
        {
            NumberGroupSeparator = "\u00A0",
            NumberDecimalDigits = 0
        };

        public static string Format(decimal amount)
        {
            return $"{amount.ToString("N0", Nfi)}{SomSuffix}";
        }

        public static string Format(long amount)
        {
            return $"{amount.ToString("N0", Nfi)}{SomSuffix}";
        }

        public static string FormatNumberOnly(decimal amount)
        {
            return amount.ToString("N0", Nfi);
        }

        public static string FormatWithSign(decimal amount)
        {
            if (amount < 0)
            {
                return $"-{Math.Abs(amount).ToString("N0", Nfi)}{SomSuffix}";
            }
            if (amount > 0)
            {
                return $"+{amount.ToString("N0", Nfi)}{SomSuffix}";
            }
            return $"0{SomSuffix}";
        }

        public static string FormatDiscount(decimal amount)
        {
            if (amount <= 0) return $"0{SomSuffix}";
            return $"-{amount.ToString("N0", Nfi)}{SomSuffix}";
        }
    }
}

