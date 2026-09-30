import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
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

class _CategoryFieldDef {
  final String key;
  final String label;
  final String hint;
  final IconData icon;
  final EntryFieldType type;
  final bool isSensitive;

  const _CategoryFieldDef({
    required this.key,
    required this.label,
    required this.hint,
    required this.icon,
    this.type = EntryFieldType.text,
    this.isSensitive = false,
  });
}

class _AttachedFileItem {
  final String id;
  final String fileName;
  final String? localFilePath;
  final Uint8List? bytes;
  final int size;
  final bool isImage;

  _AttachedFileItem({
    required this.id,
    required this.fileName,
    this.localFilePath,
    this.bytes,
    required this.size,
    this.isImage = true,
  });
}

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
  late TextEditingController _notesController;
  final Map<String, TextEditingController> _fieldControllers = {};
  final List<EntryField> _customFields = [];

  bool _isSaving = false;
  final List<_AttachedFileItem> _attachedFiles = [];

  @override
  void initState() {
    super.initState();
    final e = widget.entry;
    _nameController = TextEditingController(text: e?.title ?? '');
    _notesController = TextEditingController(text: e?.notes ?? '');

    if (e != null && e.attachments.isNotEmpty) {
      for (final att in e.attachments) {
        Uint8List? fileBytes;
        if (att.localFilePath != null && !kIsWeb && File(att.localFilePath!).existsSync()) {
          try {
            fileBytes = File(att.localFilePath!).readAsBytesSync();
          } catch (_) {}
        }
        _attachedFiles.add(
          _AttachedFileItem(
            id: att.id,
            fileName: att.fileName,
            localFilePath: att.localFilePath,
            bytes: fileBytes,
            size: att.size,
            isImage: att.isImage,
          ),
        );
      }
    }
  }

  Future<String> _savePhotoToAppDocuments(String originalName, Uint8List bytes) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final attachmentsDir = Directory('${appDir.path}/attachments');
      if (!attachmentsDir.existsSync()) {
        attachmentsDir.createSync(recursive: true);
      }
      final cleanName = originalName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
      final path = '${attachmentsDir.path}/${DateTime.now().millisecondsSinceEpoch}_$cleanName';
      final file = File(path);
      await file.writeAsBytes(bytes);

      // Save under direct filenames so any member on this device can find it instantly
      try {
        await File('${attachmentsDir.path}/$cleanName').writeAsBytes(bytes);
        if (cleanName != originalName) {
          await File('${attachmentsDir.path}/$originalName').writeAsBytes(bytes);
        }
      } catch (_) {}

      return file.path;
    } catch (_) {
      return '';
    }
  }

  List<_CategoryFieldDef> _getFieldsForCategory(String categoryName) {
    final lower = categoryName.toLowerCase();
    if (lower.contains('key') || lower.contains('place') || lower.contains('locker')) {
      return const [
        _CategoryFieldDef(
          key: 'Place Kept',
          label: 'Where is it Kept? (Safe Spot)',
          hint: 'e.g. Master bedroom almirah top drawer, Home safe',
          icon: Icons.place_outlined,
        ),
        _CategoryFieldDef(
          key: 'Bank / Institution',
          label: 'Bank / Branch / Institution',
          hint: 'e.g. State Bank of India, HDFC Indiranagar',
          icon: Icons.account_balance_outlined,
        ),
        _CategoryFieldDef(
          key: 'Locker Number',
          label: 'Locker Number / Key Code',
          hint: 'e.g. Locker #204, Key LK-994, Safe PIN 4812',
          icon: Icons.vpn_key_outlined,
          type: EntryFieldType.secret,
          isSensitive: true,
        ),
      ];
    } else if (lower.contains('insurance')) {
      return const [
        _CategoryFieldDef(
          key: 'Insurance Provider',
          label: 'Insurance Provider / Company',
          hint: 'e.g. Life Insurance Corporation (LIC), Star Health',
          icon: Icons.verified_user_outlined,
        ),
        _CategoryFieldDef(
          key: 'Policy Number',
          label: 'Policy Number',
          hint: 'e.g. 842109281',
          icon: Icons.tag_outlined,
          type: EntryFieldType.secret,
          isSensitive: true,
        ),
        _CategoryFieldDef(
          key: 'Sum Assured',
          label: 'Sum Assured / Coverage Amount',
          hint: 'e.g. 10,00,000',
          icon: Icons.shield_outlined,
          type: EntryFieldType.currency,
        ),
        _CategoryFieldDef(
          key: 'Premium Due Date',
          label: 'Premium Due Date / Renewal',
          hint: 'e.g. 15 March Annually',
          icon: Icons.event_outlined,
          type: EntryFieldType.date,
        ),
        _CategoryFieldDef(
          key: 'Registered Nominee',
          label: 'Registered Nominee',
          hint: 'e.g. Spouse / Child',
          icon: Icons.family_restroom,
        ),
      ];
    } else if (lower.contains('card') || lower.contains('bank')) {
      return const [
        _CategoryFieldDef(
          key: 'Bank Name',
          label: 'Bank / Issuing Institution',
          hint: 'e.g. HDFC Bank, ICICI Bank, SBI',
          icon: Icons.account_balance_outlined,
        ),
        _CategoryFieldDef(
          key: 'Account / Card Type',
          label: 'Account / Card Type',
          hint: 'e.g. Salary Savings A/c, Visa Platinum Card',
          icon: Icons.credit_card_outlined,
        ),
        _CategoryFieldDef(
          key: 'Account Number',
          label: 'Account / Card Last 4 Digits',
          hint: 'e.g. •••• 4821 or full account number',
          icon: Icons.pin_outlined,
          type: EntryFieldType.secret,
          isSensitive: true,
        ),
        _CategoryFieldDef(
          key: 'Branch / IFSC',
          label: 'Branch / IFSC Code',
          hint: 'e.g. HDFC0000123, Indiranagar',
          icon: Icons.location_city_outlined,
        ),
        _CategoryFieldDef(
          key: 'Registered Nominee',
          label: 'Registered Nominee',
          hint: 'e.g. Nominee name registered with bank',
          icon: Icons.family_restroom,
        ),
      ];
    } else if (lower.contains('property')) {
      return const [
        _CategoryFieldDef(
          key: 'Property Address',
          label: 'Property Address & Location',
          hint: 'e.g. Flat 302, Palm Grove, Whitefield',
          icon: Icons.location_on_outlined,
        ),
        _CategoryFieldDef(
          key: 'Document Type',
          label: 'Document / Title Deed Type',
          hint: 'e.g. Registered Sale Deed, Mutation Khata',
          icon: Icons.description_outlined,
        ),
        _CategoryFieldDef(
          key: 'Documents Kept At',
          label: 'Physical Documents Safe Spot',
          hint: 'e.g. SBI Indiranagar Locker #401, Fireproof safe',
          icon: Icons.inventory_2_outlined,
        ),
        _CategoryFieldDef(
          key: 'Registered Owners',
          label: 'Registered Owners / Nominees',
          hint: 'e.g. Joint - Self & Spouse',
          icon: Icons.people_outline,
        ),
      ];
    } else if (lower.contains('doc') || lower.contains('paper') || lower.contains('important')) {
      return const [
        _CategoryFieldDef(
          key: 'Document Type',
          label: 'Document Type / Identification',
          hint: 'e.g. Passport, Aadhaar Card, PAN Card, Will',
          icon: Icons.badge_outlined,
        ),
        _CategoryFieldDef(
          key: 'Document / ID Number',
          label: 'Document / Registration Number',
          hint: 'e.g. Document or Passport Number',
          icon: Icons.tag_outlined,
          type: EntryFieldType.secret,
          isSensitive: true,
        ),
        _CategoryFieldDef(
          key: 'Issuing Authority / Validity',
          label: 'Issuing Authority / Expiry Date',
          hint: 'e.g. Govt of India / Valid until 2032',
          icon: Icons.event_available_outlined,
        ),
        _CategoryFieldDef(
          key: 'Physical Location Kept',
          label: 'Physical Document Safe Spot',
          hint: 'e.g. Study desk bottom drawer in blue binder',
          icon: Icons.folder_open_outlined,
        ),
      ];
    } else if (lower.contains('invest')) {
      return const [
        _CategoryFieldDef(
          key: 'Institution / Branch',
          label: 'Institution / Fund House / Branch',
          hint: 'e.g. State Bank of India, Zerodha, HDFC Mutual Fund',
          icon: Icons.account_balance_outlined,
        ),
        _CategoryFieldDef(
          key: 'Deposit Amount',
          label: 'Deposit Amount / Investment Value',
          hint: 'e.g. 5,00,000',
          icon: Icons.payments_outlined,
          type: EntryFieldType.currency,
        ),
        _CategoryFieldDef(
          key: 'Certificate / Account',
          label: 'Folio / Certificate / Account #',
          hint: 'e.g. 3049 8219 4821',
          icon: Icons.pin_outlined,
          type: EntryFieldType.secret,
          isSensitive: true,
        ),
        _CategoryFieldDef(
          key: 'Maturity Date',
          label: 'Maturity Date / Horizon',
          hint: 'e.g. 12 Apr 2028',
          icon: Icons.calendar_today_outlined,
          type: EntryFieldType.date,
        ),
        _CategoryFieldDef(
          key: 'Registered Nominee',
          label: 'Registered Nominee',
          hint: 'e.g. Full legal nominee name',
          icon: Icons.family_restroom,
        ),
      ];
    } else {
      return const [
        _CategoryFieldDef(
          key: 'Primary Detail',
          label: 'Primary Identifier / Detail',
          hint: 'e.g. Reference number, Serial, or Code',
          icon: Icons.info_outline,
        ),
        _CategoryFieldDef(
          key: 'Place Kept / Location',
          label: 'Physical Location / Safe Spot',
          hint: 'e.g. Where is this item or document kept?',
          icon: Icons.place_outlined,
        ),
        _CategoryFieldDef(
          key: 'Contact / Nominee',
          label: 'Custodian / Nominee / Contact',
          hint: 'e.g. Trusted person or contact details',
          icon: Icons.person_outline,
        ),
      ];
    }
  }

  void _ensureControllers(List<_CategoryFieldDef> defs) {
    final knownKeys = defs.map((d) => d.key).toSet();
    for (final def in defs) {
      if (!_fieldControllers.containsKey(def.key)) {
        final existingVal = widget.entry?.getFieldValue(def.key) ?? '';
        _fieldControllers[def.key] = TextEditingController(text: existingVal);
      }
    }

    if (widget.entry != null && _customFields.isEmpty) {
      for (final f in widget.entry!.fields) {
        if (!knownKeys.contains(f.fieldName)) {
          _customFields.add(f);
        }
      }
    }
  }

  Future<void> _pickAttachmentModal() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Material(
          color: isDark ? AppColors.darkSurface : AppColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(AppDimensions.radiusXl)),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.margin),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
              children: [
                Text('Attach Photo or Document', style: AppTypography.headlineSm(context: ctx)),
                const SizedBox(height: AppDimensions.spaceSm),
                Text(
                  'Photos and receipts are saved privately in your vault.',
                  style: AppTypography.bodySm(context: ctx),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppDimensions.spaceMd),
                ListTile(
                  leading: Icon(Icons.camera_alt_outlined, color: isDark ? AppColors.darkPrimary : AppColors.primary),
                  title: Text('Take Photo with Camera', style: AppTypography.labelLg(context: ctx)),
                  subtitle: Text('Capture paper passbook, certificate, safe key', style: AppTypography.bodySm(context: ctx)),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final picker = ImagePicker();
                    final photo = await picker.pickImage(source: ImageSource.camera, maxWidth: 1920, maxHeight: 1920, imageQuality: 85);
                    if (photo != null) {
                      final bytes = await photo.readAsBytes();
                      final savedPath = await _savePhotoToAppDocuments(photo.name, bytes);
                      setState(() {
                        _attachedFiles.add(
                          _AttachedFileItem(
                            id: const Uuid().v4(),
                            fileName: photo.name,
                            localFilePath: savedPath.isNotEmpty ? savedPath : photo.path,
                            bytes: bytes,
                            size: bytes.length,
                            isImage: true,
                          ),
                        );
                      });
                    }
                  },
                ),
                ListTile(
                  leading: Icon(Icons.photo_library_outlined, color: isDark ? AppColors.darkPrimary : AppColors.primary),
                  title: Text('Choose Photos from Gallery', style: AppTypography.labelLg(context: ctx)),
                  subtitle: Text('Select one or more images from device gallery', style: AppTypography.bodySm(context: ctx)),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final picker = ImagePicker();
                    final photos = await picker.pickMultiImage(maxWidth: 1920, maxHeight: 1920, imageQuality: 85);
                    if (photos.isNotEmpty) {
                      final List<_AttachedFileItem> newItems = [];
                      for (final photo in photos) {
                        final bytes = await photo.readAsBytes();
                        final savedPath = await _savePhotoToAppDocuments(photo.name, bytes);
                        newItems.add(
                          _AttachedFileItem(
                            id: const Uuid().v4(),
                            fileName: photo.name,
                            localFilePath: savedPath.isNotEmpty ? savedPath : photo.path,
                            bytes: bytes,
                            size: bytes.length,
                            isImage: true,
                          ),
                        );
                      }
                      setState(() {
                        _attachedFiles.addAll(newItems);
                      });
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _notesController.dispose();
    for (final c in _fieldControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _openCustomFieldDrawer() {
    final fieldNameCtrl = TextEditingController();
    final fieldValueCtrl = TextEditingController();
    EntryFieldType selectedType = EntryFieldType.text;
    bool isSensitive = false;

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
            child: SingleChildScrollView(
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
                    'Add any extra note, key type, locker code, or specific detail for this entry.',
                    style: AppTypography.bodySm(),
                  ),
                  const SizedBox(height: AppDimensions.spaceMd),

                  // Field Name Input
                  Text('Field Name / Title', style: AppTypography.labelMd()),
                  const SizedBox(height: 6),
                  TextField(
                    controller: fieldNameCtrl,
                    decoration: const InputDecoration(
                      hintText: 'e.g. Key Type, Safe Combination, Locker PIN',
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
                        setSheetState(() {
                          selectedType = t;
                          if (t != EntryFieldType.secret) isSensitive = false;
                        });
                      }),
                      _buildTypeChip('Secret Code', EntryFieldType.secret, Icons.key, selectedType, (t) {
                        setSheetState(() {
                          selectedType = t;
                          isSensitive = true;
                        });
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
                      _buildTypeChip('Phone', EntryFieldType.phone, Icons.call, selectedType, (t) {
                        setSheetState(() => selectedType = t);
                      }),
                    ],
                  ),

                  const SizedBox(height: AppDimensions.spaceMd),

                  // Field Value Input
                  Text('Field Value / Content', style: AppTypography.labelMd()),
                  const SizedBox(height: 6),
                  TextField(
                    controller: fieldValueCtrl,
                    obscureText: selectedType == EntryFieldType.secret,
                    decoration: InputDecoration(
                      hintText: 'e.g. Small, Master Brass Key, 4921',
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
    final accent = AppColors.accent(isDark);
    final textOnAccent = AppColors.textOnAccent(isDark);

    return ChoiceChip(
      avatar: Icon(
        icon,
        size: 16,
        color: isSelected ? textOnAccent : (isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant),
      ),
      label: Text(label),
      selected: isSelected,
      selectedColor: accent,
      labelStyle: TextStyle(
        color: isSelected ? textOnAccent : (isDark ? AppColors.darkOnSurface : AppColors.onSurface),
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
      ),
      onSelected: (val) {
        if (val) onSelect(type);
      },
    );
  }

  Future<void> _saveEntry(List<_CategoryFieldDef> templateDefs, String categoryName) async {
    if (!ref.read(isVaultOwnerProvider)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only the Vault Admin can save or edit records.')),
      );
      return;
    }

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

      final fields = <EntryField>[];
      for (int i = 0; i < templateDefs.length; i++) {
        final def = templateDefs[i];
        final val = _fieldControllers[def.key]?.text.trim() ?? '';
        if (val.isNotEmpty) {
          fields.add(
            EntryField(
              id: 'f-tmpl-$i',
              entryId: widget.entry?.id ?? '',
              fieldName: def.key,
              fieldType: def.type,
              fieldValue: val,
              isSensitive: def.isSensitive,
              position: i,
            ),
          );
        }
      }
      fields.addAll(_customFields);

      final List<Attachment> attachments = [];
      for (final item in _attachedFiles) {
        attachments.add(
          Attachment(
            id: item.id.isNotEmpty ? item.id : const Uuid().v4(),
            entryId: widget.entry?.id ?? '',
            storagePath: 'vaults/${vault.id}/entries/${item.fileName}',
            fileName: item.fileName,
            mimeType: item.isImage ? 'image/jpeg' : 'application/pdf',
            size: item.size > 0 ? item.size : 1468000,
            createdAt: DateTime.now(),
            localFilePath: item.localFilePath,
          ),
        );
      }

      final entryToSave = Entry(
        id: widget.entry?.id ?? const Uuid().v4(),
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

      // Real audit log action with authenticated user
      ref.read(auditRepositoryProvider).logAction(
        vaultId: vault.id,
        userId: user?.id ?? 'user',
        userDisplayName: user?.displayName ?? 'Admin',
        action: widget.entry != null ? 'ENTRY_UPDATED' : 'ENTRY_CREATED',
        entityType: 'ENTRY',
        metadata: {'title_hint': title, 'category': categoryName},
      );
      ref.invalidate(auditLogsProvider);

      // Invalidate both categoryEntriesProvider AND categoriesProvider
      // so the home screen record count immediately reflects changes!
      ref.invalidate(categoryEntriesProvider(widget.categoryId));
      ref.invalidate(categoriesProvider);

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
    final isOwner = ref.watch(isVaultOwnerProvider);

    if (!isOwner) {
      return Scaffold(
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.surface,
        appBar: AppBar(title: const Text('Access Restricted')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.margin),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.shield_outlined, size: 64, color: isDark ? AppColors.darkPrimary : AppColors.primary),
                const SizedBox(height: AppDimensions.spaceMd),
                Text('Read-Only Access', style: AppTypography.headlineSm(context: context)),
                const SizedBox(height: AppDimensions.spaceSm),
                Text(
                  'Co-Guardians have read-only access to records. Adding, editing, or deleting entries is restricted to the Vault Admin.',
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyMd(context: context),
                ),
                const SizedBox(height: AppDimensions.spaceLg),
                AppButton(
                  text: 'Return to Vault',
                  width: double.infinity,
                  onPressed: () => context.pop(),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final categories = ref.watch(categoriesProvider).asData?.value ?? [];
    final category = categories.where((c) => c.id == widget.categoryId).firstOrNull;
    final categoryName = category?.name ?? (widget.entry != null ? 'Vault Entry' : 'Entry');
    final templateDefs = _getFieldsForCategory(categoryName);
    _ensureControllers(templateDefs);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.surface,
      appBar: AppBar(
        title: Text(widget.entry != null ? 'Edit $categoryName' : 'New $categoryName Entry'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppDimensions.margin),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppDimensions.spaceSm),

              // Context Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
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
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 6,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: isDark ? AppColors.darkSecondaryContainer : AppColors.secondaryContainer,
                                borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                              ),
                              child: Text(categoryName, style: AppTypography.labelSm()),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
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
                                Text('End-to-End Encrypted', style: AppTypography.labelSm()),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurfaceContainerHigh : AppColors.surfaceContainerHigh,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.shield_outlined, color: isDark ? AppColors.darkPrimary : AppColors.primary, size: 20),
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
                            'Only authorized circle members can view this record and its safe spot details.',
                            style: AppTypography.bodySm(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppDimensions.spaceMd),

              // Entry Name (Required)
              Text('Entry Name / Title (Required)', style: AppTypography.labelMd()),
              const SizedBox(height: 6),
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  hintText: 'e.g. $categoryName Title',
                  prefixIcon: const Icon(Icons.bookmark_outline),
                ),
              ),

              const SizedBox(height: AppDimensions.spaceMd),

              // Category Tailored Fields
              ...templateDefs.map((def) {
                final ctrl = _fieldControllers[def.key]!;
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppDimensions.spaceMd),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(def.label, style: AppTypography.labelMd()),
                      const SizedBox(height: 6),
                      TextField(
                        controller: ctrl,
                        keyboardType: def.type == EntryFieldType.currency || def.type == EntryFieldType.number
                            ? TextInputType.number
                            : TextInputType.text,
                        decoration: InputDecoration(
                          hintText: def.hint,
                          prefixIcon: Icon(def.icon),
                          prefixText: def.type == EntryFieldType.currency ? '₹ ' : null,
                          suffixIcon: def.type == EntryFieldType.date
                              ? IconButton(
                                  icon: const Icon(Icons.calendar_today, size: 18),
                                  onPressed: () async {
                                    final picked = await showDatePicker(
                                      context: context,
                                      initialDate: DateTime.now().add(const Duration(days: 365)),
                                      firstDate: DateTime(2000),
                                      lastDate: DateTime(2050),
                                    );
                                    if (picked != null) {
                                      ctrl.text = DateFormatter.formatRecordDate(picked);
                                    }
                                  },
                                )
                              : null,
                        ),
                      ),
                    ],
                  ),
                );
              }),

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
                  hintText: 'Where is the physical item, certificate, or key kept? Specific instructions for family...',
                ),
              ),

              const SizedBox(height: AppDimensions.spaceMd),

              // Attached Ledger Photos / Slips (Multi-image support)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      _attachedFiles.isEmpty
                          ? 'Attached Photos & Slips'
                          : 'Attached Photos (${_attachedFiles.length})',
                      style: AppTypography.labelMd(),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: _pickAttachmentModal,
                    icon: Icon(
                      Icons.add_a_photo,
                      size: 16,
                      color: isDark ? AppColors.darkPrimary : AppColors.primary,
                    ),
                    label: Text(_attachedFiles.isEmpty ? 'Add Photos' : 'Add More'),
                  ),
                ],
              ),

              if (_attachedFiles.isNotEmpty) ...[
                Column(
                  children: _attachedFiles.asMap().entries.map((entry) {
                    final index = entry.key;
                    final item = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppDimensions.spaceSm),
                      child: AppCard(
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: _buildItemThumbnail(item, isDark),
                            ),
                            const SizedBox(width: AppDimensions.spaceSm),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.fileName,
                                    style: AppTypography.labelMd(),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    item.size > 0
                                        ? '${(item.size / (1024 * 1024)).toStringAsFixed(1)} MB • Photo ${index + 1}'
                                        : 'Attached photo ${index + 1}',
                                    style: AppTypography.bodySm(),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, size: 18),
                              tooltip: 'Remove photo',
                              onPressed: () {
                                setState(() {
                                  _attachedFiles.removeAt(index);
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: AppDimensions.spaceSm),
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
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(f.fieldName, style: AppTypography.labelMd(), overflow: TextOverflow.ellipsis),
                                  Text(
                                    f.isSensitive ? '•••• ••••' : f.fieldValue,
                                    style: AppTypography.bodySm(),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
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
                  label: const Text('Add a Detail (Title & Content)'),
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
                onPressed: () => _saveEntry(templateDefs, categoryName),
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

  Widget _buildItemThumbnail(_AttachedFileItem item, bool isDark) {
    if (item.bytes != null && item.isImage) {
      return Image.memory(
        item.bytes!,
        width: 48,
        height: 48,
        fit: BoxFit.cover,
      );
    }
    if (item.localFilePath != null && item.isImage && !kIsWeb) {
      return Image.file(
        File(item.localFilePath!),
        width: 48,
        height: 48,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildFallbackIcon(item.isImage, isDark),
      );
    }
    return _buildFallbackIcon(item.isImage, isDark);
  }

  Widget _buildFallbackIcon(bool isImage, bool isDark) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceContainerHigh : AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        isImage ? Icons.image : Icons.picture_as_pdf,
        size: 24,
        color: isDark ? AppColors.darkPrimary : AppColors.primary,
      ),
    );
  }
}
