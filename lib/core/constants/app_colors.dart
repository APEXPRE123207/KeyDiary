import 'package:flutter/material.dart';

/// KeyDiary Design System Color Palette (Calm Dawn & Midnight Vault)
/// Defined in design.md: Sage-teal accent with warm ivory paper and deep forest-black vault.
class AppColors {
  AppColors._();

  // --- Gradients (160deg approx alignment) ---
  static const LinearGradient lightBgGradient = LinearGradient(
    begin: Alignment(-0.6, -1.0),
    end: Alignment(0.6, 1.0),
    colors: [
      Color(0xFFF7F4EC), // Warm ivory (paper)
      Color(0xFFE6F0EB), // Soft sage mist
      Color(0xFFD9E8E2), // Calm dawn base
    ],
    stops: [0.0, 0.55, 1.0],
  );

  static const LinearGradient darkBgGradient = LinearGradient(
    begin: Alignment(-0.6, -1.0),
    end: Alignment(0.6, 1.0),
    colors: [
      Color(0xFF0B1210), // Deep forest-black
      Color(0xFF101B17), // Midnight vault mid
      Color(0xFF172520), // Forest night base
    ],
    stops: [0.0, 0.55, 1.0],
  );

  static LinearGradient bgGradient(bool isDark) =>
      isDark ? darkBgGradient : lightBgGradient;

  // --- Theme 1: Calm Dawn (Light) ---
  static const Color surface = Color(0xFFF7F4EC);
  static const Color surfaceBright = Color(0xFFFBF9F5);
  static const Color surfaceDim = Color(0xFFD9E8E2);
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color surfaceContainerLow = Color(0xFFF0F5F0);
  static const Color surfaceContainer = Color(0xFFFFFFFF); // Solid white opaque
  static const Color surfaceContainerHigh = Color(0xFFDCEBE5);
  static const Color surfaceContainerHighest = Color(0xFFD9E8E2);

  static const Color cardFillLight = Color(0xB8FFFFFF); // 0.72 frosted white
  static const Color cardBorderLight = Color(0xFFE1E8E3); // 1px hairline
  static const Color dividerLight = Color(0xFFDDE6E0);

  static const Color onSurface = Color(0xFF1F2D2A); // Text primary
  static const Color onSurfaceVariant = Color(0xFF5B6B66); // Text secondary
  static const Color outline = Color(0xFF74847E); // Text muted
  static const Color outlineVariant = Color(0xFFE1E8E3); // Card border

  static const Color primary = Color(0xFF3F7D6E); // Accent (Sage-teal)
  static const Color onPrimary = Color(0xFFFFFFFF); // Text on accent
  static const Color primaryContainer = Color(0xFF3F7D6E);
  static const Color onPrimaryContainer = Color(0xFFFFFFFF);
  static const Color primaryFixed = Color(0xFFDCEBE5); // Accent soft
  static const Color primaryFixedDim = Color(0xFFC5DFD6);

  static const Color secondary = Color(0xFF5B6B66);
  static const Color onSecondary = Color(0xFFFFFFFF);
  static const Color secondaryContainer = Color(0xFFDCEBE5);
  static const Color onSecondaryContainer = Color(0xFF1F2D2A);
  static const Color secondaryFixed = Color(0xFFDCEBE5);
  static const Color secondaryFixedDim = Color(0xFFC5DFD6);

  // Status & Semantic Colors
  static const Color statusGreen = Color(0xFF2E7D32);
  static const Color statusGreenBg = Color(0xFFEAF5EA);
  static const Color statusAmber = Color(0xFFB45309);
  static const Color statusAmberBg = Color(0xFFFEF3C7);
  static const Color statusRose = Color(0xFFC2574B); // Danger
  static const Color statusRoseBg = Color(0xFFFDE8E5);

  // --- Theme 2: Midnight Vault (Dark) ---
  static const Color darkSurface = Color(0xFF0B1210); // Deep forest-black
  static const Color darkSurfaceBright = Color(0xFF172520);
  static const Color darkSurfaceContainerLowest = Color(0xFF101B17);
  static const Color darkSurfaceContainerLow = Color(0xFF14201C);
  static const Color darkSurfaceContainer = Color(0xFF16231F); // Solid dark opaque container
  static const Color darkSurfaceContainerHigh = Color(0x247CCBB4); // Accent soft
  static const Color darkSurfaceContainerHighest = Color(0xFF1F2E28);

  static const Color cardFillDark = Color(0x0DFFFFFF); // 0.05 glass
  static const Color cardBorderDark = Color(0x14FFFFFF); // 0.08 hairline
  static const Color dividerDark = Color(0x17FFFFFF); // 0.09 divider

  static const Color darkOnSurface = Color(0xFFEAF2EE); // Soft off-white
  static const Color darkOnSurfaceVariant = Color(0xFFA3B5AE); // Text secondary
  static const Color darkOutline = Color(0xFF7C8F88); // Text muted
  static const Color darkOutlineVariant = Color(0x14FFFFFF); // Card border

  static const Color darkPrimary = Color(0xFF7CCBB4); // Dark accent
  static const Color darkOnPrimary = Color(0xFF0B1210); // Text on accent
  static const Color darkPrimaryContainer = Color(0x247CCBB4); // rgba(124, 203, 180, 0.14)
  static const Color darkOnPrimaryContainer = Color(0xFF7CCBB4);

  static const Color darkSecondary = Color(0xFFA3B5AE);
  static const Color darkOnSecondary = Color(0xFF0B1210);
  static const Color darkSecondaryContainer = Color(0x247CCBB4);
  static const Color darkOnSecondaryContainer = Color(0xFFEAF2EE);

  static const Color darkStatusGreen = Color(0xFF81C784);
  static const Color darkStatusGreenBg = Color(0xFF1B3821);
  static const Color darkStatusAmber = Color(0xFFFBBF24);
  static const Color darkStatusAmberBg = Color(0xFF382910);
  static const Color darkStatusRose = Color(0xFFE58A7E); // Softer red
  static const Color darkStatusRoseBg = Color(0xFF3B1818);

  // Dynamic Contrast Helpers (Calm Dawn & Midnight Vault)
  static Color textPrimary(bool isDark) => isDark ? darkOnSurface : onSurface;
  static Color textSecondary(bool isDark) => isDark ? darkOnSurfaceVariant : onSurfaceVariant;
  static Color textMuted(bool isDark) => isDark ? darkOutline : outline;
  static Color textOnAccent(bool isDark) => isDark ? darkOnPrimary : onPrimary;

  // Convenience Helpers
  static Color accent(bool isDark) => isDark ? darkPrimary : primary;
  static Color accentSoft(bool isDark) => isDark ? darkPrimaryContainer : primaryFixed;
  static Color cardBorder(bool isDark) => isDark ? cardBorderDark : cardBorderLight;
  static Color cardFill(bool isDark) => isDark ? cardFillDark : cardFillLight;
  static const Color darkCardBorder = cardBorderDark;
  static const Color lightCardBorder = cardBorderLight;
  static const Color darkBackground = darkSurface;
  static const Color lightBackground = surface;

  // Lock screen glow
  static const Color lockScreenGlow = Color(0x2E7CCBB4); // rgba(124, 203, 180, 0.18)
}
