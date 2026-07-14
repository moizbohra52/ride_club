import 'package:get/get.dart';
import 'ride_detail_controller.dart';

class RideDetailBinding extends Bindings {
  @override
  void dependencies() {
    final String rideId = Get.arguments as String;
    Get.lazyPut<RideDetailController>(() => RideDetailController(rideId));
  }
}
