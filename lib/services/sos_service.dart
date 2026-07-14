import 'package:firebase_database/firebase_database.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/utils/logger.dart';
import '../core/utils/sms_link.dart';
import '../models/sos_alert.dart';
import 'auth_service.dart';
import 'location_service.dart';
import 'user_service.dart';

/// SOS broadcast over Realtime Database. Writes an active alert to
/// `sos/{rideId}/{sosId}` so every member watching the ride sees it instantly;
/// also offers an emergency-contact SMS. (Background push is added later by the
/// Blaze Cloud Function in `functions/`.)
class SosService extends GetxService {
  final FirebaseDatabase _db = FirebaseDatabase.instance;
  final AuthService _auth = Get.find<AuthService>();
  final UserService _users = Get.find<UserService>();
  final LocationService _loc = Get.find<LocationService>();

  DatabaseReference _sos(String rideId) => _db.ref('sos/$rideId');

  Future<String?> trigger(String rideId) async {
    final String? uid = _auth.uid;
    if (uid == null) return null;
    final profile = await _users.fetch(uid);
    double? lat;
    double? lng;
    try {
      final pos = await _loc.currentPosition();
      lat = pos?.latitude;
      lng = pos?.longitude;
    } catch (_) {
      // best-effort; still send the alert
    }
    final DatabaseReference ref = _sos(rideId).push();
    await ref.set(<String, dynamic>{
      'senderId': uid,
      'senderName': profile?.name ?? 'A rider',
      'lat': lat,
      'lng': lng,
      'active': true,
      'startedAt': ServerValue.timestamp,
    });
    return ref.key;
  }

  Future<void> cancel(String rideId, String sosId) =>
      _sos(rideId).child(sosId).update(<String, dynamic>{'active': false});

  Stream<List<SosAlert>> watchActiveSos(String rideId) {
    return _sos(rideId).onValue.map((DatabaseEvent event) {
      final Map<dynamic, dynamic>? raw =
          event.snapshot.value as Map<dynamic, dynamic>?;
      if (raw == null) return <SosAlert>[];
      return raw.entries
          .map((MapEntry<dynamic, dynamic> e) =>
              SosAlert.fromMap(e.key as String, e.value as Map<dynamic, dynamic>))
          .where((SosAlert s) => s.active)
          .toList();
    });
  }

  Future<void> textEmergencyContact(
      String contact, String senderName, double? lat, double? lng) async {
    final Uri uri = emergencySmsUri(contact, senderName, lat, lng);
    try {
      if (await canLaunchUrl(uri)) await launchUrl(uri);
    } catch (e, s) {
      Log.e('sms launch failed', error: e, stack: s);
    }
  }
}
