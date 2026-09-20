import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../data/auth_repository.dart';
import '../../../app/providers.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/security/secure_storage_service.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/trust_badge.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  bool _isSignUp = false;
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  final _nameController = TextEditingController(text: 'Dad');
  final _passwordController = TextEditingController(text: 'FamilySecret2026!');

  @override
  void dispose() {
    _nameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    final password = _passwordController.text;

    if (name.isEmpty) {
      setState(() => _errorMessage = 'Please enter your member name or role.');
      return;
    }
    if (password.isEmpty) {
      setState(() => _errorMessage = 'Please enter your vault password.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final authRepo = ref.read(authRepositoryProvider);
    final vaultEmail = AuthRepository.memberNameToEmail(name);

    try {
      if (_isSignUp) {
        final user = await authRepo.signUp(
          email: vaultEmail,
          password: password,
          displayName: name,
        );
        ref.read(currentUserProvider.notifier).state = user;
        if (mounted) context.go('/category-setup');
      } else {
        final user = await authRepo.signIn(
          email: vaultEmail,
          password: password,
        );
        ref.read(currentUserProvider.notifier).state = user;

        final hasPin = await SecureStorageService.hasPin();
        if (!mounted) return;
        if (!hasPin) {
          context.go('/security-setup');
        } else {
          context.go('/lock');
        }
      }
    } catch (e) {
      setState(() => _errorMessage = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppDimensions.margin),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppDimensions.spaceMd),

              // Trust Badge Bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const TrustBadge(
                    type: TrustBadgeType.vaultEnclave,
                    customText: 'Local Enclave',
                  ),
                  Text(
                    'Primary Recovery',
                    style: AppTypography.labelSm(
                      color: isDark ? AppColors.darkOutline : AppColors.outline,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppDimensions.spaceXl),

              // App Logo Header
              ClipRRect(
                borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                child: Image.asset(
                  'assets/images/app_logo.png',
                  width: 52,
                  height: 52,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkPrimaryContainer : AppColors.primaryFixed,
                      borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                    ),
                    child: Icon(
                      Icons.lock_outline,
                      color: isDark ? AppColors.darkOnPrimaryContainer : AppColors.primary,
                      size: 26,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: AppDimensions.spaceMd),

              Text(
                _isSignUp ? 'Create Family Vault' : 'Welcome to KeyDiary',
                style: AppTypography.headlineLg(
                  color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                ),
              ),
              const SizedBox(height: AppDimensions.spaceXs),
              Text(
                'Private, client-side encrypted repository for your household records and safe spots.',
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
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 18,
                        color: isDark ? AppColors.darkStatusRose : AppColors.statusRose,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: AppTypography.bodySm(
                            color: isDark ? AppColors.darkStatusRose : AppColors.statusRose,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppDimensions.spaceMd),
              ],

              // Form fields (Member Name & Password only - no email)
              Text(
                _isSignUp ? 'Your Member Name / Role' : 'Member Name',
                style: AppTypography.labelMd(),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  hintText: _isSignUp ? 'e.g. Dad, Mom, Child' : 'Enter your member name',
                  prefixIcon: const Icon(Icons.person_outline),
                ),
              ),

              const SizedBox(height: AppDimensions.spaceMd),

              Text('Vault Password', style: AppTypography.labelMd()),
              const SizedBox(height: 6),
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  hintText: 'Enter your secure password',
                  prefixIcon: const Icon(Icons.shield_outlined),
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
              ),

              const SizedBox(height: AppDimensions.spaceLg),

              AppButton(
                text: _isSignUp ? 'Initialize Vault' : 'Sign In to Vault',
                leadingIcon: Icons.arrow_forward,
                isLoading: _isLoading,
                width: double.infinity,
                onPressed: _submit,
              ),

              const SizedBox(height: AppDimensions.spaceMd),

              Center(
                child: TextButton(
                  onPressed: () => setState(() {
                    _isSignUp = !_isSignUp;
                    _errorMessage = null;
                  }),
                  child: Text(
                    _isSignUp
                        ? 'Already have an account? Sign In'
                        : 'First time here? Create Family Vault',
                    style: AppTypography.labelMd(
                      color: isDark ? AppColors.darkPrimary : AppColors.primary,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: AppDimensions.spaceXl),
            ],
          ),
        ),
      ),
    );
  }
}
