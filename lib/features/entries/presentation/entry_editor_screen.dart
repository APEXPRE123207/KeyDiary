import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../app/providers.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../domain/attachment.dart';
import '../domain/entry.dart';
import '../domain/entry_field.dart';

class EntryEditorScreen extends ConsumerStatefulWidget {
  final String categoryId;
  final Entry? entry;

  const EntryEditorScreen({
    super.key,
    required this.categoryId,
    this.entry,
  });

  @override
  ConsumerState<EntryEditorScreen> createState() => _EntryEditorScreenState();
}

class _EntryEditorScreenState extends ConsumerState<EntryEditorScreen> {
  late TextEditingController _nameController;
  late TextEditingController _institutionController;
  late TextEditingController _amountController;
  late TextEditingController _maturityController;
  late TextEditingController _nomineeController;
  late TextEditingController _notesController;

  final List<EntryField> _customFields = [];
  bool _isSaving = false;
  String? _attachedFileName;
  String? _attachedFilePath;
  Uint8List? _attachedFileBytes;
  int _attachedFileSize = 0;
  bool _isAttachedImage = true;

  @override
  void initState() {
    super.initState();
    final e = widget.entry;
    _nameController = TextEditingController(text: e?.title ?? 'SBI Fixed Deposit');
    _institutionController = TextEditingController(text: e?.getFieldValue('Institution / Branch') ?? 'State Bank of India');
    _amountController = TextEditingController(text: e?.getFieldValue('Deposit Amount') ?? '5,00,000');
    _maturityController = TextEditingController(text: e?.getFieldValue('Maturity Date') ?? '12 Apr 2028');
    _nomineeController = TextEditingController(text: e?.getFieldValue('Registered Nominee') ?? 'Child');
    _notesController = TextEditingController(
      text: e?.notes ??
          'Original receipt is in the blue steel almirah, bottom wooden drawer under the tax binder. Branch manager Mr. Sharma knows about this deposit.',
    );

    if (e != null && e.attachments.isNotEmpty) {
      final att = e.attachments.first;
      _attachedFileName = att.fileName;
      _attachedFilePath = att.localFilePath;
      _attachedFileSize = att.size;
      _isAttachedImage = att.isImage;
    } else {
      _attachedFileName = 'SBI_FD_Certificate_2024.jpg';
      _attachedFileSize = 1468000;
      _isAttachedImage = true;
    }

    if (e != null && e.fields.isNotEmpty) {
      _customFields.addAll(e.fields.where((f) =>
          f.fieldName != 'Institution / Branch' &&
          f.fieldName != 'Deposit Amount' &&
          f.fieldName != 'Maturity Date' &&
          f.fieldName != 'Registered Nominee'));
    }
  }

