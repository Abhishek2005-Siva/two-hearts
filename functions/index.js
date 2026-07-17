const { onDocumentCreated, onDocumentWritten } = require('firebase-functions/v2/firestore');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');

initializeApp();
const db = getFirestore();

// ── Helper: fetch recipient FCM token ─────────────────────────────────────

async function getToken(uid) {
  if (!uid) return null;
  const doc = await db.collection('users').doc(uid).get();
  return doc.exists ? (doc.data().fcmToken ?? null) : null;
}

// ── Helper: send hybrid notification+data message ─────────────────────────

async function sendNotification(token, { title, body, data = {} }) {
  if (!token) return;
  try {
    await getMessaging().send({
      token,
      notification: { title, body },
      data: { ...data },
      android: { priority: 'high' },
      apns: { payload: { aps: { sound: 'default', badge: 1 } } },
    });
  } catch (err) {
    console.error('FCM send error:', err.message);
  }
}

// ── Helper: get partner UID from couple ───────────────────────────────────

async function getPartnerUid(coupleId, senderUid) {
  const doc = await db.collection('couples').doc(coupleId).get();
  if (!doc.exists) return null;
  const members = doc.data().members ?? [];
  return members.find((uid) => uid !== senderUid) ?? null;
}

// ── Helper: get user display name ─────────────────────────────────────────

async function getDisplayName(uid) {
  if (!uid) return 'Your partner';
  const doc = await db.collection('users').doc(uid).get();
  return doc.exists ? (doc.data().displayName?.split(' ')[0] ?? 'Your partner') : 'Your partner';
}

// ── 1. Chat message notification ──────────────────────────────────────────
// Triggers on every new message in couples/{coupleId}/messages/{msgId}

exports.onNewMessage = onDocumentCreated(
  'couples/{coupleId}/messages/{msgId}',
  async (event) => {
    const data = event.data.data();
    const { coupleId } = event.params;

    const senderUid = data.senderUid;
    const type = data.type ?? 'text';

    // Skip snaps sent to the hat (handled separately) and system messages
    if (data.isSnap) return;

    const partnerUid = await getPartnerUid(coupleId, senderUid);
    if (!partnerUid) return;

    const [token, senderName] = await Promise.all([
      getToken(partnerUid),
      getDisplayName(senderUid),
    ]);

    let body;
    if (type === 'image') body = `${senderName} sent a photo 📷`;
    else if (type === 'video') body = `${senderName} sent a video 🎥`;
    else body = data.text ?? `${senderName} sent a message`;

    await sendNotification(token, {
      title: senderName,
      body,
      data: {
        type: 'message',
        coupleId,
        msgId: event.params.msgId,
        route: '/chat',
      },
    });
  }
);

// ── 2. Thinking of You / signal notification ───────────────────────────────
// Triggers on couples/{coupleId}/signals/{signalId}

exports.onNewSignal = onDocumentCreated(
  'couples/{coupleId}/signals/{signalId}',
  async (event) => {
    const data = event.data.data();
    const { coupleId } = event.params;

    const senderUid = data.fromUid;
    const toUid = data.toUid;
    if (!toUid) return;

    const [token, senderName] = await Promise.all([
      getToken(toUid),
      getDisplayName(senderUid),
    ]);

    const signalType = data.type ?? 'thinkingOfYou';
    let title, body;

    if (signalType === 'goodMorning') {
      title = `☀️ Good morning from ${senderName}`;
      body = 'They wished you a beautiful morning ♡';
    } else if (signalType === 'goodNight') {
      title = `🌙 Good night from ${senderName}`;
      body = 'Sweet dreams — they're thinking of you ♡';
    } else if (signalType === 'gratitude') {
      title = `🙏 ${senderName} is grateful for you`;
      body = 'They wanted you to know ♡';
    } else {
      title = `♡ ${senderName} is thinking of you`;
      body = data.message ?? 'A little love from your person ♡';
    }

    await sendNotification(token, {
      title,
      body,
      data: {
        type: 'signal',
        coupleId,
        signalType,
        route: '/room',
      },
    });
  }
);

// ── 3. Mood change notification ────────────────────────────────────────────
// Triggers on couples/{coupleId}/moods/{uid}

exports.onMoodChange = onDocumentWritten(
  'couples/{coupleId}/moods/{uid}',
  async (event) => {
    const after = event.data.after;
    if (!after.exists) return;

    const data = after.data();
    const { coupleId, uid: senderUid } = event.params;

    const partnerUid = await getPartnerUid(coupleId, senderUid);
    if (!partnerUid) return;

    const [token, senderName] = await Promise.all([
      getToken(partnerUid),
      getDisplayName(senderUid),
    ]);

    const moodEmojis = {
      happy: '😊', sad: '😢', anxious: '😰', calm: '😌',
      excited: '🥳', tired: '😴', loved: '🥰', angry: '😤',
    };
    const mood = data.mood ?? 'happy';
    const emoji = moodEmojis[mood] ?? '💭';

    await sendNotification(token, {
      title: `${senderName} is feeling ${mood} ${emoji}`,
      body: 'Check in on them ♡',
      data: {
        type: 'mood',
        coupleId,
        mood,
        route: '/room',
      },
    });
  }
);

// ── 4. Drawing pushed to partner's home-screen widget ─────────────────────
// Triggers on couples/{coupleId}/homeWidget/drawing (singleton doc, replaced
// on every send). Data-only — no `notification` block — so it silently
// wakes the app to redraw the widget instead of popping a system banner.

exports.onNewHomeWidgetDrawing = onDocumentWritten(
  'couples/{coupleId}/homeWidget/drawing',
  async (event) => {
    const after = event.data.after;
    if (!after.exists) return;

    const data = after.data();
    const { coupleId } = event.params;
    const senderUid = data.authorUid;
    const imageUrl = data.imageUrl;
    if (!imageUrl) return;

    const partnerUid = await getPartnerUid(coupleId, senderUid);
    if (!partnerUid) return;

    const token = await getToken(partnerUid);
    if (!token) return;

    try {
      await getMessaging().send({
        token,
        data: {
          type: 'homeWidgetDrawing',
          coupleId,
          imageUrl,
        },
        android: { priority: 'high' },
      });
    } catch (err) {
      console.error('FCM send error:', err.message);
    }
  }
);

// ── 5. Daily Snap Calendar — notify partner when I post today's memory ────
// Triggers on couples/{coupleId}/dailySnaps/{dateKey}. Only notifies when a
// NEW uid entry just appeared and the partner doesn't have one yet for that
// day — avoids re-notifying on every subsequent write to the same doc.

exports.onNewDailySnapEntry = onDocumentWritten(
  'couples/{coupleId}/dailySnaps/{dateKey}',
  async (event) => {
    const after = event.data.after;
    if (!after.exists) return;

    const beforeEntries = event.data.before.exists
      ? (event.data.before.data().entries ?? {})
      : {};
    const afterEntries = after.data().entries ?? {};

    const newUid = Object.keys(afterEntries).find((uid) => !(uid in beforeEntries));
    if (!newUid) return;

    const { coupleId } = event.params;
    const partnerUid = await getPartnerUid(coupleId, newUid);
    if (!partnerUid || afterEntries[partnerUid]) return; // partner already posted today

    const [token, senderName] = await Promise.all([
      getToken(partnerUid),
      getDisplayName(newUid),
    ]);

    await sendNotification(token, {
      title: `${senderName} posted today's memory ♡`,
      body: 'Add yours to complete the day',
      data: {
        type: 'dailySnap',
        coupleId,
        route: '/calendar',
      },
    });
  }
);
