import 'package:get/get.dart';

import '../../models/ride_history_entry.dart';
import '../../services/auth_service.dart';
import '../../services/ride_service.dart';

/// Navigation arguments for the member-history screen.
class MemberHistoryArgs {
  final String uid;
  final String name;
  const MemberHistoryArgs({required this.uid, required this.name});
}

/// Drives the per-member ride history list. Reads the member's permanent
/// `rideHistory` via [RideService.watchMemberRides].
class MemberHistoryController extends GetxController {
  final RideService _rides = Get.find<RideService>();
  final AuthService _auth = Get.find<AuthService>();

  final String uid;
  final String name;
  MemberHistoryController({required this.uid, required this.name});

  final RxList<RideHistoryEntry> history = <RideHistoryEntry>[].obs;
  final RxBool loading = true.obs;

  /// True when viewing your own history (affects the title/empty copy).
  bool get isMe => _auth.uid == uid;

  @override
  void onInit() {
    super.onInit();
    history.bindStream(_rides.watchMemberRides(uid));
    // Clear the loading skeleton on the first emission.
    once<List<RideHistoryEntry>>(history, (_) => loading.value = false);
  }
}
