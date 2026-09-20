import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:keydiary/core/security/encryption_service.dart';

void main() {
  group('EncryptionService Tests (AES-256-GCM)', () {
    test('Roundtrip string encryption and decryption preserves exact plaintext', () async {
      final key = await EncryptionService.generateRandomKey();
      expect(key.length, equals(32)); // 256 bits

      const originalText = 'SBI Fixed Deposit A/c: 3049 8219 4821; Amount: ₹5,00,000';
      final encrypted = await EncryptionService.encryptString(originalText, key);

      expect(encrypted, isNotEmpty);
      expect(encrypted, isNot(equals(originalText)));

      final decrypted = await EncryptionService.decryptString(encrypted, key);
      expect(decrypted, equals(originalText));
    });

    test('Ciphertexts use distinct nonces across multiple encryptions of same text', () async {
      final key = await EncryptionService.generateRandomKey();
      const secret = 'Locker Key #4 in blue almirah';

      final enc1 = await EncryptionService.encryptString(secret, key);
      final enc2 = await EncryptionService.encryptString(secret, key);

      // Even with identical plaintext and key, output ciphertext must differ due to unique nonces
      expect(enc1, isNot(equals(enc2)));

      expect(await EncryptionService.decryptString(enc1, key), equals(secret));
      expect(await EncryptionService.decryptString(enc2, key), equals(secret));
    });

    test('Decryption fails with incorrect key or tampered ciphertext', () async {
      final key1 = await EncryptionService.generateRandomKey();
      final key2 = await EncryptionService.generateRandomKey();

      final encrypted = await EncryptionService.encryptString('Top Secret Vault Code', key1);

      // Wrong key must fail authenticated decryption
      expect(
        () async => await EncryptionService.decryptString(encrypted, key2),
        throwsA(anything),
      );

      // Tampered payload must fail authentication tag check
      final bytes = base64Decode(encrypted);
      bytes[bytes.length - 1] ^= 0xFF; // Flip bit in tag/ciphertext
      final tampered = base64Encode(bytes);

      expect(
        () async => await EncryptionService.decryptString(tampered, key1),
        throwsA(anything),
      );
    });

    test('Roundtrip byte buffer encryption and decryption for attachments', () async {
      final key = await EncryptionService.generateRandomKey();
      final dummyPdfBytes = Uint8List.fromList(List.generate(512, (i) => i % 256));

      final encrypted = await EncryptionService.encryptBytes(dummyPdfBytes, key);
      expect(encrypted.length, greaterThan(dummyPdfBytes.length));

      final decrypted = await EncryptionService.decryptBytes(encrypted, key);
      expect(decrypted, equals(dummyPdfBytes));
    });
  });
}
