import 'package:get/get.dart';
import 'ride_map_controller.dart';

class RideMapBinding extends Bindings {
  @override
  void dependencies() {
    final String rideId = Get.arguments as String;
    Get.lazyPut<RideMapController>(() => RideMapController(rideId));
  }
}
