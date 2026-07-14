# Member Detail Sheet Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let the user tap a member (from Ride Detail's member list, or
from Live Map's members sheet) and see a detail sheet with profile info
plus, when available, live status (online/offline, speed, battery, ETA).
Also fix Live Map's members sheet showing "Rider"/"You" instead of real
names, by loading Firestore member profiles into `RideMapController`.

**Architecture:** One new shared bottom-sheet function
(`showMemberDetail`) used from both `RideDetailView` and `RideMapView`.
`RideMapController` gains a `rideMembers: RxList<RideMember>` bound to the
existing `RideService.watchMembers` stream (same method
`RideDetailController` already uses), plus a `rideMemberFor(uid)` lookup.

**Tech Stack:** Flutter, GetX. No new dependencies.

## Global Constraints

- Spec: `docs/superpowers/specs/2026-07-14-member-detail-sheet-design.md`.
- Do not modify `RideLocationService`, `LocationService`, `RoutingService`,
  `ChatService`, `SosService`, or Firestore/RTDB schemas.
- Do not change Ride Detail's pending-requests accept/reject flow, or Live
  Map's follow-mode row-tap behavior (`controller.followMember(m)` stays
  the `ListTile`'s main `onTap`).
- Do not add `package:collection` to `pubspec.yaml` — implement the
  `uid` lookup as a plain loop.
- After every task: run `flutter analyze` (expect no new warnings/errors)
  and `flutter test` (expect all existing tests still pass).
- This project is not a git repository — skip any `git commit` steps;
  leave changes on disk after each task's verification passes.

---

## File Structure

New file:
- `lib/modules/rides/member_detail_sheet.dart` — `showMemberDetail(...)`.

Modified files:
- `lib/modules/ride_map/ride_map_controller.dart` — add `rideMembers`,
  `rideMemberFor`.
- `lib/modules/rides/ride_detail_view.dart` — wrap `_MemberTile` in a tap
  handler that opens the sheet.
- `lib/modules/ride_map/ride_map_view.dart` — real names in `_showMembers`,
  add an info-icon trailing action that opens the sheet.

---

### Task 1: `RideMapController` — load real member profiles

**Files:**
- Modify: `lib/modules/ride_map/ride_map_controller.dart`

**Interfaces:**
- Produces: `RxList<RideMember> rideMembers` (bound to
  `RideService.watchMembers(rideId)`).
- Produces: `RideMember? rideMemberFor(String uid)`.
- Consumes: `RideService` (already injected as `_rideService`), `RideMember`
  model (needs a new import).

- [ ] **Step 1: Add the `RideMember` import**

Edit `lib/modules/ride_map/ride_map_controller.dart`. Add this import next
to the existing `member_location.dart` import:

```dart
import '../../models/ride_member.dart';
```

- [ ] **Step 2: Add the `rideMembers` field**

Add after the existing `final RxList<MemberLocation> members = <MemberLocation>[].obs;`
line:

```dart
  final RxList<RideMember> rideMembers = <RideMember>[].obs;
```

- [ ] **Step 3: Bind the stream in `_start()`**

Find this line in `_start()`:

```dart
    members.bindStream(_rideLoc.watchLocations(rideId));
```

Add immediately after it:

```dart
    rideMembers.bindStream(_rideService.watchMembers(rideId));
```

- [ ] **Step 4: Add the `rideMemberFor` lookup**

Add this method next to `_followTargetPosition()` (same private-helpers
region):

```dart
  RideMember? rideMemberFor(String memberUid) {
    for (final RideMember m in rideMembers) {
      if (m.uid == memberUid) return m;
    }
    return null;
  }
```

- [ ] **Step 5: Run analyze**

Run: `flutter analyze`
Expected: no new issues. (`_rideService` already exists as a field of type
`RideService`, used by the existing `watchRide` call — confirm by reading
the field declaration near the top of the class if unsure.)

- [ ] **Step 6: Run full test suite**

Run: `flutter test`
Expected: all existing tests pass (no test imports this controller).

