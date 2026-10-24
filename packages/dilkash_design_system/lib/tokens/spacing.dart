import 'package:flutter/material.dart';

/// Dilkash Restaurant Spacing Grid (Strict 4/8pt Grid)
class DilkashSpacing {
  DilkashSpacing._();

  static const double xxs = 2.0;
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 20.0;
  static const double xxl = 24.0;
  static const double xxxl = 32.0;
  static const double huge = 40.0;

  // Standard EdgeInsets Helpers
  static const EdgeInsets page = EdgeInsets.symmetric(horizontal: lg, vertical: lg);
  static const EdgeInsets screenHorizontal = EdgeInsets.symmetric(horizontal: lg);
  static const EdgeInsets card = EdgeInsets.all(lg);
  static const EdgeInsets cardDense = EdgeInsets.all(md);
  static const EdgeInsets modal = EdgeInsets.fromLTRB(xl, md, xl, xxl);
  static const EdgeInsets button = EdgeInsets.symmetric(horizontal: xl, vertical: md);
  static const EdgeInsets chip = EdgeInsets.symmetric(horizontal: md, vertical: sm);
  static const EdgeInsets input = EdgeInsets.symmetric(horizontal: lg, vertical: 14.0);
}
