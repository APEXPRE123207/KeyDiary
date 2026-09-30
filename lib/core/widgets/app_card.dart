import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_dimensions.dart';

/// Card Surface conforming to design.md:
/// - Light: frosted white rgba(255,255,255,0.72) with 1px hairline #E1E8E3 and soft shadow.
/// - Dark: barely-there glass rgba(255,255,255,0.05) with 1px hairline rgba(255,255,255,0.08) and no shadow.
/// - 20px corner radius.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final BorderSide? border;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppDimensions.spaceMd),
    this.onTap,
    this.color,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = color ??
        (isDark ? AppColors.cardFillDark : AppColors.cardFillLight);
    final borderColor = border ??
        BorderSide(
          color: isDark ? AppColors.cardBorderDark : AppColors.cardBorderLight,
          width: 1.0,
        );

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        border: Border.fromBorderSide(borderColor),
        boxShadow: isDark
            ? null
            : const [
                BoxShadow(
                  color: Color(0x0F1F2D2A), // 0 8px 24px rgba(31, 45, 42, 0.06)
                  blurRadius: 24,
                  offset: Offset(0, 8),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
          child: Padding(
            padding: padding,
            child: child,
          ),
        ),
      ),
    );
  }
}
