import 'dart:async';

import 'package:get/get.dart';

import '../core/utils/logger.dart';
import '../models/chat_message.dart';
import '../models/join_request.dart';
import '../models/ride.dart';
import '../models/ride_member.dart';
import '../models/sos_alert.dart';
import '../modules/sos/sos_ui.dart';
import '../routes/app_routes.dart';
import 'auth_service.dart';
import 'chat_service.dart';
import 'notification_service.dart';
import 'ride_service.dart';
import 'sos_service.dart';

/// Free-plan replacement for Cloud-Function push: while the app is running
/// (foreground or recently backgrounded), this listens to every active ride
/// the signed-in user belongs to and raises a **local** notification when
/// something new happens — a chat message, a join request (for the host), or a
/// new member joining.
///
/// This needs no Blaze plan. Its one limitation vs. real FCM push is that it
/// only fires while the process is alive; a fully-killed app won't deliver
/// until reopened. (SOS still also has its own in-app full-screen alert.)
///
/// Dedup rules that keep it quiet and correct:
///  * The first snapshot of each stream establishes a baseline and never
///    notifies (so reopening the app doesn't replay history).
///  * Chat messages older than [_startedAtMs] are ignored (backlog guard).
///  * A message is skipped if the user is currently on that ride's chat screen.
///  * The user's own actions never notify themselves.
class LocalAlertsService extends GetxService {
  final AuthService _auth = Get.find<AuthService>();
  final RideService _rides = Get.find<RideService>();
  final ChatService _chat = Get.find<ChatService>();
  final NotificationService _notif = Get.find<NotificationService>();
  final SosService _sos = Get.find<SosService>();

  StreamSubscription<List<Ride>>? _ridesSub;

  // Per-ride subscriptions, so we can tear them down when a ride ends/leaves.
  final Map<String, StreamSubscription<List<ChatMessage>>> _chatSubs =
      <String, StreamSubscription<List<ChatMessage>>>{};
  final Map<String, StreamSubscription<List<JoinRequest>>> _reqSubs =
      <String, StreamSubscription<List<JoinRequest>>>{};
  final Map<String, StreamSubscription<List<RideMember>>> _memberSubs =
      <String, StreamSubscription<List<RideMember>>>{};
  final Map<String, StreamSubscription<List<SosAlert>>> _sosSubs =
      <String, StreamSubscription<List<SosAlert>>>{};

  // Baselines / seen sets per ride.
  final Set<String> _seenMsgIds = <String>{};
  final Map<String, bool> _chatPrimed = <String, bool>{};
  final Map<String, Set<String>> _seenRequestUids = <String, Set<String>>{};
  final Map<String, Set<String>> _seenMemberUids = <String, Set<String>>{};
  final Map<String, String> _rideNames = <String, String>{};
  final Map<String, bool> _amHost = <String, bool>{};

  int _startedAtMs = 0;
  bool _running = false;

  /// Begin listening. Safe to call more than once (e.g. after login and again
  /// from splash) — it restarts cleanly.
  void start() {
    final String? uid = _auth.uid;
    if (uid == null) return;
    stop(); // clear any previous session
    _running = true;
    _startedAtMs = DateTime.now().millisecondsSinceEpoch;
    Log.d('LocalAlertsService started for $uid');

    _ridesSub = _rides.watchMyRides().listen(
      _onRides,
      onError: (Object e, StackTrace s) =>
          Log.e('LocalAlerts rides stream error', error: e, stack: s),
    );
  }

  /// Tear down all listeners (call on sign-out).
  void stop() {
    _running = false;
    _ridesSub?.cancel();
    _ridesSub = null;
    for (final StreamSubscription<dynamic> s in <StreamSubscription<dynamic>>[
      ..._chatSubs.values,
      ..._reqSubs.values,
      ..._memberSubs.values,
      ..._sosSubs.values,
    ]) {
      s.cancel();
    }
    _chatSubs.clear();
    _reqSubs.clear();
    _memberSubs.clear();
    _sosSubs.clear();
    _seenMsgIds.clear();
    _chatPrimed.clear();
    _seenRequestUids.clear();
    _seenMemberUids.clear();
    _rideNames.clear();
    _amHost.clear();
    _seenSosIds.clear();
    _reqPrimed.clear();
    _memberPrimed.clear();
  }

  void _onRides(List<Ride> rides) {
    if (!_running) return;
    final String? uid = _auth.uid;
    if (uid == null) return;

    final Set<String> activeIds = <String>{};
    for (final Ride r in rides) {
      if (!r.isActive) continue;
      activeIds.add(r.id);
      _rideNames[r.id] = r.name;
      _amHost[r.id] = r.createdBy == uid;
      _subscribeRide(r.id, uid);
    }

    // Drop subscriptions for rides that are no longer active / left.
    final List<String> gone = _chatSubs.keys
        .where((String id) => !activeIds.contains(id))
        .toList();
    for (final String id in gone) {
      _chatSubs.remove(id)?.cancel();
      _reqSubs.remove(id)?.cancel();
      _memberSubs.remove(id)?.cancel();
      _sosSubs.remove(id)?.cancel();
      _chatPrimed.remove(id);
    }
  }

