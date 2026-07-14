// Unit tests for RideTogether's pure logic (validators + color helpers).
//
// These run without Firebase so they pass in plain `flutter test`. Widget-level
// tests that need Firebase are added per-feature in later phases behind fakes.

import 'package:flutter_test/flutter_test.dart';
import 'package:ride_club/core/theme/app_colors.dart';
import 'package:ride_club/core/utils/validators.dart';

void main() {
  group('Validators.phone', () {
    test('rejects empty', () => expect(Validators.phone(''), isNotNull));
    test('rejects too short', () => expect(Validators.phone('123'), isNotNull));
    test('accepts a normal number',
        () => expect(Validators.phone('9876543210'), isNull));
    test('accepts with country code',
        () => expect(Validators.phone('+91 98765 43210'), isNull));
  });

  group('Validators.name', () {
    test('rejects empty', () => expect(Validators.name(''), isNotNull));
    test('rejects single char', () => expect(Validators.name('A'), isNotNull));
    test('accepts a real name',
        () => expect(Validators.name('Rupendra'), isNull));
  });

  group('Validators.emergencyContact', () {
    test('empty is allowed (optional)',
        () => expect(Validators.emergencyContact(''), isNull));
    test('invalid phone is rejected',
        () => expect(Validators.emergencyContact('12'), isNotNull));
  });

  group('Validators.rideCode', () {
    test('must be 6 chars',
        () => expect(Validators.rideCode('ABC'), isNotNull));
    test('accepts a 6-char code',
        () => expect(Validators.rideCode('AB12CD'), isNull));
  });

  group('AppColors.memberColorForKey', () {
    test('is deterministic for the same key', () {
      expect(
        AppColors.memberColorForKey('uid-123'),
        AppColors.memberColorForKey('uid-123'),
      );
    });
    test('empty key falls back to first color', () {
      expect(AppColors.memberColorForKey(''), AppColors.memberColors.first);
    });
  });
}
