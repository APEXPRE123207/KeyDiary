import 'entry_field.dart';
import 'attachment.dart';

/// Represents a decrypted vault entry record (e.g. SBI Fixed Deposit, LIC Policy, Main Gate Key)
class Entry {
  final String id;
  final String categoryId;
  final String vaultId;
  final String title; // Decrypted representation in domain
  final String? notes; // Decrypted diary notes
  final bool isPinned;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<EntryField> fields;
  final List<Attachment> attachments;

  const Entry({
    required this.id,
    required this.categoryId,
    required this.vaultId,
    required this.title,
    this.notes,
    this.isPinned = false,
    this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.fields = const [],
    this.attachments = const [],
  });

  Entry copyWith({
    String? id,
    String? title,
    String? notes,
    bool? isPinned,
    List<EntryField>? fields,
    List<Attachment>? attachments,
    DateTime? updatedAt,
  }) {
    return Entry(
      id: id ?? this.id,
      categoryId: categoryId,
      vaultId: vaultId,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      isPinned: isPinned ?? this.isPinned,
      createdBy: createdBy,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      fields: fields ?? this.fields,
      attachments: attachments ?? this.attachments,
    );
  }

  /// Helper to get a field value by its name (case-insensitive)
  String? getFieldValue(String name) {
    for (final f in fields) {
      if (f.fieldName.toLowerCase() == name.toLowerCase()) {
        return f.fieldValue;
      }
    }
    return null;
  }
}
