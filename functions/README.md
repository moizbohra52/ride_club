# RideTogether Cloud Functions (SOS push)

This folder is **deploy-ready but not deployed**. On the free **Spark** plan,
SOS alerts already work in-app (delivered instantly over Realtime Database while
a recipient has the app open or the location foreground-service running). To
also push SOS to members **when their app is closed**, deploy this function on
the **Blaze** plan.

## What it does

`onSos` listens for new writes to `sos/{rideId}/{sosId}`. When an SOS becomes
active, it looks up the ride's members (Firestore `rides/{rideId}/members`),
reads each member's `users/{uid}.fcmToken`, and sends an FCM push (SOS channel).

The Flutter app needs **no changes** — it already:
- saves each user's FCM token to `users/{uid}.fcmToken` (`NotificationService`),
- registers the `sos` Android notification channel,
- has a background message handler.

## Deploy (one time)

1. Enable the **Blaze** plan in the Firebase console (free tier is generous; a
   card is required). This does not change app behaviour, only enables Functions.
2. Install the Firebase CLI: `npm i -g firebase-tools` then `firebase login`.
3. From the project root, associate this folder:
   - If you have no `firebase.json` yet: `firebase init functions`
     (choose "use an existing project" → `ridetogether-nwaytech`, JavaScript,
     and when asked to overwrite `functions/`, keep these files).
   - Or add `"functions": { "source": "functions" }` to `firebase.json`.
4. `cd functions && npm install`
5. `firebase deploy --only functions`

After deploy, hitting SOS in the app will push a notification to every ride
member even if their app is closed — no further changes required.

## Cost

Trigger + a handful of FCM sends per SOS is negligible and stays within the
Blaze free tier for normal usage. FCM itself is free.