  void _subscribeRide(String rideId, String uid) {
    // Chat.
    if (!_chatSubs.containsKey(rideId)) {
      _chatPrimed[rideId] = false;
      _chatSubs[rideId] = _chat.watchMessages(rideId).listen(
        (List<ChatMessage> msgs) => _onChat(rideId, uid, msgs),
        onError: (Object e, _) => Log.e('LocalAlerts chat error', error: e),
      );
    }

    // Requests — only the host cares.
    if ((_amHost[rideId] ?? false) && !_reqSubs.containsKey(rideId)) {
      _seenRequestUids[rideId] = <String>{};
      _reqSubs[rideId] = _rides.watchRequests(rideId).listen(
        (List<JoinRequest> reqs) => _onRequests(rideId, reqs),
        onError: (Object e, _) => Log.e('LocalAlerts requests error', error: e),
      );
    }

    // Members (someone joined).
    if (!_memberSubs.containsKey(rideId)) {
      _seenMemberUids[rideId] = <String>{};
      _memberSubs[rideId] = _rides.watchMembers(rideId).listen(
        (List<RideMember> members) => _onMembers(rideId, uid, members),
        onError: (Object e, _) => Log.e('LocalAlerts members error', error: e),
      );
    }

    // SOS — app-wide (not just the map screen), so an alert reaches the user
    // wherever they are in the app.
    if (!_sosSubs.containsKey(rideId)) {
      _sosSubs[rideId] = _sos.watchActiveSos(rideId).listen(
        (List<SosAlert> alerts) => _onSos(rideId, uid, alerts),
        onError: (Object e, _) => Log.e('LocalAlerts sos error', error: e),
      );
    }
  }

  void _onSos(String rideId, String uid, List<SosAlert> alerts) {
    for (final SosAlert a in alerts) {
      if (a.senderId == uid) continue; // my own SOS
      if (_sos.isDismissed(a.sosId)) continue;
      if (_seenSosIds.contains(a.sosId)) continue;
      _seenSosIds.add(a.sosId);
      // Full-screen alert + local notification (handled inside showIncomingSos).
      showIncomingSos(a, rideId);
    }
  }

  final Set<String> _seenSosIds = <String>{};

  void _onChat(String rideId, String uid, List<ChatMessage> msgs) {
    // First delivery just primes the baseline.
    if (_chatPrimed[rideId] != true) {
      for (final ChatMessage m in msgs) {
        _seenMsgIds.add(m.id);
      }
      _chatPrimed[rideId] = true;
      return;
    }

    final bool onThisChat =
        Get.currentRoute == Routes.chat && Get.arguments == rideId;

    for (final ChatMessage m in msgs) {
      if (_seenMsgIds.contains(m.id)) continue;
      _seenMsgIds.add(m.id);
      if (m.senderId == uid) continue; // my own message
      if (m.timestamp < _startedAtMs) continue; // backlog guard
      if (onThisChat) continue; // already looking at it

      final String preview = m.isLocation
          ? '📍 Shared a location'
          : (m.text ?? 'New message');
      _notif.showLocal(
        m.senderName.isEmpty ? 'New message' : m.senderName,
        preview,
        data: <String, String>{'type': 'chat', 'rideId': rideId},
      );
    }
  }

  void _onRequests(String rideId, List<JoinRequest> reqs) {
    final Set<String> seen = _seenRequestUids.putIfAbsent(
      rideId,
      () => <String>{},
    );
    // Prime baseline on first delivery.
    final bool primed = seen.isNotEmpty || _reqPrimed.contains(rideId);
    if (!primed) {
      _reqPrimed.add(rideId);
      for (final JoinRequest r in reqs) {
        seen.add(r.uid);
      }
      return;
    }
    for (final JoinRequest r in reqs) {
      if (!r.isPending) continue;
      if (seen.contains(r.uid)) continue;
      seen.add(r.uid);
      _notif.showLocal(
        'New join request',
        '${r.name.isEmpty ? 'A rider' : r.name} wants to join '
            '${_rideNames[rideId] ?? 'your ride'}.',
        data: <String, String>{'type': 'joinRequest', 'rideId': rideId},
      );
    }
  }

  final Set<String> _reqPrimed = <String>{};
  final Set<String> _memberPrimed = <String>{};

  void _onMembers(String rideId, String uid, List<RideMember> members) {
    final Set<String> seen = _seenMemberUids.putIfAbsent(
      rideId,
      () => <String>{},
    );
    // Prime baseline on first delivery (existing members don't notify).
    if (!_memberPrimed.contains(rideId)) {
      _memberPrimed.add(rideId);
      for (final RideMember m in members) {
        seen.add(m.uid);
      }
      return;
    }
    for (final RideMember m in members) {
      if (seen.contains(m.uid)) continue;
      seen.add(m.uid);
      if (m.uid == uid) continue; // that's me
      if (m.isHost) continue; // host is the creator, not a "join"
      _notif.showLocal(
        '${m.name.isEmpty ? 'A new rider' : m.name} joined',
        '${m.name.isEmpty ? 'Someone' : m.name} joined '
            '${_rideNames[rideId] ?? 'your ride'}.',
        data: <String, String>{'type': 'memberJoined', 'rideId': rideId},
      );
    }
  }

  @override
  void onClose() {
    stop();
    super.onClose();
  }
}
