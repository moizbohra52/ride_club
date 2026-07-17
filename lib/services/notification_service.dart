import 'dart:convert';
import 'dart:ui' show Color;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import '../core/utils/logger.dart';
import '../routes/app_routes.dart';
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
        // Tapping a foreground (local) notification: its payload is the FCM
        // data map (JSON) — route from it just like a background tap.
        onDidReceiveNotificationResponse: (NotificationResponse r) {
          final String? payload = r.payload;
          if (payload == null || payload.isEmpty) return;
          try {
            final Map<String, dynamic> data =
                (jsonDecode(payload) as Map).cast<String, dynamic>();
            _routeFromData(data.map((k, v) => MapEntry(k, v?.toString() ?? '')));
          } catch (e, s) {
            Log.e('notification payload parse failed', error: e, stack: s);
          }
        },
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

      // Foreground message → show a local notification carrying the data map so
      // a tap can navigate.
      FirebaseMessaging.onMessage.listen((RemoteMessage m) {
        final RemoteNotification? n = m.notification;
        final Map<String, String> data = m.data.map(
          (String k, dynamic v) => MapEntry(k, v?.toString() ?? ''),
        );
        final bool isSos = data['type'] == 'sos';
        showLocal(
          n?.title ?? m.data['title']?.toString() ?? 'RideClub',
          n?.body ?? m.data['body']?.toString() ?? '',
          sos: isSos,
          data: data,
        );
      });

      // App opened from a background notification tap.
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage m) {
        _routeFromData(
          m.data.map((String k, dynamic v) => MapEntry(k, v?.toString() ?? '')),
        );
      });

      // App launched cold from a notification tap.
      final RemoteMessage? initial = await _fcm.getInitialMessage();
      if (initial != null) {
        // Defer until the first frame so the router is ready.
        Future<void>.delayed(const Duration(milliseconds: 600), () {
          _routeFromData(
            initial.data.map(
              (String k, dynamic v) => MapEntry(k, v?.toString() ?? ''),
            ),
          );
        });
      }
    } catch (e, s) {
      Log.e('NotificationService.init failed', error: e, stack: s);
    }
  }

  /// Navigate based on an FCM `data` payload. `type` selects the destination;
  /// `rideId` (and friends) supply the arguments. Safe to call with an empty
  /// map (does nothing).
  void _routeFromData(Map<String, String> data) {
    final String? type = data['type'];
    final String? rideId = data['rideId'];
    if (type == null || rideId == null || rideId.isEmpty) return;
    Log.d('notification tap → type=$type rideId=$rideId');

    switch (type) {
      case 'chat':
        Get.toNamed(Routes.chat, arguments: rideId);
        break;
      case 'sos':
        Get.toNamed(Routes.rideMap, arguments: rideId);
        break;
      case 'requestAccepted':
      case 'memberJoined':
      case 'joinRequest':
      case 'rideEnded':
        Get.toNamed(Routes.rideDetail, arguments: rideId);
        break;
      default:
        Get.toNamed(Routes.rideDetail, arguments: rideId);
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

  Future<void> showLocal(
    String title,
    String body, {
    bool sos = false,
    Map<String, String>? data,
  }) async {
    final NotificationDetails details = NotificationDetails(
      android: AndroidNotificationDetails(
        sos ? _sosChannel.id : _generalChannel.id,
        sos ? _sosChannel.name : _generalChannel.name,
        importance: sos ? Importance.max : Importance.high,
        priority: sos ? Priority.max : Priority.high,
        color: sos ? const Color(0xFFE63950) : null,
      ),
      iOS: const DarwinNotificationDetails(),
    );
    await _local.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
      // Carry the data map as JSON so the tap handler can route.
      payload: (data == null || data.isEmpty) ? null : jsonEncode(data),
    );
  }
}
