import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/utils/ui_helpers.dart';
import '../../models/join_request.dart';
import '../../models/ride.dart';
import '../../models/ride_member.dart';
import '../../models/sos_alert.dart';
import '../../services/auth_service.dart';
import '../../services/chat_service.dart';
import '../../services/ride_service.dart';
import '../../services/sos_service.dart';
import '../sos/sos_ui.dart';

class RideDetailController extends GetxController {
  final RideService _rides = Get.find<RideService>();
  final ChatService _chat = Get.find<ChatService>();
  final SosService _sos = Get.find<SosService>();
  final AuthService _auth = Get.find<AuthService>();
  final String rideId;
  RideDetailController(this.rideId);

  final Rxn<Ride> ride = Rxn<Ride>();
  final RxList<RideMember> members = <RideMember>[].obs;
  final RxList<JoinRequest> requests = <JoinRequest>[].obs;
  final RxBool busy = false.obs;
  final RxInt unread = 0.obs;
  final RxList<SosAlert> activeSos = <SosAlert>[].obs;
  final Set<String> _seenSos = <String>{};

  String? get uid => _auth.uid;
  bool get amHost => uid != null && (ride.value?.isHost(uid!) ?? false);

  @override
  void onInit() {
    super.onInit();
    ride.bindStream(_rides.watchRide(rideId));
    members.bindStream(_rides.watchMembers(rideId));
    requests.bindStream(_rides.watchRequests(rideId));
    unread.bindStream(_chat.unreadCount(rideId));
    activeSos.bindStream(_sos.watchActiveSos(rideId));
    ever<List<SosAlert>>(activeSos, (List<SosAlert> list) {
      for (final SosAlert s in list) {
        if (s.senderId == uid || _seenSos.contains(s.sosId)) continue;
        _seenSos.add(s.sosId);
        showIncomingSos(s, rideId);
      }
    });
  }

  Future<void> sendSos() => confirmAndSendSos(rideId);

  Future<void> accept(JoinRequest r) =>
      _guard(() => _rides.acceptRequest(rideId, r));

  Future<void> reject(JoinRequest r) =>
      _guard(() => _rides.rejectRequest(rideId, r.uid));

  Future<void> endRide() async {
    final bool ok = await UiHelpers.confirm(
      title: 'End ride?',
      message: 'No one will be able to join after this.',
      confirmText: 'End ride',
      destructive: true,
    );
    if (!ok) return;
    await _guard(() => _rides.endRide(rideId));
  }

  Future<void> leave() async {
    final bool ok = await UiHelpers.confirm(
      title: 'Leave ride?',
      message: 'You can rejoin later with the code.',
      confirmText: 'Leave',
      destructive: true,
    );
    if (!ok) return;
    await _guard(() async {
      await _rides.leaveRide(rideId);
      Get.back();
    });
  }

  void share() {
    final Ride? r = ride.value;
    if (r == null) return;
    Share.share('Join my RideClub ride "${r.name}" with code: ${r.code}');
  }

  Future<void> _guard(Future<void> Function() action) async {
    busy.value = true;
    try {
      await action();
    } catch (e) {
      UiHelpers.error(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      busy.value = false;
    }
  }
}
