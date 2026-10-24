import 'package:flutter/material.dart';
import 'package:dilkash_design_system/dilkash_design_system.dart';

export 'package:dilkash_design_system/dilkash_design_system.dart';

typedef AppColors = DilkashColors;

class AppTheme {
  AppTheme._();

  static ThemeData get lightTheme => DilkashTheme.lightTheme;
  static ThemeData get darkTheme => DilkashTheme.darkTheme;
}
