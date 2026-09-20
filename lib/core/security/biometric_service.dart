import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

/// Service for OS biometric authentication (Fingerprint / Face ID).
class BiometricService {
  static final LocalAuthentication _auth = LocalAuthentication();

  /// Checks if hardware supports biometrics and is enrolled
  static Future<bool> canAuthenticate() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isDeviceSupported = await _auth.isDeviceSupported();
      return canCheck || isDeviceSupported;
    } on PlatformException {
      return false;
    }
  }

  /// Lists available biometric hardware types (e.g. fingerprint, face)
  static Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } on PlatformException {
      return [];
    }
  }

  /// Prompts biometric authentication with a localized, reassuring message
  static Future<bool> authenticate({
    String reason = 'Authenticate to unlock your KeyDiary Vault',
  }) async {
    try {
      final available = await canAuthenticate();
      if (!available) return false;

      return await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );
    } on PlatformException {
      return false;
    }
  }
}
