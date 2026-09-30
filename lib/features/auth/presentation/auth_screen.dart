import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/auth_repository.dart';
import '../../../app/providers.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/network/supabase_client.dart';
import '../../../core/security/secure_storage_service.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/trust_badge.dart';
import '../../entries/data/entry_repository.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  bool _isSignUp = false;
  String _selectedRole = 'ADMIN'; // 'ADMIN' or 'CO_GUARDIAN'
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  final _nameController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _checkExistingAccounts();
  }

  Future<void> _checkExistingAccounts() async {
    final accounts = await SecureStorageService.getLocalAccounts();
    if (accounts.isEmpty && mounted) {
      setState(() => _isSignUp = true);
    }
  }

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
      setState(() => _errorMessage = 'Please enter your username.');
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
    final vaultRepo = ref.read(vaultRepositoryProvider);
    final vaultEmail = AuthRepository.memberNameToEmail(name);

    try {
      if (_isSignUp) {
        final user = await authRepo.signUp(
          email: vaultEmail,
          password: password,
          displayName: name,
          role: _selectedRole,
        );
        ref.read(currentUserProvider.notifier).state = user;

        final hasPin = await SecureStorageService.hasPin();
        if (!mounted) return;
        if (!hasPin) {
          context.go('/security-setup');
        } else if (_selectedRole == 'CO_GUARDIAN') {
          // Co-Guardians do not set up their own categories; they join Admin's shared vault
          context.go('/home');
        } else {
          // Admin configures categories
          context.go('/category-setup');
        }
      } else {
        final user = await authRepo.signIn(
          email: vaultEmail,
          password: password,
        );
        ref.read(currentUserProvider.notifier).state = user;

        // Proactively resolve and bind shared family vault and VEK
        final vaults = await vaultRepo.getUserVaults(
          user.id,
          displayName: user.displayName,
          email: user.email,
          role: user.role,
        );
        if (vaults.isNotEmpty) {
          var targetVault = vaults.first;
          targetVault = await vaultRepo.ensureValidUuidVault(targetVault);
          ref.read(activeVaultProvider.notifier).state = targetVault;
          await SecureStorageService.setActiveVaultId(targetVault.id);

          final vek = await vaultRepo.getVaultKey(
            vaultId: targetVault.id,
            userId: user.id,
            displayName: user.displayName,
            email: user.email,
          );
          if (vek != null) {
            ref.read(vaultKeyProvider.notifier).state = vek;
            await SecureStorageService.saveVaultKey(targetVault.id, vek);
          }

          if (SupabaseService.isInitialized) {
            try {
              final client = Supabase.instance.client;
              final sbUser = client.auth.currentUser;
              if (sbUser != null) {
                // A. Upsert Vault so foreign key constraints on vault_id work
                if (user.isAdmin || !user.isCoGuardian) {
                  await client.from('vaults').upsert({
                    'id': targetVault.id,
                    'name': targetVault.name,
                    'created_by': sbUser.id,
                  });
                }

                // B. Upsert current user in vault_members
                await client.from('vault_members').upsert({
                  'vault_id': targetVault.id,
                  'user_id': sbUser.id,
                  'role': user.isCoGuardian ? 'MEMBER' : 'OWNER',
                  'encrypted_vault_key': vek != null ? base64Encode(vek) : 'wrapped_key_placeholder',
                }, onConflict: 'vault_id, user_id');

                // C. If Admin, auto-enroll other members
                if (user.isAdmin) {
                  try {
                    final childProfiles = await client
                        .from('profiles')
                        .select('user_id')
                        .neq('user_id', sbUser.id);
                    for (final cp in (childProfiles as List)) {
                      final cUid = cp['user_id'] as String?;
                      if (cUid != null && cUid.isNotEmpty && cUid != sbUser.id) {
                        await client.from('vault_members').upsert({
                          'vault_id': targetVault.id,
                          'user_id': cUid,
                          'role': 'MEMBER',
                          'encrypted_vault_key': vek != null ? base64Encode(vek) : 'wrapped_key_placeholder',
                        }, onConflict: 'vault_id, user_id');
                      }
                    }
                  } catch (_) {}
                }
              }
            } catch (_) {}
          }

          if (vek != null) {
            try {
              await EntryRepository().downloadAndSyncAllVaultEntries(
                vaultId: targetVault.id,
                vekBytes: vek,
                userId: user.id,
                isOwner: user.isAdmin,
              );
            } catch (_) {}
          }

          ref.invalidate(categoriesProvider);
          ref.invalidate(vaultMembersProvider);
          ref.invalidate(vaultEntriesProvider);
        }

        final hasPin = await SecureStorageService.hasPin();
        if (!mounted) return;
        if (!hasPin) {
          context.go('/security-setup');
        } else {
          context.go('/home');
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
                'Private family vault for your household records, safe spots, and important documents.',
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

              // Role Selector for Sign Up
              if (_isSignUp) ...[
                Text(
                  'Select Account Role',
                  style: AppTypography.labelMd(
                    color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildRoleSelectorCard(
                        isDark: isDark,
                        title: 'Vault Admin',
                        subtitle: 'Primary Guardian (e.g. Dad)',
                        isSelected: _selectedRole == 'ADMIN',
                        icon: Icons.admin_panel_settings_outlined,
                        onTap: () => setState(() => _selectedRole = 'ADMIN'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildRoleSelectorCard(
                        isDark: isDark,
                        title: 'Co-Guardian',
                        subtitle: 'Family Member (e.g. Child)',
                        isSelected: _selectedRole == 'CO_GUARDIAN',
                        icon: Icons.shield_outlined,
                        onTap: () => setState(() => _selectedRole = 'CO_GUARDIAN'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppDimensions.spaceMd),
              ],

              // Form fields (Member Name & Password only - no email)
              Text(
                _isSignUp ? 'Member Username' : 'Username',
                style: AppTypography.labelMd(),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  hintText: _isSignUp
                      ? (_selectedRole == 'ADMIN' ? 'e.g. Dad' : 'e.g. Sarah')
                      : 'Enter your registered username',
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
                text: _isSignUp
                    ? (_selectedRole == 'ADMIN' ? 'Initialize Admin Vault' : 'Register Co-Guardian')
                    : 'Sign In to Vault',
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
                        : 'First time here? Sign Up',
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

  Widget _buildRoleSelectorCard({
    required bool isDark,
    required String title,
    required String subtitle,
    required bool isSelected,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final activeColor = isDark ? AppColors.darkPrimary : AppColors.primary;
    final activeBg = isDark ? AppColors.darkPrimaryContainer : AppColors.primaryFixed;
    return Material(
      color: isSelected
          ? activeBg.withValues(alpha: isDark ? 0.35 : 0.6)
          : (isDark ? AppColors.darkSurfaceContainer : AppColors.surfaceContainer),
      borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            border: Border.all(
              color: isSelected ? activeColor : (isDark ? AppColors.darkOutlineVariant : AppColors.outlineVariant),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(icon, size: 22, color: isSelected ? activeColor : (isDark ? AppColors.darkOutline : AppColors.outline)),
                  if (isSelected)
                    Icon(Icons.check_circle, size: 18, color: activeColor),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: AppTypography.labelLg(context: context).copyWith(
                  color: isSelected ? activeColor : (isDark ? AppColors.darkOnSurface : AppColors.onSurface),
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: AppTypography.bodySm(
                  color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
