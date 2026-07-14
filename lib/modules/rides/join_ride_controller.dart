import 'package:get/get.dart';
import '../../core/utils/ui_helpers.dart';
import '../../models/join_request.dart';
import '../../models/ride.dart';
import '../../routes/app_routes.dart';
import '../../services/auth_service.dart';
import '../../services/ride_service.dart';

class JoinRideController extends GetxController {
  final RideService _rides = Get.find<RideService>();
  final AuthService _auth = Get.find<AuthService>();

  final RxString code = ''.obs;
  final RxBool submitting = false.obs;
  final Rxn<JoinRequest> myRequest = Rxn<JoinRequest>();
  final Rxn<Ride> targetRide = Rxn<Ride>();

  Future<void> submit() async {
    if (code.value.length != 6) {
      UiHelpers.error('Enter the full 6-character code.');
      return;
    }
    submitting.value = true;
    try {
      final Ride? ride = await _rides.findByCode(code.value);
      if (ride == null) throw Exception('No ride found for that code.');
      await _rides.requestJoin(code.value);
      targetRide.value = ride;
      final String uid = _auth.uid!;
      myRequest.bindStream(_rides.watchMyRequest(ride.id, uid));
      UiHelpers.success('Request sent. Waiting for the host to approve.');
    } catch (e) {
      UiHelpers.error(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      submitting.value = false;
    }
  }

  void openRide() {
    final String? id = targetRide.value?.id;
    if (id != null) Get.toNamed(Routes.rideDetail, arguments: id);
  }

  void reset() {
    myRequest.value = null;
    targetRide.value = null;
    code.value = '';
  }
}
