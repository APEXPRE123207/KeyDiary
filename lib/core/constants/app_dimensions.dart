import 'package:flutter/material.dart';

/// KeyDiary Layout and Spacing Dimensions conforming to design.md
class AppDimensions {
  AppDimensions._();

  // Margins & Paddings
  static const double margin = 20.0;
  static const double marginTablet = 32.0;

  static const double spaceXs = 4.0;
  static const double spaceSm = 8.0;
  static const double spaceMd = 16.0;
  static const double spaceLg = 24.0;
  static const double spaceXl = 36.0;

  // Touch Boundaries (minimum 48px target per design.md)
  static const double minTouchTarget = 48.0;
  static const double buttonHeight = 52.0;
  static const double inputHeight = 52.0;

  // Corner Radii per design.md
  static const double radiusSm = 8.0;
  static const double radiusMd = 12.0;
  static const double radiusInput = 16.0; // Inputs: 16px radius
  static const double radiusCard = 20.0; // Cards: 20px radius
  static const double radiusLg = 20.0; // 20px radius
  static const double radiusXl = 24.0; // sheet top radius
  static const double radiusFull = 9999.0; // pill buttons / badges

  static const BorderRadius cardRadius = BorderRadius.all(Radius.circular(radiusCard));
  static const BorderRadius inputRadius = BorderRadius.all(Radius.circular(radiusInput));
  static const BorderRadius pillRadius = BorderRadius.all(Radius.circular(radiusFull));
  static const BorderRadius sheetRadius = BorderRadius.vertical(top: Radius.circular(radiusXl));
}
