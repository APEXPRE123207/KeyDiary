import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/network/supabase_client.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/security/secure_storage_service.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/trust_badge.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  bool _isLoading = false;

  Future<void> _handleStart() async {
    setState(() => _isLoading = true);
    final hasPin = await SecureStorageService.hasPin();
    final hasSession = await SecureStorageService.hasUserSession() ||
        (SupabaseService.isInitialized && Supabase.instance.client.auth.currentUser != null);
    setState(() => _isLoading = false);

    if (!mounted) return;
    if (!hasSession) {
      // Must authenticate or create vault member account first
      context.go('/auth');
    } else if (hasPin) {
      context.go('/lock');
    } else {
      context.go('/security-setup');
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
              // Top Trust Bar
              Padding(
                padding: const EdgeInsets.only(top: AppDimensions.spaceMd),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TrustBadge(
                      type: TrustBadgeType.vaultEnclave,
                      customText: 'End-to-End Isolated',
                    ),
                  ],
                ),
              ),

              // Central Brand Presentation
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkPrimaryContainer : AppColors.primaryContainer,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryContainer.withAlpha(isDark ? 80 : 40),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.menu_book,
                      size: 46,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: AppDimensions.spaceLg),
                  Text(
                    'KeyDiary',
                    style: AppTypography.headlineLg(
                      color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                    ).copyWith(fontSize: 32),
                  ),
                  const SizedBox(height: AppDimensions.spaceXs),
                  Text(
                    'Private Family Vault & Ledger',
                    style: AppTypography.bodyMd(
                      color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppDimensions.spaceMd),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.lock_outline,
                        size: 16,
                        color: isDark ? AppColors.darkPrimary : AppColors.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Local Secure Hardware Enclave',
                        style: AppTypography.labelSm(
                          color: isDark ? AppColors.darkPrimary : AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              // Bottom Actions
              Padding(
                padding: const EdgeInsets.only(bottom: AppDimensions.spaceLg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppButton(
                      text: 'Unlock Vault',
                      leadingIcon: Icons.fingerprint,
                      isLoading: _isLoading,
                      width: double.infinity,
                      onPressed: _handleStart,
                    ),
                    const SizedBox(height: AppDimensions.spaceSm),
                    Text(
                      'Private & Secure Family Vault',
                      style: AppTypography.labelSm(
                        color: isDark ? AppColors.darkOutline : AppColors.outline,
                      ),
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
}
