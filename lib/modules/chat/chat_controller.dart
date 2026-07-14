import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import '../../core/utils/ui_helpers.dart';
import '../../models/chat_message.dart';
import '../../services/auth_service.dart';
import '../../services/chat_service.dart';
import '../../services/location_service.dart';
import '../../services/ride_service.dart';

class ChatController extends GetxController {
  final ChatService _chat = Get.find<ChatService>();
  final RideService _rides = Get.find<RideService>();
  final LocationService _loc = Get.find<LocationService>();
  final AuthService _auth = Get.find<AuthService>();
  final String rideId;
  ChatController(this.rideId);

  final RxList<ChatMessage> messages = <ChatMessage>[].obs;
  final RxList<String> typingUids = <String>[].obs;
  final RxInt memberCount = 0.obs;
  final RxBool sending = false.obs;
  final TextEditingController input = TextEditingController();
  Timer? _typingTimer;
  bool _isDisposed = false;

  String? get uid => _auth.uid;

  @override
  void onInit() {
    super.onInit();
    messages.bindStream(_chat.watchMessages(rideId));
    typingUids.bindStream(_chat.watchTyping(rideId));
    _rides.watchMembers(rideId).listen((list) => memberCount.value = list.length);
    // Mark read whenever messages change while we're on this screen.
    ever<List<ChatMessage>>(messages, (list) => _chat.markRead(rideId, list));
  }

  void onChanged(String _) {
    _chat.setTyping(rideId, true);
    _typingTimer?.cancel();
    _typingTimer = Timer(
      const Duration(seconds: 2),
      () => _chat.setTyping(rideId, false),
    );
  }

  Future<void> send() async {
    final String text = input.text;
    if (text.trim().isEmpty) return;
    input.clear();
    _chat.setTyping(rideId, false);
    try {
      await _chat.sendText(rideId, text);
    } catch (e) {
      if (!_isDisposed) {
        input.text = text; // restore so the user can retry
      }
      UiHelpers.error(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> sendMyLocation() async {
    sending.value = true;
    try {
      final LocationPermissionResult res = await _loc.ensurePermission();
      if (res != LocationPermissionResult.granted) {
        UiHelpers.error('Location permission is needed to share your spot.');
        return;
      }
      final pos = await _loc.currentPosition();
      if (pos == null) {
        UiHelpers.error('Could not get your location.');
        return;
      }
      await _chat.sendLocation(rideId, pos.latitude, pos.longitude);
    } catch (e) {
      UiHelpers.error(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      sending.value = false;
    }
  }

  @override
  void onClose() {
    _isDisposed = true;
    _typingTimer?.cancel();
    _chat.setTyping(rideId, false);
    input.dispose();
    super.onClose();
  }
}
