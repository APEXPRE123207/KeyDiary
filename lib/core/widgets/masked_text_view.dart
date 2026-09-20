import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_dimensions.dart';
import '../constants/app_typography.dart';
import '../utils/clipboard_helper.dart';

/// Renders sensitive credentials (e.g. Account Number, Locker Key, Passcode)
/// in JetBrains Mono with tap-to-reveal and secure clipboard copying.
class MaskedTextView extends StatefulWidget {
  final String rawValue;
  final String label;
  final bool initialRevealed;

  const MaskedTextView({
    super.key,
    required this.rawValue,
    required this.label,
    this.initialRevealed = false,
  });

  @override
  State<MaskedTextView> createState() => _MaskedTextViewState();
}

class _MaskedTextViewState extends State<MaskedTextView> {
  late bool _isRevealed;

  @override
  void initState() {
    super.initState();
    _isRevealed = widget.initialRevealed;
  }

  String _getMaskedDisplay() {
    if (widget.rawValue.length <= 4) {
      return '••••';
    }
    final last4 = widget.rawValue.substring(widget.rawValue.length - 4);
    return '•••• •••• $last4';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pillBg = isDark ? AppColors.darkPrimaryContainer.withAlpha(60) : AppColors.primaryFixed.withAlpha(90);
    final pillFg = isDark ? AppColors.darkPrimary : AppColors.primary;

    return Container(
      padding: const EdgeInsets.all(AppDimensions.spaceMd),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceContainerLow : AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.label.toUpperCase(),
                  style: AppTypography.labelSm(
                    color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppDimensions.spaceXs),
                SelectableText(
                  _isRevealed ? widget.rawValue : _getMaskedDisplay(),
                  style: AppTypography.dataMono(
                    fontSize: 16,
                    color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppDimensions.spaceSm),
          // Reveal / Hide Toggle
          InkWell(
            onTap: () => setState(() => _isRevealed = !_isRevealed),
            borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
            child: Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: pillBg,
                borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _isRevealed ? Icons.visibility_off : Icons.visibility,
                    size: 17,
                    color: pillFg,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    _isRevealed ? 'Hide' : 'Reveal',
                    style: AppTypography.labelSm(color: pillFg),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: AppDimensions.spaceXs),
          // Copy to Clipboard
          IconButton(
            icon: const Icon(Icons.copy, size: 18),
            color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
            tooltip: 'Copy to clipboard',
            onPressed: () {
              ClipboardHelper.copySensitive(widget.rawValue);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Copied securely. Clipboard will clear in 30s.'),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
