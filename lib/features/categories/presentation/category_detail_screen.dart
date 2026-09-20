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
  String _selectedFilter = 'all';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final entriesAsync = ref.watch(categoryEntriesProvider(widget.categoryId));

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.surface,
      appBar: AppBar(
        title: Text(widget.category?.name ?? 'Category Records'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add Entry',
            onPressed: () {
              context.push('/entry-editor?categoryId=${widget.categoryId}');
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppDimensions.margin),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppDimensions.spaceSm),

              // Trust Assurance Bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  TrustBadge(
                    type: TrustBadgeType.vaultEnclave,
                    customText: 'Vault Enclave • Local Only',
                  ),
                  TrustBadge(
                    type: TrustBadgeType.biometricGuarded,
                    customText: 'Biometric Guarded',
                  ),
                ],
              ),

              const SizedBox(height: AppDimensions.spaceMd),

              // Financial / Summary Hero Card (matching Image 7.html)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppDimensions.spaceMd),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkPrimaryContainer : AppColors.primaryContainer,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryContainer.withAlpha(40),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Total Documented',
                              style: AppTypography.labelMd(
                                color: isDark ? AppColors.darkOnPrimaryContainer : AppColors.onPrimaryContainer,
                              ),
                            ),
                            const SizedBox(width: 6),
                            InkWell(
                              onTap: () => setState(() => _hideBalances = !_hideBalances),
                              child: Icon(
                                _hideBalances ? Icons.visibility_off : Icons.visibility,
                                size: 16,
                                color: isDark ? AppColors.darkOnPrimaryContainer : AppColors.onPrimaryContainer,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(25),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.account_balance, size: 20, color: Colors.white),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          _hideBalances ? '••••••••' : '₹18,40,000',
                          style: AppTypography.headlineLg(color: Colors.white),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'across 8 records',
                          style: AppTypography.bodySm(color: Colors.white.withAlpha(200)),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppDimensions.spaceMd),
                    // Micro Allocation Distribution Indicator
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Allocation distribution',
                          style: AppTypography.labelSm(color: Colors.white.withAlpha(220)),
                        ),
                        Text(
                          'FD (27%) • Life (54%) • MF (19%)',
                          style: AppTypography.labelSm(color: Colors.white.withAlpha(220)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Container(
                      height: 6,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(3),
                        color: Colors.white.withAlpha(40),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 27,
                            child: Container(
                              decoration: const BoxDecoration(
                                color: AppColors.primaryFixedDim,
                                borderRadius: BorderRadius.horizontal(left: Radius.circular(3)),
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 54,
                            child: Container(color: Colors.white),
                          ),
                          Expanded(
                            flex: 19,
                            child: Container(
                              decoration: const BoxDecoration(
                                color: AppColors.secondaryFixed,
                                borderRadius: BorderRadius.horizontal(right: Radius.circular(3)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppDimensions.spaceMd),

              // Search & Filter Panel
              TextField(
                onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
                decoration: InputDecoration(
                  hintText: 'Search investments, nominees, banks...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  filled: true,
                  fillColor: isDark ? AppColors.darkSurfaceContainerLow : AppColors.surfaceContainerLow,
                ),
              ),

              const SizedBox(height: AppDimensions.spaceSm),

              // Filter Pills
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterPill('All (8)', 'all'),
                    const SizedBox(width: 8),
                    _buildFilterPill('Bank & PO', 'bank'),
                    const SizedBox(width: 8),
                    _buildFilterPill('Life Policies', 'insurance'),
                    const SizedBox(width: 8),
                    _buildFilterPill('Mutual Funds', 'market'),
                  ],
                ),
              ),

              const SizedBox(height: AppDimensions.spaceMd),

              // Records List
              entriesAsync.when(
                data: (entries) {
                  final filtered = entries.where((e) {
                    if (_searchQuery.isNotEmpty &&
                        !e.title.toLowerCase().contains(_searchQuery) &&
                        !(e.notes ?? '').toLowerCase().contains(_searchQuery)) {
                      return false;
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
                            Text('No records found', style: AppTypography.headlineSm()),
                            const SizedBox(height: 4),
                            Text('Add your first entry to this vault category.', style: AppTypography.bodySm()),
                          ],
                        ),
                      ),
                    );
                  }

                  return Column(
                    children: filtered.map((entry) => _buildRecordCard(entry)).toList(),
                  );
                },
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (e, _) => Text('Error loading records: $e'),
              ),

              const SizedBox(height: AppDimensions.spaceXl * 2),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: isDark ? AppColors.darkPrimaryContainer : AppColors.primaryContainer,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Entry'),
        onPressed: () {
          context.push('/entry-editor?categoryId=${widget.categoryId}');
        },
      ),
    );
  }

  Widget _buildFilterPill(String label, String key) {
    final isSelected = _selectedFilter == key;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: () => setState(() => _selectedFilter = key),
      borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? AppColors.darkPrimaryContainer : AppColors.primaryContainer)
              : (isDark ? AppColors.darkSurfaceContainerLow : AppColors.surfaceContainerLow),
          borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
        ),
        child: Text(
          label,
          style: AppTypography.labelSm(
            color: isSelected
                ? Colors.white
                : (isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant),
          ),
        ),
      ),
    );
  }

  Widget _buildRecordCard(Entry entry) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final amount = entry.getFieldValue('Deposit Amount') ?? entry.getFieldValue('Sum Assured') ?? '₹5,00,000';
    final nominee = entry.getFieldValue('Registered Nominee') ?? entry.getFieldValue('Nominee') ?? 'Soumyadip';
    final maturity = entry.getFieldValue('Maturity Date') ?? '12 Apr 2028';
    final safeSpot = entry.getFieldValue('Locker Key Number') ?? 'Safe locker receipt #4';

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
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkPrimaryContainer : AppColors.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.savings,
                        color: isDark ? AppColors.darkOnPrimaryContainer : AppColors.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: AppDimensions.spaceSm),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(entry.title, style: AppTypography.labelLg()),
                        Text('A/c •••• 4821', style: AppTypography.bodySm()),
                      ],
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _hideBalances ? '••••' : '₹$amount',
                      style: AppTypography.labelLg(
                        color: isDark ? AppColors.darkPrimary : AppColors.primary,
                      ),
                    ),
                    Text('7.10% p.a.', style: AppTypography.labelSm()),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.spaceSm),
            Container(
              padding: const EdgeInsets.all(AppDimensions.spaceSm),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurfaceContainerLow : AppColors.surfaceContainerLow.withAlpha(120),
                borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            size: 14,
                            color: isDark ? AppColors.darkPrimary : AppColors.primary,
                          ),
                          const SizedBox(width: 4),
                          Text('Maturity $maturity', style: AppTypography.bodySm()),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkSurfaceContainerHighest : AppColors.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text('Cumulative', style: AppTypography.dataMono(fontSize: 11)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkSecondaryContainer : AppColors.secondaryContainer,
                          borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.person, size: 12),
                            const SizedBox(width: 3),
                            Text('Nominee: $nominee', style: AppTypography.labelSm()),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkSurfaceContainerHigh : AppColors.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.vpn_key, size: 12),
                            const SizedBox(width: 3),
                            Text(safeSpot, style: AppTypography.labelSm()),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
