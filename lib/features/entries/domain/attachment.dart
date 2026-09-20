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

  bool get isImage =>
      mimeType.startsWith('image/') ||
      fileName.endsWith('.jpg') ||
      fileName.endsWith('.jpeg') ||
      fileName.endsWith('.png') ||
      fileName.endsWith('.webp');

  bool get isPdf =>
      mimeType == 'application/pdf' || fileName.toLowerCase().endsWith('.pdf');

  String get formattedSize {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
