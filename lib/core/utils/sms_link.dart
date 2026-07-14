/// Builds an `sms:` URI to a contact with an SOS body, embedding an
/// OpenStreetMap link to [lat]/[lng] when available.
Uri emergencySmsUri(
    String contact, String senderName, double? lat, double? lng) {
  final StringBuffer body =
      StringBuffer('SOS from $senderName (RideTogether).');
  if (lat != null && lng != null) {
    body.write(
        ' My location: https://www.openstreetmap.org/?mlat=$lat&mlon=$lng#map=17/$lat/$lng');
  } else {
    body.write(' Location unavailable.');
  }
  return Uri(
    scheme: 'sms',
    path: contact,
    query: 'body=${Uri.encodeComponent(body.toString())}',
  );
}
