import 'package:get/get.dart';
import 'auth_controller.dart';

class AuthBinding extends Bindings {
  @override
  void dependencies() {
    // fenix: recreate if it was disposed, so navigating Phone→OTP→back works
    // and deep-linking straight to OTP still finds a controller.
    Get.lazyPut<AuthController>(() => AuthController(), fenix: true);
  }
}
