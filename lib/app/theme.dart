import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/constants/app_colors.dart';
import '../core/constants/app_dimensions.dart';

/// KeyDiary Material 3 Themes (Calm Dawn & Midnight Vault per design.md)
class AppTheme {
  AppTheme._();

  static ThemeData get lightTheme {
    final colorScheme = const ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.primary, // #3F7D6E
      onPrimary: AppColors.onPrimary, // #FFFFFF
      primaryContainer: AppColors.primaryFixed, // #DCEBE5
      onPrimaryContainer: AppColors.onSurface, // #1F2D2A
      secondary: AppColors.secondary, // #5B6B66
      onSecondary: AppColors.onSecondary, // #FFFFFF
      secondaryContainer: AppColors.secondaryContainer, // #DCEBE5
      onSecondaryContainer: AppColors.onSecondaryContainer,
      surface: AppColors.surface, // #F7F4EC
      onSurface: AppColors.onSurface, // #1F2D2A
      surfaceContainerLowest: Color(0xFFFFFFFF),
      surfaceContainerLow: Color(0xFFF7F4EC),
      surfaceContainer: AppColors.cardFillLight, // rgba(255,255,255,0.72)
      surfaceContainerHigh: Color(0xFFDCEBE5),
      surfaceContainerHighest: Color(0xFFD9E8E2),
      onSurfaceVariant: AppColors.onSurfaceVariant, // #5B6B66
      outline: AppColors.outline, // #74847E
      outlineVariant: AppColors.cardBorderLight, // #E1E8E3
      error: AppColors.statusRose, // #C2574B
      onError: Colors.white,
    );

    return _buildTheme(colorScheme, isDark: false);
  }

  static ThemeData get darkTheme {
    final colorScheme = const ColorScheme(
      brightness: Brightness.dark,
      primary: AppColors.darkPrimary, // #7CCBB4
      onPrimary: AppColors.darkOnPrimary, // #0B1210
      primaryContainer: AppColors.darkPrimaryContainer, // rgba(124, 203, 180, 0.14)
      onPrimaryContainer: AppColors.darkPrimary,
      secondary: AppColors.darkSecondary, // #A3B5AE
      onSecondary: AppColors.darkOnSecondary,
      secondaryContainer: AppColors.darkSecondaryContainer,
      onSecondaryContainer: AppColors.darkOnSecondaryContainer,
      surface: AppColors.darkSurface, // #0B1210
      onSurface: AppColors.darkOnSurface, // #EAF2EE
      surfaceContainerLowest: Color(0xFF0B1210),
      surfaceContainerLow: Color(0xFF101B17),
      surfaceContainer: AppColors.cardFillDark, // rgba(255,255,255,0.05)
      surfaceContainerHigh: Color(0x247CCBB4),
      surfaceContainerHighest: Color(0xFF172520),
      onSurfaceVariant: AppColors.darkOnSurfaceVariant, // #A3B5AE
      outline: AppColors.darkOutline, // #7C8F88
      outlineVariant: AppColors.cardBorderDark, // rgba(255,255,255,0.08)
      error: AppColors.darkStatusRose, // #E58A7E
      onError: Colors.white,
    );

    return _buildTheme(colorScheme, isDark: true);
  }

  static ThemeData _buildTheme(ColorScheme colorScheme, {required bool isDark}) {
    final baseTextTheme = GoogleFonts.dmSansTextTheme(
      (isDark ? ThemeData.dark().textTheme : ThemeData.light().textTheme).apply(
        bodyColor: colorScheme.onSurface,
        displayColor: colorScheme.onSurface,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: colorScheme.brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
      textTheme: baseTextTheme,
      listTileTheme: ListTileThemeData(
        textColor: colorScheme.onSurface,
        iconColor: colorScheme.onSurfaceVariant,
        subtitleTextStyle: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 14),
        titleTextStyle: TextStyle(color: colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.w500),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: isDark ? AppColors.cardFillDark : AppColors.cardFillLight,
        selectedColor: isDark ? AppColors.darkPrimary : AppColors.primary,
        labelStyle: TextStyle(color: colorScheme.onSurface),
        secondaryLabelStyle: TextStyle(color: isDark ? AppColors.darkOnPrimary : AppColors.onPrimary),
        side: BorderSide(
          color: isDark ? AppColors.cardBorderDark : AppColors.cardBorderLight,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: isDark ? const Color(0xFF101B17) : const Color(0xFFFAF7F0),
        titleTextStyle: GoogleFonts.lora(
          color: colorScheme.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        contentTextStyle: TextStyle(
          color: colorScheme.onSurfaceVariant,
          fontSize: 15,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: isDark ? const Color(0xFF101B17) : const Color(0xFFFAF7F0),
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: colorScheme.onSurface),
        titleTextStyle: GoogleFonts.lora(
          color: colorScheme.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: isDark ? AppColors.cardFillDark : AppColors.cardFillLight,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
          side: BorderSide(
            color: isDark ? AppColors.cardBorderDark : AppColors.cardBorderLight,
            width: 1.0,
          ),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
        thickness: 1.0,
        space: 1.0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? AppColors.cardFillDark : AppColors.cardFillLight,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusInput), // 16px per design.md
          borderSide: BorderSide(
            color: isDark ? AppColors.cardBorderDark : AppColors.cardBorderLight,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusInput),
          borderSide: BorderSide(
            color: isDark ? AppColors.cardBorderDark : AppColors.cardBorderLight,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusInput),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
        ),
        hintStyle: TextStyle(
          color: isDark ? AppColors.darkOutline : AppColors.outline,
          fontSize: 15,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isDark ? const Color(0xFF101B17) : const Color(0xFFE6F0EB),
        indicatorColor: isDark ? AppColors.darkPrimaryContainer : AppColors.primaryFixed,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: isDark ? AppColors.darkPrimary : AppColors.primary);
          }
          return IconThemeData(color: isDark ? AppColors.darkOutline : AppColors.outline);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            color: isSelected
                ? (isDark ? AppColors.darkPrimary : AppColors.primary)
                : (isDark ? AppColors.darkOutline : AppColors.outline),
          );
        }),
      ),
    );
  }
}
