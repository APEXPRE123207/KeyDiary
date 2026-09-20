import 'package:flutter_test/flutter_test.dart';
import 'package:keydiary/core/security/pin_service.dart';

void main() {
  group('PinService Tests (PBKDF2-HMAC-SHA256 & Rate-Limiter)', () {
    setUp(() {
      PinService.resetAttempts();
    });

    test('Valid PIN verification succeeds against hashed verifier', () async {
      const pin = '4821';
      final hash = await PinService.hashPin(pin);

      expect(hash, contains('\$'));
      expect(hash.split('\$').length, equals(3));

      final isValid = await PinService.verifyPin(pin, hash);
      expect(isValid, isTrue);
    });

    test('Invalid PIN verification fails and increments failed attempts', () async {
      const correctPin = '1234';
      final hash = await PinService.hashPin(correctPin);

      final isValid = await PinService.verifyPin('9999', hash);
      expect(isValid, isFalse);
      expect(PinService.failedAttempts, equals(1));
    });

    test('Rate-limiting activates after 3 consecutive failed PIN attempts', () async {
      const correctPin = '1234';
      final hash = await PinService.hashPin(correctPin);

      await PinService.verifyPin('0001', hash);
      await PinService.verifyPin('0002', hash);
      expect(PinService.isLockedOut(), isFalse);

      // 3rd failure triggers lockout
      await PinService.verifyPin('0003', hash);
      expect(PinService.isLockedOut(), isTrue);
      expect(PinService.remainingLockoutSeconds(), greaterThan(0));

      // Attempt during lockout is rejected immediately without checking
      final attemptDuringLockout = await PinService.verifyPin(correctPin, hash);
      expect(attemptDuringLockout, isFalse);
    });
  });
}
