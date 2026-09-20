import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/trust_badge.dart';
import '../domain/vault_member.dart';
import '../../auth/data/auth_repository.dart';

class FamilyVaultScreen extends ConsumerStatefulWidget {
  const FamilyVaultScreen({super.key});

  @override
  ConsumerState<FamilyVaultScreen> createState() => _FamilyVaultScreenState();
}

class _FamilyVaultScreenState extends ConsumerState<FamilyVaultScreen> {
  final _nameController = TextEditingController();
  bool _isEmergencyStoreActive = true;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _showInviteDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Invite Family Co-Guardian'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'The invited family member will be securely granted access to this vault with end-to-end key wrapping.',
            ),
            const SizedBox(height: AppDimensions.spaceMd),
            TextField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Co-Guardian Name',
                hintText: 'e.g. Child, Partner, Guardian',
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryContainer, foregroundColor: Colors.white),
            onPressed: () async {
              final name = _nameController.text.trim();
              if (name.isEmpty) return;
              final vault = ref.read(activeVaultProvider);
              final user = ref.read(currentUserProvider);
              if (vault == null) return;

              final memberEmail = AuthRepository.memberNameToEmail(name);

              Navigator.pop(ctx);
              await ref.read(vaultRepositoryProvider).inviteMember(
                vaultId: vault.id,
                invitedEmail: memberEmail,
                invitedBy: user?.id ?? 'user-dad',
              );
              ref.invalidate(vaultMembersProvider);
              _nameController.clear();

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Access granted securely to $name')),
                );
              }
            },
            child: const Text('Grant Access'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final vault = ref.watch(activeVaultProvider);
    final membersAsync = ref.watch(vaultMembersProvider);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.surface,
      appBar: AppBar(
        title: const Text('Family Vault & Co-Guardians'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppDimensions.margin),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppDimensions.spaceSm),

              // Trust Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  TrustBadge(
                    type: TrustBadgeType.vaultEnclave,
                    customText: 'Heritage Vault',
                  ),
                  TrustBadge(
                    type: TrustBadgeType.synced,
                    customText: 'Offline Encrypted',
                  ),
                ],
              ),

              const SizedBox(height: AppDimensions.spaceMd),

              // Vault Summary Card
              AppCard(
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkPrimaryContainer : AppColors.primaryFixed,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.menu_book,
                        color: isDark ? AppColors.darkOnPrimaryContainer : AppColors.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: AppDimensions.spaceMd),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(vault?.name ?? 'KeyDiary Family Vault', style: AppTypography.headlineSm()),
                          Text('2 authorized family members', style: AppTypography.bodySm()),
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
                  Text('Authorized Members', style: AppTypography.headlineSm()),
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
                  return Column(
                    children: members.map((m) => _buildMemberCard(m)).toList(),
                  );
                },
                loading: () => const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
                error: (e, _) => Text('Error: $e'),
              ),

              const SizedBox(height: AppDimensions.spaceLg),

              // Emergency Store Section (User requirement)
              Row(
                children: [
                  Icon(
                    Icons.emergency,
                    color: isDark ? AppColors.darkStatusRose : AppColors.statusRose,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text('Emergency Family Recovery Store', style: AppTypography.headlineSm()),
                ],
              ),

              const SizedBox(height: AppDimensions.spaceSm),

              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('Emergency Backup Sync', style: AppTypography.labelLg()),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text(
                          'Syncs an isolated emergency database schema (emergency_vault) accessible only in documented family emergency scenarios.',
                          style: AppTypography.bodySm(),
                        ),
                      ),
                      value: _isEmergencyStoreActive,
                      activeThumbColor: isDark ? AppColors.darkPrimary : AppColors.primary,
                      onChanged: (val) {
                        setState(() => _isEmergencyStoreActive = val);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(val
                                ? 'Emergency recovery store enabled.'
                                : 'Emergency recovery store paused.'),
                          ),
                        );
                      },
                    ),
                    const Divider(),
                    Padding(
                      padding: const EdgeInsets.only(top: AppDimensions.spaceSm),
                      child: Row(
                        children: [
                          Icon(
                            Icons.check_circle_outline,
                            size: 16,
                            color: isDark ? AppColors.darkStatusGreen : AppColors.statusGreen,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Status: Active • emergency_vault schema synced',
                            style: AppTypography.labelSm(
                              color: isDark ? AppColors.darkStatusGreen : AppColors.statusGreen,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppDimensions.spaceLg),

              AppButton(
                text: 'Invite Family Co-Guardian',
                leadingIcon: Icons.add,
                width: double.infinity,
                onPressed: _showInviteDialog,
              ),

              const SizedBox(height: AppDimensions.spaceXl * 2),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMemberCard(VaultMember m) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isOwner = m.role == VaultRole.owner;

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
                    ? (isDark ? AppColors.darkPrimaryContainer : AppColors.primaryContainer)
                    : (isDark ? AppColors.darkSecondaryContainer : AppColors.secondaryContainer),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  m.displayName?.isNotEmpty == true ? m.displayName![0].toUpperCase() : 'M',
                  style: TextStyle(
                    color: isOwner ? Colors.white : (isDark ? Colors.white : AppColors.onSurface),
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
                      Text(m.displayName ?? 'Family Member', style: AppTypography.labelLg()),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkSurfaceContainerHigh : AppColors.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                        ),
                        child: Text(
                          isOwner ? 'Owner' : 'Co-Guardian',
                          style: AppTypography.labelSm(),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    isOwner ? 'Primary Vault Administrator' : 'Authorized Co-Guardian',
                    style: AppTypography.bodySm(),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.verified_user,
              size: 20,
              color: isDark ? AppColors.darkStatusGreen : AppColors.statusGreen,
            ),
          ],
        ),
      ),
    );
  }
}
