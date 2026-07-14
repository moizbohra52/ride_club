# RideTogether — Design Spec

**Date:** 2026-07-10
**Project:** `ride_club` (app name: RideTogether)
**Goal:** Cross-platform (Android + iOS) group ride-tracking app — friends on a bike/car trip see each other's live location on an OpenStreetMap map and chat in real time.

---

## Locked decisions (from brainstorming)

| Fork | Decision |
|------|----------|
| State management / architecture | **GetX** — state + routing + DI + reactivity in one package. Matches the `modules/` + controller-per-screen layout. |
| Firebase wiring | User **already has a Firebase project**. Real `firebase_options.dart` values pasted in; code written against them. |
| OTP during dev | Full **real Phone OTP flow** built; user adds **fictional test numbers** in console to develop without SMS quota / SHA / APNs. |
| Profile photo | **Firebase Storage** (Spark-compatible) with a base64-in-Firestore fallback note. |
| Local persistence | **GetStorage** for theme mode + onboarding flags. |

## Strict tech stack (do not substitute)

- Flutter 3.x, null-safety, Material 3, dark + light.
- **Maps:** `flutter_map` + OpenStreetMap tiles (`https://tile.openstreetmap.org/{z}/{x}/{y}.png`), `userAgentPackageName` set, OSM attribution widget. **No Google Maps.**
- **Routing:** OSRM public API (`router.project-osrm.org`) for polyline/distance/ETA.
- **Geocoding/search:** Nominatim (proper User-Agent, rate-limit respect).
- **POI:** Overpass / Nominatim.
- **Location:** `geolocator` + `flutter_compass`.
- **Backend (Firebase Spark):** Auth (Phone OTP), Firestore (users/rides/members/history), Realtime DB (live locations, chat, presence, typing), FCM (invite/SOS/joined).

## Data model

```
Firestore:
  users/{uid}: name, phone, photoUrl, emergencyContact, fcmToken, createdAt
  rides/{rideId}: name, code, destination{lat,lng,label}, createdBy, status, createdAt
  rides/{rideId}/members/{uid}: name, color, joinedAt, role

Realtime DB:
  locations/{rideId}/{uid}: lat, lng, speed, heading, battery, updatedAt
  chats/{rideId}/messages/{msgId}: senderId, text, type, timestamp, readBy
  presence/{rideId}/{uid}: online, lastSeen, typing
```

## Architecture — folder layout

```
lib/
├── main.dart                      # Firebase.initializeApp + GetMaterialApp + initial route
├── firebase_options.dart          # real values (user-provided)
├── core/
│   ├── theme/{app_theme,app_colors}.dart
│   ├── constants/app_constants.dart
│   └── utils/{validators,ui_helpers,logger}.dart
├── routes/{app_routes,app_pages}.dart
├── models/app_user.dart
├── services/{auth_service,user_service,theme_service}.dart   # GetxService singletons
├── modules/
│   ├── splash/{splash_view,splash_controller,splash_binding}.dart
│   ├── auth/{phone_view,otp_view,auth_controller,auth_binding}.dart
│   └── profile_setup/{profile_setup_view,profile_setup_controller,profile_setup_binding}.dart
│   └── home/  (stub in Phase 1)
└── widgets/{primary_button,loading_overlay}.dart
```

Conventions: each `modules/<name>/` holds `<name>_view.dart`, `<name>_controller.dart`, `<name>_binding.dart`. Services are `GetxService` singletons registered permanently and reused by all later phases.

## Phase 1 scope (this deliverable)

Project setup, pubspec, theme, routing, splash, Firebase init, Phone OTP login, profile setup.

### Flow / state machine

```
Splash (min delay + auth check)
   ├─ not logged in ─► PhoneInput → OTP → [profile complete?]
   │                                         ├─ no  → ProfileSetup → Home(stub)
   │                                         └─ yes → Home(stub)
   └─ logged in ── [profile complete?] ─ same branch
```

### AuthService (GetxService)
`verifyPhone(phone, {onCodeSent, onAutoVerify, onError})`, `verifyOtp(code)`, `resendCode()`, `signOut()`. Owns `verificationId` + `resendToken` + auto-retrieval. OTP controller owns 60s resend countdown (`RxInt`) and 6-box PIN input.

### Error handling (Phase 1)
Typed OTP errors → friendly snackbars: `invalid-phone`, `invalid-code`, `session-expired`, `quota-exceeded`, `network`. No-internet detection with retry banner. Location permissions deferred to Phase 3.

### Theme
Material 3 `ColorScheme.fromSeed`, full light + dark `ThemeData`, `ThemeService` (system default + manual toggle persisted in GetStorage). The initial "dawn horizon" gradient motif has been replaced with a solid `AppColors.seed` background for a cleaner, more modern aesthetic.

## Delivery plan (phase by phase — wait for "next")

1. **Phase 1** — setup, pubspec, theme, routing, splash, Firebase init, Phone OTP, profile setup. ← *this*
2. **Phase 2** — Home, Create Ride, Join Ride (code), Firestore wiring.
3. **Phase 3** — flutter_map + OSM tiles, my live location, friend markers via Realtime DB.
4. **Phase 4** — OSRM routing, polyline, ETA, distance, off-route re-route.
5. **Phase 5** — Realtime chat: text + location message, typing indicator, read receipts, unread badge.
6. **Phase 6** — SOS + FCM notifications.
7. **Phase 7** — Ride history, background location (Android foreground service / iOS bg mode), iOS config, release builds (APK + iOS).

## Quality rules (all phases)
Clean architecture; every phase compiles/runs (no pseudo-code, no "TODO: implement later"); handle GPS off / no internet / permission denied / OTP failure / empty states; battery-aware location frequency (<20% → slower); full Android manifest perms + iOS Info.plist keys + Firebase setup for both platforms.
