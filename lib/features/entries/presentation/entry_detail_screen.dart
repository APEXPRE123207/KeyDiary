import 'dart:io';
import 'package:flutter/foundation.dart';
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
          title: 'SBI Fixed Deposit',
          notes:
              'Original receipt is in the blue steel almirah, bottom wooden drawer under the tax binder. Branch manager Mr. Sharma knows about this deposit.',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
  }

  Future<void> _confirmDelete() async {
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
            style: TextButton.styleFrom(foregroundColor: AppColors.statusRose),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await ref.read(entryRepositoryProvider).deleteEntry(_currentEntry.id);
      ref.invalidate(categoryEntriesProvider(_currentEntry.categoryId));
      if (mounted) context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final institution = _currentEntry.getFieldValue('Institution / Branch') ?? 'State Bank of India';
    final amount = _currentEntry.getFieldValue('Deposit Amount') ?? '5,00,000';
    final certificate = _currentEntry.getFieldValue('Certificate / Account') ?? '3049 8219 4821';
    final maturity = _currentEntry.getFieldValue('Maturity Date') ?? '12 April 2028';
    final nominee = _currentEntry.getFieldValue('Registered Nominee') ?? 'Child';
    final depositType = _currentEntry.getFieldValue('Deposit Type') ?? 'Cumulative Term';
    final interest = _currentEntry.getFieldValue('Interest Rate') ?? '7.10% p.a.';

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.surface,
      appBar: AppBar(
        title: const Text('Record Detail View'),
        actions: [
          IconButton(
            icon: Icon(_isBookmarked ? Icons.bookmark : Icons.bookmark_border),
            onPressed: () => setState(() => _isBookmarked = !_isBookmarked),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit Entry',
            onPressed: () {
              context.push('/entry-editor?categoryId=${_currentEntry.categoryId}', extra: _currentEntry);
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Delete Entry',
            onPressed: _confirmDelete,
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

              // Hero Summary Card (matching Image 9.html)
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
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: isDark ? AppColors.darkPrimaryContainer : AppColors.primaryFixed,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.account_balance,
                                color: isDark ? AppColors.darkOnPrimaryContainer : AppColors.primary,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: AppDimensions.spaceSm),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(institution, style: AppTypography.labelMd()),
                                Text(_currentEntry.title, style: AppTypography.headlineSm()),
                              ],
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkStatusGreenBg : AppColors.statusGreenBg,
                            borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                          ),
                          child: Text(
                            'Active Deposit',
                            style: AppTypography.labelSm(
                              color: isDark ? AppColors.darkStatusGreen : AppColors.statusGreen,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppDimensions.spaceMd),
                    Text('PRINCIPAL DEPOSIT', style: AppTypography.labelSm()),
                    const SizedBox(height: 2),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '₹$amount',
                          style: AppTypography.headlineLg(
                            color: isDark ? AppColors.darkPrimary : AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text('INR', style: AppTypography.bodySm()),
                      ],
                    ),
                    const SizedBox(height: AppDimensions.spaceSm),
                    const Divider(),
                    const SizedBox(height: AppDimensions.spaceSm),
                    Row(
                      children: [
                        Icon(
                          Icons.verified,
                          size: 16,
                          color: isDark ? AppColors.darkStatusGreen : AppColors.statusGreen,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Verified with physical bank receipt',
                          style: AppTypography.bodySm(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppDimensions.spaceLg),

              // Investment Details Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Investment Details', style: AppTypography.headlineSm()),
                  Text('Folio #FD-2401', style: AppTypography.labelSm()),
                ],
              ),

              const SizedBox(height: AppDimensions.spaceSm),

              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    // Sensitive Account Row
                    MaskedTextView(
                      label: 'Certificate / Account Number',
                      rawValue: certificate,
                    ),
                    const Divider(),
                    // Grid Pair 1: Deposit Type & Interest Rate
                    Padding(
                      padding: const EdgeInsets.all(AppDimensions.spaceMd),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Deposit Type', style: AppTypography.labelSm()),
                                const SizedBox(height: 2),
                                Text(depositType, style: AppTypography.labelLg()),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Interest Rate', style: AppTypography.labelSm()),
                                const SizedBox(height: 2),
                                Text(
                                  interest,
                                  style: AppTypography.labelLg(
                                    color: isDark ? AppColors.darkPrimary : AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(),
                    // Grid Pair 2: Maturity Date & Expected Returns
                    Padding(
                      padding: const EdgeInsets.all(AppDimensions.spaceMd),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Maturity Date', style: AppTypography.labelSm()),
                                const SizedBox(height: 2),
                                Text(maturity, style: AppTypography.labelLg()),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Expected Returns', style: AppTypography.labelSm()),
                                const SizedBox(height: 2),
                                Text('₹6,85,420', style: AppTypography.headlineSm()),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(),
                    // Nominee Row
                    Padding(
                      padding: const EdgeInsets.all(AppDimensions.spaceMd),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Registered Nominee', style: AppTypography.labelSm()),
                                const SizedBox(height: 2),
                                Text(nominee, style: AppTypography.labelLg()),
                                Text('Son • 100% legal entitlement', style: AppTypography.bodySm()),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.family_restroom,
                            color: isDark ? AppColors.darkPrimary : AppColors.primary,
                            size: 26,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppDimensions.spaceLg),

              // Personal Diary Notes (Warm Archival Paper container)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.edit_note,
                        size: 20,
                        color: isDark ? AppColors.darkPrimary : AppColors.primary,
                      ),
                      const SizedBox(width: 6),
                      Text('Personal Instructions & Safe Spot', style: AppTypography.labelLg()),
                    ],
                  ),
                  Text('Private note', style: AppTypography.labelSm()),
                ],
              ),

              const SizedBox(height: AppDimensions.spaceSm),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppDimensions.spaceMd),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurfaceContainerLow : const Color(0xFFF4F0E8), // Warm archival tint
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                  border: Border.all(
                    color: isDark ? AppColors.darkOutlineVariant : const Color(0xFFE2DDD3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _currentEntry.notes ?? 'No diary instructions recorded.',
                      style: AppTypography.bodyMd(),
                    ),
                    const SizedBox(height: AppDimensions.spaceSm),
                    Row(
                      children: [
                        Icon(
                          Icons.lock,
                          size: 13,
                          color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Stored privately in vault',
                          style: AppTypography.labelSm(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

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
                      Text('No documents attached to this record.', style: AppTypography.bodySm()),
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
                                  child: (att.isImage && att.localFilePath != null && !kIsWeb && File(att.localFilePath!).existsSync())
                                      ? Image.file(
                                          File(att.localFilePath!),
                                          width: 48,
                                          height: 48,
                                          fit: BoxFit.cover,
                                        )
                                      : Icon(
                                          att.isImage ? Icons.image : Icons.picture_as_pdf,
                                          color: isDark ? AppColors.darkOnPrimaryContainer : AppColors.primary,
                                          size: 24,
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
              AppButton(
                text: 'Edit Record',
                variant: AppButtonVariant.secondary,
                leadingIcon: Icons.edit,
                width: double.infinity,
                onPressed: () {
                  context.push('/entry-editor?categoryId=${_currentEntry.categoryId}', extra: _currentEntry);
                },
              ),

              const SizedBox(height: AppDimensions.spaceXl * 2),
            ],
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
                  child: (att.localFilePath != null && !kIsWeb && File(att.localFilePath!).existsSync())
                      ? Image.file(
                          File(att.localFilePath!),
                          fit: BoxFit.contain,
                          height: 300,
                        )
                      : Container(
                          height: 200,
                          color: isDark ? AppColors.darkSurfaceContainerHigh : AppColors.surfaceContainerHigh,
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.lock, size: 48, color: isDark ? AppColors.darkPrimary : AppColors.primary),
                                const SizedBox(height: 8),
                                Text('Attached Photo', style: AppTypography.labelMd()),
                                Text(att.formattedSize, style: AppTypography.bodySm()),
                              ],
                            ),
                          ),
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
