import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/providers.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/trust_badge.dart';
import '../domain/category.dart';
import '../../entries/domain/entry.dart';
import '../../entries/domain/entry_field.dart';

class CategoryDetailScreen extends ConsumerStatefulWidget {
  final String categoryId;
  final Category? category;

  const CategoryDetailScreen({
    super.key,
    required this.categoryId,
    this.category,
  });

  @override
  ConsumerState<CategoryDetailScreen> createState() => _CategoryDetailScreenState();
}

class _CategoryDetailScreenState extends ConsumerState<CategoryDetailScreen> {
  bool _hideBalances = false;
  String _searchQuery = '';

  String _formatIndianCurrency(double amount) {
    if (amount == 0) return '₹0';
    final isNegative = amount < 0;
    int intPart = amount.abs().round();
    final s = intPart.toString();
    if (s.length <= 3) {
      return '${isNegative ? "-₹" : "₹"}$s';
    }
    final last3 = s.substring(s.length - 3);
    var remaining = s.substring(0, s.length - 3);
    final result = StringBuffer();
    while (remaining.length > 2) {
      result.write(',${remaining.substring(remaining.length - 2)}');
      remaining = remaining.substring(0, remaining.length - 2);
    }
    return '${isNegative ? "-₹" : "₹"}$remaining$result,$last3';
  }

  double _extractAmount(Entry entry) {
    for (final f in entry.fields) {
      if (f.fieldType == EntryFieldType.currency ||
          f.fieldName.toLowerCase().contains('amount') ||
          f.fieldName.toLowerCase().contains('sum assured') ||
          f.fieldName.toLowerCase().contains('deposit')) {
        final cleaned = f.fieldValue.replaceAll(RegExp(r'[^0-9.]'), '');
        final val = double.tryParse(cleaned);
        if (val != null && val > 0) return val;
      }
    }
    return 0;
  }

