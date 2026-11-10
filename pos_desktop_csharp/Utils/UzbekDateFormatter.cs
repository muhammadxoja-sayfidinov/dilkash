using System;

namespace DilkashPos.Utils
{
    public static class UzbekDateFormatter
    {
        private static readonly string[] Months =
        {
            "yanvar", "fevral", "mart", "aprel", "may", "iyun",
            "iyul", "avgust", "sentabr", "oktabr", "noyabr", "dekabr"
        };

        private static readonly string[] Weekdays =
        {
            "yakshanba", "dushanba", "seshanba", "chorshanba",
            "payshanba", "juma", "shanba"
        };

        public static string FormatTime24(DateTime dt) => dt.ToString("HH:mm");

        public static string FormatDate(DateTime dt)
        {
            string month = Months[dt.Month - 1];
            string weekday = Weekdays[(int)dt.DayOfWeek];
            return $"{dt.Day}-{month}, {weekday}";
        }

        public static string FormatDuration(TimeSpan elapsed)
        {
            if (elapsed.TotalMinutes < 0) elapsed = TimeSpan.Zero;
            int hours = (int)elapsed.TotalHours;
            int mins = elapsed.Minutes;
            return $"{hours:D2}:{mins:D2}";
        }
    }
}
