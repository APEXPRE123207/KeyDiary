/// Represents a high-level, non-sensitive audit event
class AuditLog {
  final String id;
  final String vaultId;
  final String userId;
  final String action;
  final String entityType;
  final String? entityId;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;
  final String? userDisplayName;

  const AuditLog({
    required this.id,
    required this.vaultId,
    required this.userId,
    required this.action,
    required this.entityType,
    this.entityId,
    this.metadata = const {},
    required this.createdAt,
    this.userDisplayName,
  });

  factory AuditLog.fromJson(Map<String, dynamic> json) {
    return AuditLog(
      id: json['id'] as String,
      vaultId: json['vault_id'] as String,
      userId: json['user_id'] as String,
      action: json['action'] as String,
      entityType: json['entity_type'] as String,
      entityId: json['entity_id'] as String?,
      metadata: (json['metadata'] as Map<String, dynamic>?) ?? {},
      createdAt: DateTime.parse(json['created_at'] as String),
      userDisplayName: json['user_display_name'] as String?,
    );
  }

  /// Generates a friendly, non-sensitive summary description
  String get friendlyDescription {
    final actor = userDisplayName ?? 'Member';
    switch (action) {
      case 'ENTRY_CREATED':
        final titleHint = metadata['title_hint'] ?? 'an item';
        return '$actor added "$titleHint"';
      case 'ENTRY_UPDATED':
        final titleHint = metadata['title_hint'] ?? 'an item';
        return '$actor updated "$titleHint"';
      case 'ENTRY_DELETED':
        return '$actor deleted a vault entry';
      case 'CATEGORY_CREATED':
        final catName = metadata['category_name'] ?? 'a category';
        return '$actor created category "$catName"';
      case 'MEMBER_JOINED':
        return '$actor joined the family vault';
      case 'PIN_CHANGED':
        return '$actor updated master vault security';
      case 'EMERGENCY_SYNC':
        return '$actor synced emergency backup';
      default:
        return '$actor performed vault action: $action';
    }
  }
}
