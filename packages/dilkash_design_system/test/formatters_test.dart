import 'package:flutter_test/flutter_test.dart';
import 'package:dilkash_design_system/dilkash_design_system.dart';

void main() {
  group('UzbekFormatters Tests', () {
    test('formatCurrency should output uz_UZ format with soʻm', () {
      expect(UzbekFormatters.formatCurrency(45000), '45 000 soʻm');
      expect(UzbekFormatters.formatCurrency(1200000), '1 200 000 soʻm');
      expect(UzbekFormatters.formatCurrency(0), '0 soʻm');
    });

    test('formatPhone should format 9 digits correctly', () {
      expect(UzbekFormatters.formatPhone('+998901234567'), '+998 (90) 123-45-67');
      expect(UzbekFormatters.formatPhone('901234567'), '+998 (90) 123-45-67');
    });

    test('cleanPhone should normalize phone into E.164 without spaces', () {
      expect(UzbekFormatters.cleanPhone('+998 (90) 123-45-67'), '+998901234567');
    });

    test('fixUzbekApostrophes should convert ASCII quotes into correct modifier turned comma', () {
      expect(UzbekFormatters.fixUzbekApostrophes("Go'shtli to'y oshi"), "Goʻshtli toʻy oshi");
      expect(UzbekFormatters.fixUzbekApostrophes("G'ijduvon shashlik"), "Gʻijduvon shashlik");
    });

    test('formatDistance should format meters and km appropriately', () {
      expect(UzbekFormatters.formatDistance(0.45), '450 m');
      expect(UzbekFormatters.formatDistance(2.34), '2.3 km');
    });
  });

  group('DilkashColors Tokens Tests', () {
    test('brand colors are correctly configured', () {
      expect(DilkashColors.primary500.toARGB32(), 0xFF0D6B4E);
      expect(DilkashColors.primary(true).toARGB32(), DilkashColors.primary400.toARGB32());
      expect(DilkashColors.primary(false).toARGB32(), DilkashColors.primary500.toARGB32());
    });
  });
}
