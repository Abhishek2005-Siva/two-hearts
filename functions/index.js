const { onDocumentCreated, onDocumentWritten } = require('firebase-functions/v2/firestore');
const { onSchedule } = require('firebase-functions/v2/scheduler');
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
      body = "Sweet dreams — they're thinking of you ♡";
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

// ── 6. Daily Snap Calendar — evening reminder if today's post is missing ──
// Runs once every evening. For each couple, checks today's dailySnaps doc
// and nudges whoever hasn't posted yet. Sends nothing if both already have,
// so a couple who kept their streak never gets pestered.
//
// TIMEZONE: the schedule below runs in Asia/Kolkata; change both the
// timeZone option and the dateKey construction together if that ever needs
// to move, so "today" always means the same day the app's own
// dailySnapDateKey() would produce on the user's device.

exports.remindMissingDailySnap = onSchedule(
  {
    schedule: '0 20 * * *', // 20:00 every day
    timeZone: 'Asia/Kolkata',
  },
  async () => {
    // Local (not UTC) date parts, so the key matches the app's
    // DateFormat('yyyy-MM-dd') on the same calendar day.
    const now = new Date(
      new Date().toLocaleString('en-US', { timeZone: 'Asia/Kolkata' })
    );
    const dateKey = [
      now.getFullYear(),
      String(now.getMonth() + 1).padStart(2, '0'),
      String(now.getDate()).padStart(2, '0'),
    ].join('-');

    const couples = await db.collection('couples').get();

    await Promise.all(
      couples.docs.map(async (coupleDoc) => {
        const coupleId = coupleDoc.id;
        const members = coupleDoc.data().members ?? [];
        if (members.length < 2) return;

        const snapDoc = await db
          .collection('couples')
          .doc(coupleId)
          .collection('dailySnaps')
          .doc(dateKey)
          .get();

        const entries = snapDoc.exists ? (snapDoc.data().entries ?? {}) : {};
        const missing = members.filter((uid) => !(uid in entries));
        if (missing.length === 0) return; // both posted — say nothing

        await Promise.all(
          missing.map(async (uid) => {
            const token = await getToken(uid);
            if (!token) return;
            // If the partner already posted, make that the hook — it's a
            // stronger, and true, nudge than a generic reminder.
            const partnerPosted = missing.length === 1;
            await sendNotification(token, {
              title: partnerPosted
                ? 'They posted today ♡'
                : "Today's memory is still empty",
              body: partnerPosted
                ? 'Add yours to complete the day together'
                : 'Post a snap before the day ends ✨',
              data: {
                type: 'dailySnapReminder',
                coupleId,
                route: '/calendar',
              },
            });
          })
        );
      })
    );
  }
);

// ── 7. "You two haven't talked today" reminder ────────────────────────────
// Runs once daily. For each couple, checks the timestamp of their most
// recent chat message; if it's more than 24h old (or there's never been
// one), nudges BOTH partners — this is the one notification in this file
// that goes to both members instead of just "the other one."

exports.remindNoContactToday = onSchedule(
  {
    schedule: '0 9 * * *', // 09:00 every day
    timeZone: 'Asia/Kolkata',
  },
  async () => {
    const cutoffMs = Date.now() - 24 * 60 * 60 * 1000;
    const couples = await db.collection('couples').get();

    await Promise.all(
      couples.docs.map(async (coupleDoc) => {
        const coupleId = coupleDoc.id;
        const members = coupleDoc.data().members ?? [];
        if (members.length < 2) return;

        const lastMsgSnap = await db
          .collection('couples')
          .doc(coupleId)
          .collection('messages')
          .orderBy('sentAt', 'desc')
          .limit(1)
          .get();

        if (!lastMsgSnap.empty) {
          const lastSentAt = lastMsgSnap.docs[0].data().sentAt;
          const lastMs = lastSentAt?.toMillis?.();
          if (lastMs != null && lastMs > cutoffMs) return; // talked within 24h
        }

        await Promise.all(
          members.map(async (uid) => {
            const token = await getToken(uid);
            if (!token) return;
            await sendNotification(token, {
              title: "You two haven't talked today 💌",
              body: 'Send them something — even just a hi ♡',
              data: {
                type: 'noContactReminder',
                coupleId,
                route: '/chat',
              },
            });
          })
        );
      })
    );
  }
);

// ── 8. Random "remember this?" favorite-memory nudge ──────────────────────
// Runs hourly, but only actually sends once per couple per day, at an hour
// that's picked pseudo-randomly per couple-per-day (a simple string hash of
// coupleId+date, so it's stable across the 24 hourly checks that day but
// different from one day to the next) — real per-second randomness isn't
// something Cloud Scheduler can express, so this is the practical
// approximation: unpredictable which hour, never more than once a day.
// Sends nothing if the couple has no favorited memory yet.

function pseudoRandomHour(seed) {
  let h = 0;
  for (let i = 0; i < seed.length; i++) {
    h = (h * 31 + seed.charCodeAt(i)) >>> 0;
  }
  return 9 + (h % 13); // 9am-9pm, never the middle of the night
}

exports.randomFavoriteMemoryReminder = onSchedule(
  {
    schedule: '0 * * * *', // every hour, on the hour
    timeZone: 'Asia/Kolkata',
  },
  async () => {
    const nowLocal = new Date(
      new Date().toLocaleString('en-US', { timeZone: 'Asia/Kolkata' })
    );
    const dateKey = [
      nowLocal.getFullYear(),
      String(nowLocal.getMonth() + 1).padStart(2, '0'),
      String(nowLocal.getDate()).padStart(2, '0'),
    ].join('-');
    const hour = nowLocal.getHours();

    const couples = await db.collection('couples').get();

    await Promise.all(
      couples.docs.map(async (coupleDoc) => {
        const coupleId = coupleDoc.id;
        const members = coupleDoc.data().members ?? [];
        if (members.length < 2) return;
        if (hour !== pseudoRandomHour(`${coupleId}-${dateKey}`)) return;

        // Dedupe against retries/overlap within the target hour.
        const markerRef = db
          .collection('couples')
          .doc(coupleId)
          .collection('_internal')
          .doc('lastMemoryPing');
        const markerDoc = await markerRef.get();
        if (markerDoc.exists && markerDoc.data().dateKey === dateKey) return;

        const favSnap = await db
          .collection('couples')
          .doc(coupleId)
          .collection('memories')
          .where('favorite', '==', true)
          .get();
        if (favSnap.empty) return;

        const pick = favSnap.docs[Math.floor(Math.random() * favSnap.docs.length)];
        const memory = pick.data();
        await markerRef.set({ dateKey, memoryId: pick.id });

        await Promise.all(
          members.map(async (uid) => {
            const token = await getToken(uid);
            if (!token) return;
            await sendNotification(token, {
              title: '✨ Remember this?',
              body: memory.caption && memory.caption.trim()
                ? memory.caption
                : 'A favorite memory of yours, from a while back ♡',
              data: {
                type: 'memoryReminder',
                coupleId,
                memoryId: pick.id,
                route: `/memory/${pick.id}`,
              },
            });
          })
        );
      })
    );
  }
);
