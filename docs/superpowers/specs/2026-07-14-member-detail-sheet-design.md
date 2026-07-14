# Member Detail Sheet — Design Spec

Date: 2026-07-14

## Goal

Let the user tap a member (from Ride Detail's member list, or from Live
Map's members sheet) and see that member's full detail in one place:
profile info (name, photo, role, joined date) plus, when available, live
status (online/offline, last seen, speed, battery, ETA to destination).

Also fixes a real existing bug found while scoping this: Live Map's
members sheet currently shows every rider's name as "Rider" (or "You" for
self) because `RideMapController` never loads real member profiles from
Firestore — only RTDB location data, which has no name/photo/role fields.

## Current state

- `RideMember` (Firestore `rides/{id}/members/{uid}`): `name`, `photoUrl`,
  `colorValue`, `role` ('host'|'rider'), `joinedAt`.
- `MemberLocation` (RTDB `locations/{rideId}/{uid}` + `presence`): `lat`,
  `lng`, `speed`, `heading`, `battery`, `online`, `lastSeen`. No name.
- `RideDetailController` already binds `members: RxList<RideMember>` via
  `RideService.watchMembers(rideId)` — Ride Detail has real names today.
- `RideMapController` only has `members: RxList<MemberLocation>` (RTDB) —
  no Firestore member data, hence the "Rider"/"You" placeholder names in
  its members sheet.
- `RideMapController.routeFor(uid)` already returns `RouteResult?` (ETA to
  destination) when a destination is set.

## Changes

### 1. `RideMapController` — load real member profiles

Add:
```dart
final RxList<RideMember> rideMembers = <RideMember>[].obs;
```
Bind it in `_start()` the same way `members` (RTDB) is bound:
```dart
rideMembers.bindStream(_rideService.watchMembers(rideId));
```
(`_rideService` already exists as a field, typed `RideService`, used
already for `watchRide`.) Add a lookup helper (plain loop — `collection`'s
`firstWhereOrNull` is only a transitive dependency today, not declared in
`pubspec.yaml`, so avoid relying on it):
```dart
RideMember? rideMemberFor(String uid) {
  for (final RideMember m in rideMembers) {
    if (m.uid == uid) return m;
  }
  return null;
}
```

### 2. New shared widget: `lib/modules/rides/member_detail_sheet.dart`

One function:
```dart
void showMemberDetail(
  BuildContext context, {
  required RideMember member,
  required String rideId,
  MemberLocation? live,
  RouteResult? route,
})
```
Renders a `Get.bottomSheet` (consistent with other sheets in the app, e.g.
profile photo picker) with:

1. **Header** — avatar (photo if present, else initial letter on
   `member.color`), `member.name`, a "Host" badge (reusing `StatusBadge`
   from the visual-refresh work) if `member.isHost`, and "Joined
   {date}" formatted from `member.joinedAt` (or omitted if null).
2. **Live status** — only rendered when `live != null`:
   - Online/offline line via `live.lastSeenText(DateTime.now().millisecondsSinceEpoch)`.
   - Speed: `${live.speedKmh.toStringAsFixed(0)} km/h`.
   - Battery: `${live.battery}%`.
   - If `route != null`: `${route.distanceText} · ${route.etaText}` to
     destination.
   When `live == null`, instead render a muted line ("Open the live map to
   see this rider's location") plus a button labeled "Open live map" that
   calls `Get.back()` then `Get.toNamed(Routes.rideMap, arguments: rideId)`.

### 3. Ride Detail — wire tap on `_MemberTile`

`_MemberTile` (in `ride_detail_view.dart`) gets wrapped so tapping it calls
`showMemberDetail(context, member: member, rideId: controller.rideId)` —
no `live`/`route` (Ride Detail has no RTDB access), so the sheet always
shows the "Open live map" prompt for the live-status section. This does
not change the existing accept/reject request tiles, which are separate.

### 4. Live Map — real names + info-icon entry point

In `_showMembers` (`ride_map_view.dart`):
- Replace the hardcoded title:
  ```dart
  m.uid == controller.uid ? 'You' : 'Rider'
  ```
  with:
  ```dart
  controller.rideMemberFor(m.uid)?.name ??
      (m.uid == controller.uid ? 'You' : 'Rider')
  ```
  (keeps the old fallback for the brief window before `rideMembers` has
  loaded).
- The `ListTile`'s existing `onTap` (which calls `Get.back()` then
  `controller.followMember(m)`) is unchanged — tapping the row still
  starts following that member on the map.
- Add a `trailing` info icon button (`Icons.info_outline`) that, on tap,
  calls `showMemberDetail(context, member: <resolved>, rideId:
  controller.rideId, live: m, route: controller.routeFor(m.uid))`, where
  `<resolved>` is `controller.rideMemberFor(m.uid)` if found, otherwise a
  locally-constructed placeholder `RideMember` (uid, name matching the
  fallback above, `colorValue:
  AppColors.memberColorForKey(m.uid).toARGB32()`, `role: 'rider'`,
  `joinedAt: null`) so the sheet never crashes on a not-yet-loaded member
  doc. This tap does **not** close the members sheet first (info sheets
  can stack; `Get.bottomSheet` supports this) — only the row tap does.

## What does NOT change

- Ride Detail's pending-requests list (accept/reject) — untouched.
- Live Map's follow-mode behavior (from the prior feature) — untouched;
  the info icon is additive, not a replacement for the row tap.
- No changes to `RideLocationService`, `LocationService`, RTDB schema, or
  Firestore schema — `RideMember`/`MemberLocation` are read as-is.
- No new Firestore reads beyond the one new `watchMembers` binding in
  `RideMapController` (which reuses the existing `RideService` method
  already used by `RideDetailController`).

## Testing / verification

- `flutter analyze` clean.
- Existing tests untouched and passing (no controller logic this changes
  has existing unit tests; `RideMember`/`MemberLocation` models are
  unchanged).
- Manual on-device check: from Ride Detail, tap a member → sheet shows
  profile + "Open live map" prompt. From Live Map, tap a member row →
  follow starts (unchanged); tap the info icon → sheet shows profile +
  live status + ETA (if destination set). Confirm names are correct (not
  "Rider"/"You" for other members) in both the members sheet list and the
  detail sheet.

## Risk

Low — additive UI change plus one new stream binding reusing an existing
service method. No data-layer or schema changes.
