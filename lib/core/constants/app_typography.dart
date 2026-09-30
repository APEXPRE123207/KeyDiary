import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// KeyDiary Typography conforming to design.md:
/// - Soft serif (Lora) for warm diary feelings on greetings and screen titles.
/// - Clean sans (DM Sans) for UI, controls, and body text.
/// - JetBrains Mono for masked sensitive codes, keys, and numbers.
/// - Adaptive contrast for Calm Dawn (Light) and Midnight Vault (Dark).
class AppTypography {
  AppTypography._();

  static Color primaryColor(BuildContext context) =>
      AppColors.textPrimary(Theme.of(context).brightness == Brightness.dark);

  static Color secondaryColor(BuildContext context) =>
      AppColors.textSecondary(Theme.of(context).brightness == Brightness.dark);

  static Color mutedColor(BuildContext context) =>
      AppColors.textMuted(Theme.of(context).brightness == Brightness.dark);

  /// Soft serif title for greetings and screen titles (design.md)
  static TextStyle diaryTitle({
    BuildContext? context,
    Color? color,
    double fontSize = 26,
    FontWeight fontWeight = FontWeight.w600,
  }) {
    final effectiveColor = color ?? (context != null ? primaryColor(context) : null);
    return GoogleFonts.lora(
      fontSize: fontSize,
      fontWeight: fontWeight,
      height: 1.25,
      color: effectiveColor,
    );
  }

  static TextStyle headlineLg({BuildContext? context, Color? color}) {
    final effectiveColor = color ?? (context != null ? primaryColor(context) : null);
    return GoogleFonts.lora(
      fontSize: 26,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.015,
      height: 1.28,
      color: effectiveColor,
    );
  }

  static TextStyle headlineMd({BuildContext? context, Color? color}) {
    final effectiveColor = color ?? (context != null ? primaryColor(context) : null);
    return GoogleFonts.lora(
      fontSize: 22,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.01,
      height: 1.32,
      color: effectiveColor,
    );
  }

  static TextStyle headlineSm({BuildContext? context, Color? color}) {
    final effectiveColor = color ?? (context != null ? primaryColor(context) : null);
    return GoogleFonts.dmSans(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      height: 1.4,
      color: effectiveColor,
    );
  }

  static TextStyle bodyLg({BuildContext? context, Color? color}) {
    final effectiveColor = color ?? (context != null ? primaryColor(context) : null);
    return GoogleFonts.dmSans(
      fontSize: 17,
      fontWeight: FontWeight.w400,
      height: 1.5,
      color: effectiveColor,
    );
  }

  /// Standard body text: 16px per design.md ("Keep body text at 16px or larger")
  static TextStyle bodyMd({BuildContext? context, Color? color}) {
    final effectiveColor = color ?? (context != null ? primaryColor(context) : null);
    return GoogleFonts.dmSans(
      fontSize: 16,
      fontWeight: FontWeight.w400,
      height: 1.5,
      color: effectiveColor,
    );
  }

  static TextStyle bodySm({BuildContext? context, Color? color}) {
    final effectiveColor = color ?? (context != null ? secondaryColor(context) : null);
    return GoogleFonts.dmSans(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      height: 1.45,
      color: effectiveColor,
    );
  }

  /// Entry names: 16-18px, weight 500 per design.md
  static TextStyle labelLg({BuildContext? context, Color? color}) {
    final effectiveColor = color ?? (context != null ? primaryColor(context) : null);
    return GoogleFonts.dmSans(
      fontSize: 16,
      fontWeight: FontWeight.w500,
      height: 1.35,
      color: effectiveColor,
    );
  }

  static TextStyle labelMd({BuildContext? context, Color? color}) {
    final effectiveColor = color ?? (context != null ? primaryColor(context) : null);
    return GoogleFonts.dmSans(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.01,
      height: 1.38,
      color: effectiveColor,
    );
  }

  static TextStyle labelSm({BuildContext? context, Color? color}) {
    final effectiveColor = color ?? (context != null ? secondaryColor(context) : null);
    return GoogleFonts.dmSans(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.02,
      height: 1.45,
      color: effectiveColor,
    );
  }

  /// JetBrains Mono for numeric codes, masked accounts, and recovery keys
  static TextStyle dataMono({
    BuildContext? context,
    Color? color,
    double fontSize = 15,
    FontWeight fontWeight = FontWeight.w500,
    double letterSpacing = 0.05,
  }) {
    final effectiveColor = color ?? (context != null ? primaryColor(context) : null);
    return GoogleFonts.jetBrainsMono(
      fontSize: fontSize,
      fontWeight: fontWeight,
      letterSpacing: letterSpacing,
      color: effectiveColor,
    );
  }
}
