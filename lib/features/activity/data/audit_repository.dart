import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/network/supabase_client.dart';
import '../domain/audit_log.dart';

/// Repository for privacy-preserving audit logs
class AuditRepository {
  final List<AuditLog> _localLogs = [];

  Future<List<AuditLog>> getLogs(String vaultId) async {
    if (SupabaseService.isInitialized) {
      final client = Supabase.instance.client;
      final res = await client
          .from('audit_logs')
          .select('*, profiles:user_id(display_name)')
          .eq('vault_id', vaultId)
          .order('created_at', ascending: false)
          .limit(50);

      return (res as List).map((json) {
        final profile = json['profiles'] as Map<String, dynamic>?;
        final map = Map<String, dynamic>.from(json);
        if (profile != null) {
          map['user_display_name'] = profile['display_name'];
        }
        return AuditLog.fromJson(map);
      }).toList();
    } else {
      return List.unmodifiable(_localLogs.where((l) => l.vaultId == vaultId));
    }
  }

  Future<void> logAction({
    required String vaultId,
    required String userId,
    required String action,
    required String entityType,
    String? entityId,
    Map<String, dynamic> metadata = const {},
    String? userDisplayName,
  }) async {
    // Sanitization check: Ensure no sensitive keys exist in metadata
    final sanitizedMeta = Map<String, dynamic>.from(metadata)
      ..removeWhere((k, v) =>
          k.contains('secret') ||
          k.contains('password') ||
          k.contains('pin') ||
          k.contains('key') ||
          k.contains('account') ||
          k.contains('value'));

    if (SupabaseService.isInitialized) {
      try {
        await Supabase.instance.client.from('audit_logs').insert({
          'vault_id': vaultId,
          'user_id': userId,
          'action': action,
          'entity_type': entityType,
          'entity_id': entityId,
          'metadata': sanitizedMeta,
        });
      } catch (_) {}
    } else {
      _localLogs.insert(
        0,
        AuditLog(
          id: 'log-${DateTime.now().millisecondsSinceEpoch}',
          vaultId: vaultId,
          userId: userId,
          action: action,
          entityType: entityType,
          entityId: entityId,
          metadata: sanitizedMeta,
          createdAt: DateTime.now(),
          userDisplayName: userDisplayName ?? 'You',
        ),
      );
    }
  }

  void seedDemoLogs(String vaultId) {
    if (_localLogs.isNotEmpty) return;
    _localLogs.addAll([
      AuditLog(
        id: 'l1',
        vaultId: vaultId,
        userId: 'u1',
        action: 'ENTRY_CREATED',
        entityType: 'ENTRY',
        metadata: {'title_hint': 'SBI Fixed Deposit'},
        createdAt: DateTime.now().subtract(const Duration(minutes: 32)),
        userDisplayName: 'You',
      ),
      AuditLog(
        id: 'l2',
        vaultId: vaultId,
        userId: 'u2',
        action: 'ENTRY_UPDATED',
        entityType: 'ENTRY',
        metadata: {'title_hint': 'LIC Policy'},
        createdAt: DateTime.now().subtract(const Duration(hours: 3)),
        userDisplayName: 'Dad',
      ),
      AuditLog(
        id: 'l3',
        vaultId: vaultId,
        userId: 'u1',
        action: 'ENTRY_CREATED',
        entityType: 'ENTRY',
        metadata: {'title_hint': 'Main Door Key'},
        createdAt: DateTime.now().subtract(const Duration(days: 1, hours: 2)),
        userDisplayName: 'You',
      ),
    ]);
  }
}
