import 'package:intl/intl.dart';

/// Dilkash Restaurant Uzbek Localization & Text Formatters
class UzbekFormatters {
  UzbekFormatters._();

  static final NumberFormat _currencyFormatter = NumberFormat('#,###', 'uz_UZ');

  /// Formats currency into production Uzbek standard: "45 000 soʻm"
  static String formatCurrency(num amount) {
    final formatted = _currencyFormatter
        .format(amount)
        .replaceAll(',', ' ')
        .replaceAll('\u00A0', ' ');
    return '$formatted soʻm';
  }

  /// Formats raw phone number into: +998 (90) 123-45-67
  static String formatPhone(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return raw;

    String clean = digits;
    if (clean.startsWith('998') && clean.length >= 12) {
      clean = clean.substring(clean.length - 9);
    } else if (clean.length > 9) {
      clean = clean.substring(clean.length - 9);
    }

    if (clean.length == 9) {
      final code = clean.substring(0, 2);
      final p1 = clean.substring(2, 5);
      final p2 = clean.substring(5, 7);
      final p3 = clean.substring(7, 9);
      return '+998 ($code) $p1-$p2-$p3';
    }

    return raw;
  }

  /// Normalizes phone into standard format: +998901234567
  static String cleanPhone(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.length >= 9) {
      final last9 = digits.substring(digits.length - 9);
      return '+998$last9';
    }
    return raw;
  }

  /// Normalizes generic ASCII apostrophes and variants to correct Uzbek modifier turned comma (oʻ / gʻ)
  static String fixUzbekApostrophes(String text) {
    return text
        .replaceAll('’', 'ʻ')
        .replaceAll('ʼ', 'ʻ')
        .replaceAll("o'", "oʻ")
        .replaceAll("O'", "Oʻ")
        .replaceAll("g'", "gʻ")
        .replaceAll("G'", "Gʻ")
        .replaceAll("o`", "oʻ")
        .replaceAll("O`", "Oʻ")
        .replaceAll("g`", "gʻ")
        .replaceAll("G`", "Gʻ");
  }

  /// Formats distance in kilometers or meters
  static String formatDistance(double km) {
    if (km < 1.0) {
      final meters = (km * 1000).round();
      return '$meters m';
    }
    return '${km.toStringAsFixed(1)} km';
  }

  /// Formats delivery ETA duration
  static String formatEta(int minutes) {
    if (minutes <= 0) return 'Tez orada';
    return '$minutes daqiqa';
  }
}
