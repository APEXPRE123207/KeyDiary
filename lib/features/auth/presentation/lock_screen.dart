import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/providers.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/security/biometric_service.dart';
import '../../../core/security/pin_service.dart';
import '../../../core/security/secure_storage_service.dart';
import '../../../core/security/encryption_service.dart';
import '../../../core/widgets/trust_badge.dart';

class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> with SingleTickerProviderStateMixin {
  String _enteredPin = '';
  String? _errorMessage;
  Timer? _lockoutTimer;
  int _remainingLockout = 0;
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _shakeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_shakeController);
    _checkLockout();
    _tryBiometricUnlock();
  }

  @override
  void dispose() {
    _shakeController.dispose();
    _lockoutTimer?.cancel();
    super.dispose();
  }

  void _checkLockout() {
    if (PinService.isLockedOut()) {
      setState(() {
        _remainingLockout = PinService.remainingLockoutSeconds();
        _errorMessage = 'Too many attempts. Wait $_remainingLockout seconds.';
      });
      _startLockoutCountdown();
    }
  }

  void _startLockoutCountdown() {
    _lockoutTimer?.cancel();
    _lockoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      final remaining = PinService.remainingLockoutSeconds();
      setState(() {
        _remainingLockout = remaining;
        if (remaining <= 0) {
          _errorMessage = null;
          timer.cancel();
        } else {
          _errorMessage = 'Too many attempts. Wait $remaining seconds.';
        }
      });
    });
  }

  Future<void> _tryBiometricUnlock() async {
    final enabled = await SecureStorageService.isBiometricsEnabled();
    if (!enabled) return;

    final authenticated = await BiometricService.authenticate(
      reason: 'Authenticate to unlock KeyDiary Vault',
    );
    if (authenticated && mounted) {
      await _unlockVault();
    }
  }

  Future<void> _handleDigitPress(String digit) async {
    if (PinService.isLockedOut()) return;
    if (_enteredPin.length >= 6) return;

    setState(() {
      _enteredPin += digit;
      _errorMessage = null;
    });

    if (_enteredPin.length == 6) {
      await _verifyPin();
    }
  }

  void _handleBackspace() {
    if (_enteredPin.isNotEmpty) {
      setState(() {
        _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
        _errorMessage = null;
      });
    }
  }

  Future<void> _verifyPin() async {
    final storedHash = await SecureStorageService.getPinHash();

    if (storedHash == null) {
      // No PIN set yet, direct to setup
      if (mounted) context.go('/security-setup');
      return;
    }

    final isValid = await PinService.verifyPin(_enteredPin, storedHash);

    if (!mounted) return;

    if (isValid) {
      await _unlockVault();
    } else {
      _shakeController.forward(from: 0.0);
      setState(() {
        _enteredPin = '';
        if (PinService.isLockedOut()) {
          _remainingLockout = PinService.remainingLockoutSeconds();
          _errorMessage = 'Too many attempts. Wait $_remainingLockout seconds.';
          _startLockoutCountdown();
        } else {
          _errorMessage = 'Incorrect PIN. Please try again.';
        }
      });
    }
  }

  Future<void> _unlockVault() async {
    // Retrieve or provision Vault Encryption Key (VEK)
    final activeVaultId = await SecureStorageService.getActiveVaultId() ?? 'primary-vault';
    var vek = await SecureStorageService.getVaultKey(activeVaultId);
    if (vek == null) {
      vek = await EncryptionService.generateRandomKey();
      await SecureStorageService.saveVaultKey(activeVaultId, vek);
    }
    ref.read(vaultKeyProvider.notifier).state = vek;

    if (mounted) {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppDimensions.margin),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Top Trust Badge
              Padding(
                padding: const EdgeInsets.only(top: AppDimensions.spaceMd),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const TrustBadge(
                      type: TrustBadgeType.vaultEnclave,
                      customText: 'Local Enclave',
                    ),
                    Icon(
                      Icons.shield_outlined,
                      size: 20,
                      color: isDark ? AppColors.darkPrimary : AppColors.primary,
                    ),
                  ],
                ),
              ),

              // Title and PIN indicator
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
                    child: Image.asset(
                      'assets/images/app_logo.png',
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkPrimaryContainer : AppColors.primaryFixed,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.lock_outline,
                          size: 32,
                          color: isDark ? AppColors.darkOnPrimaryContainer : AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppDimensions.spaceMd),
                  Text(
                    'KeyDiary',
                    style: AppTypography.headlineMd(
                      color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                    ),
                  ),
                  const SizedBox(height: AppDimensions.spaceXs),
                  Text(
                    'Enter 6-digit Master PIN or use Biometrics',
                    textAlign: TextAlign.center,
                    style: AppTypography.bodySm(
                      color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppDimensions.spaceLg),

                  // 6-Dot PIN Indicator with subtle shake on error
                  AnimatedBuilder(
                    animation: _shakeAnimation,
                    builder: (context, child) {
                      final offset = _shakeAnimation.value > 0.0
                          ? 10.0 * (1.0 - _shakeAnimation.value) * (
                              _shakeAnimation.value * 12 % 2 == 0 ? 1 : -1
                            )
                          : 0.0;
                      return Transform.translate(
                        offset: Offset(offset, 0),
                        child: child,
                      );
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(6, (index) {
                        final isFilled = index < _enteredPin.length;
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 6),
                          width: 15,
                          height: 15,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isFilled
                                ? (isDark ? AppColors.darkPrimary : AppColors.primary)
                                : Colors.transparent,
                            border: Border.all(
                              color: isDark ? AppColors.darkOutline : AppColors.outlineVariant,
                              width: 2.0,
                            ),
                          ),
                        );
                      }),
                    ),
                  ),

                  // Error Message
                  if (_errorMessage != null) ...[
                    const SizedBox(height: AppDimensions.spaceMd),
                    Text(
                      _errorMessage!,
                      style: AppTypography.labelSm(
                        color: isDark ? AppColors.darkStatusRose : AppColors.statusRose,
                      ),
                    ),
                  ],
                ],
              ),

              // Tactile Keypad (1-9, Biometric, 0, Backspace)
              Padding(
                padding: const EdgeInsets.only(bottom: AppDimensions.spaceMd),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildKeypadRow(['1', '2', '3']),
                    const SizedBox(height: 12),
                    _buildKeypadRow(['4', '5', '6']),
                    const SizedBox(height: 12),
                    _buildKeypadRow(['7', '8', '9']),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Biometric prompt trigger
                        _buildKeypadButton(
                          child: Icon(
                            Icons.fingerprint,
                            size: 28,
                            color: isDark ? AppColors.darkPrimary : AppColors.primary,
                          ),
                          onTap: _tryBiometricUnlock,
                        ),
                        _buildDigitButton('0'),
                        _buildKeypadButton(
                          child: Icon(
                            Icons.backspace_outlined,
                            size: 24,
                            color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
                          ),
                          onTap: _handleBackspace,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKeypadRow(List<String> digits) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: digits.map((d) => _buildDigitButton(d)).toList(),
    );
  }

  Widget _buildDigitButton(String digit) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return _buildKeypadButton(
      child: Text(
        digit,
        style: AppTypography.headlineSm(
          color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
        ).copyWith(fontSize: 24),
      ),
      onTap: () => _handleDigitPress(digit),
    );
  }

  Widget _buildKeypadButton({required Widget child, required VoidCallback onTap}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      width: 72,
      height: 72,
      child: Material(
        color: isDark ? AppColors.darkSurfaceContainerLowest : AppColors.surfaceContainerLowest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(36),
          side: BorderSide(
            color: isDark ? AppColors.darkOutlineVariant : AppColors.outlineVariant,
            width: 1.0,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(36),
          child: Center(child: child),
        ),
      ),
    );
  }
}
