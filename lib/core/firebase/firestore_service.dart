import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'models.dart';

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

  Future<String> createInviteCode() async {
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

  // ── Messages ──────────────────────────────────────────────────────────────

  Stream<List<MessageModel>> watchMessages(String coupleId) => _db
      .collection('couples')
      .doc(coupleId)
      .collection('messages')
      .orderBy('sentAt', descending: false)
      .snapshots()
      .map((s) => s.docs.map(MessageModel.fromDoc).toList());

  Future<void> sendMessage(String coupleId, MessageModel msg) => _db
      .collection('couples')
      .doc(coupleId)
      .collection('messages')
      .doc(msg.id)
      .set(msg.toMap());

  Future<void> markMessageRead(String coupleId, String msgId) => _db
      .collection('couples')
      .doc(coupleId)
      .collection('messages')
      .doc(msgId)
      .update({'readByPartner': true});

  Future<void> reactToMessage(String coupleId, String msgId, String emoji) => _db
      .collection('couples')
      .doc(coupleId)
      .collection('messages')
      .doc(msgId)
      .update({'reactionEmoji': emoji});

  // ── Mood ──────────────────────────────────────────────────────────────────

  Future<void> setMood(String coupleId, MoodType mood) => _db
      .collection('couples')
      .doc(coupleId)
      .collection('moods')
      .doc(_uid)
      .set(MoodEntry(uid: _uid, mood: mood, updatedAt: DateTime.now()).toMap());

  Stream<List<MoodEntry>> watchMoods(String coupleId) => _db
      .collection('couples')
      .doc(coupleId)
      .collection('moods')
      .snapshots()
      .map((s) => s.docs.map(MoodEntry.fromDoc).toList());

  // ── Thinking Of You ───────────────────────────────────────────────────────

  Future<void> sendThinkingOfYou(String coupleId, {String? message}) => _db
      .collection('couples')
      .doc(coupleId)
      .collection('signals')
      .add({
        'type': 'thinkingOfYou',
        'fromUid': _uid,
        'message': message,
        'sentAt': FieldValue.serverTimestamp(),
      });

  Stream<QuerySnapshot> watchSignals(String coupleId) => _db
      .collection('couples')
      .doc(coupleId)
      .collection('signals')
      .orderBy('sentAt', descending: true)
      .limit(1)
      .snapshots();

  // ── Letters ───────────────────────────────────────────────────────────────

  Future<void> sendLetter(String coupleId, LetterModel letter) => _db
      .collection('couples')
      .doc(coupleId)
      .collection('letters')
      .doc(letter.id)
      .set(letter.toMap());

  Stream<List<LetterModel>> watchLetters(String coupleId) => _db
      .collection('couples')
      .doc(coupleId)
      .collection('letters')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map(LetterModel.fromDoc).toList());

  Future<void> openLetter(String coupleId, String letterId) => _db
      .collection('couples')
      .doc(coupleId)
      .collection('letters')
      .doc(letterId)
      .update({'opened': true});

  // ── Journal ───────────────────────────────────────────────────────────────

  Future<void> submitJournalEntry(
      String coupleId, String dayId, String entry, String otherUid) async {
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
      });
    }
  }

  Stream<List<JournalDay>> watchJournal(String coupleId) => _db
      .collection('couples')
      .doc(coupleId)
      .collection('journal')
      .orderBy(FieldPath.documentId, descending: true)
      .limit(30)
      .snapshots()
      .map((s) => s.docs.map(JournalDay.fromDoc).toList());

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
  }

  Stream<List<MemoryModel>> watchMemories(String coupleId) => _db
      .collection('couples')
      .doc(coupleId)
      .collection('memories')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map(MemoryModel.fromDoc).toList());

  Future<void> toggleFavoriteMemory(String coupleId, String memoryId, bool fav) =>
      _db
          .collection('couples')
          .doc(coupleId)
          .collection('memories')
          .doc(memoryId)
          .update({'favorite': fav});

  Future<void> requestMemoryDeletion(String coupleId, String memoryId) =>
      _db
          .collection('couples')
          .doc(coupleId)
          .collection('memories')
          .doc(memoryId)
          .update({'deletionRequestedBy': _uid});

  Future<void> cancelMemoryDeletion(String coupleId, String memoryId) =>
      _db
          .collection('couples')
          .doc(coupleId)
          .collection('memories')
          .doc(memoryId)
          .update({'deletionRequestedBy': FieldValue.delete()});

  Future<void> approveMemoryDeletion(String coupleId, String memoryId) =>
      _db
          .collection('couples')
          .doc(coupleId)
          .collection('memories')
          .doc(memoryId)
          .delete();

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

  Future<void> markMessagesRead(String coupleId, List<String> msgIds) async {
    final batch = _db.batch();
    for (final id in msgIds) {
      batch.update(_db.collection('couples').doc(coupleId).collection('messages').doc(id),
          {'readByPartner': true});
    }
    await batch.commit();
  }

  // ── Signals (extended) ────────────────────────────────────────────────────

  Future<void> sendSignal(String coupleId, String type, {String? message}) => _db
      .collection('couples').doc(coupleId).collection('signals').add({
        'type': type,
        'fromUid': _uid,
        if (message != null) 'message': message,
        'sentAt': FieldValue.serverTimestamp(),
      });

  // ── FCM token ─────────────────────────────────────────────────────────────

  Future<void> saveFCMToken(String token) => _db
      .collection('users').doc(_uid)
      .update({'fcmToken': token});

  // ── Truth Jar game ────────────────────────────────────────────────────────

  Future<void> submitTruth(String coupleId, String date, String answer) async {
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

  Future<void> pickGameOption(String coupleId, String date, String option) => _db
      .collection('couples')
      .doc(coupleId)
      .collection('games')
      .doc(date)
      .update({'picks.$_uid': option});

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

  String _todayKey() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  double _randomPos() => (Random().nextDouble() * 4 - 2);

  // ── Presence ──────────────────────────────────────────────────────────────

  Future<void> setPresence(String coupleId) => _db
      .collection('couples').doc(coupleId)
      .update({'presence.$_uid': FieldValue.serverTimestamp()});

  Stream<bool> watchPartnerOnline(String coupleId, String partnerUid) => _db
      .collection('couples').doc(coupleId)
      .snapshots()
      .map((d) {
        final ts = d.data()?['presence']?[partnerUid];
        if (ts == null) return false;
        return DateTime.now().difference((ts as Timestamp).toDate()).inMinutes < 5;
      });

  // ── Snaps / Whispers ──────────────────────────────────────────────────────

  Future<void> deleteMessage(String coupleId, String msgId) => _db
      .collection('couples').doc(coupleId).collection('messages').doc(msgId)
      .delete();

  Future<void> viewSnap(String coupleId, String msgId) => _db
      .collection('couples').doc(coupleId).collection('messages').doc(msgId)
      .update({'snapViewed': true});
}