  Future<void> _pickAttachmentModal() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Container(
          padding: const EdgeInsets.all(AppDimensions.margin),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(AppDimensions.radiusXl)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Attach Photo or Document', style: AppTypography.headlineSm()),
                const SizedBox(height: AppDimensions.spaceSm),
                Text(
                  'Photos and receipts are saved privately in your vault.',
                  style: AppTypography.bodySm(),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppDimensions.spaceMd),
                ListTile(
                  leading: Icon(Icons.camera_alt_outlined, color: isDark ? AppColors.darkPrimary : AppColors.primary),
                  title: Text('Take Photo with Camera', style: AppTypography.labelLg()),
                  subtitle: Text('Capture paper passbook, certificate, safe key', style: AppTypography.bodySm()),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final picker = ImagePicker();
                    final photo = await picker.pickImage(source: ImageSource.camera, maxWidth: 1920, maxHeight: 1920, imageQuality: 85);
                    if (photo != null) {
                      final bytes = await photo.readAsBytes();
                      setState(() {
                        _attachedFileName = photo.name;
                        _attachedFilePath = photo.path;
                        _attachedFileBytes = bytes;
                        _attachedFileSize = bytes.length;
                        _isAttachedImage = true;
                      });
                    }
                  },
                ),
                ListTile(
                  leading: Icon(Icons.photo_library_outlined, color: isDark ? AppColors.darkPrimary : AppColors.primary),
                  title: Text('Choose Photo from Gallery', style: AppTypography.labelLg()),
                  subtitle: Text('Select an image from device gallery', style: AppTypography.bodySm()),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final picker = ImagePicker();
                    final photo = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1920, maxHeight: 1920, imageQuality: 85);
                    if (photo != null) {
                      final bytes = await photo.readAsBytes();
                      setState(() {
                        _attachedFileName = photo.name;
                        _attachedFilePath = photo.path;
                        _attachedFileBytes = bytes;
                        _attachedFileSize = bytes.length;
                        _isAttachedImage = true;
                      });
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _institutionController.dispose();
    _amountController.dispose();
    _maturityController.dispose();
    _nomineeController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _openCustomFieldDrawer() {
    final fieldNameCtrl = TextEditingController(text: 'Locker Key Number');
    final fieldValueCtrl = TextEditingController(text: 'LK-994');
    EntryFieldType selectedType = EntryFieldType.secret;
    bool isSensitive = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;

          return Container(
            padding: EdgeInsets.only(
              left: AppDimensions.margin,
              right: AppDimensions.margin,
              top: AppDimensions.spaceMd,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + AppDimensions.spaceLg,
            ),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurfaceContainerLowest : AppColors.surfaceContainerLowest,
              borderRadius: AppDimensions.sheetRadius,
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Add a Detail', style: AppTypography.headlineSm()),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                Text(
                  'Add any extra note, locker code, or specific instructions for this entry.',
                  style: AppTypography.bodySm(),
                ),
                const SizedBox(height: AppDimensions.spaceMd),

                // Field Name Input
                Text('Field Name / Title', style: AppTypography.labelMd()),
                const SizedBox(height: 6),
                TextField(
                  controller: fieldNameCtrl,
                  decoration: const InputDecoration(
                    hintText: 'e.g. Secret Passcode, Safe Combination',
                    prefixIcon: Icon(Icons.label_outline),
                  ),
                ),

                const SizedBox(height: AppDimensions.spaceMd),

                // Select Data Type Chips Grid
                Text('Select Data Type', style: AppTypography.labelMd()),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildTypeChip('Text', EntryFieldType.text, Icons.notes, selectedType, (t) {
                      setSheetState(() => selectedType = t);
                    }),
                    _buildTypeChip('Number', EntryFieldType.number, Icons.pin, selectedType, (t) {
                      setSheetState(() => selectedType = t);
                    }),
                    _buildTypeChip('Currency', EntryFieldType.currency, Icons.payments, selectedType, (t) {
                      setSheetState(() => selectedType = t);
                    }),
                    _buildTypeChip('Date', EntryFieldType.date, Icons.calendar_today, selectedType, (t) {
                      setSheetState(() => selectedType = t);
                    }),
                    _buildTypeChip('Secret Code', EntryFieldType.secret, Icons.key, selectedType, (t) {
                      setSheetState(() {
                        selectedType = t;
                        isSensitive = true;
                      });
                    }),
                    _buildTypeChip('Phone', EntryFieldType.phone, Icons.call, selectedType, (t) {
                      setSheetState(() => selectedType = t);
                    }),
                    _buildTypeChip('File', EntryFieldType.document, Icons.attach_file, selectedType, (t) {
                      setSheetState(() => selectedType = t);
                    }),
                    _buildTypeChip('Yes / No', EntryFieldType.boolean, Icons.toggle_on, selectedType, (t) {
                      setSheetState(() => selectedType = t);
                    }),
                  ],
                ),

                const SizedBox(height: AppDimensions.spaceMd),

                // Field Value Input
                Text('Field Value', style: AppTypography.labelMd()),
                const SizedBox(height: 6),
                TextField(
                  controller: fieldValueCtrl,
                  obscureText: selectedType == EntryFieldType.secret,
                  decoration: InputDecoration(
                    hintText: 'Enter value',
                    prefixIcon: Icon(selectedType == EntryFieldType.secret ? Icons.lock : Icons.edit),
                  ),
                ),

