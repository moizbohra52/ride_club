# Phase 2 — Rides (Create, Join, Approve, Manage) — Design Spec

**Date:** 2026-07-11
**Project:** `ride_club` (RideTogether)
**Builds on:** Phase 1 (Google auth, profile, theme, routing, home stub).

---

## Locked decisions (from brainstorming)

| Fork | Decision |
|------|----------|
| Ride model | **Code + host approval.** Creator = host, gets 6-char code. Others enter code → join **request** → host accepts/rejects. |
| Active rides per user | **Multiple** — a user can host/belong to several rides; shown as a list. |
| Approval data | **Separate `requests` subcollection** per ride; host sees a live pending list (+ badge). FCM push deferred to Phase 6 — structure built so push is trivial to add. |
| Home layout | **Bottom tabs: My Rides · Create · Join.** Ride tap → Ride Detail. |
| Destination | **Nominatim search now** — search destination, store `{lat,lng,label}`. (Was originally Phase 4; pulled forward per user.) |

## Data model (Firestore)

```
rides/{rideId}
  name: string
  code: string            // 6-char A–Z0–9, unique
  destination: { lat, lng, label } | null
  createdBy: uid
  status: 'active' | 'ended'
  memberCount: int         // denormalized, kept in sync on accept/end
  createdAt: serverTimestamp

rides/{rideId}/members/{uid}
  name, photoUrl, color, role: 'host'|'rider', joinedAt

rides/{rideId}/requests/{uid}
  name, photoUrl, requestedAt, status: 'pending'|'accepted'|'rejected'

users/{uid}/rideRefs/{rideId}     // denormalized index for a fast "My Rides"
  rideId, name, role, status, joinedAt
```

**Why `rideRefs`:** listing a user's rides without a collection-group query. Written when a user creates a ride (role host, immediately) and when a request is accepted (role rider). Kept minimal; the ride doc is the source of truth.

**Code generation:** 6 chars from `ABCDEFGHJKLMNPQRSTUVWXYZ23456789` (no ambiguous 0/O/1/I). On create, generate → check `rides` where `code == x` → retry up to 5× on collision.

## Architecture

### Services (new, GetxService singletons)
- **`RideService`** — `createRide(name, destination)`, `requestJoin(code)`, `watchMyRides()`, `watchRide(id)`, `watchMembers(id)`, `watchRequests(id)`, `acceptRequest(rideId, uid)`, `rejectRequest(rideId, uid)`, `endRide(id)`, `leaveRide(id)`. Owns unique-code generation. All writes wrapped with a timeout (Phase 1 pattern).
- **`GeoService`** — Nominatim search (`searchPlaces(query)`) + reverse geocode, with the required `User-Agent` header (`AppConstants.httpUserAgent`) and rate-limit respect (debounce input, min 1 req/sec).

### Models
- `Ride` (fromDoc/toMap, `isHost(uid)`, `destinationLabel`)
- `RideMember` (role, color)
- `JoinRequest` (status enum)
- `PlaceResult` (Nominatim: lat, lng, displayName)

### Module `modules/rides/`
- `rides_shell` — Scaffold + bottom `NavigationBar` (My Rides · Create · Join), holds the 3 tab bodies. Replaces the Phase 1 home stub as `Routes.home`.
- `my_rides` — view/controller/binding: live list from `watchMyRides()`; cards with role + status + pending-count badge (host). Empty state.
- `create_ride` — view/controller: name field + Nominatim destination search (autocomplete list); on submit → RideService.createRide → success sheet with code + share (share_plus).
- `join_ride` — view/controller: 6-box code input → requestJoin → states: sent / pending / rejected / not-found / already-member.
- `ride_detail` — view/controller/binding (arg: rideId): members list, code + share; **host-only** pending requests with Accept/Reject and End ride; rider sees Leave ride. Live via streams.

### Routing
- `Routes.home` → `RidesShell` (tabs). `Routes.rideDetail` (arg rideId) added to `app_pages`.
- Splash/auth already route to `Routes.home` — unchanged.

## Data flow
- **Create:** form → `RideService.createRide` writes `rides/{id}` (status active, memberCount 1) + `members/{host}` (role host) + `users/{host}/rideRefs/{id}` in a batch → returns code.
- **Join:** code → find ride by code → write `requests/{uid}` (pending). Host's `watchRequests` stream updates live.
- **Accept:** host → batch: `requests/{uid}.status=accepted` + `members/{uid}` (role rider, assigned color) + `rides/{id}.memberCount++` + `users/{uid}/rideRefs/{id}`. Requester's join screen (watching own request) flips to "joined" and can open the ride.
- **Reject:** `requests/{uid}.status=rejected`; requester sees rejected state.

## Error / empty handling
- No internet / Firestore write timeout (reuse Phase 1 `.timeout`).
- Duplicate code on create → retry; surface friendly error after 5 tries.
- Join: code not found, ride ended, already a member, already requested (pending), previously rejected.
- Nominatim: no results, network error, rate-limit (debounce 500ms; don't spam).
- Empty states: no rides, no members, no pending requests.
- Location permissions still deferred to Phase 3.

## Security rules (test mode now; documented for later)
Phase 2 runs in Firestore test mode. Real rules (Phase 7 hardening) will enforce: only `createdBy` can accept/reject/end; a user can write only their own `requests/{uid}` and `rideRefs`; members readable by ride members. Documented now, enforced later.

## Out of scope (later phases)
- Live location markers, map — Phase 3.
- Route polyline / ETA — Phase 4 (destination *data* captured now; routing later).
- Chat — Phase 5. FCM push for requests/invites — Phase 6.

## Console prerequisite (BLOCKS running Phase 2)
**Cloud Firestore must be created**: Firebase Console → Build → Firestore Database → Create database → test mode. Without it: `NOT_FOUND / database does not exist`. Realtime DB not needed until Phase 3.

## Quality rules (carried from Phase 1)
Clean module structure; every phase compiles/runs; typed friendly errors; no pseudo-code; `flutter analyze` clean; verify on emulator with screenshots.
