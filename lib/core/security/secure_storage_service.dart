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
