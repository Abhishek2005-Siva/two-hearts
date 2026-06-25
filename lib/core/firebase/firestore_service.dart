import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'models.dart';

class FirestoreService {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String get _uid => _auth.currentUser!.uid;

  // ── User ──────────────────────────────────────────────────────────────────

  Future<void> createUser(UserModel user) =>
      _db.collection('users').doc(user.uid).set(user.toMap());

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

    if (couple.members.length >= 2) return null; // already paired
    if (couple.members.contains(_uid)) return null; // same person

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

  Future<void> sendThinkingOfYou(String coupleId) => _db
      .collection('couples')
      .doc(coupleId)
      .collection('signals')
      .add({
        'type': 'thinkingOfYou',
        'fromUid': _uid,
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

  Future<void> toggleFavoriteMemory(
      String coupleId, String memoryId, bool fav) =>
      _db
          .collection('couples')
          .doc(coupleId)
          .collection('memories')
          .doc(memoryId)
          .update({'favorite': fav});

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

  double _randomPos() => (Random().nextDouble() * 4 - 2);
}
