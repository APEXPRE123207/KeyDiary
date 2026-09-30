import 'dart:async';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_dimensions.dart';
import '../constants/app_typography.dart';
import '../utils/clipboard_helper.dart';

/// Renders sensitive credentials (e.g. Account Number, Locker Key, Passcode)
/// in JetBrains Mono with tap-to-reveal, 10s auto-hide, and secure clipboard copying.
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
  Timer? _autoHideTimer;

  @override
  void initState() {
    super.initState();
    _isRevealed = widget.initialRevealed;
    if (_isRevealed) {
      _startAutoHideTimer();
    }
  }

  @override
  void dispose() {
    _autoHideTimer?.cancel();
    super.dispose();
  }

  void _startAutoHideTimer() {
    _autoHideTimer?.cancel();
    _autoHideTimer = Timer(const Duration(seconds: 10), () {
      if (mounted) {
        setState(() {
          _isRevealed = false;
        });
      }
    });
  }

  void _toggleReveal() {
    setState(() {
      _isRevealed = !_isRevealed;
      if (_isRevealed) {
        _startAutoHideTimer();
      } else {
        _autoHideTimer?.cancel();
      }
    });
  }

  String _getMaskedDisplay() {
    if (widget.rawValue.length <= 4) {
      return '••••';
    }
    final last4 = widget.rawValue.substring(widget.rawValue.length - 4);
    return '•••• $last4';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = AppColors.accent(isDark);
    final accentSoft = AppColors.accentSoft(isDark);

    return Container(
      padding: const EdgeInsets.all(AppDimensions.spaceMd),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceContainerLow : AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        border: Border.all(
          color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
          width: 1,
        ),
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
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: accentSoft,
                    borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                  ),
                  child: SelectableText(
                    _isRevealed ? widget.rawValue : _getMaskedDisplay(),
                    style: AppTypography.dataMono(
                      fontSize: 16,
                      color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppDimensions.spaceSm),
          // Reveal / Hide Toggle (accent colored)
          InkWell(
            onTap: _toggleReveal,
            borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
            child: Container(
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: accentSoft,
                borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                border: Border.all(
                  color: accent.withAlpha(80),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _isRevealed ? Icons.visibility_off : Icons.visibility,
                    size: 18,
                    color: accent,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _isRevealed ? 'Hide' : 'Reveal',
                    style: AppTypography.labelSm(color: accent),
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
                    borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
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

