// RideTogether Cloud Functions — deploy ONLY after enabling the Blaze plan.
//
// This turns the app's RTDB SOS writes into real background push notifications
// (delivered even when the recipient's app is closed). No Flutter app changes
// are needed — the app already saves each user's fcmToken to
// users/{uid}.fcmToken and shows notifications via the 'sos' channel.
//
// Deploy:  firebase deploy --only functions

const { onValueCreated } = require('firebase-functions/v2/database');
const {
  onDocumentUpdated,
  onDocumentCreated,
} = require('firebase-functions/v2/firestore');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');

initializeApp();
const db = getFirestore();

// ── Helpers ────────────────────────────────────────────────────────────────

/** Fetch FCM tokens for a set of uids (skips missing tokens). */
async function tokensFor(uids) {
  const tokens = [];
  for (const uid of uids) {
    const u = await db.collection('users').doc(uid).get();
    const t = u.get('fcmToken');
    if (t) tokens.push(t);
  }
  return tokens;
}

/** Member uids of a ride, optionally excluding one uid (e.g. the sender). */
async function rideMemberUids(rideId, excludeUid) {
  const snap = await db
    .collection('rides')
    .doc(rideId)
    .collection('members')
    .get();
  return snap.docs.map((d) => d.id).filter((u) => u !== excludeUid);
}

/** Ride's display name (falls back to "your ride"). */
async function rideName(rideId) {
  const r = await db.collection('rides').doc(rideId).get();
  return (r.exists && r.get('name')) || 'your ride';
}

/**
 * Send a push to the given tokens. `data` values must be strings — they drive
 * tap navigation in the app (see NotificationService._routeFromData).
 */
async function sendPush(tokens, { title, body, data, channelId = 'general' }) {
  if (!tokens || tokens.length === 0) return;
  const stringData = {};
  for (const [k, v] of Object.entries(data || {})) {
    if (v !== undefined && v !== null) stringData[k] = String(v);
  }
  await getMessaging().sendEachForMulticast({
    tokens,
    notification: { title, body },
    data: stringData,
    android: { priority: 'high', notification: { channelId } },
    apns: { payload: { aps: { sound: 'default' } } },
  });
}

// SOS — fires when a new alert is written to sos/{rideId}/{sosId}.
exports.onSos = onValueCreated('/sos/{rideId}/{sosId}', async (event) => {
  const sos = event.data.val();
  const { rideId, sosId } = event.params;
  if (!sos || sos.active !== true) return;

  const uids = await rideMemberUids(rideId, sos.senderId);
  const tokens = await tokensFor(uids);
  const who = sos.senderName || 'A rider';
  await sendPush(tokens, {
    title: `SOS: ${who}`,
    body: `${who} needs help! Open RideClub.`,
    channelId: 'sos',
    data: { type: 'sos', rideId, sosId },
  });
});

// Chat — fires on each new message at chats/{rideId}/messages/{msgId}.
// Notifies every ride member except the sender.
exports.onChatMessage = onValueCreated(
  '/chats/{rideId}/messages/{msgId}',
  async (event) => {
    const msg = event.data.val();
    const { rideId, msgId } = event.params;
    if (!msg || !msg.senderId) return;

    const uids = await rideMemberUids(rideId, msg.senderId);
    const tokens = await tokensFor(uids);
    const who = msg.senderName || 'A rider';
    const preview =
      msg.type === 'location'
        ? '📍 Shared a location'
        : (msg.text || 'New message');
    await sendPush(tokens, {
      title: who,
      body: preview,
      channelId: 'general',
      data: { type: 'chat', rideId, msgId },
    });
  }
);

