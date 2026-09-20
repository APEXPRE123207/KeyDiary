import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/network/supabase_client.dart';
import '../../../core/security/encryption_service.dart';
import '../domain/entry.dart';
import '../domain/entry_field.dart';
import '../domain/attachment.dart';

/// Repository for client-side encrypted vault entries and emergency sync
class EntryRepository {
  final List<Entry> _localEntries = [];

  Future<List<Entry>> getEntriesByCategory({
    required String categoryId,
    required Uint8List vekBytes,
  }) async {
    if (SupabaseService.isInitialized) {
      final client = Supabase.instance.client;

      // 1. Fetch entries with fields and attachments
      final res = await client
          .from('entries')
          .select('*, entry_fields(*), attachments(*)')
          .eq('category_id', categoryId)
          .order('created_at', ascending: false);

      final List<Entry> decryptedList = [];

      for (final raw in (res as List)) {
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
        for (final a in rawAttachments) {
          final fileName = await EncryptionService.decryptString(
            a['file_name_encrypted'] as String,
            vekBytes,
          );
          attachments.add(
            Attachment(
              id: a['id'] as String,
              entryId: raw['id'] as String,
              storagePath: a['storage_path'] as String,
              fileName: fileName,
              mimeType: a['mime_type'] as String,
              size: a['size'] as int? ?? 0,
              createdAt: DateTime.parse(a['created_at'] as String),
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
      }

      return decryptedList;
    } else {
      return _localEntries.where((e) => e.categoryId == categoryId).toList();
    }
  }

  Future<Entry> saveEntry({
    required Entry entry,
    required Uint8List vekBytes,
    String? userId,
  }) async {
    if (SupabaseService.isInitialized) {
      final client = Supabase.instance.client;

      // 1. Client-Side Encryption
      final titleEncrypted = await EncryptionService.encryptString(entry.title, vekBytes);
      final notesEncrypted = entry.notes != null && entry.notes!.isNotEmpty
          ? await EncryptionService.encryptString(entry.notes!, vekBytes)
          : null;

      // Upsert entry
      final entryRes = await client.from('entries').upsert({
        if (entry.id.isNotEmpty && !entry.id.startsWith('local-')) 'id': entry.id,
        'category_id': entry.categoryId,
        'vault_id': entry.vaultId,
        'title_encrypted': titleEncrypted,
        'notes_encrypted': notesEncrypted,
        'is_pinned': entry.isPinned,
        'created_by': ?userId,
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

      // 3. Sync to Emergency Store (User explicit emergency access requirement)
      try {
        await _syncToEmergencyStore(entry.copyWith(id: savedEntryId), userId: userId ?? '');
      } catch (_) {}

      return entry.copyWith(id: savedEntryId);
    } else {
      final existingIdx = _localEntries.indexWhere((e) => e.id == entry.id);
      if (existingIdx != -1) {
        _localEntries[existingIdx] = entry;
      } else {
        _localEntries.add(entry);
      }
      return entry;
    }
  }

  /// Syncs plaintext emergency backup to the isolated emergency_vault schema
  Future<void> _syncToEmergencyStore(Entry entry, {required String userId}) async {
    if (!SupabaseService.isInitialized || userId.isEmpty) return;
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
    if (SupabaseService.isInitialized) {
      await Supabase.instance.client.from('entries').delete().eq('id', entryId);
      try {
        await Supabase.instance.client
            .schema('emergency_vault')
            .from('entries')
            .delete()
            .eq('original_entry_id', entryId);
      } catch (_) {}
    } else {
      _localEntries.removeWhere((e) => e.id == entryId);
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
}
