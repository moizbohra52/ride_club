# Phase 5 — Realtime Group Chat — Design Spec

**Date:** 2026-07-11
**Project:** `ride_club` (RideTogether)
**Builds on:** Phase 1 (auth/profile), Phase 2 (rides/members), Phase 3 (RTDB, presence, map), Phase 4 (routing).

---

## Locked decisions (from brainstorming)

| Fork | Decision |
|------|----------|
| Chat entry + unread badge | Chat icon **+ unread badge** in both Ride Detail and Live Map AppBars; small badge on My Rides cards. |
| Read receipts | **Seen-by count** — "Seen" (all members) or "Seen by N", via `readBy/{uid}` map. |
| Location message | **"Send my location"** → bubble with a small non-interactive flutter_map thumbnail + pin; tap → full map. |
| Unread tracking | **Client-side** `lastRead/{rideId}/{uid}` timestamp; unread = messages after it not sent by me. |

## Realtime Database structure

```
chats/{rideId}/messages/{msgId}      // push() key = chronological id
  senderId, senderName, senderPhoto?, type ('text'|'location'),
  text?, lat?, lng?, timestamp (ServerValue.timestamp),
  readBy: { uid: true, ... }

presence/{rideId}/{uid}/typing: bool  // reuses Phase 3 presence node
lastRead/{rideId}/{uid}: timestamp    // per-user read marker
```

## Service (new)

**`ChatService`** (GetxService):
- `Stream<List<ChatMessage>> watchMessages(String rideId)` — `chats/{rideId}/messages` ordered by key, limited to last 200; parsed to `ChatMessage`.
- `Future<void> sendText(String rideId, String text)` — push message (type text) with sender name/photo from `UserService`. Timeout-guarded.
- `Future<void> sendLocation(String rideId, double lat, double lng)` — push (type location).
- `Future<void> markRead(String rideId, List<ChatMessage> visible)` — set `lastRead/{rideId}/{uid}` = ServerValue.timestamp; add my uid to `readBy` of each visible message not mine.
- `void setTyping(String rideId, bool typing)` — write `presence/{rideId}/{uid}/typing`.
- `Stream<List<String>> watchTyping(String rideId)` — uids currently typing, excluding me.
- `Stream<int> unreadCount(String rideId)` — count of messages with `timestamp > lastRead` and `senderId != me`.

## Models

`ChatMessage{ id, senderId, senderName, senderPhoto?, type, text?, lat?, lng?, timestamp (int ms), readBy: Set<String> }`:
- `bool isMine(String uid)`, `bool get isLocation`, `int get seenByCount` (readBy minus sender), `String timeText`.

## Module `modules/chat/`

- `chat_view` + `chat_controller` + `chat_binding` (arg: rideId).
- Controller: binds `watchMessages`, `watchTyping`; holds member count (from `RideService.watchMembers`) for "Seen by all"; text controller with debounced `setTyping`; `send()`, `sendMyLocation()` (uses `LocationService.currentPosition`); calls `markRead` on open and whenever new messages arrive while the screen is active.
- View:
  - Reversed `ListView` of bubbles. Mine: right-aligned, `AppColors.seed` bubble, white text, seen status under it. Others: left-aligned with small avatar + name.
  - **Location bubble:** ~160×120 non-interactive `FlutterMap` (OSM tile + a pin marker), rounded; tap → full-screen map dialog centered on the point.
  - Composer row: attach (location) icon + `TextField` + send button.
  - Typing row above composer: "{name} is typing…".
  - Empty state: "Say hi to your crew 👋".

## Unread badge integration

- `RideDetailController` and `RideMapController` gain `RxInt unread` bound to `ChatService.unreadCount(rideId)`; both AppBars show an `IconButton` (chat bubble) with a badge when `unread > 0` → `Get.toNamed(Routes.chat, arguments: rideId)`.
- `MyRidesTab` `_RideCard`: a small badge using a per-ride `unreadCount` stream.

## Data flow
- Send: composer → `ChatService.sendText/​sendLocation` → RTDB push → everyone's `watchMessages` updates live.
- Typing: keystrokes → debounced `setTyping(true)`; cleared after ~2s idle and on send.
- Read: on chat open + on each new inbound message while visible → `markRead` (updates `lastRead` + `readBy`).
- Unread: `unreadCount` compares message timestamps to `lastRead`.

## Error handling
Send timeout → keep the composed text + snackbar "Couldn't send, try again". No internet → banner. Location message without permission → prompt via `LocationService.ensurePermission`. Empty chat → friendly empty state. Missing/late `lastRead` → treat all as read at first open (no false huge counts).

## Testing
- Unit: `ChatMessage.fromMap` (text + location), `seenByCount` excludes sender, `timeText` formatting, unread computation helper (pure function over a message list + lastRead).
- On-device: two accounts — send text both ways, typing indicator shows, seen-by updates, send location renders map bubble, unread badge appears/clears.

## Out of scope (later)
FCM push notifications for new messages (Phase 6). Media/images. SOS (Phase 6). History + release (Phase 7).

## Quality rules (carried forward)
Clean units; compiles/runs; typed friendly errors; RTDB reused (no new backend); no Google Maps (chat thumbnail uses flutter_map/OSM); `flutter analyze` clean; tests pass; verify on emulator.
