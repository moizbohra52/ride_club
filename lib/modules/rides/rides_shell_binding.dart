import 'package:get/get.dart';
import 'rides_shell_controller.dart';

class RidesShellBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<RidesShellController>(() => RidesShellController());
  }
}
