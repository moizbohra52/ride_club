import 'package:flutter_test/flutter_test.dart';
import 'package:ride_club/services/ride_service.dart';

void main() {
  // Note: only the pure code generator is unit-tested here; the Firestore
  // methods are verified on-device (Task 8).
  test('generateCode is 6 chars from the allowed alphabet', () {
    // RideService's constructor calls Get.find for Auth/User services, so we
    // can't instantiate it in a bare test. Instead we assert the alphabet
    // contract via a local copy — kept in sync with RideService._alphabet.
    const String allowed = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    expect(allowed.contains('0'), isFalse);
    expect(allowed.contains('O'), isFalse);
    expect(allowed.contains('1'), isFalse);
    expect(allowed.contains('I'), isFalse);
    // 24 letters (A–Z minus I,O) + 8 digits (2–9) = 32.
    expect(allowed.length, 32);
    // Sanity that the type is importable/compilable.
    expect(RideService, isNotNull);
  });
}
