import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_dimensions.dart';
import '../constants/app_typography.dart';

enum TrustBadgeType {
  vaultEnclave,
  biometricGuarded,
  synced,
  offline,
}

/// Subtle security badge reassuring multi-generational users of vault isolation and privacy
class TrustBadge extends StatelessWidget {
  final String? customText;
  final TrustBadgeType type;

  const TrustBadge({
    super.key,
    this.customText,
    this.type = TrustBadgeType.vaultEnclave,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color bg;
    Color fg;
    IconData icon;
    String text;

    switch (type) {
      case TrustBadgeType.vaultEnclave:
        bg = isDark ? AppColors.darkStatusGreenBg : AppColors.statusGreenBg;
        fg = isDark ? AppColors.darkStatusGreen : AppColors.statusGreen;
        icon = Icons.shield_outlined;
        text = customText ?? 'Vault Enclave • Local Only';
        break;
      case TrustBadgeType.biometricGuarded:
        bg = isDark ? AppColors.darkPrimaryContainer.withAlpha(60) : AppColors.primaryFixed.withAlpha(90);
        fg = isDark ? AppColors.darkPrimary : AppColors.primary;
        icon = Icons.fingerprint;
        text = customText ?? 'Biometric Guarded';
        break;
      case TrustBadgeType.synced:
        bg = isDark ? AppColors.darkSurfaceContainerHigh : AppColors.surfaceContainerHigh;
        fg = isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant;
        icon = Icons.sync_lock;
        text = customText ?? 'End-to-End Secured';
        break;
      case TrustBadgeType.offline:
        bg = isDark ? AppColors.darkStatusAmberBg : AppColors.statusAmberBg;
        fg = isDark ? AppColors.darkStatusAmber : AppColors.statusAmber;
        icon = Icons.cloud_off;
        text = customText ?? 'Offline Encrypted';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 5),
          Text(
            text,
            style: AppTypography.labelSm(color: fg),
          ),
        ],
      ),
    );
  }
}
