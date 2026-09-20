import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/providers.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/security/biometric_service.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/trust_badge.dart';
import '../domain/category.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentNavIndex = 0;

  @override
  void initState() {
    super.initState();
    _ensureVaultLoaded();
  }

  Future<void> _ensureVaultLoaded() async {
    final activeVault = ref.read(activeVaultProvider);
    if (activeVault == null) {
      final user = ref.read(currentUserProvider);
      final vaultRepo = ref.read(vaultRepositoryProvider);
      final catRepo = ref.read(categoryRepositoryProvider);
      final entryRepo = ref.read(entryRepositoryProvider);

      final vaults = await vaultRepo.getUserVaults(user?.id ?? 'user-dad');
      if (vaults.isNotEmpty) {
        ref.read(activeVaultProvider.notifier).state = vaults.first;
      } else {
        // Create demo vault
        final created = await vaultRepo.createVault(
          name: 'KeyDiary Family Vault',
          userId: user?.id ?? 'user-dad',
          vekBytes: Uint8List(32),
        );
        ref.read(activeVaultProvider.notifier).state = created;
        await catRepo.seedDefaultCategories(vaultId: created.id);
        entryRepo.seedLocalDemoEntries(
          categoryId: 'cat-investments-${created.id}',
          vaultId: created.id,
        );
      }
    }
  }

  Future<void> _openCategory(Category category) async {
    if (category.isLocked) {
      // Biometric category lock (Section 17 requirement)
      final authenticated = await BiometricService.authenticate(
        reason: 'Authenticate to view protected category "${category.name}"',
      );
      if (!authenticated) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Authentication required to access ${category.name}.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
    }

    if (!mounted) return;
    context.push('/category/${category.id}', extra: category);
  }

  void _showAddCategoryDialog() {
    final nameCtrl = TextEditingController();
    bool isProtected = false;
    String selectedIcon = 'folder';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: AppDimensions.sheetRadius),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          return Padding(
            padding: EdgeInsets.only(
              left: AppDimensions.margin,
              right: AppDimensions.margin,
              top: AppDimensions.spaceMd,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + AppDimensions.spaceLg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkOutlineVariant : AppColors.outlineVariant,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                const SizedBox(height: AppDimensions.spaceMd),
                Text('Add New Category', style: AppTypography.headlineSm()),
                const SizedBox(height: AppDimensions.spaceMd),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Category Name',
                    hintText: 'e.g. Health Records, Gold, Wills',
                  ),
                ),
                const SizedBox(height: AppDimensions.spaceMd),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Require Biometric Lock', style: AppTypography.labelMd()),
                  subtitle: Text('Requires fingerprint/PIN every time it is opened', style: AppTypography.bodySm()),
                  value: isProtected,
                  activeThumbColor: isDark ? AppColors.darkPrimary : AppColors.primary,
                  onChanged: (val) => setModalState(() => isProtected = val),
                ),
                const SizedBox(height: AppDimensions.spaceLg),
                SizedBox(
                  width: double.infinity,
                  height: AppDimensions.buttonHeight,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? AppColors.darkPrimaryContainer : AppColors.primaryContainer,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusLg)),
                    ),
                    onPressed: () async {
                      final name = nameCtrl.text.trim();
                      if (name.isEmpty) return;
                      final vault = ref.read(activeVaultProvider);
                      if (vault == null) return;

                      final cat = Category(
                        id: 'cat-${DateTime.now().millisecondsSinceEpoch}',
                        vaultId: vault.id,
                        name: name,
                        icon: selectedIcon,
                        isLocked: isProtected,
                        createdAt: DateTime.now(),
                        updatedAt: DateTime.now(),
                      );
                      await ref.read(categoryRepositoryProvider).createCategory(cat);
                      ref.invalidate(categoriesProvider);
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                    child: Text('Create Category', style: AppTypography.labelLg(color: Colors.white)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final categoriesAsync = ref.watch(categoriesProvider);
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.surface,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkPrimaryContainer : AppColors.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.menu_book, size: 18, color: Colors.white),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'KeyDiary',
                  style: AppTypography.labelLg(
                    color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDark ? AppColors.darkPrimary : AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Vault Records',
                      style: AppTypography.labelSm(
                        color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none),
            onPressed: () => context.push('/activity'),
          ),
          IconButton(
            icon: const Icon(Icons.people_outline),
            tooltip: 'Family Vault Members',
            onPressed: () => context.push('/family-vault'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppDimensions.margin),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppDimensions.spaceSm),

              // Trust & Greeting Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const TrustBadge(
                    type: TrustBadgeType.vaultEnclave,
                    customText: 'Secure & synced with Soumyadip',
                  ),
                  Text(
                    'v2.4 Private',
                    style: AppTypography.labelSm(
                      color: isDark ? AppColors.darkOutline : AppColors.outline,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppDimensions.spaceMd),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Good evening, ${user?.displayName ?? "Dad"}',
                        style: AppTypography.headlineLg(
                          color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                        ),
                      ),
                      Text(
                        'Your family vault & vital records',
                        style: AppTypography.bodyMd(
                          color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  // Avatar stack
                  Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDark ? AppColors.darkPrimaryContainer : AppColors.primaryContainer,
                        ),
                        child: Center(
                          child: Text(
                            user?.displayName.isNotEmpty == true ? user!.displayName[0].toUpperCase() : 'D',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDark ? AppColors.darkSecondaryContainer : AppColors.secondaryContainer,
                        ),
                        child: const Center(
                          child: Text(
                            'S',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: AppDimensions.spaceMd),

              // High-Trust Co-Guardian Notice Card
              AppCard(
                onTap: () => context.push('/family-vault'),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkPrimaryContainer : AppColors.primaryFixed,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.shield,
                        color: isDark ? AppColors.darkOnPrimaryContainer : AppColors.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: AppDimensions.spaceMd),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Shared with Soumyadip (Son)',
                                style: AppTypography.labelMd(
                                  color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: isDark ? AppColors.darkSurfaceContainerHigh : AppColors.surfaceContainerHigh,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text('Co-Guardian', style: AppTypography.labelSm()),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Last synced today • End-to-end secured',
                            style: AppTypography.bodySm(
                              color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppDimensions.spaceMd),

              // Search Bar Affordance
              InkWell(
                onTap: () => context.push('/search'),
                borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                child: Container(
                  height: AppDimensions.inputHeight,
                  padding: const EdgeInsets.symmetric(horizontal: AppDimensions.spaceMd),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurfaceContainerLowest : AppColors.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                    border: Border.all(
                      color: isDark ? AppColors.darkOutlineVariant : AppColors.outlineVariant,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.search,
                        color: isDark ? AppColors.darkPrimary : AppColors.primary,
                        size: 22,
                      ),
                      const SizedBox(width: AppDimensions.spaceSm),
                      Expanded(
                        child: Text(
                          'Search your vault... (e.g. FD, lockers, policy)',
                          style: AppTypography.bodyMd(
                            color: isDark ? AppColors.darkOutline : AppColors.outline,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: AppDimensions.spaceLg),

              // Categories Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text('Your Information', style: AppTypography.headlineSm()),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkSurfaceContainerHigh : AppColors.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                        ),
                        child: Text(
                          '46 entries',
                          style: AppTypography.labelSm(),
                        ),
                      ),
                    ],
                  ),
                  TextButton.icon(
                    onPressed: _showAddCategoryDialog,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add Category'),
                  ),
                ],
              ),

              const SizedBox(height: AppDimensions.spaceSm),

              // 2-Column Category Grid
              categoriesAsync.when(
                data: (categories) {
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.98,
                    ),
                    itemCount: categories.length,
                    itemBuilder: (context, index) {
                      final cat = categories[index];
                      return _buildCategoryCard(cat);
                    },
                  );
                },
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (e, _) => Center(child: Text('Error loading categories: $e')),
              ),

              const SizedBox(height: AppDimensions.spaceXl * 2),
            ],
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentNavIndex,
        onDestinationSelected: (idx) {
          setState(() => _currentNavIndex = idx);
          if (idx == 1) context.push('/search');
          if (idx == 2) context.push('/activity');
          if (idx == 3) context.push('/settings');
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: 'Vault',
          ),
          NavigationDestination(
            icon: Icon(Icons.search),
            label: 'Search',
          ),
          NavigationDestination(
            icon: Icon(Icons.history),
            label: 'Activity',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(Category cat) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    IconData iconData = Icons.folder;
    switch (cat.icon) {
      case 'savings':
        iconData = Icons.savings;
        break;
      case 'key':
        iconData = Icons.key;
        break;
      case 'verified_user':
        iconData = Icons.verified_user;
        break;
      case 'credit_card':
        iconData = Icons.credit_card;
        break;
      case 'home':
        iconData = Icons.home;
        break;
      case 'description':
        iconData = Icons.description;
        break;
    }

    return AppCard(
      padding: const EdgeInsets.all(AppDimensions.spaceMd),
      onTap: () => _openCategory(cat),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkPrimaryContainer : AppColors.primaryFixed,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  iconData,
                  color: isDark ? AppColors.darkOnPrimaryContainer : AppColors.primary,
                  size: 22,
                ),
              ),
              if (cat.isLocked)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurfaceContainerHigh : AppColors.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.lock, size: 10, color: isDark ? AppColors.darkPrimary : AppColors.primary),
                      const SizedBox(width: 2),
                      Text('Protected', style: AppTypography.labelSm()),
                    ],
                  ),
                ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                cat.name,
                style: AppTypography.labelLg(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                '${cat.recordCount} records',
                style: AppTypography.bodySm(),
              ),
              if (cat.description != null && cat.description!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  cat.description!,
                  style: AppTypography.labelSm(color: isDark ? AppColors.darkPrimary : AppColors.primary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
