import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'fcm_service.dart';
import 'models.dart';
import '../../features/avatar/avatar_model.dart';

class FirestoreService {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String get _uid {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw StateError('FirestoreService called without authenticated user');
    return uid;
  }

  // ── User ──────────────────────────────────────────────────────────────────

  Future<void> createUser(UserModel user) =>
      _db.collection('users').doc(user.uid).set(user.toMap(), SetOptions(merge: true));

  Future<UserModel?> getUser(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return UserModel.fromDoc(doc);
  }

  Stream<UserModel?> watchUser(String uid) => _db
      .collection('users')
      .doc(uid)
      .snapshots()
      .map((d) => d.exists ? UserModel.fromDoc(d) : null);

  Future<void> updateUser(Map<String, dynamic> data) =>
      _db.collection('users').doc(_uid).update(data);

  Future<void> updateBirthday(DateTime birthday) =>
      _db.collection('users').doc(_uid).update({
        'birthday': Timestamp.fromDate(birthday),
      });

  // ── Couple / Pairing ──────────────────────────────────────────────────────

  String _generateInviteCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rng = Random.secure();
    return List.generate(6, (_) => chars[rng.nextInt(chars.length)]).join();
  }

  /// Returns an invite code for this user — reusing any couple they already
  /// belong to instead of minting a new one on every screen open.
  ///
  /// Returns '' when the user turns out to be already paired: that happens
  /// when the partner redeemed an older code while this user's doc pointed
  /// at a newer orphaned invite. In that case the coupleId is repaired and
  /// the router redirects away from the pairing screen on its own.
  Future<String> createInviteCode() async {
    final mine = await _db
        .collection('couples')
        .where('members', arrayContains: _uid)
        .get();

    QueryDocumentSnapshot<Map<String, dynamic>>? openInvite;
    for (final d in mine.docs) {
      final members = List<String>.from(d.data()['members'] ?? []);
      if (members.length >= 2) {
        // Already paired — heal the pointer and bail out.
        await _db.collection('users').doc(_uid).update({'coupleId': d.id});
        return '';
      }
      if ((d.data()['inviteCode'] as String?)?.isNotEmpty == true) {
        openInvite ??= d;
      }
    }

    if (openInvite != null) {
      // Reuse the existing open invite so the code stays stable across
      // screen opens and the shared code always matches this user's couple.
      await _db
          .collection('users')
          .doc(_uid)
          .update({'coupleId': openInvite.id});
      return openInvite.data()['inviteCode'] as String;
    }

    final code = _generateInviteCode();
    final coupleRef = _db.collection('couples').doc();
    await coupleRef.set({
      'members': [_uid],
      'themeColor': 0xFFE8896A,
      'createdAt': FieldValue.serverTimestamp(),
      'inviteCode': code,
    });
    await _db.collection('users').doc(_uid).update({'coupleId': coupleRef.id});
    return code;
  }

  Future<CoupleModel?> redeemInviteCode(String code) async {
    final snap = await _db
        .collection('couples')
        .where('inviteCode', isEqualTo: code.toUpperCase())
        .limit(1)
        .get();

    if (snap.docs.isEmpty) return null;
    final coupleDoc = snap.docs.first;
    final couple = CoupleModel.fromDoc(coupleDoc);

    if (couple.members.length >= 2) return null;
    if (couple.members.contains(_uid)) return null;

    await coupleDoc.reference.update({
      'members': FieldValue.arrayUnion([_uid]),
      'inviteCode': FieldValue.delete(),
    });
    await _db.collection('users').doc(_uid).update({'coupleId': coupleDoc.id});

    final updated = await coupleDoc.reference.get();
    return CoupleModel.fromDoc(updated);
  }

  Stream<CoupleModel?> watchCouple(String coupleId) => _db
      .collection('couples')
      .doc(coupleId)
      .snapshots()
      .map((d) => d.exists ? CoupleModel.fromDoc(d) : null);

  Future<void> updateCoupleTheme(String coupleId, int colorValue) =>
      _db.collection('couples').doc(coupleId).update({'themeColor': colorValue});

  Future<void> setChatBackground(String coupleId, String backgroundName,
          {String? customUrl}) =>
      _db.collection('couples').doc(coupleId).update({
        'chatBackground': backgroundName,
        'chatBackgroundUrl': ?customUrl,
        if (customUrl == null) 'chatBackgroundUrl': FieldValue.delete(),
      });

  // ── Presence ──────────────────────────────────────────────────────────────

  /// Heartbeat — called every ~30 s while the app is in the foreground, and
  /// on every section (tab) change so the partner sees where we are.
  Future<void> setPresence(String coupleId, {String? section}) => _db
      .collection('couples').doc(coupleId)
      .update({
        'presence.$_uid': FieldValue.serverTimestamp(),
        'sections.$_uid': ?section,
      });

  /// Called when the app goes to background — makes the partner's "online"
  /// dot flip off immediately instead of waiting for the timeout.
  Future<void> clearPresence(String coupleId) => _db
      .collection('couples').doc(coupleId)
      .update({
        'presence.$_uid': FieldValue.delete(),
        'sections.$_uid': FieldValue.delete(),
      });

  /// Online = heartbeat within the last 90 s. Re-evaluates on a local timer
  /// too, so the dot turns off even when no further doc updates arrive.
  Stream<bool> watchPartnerOnline(String coupleId, String partnerUid) {
    Timestamp? last;
    bool compute() =>
        last != null &&
        DateTime.now().difference(last!.toDate()).inSeconds < 90;
    StreamSubscription? sub;
    Timer? timer;
    late final StreamController<bool> ctrl;
    ctrl = StreamController<bool>(
      onListen: () {
        sub = _db
            .collection('couples')
            .doc(coupleId)
            .snapshots()
            .listen((d) {
          last = d.data()?['presence']?[partnerUid] as Timestamp?;
          if (!ctrl.isClosed) ctrl.add(compute());
        });
        timer = Timer.periodic(const Duration(seconds: 20), (_) {
          if (!ctrl.isClosed) ctrl.add(compute());
        });
      },
      onCancel: () {
        sub?.cancel();
        timer?.cancel();
      },
    );
    return ctrl.stream.distinct();
  }

  /// Which section (room / chat / memory / together / you) the partner is
  /// currently in — meaningful only while they're online.
  Stream<String?> watchPartnerSection(String coupleId, String partnerUid) =>
      _db.collection('couples').doc(coupleId).snapshots().map(
          (d) => d.data()?['sections']?[partnerUid] as String?);

  // ── Messages ──────────────────────────────────────────────────────────────

  Stream<List<MessageModel>> watchMessages(String coupleId) => _db
      .collection('couples')
      .doc(coupleId)
      .collection('messages')
      .orderBy('sentAt', descending: false)
      .snapshots()
      .map((s) => s.docs.map(MessageModel.fromDoc).toList());

  Stream<List<MessageModel>> watchSnaps(String coupleId) => _db
      .collection('couples')
      .doc(coupleId)
      .collection('messages')
      .where('isSnap', isEqualTo: true)
      .snapshots()
      .map((s) {
        final list = s.docs.map(MessageModel.fromDoc).toList();
        list.sort((a, b) => b.sentAt.compareTo(a.sentAt));
        return list;
      });

  Stream<List<MessageModel>> watchImageMessages(String coupleId) =>
      watchMessages(coupleId).map(
          (msgs) => msgs.where((m) => m.type == MessageType.image).toList());

  // ── FCM helpers ───────────────────────────────────────────────────────────

  Future<String?> _partnerToken(String coupleId) async {
    final couple = await _db.collection('couples').doc(coupleId).get();
    if (!couple.exists) return null;
    final members = List<String>.from(couple.data()?['members'] ?? []);
    final partnerUid = members.firstWhere((id) => id != _uid, orElse: () => '');
    if (partnerUid.isEmpty) return null;
    final userDoc = await _db.collection('users').doc(partnerUid).get();
    return userDoc.data()?['fcmToken'] as String?;
  }

  /// The name the partner sees in notifications — nickname first ♡
  Future<String> _myFirstName() async {
    final doc = await _db.collection('users').doc(_uid).get();
    final nickname = doc.data()?['nickname'] as String?;
    if (nickname != null && nickname.isNotEmpty) return nickname;
    final full = (doc.data()?['displayName'] as String?) ?? 'Your partner';
    return full.split(' ').first;
  }

  /// Picks a random line so notifications never feel copy-pasted.
  static String _anyOf(List<String> options) =>
      options[Random().nextInt(options.length)];

  /// Pushes a high-priority "incoming video call" notification so the
  /// partner hears about the call even when the app is backgrounded.
  Future<void> notifyIncomingCall(String coupleId, String callId) async {
    final token = await _partnerToken(coupleId);
    final name = await _myFirstName();
    await FcmService.send(
      recipientToken: token,
      title: _anyOf([
        '📹 $name wants to see your face!',
        '📹 Incoming cuteness — $name is calling',
        '📹 Psst… $name misses your voice',
      ]),
      body: _anyOf([
        'Quick, they\'re waiting on the other side ♡',
        'Pick up pick up pick up! 🥺',
        'Your favourite person is on the line ♡',
      ]),
      data: {
        'type': 'videoCall',
        'coupleId': coupleId,
        'callId': callId,
        'route': '/chat',
      },
    );
  }

  // ── Messages ──────────────────────────────────────────────────────────────

  Future<void> sendMessage(String coupleId, MessageModel msg) async {
    await _db
        .collection('couples')
        .doc(coupleId)
        .collection('messages')
        .doc(msg.id)
        .set(msg.toMap());
    final token = await _partnerToken(coupleId);
    final name = await _myFirstName();
    if (msg.isSnap) {
      // Snaps stay secret — tease, never spoil.
      await FcmService.send(
        recipientToken: token,
        title: _anyOf([
          '👻 $name sent a snap!',
          '👀 A snap from $name just landed',
          '📸 $name caught a moment for you',
        ]),
        body: _anyOf([
          'It disappears in 24h — peek quick!',
          'No spoilers… open it before it\'s gone ♡',
          'Blink and you\'ll miss it 👀',
        ]),
        data: {'type': 'message', 'coupleId': coupleId, 'route': '/chat'},
      );
      return;
    }
    final body = switch (msg.type) {
      MessageType.image => _anyOf([
          '📷 A photo, just for your eyes ♡',
          '📷 $name sent you a little something to look at',
          '🖼️ New photo! Bet it makes you smile',
        ]),
      MessageType.video => _anyOf([
          '🎥 $name sent a video — press play ♡',
          '🎬 A tiny movie starring your favourite person',
        ]),
      MessageType.voice => _anyOf([
          '🎙️ $name\'s voice is waiting for you ♡',
          '🎧 A voice note — headphones on!',
        ]),
      _ => msg.content.isNotEmpty ? msg.content : '$name sent a message ♡',
    };
    await FcmService.send(
      recipientToken: token,
      title: name,
      body: body,
      data: {'type': 'message', 'coupleId': coupleId, 'route': '/chat'},
    );
  }

  Future<void> markMessageRead(String coupleId, String msgId) => _db
      .collection('couples')
      .doc(coupleId)
      .collection('messages')
      .doc(msgId)
      .update({'readByPartner': true});

  Future<void> markMessagesRead(String coupleId, List<String> msgIds) async {
    final batch = _db.batch();
    for (final id in msgIds) {
      batch.update(_db.collection('couples').doc(coupleId).collection('messages').doc(id),
          {'readByPartner': true});
    }
    await batch.commit();
  }

  Future<void> reactToMessage(String coupleId, String msgId, String emoji) => _db
      .collection('couples')
      .doc(coupleId)
      .collection('messages')
      .doc(msgId)
      .update({
        'reactionEmoji': emoji.isEmpty ? FieldValue.delete() : emoji,
      });

  Future<void> deleteMessage(String coupleId, String msgId) => _db
      .collection('couples')
      .doc(coupleId)
      .collection('messages')
      .doc(msgId)
      .delete();

  Future<void> viewSnap(String coupleId, String msgId) => _db
      .collection('couples')
      .doc(coupleId)
      .collection('messages')
      .doc(msgId)
      .update({'snapViewed': true});

  // ── Mood ──────────────────────────────────────────────────────────────────

  Future<void> setMood(String coupleId, MoodType mood) async {
    await _db
        .collection('couples')
        .doc(coupleId)
        .collection('moods')
        .doc(_uid)
        .set(MoodEntry(uid: _uid, mood: mood, updatedAt: DateTime.now()).toMap());
    final token = await _partnerToken(coupleId);
    final name = await _myFirstName();
    final emoji = mood.emoji;
    final moodName = mood.name;
    await FcmService.send(
      recipientToken: token,
      title: '$emoji $name is feeling $moodName',
      body: _anyOf([
        'Mood update from your person — go check in ♡',
        'Their little heart just changed colour. Peek! $emoji',
        'A feeling was shared with you. Handle with care ♡',
      ]),
      data: {'type': 'mood', 'coupleId': coupleId, 'route': '/room'},
    );
  }

  Stream<List<MoodEntry>> watchMoods(String coupleId) => _db
      .collection('couples')
      .doc(coupleId)
      .collection('moods')
      .snapshots()
      .map((s) => s.docs.map(MoodEntry.fromDoc).toList());

  // ── Thinking Of You ───────────────────────────────────────────────────────

  Future<void> sendThinkingOfYou(String coupleId,
      {String? message, String? toUid}) async {
    await _db.collection('couples').doc(coupleId).collection('signals').add({
      'type': 'thinkingOfYou',
      'fromUid': _uid,
      'toUid': ?toUid,
      'message': ?message,
      'sentAt': FieldValue.serverTimestamp(),
    });
    final token = toUid != null
        ? ((await _db.collection('users').doc(toUid).get()).data()?['fcmToken'] as String?)
        : await _partnerToken(coupleId);
    final name = await _myFirstName();
    await FcmService.send(
      recipientToken: token,
      title: _anyOf([
        '💭 $name is thinking of you',
        '💘 You just crossed $name\'s mind',
        '🫶 $name sent their heart your way',
      ]),
      body: message ??
          _anyOf([
            'No reason. Just you. ♡',
            'Somewhere out there, someone smiled thinking of you',
            'Tiny love delivery — sign here: ♡',
          ]),
      data: {'type': 'signal', 'coupleId': coupleId, 'route': '/room'},
    );
  }

  /// A "wild idea" gift — lands on the partner's screen as a present box
  /// they unwrap into a letter. Never shown on the sender's side.
  Future<void> sendGift(String coupleId,
      {required String toUid, required String message}) async {
    await _db.collection('couples').doc(coupleId).collection('signals').add({
      'type': 'gift',
      'fromUid': _uid,
      'toUid': toUid,
      'message': message,
      'sentAt': FieldValue.serverTimestamp(),
    });
    final token = (await _db.collection('users').doc(toUid).get())
        .data()?['fcmToken'] as String?;
    final name = await _myFirstName();
    await FcmService.send(
      recipientToken: token,
      title: _anyOf([
        '🎁 $name left you a present!',
        '🎁 Special delivery from $name',
        '🎀 Something from $name is waiting…',
      ]),
      body: _anyOf([
        'Open the app to unwrap it ♡',
        'No peeking — come unwrap it!',
        'A little surprise, wrapped with love',
      ]),
      data: {'type': 'signal', 'coupleId': coupleId, 'route': '/room'},
    );
  }

  Stream<QuerySnapshot> watchSignals(String coupleId) => _db
      .collection('couples')
      .doc(coupleId)
      .collection('signals')
      .orderBy('sentAt', descending: true)
      .limit(1)
      .snapshots();

  Future<void> deleteSignal(String coupleId, String signalId) => _db
      .collection('couples')
      .doc(coupleId)
      .collection('signals')
      .doc(signalId)
      .delete();

  Future<void> sendSignal(String coupleId, String type, {String? message}) async {
    await _db.collection('couples').doc(coupleId).collection('signals').add({
      'type': type,
      'fromUid': _uid,
      'message': ?message,
      'sentAt': FieldValue.serverTimestamp(),
    });
    final token = await _partnerToken(coupleId);
    final name = await _myFirstName();
    final (title, body) = switch (type) {
      'goodMorning' => (
          _anyOf([
            '☀️ Rise and shine, says $name',
            '🌅 $name beat the sun to say hi',
            '☀️ Morning delivery from $name',
          ]),
          _anyOf([
            'First thought of their day? You. ♡',
            'Have the softest, luckiest day today ♡',
            'They\'re starting the day with you in mind',
          ])),
      'goodNight' => (
          _anyOf([
            '🌙 $name says goodnight',
            '✨ Sleepy wishes from $name',
            '🌙 $name tucked a goodnight into your pocket',
          ]),
          _anyOf([
            'Dream of them — they\'ll dream of you ♡',
            'Last thought of their day: you. Always you.',
            'Sweet dreams, from your favourite human ♡',
          ])),
      'gratitude' => (
          _anyOf([
            '🙏 $name is grateful for you',
            '🌸 $name counted their blessings — you\'re #1',
          ]),
          _anyOf([
            'They just wanted you to know ♡',
            'Being loved like this? Lucky you ♡',
          ])),
      _ => (
          '💌 $name is thinking of you',
          message ?? 'A little love from your person ♡'),
    };
    await FcmService.send(
      recipientToken: token,
      title: title,
      body: body,
      data: {'type': 'signal', 'signalType': type, 'coupleId': coupleId, 'route': '/room'},
    );
  }

  // ── Letters ───────────────────────────────────────────────────────────────

  Future<void> sendLetter(String coupleId, LetterModel letter) async {
    await _db
        .collection('couples')
        .doc(coupleId)
        .collection('letters')
        .doc(letter.id)
        .set(letter.toMap());
    final token = await _partnerToken(coupleId);
    final name = await _myFirstName();
    final locked = !letter.isUnlocked;
    await FcmService.send(
      recipientToken: token,
      title: _anyOf([
        '💌 A sealed letter from $name',
        '✉️ $name wrote you something',
        '💌 Mail\'s here! From: $name. To: you.',
      ]),
      body: locked
          ? _anyOf([
              'It\'s locked for now… the wait makes it sweeter 🔐',
              'No peeking yet — it opens when the time is right ⏳',
            ])
          : _anyOf([
              'It\'s ready to open. Go on, we\'ll wait ♡',
              'Words written just for you are waiting 💗',
            ]),
      data: {'type': 'letter', 'coupleId': coupleId, 'route': '/together'},
    );
  }

  // Returns only letters the current user received (not authored) that are unlocked.
  // Locked letters are completely hidden from the receiver.
  Stream<List<LetterModel>> watchLetters(String coupleId, String myUid) => _db
      .collection('couples')
      .doc(coupleId)
      .collection('letters')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map(LetterModel.fromDoc).toList().where((l) {
            // Show only letters where I'm the recipient (not the author)
            final isReceiver = l.receiverId == myUid ||
                (l.receiverId == null && l.authorId != myUid);
            // Only show unlocked letters (locked ones are invisible to receiver)
            return isReceiver && l.isUnlocked;
          }).toList());

  Future<void> openLetter(String coupleId, String letterId) => _db
      .collection('couples')
      .doc(coupleId)
      .collection('letters')
      .doc(letterId)
      .update({'opened': true});

  // ── Journal ───────────────────────────────────────────────────────────────

  Future<void> submitJournalEntry(
      String coupleId, String dayId, String entry, String otherUid,
      {String? title}) async {
    final ref = _db
        .collection('couples')
        .doc(coupleId)
        .collection('journal')
        .doc(dayId);
    final doc = await ref.get();
    if (!doc.exists) {
      await ref.set({
        'uidA': _uid,
        'entryA': entry,
        'uidB': null,
        'entryB': null,
        'bothSubmitted': false,
        'title': ?title,
      });
    } else {
      final d = doc.data() as Map<String, dynamic>;
      final isA = d['uidA'] == _uid;
      final otherField = isA ? 'entryB' : 'entryA';
      final otherUidField = isA ? 'uidB' : 'uidA';
      final myField = isA ? 'entryA' : 'entryB';
      final otherAlreadyIn = d[otherField] != null;
      await ref.update({
        myField: entry,
        otherUidField: otherUid,
        'bothSubmitted': otherAlreadyIn,
        if (title != null && d['title'] == null) 'title': title,
      });
    }
  }

  Future<void> saveJournalEntry(String coupleId, String dayId, String content,
      {String? title}) =>
      _db
          .collection('couples')
          .doc(coupleId)
          .collection('journal')
          .doc(dayId)
          .set({
        'sharedEntry': content,
        'title': title ?? '',
        'lastEditedBy': _uid,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

  Stream<List<JournalDay>> watchJournal(String coupleId) => _db
      .collection('couples')
      .doc(coupleId)
      .collection('journal')
      .snapshots()
      .map((s) {
        final list = s.docs.map(JournalDay.fromDoc).toList();
        list.sort((a, b) => b.id.compareTo(a.id));
        return list;
      });

  // ── Memories ──────────────────────────────────────────────────────────────

  Future<void> addMemory(String coupleId, MemoryModel memory) async {
    await _db
        .collection('couples')
        .doc(coupleId)
        .collection('memories')
        .doc(memory.id)
        .set(memory.toMap());
    await _addRoomObject(coupleId, RoomObject(
      id: 'frame_${memory.id}',
      type: RoomObjectType.photoFrame,
      sourceRef: memory.id,
      position: {'x': _randomPos(), 'y': 0.0, 'z': _randomPos()},
      createdAt: DateTime.now(),
    ));
    // Update collection cover/count
    if (memory.collectionId != null) {
      await _db
          .collection('couples').doc(coupleId)
          .collection('photoCollections').doc(memory.collectionId)
          .update({
            'photoCount': FieldValue.increment(1),
            'coverUrl': memory.imageUrl,
          });
    }
  }

  Future<void> assignToCollection(String coupleId, String memoryId, String? collectionId) => _db
      .collection('couples').doc(coupleId).collection('memories').doc(memoryId)
      .update({'collectionId': collectionId});

  Stream<List<MemoryModel>> watchMemories(String coupleId) => _db
      .collection('couples')
      .doc(coupleId)
      .collection('memories')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map(MemoryModel.fromDoc).toList());

  Stream<List<MemoryModel>> watchCollectionMemories(String coupleId, String collectionId) => _db
      .collection('couples').doc(coupleId).collection('memories')
      .where('collectionId', isEqualTo: collectionId)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map(MemoryModel.fromDoc).toList());

  Future<void> toggleFavoriteMemory(String coupleId, String memoryId, bool fav) =>
      _db.collection('couples').doc(coupleId).collection('memories').doc(memoryId)
          .update({'favorite': fav});

  Future<void> requestMemoryDeletion(String coupleId, String memoryId) =>
      _db.collection('couples').doc(coupleId).collection('memories').doc(memoryId)
          .update({'deletionRequestedBy': _uid});

  Future<void> cancelMemoryDeletion(String coupleId, String memoryId) =>
      _db.collection('couples').doc(coupleId).collection('memories').doc(memoryId)
          .update({'deletionRequestedBy': FieldValue.delete()});

  Future<void> approveMemoryDeletion(String coupleId, String memoryId) =>
      _db.collection('couples').doc(coupleId).collection('memories').doc(memoryId).delete();

  // ── Photo Collections ─────────────────────────────────────────────────────

  Future<PhotoCollection> createCollection(String coupleId, String name) async {
    final ref = _db.collection('couples').doc(coupleId).collection('photoCollections').doc();
    final col = PhotoCollection(
      id: ref.id,
      name: name,
      createdBy: _uid,
      createdAt: DateTime.now(),
    );
    await ref.set(col.toMap());
    return col;
  }

  Stream<List<PhotoCollection>> watchCollections(String coupleId) => _db
      .collection('couples').doc(coupleId).collection('photoCollections')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map(PhotoCollection.fromDoc).toList());

  Future<void> deleteCollection(String coupleId, String collectionId) async {
    // Unassign photos from the collection
    final memories = await _db
        .collection('couples').doc(coupleId).collection('memories')
        .where('collectionId', isEqualTo: collectionId).get();
    final batch = _db.batch();
    for (final doc in memories.docs) {
      batch.update(doc.reference, {'collectionId': FieldValue.delete()});
    }
    batch.delete(_db.collection('couples').doc(coupleId)
        .collection('photoCollections').doc(collectionId));
    await batch.commit();
  }

  // ── Bucket List ───────────────────────────────────────────────────────────

  Future<void> addBucketItem(String coupleId, BucketItem item) => _db
      .collection('couples')
      .doc(coupleId)
      .collection('bucketList')
      .doc(item.id)
      .set(item.toMap());

  Stream<List<BucketItem>> watchBucketList(String coupleId) => _db
      .collection('couples')
      .doc(coupleId)
      .collection('bucketList')
      .orderBy('createdAt', descending: false)
      .snapshots()
      .map((s) => s.docs.map(BucketItem.fromDoc).toList());

  Future<void> deleteBucketItem(String coupleId, String itemId) => _db
      .collection('couples')
      .doc(coupleId)
      .collection('bucketList')
      .doc(itemId)
      .delete();

  Future<void> updateBucketStatus(
      String coupleId, String itemId, BucketStatus status) async {
    await _db
        .collection('couples')
        .doc(coupleId)
        .collection('bucketList')
        .doc(itemId)
        .update({'status': status.name});
    if (status == BucketStatus.done) {
      await _addRoomObject(coupleId, RoomObject(
        id: 'trophy_$itemId',
        type: RoomObjectType.bucketTrophy,
        sourceRef: itemId,
        position: {'x': _randomPos(), 'y': 0.0, 'z': _randomPos()},
        createdAt: DateTime.now(),
      ));
    }
  }

  // ── Room Objects ──────────────────────────────────────────────────────────

  Future<void> _addRoomObject(String coupleId, RoomObject obj) => _db
      .collection('couples')
      .doc(coupleId)
      .collection('roomObjects')
      .doc(obj.id)
      .set(obj.toMap());

  Stream<List<RoomObject>> watchRoomObjects(String coupleId) => _db
      .collection('couples')
      .doc(coupleId)
      .collection('roomObjects')
      .snapshots()
      .map((s) => s.docs.map(RoomObject.fromDoc).toList());

  // ── Typing indicator ─────────────────────────────────────────────────────

  Future<void> setTyping(String coupleId, bool typing) => _db
      .collection('couples').doc(coupleId)
      .update({'typing.$_uid': typing ? Timestamp.now() : FieldValue.delete()});

  Stream<bool> watchPartnerTyping(String coupleId, String partnerUid) => _db
      .collection('couples').doc(coupleId)
      .snapshots()
      .map((d) {
        final ts = d.data()?['typing']?[partnerUid];
        if (ts == null) return false;
        final t = (ts as Timestamp).toDate();
        return DateTime.now().difference(t).inSeconds < 8;
      });

  // ── Game start notifications ──────────────────────────────────────────────
  // Whenever one side makes the first move in a game, the partner gets a
  // nudge. Cooldown per game so repeated taps (or the kiss heartbeat)
  // don't spam their phone.

  static final Map<String, DateTime> _lastGameNotify = {};

  Future<void> notifyGameStart(String coupleId, String game) async {
    final now = DateTime.now();
    final key = '$coupleId/$game';
    final last = _lastGameNotify[key];
    if (last != null && now.difference(last) < const Duration(minutes: 10)) {
      return;
    }
    _lastGameNotify[key] = now;
    final token = await _partnerToken(coupleId);
    final name = await _myFirstName();
    final (title, body) = switch (game) {
      'wyr' => (
          '🎯 $name made their pick!',
          _anyOf([
            'Would You Rather is waiting — what do YOU choose?',
            'Answer today\'s question and see if you match ♡',
          ])
        ),
      'truth' => (
          '🫙 $name dropped a truth in the jar',
          _anyOf([
            'Add yours to unlock what they wrote 👀',
            'One secret in, one to go — your move!',
          ])
        ),
      'scribble' => (
          '🎨 $name is drawing something for you',
          _anyOf([
            'Come watch the masterpiece and guess it!',
            'Live art in progress — can you tell what it is?',
          ])
        ),
      'rps' => (
          '✊ $name threw down a challenge!',
          _anyOf([
            'Rock, paper, scissors — settle it right now',
            'They\'ve locked in. Don\'t leave them hanging ✋✌️',
          ])
        ),
      'kiss' => (
          '💋 $name is holding the kiss heart…',
          _anyOf([
            'Hold it together and feel the buzz 💞',
            'Quick — they\'re waiting for your thumb!',
          ])
        ),
      'guessMe' => (
          '💘 $name answered Guess Me',
          _anyOf([
            'Can you read their mind? Lock in your guess!',
            'They think they know you… prove them right ♡',
          ])
        ),
      _ => ('🎮 $name started a game!', 'Come play together ♡'),
    };
    await FcmService.send(
      recipientToken: token,
      title: title,
      body: body,
      data: {'type': 'game', 'coupleId': coupleId, 'route': '/games'},
    );
  }

  // ── Truth Jar game ────────────────────────────────────────────────────────

  Future<void> submitTruth(String coupleId, String date, String answer) async {
    notifyGameStart(coupleId, 'truth').ignore();
    final ref = _db.collection('couples').doc(coupleId).collection('truths').doc(date);
    final doc = await ref.get();
    if (!doc.exists) {
      await ref.set({_uid: answer});
    } else {
      await ref.update({_uid: answer});
    }
  }

  Stream<Map<String, String>> watchTodayTruths(String coupleId) {
    final today = _todayKey();
    return _db.collection('couples').doc(coupleId).collection('truths').doc(today)
        .snapshots()
        .map((d) {
          if (!d.exists) return {};
          return Map<String, String>.from(
            (d.data() as Map<String, dynamic>).map((k, v) => MapEntry(k, v as String)));
        });
  }

  // ── Date Wheel ────────────────────────────────────────────────────────────

  Future<void> setDateWheelResult(String coupleId, String weekKey, int index) => _db
      .collection('couples').doc(coupleId).collection('dateWheel').doc(weekKey)
      .set({'index': index, 'chosenAt': FieldValue.serverTimestamp()});

  Stream<int?> watchDateWheelResult(String coupleId) {
    final now = DateTime.now();
    final weekKey = '${now.year}-W${_weekOfYear(now)}';
    return _db.collection('couples').doc(coupleId).collection('dateWheel').doc(weekKey)
        .snapshots()
        .map((d) => d.exists ? (d.data() as Map)['index'] as int? : null);
  }

  int _weekOfYear(DateTime date) {
    final startOfYear = DateTime(date.year, 1, 1);
    return ((date.difference(startOfYear).inDays) / 7).ceil();
  }

  String get currentWeekKey {
    final now = DateTime.now();
    return '${now.year}-W${_weekOfYear(now)}';
  }

  // ── Compatibility score ───────────────────────────────────────────────────

  Future<Map<String, int>> getCompatibilityStats(String coupleId) async {
    final snap = await _db.collection('couples').doc(coupleId).collection('games').get();
    int total = 0, matched = 0;
    for (final doc in snap.docs) {
      final picks = (doc.data()['picks'] as Map<String, dynamic>?) ?? {};
      if (picks.length >= 2) {
        total++;
        if (picks.values.toSet().length == 1) matched++;
      }
    }
    return {'total': total, 'matched': matched};
  }

  // ── Games (Would You Rather) ──────────────────────────────────────────────

  Future<void> setTodayGame(String coupleId, GameRound game) => _db
      .collection('couples')
      .doc(coupleId)
      .collection('games')
      .doc(game.date)
      .set(game.toMap());

  Future<void> pickGameOption(String coupleId, String date, String option) {
    notifyGameStart(coupleId, 'wyr').ignore();
    return _db
        .collection('couples')
        .doc(coupleId)
        .collection('games')
        .doc(date)
        .update({'picks.$_uid': option});
  }

  Stream<GameRound?> watchTodayGame(String coupleId) {
    final today = _todayKey();
    return _db
        .collection('couples')
        .doc(coupleId)
        .collection('games')
        .doc(today)
        .snapshots()
        .map((d) => d.exists ? GameRound.fromDoc(d) : null);
  }

  // ── Scribble game ─────────────────────────────────────────────────────────

  Stream<Map<String, dynamic>?> watchScribble(String coupleId) {
    final key = _todayKey();
    return _db.collection('couples').doc(coupleId)
        .collection('scribble').doc(key)
        .snapshots()
        .map((d) => d.exists ? d.data() : null);
  }

  Future<void> startScribble(String coupleId, String word, String drawerId) {
    notifyGameStart(coupleId, 'scribble').ignore();
    final key = _todayKey();
    return _db.collection('couples').doc(coupleId)
        .collection('scribble').doc(key)
        .set({
          'word': word,
          'drawerId': drawerId,
          'strokes': [],
          'guesses': [],
          'status': 'drawing',
          'startedAt': FieldValue.serverTimestamp(),
        });
  }

  Future<void> addScribbleStroke(
      String coupleId, List<Map<String, double>> pts, String color, double width) {
    final key = _todayKey();
    return _db.collection('couples').doc(coupleId)
        .collection('scribble').doc(key)
        .update({
          'strokes': FieldValue.arrayUnion([{
            'pts': pts.map((p) => {'x': p['x'], 'y': p['y']}).toList(),
            'color': color,
            'width': width,
            'by': _uid,
          }]),
        });
  }

  Future<void> clearScribbleCanvas(String coupleId) {
    final key = _todayKey();
    return _db.collection('couples').doc(coupleId)
        .collection('scribble').doc(key)
        .update({'strokes': []});
  }

  Future<void> submitScribbleGuess(String coupleId, String guess) async {
    final key = _todayKey();
    final ref = _db.collection('couples').doc(coupleId).collection('scribble').doc(key);
    final doc = await ref.get();
    if (!doc.exists) return;
    final data = doc.data()!;
    final word = (data['word'] as String? ?? '').toLowerCase().trim();
    final correct = guess.toLowerCase().trim() == word;
    await ref.update({
      'guesses': FieldValue.arrayUnion([{
        'uid': _uid,
        'guess': guess,
        'correct': correct,
        'time': Timestamp.now(),
      }]),
      if (correct) 'status': 'correct',
    });
  }

  Future<void> resetScribble(String coupleId) {
    final key = _todayKey();
    return _db.collection('couples').doc(coupleId)
        .collection('scribble').doc(key)
        .delete();
  }

  // ── Rock Paper Scissors ───────────────────────────────────────────────────

  DocumentReference<Map<String, dynamic>> _rpsRef(String coupleId) =>
      _db.collection('couples').doc(coupleId).collection('rps').doc('current');

  Stream<Map<String, dynamic>?> watchRps(String coupleId) =>
      _rpsRef(coupleId).snapshots().map((d) => d.exists ? d.data() : null);

  Future<void> pickRps(String coupleId, String choice) {
    notifyGameStart(coupleId, 'rps').ignore();
    // Nested map + merge — dotted keys inside set() are NOT treated as
    // paths (that only works in update()), so 'picks.$uid' never landed
    // where the UI reads it.
    return _rpsRef(coupleId).set({
      'picks': {_uid: choice}
    }, SetOptions(merge: true));
  }

  /// Applies the round result to the scores and clears picks for the next
  /// round. Safe to call from either side — runs in a transaction.
  Future<void> nextRpsRound(String coupleId) =>
      _db.runTransaction((tx) async {
        final snap = await tx.get(_rpsRef(coupleId));
        final data = snap.data() ?? {};
        final picks = Map<String, String>.from(data['picks'] ?? {});
        if (picks.length < 2) return; // already advanced by the partner
        final scores = Map<String, int>.from(data['scores'] ?? {});
        const beats = {'rock': 'scissors', 'paper': 'rock', 'scissors': 'paper'};
        final uids = picks.keys.toList();
        final a = uids[0], b = uids[1];
        if (picks[a] != picks[b]) {
          final winner = beats[picks[a]] == picks[b] ? a : b;
          scores[winner] = (scores[winner] ?? 0) + 1;
        }
        tx.set(_rpsRef(coupleId), {
          'picks': {},
          'scores': scores,
          'round': (data['round'] ?? 1) + 1,
        });
      });

  Future<void> resetRps(String coupleId) => _rpsRef(coupleId).delete();

  // ── Thumb Kiss (touch the same spot, feel the buzz) ───────────────────────

  DocumentReference<Map<String, dynamic>> _touchRef(String coupleId) =>
      _db.collection('couples').doc(coupleId).collection('rps').doc('touch');

  Stream<Map<String, dynamic>?> watchTouch(String coupleId) =>
      _touchRef(coupleId).snapshots().map((d) => d.exists ? d.data() : null);

  /// Heartbeat while the user is holding their thumb on the kiss pad.
  Future<void> setTouching(String coupleId, bool touching) {
    // The 10-min cooldown inside notifyGameStart absorbs the 2 s heartbeat.
    if (touching) notifyGameStart(coupleId, 'kiss').ignore();
    return _touchRef(coupleId).set(
      {'touch_$_uid': touching ? Timestamp.now() : null},
      SetOptions(merge: true),
    );
  }

  // ── Guess Me (how well do you know each other?) ───────────────────────────

  DocumentReference<Map<String, dynamic>> _guessMeRef(String coupleId) => _db
      .collection('couples')
      .doc(coupleId)
      .collection('guessMe')
      .doc(_todayKey());

  Stream<Map<String, dynamic>?> watchGuessMe(String coupleId) =>
      _guessMeRef(coupleId).snapshots().map((d) => d.exists ? d.data() : null);

  /// Each partner submits their own truth and a guess about the other.
  Future<void> submitGuessMe(
      String coupleId, String selfAnswer, String guess) {
    notifyGameStart(coupleId, 'guessMe').ignore();
    return _guessMeRef(coupleId).set({
      'self': {_uid: selfAnswer},
      'guess': {_uid: guess},
    }, SetOptions(merge: true));
  }

  // ── Places ────────────────────────────────────────────────────────────────

  Stream<List<PlacePin>> watchPlaces(String coupleId) => _db
      .collection('couples')
      .doc(coupleId)
      .collection('places')
      .orderBy('createdAt', descending: false)
      .snapshots()
      .map((s) => s.docs.map(PlacePin.fromDoc).toList());

  Future<void> addPlace(String coupleId, PlacePin place) => _db
      .collection('couples')
      .doc(coupleId)
      .collection('places')
      .doc(place.id)
      .set(place.toMap());

  Future<void> deletePlace(String coupleId, String placeId) => _db
      .collection('couples')
      .doc(coupleId)
      .collection('places')
      .doc(placeId)
      .delete();

  Future<void> toggleVisited(String coupleId, String placeId, bool visited) => _db
      .collection('couples')
      .doc(coupleId)
      .collection('places')
      .doc(placeId)
      .update({'visited': visited});

  // ── Books ─────────────────────────────────────────────────────────────────

  Stream<List<BookWish>> watchBooks(String coupleId) => _db
      .collection('couples')
      .doc(coupleId)
      .collection('books')
      .orderBy('addedAt', descending: false)
      .snapshots()
      .map((s) => s.docs.map(BookWish.fromDoc).toList());

  Future<void> addBook(String coupleId, BookWish book) => _db
      .collection('couples')
      .doc(coupleId)
      .collection('books')
      .doc(book.id)
      .set(book.toMap());

  Future<void> deleteBook(String coupleId, String bookId) => _db
      .collection('couples')
      .doc(coupleId)
      .collection('books')
      .doc(bookId)
      .delete();

  Future<void> toggleRead(String coupleId, String bookId, bool read) => _db
      .collection('couples')
      .doc(coupleId)
      .collection('books')
      .doc(bookId)
      .update({'read': read});

  Stream<BookWish?> watchBook(String coupleId, String bookId) => _db
      .collection('couples')
      .doc(coupleId)
      .collection('books')
      .doc(bookId)
      .snapshots()
      .map((d) => d.exists ? BookWish.fromDoc(d) : null);

  /// Saves the current user's reading position on the book doc.
  Future<void> updateBookProgress(
          String coupleId, String bookId, int page, int totalPages) =>
      _db
          .collection('couples')
          .doc(coupleId)
          .collection('books')
          .doc(bookId)
          .update({
        'progress.$_uid': BookProgress(
          page: page,
          totalPages: totalPages,
          updatedAt: DateTime.now(),
        ).toMap(),
      });

  // ── Book page notes ───────────────────────────────────────────────────────

  Stream<List<BookNote>> watchBookNotes(String coupleId, String bookId) => _db
      .collection('couples')
      .doc(coupleId)
      .collection('books')
      .doc(bookId)
      .collection('notes')
      .orderBy('createdAt', descending: false)
      .snapshots()
      .map((s) => s.docs.map(BookNote.fromDoc).toList());

  Future<void> addBookNote(String coupleId, String bookId, BookNote note) => _db
      .collection('couples')
      .doc(coupleId)
      .collection('books')
      .doc(bookId)
      .collection('notes')
      .doc(note.id)
      .set(note.toMap());

  Future<void> deleteBookNote(String coupleId, String bookId, String noteId) =>
      _db
          .collection('couples')
          .doc(coupleId)
          .collection('books')
          .doc(bookId)
          .collection('notes')
          .doc(noteId)
          .delete();

  // ── FCM token ─────────────────────────────────────────────────────────────

  Future<void> saveFCMToken(String token) => _db
      .collection('users').doc(_uid)
      .update({'fcmToken': token});

  Future<String?> getEmailByUsername(String username) async {
    final q = await _db.collection('users').where('username', isEqualTo: username).limit(1).get();
    if (q.docs.isEmpty) return null;
    return q.docs.first.data()['email'] as String?;
  }

  // ── Cinema (Watch Together) ───────────────────────────────────────────────

  DocumentReference<Map<String, dynamic>> _cinemaDoc(String coupleId) =>
      _db.collection('couples').doc(coupleId).collection('cinema').doc('session');

  Stream<Map<String, dynamic>?> watchCinemaSession(String coupleId) =>
      _cinemaDoc(coupleId).snapshots().map((s) => s.data());

  Future<void> startCinemaSession(
      String coupleId, String videoUrl, String title) async {
    await _cinemaDoc(coupleId).set({
      'videoUrl': videoUrl,
      'title': title,
      'startedBy': _uid,
      'isPlaying': false,
      'positionMs': 0,
      'updatedBy': _uid,
      'updatedAt': FieldValue.serverTimestamp(),
      'startedAt': FieldValue.serverTimestamp(),
      'watching': {_uid: Timestamp.now()},
    });
    final token = await _partnerToken(coupleId);
    final name = await _myFirstName();
    await FcmService.send(
      recipientToken: token,
      title: _anyOf([
        '🍿 $name is saving you a seat',
        '🎬 Movie night! $name pressed play',
        '🍿 Popcorn\'s (virtually) ready — $name is waiting',
      ]),
      body: title.isEmpty
          ? _anyOf([
              'Come watch together, same second, same scene ♡',
              'Best seat in the house is next to them 🎟️',
            ])
          : 'Now showing: $title — hurry in! 🎟️',
      data: {'type': 'cinema', 'coupleId': coupleId, 'route': '/cinema'},
    );
  }

  /// Nudges the partner that a live screen share is starting, so the
  /// incoming prompt fires even if their app is backgrounded.
  Future<void> notifyScreenShare(String coupleId) async {
    final token = await _partnerToken(coupleId);
    final name = await _myFirstName();
    await FcmService.send(
      recipientToken: token,
      title: _anyOf([
        '🖥️ $name is sharing their screen',
        '🍿 $name wants to watch together',
        '🖥️ Come see what $name is showing you',
      ]),
      body: 'Open the app to watch live ♡',
      data: {'type': 'cinema', 'coupleId': coupleId, 'route': '/cinema'},
    );
  }

  Future<void> updateCinemaPlayback(String coupleId,
          {required bool isPlaying, required int positionMs}) =>
      _cinemaDoc(coupleId).update({
        'isPlaying': isPlaying,
        'positionMs': positionMs,
        'updatedBy': _uid,
        'updatedAt': FieldValue.serverTimestamp(),
      });

  Future<void> cinemaHeartbeat(String coupleId) =>
      _cinemaDoc(coupleId).update({'watching.$_uid': Timestamp.now()});

  Future<void> leaveCinema(String coupleId) =>
      _cinemaDoc(coupleId).update({'watching.$_uid': FieldValue.delete()});

  Future<void> endCinemaSession(String coupleId) async {
    final reactions = await _cinemaDoc(coupleId).collection('reactions').get();
    final batch = _db.batch();
    for (final d in reactions.docs) {
      batch.delete(d.reference);
    }
    batch.delete(_cinemaDoc(coupleId));
    await batch.commit();
  }

  Future<void> sendCinemaReaction(String coupleId, String emoji) =>
      _cinemaDoc(coupleId).collection('reactions').add({
        'emoji': emoji,
        'uid': _uid,
        'sentAt': FieldValue.serverTimestamp(),
      });

  Stream<List<Map<String, dynamic>>> watchCinemaReactions(String coupleId) =>
      _cinemaDoc(coupleId)
          .collection('reactions')
          .orderBy('sentAt', descending: true)
          .limit(12)
          .snapshots()
          .map((s) => s.docs.map((d) => {'id': d.id, ...d.data()}).toList());

  // ── Listen Together (Spotify) ─────────────────────────────────────────────

  DocumentReference<Map<String, dynamic>> _listenDoc(String coupleId) => _db
      .collection('couples')
      .doc(coupleId)
      .collection('listen')
      .doc('session');

  Stream<Map<String, dynamic>?> watchListenSession(String coupleId) =>
      _listenDoc(coupleId).snapshots().map((s) => s.data());

  /// Marks this user as present in the listening room (heartbeat).
  Future<void> joinListen(String coupleId) async {
    await _listenDoc(coupleId).set({
      'present.$_uid': Timestamp.now(),
    }, SetOptions(merge: true));
  }

  Future<void> listenHeartbeat(String coupleId) =>
      _listenDoc(coupleId).set({
        'present.$_uid': Timestamp.now(),
      }, SetOptions(merge: true));

  Future<void> leaveListen(String coupleId) => _listenDoc(coupleId)
      .set({'present.$_uid': FieldValue.delete()}, SetOptions(merge: true));

  /// Sets the shared track and notifies the partner it's time to tune in.
  Future<void> setListenTrack(
    String coupleId, {
    required String uri,
    required String name,
    required String artist,
    required String imageUrl,
    required int durationMs,
    bool notify = true,
  }) async {
    await _listenDoc(coupleId).set({
      'uri': uri,
      'name': name,
      'artist': artist,
      'imageUrl': imageUrl,
      'durationMs': durationMs,
      'isPlaying': true,
      'positionMs': 0,
      'updatedBy': _uid,
      'updatedAt': FieldValue.serverTimestamp(),
      'present.$_uid': Timestamp.now(),
    }, SetOptions(merge: true));
    if (notify) {
      final token = await _partnerToken(coupleId);
      final myName = await _myFirstName();
      await FcmService.send(
        recipientToken: token,
        title: _anyOf([
          '🎧 $myName started a song for you two',
          '🎶 $myName wants to listen together',
          '🎧 Press play with $myName',
        ]),
        body: name.isEmpty ? 'Tap to tune in ♡' : 'Now playing: $name — $artist',
        data: {'type': 'listen', 'coupleId': coupleId, 'route': '/listen'},
      );
    }
  }

  /// Mirrors play/pause + scrub position to the partner.
  Future<void> updateListenPlayback(
    String coupleId, {
    required bool isPlaying,
    required int positionMs,
  }) =>
      _listenDoc(coupleId).set({
        'isPlaying': isPlaying,
        'positionMs': positionMs,
        'updatedBy': _uid,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

  Future<void> endListenSession(String coupleId) =>
      _listenDoc(coupleId).delete();

  // ── Avatar ────────────────────────────────────────────────────────────────

  Future<void> updateAvatarConfig(String uid, AvatarConfig config) =>
      _db.collection('users').doc(uid).update({'avatarConfig': config.toMap()});

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _todayKey() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  double _randomPos() => (Random().nextDouble() * 4 - 2);
}
