import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../../core/network/supabase_client.dart';
import '../../../app/providers.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/security/biometric_service.dart';
import '../../../core/security/pin_service.dart';
import '../../../core/security/secure_storage_service.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/trust_badge.dart';
import '../../vault/domain/vault.dart';
import '../../vault/domain/vault_member.dart';
import '../domain/category.dart';
import '../../entries/data/entry_repository.dart';

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
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    final vaultRepo = ref.read(vaultRepositoryProvider);
    final catRepo = ref.read(categoryRepositoryProvider);

    Vault? targetVault;

    // 0. If Supabase is connected, query remote vault membership directly first
    if (SupabaseService.isInitialized) {
      try {
        final client = Supabase.instance.client;
        final sbUser = client.auth.currentUser;
        if (sbUser != null) {
          final remoteMemberships = await client
              .from('vault_members')
              .select('vault_id, encrypted_vault_key, role, vaults(*)')
              .eq('user_id', sbUser.id);
          for (final m in (remoteMemberships as List)) {
            final vJson = m['vaults'];
            if (vJson != null && vJson is Map<String, dynamic>) {
              targetVault = Vault.fromJson(vJson);
              final encKey = m['encrypted_vault_key'] as String?;
              if (encKey != null && encKey.isNotEmpty && encKey != 'wrapped_key_placeholder') {
                try {
                  final kBytes = base64Decode(encKey);
                  ref.read(vaultKeyProvider.notifier).state = kBytes;
                  await SecureStorageService.saveVaultKey(targetVault.id, kBytes);
                } catch (_) {}
              }
              break;
            }
          }
        }
      } catch (e) {
        debugPrint('[HomeScreen] Remote membership lookup error: $e');
      }
    }

    if (targetVault == null) {
      final vaults = await vaultRepo.getUserVaults(
        user.id,
        displayName: user.displayName,
        email: user.email,
        role: user.role,
      );

      if (vaults.isNotEmpty) {
        targetVault = vaults.first;
      } else if (user.isCoGuardian || user.role.toUpperCase() == 'CO_GUARDIAN' || user.role.toUpperCase() == 'MEMBER') {
        final allVaults = await vaultRepo.getAllVaults();
        if (allVaults.isNotEmpty) {
          targetVault = allVaults.first;
        } else {
          ref.read(activeVaultProvider.notifier).state = null;
          ref.read(vaultKeyProvider.notifier).state = null;
          if (mounted) setState(() {});
          return;
        }
      } else {
        final vek = Uint8List.fromList(List.generate(32, (i) => (i * 7 + 13) % 256));
        targetVault = await vaultRepo.createVault(
          name: '${user.displayName}\'s Family Vault',
          userId: user.id,
          vekBytes: vek,
          displayName: user.displayName,
        );
        await catRepo.seedDefaultCategories(vaultId: targetVault.id, userId: user.id);
      }
    }

    targetVault = await vaultRepo.ensureValidUuidVault(targetVault);
    ref.read(activeVaultProvider.notifier).state = targetVault;
    await SecureStorageService.setActiveVaultId(targetVault.id);

    // Retrieve VEK for current user (shared with co-guardian or owned)
    Uint8List? vek = ref.read(vaultKeyProvider);
    if (vek == null) {
      vek = await vaultRepo.getVaultKey(
        vaultId: targetVault.id,
        userId: user.id,
        displayName: user.displayName,
        email: user.email,
      );
      if (vek != null) {
        ref.read(vaultKeyProvider.notifier).state = vek;
        await SecureStorageService.saveVaultKey(targetVault.id, vek);
      }
    }

    // 1. Ensure Vault and membership exist in Supabase for Admin/Owner
    if (SupabaseService.isInitialized) {
      try {
        final client = Supabase.instance.client;
        final sbUser = client.auth.currentUser;
        if (sbUser != null && (user.isAdmin || !user.isCoGuardian)) {
          // A. Upsert Vault so foreign key constraints on vault_id work
          await client.from('vaults').upsert({
            'id': targetVault.id,
            'name': targetVault.name,
            'created_by': sbUser.id,
          });

          // B. Upsert current user in vault_members
          await client.from('vault_members').upsert({
            'vault_id': targetVault.id,
            'user_id': sbUser.id,
            'role': 'OWNER',
            'encrypted_vault_key': vek != null ? base64Encode(vek) : 'wrapped_key_placeholder',
          }, onConflict: 'vault_id, user_id');

          // C. If Admin, auto-enroll all other members and sync categories
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

            // D. Sync all local Categories to Supabase
            try {
              final localCats = await catRepo.getCategories(targetVault.id);
              for (final c in localCats) {
                await client.from('categories').upsert({
                  'id': c.id,
                  'vault_id': targetVault.id,
                  'name': c.name,
                  'description': c.description,
                  'icon': c.icon,
                  'color': c.color,
                  'position': c.position,
                  'is_locked': c.isLocked,
                  'created_by': sbUser.id,
                });
              }
            } catch (_) {}
          }
        }
      } catch (e) {
        debugPrint('[HomeScreen] Vault online sync error: $e');
      }
    }

    // 2. Now that vault, categories, and membership exist, sync all entries
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

    // 3. Ensure categories exist in target vault
    final existingCats = await catRepo.getCategories(targetVault.id);
    if (existingCats.isEmpty) {
      await catRepo.seedDefaultCategories(vaultId: targetVault.id, userId: targetVault.createdBy);
    }

    // Refresh categories & members & entries
    if (!mounted) return;
    ref.invalidate(categoriesProvider);
    ref.invalidate(vaultMembersProvider);
    ref.invalidate(vaultEntriesProvider);
  }

  Future<bool> _promptPinDialog(String categoryName) async {
    final pinCtrl = TextEditingController();
    String? error;

    final success = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          return AlertDialog(
            backgroundColor: isDark ? AppColors.darkSurfaceContainer : AppColors.surfaceContainer,
            title: Text('Unlock $categoryName', style: AppTypography.headlineSm()),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Enter your 6-digit Master PIN to open this protected category.',
                  style: AppTypography.bodySm(),
                ),
                const SizedBox(height: AppDimensions.spaceMd),
                TextField(
                  controller: pinCtrl,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  obscureText: true,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: '6-Digit PIN',
                    errorText: error,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () async {
                  final pin = pinCtrl.text.trim();
                  if (pin.length != 6) {
                    setDialogState(() => error = 'Enter 6 digits');
                    return;
                  }
                  final storedHash = await SecureStorageService.getPinHash();
                  if (!ctx.mounted) return;
                  if (storedHash == null) {
                    Navigator.pop(ctx, true);
                    return;
                  }
                  final valid = await PinService.verifyPin(pin, storedHash);
                  if (!ctx.mounted) return;
                  if (valid) {
                    Navigator.pop(ctx, true);
                  } else {
                    setDialogState(() => error = 'Incorrect PIN');
                  }
                },
                child: const Text('Unlock'),
              ),
            ],
          );
        },
      ),
    );

    return success ?? false;
  }

  Future<void> _openCategory(Category category) async {
    if (category.isLocked) {
      bool authenticated = false;
      final canBio = await BiometricService.canAuthenticate();
      if (canBio) {
        authenticated = await BiometricService.authenticate(
          reason: 'Authenticate to view protected category "${category.name}"',
        );
      }
      if (!authenticated) {
        if (!mounted) return;
        authenticated = await _promptPinDialog(category.name);
      }
      if (!authenticated) {
        return;
      }
    }

    if (!mounted) return;
    context.push('/category/${category.id}', extra: category);
  }

  void _showAddCategoryDialog() {
    if (!ref.read(isVaultOwnerProvider)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only Vault Admins can create new categories.')),
      );
      return;
    }

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
                Text('Add New Category', style: AppTypography.headlineSm(context: ctx)),
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
                  title: Text('Require Biometric Lock', style: AppTypography.labelMd(context: ctx)),
                  subtitle: Text('Requires fingerprint/PIN every time it is opened', style: AppTypography.bodySm(context: ctx)),
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
                      backgroundColor: AppColors.accent(isDark),
                      foregroundColor: AppColors.textOnAccent(isDark),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusFull)),
                    ),
                    onPressed: () async {
                      final name = nameCtrl.text.trim();
                      if (name.isEmpty) return;
                      final vault = ref.read(activeVaultProvider);
                      if (vault == null) return;

                      final cat = Category(
                        id: const Uuid().v4(),
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
                    child: Text('Create Category', style: AppTypography.labelLg(color: AppColors.textOnAccent(isDark))),
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
    final isOwner = ref.watch(isVaultOwnerProvider);
    final vault = ref.watch(activeVaultProvider);
    final members = ref.watch(vaultMembersProvider).asData?.value ?? [];

    // Dynamically resolve Admin and Co-Guardian names and initials
    final adminMember = members.where((m) => m.role == VaultRole.owner).firstOrNull;
    String adminName = adminMember?.displayName?.trim() ?? '';
    if (adminName.isEmpty || ['owner', 'admin', 'primary guardian', 'member', 'null'].contains(adminName.toLowerCase())) {
      if (user != null && user.isAdmin) {
        adminName = user.displayName.trim();
      } else if (vault?.name != null && vault!.name.isNotEmpty) {
        final match = RegExp(r"^(.+?)'s\s+", caseSensitive: false).firstMatch(vault.name);
        if (match != null && match.group(1)!.trim().isNotEmpty) {
          adminName = match.group(1)!.trim();
        }
      }
    }
    if (adminName.isEmpty || ['owner', 'admin', 'primary guardian', 'member', 'null'].contains(adminName.toLowerCase())) {
      adminName = 'Admin';
    }
    final adminInitial = adminName.isNotEmpty ? adminName[0].toUpperCase() : 'A';

    final coGuardianMember = members.where((m) => m.role == VaultRole.member).firstOrNull;
    String? coGuardianName = coGuardianMember?.displayName?.trim();
    if (coGuardianName == null || coGuardianName.isEmpty) {
      if (user != null && user.isCoGuardian) {
        coGuardianName = user.displayName.trim();
      }
    }
    final coGuardianInitial = (coGuardianName != null && coGuardianName.isNotEmpty)
        ? coGuardianName[0].toUpperCase()
        : null;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.surface,
      body: SizedBox.expand(
        child: Container(
          decoration: BoxDecoration(
            gradient: AppColors.bgGradient(isDark),
          ),
          child: SafeArea(
            child: RefreshIndicator(
              color: isDark ? AppColors.darkPrimary : AppColors.primary,
              backgroundColor: isDark ? AppColors.darkSurfaceContainer : AppColors.surfaceContainer,
              displacement: 40,
              strokeWidth: 2.5,
              onRefresh: () async {
                await _ensureVaultLoaded();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Vault synced and updated!'),
                      duration: Duration(milliseconds: 1500),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                padding: const EdgeInsets.symmetric(horizontal: AppDimensions.margin),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: AppDimensions.spaceSm),

                    // Top Header with KeyDiary Title and action icons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: isDark ? AppColors.darkPrimaryContainer : AppColors.primaryFixed,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.menu_book,
                                size: 18,
                                color: isDark ? AppColors.darkPrimary : AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'KeyDiary',
                              style: AppTypography.diaryTitle(
                                color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                                fontSize: 20,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: Icon(
                                Icons.sync,
                                color: isDark ? AppColors.darkPrimary : AppColors.primary,
                              ),
                              tooltip: 'Sync Vault',
                              onPressed: () async {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Syncing with Supabase...'), duration: Duration(seconds: 1)),
                                );
                                await _ensureVaultLoaded();
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Vault synced successfully!'), duration: Duration(seconds: 1)),
                                  );
                                }
                              },
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.notifications_none,
                                color: isDark ? AppColors.darkOutline : AppColors.outline,
                              ),
                              onPressed: () => context.push('/activity'),
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.people_outline,
                                color: isDark ? AppColors.darkOutline : AppColors.outline,
                              ),
                              tooltip: 'Family Vault Members',
                              onPressed: () => context.push('/family-vault'),
                            ),
                          ],
                        ),
                      ],
                    ),

                const SizedBox(height: AppDimensions.spaceSm),

                // Trust & Greeting Header
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: TrustBadge(
                        type: TrustBadgeType.vaultEnclave,
                        customText: 'End-to-End Vault',
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
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Good day, ${user?.displayName ?? "Member"}',
                            style: AppTypography.bodySm(
                              color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Welcome back',
                            style: AppTypography.diaryTitle(
                              color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                              fontSize: 26,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Dynamic Admin & Co-Guardian Avatar Pair
                    Row(
                      children: [
                        Tooltip(
                          message: 'Admin: $adminName',
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isDark ? AppColors.darkPrimaryContainer : AppColors.primaryFixed,
                              border: Border.all(
                                color: isDark ? AppColors.darkPrimary : AppColors.primary,
                                width: 1.5,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                adminInitial,
                                style: TextStyle(
                                  color: isDark ? AppColors.darkPrimary : AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Tooltip(
                          message: coGuardianName != null
                              ? 'Co-Guardian: $coGuardianName'
                              : 'No Co-Guardian registered',
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isDark ? const Color(0x247CCBB4) : AppColors.primaryFixedDim,
                              border: Border.all(
                                color: (coGuardianInitial != null)
                                    ? (isDark ? AppColors.darkPrimary : AppColors.primary)
                                    : (isDark ? AppColors.darkOutline : AppColors.outline),
                                width: 1.5,
                              ),
                            ),
                            child: Center(
                              child: coGuardianInitial != null
                                  ? Text(
                                      coGuardianInitial,
                                      style: TextStyle(
                                        color: isDark ? AppColors.darkPrimary : AppColors.primary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    )
                                  : Icon(
                                      Icons.person_add_outlined,
                                      size: 16,
                                      color: isDark ? AppColors.darkOutline : AppColors.outline,
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

              const SizedBox(height: AppDimensions.spaceMd),

              if (user != null && user.isCoGuardian && vault == null) ...[
                AppCard(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                    child: Column(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkPrimaryContainer : AppColors.primaryFixed,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.shield_outlined,
                            size: 28,
                            color: isDark ? AppColors.darkPrimary : AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Waiting for Vault Access',
                          style: AppTypography.headlineSm(context: context),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'You are registered as a Family Co-Guardian.\n\nAsk your Vault Admin (Dad) to invite your username:\n"${user.displayName}"\nfrom the Family Vault tab.',
                          style: AppTypography.bodySm(context: context),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          onPressed: _ensureVaultLoaded,
                          icon: const Icon(Icons.refresh, size: 18),
                          label: const Text('Check for Access'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppDimensions.spaceXl * 2),
              ] else ...[
                // High-Trust Co-Guardian Notice Card
                AppCard(
                  onTap: () => context.push('/family-vault'),
                child: Row(
                  children: [
                    // Dual Admin + Co-Guardian visual badge
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Tooltip(
                          message: 'Admin: $adminName',
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isDark ? AppColors.darkPrimaryContainer : AppColors.primaryFixed,
                              border: Border.all(
                                color: isDark ? AppColors.darkPrimary : AppColors.primary,
                                width: 1.5,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                adminInitial,
                                style: TextStyle(
                                  color: isDark ? AppColors.darkPrimary : AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Transform.translate(
                          offset: const Offset(-8, 0),
                          child: Tooltip(
                            message: coGuardianName != null
                                ? 'Co-Guardian: $coGuardianName'
                                : 'No Co-Guardian registered',
                            child: Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isDark ? const Color(0x247CCBB4) : AppColors.primaryFixedDim,
                                border: Border.all(
                                  color: isDark ? AppColors.darkSurface : AppColors.surface,
                                  width: 2,
                                ),
                              ),
                              child: Center(
                                child: coGuardianInitial != null
                                    ? Text(
                                        coGuardianInitial,
                                        style: TextStyle(
                                          color: isDark ? AppColors.darkPrimary : AppColors.primary,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      )
                                    : Icon(
                                        Icons.person_add_outlined,
                                        size: 16,
                                        color: isDark ? AppColors.darkOutline : AppColors.outline,
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: AppDimensions.spaceSm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  'Shared Vault',
                                  style: AppTypography.labelMd(
                                    color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: isDark ? AppColors.darkSurfaceContainerHigh : AppColors.surfaceContainerHigh,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(isOwner ? 'Admin' : 'Co-Guardian', style: AppTypography.labelSm(context: context)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Last synced today • End-to-end secured',
                            style: AppTypography.bodySm(
                              color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
                            ),
                            overflow: TextOverflow.ellipsis,
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
              // Rounded search bar with frosted fill per design.md
              InkWell(
                onTap: () => context.push('/search'),
                borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                child: Container(
                  height: AppDimensions.inputHeight,
                  padding: const EdgeInsets.symmetric(horizontal: AppDimensions.spaceMd),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.cardFillDark : AppColors.cardFillLight,
                    borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                    border: Border.all(
                      color: isDark ? AppColors.cardBorderDark : AppColors.cardBorderLight,
                      width: 1.0,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.search,
                        color: isDark ? AppColors.darkPrimary : AppColors.primary,
                        size: 20,
                      ),
                      const SizedBox(width: AppDimensions.spaceSm),
                      Expanded(
                        child: Text(
                          'Search your vault...',
                          style: AppTypography.bodySm(
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
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Text(
                          'Your Information',
                          style: AppTypography.headlineSm(context: context),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkPrimaryContainer : AppColors.primaryFixed,
                            borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                          ),
                          child: Text(
                            '${categoriesAsync.asData?.value.fold<int>(0, (sum, c) => sum + c.recordCount) ?? 0} entries',
                            style: AppTypography.labelSm(
                              color: isDark ? AppColors.darkPrimary : AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isOwner)
                    IconButton(
                      tooltip: 'Add Category',
                      visualDensity: VisualDensity.compact,
                      onPressed: _showAddCategoryDialog,
                      icon: const Icon(Icons.add_circle_outline, size: 22),
                    ),
                ],
              ),

              const SizedBox(height: AppDimensions.spaceSm),

              // 2-Column Category Grid with New Category Action Card per design.md
              categoriesAsync.when(
                data: (categories) {
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.95,
                    ),
                    itemCount: isOwner ? categories.length + 1 : categories.length,
                    itemBuilder: (context, index) {
                      if (index < categories.length) {
                        final cat = categories[index];
                        return _buildCategoryCard(cat);
                      } else {
                        return _buildNewCategoryCard(isDark);
                      }
                    },
                  );
                },
                loading: () => _buildCategoryGridSkeleton(isDark),
                error: (e, _) => Center(child: Text('Error loading categories: $e')),
              ),

              const SizedBox(height: AppDimensions.spaceXl * 2),
              ],
            ],
          ),
        ),
      ),
    ),
    ),
    ),
      // Bottom tab bar: Home, Activity, Family, Settings per design.md
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentNavIndex,
        onDestinationSelected: (idx) {
          setState(() => _currentNavIndex = idx);
          if (idx == 1) context.push('/activity');
          if (idx == 2) context.push('/family-vault');
          if (idx == 3) context.push('/settings');
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.history),
            label: 'Activity',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Family',
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

  Widget _buildCategoryGridSkeleton(bool isDark) {
    final shimmerBase = isDark ? const Color(0xFF162320) : const Color(0xFFE8EDE9);
    final shimmerHighlight = isDark ? const Color(0xFF1E2E2A) : const Color(0xFFF3F7F4);

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.95,
      ),
      itemCount: 4,
      itemBuilder: (context, index) {
        return AppCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: shimmerBase,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: shimmerBase,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 90,
                    height: 14,
                    decoration: BoxDecoration(
                      color: shimmerHighlight,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 50,
                    height: 10,
                    decoration: BoxDecoration(
                      color: shimmerBase,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
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
        iconData = Icons.vpn_key;
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
      padding: const EdgeInsets.all(14),
      border: cat.isLocked
          ? BorderSide(
              color: isDark ? AppColors.darkPrimary : AppColors.primary,
              width: 1.5,
            )
          : null,
      onTap: () => _openCategory(cat),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Accent icon chip
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkPrimaryContainer : AppColors.primaryFixed,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  iconData,
                  color: isDark ? AppColors.darkPrimary : AppColors.primary,
                  size: 20,
                ),
              ),
              if (cat.isLocked)
                Icon(
                  Icons.lock_outline,
                  size: 16,
                  color: isDark ? AppColors.darkPrimary : AppColors.primary,
                ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                cat.name,
                style: AppTypography.labelLg().copyWith(
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                '${cat.recordCount} records',
                style: AppTypography.bodySm(
                  color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNewCategoryCard(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        border: Border.all(
          color: (isDark ? AppColors.darkPrimary : AppColors.primary).withAlpha(120),
          width: 1.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _showAddCategoryDialog,
          borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkPrimaryContainer : AppColors.primaryFixed,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.add,
                    color: isDark ? AppColors.darkPrimary : AppColors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'New category',
                  style: AppTypography.labelMd(
                    color: isDark ? AppColors.darkPrimary : AppColors.primary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Add section',
                  style: AppTypography.labelSm(
                    color: isDark ? AppColors.darkOutline : AppColors.outline,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
