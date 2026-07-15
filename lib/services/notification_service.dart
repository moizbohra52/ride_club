import 'dart:ui' show Color;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import '../core/utils/logger.dart';
import 'auth_service.dart';
import 'user_service.dart';

/// Local notifications + FCM token capture.
///
/// On free (Spark) plan this shows in-app/foreground local notifications and
/// saves the FCM token; a Blaze Cloud Function (see `functions/`) later sends
/// real background push using that token with no app change needed.
class NotificationService extends GetxService {
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final AuthService _auth = Get.find<AuthService>();
  final UserService _users = Get.find<UserService>();
  bool _initialized = false;

  static const AndroidNotificationChannel _sosChannel =
      AndroidNotificationChannel(
        'sos',
        'SOS Alerts',
        description: 'Emergency alerts from your ride',
        importance: Importance.max,
      );
  static const AndroidNotificationChannel _generalChannel =
      AndroidNotificationChannel(
        'general',
        'General',
        description: 'Ride updates',
        importance: Importance.high,
      );

  Future<void> init() async {
    if (_initialized) {
      await saveToken();
      return;
    }
    _initialized = true;
    try {
      const AndroidInitializationSettings android =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const DarwinInitializationSettings ios = DarwinInitializationSettings();
      await _local.initialize(
        const InitializationSettings(android: android, iOS: ios),
      );

      final AndroidFlutterLocalNotificationsPlugin? androidImpl = _local
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await androidImpl?.createNotificationChannel(_sosChannel);
      await androidImpl?.createNotificationChannel(_generalChannel);
      await androidImpl?.requestNotificationsPermission();

      await _fcm.requestPermission();
      await saveToken();
      _fcm.onTokenRefresh.listen((_) => saveToken());

      FirebaseMessaging.onMessage.listen((RemoteMessage m) {
        final RemoteNotification? n = m.notification;
        if (n != null) {
          showLocal(n.title ?? 'RideClub', n.body ?? '');
        }
      });
    } catch (e, s) {
      Log.e('NotificationService.init failed', error: e, stack: s);
    }
  }

  Future<void> saveToken() async {
    try {
      final String? uid = _auth.uid;
      if (uid == null) return;
      final String? token = await _fcm.getToken();
      if (token != null) {
        await _users.update(uid, <String, dynamic>{'fcmToken': token});
      }
    } catch (e, s) {
      Log.e('saveToken failed', error: e, stack: s);
    }
  }

  Future<void> showLocal(String title, String body, {bool sos = false}) async {
    final NotificationDetails details = NotificationDetails(
      android: AndroidNotificationDetails(
        sos ? _sosChannel.id : _generalChannel.id,
        sos ? _sosChannel.name : _generalChannel.name,
        importance: sos ? Importance.max : Importance.high,
        priority: sos ? Priority.max : Priority.high,
        color: sos ? const Color(0xFFE11D48) : null,
      ),
      iOS: const DarwinNotificationDetails(),
    );
    await _local.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
    );
  }
}
