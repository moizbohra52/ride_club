// RideTogether Cloud Functions — deploy ONLY after enabling the Blaze plan.
//
// This turns the app's RTDB SOS writes into real background push notifications
// (delivered even when the recipient's app is closed). No Flutter app changes
// are needed — the app already saves each user's fcmToken to
// users/{uid}.fcmToken and shows notifications via the 'sos' channel.
//
// Deploy:  firebase deploy --only functions

const { onValueCreated } = require('firebase-functions/v2/database');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');

initializeApp();

// Fires when a new SOS alert is written to sos/{rideId}/{sosId}.
exports.onSos = onValueCreated('/sos/{rideId}/{sosId}', async (event) => {
  const sos = event.data.val();
  const { rideId } = event.params;
  if (!sos || sos.active !== true) return;

  // Collect the ride's members (Firestore), excluding the sender.
  const membersSnap = await getFirestore()
    .collection('rides')
    .doc(rideId)
    .collection('members')
    .get();
  const uids = membersSnap.docs
    .map((d) => d.id)
    .filter((u) => u !== sos.senderId);
  if (uids.length === 0) return;

  // Look up each member's FCM token.
  const tokens = [];
  for (const uid of uids) {
    const u = await getFirestore().collection('users').doc(uid).get();
    const t = u.get('fcmToken');
    if (t) tokens.push(t);
  }
  if (tokens.length === 0) return;

  await getMessaging().sendEachForMulticast({
    tokens,
    notification: {
      title: `SOS: ${sos.senderName || 'A rider'}`,
      body: `${sos.senderName || 'A rider'} needs help! Open RideTogether.`,
    },
    android: {
      priority: 'high',
      notification: { channelId: 'sos' },
    },
    apns: {
      payload: { aps: { sound: 'default' } },
    },
  });
});
