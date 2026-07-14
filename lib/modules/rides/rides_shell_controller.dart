import 'package:get/get.dart';
import '../../models/ride.dart';
import '../../services/ride_service.dart';

class RidesShellController extends GetxController {
  final RideService _rides = Get.find<RideService>();
  final RxInt tabIndex = 0.obs;
  final RxList<Ride> myRides = <Ride>[].obs;
  final RxBool loading = true.obs;

  @override
  void onInit() {
    super.onInit();
    myRides.bindStream(_rides.watchMyRides());
    ever<List<Ride>>(myRides, (_) => loading.value = false);
  }
}