// Join request — fires when a rider requests to join
// (rides/{rideId}/requests/{uid}). Notifies the host.
exports.onJoinRequest = onDocumentCreated(
  'rides/{rideId}/requests/{uid}',
  async (event) => {
    const req = event.data && event.data.data();
    const { rideId } = event.params;
    if (!req) return;

    const rideDoc = await db.collection('rides').doc(rideId).get();
    if (!rideDoc.exists) return;
    const hostUid = rideDoc.get('createdBy');
    if (!hostUid) return;

    const tokens = await tokensFor([hostUid]);
    const name = rideDoc.get('name') || 'your ride';
    await sendPush(tokens, {
      title: 'New join request',
      body: `${req.name || 'A rider'} wants to join ${name}.`,
      channelId: 'general',
      data: { type: 'joinRequest', rideId },
    });
  }
);

// Request accepted — fires when a request's status changes to "accepted".
// Notifies the requester.
exports.onRequestAccepted = onDocumentUpdated(
  'rides/{rideId}/requests/{uid}',
  async (event) => {
    const before = event.data.before.data();
    const after = event.data.after.data();
    const { rideId, uid } = event.params;
    if (!after) return;
    if (before?.status === after.status || after.status !== 'accepted') return;

    const tokens = await tokensFor([uid]);
    const name = await rideName(rideId);
    await sendPush(tokens, {
      title: 'Request accepted',
      body: `You're in! ${name} is ready — open the live map.`,
      channelId: 'general',
      data: { type: 'requestAccepted', rideId },
    });
  }
);

// Member joined — fires when a member doc is created
// (rides/{rideId}/members/{uid}). Notifies existing members (not the joiner,
// and not on the host's own creation of the ride).
exports.onMemberJoined = onDocumentCreated(
  'rides/{rideId}/members/{uid}',
  async (event) => {
    const member = event.data && event.data.data();
    const { rideId, uid } = event.params;
    if (!member) return;
    // The host is added at ride-creation time — don't announce that.
    if (member.role === 'host') return;

    const uids = await rideMemberUids(rideId, uid);
    const tokens = await tokensFor(uids);
    const name = await rideName(rideId);
    await sendPush(tokens, {
      title: `${member.name || 'A new rider'} joined`,
      body: `${member.name || 'Someone'} joined ${name}.`,
      channelId: 'general',
      data: { type: 'memberJoined', rideId },
    });
  }
);

// Ride ended — fires when a ride's status changes to "ended". Notifies members.
exports.onRideEnded = onDocumentUpdated('rides/{rideId}', async (event) => {
  const before = event.data.before.data();
  const after = event.data.after.data();
  const { rideId } = event.params;
  if (!after) return;
  if (before?.status === after.status || after.status !== 'ended') return;

  const uids = await rideMemberUids(rideId, after.createdBy);
  const tokens = await tokensFor(uids);
  await sendPush(tokens, {
    title: 'Ride ended',
    body: `${after.name || 'Your ride'} has ended.`,
    channelId: 'general',
    data: { type: 'rideEnded', rideId },
  });
});

// Fires when a user's profile is updated. Updates all ride member documents
// in rides/{rideId}/members/{uid} with the new name and photoUrl.
exports.onProfileUpdated = onDocumentUpdated('users/{uid}', async (event) => {
  const before = event.data.before.data();
  const after = event.data.after.data();
  const uid = event.params.uid;
  
  // Check if name or photoUrl actually changed
  if (before?.name === after?.name && before?.photoUrl === after?.photoUrl) {
    return null;
  }

  // Get all rideRefs for this user to find which rides they're in
  const rideRefsSnap = await db.collection('users').doc(uid).collection('rideRefs').get();
  
  if (rideRefsSnap.empty) {
    return null;
  }

  const batch = db.batch();
  const updateData = {};
  if (after?.name) updateData.name = after.name;
  if (after?.photoUrl !== undefined) updateData.photoUrl = after.photoUrl;

  // Update each ride's member document
  for (const rideRefDoc of rideRefsSnap.docs) {
    const rideId = rideRefDoc.id;
    const memberRef = db.collection('rides').doc(rideId).collection('members').doc(uid);
    batch.set(memberRef, updateData, { merge: true });
  }

  await batch.commit();
  return null;
});
