import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_dimensions.dart';

/// Tactile L1 Card Surface with linen borders and subtle primary-tinted ambient shadow
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
        (isDark
            ? AppColors.darkSurfaceContainerLowest
            : AppColors.surfaceContainerLowest);
    final borderColor = border ??
        BorderSide(
          color: isDark ? AppColors.darkOutlineVariant : AppColors.outlineVariant,
          width: 1.0,
        );

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        border: Border.fromBorderSide(borderColor),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: AppColors.primaryContainer.withAlpha(10),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
                BoxShadow(
                  color: Colors.black.withAlpha(5),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
          child: Padding(
            padding: padding,
            child: child,
          ),
        ),
      ),
    );
  }
}
