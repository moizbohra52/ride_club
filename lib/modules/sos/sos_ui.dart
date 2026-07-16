import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/theme/app_colors.dart';
import '../../models/sos_alert.dart';
import '../../routes/app_routes.dart';
import '../../services/auth_service.dart';
import '../../services/notification_service.dart';
import '../../services/sos_service.dart';
import '../../services/user_service.dart';
import '../ride_map/ride_map_controller.dart' show RideMapArgs;

/// Confirms and triggers an SOS for [rideId]. Returns the sosId if sent, else
/// null (user cancelled). Also offers to text the emergency contact.
Future<String?> confirmAndSendSos(String rideId) async {
  final bool? ok = await Get.dialog<bool>(
    AlertDialog(
      title: const Text('Send SOS?'),
      content: const Text(
        'Everyone in this ride will see an emergency alert with your live '
        'location.',
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Get.back(result: false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.sos),
          onPressed: () => Get.back(result: true),
          child: const Text('Send SOS'),
        ),
      ],
    ),
  );
  if (ok != true) return null;

  final String? sosId = await Get.find<SosService>().trigger(rideId);
  Get.find<NotificationService>().showLocal(
    'SOS sent',
    'Your ride has been alerted.',
    sos: true,
  );

  // Offer emergency-contact SMS if one is set.
  final String? uid = Get.find<AuthService>().uid;
  if (uid != null) {
    final profile = await Get.find<UserService>().fetch(uid);
    final String? contact = profile?.emergencyContact;
    if (contact != null && contact.isNotEmpty) {
      final bool? text = await Get.dialog<bool>(
        AlertDialog(
          title: const Text('Text emergency contact?'),
          content: Text('Also send an SMS to $contact with your location?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Get.back(result: false),
              child: const Text('No'),
            ),
            FilledButton(
              onPressed: () => Get.back(result: true),
              child: const Text('Text them'),
            ),
          ],
        ),
      );
      if (text == true) {
        await Get.find<SosService>().textEmergencyContact(
          contact,
          profile?.name ?? 'A rider',
          null,
          null,
        );
      }
    }
  }
  return sosId;
}

/// A full-screen incoming SOS alert for an alert not sent by me.
void showIncomingSos(SosAlert alert, String rideId) {
  if (Get.isDialogOpen ?? false) return;
  Get.find<NotificationService>().showLocal(
    'SOS: ${alert.senderName}',
    '${alert.senderName} needs help!',
    sos: true,
  );
  Get.dialog(
    Dialog(
      backgroundColor: AppColors.sos,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.warning_amber_rounded,
              color: Colors.white,
              size: 56,
            ),
            const SizedBox(height: 12),
            Text(
              '${alert.senderName} needs help!',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 20),
            if (alert.hasLocation)
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.sos,
                ),
                onPressed: () {
                  Get.find<SosService>().dismiss(alert.sosId);
                  Get.back();
                  Get.toNamed(
                    Routes.rideMap,
                    arguments: RideMapArgs(
                      rideId: rideId,
                      focusUid: alert.senderId,
                    ),
                  );
                },
                icon: const Icon(Icons.map_rounded),
                label: const Text('Open live map'),
              ),
            TextButton(
              onPressed: () {
                Get.find<SosService>().dismiss(alert.sosId);
                Get.back();
              },
              child: const Text(
                'Dismiss',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    ),
    barrierDismissible: false,
  );
}
