import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/trust_badge.dart';
import '../domain/vault_member.dart';

class FamilyVaultScreen extends ConsumerStatefulWidget {
  const FamilyVaultScreen({super.key});

  @override
  ConsumerState<FamilyVaultScreen> createState() => _FamilyVaultScreenState();
}

class _FamilyVaultScreenState extends ConsumerState<FamilyVaultScreen> {
  final _nameController = TextEditingController();
  bool _emergencySyncEnabled = true;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _showInviteDialog() async {
    if (!ref.read(isVaultOwnerProvider)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only Vault Admins can invite new Co-Guardians.')),
      );
      return;
    }

    String? dialogError;
    bool isSearching = false;

    // Load ALL registered Co-Guardians across device and online
    final vaultRepo = ref.read(vaultRepositoryProvider);
    final allRegistered = await vaultRepo.getAllRegisteredCoGuardians();
    final activeMembers = ref.read(vaultMembersProvider).value ?? [];
    final registeredCandidates = allRegistered.where((c) {
      final cId = c['user_id'] as String? ?? '';
      final cName = (c['display_name'] as String? ?? '').toLowerCase();
      final alreadyInVault = activeMembers.any((m) =>
          (cId.isNotEmpty && m.userId == cId) ||
          (m.displayName != null && m.displayName!.trim().toLowerCase() == cName));
      return !alreadyInVault;
    }).toList();

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          return AlertDialog(
            backgroundColor: isDark ? AppColors.darkSurfaceContainer : AppColors.surfaceContainer,
            title: const Text('Invite Family Co-Guardian'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'The family member must have an existing KeyDiary account. Enter their registered username to grant access to this vault.',
                  ),
                  if (registeredCandidates.isNotEmpty) ...[
                    const SizedBox(height: AppDimensions.spaceSm),
                    Text(
                      'Registered Co-Guardians available:',
                      style: AppTypography.labelSm(context: ctx),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: registeredCandidates.map((c) {
                        final cName = c['display_name'] as String? ?? 'Co-Guardian';
                        return ActionChip(
                          avatar: const Icon(Icons.person_add_alt_1, size: 16),
                          label: Text(cName),
                          onPressed: () {
                            setDialogState(() {
                              _nameController.text = cName;
                              dialogError = null;
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ],
                  const SizedBox(height: AppDimensions.spaceMd),
                  TextField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: 'Registered Member Username',
                      hintText: 'Enter registered username',
                      prefixIcon: const Icon(Icons.person_outline),
                      errorText: dialogError,
                    ),
                  ),
                  if (isSearching)
                    const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: isSearching
                    ? null
                    : () async {
                        final name = _nameController.text.trim();
                        if (name.isEmpty) {
                          setDialogState(() => dialogError = 'Please enter a name');
                          return;
                        }
                        final vault = ref.read(activeVaultProvider);
                        final user = ref.read(currentUserProvider);
                        if (vault == null) return;

                        setDialogState(() {
                          isSearching = true;
                          dialogError = null;
                        });

                        try {
                          final authRepo = ref.read(authRepositoryProvider);
                          final vaultRepo = ref.read(vaultRepositoryProvider);
                          final targetUser = await vaultRepo.findUser(
                            query: name,
                            localUsers: await authRepo.getRegisteredUsers(),
                          );

                          if (targetUser == null) {
                            setDialogState(() {
                              isSearching = false;
                              dialogError = 'No registered member found for "$name".\nPlease ask them to sign up for KeyDiary first.';
                            });
                            return;
                          }

                          final vek = ref.read(vaultKeyProvider);
                          await vaultRepo.inviteMember(
                            vaultId: vault.id,
                            invitedEmail: targetUser['email'] as String,
                            invitedBy: user?.id ?? 'owner',
                            targetUserId: targetUser['user_id'] as String,
                            targetDisplayName: targetUser['display_name'] as String,
                            vekBytes: vek,
                          );

                          ref.invalidate(vaultMembersProvider);
                          ref.read(auditRepositoryProvider).logAction(
                            vaultId: vault.id,
                            userId: user?.id ?? 'user',
                            userDisplayName: user?.displayName ?? 'Admin',
                            action: 'MEMBER_JOINED',
                            entityType: 'MEMBER',
                            metadata: {'title_hint': targetUser['display_name'] as String},
                          );
                          ref.invalidate(auditLogsProvider);
                          _nameController.clear();
                          if (!ctx.mounted) return;
                          Navigator.pop(ctx);

                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Access granted to ${targetUser['display_name']}')),
                            );
                          }
                        } catch (e) {
                          setDialogState(() {
                            isSearching = false;
                            dialogError = e.toString().replaceAll('Exception: ', '');
                          });
                        }
                      },
                child: const Text('Verify & Grant Access'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _confirmRemoveMember(VaultMember m) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Revoke Access for ${m.displayName ?? "Member"}?'),
        content: const Text(
          'This member will immediately lose access to all encrypted vaults and sensitive records.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.statusRose),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Revoke Access'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final vault = ref.read(activeVaultProvider);
      final user = ref.read(currentUserProvider);
      if (vault != null) {
        await ref.read(vaultRepositoryProvider).removeMember(
          vaultId: vault.id,
          memberId: m.id,
        );
        ref.read(auditRepositoryProvider).logAction(
          vaultId: vault.id,
          userId: user?.id ?? 'user',
          userDisplayName: user?.displayName ?? 'Admin',
          action: 'ENTRY_DELETED',
          entityType: 'MEMBER',
          metadata: {'title_hint': m.displayName ?? 'Member'},
        );
        ref.invalidate(vaultMembersProvider);
        ref.invalidate(auditLogsProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${m.displayName ?? "Member"} removed from Family Vault.')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final vault = ref.watch(activeVaultProvider);
    final membersAsync = ref.watch(vaultMembersProvider);
    final isOwner = ref.watch(isVaultOwnerProvider);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.surface,
      appBar: AppBar(
        title: const Text('Family Vault Access'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppDimensions.margin),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppDimensions.spaceSm),

              // Trust Bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Flexible(
                    child: TrustBadge(
                      type: TrustBadgeType.vaultEnclave,
                      customText: 'Zero-Knowledge Group',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(ref.watch(isVaultOwnerProvider) ? 'Admin Controls' : 'Co-Guardian View'),
                ],
              ),

              const SizedBox(height: AppDimensions.spaceMd),

              // Emergency Backup Sync Toggle Card
              AppCard(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Icon(
                            Icons.backup_outlined,
                            color: isDark ? AppColors.darkPrimary : AppColors.primary,
                            size: 22,
                          ),
                          const SizedBox(width: AppDimensions.spaceSm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Emergency Backup Sync',
                                  style: AppTypography.headlineSm(context: context),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (!isOwner) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    'Managed by Vault Admin • Read-Only',
                                    style: AppTypography.bodySm(
                                      color: isDark ? AppColors.darkOutline : AppColors.outline,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Switch.adaptive(
                      value: _emergencySyncEnabled,
                      activeTrackColor: isDark ? AppColors.darkPrimary : AppColors.primary,
                      onChanged: isOwner
                          ? (val) {
                              setState(() => _emergencySyncEnabled = val);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(val
                                      ? 'Emergency vault sync enabled.'
                                      : 'Emergency vault sync paused.'),
                                ),
                              );
                            }
                          : null,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppDimensions.spaceMd),

              // Vault Encryption Key Card
              AppCard(
                child: Row(
                  children: [
                    Icon(Icons.vpn_key_outlined, color: isDark ? AppColors.darkPrimary : AppColors.primary, size: 20),
                    const SizedBox(width: AppDimensions.spaceSm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Vault Encryption Key (VEK)', style: AppTypography.labelMd()),
                          Text(
                            'Shared securely via envelope encryption',
                            style: AppTypography.bodySm(
                              color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurfaceContainerHighest : AppColors.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'AES-256',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppColors.darkPrimary : AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppDimensions.spaceMd),

              // Active Vault Summary Card
              AppCard(
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkPrimaryContainer : AppColors.primaryFixed,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.shield_outlined,
                        color: isDark ? AppColors.darkOnPrimaryContainer : AppColors.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: AppDimensions.spaceMd),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(vault?.name ?? 'KeyDiary Family Vault', style: AppTypography.headlineSm(context: context)),
                          Text('${membersAsync.asData?.value.length ?? 1} authorized family ${(membersAsync.asData?.value.length ?? 1) == 1 ? "member" : "members"}', style: AppTypography.bodySm(context: context)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppDimensions.spaceLg),

              // Members List
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text('Authorized Members', style: AppTypography.headlineSm(context: context), overflow: TextOverflow.ellipsis),
                  ),
                  if (ref.watch(isVaultOwnerProvider))
                    TextButton.icon(
                      onPressed: _showInviteDialog,
                      icon: const Icon(Icons.person_add, size: 16),
                      label: const Text('Invite'),
                    ),
                ],
              ),

              const SizedBox(height: AppDimensions.spaceSm),

              membersAsync.when(
                data: (members) {
                  final seen = <String>{};
                  final deduped = <VaultMember>[];
                  for (final m in members) {
                    final key = (m.displayName ?? '').trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
                    if (key.isNotEmpty && seen.contains(key)) continue;
                    if (key.isNotEmpty) seen.add(key);
                    deduped.add(m);
                  }
                  return Column(
                    children: deduped.map((m) => _buildMemberCard(m)).toList(),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('Error loading members: $e'),
              ),

              const SizedBox(height: AppDimensions.spaceXl),

              // Co-Guardian Role Description Card
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 18,
                          color: isDark ? AppColors.darkPrimary : AppColors.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Co-Guardian Permissions',
                          style: AppTypography.labelMd(
                            color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppDimensions.spaceSm),
                    Text(
                      '• Co-Guardians have secure read-only access to records.\n'
                      '• Emergency backup controls are managed exclusively by Vault Admins.\n'
                      '• Sensitive values like locker codes remain encrypted.\n'
                      '• All view and export events are immutably logged.',
                      style: AppTypography.bodySm(
                        color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppDimensions.spaceXl),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMemberCard(VaultMember m) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentAuth = ref.watch(currentUserProvider);
    final vault = ref.watch(activeVaultProvider);
    final rawName = m.displayName?.trim();
    final isChild = (rawName != null && rawName.toLowerCase().contains('child')) ||
        (m.email != null && m.email!.toLowerCase().contains('child'));
    final isOwner = m.role == VaultRole.owner && !isChild;

    final isCurrentUser = currentAuth != null &&
        (m.userId == currentAuth.id ||
         (rawName != null && rawName.toLowerCase() == currentAuth.displayName.toLowerCase()));

    // Dynamically resolve owner / admin name from vault name (e.g. "Deb's Family Vault" -> "Deb")
    String? vaultAdminName;
    if (vault?.name != null && vault!.name.isNotEmpty) {
      final match = RegExp(r"^(.+?)'s\s+", caseSensitive: false).firstMatch(vault.name);
      if (match != null && match.group(1)!.trim().isNotEmpty) {
        vaultAdminName = match.group(1)!.trim();
      }
    }

    String effectiveDisplayName;
    if (isCurrentUser) {
      effectiveDisplayName = currentAuth.displayName;
    } else if (rawName != null && rawName.isNotEmpty && !['owner', 'admin', 'primary guardian', 'member', 'null'].contains(rawName.toLowerCase())) {
      effectiveDisplayName = rawName;
    } else if (isOwner) {
      if (currentAuth?.isAdmin == true) {
        effectiveDisplayName = currentAuth!.displayName;
      } else if (vaultAdminName != null && vaultAdminName.isNotEmpty) {
        effectiveDisplayName = vaultAdminName;
      } else {
        effectiveDisplayName = 'Admin';
      }
    } else {
      effectiveDisplayName = 'Co-Guardian';
    }

    if (effectiveDisplayName == 'Member' || effectiveDisplayName == 'null') {
      effectiveDisplayName = isOwner ? (vaultAdminName ?? 'Admin') : 'Co-Guardian';
    }

    final displayNameWithYou = isCurrentUser ? '$effectiveDisplayName (You)' : effectiveDisplayName;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.spaceSm),
      child: AppCard(
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isOwner
                    ? (isDark ? AppColors.darkPrimaryContainer : AppColors.primary)
                    : (isDark ? AppColors.darkSecondaryContainer : AppColors.primaryFixed),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  effectiveDisplayName.isNotEmpty ? effectiveDisplayName[0].toUpperCase() : 'A',
                  style: TextStyle(
                    color: isOwner
                        ? (isDark ? AppColors.darkPrimary : Colors.white)
                        : (isDark ? AppColors.darkSecondary : AppColors.primary),
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppDimensions.spaceMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          displayNameWithYou,
                          style: AppTypography.labelLg(context: context),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkSurfaceContainerHigh : AppColors.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                        ),
                        child: Text(
                          isOwner ? 'Admin' : 'Co-Guardian',
                          style: AppTypography.labelSm(context: context),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    isOwner ? 'Vault Administrator' : 'Authorized Co-Guardian',
                    style: AppTypography.bodySm(context: context),
                  ),
                ],
              ),
            ),
            if (isOwner)
              Icon(
                Icons.verified_user,
                size: 20,
                color: isDark ? AppColors.darkStatusGreen : AppColors.statusGreen,
              )
            else if (ref.watch(isVaultOwnerProvider))
              IconButton(
                icon: const Icon(
                  Icons.person_remove_outlined,
                  size: 20,
                  color: Colors.redAccent,
                ),
                tooltip: 'Revoke Access',
                onPressed: () => _confirmRemoveMember(m),
              ),
          ],
        ),
      ),
    );
  }
}
