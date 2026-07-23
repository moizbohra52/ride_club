import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import 'core/theme/app_theme.dart';
import 'core/utils/logger.dart';
import 'firebase_options.dart';
import 'routes/app_pages.dart';
import 'services/audio_service.dart';
import 'services/auth_service.dart';
import 'services/chat_service.dart';
import 'services/geo_service.dart';
import 'services/local_alerts_service.dart';
import 'services/location_service.dart';
import 'services/notification_service.dart';
import 'services/ride_location_service.dart';
import 'services/ride_memory_service.dart';
import 'services/ride_service.dart';
import 'services/routing_service.dart';
import 'services/sos_service.dart';
import 'services/theme_service.dart';
import 'services/user_service.dart';

/// Background FCM handler. No-op for now — the system auto-displays
/// notification-type messages. Becomes meaningful once the Blaze Cloud
/// Function in `functions/` starts sending pushes.
@pragma('vm:entry-point')
Future<void> _fcmBackgroundHandler(RemoteMessage message) async {}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Local persistence for theme + onboarding flags.
  await GetStorage.init();

  // Initialize Firebase.
  //
  // On Android, the google-services plugin + google-services.json auto-create
  // the default app natively (via a ContentProvider) BEFORE main() runs, so a
  // plain initializeApp() throws `[core/duplicate-app]`. We treat an existing
  // default app as success and reuse it. A genuine failure (truly missing/
  // invalid config) still surfaces the config screen.
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } else {
      // Default app already initialized natively — reuse it.
      Firebase.app();
    }

    // Initialize App Check with debug provider for development
    await FirebaseAppCheck.instance.activate(
      androidProvider: AndroidProvider.debug,
      appleProvider: AppleProvider.debug,
    );
  } on FirebaseException catch (e, s) {
    if (e.code == 'duplicate-app') {
      // Harmless race: the native default app already exists. Carry on.
      Log.d('Firebase default app already existed; reusing it.');
    } else {
      Log.e(
        'Firebase init failed — check firebase_options.dart',
        error: e,
        stack: s,
      );
      runApp(const _FirebaseConfigError());
      return;
    }
  } catch (e, s) {
    Log.e(
      'Firebase init failed — check firebase_options.dart',
      error: e,
      stack: s,
    );
    runApp(const _FirebaseConfigError());
    return;
  }

  // Background FCM handler (active once a Cloud Function sends pushes).
  FirebaseMessaging.onBackgroundMessage(_fcmBackgroundHandler);

  // Register services permanently so every module/phase can Get.find() them.
  Get.put<ThemeService>(ThemeService(), permanent: true);
  Get.put<AuthService>(AuthService(), permanent: true);
  Get.put<UserService>(UserService(), permanent: true);
  Get.put<RideService>(RideService(), permanent: true);
  Get.put<GeoService>(GeoService(), permanent: true);
  Get.put<LocationService>(LocationService(), permanent: true);
  Get.put<RideLocationService>(RideLocationService(), permanent: true);
  Get.put<RoutingService>(RoutingService(), permanent: true);
  Get.put<ChatService>(ChatService(), permanent: true);
  Get.put<RideMemoryService>(RideMemoryService(), permanent: true);
  Get.put<AudioService>(AudioService(), permanent: true);
  Get.put<SosService>(SosService(), permanent: true);
  Get.put<NotificationService>(NotificationService(), permanent: true);
  Get.put<LocalAlertsService>(LocalAlertsService(), permanent: true);

  runApp(const RideClubApp());
}

class RideClubApp extends StatelessWidget {
  const RideClubApp({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeService themeService = Get.find<ThemeService>();
    return Obx(
      () => GetMaterialApp(
        title: 'RideClub',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: themeService.mode.value,
        initialRoute: AppPages.initial,
        getPages: AppPages.pages,
      ),
    );
  }
}

/// Shown only when Firebase failed to initialize (placeholder config).
class _FirebaseConfigError extends StatelessWidget {
  const _FirebaseConfigError();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const <Widget>[
                Icon(Icons.settings_suggest_outlined, size: 56),
                SizedBox(height: 16),
                Text(
                  'Firebase is not configured yet',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 12),
                Text(
                  'Run  flutterfire configure  (or paste your real values into '
                  'lib/firebase_options.dart) and restart the app.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
