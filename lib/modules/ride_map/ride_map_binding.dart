import 'package:get/get.dart';
import 'ride_map_controller.dart';

class RideMapBinding extends Bindings {
  @override
  void dependencies() {
    final dynamic args = Get.arguments;
    final RideMapArgs mapArgs = args is RideMapArgs
        ? args
        : RideMapArgs(rideId: args as String);
    Get.lazyPut<RideMapController>(
      () => RideMapController(
        mapArgs.rideId,
        initialFocusUid: mapArgs.focusUid,
      ),
    );
  }
}
