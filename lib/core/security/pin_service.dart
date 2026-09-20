import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';

/// Service for Master PIN hashing, verification, and brute-force rate-limiting.
class PinService {
  static const int _iterations = 100000;
  static const int _saltLength = 16;
  static const int _derivedKeyLength = 32;

  // In-memory brute force protection tracking
  static int _failedAttempts = 0;
  static DateTime? _lockedUntil;

  /// Hashes a 4-to-6 digit PIN using PBKDF2-HMAC-SHA256 with 100,000 iterations and random salt.
  /// Format stored: "iterations$base64Salt$base64Hash"
  static Future<String> hashPin(String pin) async {
    final random = Random.secure();
    final salt = Uint8List(_saltLength);
    for (int i = 0; i < _saltLength; i++) {
      salt[i] = random.nextInt(256);
    }

    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: _iterations,
      bits: _derivedKeyLength * 8,
    );

    final secretKey = SecretKey(utf8.encode(pin));
    final derivedKey = await pbkdf2.deriveKey(
      secretKey: secretKey,
      nonce: salt,
    );
    final hashBytes = await derivedKey.extractBytes();

    return '$_iterations\$${base64Encode(salt)}\$${base64Encode(hashBytes)}';
  }

  /// Verifies entered PIN against stored hash string, enforcing rate-limiting.
  static Future<bool> verifyPin(String enteredPin, String storedHash) async {
    // Check if lockout is currently active
    if (isLockedOut()) {
      return false;
    }

    try {
      final parts = storedHash.split('\$');
      if (parts.length != 3) return false;

      final iterations = int.parse(parts[0]);
      final salt = base64Decode(parts[1]);
      final expectedHash = base64Decode(parts[2]);

      final pbkdf2 = Pbkdf2(
        macAlgorithm: Hmac.sha256(),
        iterations: iterations,
        bits: expectedHash.length * 8,
      );

      final secretKey = SecretKey(utf8.encode(enteredPin));
      final derivedKey = await pbkdf2.deriveKey(
        secretKey: secretKey,
        nonce: salt,
      );
      final derivedBytes = await derivedKey.extractBytes();

      // Constant time equality check
      bool matches = derivedBytes.length == expectedHash.length;
      int diff = 0;
      for (int i = 0; i < derivedBytes.length; i++) {
        diff |= derivedBytes[i] ^ expectedHash[i];
      }
      matches = matches && (diff == 0);

      if (matches) {
        // Reset failed attempt counter on success
        _failedAttempts = 0;
        _lockedUntil = null;
        return true;
      } else {
        _recordFailedAttempt();
        return false;
      }
    } catch (_) {
      _recordFailedAttempt();
      return false;
    }
  }

  static void _recordFailedAttempt() {
    _failedAttempts++;
    if (_failedAttempts >= 5) {
      // 5+ failures: 60 second delay
      _lockedUntil = DateTime.now().add(const Duration(seconds: 60));
    } else if (_failedAttempts >= 4) {
      // 4 failures: 30 second delay
      _lockedUntil = DateTime.now().add(const Duration(seconds: 30));
    } else if (_failedAttempts >= 3) {
      // 3 failures: 10 second delay
      _lockedUntil = DateTime.now().add(const Duration(seconds: 10));
    }
  }

  /// Returns whether verification is temporarily locked out
  static bool isLockedOut() {
    if (_lockedUntil == null) return false;
    if (DateTime.now().isBefore(_lockedUntil!)) {
      return true;
    }
    _lockedUntil = null;
    return false;
  }

  /// Returns remaining lockout duration in seconds
  static int remainingLockoutSeconds() {
    if (_lockedUntil == null) return 0;
    final diff = _lockedUntil!.difference(DateTime.now()).inSeconds;
    return diff > 0 ? diff : 0;
  }

  static int get failedAttempts => _failedAttempts;

  /// Resets failure count (used for testing or explicit biometric recovery)
  static void resetAttempts() {
    _failedAttempts = 0;
    _lockedUntil = null;
  }
}
