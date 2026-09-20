import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_dimensions.dart';
import '../constants/app_typography.dart';

enum AppButtonVariant { primary, secondary, ghost, danger }

/// High-quality button conforming to KeyDiary Tactile Warm Modernism specifications
class AppButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final IconData? leadingIcon;
  final IconData? trailingIcon;
  final bool isLoading;
  final double? width;
  final double height;

  const AppButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.leadingIcon,
    this.trailingIcon,
    this.isLoading = false,
    this.width,
    this.height = AppDimensions.buttonHeight,
  });

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color bg;
    Color fg;
    BorderSide border = BorderSide.none;

    switch (widget.variant) {
      case AppButtonVariant.primary:
        bg = isDark ? AppColors.darkPrimaryContainer : AppColors.primaryContainer;
        fg = isDark ? AppColors.darkOnPrimaryContainer : AppColors.onPrimary;
        break;
      case AppButtonVariant.secondary:
        bg = isDark ? AppColors.darkSurfaceContainerLowest : AppColors.surfaceContainerLowest;
        fg = isDark ? AppColors.darkOnSurface : AppColors.primary;
        border = BorderSide(
          color: isDark ? AppColors.darkOutlineVariant : AppColors.outlineVariant,
          width: 1.0,
        );
        break;
      case AppButtonVariant.ghost:
        bg = Colors.transparent;
        fg = isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant;
        break;
      case AppButtonVariant.danger:
        bg = isDark ? AppColors.darkStatusRoseBg : AppColors.statusRoseBg;
        fg = isDark ? AppColors.darkStatusRose : AppColors.statusRose;
        break;
    }

    return AnimatedScale(
      scale: _isPressed ? 0.98 : 1.0,
      duration: const Duration(milliseconds: 100),
      curve: Curves.easeInOut,
      child: SizedBox(
        width: widget.width,
        height: widget.height,
        child: Material(
          color: widget.onPressed == null ? bg.withAlpha(120) : bg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
            side: border,
          ),
          child: InkWell(
            onTap: widget.isLoading ? null : widget.onPressed,
            onHighlightChanged: (val) => setState(() => _isPressed = val),
            borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppDimensions.spaceMd),
              child: widget.isLoading
                  ? Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          valueColor: AlwaysStoppedAnimation<Color>(fg),
                        ),
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: widget.width == null ? MainAxisSize.min : MainAxisSize.max,
                      children: [
                        if (widget.leadingIcon != null) ...[
                          Icon(widget.leadingIcon, size: 20, color: fg),
                          const SizedBox(width: AppDimensions.spaceSm),
                        ],
                        Text(
                          widget.text,
                          style: AppTypography.labelLg(color: fg),
                        ),
                        if (widget.trailingIcon != null) ...[
                          const SizedBox(width: AppDimensions.spaceSm),
                          Icon(widget.trailingIcon, size: 20, color: fg),
                        ],
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