                const SizedBox(height: AppDimensions.spaceLg),

                AppButton(
                  text: 'Add to Entry',
                  width: double.infinity,
                  onPressed: () {
                    final name = fieldNameCtrl.text.trim();
                    final val = fieldValueCtrl.text.trim();
                    if (name.isNotEmpty && val.isNotEmpty) {
                      setState(() {
                        _customFields.add(
                          EntryField(
                            id: 'f-${DateTime.now().millisecondsSinceEpoch}',
                            entryId: widget.entry?.id ?? '',
                            fieldName: name,
                            fieldType: selectedType,
                            fieldValue: val,
                            isSensitive: isSensitive,
                          ),
                        );
                      });
                    }
                    Navigator.pop(ctx);
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTypeChip(
    String label,
    EntryFieldType type,
    IconData icon,
    EntryFieldType selectedType,
    Function(EntryFieldType) onSelect,
  ) {
    final isSelected = type == selectedType;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ChoiceChip(
      avatar: Icon(icon, size: 16, color: isSelected ? Colors.white : null),
      label: Text(label),
      selected: isSelected,
      selectedColor: isDark ? AppColors.darkPrimaryContainer : AppColors.primaryContainer,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : null,
        fontSize: 12,
      ),
      onSelected: (val) {
        if (val) onSelect(type);
      },
    );
  }

  Future<void> _saveEntry() async {
    final title = _nameController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an entry name.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final vek = ref.read(vaultKeyProvider);
      final vault = ref.read(activeVaultProvider);
      final user = ref.read(currentUserProvider);

      if (vek == null || vault == null) {
        throw Exception('Vault encryption key is locked.');
      }

      final fields = <EntryField>[
        EntryField(
          id: 'f-inst',
          entryId: widget.entry?.id ?? '',
          fieldName: 'Institution / Branch',
          fieldType: EntryFieldType.text,
          fieldValue: _institutionController.text.trim(),
        ),
        EntryField(
          id: 'f-amt',
          entryId: widget.entry?.id ?? '',
          fieldName: 'Deposit Amount',
          fieldType: EntryFieldType.currency,
          fieldValue: _amountController.text.trim(),
        ),
        EntryField(
          id: 'f-mat',
          entryId: widget.entry?.id ?? '',
          fieldName: 'Maturity Date',
          fieldType: EntryFieldType.date,
          fieldValue: _maturityController.text.trim(),
        ),
        EntryField(
          id: 'f-nom',
          entryId: widget.entry?.id ?? '',
          fieldName: 'Registered Nominee',
          fieldType: EntryFieldType.text,
          fieldValue: _nomineeController.text.trim(),
        ),
        ..._customFields,
      ];

      final List<Attachment> attachments = [];
      if (_attachedFileName != null) {
        attachments.add(
          Attachment(
            id: 'att-${DateTime.now().millisecondsSinceEpoch}',
            entryId: widget.entry?.id ?? '',
            storagePath: 'vaults/${vault.id}/entries/$_attachedFileName',
            fileName: _attachedFileName!,
            mimeType: _isAttachedImage ? 'image/jpeg' : 'application/pdf',
            size: _attachedFileSize > 0 ? _attachedFileSize : 1468000,
            createdAt: DateTime.now(),
            localFilePath: _attachedFilePath,
          ),
        );
      }

      final entryToSave = Entry(
        id: widget.entry?.id ?? 'entry-${DateTime.now().millisecondsSinceEpoch}',
        categoryId: widget.categoryId,
        vaultId: vault.id,
        title: title,
        notes: _notesController.text.trim(),
        createdBy: user?.id,
        createdAt: widget.entry?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
        fields: fields,
        attachments: attachments,
      );

      await ref.read(entryRepositoryProvider).saveEntry(
        entry: entryToSave,
        vekBytes: vek,
        userId: user?.id,
      );

      // Audit log action
      ref.read(auditRepositoryProvider).logAction(
        vaultId: vault.id,
        userId: user?.id ?? 'user-dad',
        action: widget.entry != null ? 'ENTRY_UPDATED' : 'ENTRY_CREATED',
        entityType: 'ENTRY',
        metadata: {'title_hint': title},
      );

      ref.invalidate(categoryEntriesProvider(widget.categoryId));

      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.surface,
      appBar: AppBar(
        title: Text(widget.entry != null ? 'Edit Vault Entry' : 'New Vault Entry'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppDimensions.margin),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppDimensions.spaceSm),

              // Warm Top Framing & Context Header (matching Image 11.html)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.auto_stories, size: 16, color: isDark ? AppColors.darkPrimary : AppColors.primary),
                          const SizedBox(width: 4),
                          Text('Family Vault Ledger', style: AppTypography.labelSm()),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.darkSecondaryContainer : AppColors.secondaryContainer,
                              borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                            ),
                            child: Text('Investments', style: AppTypography.labelSm()),
                          ),
                          const SizedBox(width: 6),
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
                              Text('Draft auto-saving', style: AppTypography.labelSm()),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurfaceContainerHigh : AppColors.surfaceContainerHigh,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.account_balance, color: isDark ? AppColors.darkPrimary : AppColors.primary, size: 20),
                  ),
                ],
              ),

              const SizedBox(height: AppDimensions.spaceMd),

              // Reassuring Ledger Intro Note
              AppCard(
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkPrimaryContainer : AppColors.primaryFixed,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.verified_user, color: isDark ? AppColors.darkOnPrimaryContainer : AppColors.primary, size: 16),
                    ),
                    const SizedBox(width: AppDimensions.spaceSm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Private Family Record', style: AppTypography.labelMd()),
                          Text(
                            'Only trusted circle members can view these sensitive deposit details and nominee records.',
                            style: AppTypography.bodySm(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppDimensions.spaceMd),

              // Form fields
              Text('Entry Name (Required)', style: AppTypography.labelMd()),
              const SizedBox(height: 6),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  hintText: 'e.g. SBI Fixed Deposit, Master Bedroom Locker',
                  prefixIcon: Icon(Icons.bookmark_outline),
                ),
              ),

              const SizedBox(height: AppDimensions.spaceMd),

              Text('Institution / Branch', style: AppTypography.labelMd()),
              const SizedBox(height: 6),
              TextField(
                controller: _institutionController,
                decoration: const InputDecoration(
                  hintText: 'Bank, agency, or office location',
                  prefixIcon: Icon(Icons.account_balance_outlined),
                ),
              ),

              const SizedBox(height: AppDimensions.spaceMd),

              // Dual Row: Amount & Maturity
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Deposit Amount', style: AppTypography.labelMd()),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _amountController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            hintText: '5,00,000',
                            prefixText: '₹ ',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppDimensions.spaceSm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Maturity Date', style: AppTypography.labelMd()),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _maturityController,
                          decoration: InputDecoration(
                            hintText: '12 Apr 2028',
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.calendar_today, size: 18),
                              onPressed: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: DateTime.now().add(const Duration(days: 365)),
                                  firstDate: DateTime(2000),
                                  lastDate: DateTime(2050),
                                );
                                if (picked != null) {
                                  _maturityController.text = DateFormatter.formatRecordDate(picked);
                                }
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppDimensions.spaceMd),

              Text('Registered Nominee', style: AppTypography.labelMd()),
              const SizedBox(height: 6),
              TextField(
                controller: _nomineeController,
                decoration: const InputDecoration(
                  hintText: 'Full legal name as per government IDs',
                  prefixIcon: Icon(Icons.family_restroom),
                ),
              ),

              const SizedBox(height: AppDimensions.spaceMd),

              // Personal Diary Notes (Warm Archival Paper textarea)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.edit_note, size: 18, color: isDark ? AppColors.darkPrimary : AppColors.primary),
                      const SizedBox(width: 4),
                      Text('Personal Instructions & Safe Spot', style: AppTypography.labelMd()),
                    ],
                  ),
                  Text('Private note', style: AppTypography.labelSm()),
                ],
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _notesController,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Where is the physical certificate kept? Specific instructions for family...',
                ),
              ),

              const SizedBox(height: AppDimensions.spaceMd),

              // Attached Ledger Photo / Slip Preview
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Attached Ledger Photo / Slip', style: AppTypography.labelMd()),
                  TextButton.icon(
                    onPressed: _pickAttachmentModal,
                    icon: Icon(
                      _attachedFileName != null ? Icons.photo_camera_back : Icons.add_a_photo,
                      size: 16,
                      color: isDark ? AppColors.darkPrimary : AppColors.primary,
                    ),
                    label: Text(_attachedFileName != null ? 'Change Photo' : 'Add Photo'),
                  ),
                ],
              ),

              if (_attachedFileName != null) ...[
                AppCard(
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: _buildAttachmentThumbnail(isDark),
                      ),
                      const SizedBox(width: AppDimensions.spaceSm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _attachedFileName!,
                              style: AppTypography.labelMd(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              _attachedFileSize > 0
                                  ? '${(_attachedFileSize / (1024 * 1024)).toStringAsFixed(1)} MB • Attached photo'
                                  : 'Attached photo',
                              style: AppTypography.bodySm(),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () => setState(() {
                          _attachedFileName = null;
                          _attachedFilePath = null;
                          _attachedFileBytes = null;
                          _attachedFileSize = 0;
                        }),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppDimensions.spaceMd),
              ],

              // Custom Fields List (if any added)
              if (_customFields.isNotEmpty) ...[
                Text('Additional Custom Details', style: AppTypography.labelMd()),
                const SizedBox(height: 6),
                ..._customFields.map((f) => Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: AppCard(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(f.fieldName, style: AppTypography.labelMd()),
                                Text(
                                  f.isSensitive ? '•••• ••••' : f.fieldValue,
                                  style: AppTypography.bodySm(),
                                ),
                              ],
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 18),
                              onPressed: () => setState(() => _customFields.remove(f)),
                            ),
                          ],
                        ),
                      ),
                    )),
                const SizedBox(height: AppDimensions.spaceMd),
              ],

              // Dynamic Custom Detail Drawer Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.add_circle_outline),
                  label: const Text('Add Custom Detail (Locker, PIN, Code)'),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusLg)),
                  ),
                  onPressed: _openCustomFieldDrawer,
                ),
              ),

              const SizedBox(height: AppDimensions.spaceLg),

              // Action Buttons
              AppButton(
                text: 'Save to Vault',
                leadingIcon: Icons.lock,
                isLoading: _isSaving,
                width: double.infinity,
                onPressed: _saveEntry,
              ),

              const SizedBox(height: AppDimensions.spaceSm),

              AppButton(
                text: 'Cancel & Discard',
                variant: AppButtonVariant.ghost,
                width: double.infinity,
                onPressed: () => context.pop(),
              ),

              const SizedBox(height: AppDimensions.spaceXl * 2),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAttachmentThumbnail(bool isDark) {
    if (_attachedFileBytes != null && _isAttachedImage) {
      return Image.memory(
        _attachedFileBytes!,
        width: 48,
        height: 48,
        fit: BoxFit.cover,
      );
    }
    if (_attachedFilePath != null && _isAttachedImage && !kIsWeb) {
      return Image.file(
        File(_attachedFilePath!),
        width: 48,
        height: 48,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildFallbackIcon(isDark),
      );
    }
    return _buildFallbackIcon(isDark);
  }

  Widget _buildFallbackIcon(bool isDark) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceContainerHigh : AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        _isAttachedImage ? Icons.image : Icons.picture_as_pdf,
        size: 24,
        color: isDark ? AppColors.darkPrimary : AppColors.primary,
      ),
    );
  }
}
