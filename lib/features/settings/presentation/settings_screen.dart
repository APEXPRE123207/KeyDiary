import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/providers.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/security/secure_storage_service.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _biometrics = true;
  int _autoLockSeconds = 60;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final bio = await SecureStorageService.isBiometricsEnabled();
    final lockSec = await SecureStorageService.getAutoLockSeconds();
    if (mounted) {
      setState(() {
        _biometrics = bio;
        _autoLockSeconds = lockSec;
      });
    }
  }

  void _lockVault() {
    ref.read(vaultKeyProvider.notifier).state = null;
    context.go('/lock');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentThemeMode = ref.watch(themeModeProvider);
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.surface,
      appBar: AppBar(
        title: const Text('Vault Settings'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppDimensions.margin),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppDimensions.spaceSm),

              // Profile Section
              AppCard(
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkPrimaryContainer : AppColors.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          user?.displayName.isNotEmpty == true ? user!.displayName[0].toUpperCase() : 'D',
                          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppDimensions.spaceMd),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(user?.displayName ?? 'Dad', style: AppTypography.headlineSm()),
                          Text(user?.email ?? 'dad@family.vault', style: AppTypography.bodySm()),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.darkSurfaceContainerHigh : AppColors.surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                            ),
                            child: Text('Primary Vault Owner', style: AppTypography.labelSm()),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppDimensions.spaceLg),

              // Appearance (Dark Theme & Light Theme)
              Text('Appearance', style: AppTypography.headlineSm()),
              const SizedBox(height: AppDimensions.spaceSm),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Theme Mode', style: AppTypography.labelLg()),
                    const SizedBox(height: AppDimensions.spaceSm),
                    Row(
                      children: [
                        _buildThemeOption('System', ThemeMode.system, currentThemeMode),
                        const SizedBox(width: 8),
                        _buildThemeOption('Light', ThemeMode.light, currentThemeMode),
                        const SizedBox(width: 8),
                        _buildThemeOption('Dark', ThemeMode.dark, currentThemeMode),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppDimensions.spaceLg),

              // Security Section
              Text('Security & Privacy', style: AppTypography.headlineSm()),
              const SizedBox(height: AppDimensions.spaceSm),
              AppCard(
                child: Column(
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.pin),
                      title: Text('Change Master PIN', style: AppTypography.labelLg()),
                      subtitle: Text('Update your 4 to 6 digit security code', style: AppTypography.bodySm()),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push('/security-setup'),
                    ),
                    const Divider(),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      secondary: const Icon(Icons.fingerprint),
                      title: Text('Biometric Authentication', style: AppTypography.labelLg()),
                      subtitle: Text('Fingerprint / Face unlock', style: AppTypography.bodySm()),
                      value: _biometrics,
                      activeThumbColor: isDark ? AppColors.darkPrimary : AppColors.primary,
                      onChanged: (val) async {
                        setState(() => _biometrics = val);
                        await SecureStorageService.setBiometricsEnabled(val);
                      },
                    ),
                    const Divider(),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.timer_outlined),
                      title: Text('Auto-Lock Duration', style: AppTypography.labelLg()),
                      subtitle: Text('$_autoLockSeconds seconds background timeout', style: AppTypography.bodySm()),
                      trailing: DropdownButton<int>(
                        value: _autoLockSeconds,
                        underline: const SizedBox(),
                        items: const [
                          DropdownMenuItem(value: 0, child: Text('Immediately')),
                          DropdownMenuItem(value: 30, child: Text('30 seconds')),
                          DropdownMenuItem(value: 60, child: Text('1 minute')),
                          DropdownMenuItem(value: 300, child: Text('5 minutes')),
                          DropdownMenuItem(value: 900, child: Text('15 minutes')),
                          DropdownMenuItem(value: -1, child: Text('Never')),
                        ],
                        onChanged: (val) async {
                          if (val != null) {
                            setState(() => _autoLockSeconds = val);
                            await SecureStorageService.setAutoLockSeconds(val);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppDimensions.spaceLg),

              // Vault & Co-Guardians
              Text('Family & Backup', style: AppTypography.headlineSm()),
              const SizedBox(height: AppDimensions.spaceSm),
              AppCard(
                child: Column(
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.people_outline),
                      title: Text('Family Co-Guardians', style: AppTypography.labelLg()),
                      subtitle: Text('Manage shared access with Soumyadip (Son)', style: AppTypography.bodySm()),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push('/family-vault'),
                    ),
                    const Divider(),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.emergency_outlined),
                      title: Text('Emergency Recovery Database', style: AppTypography.labelLg()),
                      subtitle: Text('Dedicated emergency_vault store synced', style: AppTypography.bodySm()),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push('/family-vault'),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppDimensions.spaceLg),

              // Lock Vault Now Button
              AppButton(
                text: 'Lock Vault Now',
                variant: AppButtonVariant.secondary,
                leadingIcon: Icons.lock_clock,
                width: double.infinity,
                onPressed: _lockVault,
              ),

              const SizedBox(height: AppDimensions.spaceSm),

              AppButton(
                text: 'Sign Out of KeyDiary',
                variant: AppButtonVariant.ghost,
                leadingIcon: Icons.logout,
                width: double.infinity,
                onPressed: () async {
                  await ref.read(authRepositoryProvider).signOut();
                  ref.read(vaultKeyProvider.notifier).state = null;
                  if (!context.mounted) return;
                  context.go('/auth');
                },
              ),

              const SizedBox(height: AppDimensions.spaceXl * 2),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThemeOption(String label, ThemeMode mode, ThemeMode currentMode) {
    final isSelected = currentMode == mode;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: isDark ? AppColors.darkPrimaryContainer : AppColors.primaryContainer,
      labelStyle: TextStyle(color: isSelected ? Colors.white : null),
      onSelected: (_) {
        ref.read(themeModeProvider.notifier).setMode(mode);
      },
    );
  }
}
