import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/providers.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/widgets/app_card.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final vault = ref.watch(activeVaultProvider);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.surface,
      appBar: AppBar(
        title: const Text('Search KeyDiary'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppDimensions.margin),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppDimensions.spaceSm),

              // Search Input
              TextField(
                controller: _searchController,
                autofocus: true,
                onChanged: (val) => setState(() => _query = val.trim().toLowerCase()),
                decoration: InputDecoration(
                  hintText: 'Search everything... (e.g. SBI, Locker, LIC)',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                        )
                      : null,
                ),
              ),

              const SizedBox(height: AppDimensions.spaceMd),

              // Client-Side Security Reassurance
              Row(
                children: [
                  Icon(Icons.lock_outline, size: 14, color: isDark ? AppColors.darkPrimary : AppColors.primary),
                  const SizedBox(width: 4),
                  Text(
                    'Search is performed locally on decrypted memory — queries are never sent to servers.',
                    style: AppTypography.labelSm(),
                  ),
                ],
              ),

              const SizedBox(height: AppDimensions.spaceLg),

              // Results
              Expanded(
                child: _query.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search, size: 48, color: isDark ? AppColors.darkOutline : AppColors.outline),
                            const SizedBox(height: AppDimensions.spaceSm),
                            Text('Search your private vault', style: AppTypography.labelLg()),
                            Text('Find bank details, keys, policy numbers, or safe spots.', style: AppTypography.bodySm()),
                          ],
                        ),
                      )
                    : _buildSearchResults(vault?.id ?? ''),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchResults(String vaultId) {
    final entriesAsync = ref.watch(categoryEntriesProvider('cat-investments-$vaultId'));

    return entriesAsync.when(
      data: (entries) {
        final matches = entries.where((e) {
          final inTitle = e.title.toLowerCase().contains(_query);
          final inNotes = (e.notes ?? '').toLowerCase().contains(_query);
          final inFields = e.fields.any((f) => f.fieldValue.toLowerCase().contains(_query) || f.fieldName.toLowerCase().contains(_query));
          return inTitle || inNotes || inFields;
        }).toList();

        if (matches.isEmpty) {
          return Center(
            child: Text('No matching records found for "$_query"', style: AppTypography.bodyMd()),
          );
        }

        return ListView.builder(
          itemCount: matches.length,
          itemBuilder: (ctx, idx) {
            final entry = matches[idx];
            return Padding(
              padding: const EdgeInsets.only(bottom: AppDimensions.spaceSm),
              child: AppCard(
                onTap: () => context.push('/entry/${entry.id}', extra: entry),
                child: Row(
                  children: [
                    const Icon(Icons.bookmark, size: 20),
                    const SizedBox(width: AppDimensions.spaceSm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(entry.title, style: AppTypography.labelLg()),
                          Text('Investments • Tap to view', style: AppTypography.bodySm()),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text('Search error: $e'),
    );
  }
}