---

### Task 2: Shared `showMemberDetail` sheet

**Files:**
- Create: `lib/modules/rides/member_detail_sheet.dart`

**Interfaces:**
- Consumes: `RideMember` (`models/ride_member.dart`), `MemberLocation`
  (`models/member_location.dart`), `RouteResult` (`models/route_result.dart`),
  `StatusBadge.label` (`widgets/status_badge.dart`), `Routes.rideMap`
  (`routes/app_routes.dart`), `AppSpacing` (`core/theme/app_spacing.dart`).
- Produces:
  ```dart
  void showMemberDetail(
    BuildContext context, {
    required RideMember member,
    required String rideId,
    MemberLocation? live,
    RouteResult? route,
  })
  ```
  Called by Task 3 (Ride Detail) and Task 4 (Live Map).

- [ ] **Step 1: Write the file**

```dart
// lib/modules/rides/member_detail_sheet.dart

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_spacing.dart';
import '../../models/member_location.dart';
import '../../models/ride_member.dart';
import '../../models/route_result.dart';
import '../../routes/app_routes.dart';
import '../../widgets/status_badge.dart';

/// Shows a bottom sheet with a member's profile info, and — when [live] is
/// provided (i.e. the Live Map screen is open and has RTDB data for this
/// member) — their live status: online/offline, speed, battery, and ETA to
/// destination if [route] is given.
///
/// When [live] is null (e.g. opened from Ride Detail, which has no RTDB
/// access), shows a prompt to open the live map instead.
void showMemberDetail(
  BuildContext context, {
  required RideMember member,
  required String rideId,
  MemberLocation? live,
  RouteResult? route,
}) {
  final ColorScheme scheme = Theme.of(context).colorScheme;

  Get.bottomSheet(
    SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: member.color.withValues(alpha: 0.6),
                      width: 2.5,
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 28,
                    backgroundColor: member.color.withValues(alpha: 0.15),
                    backgroundImage: member.photoUrl != null
                        ? CachedNetworkImageProvider(member.photoUrl!)
                        : null,
                    child: member.photoUrl == null
                        ? Text(
                            member.name.isNotEmpty
                                ? member.name[0].toUpperCase()
                                : '?',
                            style: TextStyle(
                              color: member.color,
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                            ),
                          )
                        : null,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        member.name,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: <Widget>[
                          if (member.isHost) ...<Widget>[
                            StatusBadge.label(
                              label: 'Host',
                              color: scheme.primaryContainer,
                              textColor: scheme.primary,
                            ),
                            const SizedBox(width: 8),
                          ],
                          if (member.joinedAt != null)
                            Expanded(
                              child: Text(
                                'Joined ${_formatDate(member.joinedAt!)}',
                                style:
                                    Theme.of(context).textTheme.bodyMedium,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            const Divider(),
            const SizedBox(height: AppSpacing.md),
            if (live != null)
              _LiveStatus(live: live, route: route)
            else
              _NoLiveData(rideId: rideId),
          ],
        ),
      ),
    ),
    backgroundColor: scheme.surface,
  );
}

String _formatDate(DateTime d) {
  const List<String> months = <String>[
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${months[d.month - 1]} ${d.day}, ${d.year}';
}

class _LiveStatus extends StatelessWidget {
  final MemberLocation live;
  final RouteResult? route;
  const _LiveStatus({required this.live, this.route});

  @override
  Widget build(BuildContext context) {
    final int now = DateTime.now().millisecondsSinceEpoch;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _row(context, Icons.circle,
            live.online ? scheme.primary : scheme.onSurfaceVariant,
            live.lastSeenText(now)),
        const SizedBox(height: AppSpacing.sm),
        _row(context, Icons.speed_rounded, scheme.onSurfaceVariant,
            '${live.speedKmh.toStringAsFixed(0)} km/h'),
        const SizedBox(height: AppSpacing.sm),
        _row(context, Icons.battery_std_rounded, scheme.onSurfaceVariant,
            '${live.battery}% battery'),
        if (route != null) ...<Widget>[
          const SizedBox(height: AppSpacing.sm),
          _row(context, Icons.navigation_rounded, scheme.onSurfaceVariant,
              '${route!.distanceText} · ${route!.etaText} to destination'),
        ],
      ],
    );
  }

  Widget _row(BuildContext context, IconData icon, Color color, String text) {
    return Row(
      children: <Widget>[
        Icon(icon, size: 18, color: color),
        const SizedBox(width: AppSpacing.sm),
        Text(text, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}

class _NoLiveData extends StatelessWidget {
  final String rideId;
  const _NoLiveData({required this.rideId});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          "Open the live map to see this rider's location.",
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.md),
        FilledButton.icon(
          onPressed: () {
            Get.back();
            Get.toNamed(Routes.rideMap, arguments: rideId);
          },
          icon: const Icon(Icons.map_rounded),
          label: const Text('Open live map'),
        ),
      ],
    );
  }
}
```

