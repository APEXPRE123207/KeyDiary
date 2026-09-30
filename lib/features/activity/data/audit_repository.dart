import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/network/supabase_client.dart';
import '../../../core/security/secure_storage_service.dart';
import '../domain/audit_log.dart';

/// Repository for privacy-preserving audit logs
class AuditRepository {
  final List<AuditLog> _localLogs = [];
  bool _loaded = false;

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    try {
      final raw = await SecureStorageService.getLocalAuditLogs();
      _localLogs.clear();
      _localLogs.addAll(raw.map((m) => AuditLog.fromJson(m)));
      _loaded = true;
    } catch (_) {
      _loaded = true;
    }
  }

  Future<void> _persist() async {
    await SecureStorageService.saveLocalAuditLogs(
      _localLogs.map((l) => l.toJson()).toList(),
    );
  }

  Future<List<AuditLog>> getLogs(String vaultId) async {
    await _ensureLoaded();

    if (SupabaseService.isInitialized) {
      try {
        final client = Supabase.instance.client;
        final res = await client
            .from('audit_logs')
            .select()
            .eq('vault_id', vaultId)
            .order('created_at', ascending: false)
            .limit(50)
            .timeout(const Duration(seconds: 4));

        final remoteLogs = (res as List).map((json) {
          final map = Map<String, dynamic>.from(json);
          return AuditLog.fromJson(map);
        }).toList();

        for (final rl in remoteLogs) {
          final idx = _localLogs.indexWhere((l) => l.id == rl.id);
          if (idx != -1) {
            _localLogs[idx] = rl;
          } else {
            _localLogs.add(rl);
          }
        }
        await _persist();
      } catch (_) {
        // Fall back gracefully to local storage if offline or query fails
      }
    }

    final logs = _localLogs.where((l) => l.vaultId == vaultId).toList();
    logs.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    // Resolve user display names from stored accounts / members
    final accounts = await SecureStorageService.getLocalAccounts();
    final members = await SecureStorageService.getLocalMembers();

    return logs.map((l) {
      if (l.userDisplayName != null && l.userDisplayName!.isNotEmpty) return l;

      final acc = accounts.where((a) => a['id'] == l.userId).firstOrNull;
      if (acc != null && acc['displayName'] != null) {
        return l.copyWith(userDisplayName: acc['displayName'] as String);
      }

      final mem = members.where((m) => m['user_id'] == l.userId).firstOrNull;
      if (mem != null && mem['display_name'] != null) {
        return l.copyWith(userDisplayName: mem['display_name'] as String);
      }

      return l;
    }).toList();
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

    await _ensureLoaded();
    final logId = 'log-${DateTime.now().millisecondsSinceEpoch}';

    _localLogs.insert(
      0,
      AuditLog(
        id: logId,
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
    await _persist();

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
    }
  }

  void seedDemoLogs(String vaultId) {
    // No-op: Only genuine user activities are logged
  }
}
