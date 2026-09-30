import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/providers.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/masked_text_view.dart';
import '../../../core/widgets/trust_badge.dart';
import '../domain/attachment.dart';
import '../domain/entry.dart';
import '../domain/entry_field.dart';
import 'widgets/secure_attachment_image.dart';

class EntryDetailScreen extends ConsumerStatefulWidget {
  final String entryId;
  final Entry? entry;

  const EntryDetailScreen({
    super.key,
    required this.entryId,
    this.entry,
  });

  @override
  ConsumerState<EntryDetailScreen> createState() => _EntryDetailScreenState();
}

class _EntryDetailScreenState extends ConsumerState<EntryDetailScreen> {
  late Entry _currentEntry;
  bool _isBookmarked = false;

  @override
  void initState() {
    super.initState();
    _currentEntry = widget.entry ??
        Entry(
          id: widget.entryId,
          categoryId: 'cat-default',
          vaultId: 'vault-default',
          title: 'Vault Record',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
  }

  Future<void> _confirmDelete() async {
    if (!ref.read(isVaultOwnerProvider)) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "${_currentEntry.title}"?'),
        content: const Text(
          'This action will remove this encrypted entry and its safe spot records permanently.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.statusRose),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final vault = ref.read(activeVaultProvider);
      final user = ref.read(currentUserProvider);

      await ref.read(entryRepositoryProvider).deleteEntry(_currentEntry.id);

      if (vault != null) {
        ref.read(auditRepositoryProvider).logAction(
          vaultId: vault.id,
          userId: user?.id ?? 'user',
          userDisplayName: user?.displayName ?? 'Admin',
          action: 'ENTRY_DELETED',
          entityType: 'ENTRY',
          metadata: {'title_hint': _currentEntry.title},
        );
        ref.invalidate(auditLogsProvider);
      }

      ref.invalidate(categoryEntriesProvider(_currentEntry.categoryId));
      ref.invalidate(categoriesProvider);

      if (mounted) context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isOwner = ref.watch(isVaultOwnerProvider);

    // Find primary amount if exists
    String? amount;
    for (final f in _currentEntry.fields) {
      if (f.fieldType == EntryFieldType.currency ||
          f.fieldName.toLowerCase().contains('amount') ||
          f.fieldName.toLowerCase().contains('sum assured') ||
          f.fieldName.toLowerCase().contains('deposit')) {
        amount = f.fieldValue;
        break;
      }
    }

    // Find subtitle institution or location
    String? subtitle;
    for (final f in _currentEntry.fields) {
      final name = f.fieldName.toLowerCase();
      if (!f.isSensitive &&
          (name.contains('institution') ||
              name.contains('branch') ||
              name.contains('provider') ||
              name.contains('bank') ||
              name.contains('place') ||
              name.contains('address') ||
              name.contains('location'))) {
        subtitle = f.fieldValue;
        break;
      }
    }

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.surface,
      appBar: AppBar(
        title: Text(_currentEntry.title),
        actions: [
          IconButton(
            icon: Icon(_isBookmarked ? Icons.bookmark : Icons.bookmark_border),
            onPressed: () => setState(() => _isBookmarked = !_isBookmarked),
          ),
          if (isOwner)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete Entry',
              onPressed: _confirmDelete,
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

                // Trust & Status Indicator
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    TrustBadge(
                      type: TrustBadgeType.vaultEnclave,
                      customText: 'Family Vault Record',
                    ),
                    TrustBadge(
                      type: TrustBadgeType.synced,
                      customText: 'End-to-End Secured',
                    ),
                  ],
                ),

                const SizedBox(height: AppDimensions.spaceMd),

                // Hero Summary Card (Dynamic based on entry fields)
                AppCard(
                  padding: const EdgeInsets.all(AppDimensions.spaceMd),
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
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: isDark ? AppColors.darkPrimaryContainer : AppColors.primaryFixed,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.shield_outlined,
                                    color: isDark ? AppColors.darkOnPrimaryContainer : AppColors.primary,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: AppDimensions.spaceSm),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (subtitle != null && subtitle.isNotEmpty)
                                        Text(subtitle, style: AppTypography.labelMd(context: context), overflow: TextOverflow.ellipsis),
                                      Text(_currentEntry.title, style: AppTypography.headlineSm(context: context), overflow: TextOverflow.ellipsis),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.darkStatusGreenBg : AppColors.statusGreenBg,
                              borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                            ),
                            child: Text(
                              'Verified Record',
                              style: AppTypography.labelSm(
                                context: context,
                                color: isDark ? AppColors.darkStatusGreen : AppColors.statusGreen,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (amount != null && amount.isNotEmpty) ...[
                        const SizedBox(height: AppDimensions.spaceMd),
                        Text('RECORD VALUE / AMOUNT', style: AppTypography.labelSm(context: context)),
                        const SizedBox(height: 2),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              amount.startsWith('₹') ? amount : '₹$amount',
                              style: AppTypography.headlineLg(
                                color: isDark ? AppColors.darkPrimary : AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text('INR', style: AppTypography.bodySm(context: context)),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: AppDimensions.spaceLg),

                // Record Details Section
                Text(
                  'Record Details',
                  style: AppTypography.headlineSm(context: context),
                ),

                const SizedBox(height: AppDimensions.spaceSm),

                if (_currentEntry.fields.isEmpty)
                  AppCard(
                    child: Text(
                      'No specific field values entered for this record.',
                      style: AppTypography.bodySm(),
                    ),
                  )
                else
                  AppCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        for (int i = 0; i < _currentEntry.fields.length; i++) ...[
                          if (i > 0) const Divider(height: 1),
                          if (_currentEntry.fields[i].isSensitive ||
                              _currentEntry.fields[i].fieldType == EntryFieldType.secret)
                            MaskedTextView(
                              label: _currentEntry.fields[i].fieldName,
                              rawValue: _currentEntry.fields[i].fieldValue,
                            )
                          else
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppDimensions.spaceMd,
                                vertical: AppDimensions.spaceSm + 2,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _currentEntry.fields[i].fieldName,
                                          style: AppTypography.labelSm(
                                            color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          _currentEntry.fields[i].fieldValue,
                                          style: AppTypography.labelLg(),
                                        ),
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

                // Personal Instructions & Safe Spot
                if (_currentEntry.notes != null && _currentEntry.notes!.trim().isNotEmpty) ...[
                  const SizedBox(height: AppDimensions.spaceLg),
                  Text('Personal Instructions & Safe Spot', style: AppTypography.headlineSm(context: context)),
                  const SizedBox(height: AppDimensions.spaceSm),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.edit_note, size: 20, color: isDark ? AppColors.darkPrimary : AppColors.primary),
                            const SizedBox(width: 8),
                            Text('Confidential Instructions', style: AppTypography.labelMd()),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _currentEntry.notes!,
                          style: AppTypography.bodySm(
                            color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                          ).copyWith(height: 1.5),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: AppDimensions.spaceLg),

                // Attached Documents
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Attached Documents', style: AppTypography.headlineSm()),
                    Text(
                      '${_currentEntry.attachments.length} ${(_currentEntry.attachments.length == 1) ? 'file' : 'files'}',
                      style: AppTypography.labelSm(),
                    ),
                  ],
                ),

                const SizedBox(height: AppDimensions.spaceSm),

                if (_currentEntry.attachments.isEmpty)
                  AppCard(
                    child: Row(
                      children: [
                        Icon(Icons.attachment, color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant),
                        const SizedBox(width: AppDimensions.spaceSm),
                        Expanded(
                          child: Text('No documents attached to this record.', style: AppTypography.bodySm()),
                        ),
                      ],
                    ),
                  )
                else
                  ..._currentEntry.attachments.map((att) => Padding(
                        padding: const EdgeInsets.only(bottom: AppDimensions.spaceSm),
                        child: AppCard(
                          child: InkWell(
                            onTap: () {
                              if (att.isImage) {
                                _showImagePreview(context, att);
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Opening ${att.fileName}...')),
                                );
                              }
                            },
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: isDark ? AppColors.darkPrimaryContainer : AppColors.primaryFixed,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: SecureAttachmentImage(
                                    attachment: att,
                                    width: 48,
                                    height: 48,
                                    isThumbnail: true,
                                    fit: BoxFit.cover,
                                  ),
                                  ),
                                ),
                                const SizedBox(width: AppDimensions.spaceMd),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        att.fileName,
                                        style: AppTypography.labelMd(),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        '${att.formattedSize} • Secure photo',
                                        style: AppTypography.bodySm(),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(att.isImage ? Icons.visibility_outlined : Icons.file_open_outlined),
                                  onPressed: () {
                                    if (att.isImage) {
                                      _showImagePreview(context, att);
                                    } else {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Opening ${att.fileName}...')),
                                      );
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      )),

                const SizedBox(height: AppDimensions.spaceLg),

                // Action Buttons
                if (isOwner)
                  AppButton(
                    text: 'Edit Record',
                    variant: AppButtonVariant.secondary,
                    leadingIcon: Icons.edit,
                    width: double.infinity,
                    onPressed: () {
                      context.push('/entry-editor?categoryId=${_currentEntry.categoryId}', extra: _currentEntry);
                    },
                  )
                else
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppDimensions.spaceMd),
                    decoration: BoxDecoration(
                      color: AppColors.cardFill(isDark),
                      borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                      border: Border.all(
                        color: AppColors.cardBorder(isDark),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.shield_outlined,
                          color: AppColors.textSecondary(isDark),
                          size: 20,
                        ),
                        const SizedBox(width: AppDimensions.spaceSm),
                        Expanded(
                          child: Text(
                            'Co-Guardian Access: Read-only mode. Editing and deleting records are restricted to the Vault Admin.',
                            style: AppTypography.bodySm(context: context),
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: AppDimensions.spaceXl * 2),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }

  void _showImagePreview(BuildContext context, Attachment att) {
    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(AppDimensions.margin),
          child: Container(
            padding: const EdgeInsets.all(AppDimensions.spaceMd),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.surface,
              borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        att.fileName,
                        style: AppTypography.headlineSm(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: AppDimensions.spaceSm),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                  child: SecureAttachmentImage(
                    attachment: att,
                    height: 300,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: AppDimensions.spaceMd),
                AppButton(
                  text: 'Close Preview',
                  variant: AppButtonVariant.secondary,
                  width: double.infinity,
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