Note: `GoogleFonts` is imported but unused if every text style now comes
from `Theme.of(context).textTheme` — remove the `google_fonts` import
since this file uses only theme text styles (double-check before running
analyze; the import above was included preemptively but nothing in this
file calls `GoogleFonts.poppins`, so delete the
`import 'package:google_fonts/google_fonts.dart';` line before saving).

- [ ] **Step 2: Run analyze**

Run: `flutter analyze`
Expected: no new issues. If an "unused import" warning appears for
`google_fonts`, remove that import line (per the note in Step 1) and
re-run.

- [ ] **Step 3: Run full test suite**

Run: `flutter test`
Expected: all existing tests pass (new file has no test importing it yet).

---

### Task 3: Wire the sheet into Ride Detail

**Files:**
- Modify: `lib/modules/rides/ride_detail_view.dart`

**Interfaces:**
- Consumes: `showMemberDetail` (Task 2), `controller.rideId` (already
  exists on `RideDetailController`).

- [ ] **Step 1: Add the import**

Add to the top of `lib/modules/rides/ride_detail_view.dart`:

```dart
import 'member_detail_sheet.dart';
```

- [ ] **Step 2: Wrap `_MemberTile`'s `AppCard` with a tap handler**

Find the `_MemberTile.build` method:

```dart
class _MemberTile extends StatelessWidget {
  final RideMember member;

  const _MemberTile({required this.member});

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.xs),
        child: Row(
```

`AppCard` already supports an `onTap` parameter (used elsewhere in this
same file by `_RideCard` in `my_rides_tab.dart` — check
`lib/widgets/app_card.dart` if unsure of the exact parameter name; it is
`onTap: VoidCallback?`). Add `onTap` to this `AppCard` call:

```dart
class _MemberTile extends StatelessWidget {
  final RideMember member;

  const _MemberTile({required this.member});

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        onTap: () => showMemberDetail(
          context,
          member: member,
          rideId: Get.find<RideDetailController>().rideId,
        ),
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.xs),
        child: Row(
```

