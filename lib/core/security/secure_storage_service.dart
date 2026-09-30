import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Wraps platform hardware secure storage (Android Keystore / iOS Keychain).
class SecureStorageService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      resetOnError: false,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ),
  );

  static const String _keyPinHash = 'keydiary_pin_hash';
  static const String _keyVaultKey = 'keydiary_vault_key_';
  static const String _keyBiometricsEnabled = 'keydiary_biometrics_enabled';
  static const String _keyAutoLockSeconds = 'keydiary_autolock_seconds';
  static const String _keyActiveVaultId = 'keydiary_active_vault_id';
  static const String _keyThemeMode = 'keydiary_theme_mode'; // system, light, dark
  static const String _keyUserSession = 'keydiary_user_session';
  static const String _keyLocalAccounts = 'keydiary_local_accounts';
  static const String _keyLocalVaults = 'keydiary_local_vaults';
  static const String _keyLocalMembers = 'keydiary_local_members';
  static const String _keyLocalCategories = 'keydiary_local_categories';
  static const String _keyLocalEntries = 'keydiary_local_entries';

  /// Saves current active authenticated user session
  static Future<void> saveUserSession({
    required String id,
    required String email,
    required String displayName,
    String role = 'ADMIN',
  }) async {
    final data = jsonEncode({
      'id': id,
      'email': email,
      'displayName': displayName,
      'role': role,
    });
    await _storage.write(key: _keyUserSession, value: data);
  }

  /// Retrieves current active authenticated user session
  static Future<Map<String, String>?> getUserSession() async {
    final raw = await _storage.read(key: _keyUserSession);
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return {
        'id': map['id'] as String? ?? '',
        'email': map['email'] as String? ?? '',
        'displayName': map['displayName'] as String? ?? 'Member',
        'role': map['role'] as String? ?? 'ADMIN',
      };
    } catch (_) {
      return null;
    }
  }

  /// Clears active user session on sign out
  static Future<void> clearUserSession() async {
    await _storage.delete(key: _keyUserSession);
  }

  /// Checks if an active user session exists
  static Future<bool> hasUserSession() async {
    final session = await getUserSession();
    return session != null && session['id']!.isNotEmpty;
  }

  /// Retrieves stored local accounts
  static Future<List<Map<String, dynamic>>> getLocalAccounts() async {
    final raw = await _storage.read(key: _keyLocalAccounts);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  /// Saves local accounts list
  static Future<void> saveLocalAccounts(List<Map<String, dynamic>> accounts) async {
    await _storage.write(key: _keyLocalAccounts, value: jsonEncode(accounts));
  }

  /// Retrieves stored local vaults
  static Future<List<Map<String, dynamic>>> getLocalVaults() async {
    final raw = await _storage.read(key: _keyLocalVaults);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  /// Saves local vaults list
  static Future<void> saveLocalVaults(List<Map<String, dynamic>> vaults) async {
    await _storage.write(key: _keyLocalVaults, value: jsonEncode(vaults));
  }

  /// Retrieves stored local members
  static Future<List<Map<String, dynamic>>> getLocalMembers() async {
    final raw = await _storage.read(key: _keyLocalMembers);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  /// Saves local members list
  static Future<void> saveLocalMembers(List<Map<String, dynamic>> members) async {
    await _storage.write(key: _keyLocalMembers, value: jsonEncode(members));
  }

  /// Retrieves stored local categories
  static Future<List<Map<String, dynamic>>> getLocalCategories() async {
    final raw = await _storage.read(key: _keyLocalCategories);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  /// Saves local categories list
  static Future<void> saveLocalCategories(List<Map<String, dynamic>> categories) async {
    await _storage.write(key: _keyLocalCategories, value: jsonEncode(categories));
  }

  /// Retrieves stored local entries
  static Future<List<Map<String, dynamic>>> getLocalEntries() async {
    final raw = await _storage.read(key: _keyLocalEntries);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  /// Saves local entries list
  static Future<void> saveLocalEntries(List<Map<String, dynamic>> entries) async {
    await _storage.write(key: _keyLocalEntries, value: jsonEncode(entries));
  }

  static const String _keyLocalAuditLogs = 'keydiary_local_audit_logs';

  /// Retrieves stored local audit logs
  static Future<List<Map<String, dynamic>>> getLocalAuditLogs() async {
    final raw = await _storage.read(key: _keyLocalAuditLogs);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  /// Saves local audit logs list
  static Future<void> saveLocalAuditLogs(List<Map<String, dynamic>> logs) async {
    await _storage.write(key: _keyLocalAuditLogs, value: jsonEncode(logs));
  }

  /// Saves hashed PIN verifier
  static Future<void> savePinHash(String hash) async {
    await _storage.write(key: _keyPinHash, value: hash);
  }

  /// Retrieves stored PIN hash verifier
  static Future<String?> getPinHash() async {
    return await _storage.read(key: _keyPinHash);
  }

  /// Checks whether a PIN is configured
  static Future<bool> hasPin() async {
    final hash = await getPinHash();
    return hash != null && hash.isNotEmpty;
  }

  /// Saves a Vault Encryption Key (VEK) into hardware secure storage
  static Future<void> saveVaultKey(String vaultId, Uint8List keyBytes) async {
    await _storage.write(
      key: '$_keyVaultKey$vaultId',
      value: base64Encode(keyBytes),
    );
  }

  /// Retrieves the Vault Encryption Key (VEK) from hardware secure storage
  static Future<Uint8List?> getVaultKey(String vaultId) async {
    final b64 = await _storage.read(key: '$_keyVaultKey$vaultId');
    if (b64 == null) return null;
    return Uint8List.fromList(base64Decode(b64));
  }

  /// Biometrics preference
  static Future<void> setBiometricsEnabled(bool enabled) async {
    await _storage.write(key: _keyBiometricsEnabled, value: enabled.toString());
  }

  static Future<bool> isBiometricsEnabled() async {
    final val = await _storage.read(key: _keyBiometricsEnabled);
    return val == 'true';
  }

  /// Auto-lock timeout in seconds (default 60 seconds = 1 minute)
  static Future<void> setAutoLockSeconds(int seconds) async {
    await _storage.write(key: _keyAutoLockSeconds, value: seconds.toString());
  }

  static Future<int> getAutoLockSeconds() async {
    final val = await _storage.read(key: _keyAutoLockSeconds);
    if (val == null) return 60; // 1 minute default
    return int.tryParse(val) ?? 60;
  }

  /// Active Vault ID
  static Future<void> setActiveVaultId(String vaultId) async {
    await _storage.write(key: _keyActiveVaultId, value: vaultId);
  }

  static Future<String?> getActiveVaultId() async {
    return await _storage.read(key: _keyActiveVaultId);
  }

  /// Theme mode (system, light, dark)
  static Future<void> setThemeMode(String mode) async {
    await _storage.write(key: _keyThemeMode, value: mode);
  }

  static Future<String> getThemeMode() async {
    return await _storage.read(key: _keyThemeMode) ?? 'system';
  }

  /// Clears sensitive local vault credentials (e.g. on full sign-out)
  static Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}
