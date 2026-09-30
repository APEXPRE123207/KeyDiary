import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../../core/network/supabase_client.dart';
import '../../../core/security/encryption_service.dart';
import '../../../core/security/secure_storage_service.dart';
import '../domain/entry.dart';
import '../domain/entry_field.dart';
import '../domain/attachment.dart';

/// Repository for client-side encrypted vault entries and emergency sync
class EntryRepository {
  final List<Entry> _localEntries = [];
  bool _loaded = false;

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    try {
      final stored = await SecureStorageService.getLocalEntries();
      _localEntries.clear();
      _localEntries.addAll(stored.map((e) => Entry.fromJson(e)));

      bool migrated = false;
      for (int i = 0; i < _localEntries.length; i++) {
        if (!_isValidUuid(_localEntries[i].vaultId)) {
          final activeVid = await SecureStorageService.getActiveVaultId();
          final targetVid = (activeVid != null && _isValidUuid(activeVid)) ? activeVid : const Uuid().v4();
          _localEntries[i] = _localEntries[i].copyWith(vaultId: targetVid);
          migrated = true;
        }
      }
      if (migrated) {
        await _persist();
      }

      _loaded = true;
    } catch (_) {
      _loaded = true;
    }
  }

  Future<void> _persist() async {
    await SecureStorageService.saveLocalEntries(
      _localEntries.map((e) => e.toJson()).toList(),
    );
  }

  Future<List<Entry>> getEntriesByCategory({
    required String categoryId,
    required Uint8List vekBytes,
    String? vaultId,
  }) async {
    await _ensureLoaded();

    if (SupabaseService.isInitialized) {
      try {
        final client = Supabase.instance.client;

        // 1. Fetch entries with fields and attachments
        var query = client
            .from('entries')
            .select('*, entry_fields(*), attachments(*)')
            .eq('category_id', categoryId);

        if (vaultId != null && vaultId.isNotEmpty) {
          query = query.eq('vault_id', vaultId);
        }

        final res = await query
            .order('created_at', ascending: false)
            .timeout(const Duration(seconds: 4));

        final List<Entry> decryptedList = [];

        for (final raw in (res as List)) {
          try {
            // Decrypt title & notes
            final title = await EncryptionService.decryptString(
              raw['title_encrypted'] as String,
              vekBytes,
            );

          String? notes;
          if (raw['notes_encrypted'] != null && (raw['notes_encrypted'] as String).isNotEmpty) {
            try {
              notes = await EncryptionService.decryptString(
                raw['notes_encrypted'] as String,
                vekBytes,
              );
            } catch (_) {}
          }

          // Decrypt custom fields
          final rawFields = raw['entry_fields'] as List? ?? [];
          final List<EntryField> fields = [];
          for (final f in rawFields) {
            final fName = await EncryptionService.decryptString(
              f['field_name_encrypted'] as String,
              vekBytes,
            );
            final fVal = await EncryptionService.decryptString(
              f['field_value_encrypted'] as String,
              vekBytes,
            );

            fields.add(
              EntryField(
                id: f['id'] as String,
                entryId: raw['id'] as String,
                fieldName: fName,
                fieldType: EntryFieldType.fromString(f['field_type'] as String),
                fieldValue: fVal,
                position: f['position'] as int? ?? 0,
                isSensitive: f['is_sensitive'] as bool? ?? false,
              ),
            );
          }

          // Decrypt attachments metadata
          final rawAttachments = raw['attachments'] as List? ?? [];
          final List<Attachment> attachments = [];
          Directory? localAttachmentsDir;
          try {
            final appDir = await getApplicationDocumentsDirectory();
            localAttachmentsDir = Directory('${appDir.path}/attachments');
          } catch (_) {}

          for (final a in rawAttachments) {
            final fileName = await EncryptionService.decryptString(
              a['file_name_encrypted'] as String,
              vekBytes,
            );

            String? matchedLocalPath;
            final cleanSearch = fileName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
            if (localAttachmentsDir != null && localAttachmentsDir.existsSync()) {
              for (final entity in localAttachmentsDir.listSync()) {
                if (entity is File) {
                  final base = entity.uri.pathSegments.last.toLowerCase();
                  final cleanBase = base.replaceAll(RegExp(r'[^a-z0-9]'), '');
                  if (base.endsWith(fileName.toLowerCase()) ||
                      cleanBase.endsWith(cleanSearch) ||
                      cleanBase.contains(cleanSearch) ||
                      (a['id'] != null && entity.path.contains(a['id'] as String))) {
                    matchedLocalPath = entity.path;
                    break;
                  }
                }
              }
            }

            // Fallback: check existing local entries to see if we already had a valid file path for this attachment
            if (matchedLocalPath == null) {
              final existingEntry = _localEntries.where((e) => e.id == raw['id']).firstOrNull;
              if (existingEntry != null) {
                final existingAtt = existingEntry.attachments.where((att) =>
                  att.fileName.toLowerCase() == fileName.toLowerCase() ||
                  att.id == a['id']
                ).firstOrNull;
                if (existingAtt?.localFilePath != null && File(existingAtt!.localFilePath!).existsSync()) {
                  matchedLocalPath = existingAtt.localFilePath;
                }
              }
            }

            attachments.add(
              Attachment(
                id: a['id'] as String? ?? '',
                entryId: raw['id'] as String,
                storagePath: a['storage_path'] as String? ?? '',
                fileName: fileName,
                mimeType: a['mime_type'] as String? ?? '',
                size: a['size'] as int? ?? 0,
                createdAt: DateTime.tryParse(a['created_at']?.toString() ?? '') ?? DateTime.now(),
                localFilePath: matchedLocalPath,
              ),
            );
          }

          decryptedList.add(
            Entry(
              id: raw['id'] as String,
              categoryId: raw['category_id'] as String,
              vaultId: raw['vault_id'] as String,
              title: title,
              notes: notes,
              isPinned: raw['is_pinned'] as bool? ?? false,
              createdBy: raw['created_by'] as String?,
              createdAt: DateTime.parse(raw['created_at'] as String),
              updatedAt: DateTime.parse(raw['updated_at'] as String),
              fields: fields,
              attachments: attachments,
            ),
          );
        } catch (_) {
          // Decryption failure for this specific item: continue with other items
        }
      }

        // Save downloaded and decrypted entries to local phone storage while preserving existing valid local attachment paths
        for (final remoteEntry in decryptedList) {
          final idx = _localEntries.indexWhere((e) => e.id == remoteEntry.id);
          if (idx != -1) {
            final existingAtts = _localEntries[idx].attachments;
            final mergedAtts = remoteEntry.attachments.map((remAtt) {
              if (remAtt.localFilePath != null && File(remAtt.localFilePath!).existsSync()) {
                return remAtt;
              }
              final existingMatch = existingAtts.where((locAtt) =>
                (locAtt.id == remAtt.id || locAtt.fileName.toLowerCase() == remAtt.fileName.toLowerCase()) &&
                locAtt.localFilePath != null &&
                File(locAtt.localFilePath!).existsSync()
              ).firstOrNull;
              if (existingMatch != null) {
                return remAtt.copyWith(localFilePath: existingMatch.localFilePath);
              }
              return remAtt;
            }).toList();
            _localEntries[idx] = remoteEntry.copyWith(attachments: mergedAtts);
          } else {
            _localEntries.add(remoteEntry);
          }
        }
        if (decryptedList.isNotEmpty) {
          await _persist();
        }
      } catch (_) {
        // Offline or slow network: smoothly use phone local data
      }
    }

    if (vaultId != null && vaultId.isNotEmpty) {
      final direct = _localEntries.where((e) => e.categoryId == categoryId && e.vaultId == vaultId).toList();
      if (direct.isNotEmpty) return direct;
      // If direct match by vaultId is empty, but entries exist for this categoryId on device, return them
      final byCat = _localEntries.where((e) => e.categoryId == categoryId).toList();
      if (byCat.isNotEmpty) return byCat;
    }
    return _localEntries.where((e) => e.categoryId == categoryId).toList();
  }

  Future<List<Entry>> getAllVaultEntries({
    required String vaultId,
  }) async {
    await _ensureLoaded();
    final direct = _localEntries.where((e) => e.vaultId == vaultId).toList();
    if (direct.isNotEmpty) return direct;
    return List.unmodifiable(_localEntries);
  }

  static bool _isValidUuid(String? id) {
    if (id == null) return false;
    return RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')
        .hasMatch(id);
  }

  Future<Entry> saveEntry({
    required Entry entry,
    required Uint8List vekBytes,
    String? userId,
  }) async {
    await _ensureLoaded();

    String effectiveVaultId = entry.vaultId;
    if (!_isValidUuid(effectiveVaultId)) {
      final activeVid = await SecureStorageService.getActiveVaultId();
      effectiveVaultId = (activeVid != null && _isValidUuid(activeVid)) ? activeVid : const Uuid().v4();
    }

    // 1. Ensure all attachments are permanently copied into local documents directory FIRST
    final List<Attachment> preparedAttachments = [];
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final attachmentsDir = Directory('${appDir.path}/attachments');
      if (!attachmentsDir.existsSync()) {
        attachmentsDir.createSync(recursive: true);
      }

      for (final att in entry.attachments) {
        File? sourceFile;
        if (att.localFilePath != null && File(att.localFilePath!).existsSync()) {
          sourceFile = File(att.localFilePath!);
        } else {
          // Check if already in attachmentsDir
          final candidate = File('${attachmentsDir.path}/${att.fileName}');
          if (candidate.existsSync()) {
            sourceFile = candidate;
          } else {
            // Search in attachmentsDir
            final cleanSearch = att.fileName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
            for (final entity in attachmentsDir.listSync()) {
              if (entity is File) {
                final base = entity.uri.pathSegments.last.toLowerCase();
                if (base.endsWith(att.fileName.toLowerCase()) ||
                    base.replaceAll(RegExp(r'[^a-z0-9]'), '').contains(cleanSearch)) {
                  sourceFile = entity;
                  break;
                }
              }
            }
          }
        }

        String effectiveLocalPath = att.localFilePath ?? '';
        if (sourceFile != null && sourceFile.existsSync()) {
          final permFile = File('${attachmentsDir.path}/${att.fileName}');
          if (!permFile.existsSync() || permFile.path != sourceFile.path) {
            try {
              await sourceFile.copy(permFile.path);
              effectiveLocalPath = permFile.path;
            } catch (_) {
              effectiveLocalPath = sourceFile.path;
            }
          } else {
            effectiveLocalPath = permFile.path;
          }

          // Also create an ID-prefixed copy for collision-free lookup
          if (att.id.isNotEmpty) {
            final idFile = File('${attachmentsDir.path}/${att.id}_${att.fileName}');
            if (!idFile.existsSync()) {
              try {
                await sourceFile.copy(idFile.path);
              } catch (_) {}
            }
          }
        }

        preparedAttachments.add(
          att.copyWith(
            localFilePath: effectiveLocalPath.isNotEmpty ? effectiveLocalPath : att.localFilePath,
          ),
        );
      }
    } catch (_) {
      preparedAttachments.addAll(entry.attachments);
    }

    Entry completedEntry = entry.copyWith(
      vaultId: effectiveVaultId,
      attachments: preparedAttachments,
    );

    if (SupabaseService.isInitialized) {
      try {
        final client = Supabase.instance.client;

        // 1. Client-Side Encryption
        final titleEncrypted = await EncryptionService.encryptString(entry.title, vekBytes);
        final notesEncrypted = entry.notes != null && entry.notes!.isNotEmpty
            ? await EncryptionService.encryptString(entry.notes!, vekBytes)
            : null;

        // Ensure category exists in Supabase categories table first to avoid FK violation
        try {
          final catExists = await client.from('categories').select('id').eq('id', entry.categoryId).maybeSingle();
          if (catExists == null) {
            final localCats = await SecureStorageService.getLocalCategories();
            final localCat = localCats.where((c) => c['id'] == entry.categoryId).firstOrNull;
            await client.from('categories').upsert({
              'id': entry.categoryId,
              'vault_id': effectiveVaultId,
              'name': localCat?['name'] ?? 'General',
              'description': localCat?['description'],
              'icon': localCat?['icon'] ?? 'folder',
              'color': localCat?['color'] ?? '#1D5D5B',
              'position': localCat?['position'] ?? 0,
              'is_locked': localCat?['is_locked'] ?? false,
              if (_isValidUuid(userId)) 'created_by': userId,
            });
          }
        } catch (_) {}

        // Upsert entry
        final entryRes = await client.from('entries').upsert({
          if (entry.id.isNotEmpty && !entry.id.startsWith('local-') && _isValidUuid(entry.id)) 'id': entry.id,
          'category_id': entry.categoryId,
          'vault_id': effectiveVaultId,
          'title_encrypted': titleEncrypted,
          'notes_encrypted': notesEncrypted,
          'is_pinned': entry.isPinned,
          if (_isValidUuid(userId)) 'created_by': userId,
          'updated_at': DateTime.now().toIso8601String(),
        }).select().single();

        final savedEntryId = entryRes['id'] as String;

        // 2. Encrypt & Save fields
        await client.from('entry_fields').delete().eq('entry_id', savedEntryId);
        for (int i = 0; i < entry.fields.length; i++) {
          final f = entry.fields[i];
          final fNameEncrypted = await EncryptionService.encryptString(f.fieldName, vekBytes);
          final fValEncrypted = await EncryptionService.encryptString(f.fieldValue, vekBytes);

          await client.from('entry_fields').insert({
            'entry_id': savedEntryId,
            'field_name_encrypted': fNameEncrypted,
            'field_type': f.fieldType.toDbString(),
            'field_value_encrypted': fValEncrypted,
            'position': i,
            'is_sensitive': f.isSensitive,
          });
        }

        // 3. Encrypt & Save attachments metadata & upload to storage
        await client.from('attachments').delete().eq('entry_id', savedEntryId);
        final List<Attachment> savedAttachments = [];
        for (final att in preparedAttachments) {
          final fileNameEncrypted = await EncryptionService.encryptString(att.fileName, vekBytes);
          final storagePath = 'vaults/$effectiveVaultId/entries/$savedEntryId/${att.fileName}';

          File? fileToUpload;
          if (att.localFilePath != null && File(att.localFilePath!).existsSync()) {
            fileToUpload = File(att.localFilePath!);
          } else {
            try {
              final appDir = await getApplicationDocumentsDirectory();
              final directFile = File('${appDir.path}/attachments/${att.fileName}');
              if (directFile.existsSync()) {
                fileToUpload = directFile;
              }
            } catch (_) {}
          }

          if (fileToUpload != null && fileToUpload.existsSync()) {
            try {
              final appDir = await getApplicationDocumentsDirectory();
              final attDir = Directory('${appDir.path}/attachments');
              if (!attDir.existsSync()) attDir.createSync(recursive: true);
              final dest1 = File('${attDir.path}/${att.fileName}');
              if (!dest1.existsSync() || dest1.path != fileToUpload.path) {
                await fileToUpload.copy(dest1.path);
              }
              final cleanName = att.fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
              if (cleanName != att.fileName) {
                final dest2 = File('${attDir.path}/$cleanName');
                if (!dest2.existsSync()) await fileToUpload.copy(dest2.path);
              }
            } catch (_) {}

            try {
              final fileBytes = await fileToUpload.readAsBytes();
              final mimeType = att.mimeType.isNotEmpty ? att.mimeType : 'image/jpeg';
              for (final bucket in ['vault_attachments', 'attachments']) {
                bool ok = false;
                try {
                  await client.storage.from(bucket).uploadBinary(
                    storagePath,
                    fileBytes,
                    fileOptions: FileOptions(
                      upsert: true,
                      contentType: mimeType,
                    ),
                  );
                  ok = true;
                } catch (_) {
                  try {
                    await client.storage.from(bucket).uploadBinary(
                      storagePath,
                      fileBytes,
                      fileOptions: FileOptions(
                        upsert: false,
                        contentType: mimeType,
                      ),
                    );
                    ok = true;
                  } catch (_) {}
                }
                if (ok) break;
              }
            } catch (_) {}
          }

          final attRes = await client.from('attachments').insert({
            'entry_id': savedEntryId,
            'storage_path': storagePath,
            'file_name_encrypted': fileNameEncrypted,
            'mime_type': att.mimeType,
            'size': att.size,
          }).select().maybeSingle();

          savedAttachments.add(
            att.copyWith(
              id: (attRes != null && attRes['id'] != null) ? attRes['id'] as String : att.id,
              entryId: savedEntryId,
              storagePath: storagePath,
              localFilePath: att.localFilePath,
            ),
          );
        }

        completedEntry = entry.copyWith(
          id: savedEntryId,
          vaultId: effectiveVaultId,
          attachments: savedAttachments,
        );

        // 4. Sync to Emergency Store (User explicit emergency access requirement)
        try {
          await _syncToEmergencyStore(completedEntry, userId: userId ?? '');
        } catch (_) {}
      } catch (_) {
        // Offline: entry remains safely queued and stored locally on phone
      }
    }

    // ALWAYS persist in local phone storage for instant 0ms offline access
    final existingIdx = _localEntries.indexWhere((e) => e.id == completedEntry.id || e.id == entry.id);
    if (existingIdx != -1) {
      _localEntries[existingIdx] = completedEntry;
    } else {
      _localEntries.add(completedEntry);
    }
    await _persist();

    return completedEntry;
  }

  /// Syncs plaintext emergency backup to the isolated emergency_vault schema
  Future<void> _syncToEmergencyStore(Entry entry, {required String userId}) async {
    if (!SupabaseService.isInitialized || userId.isEmpty || !_isValidUuid(userId) || !_isValidUuid(entry.id)) return;
    final client = Supabase.instance.client;

    // Delete existing emergency entry for this original_entry_id
    await client
        .schema('emergency_vault')
        .from('entries')
        .delete()
        .eq('original_entry_id', entry.id);

    final emergencyEntry = await client
        .schema('emergency_vault')
        .from('entries')
        .insert({
          'original_entry_id': entry.id,
          'vault_id': entry.vaultId,
          'category_name': 'Vault Entry',
          'title_plaintext': entry.title,
          'notes_plaintext': entry.notes,
          'synced_by': userId,
        })
        .select()
        .single();

    final emEntryId = emergencyEntry['id'] as String;

    for (final f in entry.fields) {
      await client.schema('emergency_vault').from('entry_fields').insert({
        'emergency_entry_id': emEntryId,
        'field_name': f.fieldName,
        'field_type': f.fieldType.toDbString(),
        'field_value': f.fieldValue,
        'is_sensitive': f.isSensitive,
      });
    }
  }

  Future<void> deleteEntry(String entryId) async {
    await _ensureLoaded();
    _localEntries.removeWhere((e) => e.id == entryId);
    await _persist();

    if (SupabaseService.isInitialized) {
      try {
        await Supabase.instance.client.from('entries').delete().eq('id', entryId);
        await Supabase.instance.client
            .schema('emergency_vault')
            .from('entries')
            .delete()
            .eq('original_entry_id', entryId);
      } catch (_) {}
    }
  }

  /// Seeds realistic initial records (matching Image 7.html and Image 9.html)
  void seedLocalDemoEntries({required String categoryId, required String vaultId}) {
    if (_localEntries.any((e) => e.categoryId == categoryId)) return;

    final sbiFd = Entry(
      id: 'entry-sbi-fd',
      categoryId: categoryId,
      vaultId: vaultId,
      title: 'SBI Fixed Deposit',
      notes:
          'Original receipt is in the blue steel almirah, bottom wooden drawer under the tax binder. Branch manager Mr. Sharma knows about this deposit.',
      isPinned: true,
      createdAt: DateTime.now().subtract(const Duration(days: 45)),
      updatedAt: DateTime.now().subtract(const Duration(days: 45)),
      fields: [
        const EntryField(
          id: 'f1',
          entryId: 'entry-sbi-fd',
          fieldName: 'Institution / Branch',
          fieldType: EntryFieldType.text,
          fieldValue: 'State Bank of India',
        ),
        const EntryField(
          id: 'f2',
          entryId: 'entry-sbi-fd',
          fieldName: 'Deposit Amount',
          fieldType: EntryFieldType.currency,
          fieldValue: '5,00,000',
        ),
        const EntryField(
          id: 'f3',
          entryId: 'entry-sbi-fd',
          fieldName: 'Certificate / Account',
          fieldType: EntryFieldType.secret,
          fieldValue: '3049 8219 4821',
          isSensitive: true,
        ),
        const EntryField(
          id: 'f4',
          entryId: 'entry-sbi-fd',
          fieldName: 'Maturity Date',
          fieldType: EntryFieldType.date,
          fieldValue: '12 Apr 2028',
        ),
        const EntryField(
          id: 'f5',
          entryId: 'entry-sbi-fd',
          fieldName: 'Registered Nominee',
          fieldType: EntryFieldType.text,
          fieldValue: 'Child',
        ),
        const EntryField(
          id: 'f6',
          entryId: 'entry-sbi-fd',
          fieldName: 'Deposit Type',
          fieldType: EntryFieldType.text,
          fieldValue: 'Cumulative Term',
        ),
        const EntryField(
          id: 'f7',
          entryId: 'entry-sbi-fd',
          fieldName: 'Interest Rate',
          fieldType: EntryFieldType.text,
          fieldValue: '7.10% p.a.',
        ),
        const EntryField(
          id: 'f8',
          entryId: 'entry-sbi-fd',
          fieldName: 'Locker Key Number',
          fieldType: EntryFieldType.secret,
          fieldValue: 'LK-994',
          isSensitive: true,
        ),
      ],
      attachments: [
        Attachment(
          id: 'att-1',
          entryId: 'entry-sbi-fd',
          storagePath: 'demo/sbi_receipt.pdf',
          fileName: 'SBI_FD_Certificate_2024.pdf',
          mimeType: 'application/pdf',
          size: 1468006, // 1.4 MB
          createdAt: DateTime.now().subtract(const Duration(days: 40)),
        ),
      ],
    );

    final licPolicy = Entry(
      id: 'entry-lic-policy',
      categoryId: categoryId,
      vaultId: vaultId,
      title: 'LIC Investment Policy',
      notes: 'Premium auto-debited annually on 15 March from SBI savings account.',
      isPinned: false,
      createdAt: DateTime.now().subtract(const Duration(days: 120)),
      updatedAt: DateTime.now().subtract(const Duration(days: 12)),
      fields: [
        const EntryField(
          id: 'f11',
          entryId: 'entry-lic-policy',
          fieldName: 'Plan Name',
          fieldType: EntryFieldType.text,
          fieldValue: 'Jeevan Labh',
        ),
        const EntryField(
          id: 'f12',
          entryId: 'entry-lic-policy',
          fieldName: 'Policy Number',
          fieldType: EntryFieldType.secret,
          fieldValue: '842109281',
          isSensitive: true,
        ),
        const EntryField(
          id: 'f13',
          entryId: 'entry-lic-policy',
          fieldName: 'Annual Premium',
          fieldType: EntryFieldType.currency,
          fieldValue: '25,000',
        ),
        const EntryField(
          id: 'f14',
          entryId: 'entry-lic-policy',
          fieldName: 'Sum Assured',
          fieldType: EntryFieldType.currency,
          fieldValue: '10,00,000',
        ),
        const EntryField(
          id: 'f15',
          entryId: 'entry-lic-policy',
          fieldName: 'Nominee',
          fieldType: EntryFieldType.text,
          fieldValue: 'Meera (Wife)',
        ),
      ],
    );

    _localEntries.add(sbiFd);
    _localEntries.add(licPolicy);
  }

  /// Downloads all vault data from Supabase, persists to local phone storage, and syncs any offline pending entries
  Future<void> downloadAndSyncAllVaultEntries({
    required String vaultId,
    required Uint8List vekBytes,
    String? userId,
    bool isOwner = false,
  }) async {
    await _ensureLoaded();
    if (!SupabaseService.isInitialized) return;

    try {
      final client = Supabase.instance.client;
      String effectiveVaultId = vaultId;
      if (!_isValidUuid(effectiveVaultId)) {
        final activeVid = await SecureStorageService.getActiveVaultId();
        effectiveVaultId = (activeVid != null && _isValidUuid(activeVid)) ? activeVid : vaultId;
      }

      // 1. Sync local entries to Supabase (all entries if owner or pending offline)
      final localEntries = _localEntries.where((e) =>
        e.vaultId == vaultId || e.vaultId == effectiveVaultId || !_isValidUuid(e.vaultId)
      ).toList();

      if (isOwner || localEntries.any((e) => e.id.startsWith('local-') || !_isValidUuid(e.id))) {
        for (final entry in localEntries) {
          try {
            await saveEntry(
              entry: entry.copyWith(vaultId: effectiveVaultId),
              vekBytes: vekBytes,
              userId: userId,
            );
          } catch (_) {}
        }
      }

      // 2. Download all vault entries
      final res = await client
          .from('entries')
          .select('*, entry_fields(*), attachments(*)')
          .eq('vault_id', effectiveVaultId)
          .order('created_at', ascending: false)
          .timeout(const Duration(seconds: 8));

      final List<Entry> decryptedList = [];

      Directory? localAttachmentsDir;
      try {
        final appDir = await getApplicationDocumentsDirectory();
        localAttachmentsDir = Directory('${appDir.path}/attachments');
      } catch (_) {}

      for (final raw in (res as List)) {
        try {
          final title = await EncryptionService.decryptString(
            raw['title_encrypted'] as String,
            vekBytes,
          );

          String? notes;
          if (raw['notes_encrypted'] != null && (raw['notes_encrypted'] as String).isNotEmpty) {
            try {
              notes = await EncryptionService.decryptString(
                raw['notes_encrypted'] as String,
                vekBytes,
              );
            } catch (_) {}
          }

          final rawFields = raw['entry_fields'] as List? ?? [];
          final List<EntryField> fields = [];
          for (final f in rawFields) {
            final fName = await EncryptionService.decryptString(
              f['field_name_encrypted'] as String,
              vekBytes,
            );
            final fVal = await EncryptionService.decryptString(
              f['field_value_encrypted'] as String,
              vekBytes,
            );
            fields.add(
              EntryField(
                id: f['id'] as String,
                entryId: raw['id'] as String,
                fieldName: fName,
                fieldType: EntryFieldType.fromString(f['field_type'] as String),
                fieldValue: fVal,
                position: f['position'] as int? ?? 0,
                isSensitive: f['is_sensitive'] as bool? ?? false,
              ),
            );
          }

          final rawAttachments = raw['attachments'] as List? ?? [];
          final List<Attachment> attachments = [];
          for (final a in rawAttachments) {
            final fileName = await EncryptionService.decryptString(
              a['file_name_encrypted'] as String,
              vekBytes,
            );

            String? matchedLocalPath;
            final cleanSearch = fileName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
            if (localAttachmentsDir != null && localAttachmentsDir.existsSync()) {
              for (final entity in localAttachmentsDir.listSync()) {
                if (entity is File) {
                  final base = entity.uri.pathSegments.last.toLowerCase();
                  final cleanBase = base.replaceAll(RegExp(r'[^a-z0-9]'), '');
                  if (base.endsWith(fileName.toLowerCase()) ||
                      cleanBase.endsWith(cleanSearch) ||
                      cleanBase.contains(cleanSearch) ||
                      (a['id'] != null && entity.path.contains(a['id'] as String))) {
                    matchedLocalPath = entity.path;
                    break;
                  }
                }
              }
            }

            // Fallback: check existing local entries to see if we already had a valid file path for this attachment
            if (matchedLocalPath == null) {
              final existingEntry = _localEntries.where((e) => e.id == raw['id']).firstOrNull;
              if (existingEntry != null) {
                final existingAtt = existingEntry.attachments.where((att) =>
                  att.fileName.toLowerCase() == fileName.toLowerCase() ||
                  att.id == a['id']
                ).firstOrNull;
                if (existingAtt?.localFilePath != null && File(existingAtt!.localFilePath!).existsSync()) {
                  matchedLocalPath = existingAtt.localFilePath;
                }
              }
            }

            // Fallback 2: Download binary directly from Supabase Storage bucket
            if (matchedLocalPath == null && a['storage_path'] != null && localAttachmentsDir != null) {
              try {
                final storagePath = a['storage_path'] as String;
                if (storagePath.isNotEmpty) {
                  for (final bucket in ['vault_attachments', 'attachments']) {
                    try {
                      final bytes = await client.storage.from(bucket).download(storagePath);
                      if (bytes.isNotEmpty) {
                        if (!localAttachmentsDir.existsSync()) {
                          localAttachmentsDir.createSync(recursive: true);
                        }
                        final dest = File('${localAttachmentsDir.path}/$fileName');
                        await dest.writeAsBytes(bytes);
                        matchedLocalPath = dest.path;
                        break;
                      }
                    } catch (_) {}
                  }
                }
              } catch (_) {}
            }

            attachments.add(
              Attachment(
                id: a['id'] as String? ?? '',
                entryId: raw['id'] as String,
                storagePath: a['storage_path'] as String? ?? '',
                fileName: fileName,
                mimeType: a['mime_type'] as String? ?? '',
                size: a['size'] as int? ?? 0,
                createdAt: DateTime.tryParse(a['created_at']?.toString() ?? '') ?? DateTime.now(),
                localFilePath: matchedLocalPath,
              ),
            );
          }

          decryptedList.add(
            Entry(
              id: raw['id'] as String,
              categoryId: raw['category_id'] as String,
              vaultId: raw['vault_id'] as String,
              title: title,
              notes: notes,
              isPinned: raw['is_pinned'] as bool? ?? false,
              createdBy: raw['created_by'] as String?,
              createdAt: DateTime.parse(raw['created_at'] as String),
              updatedAt: DateTime.parse(raw['updated_at'] as String),
              fields: fields,
              attachments: attachments,
            ),
          );
        } catch (_) {}
      }

      // Prune local entries for this vault ONLY when remote successfully returned entries
      if (decryptedList.isNotEmpty) {
        final remoteIds = decryptedList.map((e) => e.id).toSet();
        _localEntries.removeWhere((e) =>
          (e.vaultId == vaultId || e.vaultId == effectiveVaultId) &&
          !remoteIds.contains(e.id) &&
          !e.id.startsWith('local-')
        );
      }

      // Merge and preserve existing local valid attachment paths
      for (final remoteEntry in decryptedList) {
        final idx = _localEntries.indexWhere((e) => e.id == remoteEntry.id);
        if (idx != -1) {
          final existingAtts = _localEntries[idx].attachments;
          final mergedAtts = remoteEntry.attachments.map((remAtt) {
            if (remAtt.localFilePath != null && File(remAtt.localFilePath!).existsSync()) {
              return remAtt;
            }
            final existingMatch = existingAtts.where((locAtt) =>
              (locAtt.id == remAtt.id || locAtt.fileName.toLowerCase() == remAtt.fileName.toLowerCase()) &&
              locAtt.localFilePath != null &&
              File(locAtt.localFilePath!).existsSync()
            ).firstOrNull;
            if (existingMatch != null) {
              return remAtt.copyWith(localFilePath: existingMatch.localFilePath);
            }
            return remAtt;
          }).toList();
          _localEntries[idx] = remoteEntry.copyWith(attachments: mergedAtts);
        } else {
          _localEntries.add(remoteEntry);
        }
      }
      await _persist();
    } catch (_) {
      // Offline: gracefully maintain local copy
    }
  }
}
