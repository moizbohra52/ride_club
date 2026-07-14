import 'package:get/get.dart';
import 'chat_controller.dart';

class ChatBinding extends Bindings {
  @override
  void dependencies() {
    final String rideId = Get.arguments as String;
    Get.lazyPut<ChatController>(() => ChatController(rideId));
  }
}
