import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/security/pin_service.dart';
import '../../../core/security/secure_storage_service.dart';
import '../../../core/security/encryption_service.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';

class SecuritySetupScreen extends ConsumerStatefulWidget {
  const SecuritySetupScreen({super.key});

  @override
  ConsumerState<SecuritySetupScreen> createState() => _SecuritySetupScreenState();
}

class _SecuritySetupScreenState extends ConsumerState<SecuritySetupScreen> {
  final _pinController = TextEditingController(text: '123456');
  final _confirmPinController = TextEditingController(text: '123456');
  bool _biometricsEnabled = true;
  int _autoLockSeconds = 60; // 1 minute default
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void dispose() {
    _pinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  Future<void> _saveSecurity() async {
    final pin = _pinController.text.trim();
    final confirm = _confirmPinController.text.trim();

    if (pin.length != 6) {
      setState(() => _errorMessage = 'PIN must be exactly 6 digits');
      return;
    }
    if (pin != confirm) {
      setState(() => _errorMessage = 'PINs do not match');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      // 1. Hash and save PIN
      final pinHash = await PinService.hashPin(pin);
      await SecureStorageService.savePinHash(pinHash);

      // 2. Save biometrics setting
      await SecureStorageService.setBiometricsEnabled(_biometricsEnabled);

      // 3. Save auto-lock duration
      await SecureStorageService.setAutoLockSeconds(_autoLockSeconds);

      // 4. Ensure VEK is generated and saved
      final activeVaultId = await SecureStorageService.getActiveVaultId() ?? 'primary-vault';
      var vek = await SecureStorageService.getVaultKey(activeVaultId);
      if (vek == null) {
        vek = await EncryptionService.generateRandomKey();
        await SecureStorageService.saveVaultKey(activeVaultId, vek);
      }

      if (mounted) {
        context.go('/category-setup');
      }
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.surface,
      appBar: AppBar(
        title: const Text('Security Protection Setup'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppDimensions.margin),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppDimensions.spaceSm),
              Text(
                'Keep your vault protected',
                style: AppTypography.headlineMd(
                  color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                ),
              ),
              const SizedBox(height: AppDimensions.spaceXs),
              Text(
                'Configure hardware biometrics and master PIN for day-to-day access.',
                style: AppTypography.bodyMd(
                  color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppDimensions.spaceLg),

              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(AppDimensions.spaceSm),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkStatusRoseBg : AppColors.statusRoseBg,
                    borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: AppTypography.bodySm(
                      color: isDark ? AppColors.darkStatusRose : AppColors.statusRose,
                    ),
                  ),
                ),
                const SizedBox(height: AppDimensions.spaceMd),
              ],

              // Section 1: Master PIN
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.pin,
                          color: isDark ? AppColors.darkPrimary : AppColors.primary,
                        ),
                        const SizedBox(width: 8),
                        Text('Master PIN Protection', style: AppTypography.labelLg()),
                      ],
                    ),
                    const SizedBox(height: AppDimensions.spaceSm),
                    Text(
                      'Used when unlocking your vault and recovering protected categories.',
                      style: AppTypography.bodySm(),
                    ),
                    const SizedBox(height: AppDimensions.spaceMd),
                    TextField(
                      controller: _pinController,
                      keyboardType: TextInputType.number,
                      obscureText: true,
                      maxLength: 6,
                      decoration: const InputDecoration(
                        labelText: 'Enter 6-digit Master PIN',
                        counterText: '',
                      ),
                    ),
                    const SizedBox(height: AppDimensions.spaceSm),
                    TextField(
                      controller: _confirmPinController,
                      keyboardType: TextInputType.number,
                      obscureText: true,
                      maxLength: 6,
                      decoration: const InputDecoration(
                        labelText: 'Confirm PIN',
                        counterText: '',
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppDimensions.spaceMd),

              // Section 2: Biometrics
              AppCard(
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Row(
                    children: [
                      Icon(
                        Icons.fingerprint,
                        color: isDark ? AppColors.darkPrimary : AppColors.primary,
                      ),
                      const SizedBox(width: 8),
                      Text('Biometrics (Fingerprint / Face)', style: AppTypography.labelLg()),
                    ],
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      'Allow fast, secure unlock using device biometric sensors.',
                      style: AppTypography.bodySm(),
                    ),
                  ),
                  value: _biometricsEnabled,
                  activeThumbColor: isDark ? AppColors.darkPrimary : AppColors.primary,
                  onChanged: (val) => setState(() => _biometricsEnabled = val),
                ),
              ),

              const SizedBox(height: AppDimensions.spaceMd),

              // Section 3: Automatic Lock Duration
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.timer_outlined,
                          color: isDark ? AppColors.darkPrimary : AppColors.primary,
                        ),
                        const SizedBox(width: 8),
                        Text('Automatic Lock', style: AppTypography.labelLg()),
                      ],
                    ),
                    const SizedBox(height: AppDimensions.spaceSm),
                    Text(
                      'Lock the vault when KeyDiary is backgrounded.',
                      style: AppTypography.bodySm(),
                    ),
                    const SizedBox(height: AppDimensions.spaceMd),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildTimeoutChip('Immediately', 0),
                        _buildTimeoutChip('30 seconds', 30),
                        _buildTimeoutChip('1 minute', 60),
                        _buildTimeoutChip('5 minutes', 300),
                        _buildTimeoutChip('15 minutes', 900),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppDimensions.spaceXl),

              AppButton(
                text: 'Save & Continue',
                leadingIcon: Icons.lock,
                isLoading: _isSaving,
                width: double.infinity,
                onPressed: _saveSecurity,
              ),

              const SizedBox(height: AppDimensions.spaceXl),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimeoutChip(String label, int seconds) {
    final isSelected = _autoLockSeconds == seconds;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: isDark ? AppColors.darkPrimaryContainer : AppColors.primaryFixed,
      onSelected: (val) {
        if (val) setState(() => _autoLockSeconds = seconds);
      },
    );
  }
}
