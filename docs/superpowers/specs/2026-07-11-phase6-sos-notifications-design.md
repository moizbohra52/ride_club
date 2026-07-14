# Phase 6 — SOS + Notifications (FCM-ready) — Design Spec

**Date:** 2026-07-11
**Project:** `ride_club` (RideTogether)
**Builds on:** Phase 1–5 (auth/profile, rides, RTDB live location, routing, chat).

---

## Reality check (drives the whole phase)

Cross-device **push** (delivered while the app is closed) needs a server sender —
a Firebase **Cloud Function**, which requires the **Blaze (paid) plan**. The project
is on **Spark (free)**. So Phase 6 delivers what genuinely works on Spark:

- **SOS over Realtime Database** → members watching the ride get an instant in-app
  full-screen alert + local notification + sound (works while the app is open or in
  the Phase-3 foreground service).
- **FCM token + local notifications** fully wired, so enabling Blaze and deploying the
  included Cloud Function turns on real background push with **zero app changes**.

## Locked decisions (from brainstorming)

| Fork | Decision |
|------|----------|
| Push approach | SOS via **RTDB in-app alert** now; FCM token + local-notifications ready for a Blaze Cloud Function later. |
| SOS actions | RTDB alert → members' full-screen alert + location; **emergency-contact SMS**; **confirm dialog**; **active-SOS banner + cancel**. |
| SOS button | Red **FAB on Live Map** (active ride) + button in **Ride Detail**. |
| Other notifications | FCM token saved to `users/{uid}.fcmToken`; **member-joined / request-accepted** shown in-app (snackbar + local notification). |
| Local notifications | Add **flutter_local_notifications** (same plugin will render FCM background push after Blaze). |
| SOS confirm | A **dialog** (not 3-sec hold) — clearer + reliable. |
| Cloud Function | Ship **deploy-ready** in `functions/` with a README; deployed only when Blaze is on. |

## RTDB structure

```
sos/{rideId}/{sosId}
  senderId, senderName, lat?, lng?, active (bool), startedAt (ServerValue.timestamp)
```
`users/{uid}.fcmToken` (Firestore) — saved for the future Cloud Function.

## Services (new)

- **`NotificationService`** (GetxService):
  - `init()` — initialize flutter_local_notifications (Android channel `sos` high-importance + `general`); request notification permission (Android 13+/iOS); get FCM token → `UserService.update(uid, {fcmToken})`; listen `onTokenRefresh`; `FirebaseMessaging.onMessage` → `showLocal`.
  - `showLocal(String title, String body, {bool sos = false})`.
- **`SosService`** (GetxService):
  - `Future<String?> trigger(String rideId)` — get current location (best-effort), write `sos/{rideId}/{sosId}` with `active:true`; returns sosId.
  - `Future<void> cancel(String rideId, String sosId)` — set `active:false`.
  - `Stream<List<SosAlert>> watchActiveSos(String rideId)` — active alerts (excluding my own for the incoming-alert UI; sender tracks own via returned id).
  - `Future<void> textEmergencyContact(String contact, double? lat, double? lng)` — `url_launcher` `sms:` with an OSM location link.
- **`RideEventsService`** (GetxService):
  - Watches a ride's members/requests (Phase 2 streams) and emits in-app notifications for new members / accepted requests while the user has that ride open. (Kept lightweight; full cross-device delivery is the Cloud Function's job later.)

## Model
`SosAlert{ sosId, senderId, senderName, lat?, lng?, active, startedAt }` + `hasLocation`.

## UI

- **SOS button** — red FAB on `RideMapView` (when ride active) + a red button in `RideDetailView`. Tap → confirm dialog "Send SOS to your ride? Everyone will see your live location." → on confirm: `SosService.trigger`; then, if profile has an emergency contact, a second prompt "Also text {contact}?" → `textEmergencyContact`.
- **Incoming SOS** — `RideMapController`/`RideDetailController` watch `watchActiveSos`; on a new active alert not mine → show a **full-screen red `Get.dialog`** (⚠️ "{name} needs help!" + "Open live map" + "Dismiss") + `showLocal(sos:true)`. The sender's pin on the map pulses red while active.
- **Active-SOS banner** (sender) — a persistent red bar on map/detail "SOS active · Tap to cancel" → `SosService.cancel`.

## FCM wiring
- `NotificationService.init()` called after login (in splash→home path or main). Token saved to Firestore. Background FCM handler registered (top-level function) that shows a local notification — active once the Cloud Function sends pushes.
- `functions/index.js` — a **ready** onValueCreated trigger for `sos/{rideId}/{sosId}` that fetches ride members' fcmTokens and sends FCM. Not deployed on Spark; README explains `firebase deploy --only functions` after enabling Blaze.

## Native config
- Android: `POST_NOTIFICATIONS` present (Phase 1). flutter_local_notifications channel init in code; uses app launcher icon. iOS: add push/background note in docs (real device push needs Apple dev account + APNs key — documented, not blocking).

## Error handling
- SOS with no GPS fix → still send alert (`lat/lng` null, "location unavailable" in UI).
- No emergency contact → skip SMS step silently.
- Notification permission denied → in-app dialogs still fire; log it.
- RTDB offline → write queues; alert delivers on reconnect.

## Testing
- Unit: `SosAlert.fromMap` (with/without location), `hasLocation`; emergency SMS URI builder (pure function → `sms:?body=...`).
- On-device: trigger SOS → confirm dialog → RTDB `sos/...` written; second account sees full-screen alert + notification; sender sees active banner, cancels → alert clears; emergency SMS composer opens with location link.

## Out of scope (later)
Real background push (deploy the included Cloud Function on Blaze). iOS real-device push. Ride history + release (Phase 7).

## Quality rules
Clean units; compiles/runs; honest about Spark limits; typed friendly errors; `flutter analyze` clean; tests pass; no Google Maps.
