/// Represents a private file or document attachment
class Attachment {
  final String id;
  final String entryId;
  final String storagePath;
  final String fileName; // Decrypted name in domain
  final String mimeType;
  final int size;
  final DateTime createdAt;
  final String? localFilePath;

  const Attachment({
    required this.id,
    required this.entryId,
    required this.storagePath,
    required this.fileName,
    required this.mimeType,
    required this.size,
    required this.createdAt,
    this.localFilePath,
  });

  Attachment copyWith({
    String? id,
    String? entryId,
    String? storagePath,
    String? fileName,
    String? mimeType,
    int? size,
    DateTime? createdAt,
    String? localFilePath,
  }) {
    return Attachment(
      id: id ?? this.id,
      entryId: entryId ?? this.entryId,
      storagePath: storagePath ?? this.storagePath,
      fileName: fileName ?? this.fileName,
      mimeType: mimeType ?? this.mimeType,
      size: size ?? this.size,
      createdAt: createdAt ?? this.createdAt,
      localFilePath: localFilePath ?? this.localFilePath,
    );
  }

  bool get isImage {
    final lowerName = fileName.toLowerCase();
    final lowerMime = mimeType.toLowerCase();
    return lowerMime.startsWith('image/') ||
        lowerName.endsWith('.jpg') ||
        lowerName.endsWith('.jpeg') ||
        lowerName.endsWith('.png') ||
        lowerName.endsWith('.webp') ||
        lowerName.endsWith('.heic') ||
        lowerName.endsWith('.gif');
  }

  bool get isPdf =>
      mimeType == 'application/pdf' || fileName.toLowerCase().endsWith('.pdf');

  String get formattedSize {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  factory Attachment.fromJson(Map<String, dynamic> json) {
    return Attachment(
      id: json['id'] as String? ?? '',
      entryId: json['entry_id'] as String? ?? json['entryId'] as String? ?? '',
      storagePath: json['storage_path'] as String? ?? json['storagePath'] as String? ?? '',
      fileName: json['file_name'] as String? ?? json['fileName'] as String? ?? 'attachment',
      mimeType: json['mime_type'] as String? ?? json['mimeType'] as String? ?? 'image/jpeg',
      size: (json['size'] as num?)?.toInt() ?? 0,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : DateTime.now(),
      localFilePath: json['local_file_path'] as String? ?? json['localFilePath'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'entry_id': entryId,
      'storage_path': storagePath,
      'file_name': fileName,
      'mime_type': mimeType,
      'size': size,
      'created_at': createdAt.toIso8601String(),
      'local_file_path': localFilePath,
    };
  }
}
