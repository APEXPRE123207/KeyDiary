import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';

/// Core AES-256-GCM authenticated encryption service.
///
/// Every encrypted string produces a versioned, authenticated package:
/// Format: Base64( [1 byte version] + [12 bytes nonce] + [16 bytes tag] + [ciphertext] )
class EncryptionService {
  static final AesGcm _algorithm = AesGcm.with256bits();
  static const int _version = 1;
  static const int _nonceLength = 12;
  static const int _tagLength = 16;

  /// Generates a new cryptographically secure 256-bit Vault Encryption Key (VEK)
  static Future<Uint8List> generateRandomKey() async {
    final secretKey = await _algorithm.newSecretKey();
    final bytes = await secretKey.extractBytes();
    return Uint8List.fromList(bytes);
  }

  /// Encrypts a plaintext string using AES-256-GCM and the given 256-bit key
  static Future<String> encryptString(String plaintext, Uint8List keyBytes) async {
    final clearTextBytes = utf8.encode(plaintext);
    final secretKey = SecretKey(keyBytes);

    // Generate random 12-byte nonce
    final secretBox = await _algorithm.encrypt(
      clearTextBytes,
      secretKey: secretKey,
    );

    // Pack: Version(1) + Nonce(12) + Tag/MAC(16) + Ciphertext
    final macBytes = secretBox.mac.bytes;
    final packed = BytesBuilder()
      ..addByte(_version)
      ..add(secretBox.nonce)
      ..add(macBytes)
      ..add(secretBox.cipherText);

    return base64Encode(packed.toBytes());
  }

  /// Decrypts a previously encrypted base64 payload using the given 256-bit key
  static Future<String> decryptString(String packedBase64, Uint8List keyBytes) async {
    final packed = base64Decode(packedBase64);
    if (packed.length < 1 + _nonceLength + _tagLength) {
      throw const FormatException('Invalid ciphertext length');
    }

    final version = packed[0];
    if (version != _version) {
      throw FormatException('Unsupported encryption version: $version');
    }

    final nonce = packed.sublist(1, 1 + _nonceLength);
    final macBytes = packed.sublist(1 + _nonceLength, 1 + _nonceLength + _tagLength);
    final cipherText = packed.sublist(1 + _nonceLength + _tagLength);

    final secretKey = SecretKey(keyBytes);
    final secretBox = SecretBox(
      cipherText,
      nonce: nonce,
      mac: Mac(macBytes),
    );

    final clearTextBytes = await _algorithm.decrypt(
      secretBox,
      secretKey: secretKey,
    );

    return utf8.decode(clearTextBytes);
  }

  /// Encrypts arbitrary byte payload (e.g. for files/documents)
  static Future<Uint8List> encryptBytes(Uint8List clearTextBytes, Uint8List keyBytes) async {
    final secretKey = SecretKey(keyBytes);
    final secretBox = await _algorithm.encrypt(
      clearTextBytes,
      secretKey: secretKey,
    );

    final packed = BytesBuilder()
      ..addByte(_version)
      ..add(secretBox.nonce)
      ..add(secretBox.mac.bytes)
      ..add(secretBox.cipherText);

    return packed.toBytes();
  }

  /// Decrypts arbitrary byte payload (e.g. for files/documents)
  static Future<Uint8List> decryptBytes(Uint8List packed, Uint8List keyBytes) async {
    if (packed.length < 1 + _nonceLength + _tagLength) {
      throw const FormatException('Invalid ciphertext payload');
    }

    final nonce = packed.sublist(1, 1 + _nonceLength);
    final macBytes = packed.sublist(1 + _nonceLength, 1 + _nonceLength + _tagLength);
    final cipherText = packed.sublist(1 + _nonceLength + _tagLength);

    final secretKey = SecretKey(keyBytes);
    final secretBox = SecretBox(
      cipherText,
      nonce: nonce,
      mac: Mac(macBytes),
    );

    final clearBytes = await _algorithm.decrypt(
      secretBox,
      secretKey: secretKey,
    );

    return Uint8List.fromList(clearBytes);
  }
}
