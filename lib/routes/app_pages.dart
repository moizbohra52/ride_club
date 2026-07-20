import 'package:get/get.dart';

import '../modules/auth/auth_binding.dart';
import '../modules/auth/login_view.dart';
import '../modules/chat/chat_binding.dart';
import '../modules/chat/chat_view.dart';
import '../modules/profile/profile_binding.dart';
import '../modules/profile/profile_view.dart';
import '../modules/profile_setup/profile_setup_binding.dart';
import '../modules/profile_setup/profile_setup_view.dart';
import '../modules/ride_map/ride_map_binding.dart';
import '../modules/ride_map/ride_map_view.dart';
import '../modules/rides/edit_ride_view.dart';
import '../modules/rides/ride_detail_binding.dart';
import '../modules/rides/ride_detail_view.dart';
import '../modules/rides/rides_shell_binding.dart';
import '../modules/rides/rides_shell_view.dart';
import '../modules/splash/splash_binding.dart';
import '../modules/splash/splash_view.dart';
import 'app_routes.dart';

/// GetX page registry. Each page pairs a view with a binding that lazily
/// injects only the controllers/services that page needs.
class AppPages {
  AppPages._();

  static const String initial = Routes.splash;

  static final List<GetPage<dynamic>> pages = <GetPage<dynamic>>[
    GetPage<dynamic>(
      name: Routes.splash,
      page: () => const SplashView(),
      binding: SplashBinding(),
    ),
    GetPage<dynamic>(
      name: Routes.login,
      page: () => const LoginView(),
      binding: AuthBinding(),
      transition: Transition.fadeIn,
    ),
    GetPage<dynamic>(
      name: Routes.profileSetup,
      page: () => const ProfileSetupView(),
      binding: ProfileSetupBinding(),
      transition: Transition.rightToLeft,
    ),
    GetPage<dynamic>(
      name: Routes.home,
      page: () => const RidesShellView(),
      binding: RidesShellBinding(),
      transition: Transition.fadeIn,
    ),
    GetPage<dynamic>(
      name: Routes.rideDetail,
      page: () => const RideDetailView(),
      binding: RideDetailBinding(),
      transition: Transition.rightToLeft,
    ),
    GetPage<dynamic>(
      name: Routes.editRide,
      page: () => const EditRideView(),
      transition: Transition.rightToLeft,
    ),
    GetPage<dynamic>(
      name: Routes.profile,
      page: () => const ProfileView(),
      binding: ProfileBinding(),
      transition: Transition.rightToLeft,
    ),
    GetPage<dynamic>(
      name: Routes.rideMap,
      page: () => const RideMapView(),
      binding: RideMapBinding(),
      transition: Transition.cupertino,
    ),
    GetPage<dynamic>(
      name: Routes.chat,
      page: () => const ChatView(),
      binding: ChatBinding(),
      transition: Transition.downToUp,
    ),
  ];
}
