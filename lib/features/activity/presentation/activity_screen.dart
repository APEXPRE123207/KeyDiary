import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/trust_badge.dart';

class ActivityScreen extends ConsumerStatefulWidget {
  const ActivityScreen({super.key});

  @override
  ConsumerState<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends ConsumerState<ActivityScreen> {
  @override
  void initState() {
    super.initState();
    // Ensure demo activity logs are populated for active vault
    final vault = ref.read(activeVaultProvider);
    if (vault != null) {
      ref.read(auditRepositoryProvider).seedDemoLogs(vault.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final logsAsync = ref.watch(auditLogsProvider);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.surface,
      appBar: AppBar(
        title: const Text('Recent Vault Activity'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppDimensions.margin),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppDimensions.spaceSm),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  TrustBadge(
                    type: TrustBadgeType.vaultEnclave,
                    customText: 'Zero Plaintext Trail',
                  ),
                  Text('Audit Ledger'),
                ],
              ),

              const SizedBox(height: AppDimensions.spaceMd),

              Text(
                'Family Vault Activity',
                style: AppTypography.headlineMd(
                  color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                ),
              ),
              const SizedBox(height: AppDimensions.spaceXs),
              Text(
                'Cryptographic audit trail of all records created, modified, and shared.',
                style: AppTypography.bodyMd(
                  color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
                ),
              ),

              const SizedBox(height: AppDimensions.spaceLg),

              logsAsync.when(
                data: (logs) {
                  if (logs.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Text('No activity recorded yet.', style: AppTypography.bodyMd()),
                      ),
                    );
                  }

                  return Column(
                    children: logs.map((log) {
                      IconData icon = Icons.bookmark_added;
                      if (log.action == 'ENTRY_UPDATED') icon = Icons.edit_note;
                      if (log.action == 'ENTRY_DELETED') icon = Icons.delete_outline;
                      if (log.action == 'MEMBER_JOINED') icon = Icons.person_add;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppDimensions.spaceSm),
                        child: AppCard(
                          child: Row(
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: isDark ? AppColors.darkPrimaryContainer : AppColors.primaryFixed,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  icon,
                                  size: 20,
                                  color: isDark ? AppColors.darkOnPrimaryContainer : AppColors.primary,
                                ),
                              ),
                              const SizedBox(width: AppDimensions.spaceSm),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(log.friendlyDescription, style: AppTypography.labelMd()),
                                    Text(
                                      DateFormatter.formatRelativeTimestamp(log.createdAt),
                                      style: AppTypography.bodySm(),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('Error loading activity: $e'),
              ),

              const SizedBox(height: AppDimensions.spaceXl * 2),
            ],
          ),
        ),
      ),
    );
  }
}
