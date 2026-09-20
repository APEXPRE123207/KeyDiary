import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/providers.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/security/encryption_service.dart';
import '../../../core/security/secure_storage_service.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';

class CategorySetupScreen extends ConsumerStatefulWidget {
  const CategorySetupScreen({super.key});

  @override
  ConsumerState<CategorySetupScreen> createState() => _CategorySetupScreenState();
}

class _CategorySetupScreenState extends ConsumerState<CategorySetupScreen> {
  final Set<String> _selected = {
    'Investments',
    'Keys & Places',
    'Insurance',
    'Cards & Bank',
    'Property',
    'Important Docs',
  };

  bool _isCreating = false;

  final List<Map<String, dynamic>> _templates = [
    {
      'name': 'Investments',
      'subtitle': 'Mutual funds, FDs, stocks & nominee records',
      'icon': Icons.savings,
      'isProtected': true,
    },
    {
      'name': 'Keys & Places',
      'subtitle': 'Physical locker keys, almirah safe spots & combinations',
      'icon': Icons.key,
      'isProtected': false,
    },
    {
      'name': 'Insurance',
      'subtitle': 'Life policies (LIC), health cards & premium dates',
      'icon': Icons.verified_user,
      'isProtected': false,
    },
    {
      'name': 'Cards & Bank',
      'subtitle': 'Savings accounts, branch IFSC & card limits',
      'icon': Icons.credit_card,
      'isProtected': true,
    },
    {
      'name': 'Property',
      'subtitle': 'Deeds, mutation certificates, land papers & tax slips',
      'icon': Icons.home,
      'isProtected': false,
    },
    {
      'name': 'Important Docs',
      'subtitle': 'Passports, Aadhaar, PAN, birth certificates & wills',
      'icon': Icons.description,
      'isProtected': false,
    },
  ];

  Future<void> _handleFinish() async {
    setState(() => _isCreating = true);

    final vaultRepo = ref.read(vaultRepositoryProvider);
    final catRepo = ref.read(categoryRepositoryProvider);
    final entryRepo = ref.read(entryRepositoryProvider);
    final user = ref.read(currentUserProvider);

    try {
      // 1. Generate or load VEK
      final activeVaultId = await SecureStorageService.getActiveVaultId() ?? 'primary-family-vault';
      var vek = await SecureStorageService.getVaultKey(activeVaultId);
      if (vek == null) {
        vek = await EncryptionService.generateRandomKey();
        await SecureStorageService.saveVaultKey(activeVaultId, vek);
      }

      // 2. Create or verify Vault
      final vault = await vaultRepo.createVault(
        name: 'KeyDiary Family Vault',
        userId: user?.id ?? 'user-dad',
        vekBytes: vek,
      );
      ref.read(activeVaultProvider.notifier).state = vault;
      ref.read(vaultKeyProvider.notifier).state = vek;

      // 3. Seed selected categories
      await catRepo.seedDefaultCategories(
        vaultId: vault.id,
        userId: user?.id,
        selectedCategoryNames: _selected.toList(),
      );

      // 4. Seed demo entries for high-fidelity UI demonstration
      entryRepo.seedLocalDemoEntries(
        categoryId: 'cat-investments-${vault.id}',
        vaultId: vault.id,
      );

      if (mounted) {
        context.go('/home');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Setup error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.surface,
      appBar: AppBar(
        title: const Text('First Category Setup'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: AppDimensions.margin),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: AppDimensions.spaceSm),
                    Text(
                      'Choose your ledger categories',
                      style: AppTypography.headlineMd(
                        color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: AppDimensions.spaceXs),
                    Text(
                      'Select the information types you wish to record. You can customize icons and add more anytime.',
                      style: AppTypography.bodyMd(
                        color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppDimensions.spaceLg),

                    // Templates List
                    ..._templates.map((tpl) {
                      final name = tpl['name'] as String;
                      final isSelected = _selected.contains(name);
                      final isProtected = tpl['isProtected'] as bool;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppDimensions.spaceSm),
                        child: AppCard(
                          onTap: () {
                            setState(() {
                              if (isSelected) {
                                if (_selected.length > 1) _selected.remove(name);
                              } else {
                                _selected.add(name);
                              }
                            });
                          },
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: isDark ? AppColors.darkPrimaryContainer : AppColors.primaryFixed,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  tpl['icon'] as IconData,
                                  color: isDark ? AppColors.darkOnPrimaryContainer : AppColors.primary,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: AppDimensions.spaceMd),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(name, style: AppTypography.labelLg()),
                                        if (isProtected) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                            decoration: BoxDecoration(
                                              color: isDark ? AppColors.darkSurfaceContainerHigh : AppColors.surfaceContainerHigh,
                                              borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.lock,
                                                  size: 11,
                                                  color: isDark ? AppColors.darkPrimary : AppColors.primary,
                                                ),
                                                const SizedBox(width: 3),
                                                Text(
                                                  'Protected',
                                                  style: AppTypography.labelSm(
                                                    color: isDark ? AppColors.darkPrimary : AppColors.primary,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      tpl['subtitle'] as String,
                                      style: AppTypography.bodySm(),
                                    ),
                                  ],
                                ),
                              ),
                              Checkbox(
                                value: isSelected,
                                activeColor: isDark ? AppColors.darkPrimary : AppColors.primary,
                                onChanged: (val) {
                                  setState(() {
                                    if (val == true) {
                                      _selected.add(name);
                                    } else if (_selected.length > 1) {
                                      _selected.remove(name);
                                    }
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    }),

                    const SizedBox(height: AppDimensions.spaceMd),
                  ],
                ),
              ),
            ),

            // Bottom Action
            Padding(
              padding: const EdgeInsets.all(AppDimensions.margin),
              child: AppButton(
                text: 'Create Vault (${_selected.length} categories)',
                leadingIcon: Icons.check,
                isLoading: _isCreating,
                width: double.infinity,
                onPressed: _handleFinish,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