(`_MemberTile` doesn't currently hold a reference to the controller — use
`Get.find<RideDetailController>()` the same way `_RequestTile` already
does in this file, e.g. `final RideDetailController c =
Get.find<RideDetailController>();` — either inline as above or as a local
variable; inline is fine since it's used once.)

- [ ] **Step 3: Run analyze**

Run: `flutter analyze`
Expected: no new issues.

- [ ] **Step 4: Run full test suite**

Run: `flutter test`
Expected: all existing tests pass.

---

### Task 4: Wire real names + info-icon sheet into Live Map

**Files:**
- Modify: `lib/modules/ride_map/ride_map_view.dart`

**Interfaces:**
- Consumes: `showMemberDetail` (Task 2), `controller.rideMembers`,
  `controller.rideMemberFor(uid)` (Task 1), `controller.routeFor(uid)`
  (already exists), `controller.rideId` (already exists).

- [ ] **Step 1: Add imports**

Add to the top of `lib/modules/ride_map/ride_map_view.dart`:

```dart
import '../../models/ride_member.dart';
import '../rides/member_detail_sheet.dart';
```

- [ ] **Step 2: Fix the hardcoded name and add the info-icon action in
  `_showMembers`**

Find this block inside `_showMembers`:

```dart
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: CircleAvatar(
                      backgroundColor: AppColors.memberColorForKey(m.uid).withValues(alpha: 0.15),
                      radius: 16,
                      child: Icon(Icons.person, color: AppColors.memberColorForKey(m.uid)),
                    ),
                    title: Text(
                      m.uid == controller.uid ? 'You' : 'Rider',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      '${m.speedKmh.toStringAsFixed(0)} km/h · ${m.battery}% · '
                      '${m.lastSeenText(now)}$eta',
                      style: GoogleFonts.poppins(fontSize: 12),
                    ),
                    onTap: () {
                      Get.back();
                      controller.followMember(m);
                    },
                  ),
                );
```

Replace it with:

```dart
                final RideMember? profile = controller.rideMemberFor(m.uid);
                final String displayName = profile?.name ??
                    (m.uid == controller.uid ? 'You' : 'Rider');
                final RideMember resolvedMember = profile ??
                    RideMember(
                      uid: m.uid,
                      name: displayName,
                      colorValue:
                          AppColors.memberColorForKey(m.uid).toARGB32(),
                      role: 'rider',
                    );

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: CircleAvatar(
                      backgroundColor: AppColors.memberColorForKey(m.uid).withValues(alpha: 0.15),
                      radius: 16,
                      child: Icon(Icons.person, color: AppColors.memberColorForKey(m.uid)),
                    ),
                    title: Text(
                      displayName,
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      '${m.speedKmh.toStringAsFixed(0)} km/h · ${m.battery}% · '
                      '${m.lastSeenText(now)}$eta',
                      style: GoogleFonts.poppins(fontSize: 12),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.info_outline),
                      tooltip: 'Member details',
                      onPressed: () => showMemberDetail(
                        context,
                        member: resolvedMember,
                        rideId: controller.rideId,
                        live: m,
                        route: route,
                      ),
                    ),
                    onTap: () {
                      Get.back();
                      controller.followMember(m);
                    },
                  ),
                );
```

Note: `route` here is the same local variable already computed two lines
above this block (`final RouteResult? route = controller.routeFor(m.uid);`)
— no new lookup needed, it's already in scope. `RideMember`'s constructor
requires `uid`, `name`, `colorValue`, `role` (all provided above);
`photoUrl` and `joinedAt` default to `null`/unset per the model's existing
constructor defaults.

- [ ] **Step 3: Run analyze**

Run: `flutter analyze`
Expected: no new issues.

- [ ] **Step 4: Run full test suite**

Run: `flutter test`
Expected: all existing tests pass.

- [ ] **Step 5: Manual on-device verification**

No automated test covers these two screens (both depend on live GetX
controllers wired to RTDB/Firestore streams and `flutter_map`). Verify by
hand with 2 devices in the same active ride:

1. **Ride Detail:** tap a member tile → sheet opens showing name, role
   badge (if host), joined date, and "Open the live map to see this
   rider's location" + working "Open live map" button.
2. **Live Map members sheet:** confirm both rows now show real names
   (not "Rider"/"You" for the other member) instead of the placeholder.
3. **Live Map members sheet, row tap:** still starts following that
   member on the map (unchanged from the prior follow-mode feature).
4. **Live Map members sheet, info icon tap:** sheet opens showing name,
   role, joined date, online/offline + last-seen, speed, battery, and (if
   a destination is set on the ride) distance + ETA.
5. Confirm tapping the info icon does **not** close the members sheet
   underneath it (sheets should stack, per the design — Ride Detail's
   `Get.back()` in the "Open live map" button only closes the *detail*
   sheet, and navigates to the map).

Report back whether all 5 checks pass; do not mark this task complete
until they do.