  Future<void> _confirmDeleteCategory(List<Entry> entries) async {
    final catName = widget.category?.name ?? 'this category';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "$catName"?'),
        content: Text(
          'This action will permanently delete the category and all ${entries.length} entries inside it. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.statusRose),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete Category'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        final catRepo = ref.read(categoryRepositoryProvider);
        final entryRepo = ref.read(entryRepositoryProvider);
        final auditRepo = ref.read(auditRepositoryProvider);
        final vault = ref.read(activeVaultProvider);
        final user = ref.read(currentUserProvider);

        for (final e in entries) {
          await entryRepo.deleteEntry(e.id);
        }
        await catRepo.deleteCategory(widget.categoryId);

        if (vault != null) {
          auditRepo.logAction(
            vaultId: vault.id,
            userId: user?.id ?? 'user',
            userDisplayName: user?.displayName ?? 'Admin',
            action: 'CATEGORY_DELETED',
            entityType: 'CATEGORY',
            metadata: {'name': catName},
          );
          ref.invalidate(auditLogsProvider);
        }

        ref.invalidate(categoriesProvider);
        ref.invalidate(categoryEntriesProvider(widget.categoryId));

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Category "$catName" deleted.')),
          );
          context.pop();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting category: $e')),
          );
        }
      }
    }
  }

  Future<void> _confirmDeleteEntry(Entry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "${entry.title}"?'),
        content: const Text(
          'This encrypted entry and its safe spot records will be permanently removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.statusRose),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        final vault = ref.read(activeVaultProvider);
        final user = ref.read(currentUserProvider);

        await ref.read(entryRepositoryProvider).deleteEntry(entry.id);

        if (vault != null) {
          ref.read(auditRepositoryProvider).logAction(
            vaultId: vault.id,
            userId: user?.id ?? 'user',
            userDisplayName: user?.displayName ?? 'Admin',
            action: 'ENTRY_DELETED',
            entityType: 'ENTRY',
            metadata: {'title_hint': entry.title},
          );
          ref.invalidate(auditLogsProvider);
        }

        ref.invalidate(categoryEntriesProvider(widget.categoryId));
        ref.invalidate(categoriesProvider);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Deleted "${entry.title}"')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting entry: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final entriesAsync = ref.watch(categoryEntriesProvider(widget.categoryId));
    final entries = entriesAsync.asData?.value ?? [];
    final entryCount = entries.length;
    final totalAmount = entries.fold<double>(0, (sum, e) => sum + _extractAmount(e));
    final categoryName = widget.category?.name ?? 'Category Records';
    final isOwner = ref.watch(isVaultOwnerProvider);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.surface,
      appBar: AppBar(
        title: Text(categoryName),
        actions: [
          if (isOwner)
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Add Entry',
              onPressed: () {
                context.push('/entry-editor?categoryId=${widget.categoryId}');
              },
            ),
          if (isOwner)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete Category',
              onPressed: () => _confirmDeleteCategory(entries),
            ),
        ],
      ),
      body: SizedBox.expand(
        child: Container(
          decoration: BoxDecoration(
            gradient: AppColors.bgGradient(isDark),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: AppDimensions.margin),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: AppDimensions.spaceSm),

                // Trust Assurance Bar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Flexible(
                      child: TrustBadge(
                        type: TrustBadgeType.vaultEnclave,
                        customText: 'Vault Enclave',
                      ),
                    ),
                    SizedBox(width: 8),
                    Flexible(
                      child: TrustBadge(
                        type: TrustBadgeType.biometricGuarded,
                        customText: 'Biometric Guarded',
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: AppDimensions.spaceMd),

                // Dynamic Summary Hero Card (No hardcoded values)
                AppCard(
                  padding: const EdgeInsets.all(AppDimensions.spaceMd),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Text(
                                totalAmount > 0 ? 'Total Documented' : 'Category Summary',
                                style: AppTypography.labelMd(
                                  color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
                                ),
                              ),
                              if (totalAmount > 0) ...[
                                const SizedBox(width: 6),
                                InkWell(
                                  onTap: () => setState(() => _hideBalances = !_hideBalances),
                                  child: Icon(
                                    _hideBalances ? Icons.visibility_off : Icons.visibility,
                                    size: 16,
                                    color: isDark ? AppColors.darkPrimary : AppColors.primary,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.darkPrimaryContainer : AppColors.primaryFixed,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              totalAmount > 0 ? Icons.account_balance : Icons.folder_special_outlined,
                              size: 20,
                              color: isDark ? AppColors.darkPrimary : AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            totalAmount > 0
                                ? (_hideBalances ? '••••••••' : _formatIndianCurrency(totalAmount))
                                : (entryCount == 0 ? '0 Records' : '$entryCount ${entryCount == 1 ? "Record" : "Records"}'),
                            style: AppTypography.headlineLg(
                              color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            totalAmount > 0
                                ? 'across $entryCount ${entryCount == 1 ? "record" : "records"}'
                                : 'secured in vault',
                            style: AppTypography.bodySm(
                              color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppDimensions.spaceSm),
                      // Dynamic Category Status Chip
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkSurfaceContainerHighest : AppColors.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          widget.category?.description ?? 'End-to-End Encrypted • Verified Sync',
                          style: AppTypography.bodySm(
                            color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppDimensions.spaceMd),

                // Search Bar
                TextField(
                  onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
                  decoration: InputDecoration(
                    hintText: 'Search $categoryName entries...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    filled: true,
                    fillColor: isDark ? AppColors.darkSurfaceContainerLow : AppColors.surfaceContainerLow,
                  ),
                ),

                const SizedBox(height: AppDimensions.spaceMd),

                // Records List
                entriesAsync.when(
                  data: (rawEntries) {
                    final filtered = rawEntries.where((e) {
                      if (_searchQuery.isNotEmpty) {
                        final q = _searchQuery.toLowerCase();
                        final matchesTitle = e.title.toLowerCase().contains(q);
                        final matchesNotes = (e.notes ?? '').toLowerCase().contains(q);
                        final matchesField = e.fields.any((f) =>
                            f.fieldName.toLowerCase().contains(q) ||
                            f.fieldValue.toLowerCase().contains(q));
                        if (!matchesTitle && !matchesNotes && !matchesField) return false;
                      }
                      return true;
                    }).toList();

                    if (filtered.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 48.0),
                          child: Column(
                            children: [
                              Icon(
                                Icons.lock_clock,
                                size: 48,
                                color: isDark ? AppColors.darkOutline : AppColors.outline,
                              ),
                              const SizedBox(height: AppDimensions.spaceSm),
                              Text('No records found', style: AppTypography.headlineSm(context: context)),
                              const SizedBox(height: 4),
                              Text(isOwner ? 'Add your first entry to this vault category.' : 'No entries available in this category yet.', style: AppTypography.bodySm(context: context)),
                            ],
                          ),
                        ),
                      );
                    }

                    return Column(
                      children: filtered.map((entry) => _buildRecordCard(entry)).toList(),
                    );
                  },
                  loading: () => _buildRecordSkeletonList(isDark),
                  error: (e, _) => Text('Error loading records: $e'),
                ),

                const SizedBox(height: AppDimensions.spaceXl * 2),
              ],
            ),
          ),
        ),
      ),
    ),
      floatingActionButton: isOwner
          ? FloatingActionButton.extended(
              backgroundColor: AppColors.accent(isDark),
              foregroundColor: AppColors.textOnAccent(isDark),
              icon: const Icon(Icons.add),
              label: const Text('Add Entry'),
              onPressed: () {
                context.push('/entry-editor?categoryId=${widget.categoryId}');
              },
            )
          : null,
    );
  }

  Widget _buildRecordSkeletonList(bool isDark) {
    final shimmerBase = isDark ? const Color(0xFF162320) : const Color(0xFFE8EDE9);
    final shimmerHighlight = isDark ? const Color(0xFF1E2E2A) : const Color(0xFFF3F7F4);

    return Column(
      children: List.generate(3, (index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: AppDimensions.spaceSm),
          child: AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      width: 140,
                      height: 16,
                      decoration: BoxDecoration(
                        color: shimmerHighlight,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    Container(
                      width: 50,
                      height: 16,
                      decoration: BoxDecoration(
                        color: shimmerBase,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  width: 200,
                  height: 12,
                  decoration: BoxDecoration(
                    color: shimmerBase,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildRecordCard(Entry entry) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Extract dynamic fields without hardcoded fallbacks
    String? amountStr;
    for (final f in entry.fields) {
      if (f.fieldType == EntryFieldType.currency ||
          f.fieldName.toLowerCase().contains('amount') ||
          f.fieldName.toLowerCase().contains('sum assured') ||
          f.fieldName.toLowerCase().contains('deposit')) {
        amountStr = f.fieldValue;
        break;
      }
    }

    String? nominee;
    for (final f in entry.fields) {
      if (f.fieldName.toLowerCase().contains('nominee')) {
        nominee = f.fieldValue;
        break;
      }
    }

    String? safeSpot;
    for (final f in entry.fields) {
      final name = f.fieldName.toLowerCase();
      if (name.contains('place') || name.contains('kept') || name.contains('locker') || name.contains('location')) {
        safeSpot = f.fieldValue;
        break;
      }
    }

    String? dateStr;
    for (final f in entry.fields) {
      if (f.fieldType == EntryFieldType.date || f.fieldName.toLowerCase().contains('date')) {
        dateStr = f.fieldValue;
        break;
      }
    }

    // Subtitle descriptor
    String subtitle = '';
    for (final f in entry.fields) {
      if (!f.isSensitive && f.fieldName.toLowerCase() != 'amount' && f.fieldValue.isNotEmpty) {
        subtitle = '${f.fieldName}: ${f.fieldValue}';
        break;
      }
    }
    if (subtitle.isEmpty && entry.notes != null && entry.notes!.isNotEmpty) {
      subtitle = entry.notes!;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.spaceSm),
      child: AppCard(
        onTap: () {
          context.push('/entry/${entry.id}', extra: entry);
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkPrimaryContainer : AppColors.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.bookmark_outline,
                          color: isDark ? AppColors.darkOnPrimaryContainer : AppColors.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: AppDimensions.spaceSm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(entry.title, style: AppTypography.labelLg(context: context), overflow: TextOverflow.ellipsis),
                            if (subtitle.isNotEmpty)
                              Text(subtitle, style: AppTypography.bodySm(context: context), maxLines: 1, overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (amountStr != null)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _hideBalances ? '••••' : (amountStr.startsWith('₹') ? amountStr : '₹$amountStr'),
                            style: AppTypography.labelLg(
                              color: isDark ? AppColors.darkPrimary : AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20),
                      tooltip: 'Delete Entry',
                      onPressed: () => _confirmDeleteEntry(entry),
                    ),
                  ],
                ),
              ],
            ),
            if (dateStr != null || nominee != null || safeSpot != null) ...[
              const SizedBox(height: AppDimensions.spaceSm),
              Container(
                padding: const EdgeInsets.all(AppDimensions.spaceSm),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurfaceContainerLow : AppColors.surfaceContainerLow.withAlpha(120),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                ),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (dateStr != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkSurfaceContainerHighest : AppColors.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.calendar_today, size: 12),
                            const SizedBox(width: 4),
                            Text(dateStr, style: AppTypography.labelSm(context: context)),
                          ],
                        ),
                      ),
                    if (nominee != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkSecondaryContainer : AppColors.secondaryContainer,
                          borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.person, size: 12),
                            const SizedBox(width: 4),
                            Text('Nominee: $nominee', style: AppTypography.labelSm(context: context)),
                          ],
                        ),
                      ),
                    if (safeSpot != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkSurfaceContainerHigh : AppColors.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.vpn_key, size: 12),
                            const SizedBox(width: 4),
                            Text(safeSpot, style: AppTypography.labelSm(context: context)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
