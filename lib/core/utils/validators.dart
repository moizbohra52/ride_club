/// Form field validators. Return `null` when valid, else an error message.
class Validators {
  Validators._();

  /// Validates a phone number that already includes a country code
  /// (E.164-ish). We keep this permissive: 8–15 digits after an optional '+'.
  static String? phone(String? raw) {
    final String value = (raw ?? '').trim();
    if (value.isEmpty) return 'Enter your phone number';
    final String digits = value.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.length < 8 || digits.length > 15) {
      return 'Enter a valid phone number';
    }
    return null;
  }

  static String? required(String? raw, {String field = 'This field'}) {
    if ((raw ?? '').trim().isEmpty) return '$field is required';
    return null;
  }

  static String? name(String? raw) {
    final String value = (raw ?? '').trim();
    if (value.isEmpty) return 'Enter your name';
    if (value.length < 2) return 'Name is too short';
    if (value.length > 40) return 'Name is too long';
    return null;
  }

  /// Emergency contact is optional; if provided it must look like a phone.
  static String? emergencyContact(String? raw) {
    final String value = (raw ?? '').trim();
    if (value.isEmpty) return null; // optional
    return phone(value);
  }

  static String? rideCode(String? raw) {
    final String value = (raw ?? '').trim();
    if (value.isEmpty) return 'Enter the ride code';
    if (value.length != 6) return 'Ride code is 6 characters';
    return null;
  }
}
