import 'package:cloud_firestore/cloud_firestore.dart';

// ──────────────── User ────────────────

class UserModel {
  final String uid;
  final String displayName;
  final String email;
  final String? avatarUrl; // Ready Player Me glTF URL
  final int level;
  final String? coupleId;

  const UserModel({
    required this.uid,
    required this.displayName,
    required this.email,
    this.avatarUrl,
    this.level = 1,
    this.coupleId,
  });

  factory UserModel.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid: doc.id,
      displayName: d['displayName'] ?? '',
      email: d['email'] ?? '',
      avatarUrl: d['avatarUrl'],
      level: d['level'] ?? 1,
      coupleId: d['coupleId'],
    );
  }

  Map<String, dynamic> toMap() => {
        'displayName': displayName,
        'email': email,
        'avatarUrl': avatarUrl,
        'level': level,
        'coupleId': coupleId,
      };

  UserModel copyWith({
    String? displayName,
    String? avatarUrl,
    int? level,
    String? coupleId,
  }) =>
      UserModel(
        uid: uid,
        displayName: displayName ?? this.displayName,
        email: email,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        level: level ?? this.level,
        coupleId: coupleId ?? this.coupleId,
      );
}

// ──────────────── Couple ────────────────

class CoupleModel {
  final String id;
  final List<String> members; // exactly 2 uids
  final int themeColor;
  final DateTime? anniversary;
  final DateTime createdAt;
  final String? inviteCode;

  const CoupleModel({
    required this.id,
    required this.members,
    required this.themeColor,
    this.anniversary,
    required this.createdAt,
    this.inviteCode,
  });

  factory CoupleModel.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return CoupleModel(
      id: doc.id,
      members: List<String>.from(d['members'] ?? []),
      themeColor: d['themeColor'] ?? 0xFFE8896A,
      anniversary: (d['anniversary'] as Timestamp?)?.toDate(),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      inviteCode: d['inviteCode'],
    );
  }

  Map<String, dynamic> toMap() => {
        'members': members,
        'themeColor': themeColor,
        'anniversary': anniversary != null ? Timestamp.fromDate(anniversary!) : null,
        'createdAt': Timestamp.fromDate(createdAt),
        'inviteCode': inviteCode,
      };

  String partnerUid(String myUid) =>
      members.firstWhere((uid) => uid != myUid, orElse: () => '');
}

// ──────────────── Message ────────────────

enum MessageType { text, image, voice, reaction }

class MessageModel {
  final String id;
  final String senderId;
  final String content; // text or storage URL
  final MessageType type;
  final DateTime sentAt;
  final bool readByPartner;
  final String? reactionEmoji;

  const MessageModel({
    required this.id,
    required this.senderId,
    required this.content,
    required this.type,
    required this.sentAt,
    this.readByPartner = false,
    this.reactionEmoji,
  });

  factory MessageModel.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return MessageModel(
      id: doc.id,
      senderId: d['senderId'] ?? '',
      content: d['content'] ?? '',
      type: MessageType.values.byName(d['type'] ?? 'text'),
      sentAt: (d['sentAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      readByPartner: d['readByPartner'] ?? false,
      reactionEmoji: d['reactionEmoji'],
    );
  }

  Map<String, dynamic> toMap() => {
        'senderId': senderId,
        'content': content,
        'type': type.name,
        'sentAt': Timestamp.fromDate(sentAt),
        'readByPartner': readByPartner,
        'reactionEmoji': reactionEmoji,
      };
}

// ──────────────── Mood ────────────────

enum MoodType { happy, excited, tired, sad, angry, stressed, inLove }

extension MoodEmoji on MoodType {
  String get emoji {
    switch (this) {
      case MoodType.happy: return '😊';
      case MoodType.excited: return '🤩';
      case MoodType.tired: return '😴';
      case MoodType.sad: return '😢';
      case MoodType.angry: return '😤';
      case MoodType.stressed: return '😰';
      case MoodType.inLove: return '🥰';
    }
  }

  String get label {
    switch (this) {
      case MoodType.happy: return 'Happy';
      case MoodType.excited: return 'Excited';
      case MoodType.tired: return 'Tired';
      case MoodType.sad: return 'Sad';
      case MoodType.angry: return 'Angry';
      case MoodType.stressed: return 'Stressed';
      case MoodType.inLove: return 'In Love';
    }
  }
}

class MoodEntry {
  final String uid;
  final MoodType mood;
  final DateTime updatedAt;

  const MoodEntry({required this.uid, required this.mood, required this.updatedAt});

  factory MoodEntry.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return MoodEntry(
      uid: doc.id,
      mood: MoodType.values.byName(d['mood'] ?? 'happy'),
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'mood': mood.name,
        'updatedAt': Timestamp.fromDate(updatedAt),
      };
}

// ──────────────── Letter ────────────────

enum LetterUnlockType { tomorrow, nextMonth, birthday, anniversary, openWhenSad, custom }

class LetterModel {
  final String id;
  final String authorId;
  final String title;
  final String body;
  final LetterUnlockType unlockType;
  final DateTime? unlockAt;
  final bool opened;
  final DateTime createdAt;

  const LetterModel({
    required this.id,
    required this.authorId,
    required this.title,
    required this.body,
    required this.unlockType,
    this.unlockAt,
    this.opened = false,
    required this.createdAt,
  });

  factory LetterModel.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return LetterModel(
      id: doc.id,
      authorId: d['authorId'] ?? '',
      title: d['title'] ?? '',
      body: d['body'] ?? '',
      unlockType: LetterUnlockType.values.byName(d['unlockType'] ?? 'tomorrow'),
      unlockAt: (d['unlockAt'] as Timestamp?)?.toDate(),
      opened: d['opened'] ?? false,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  bool get isUnlocked {
    if (unlockAt == null) return true;
    return DateTime.now().isAfter(unlockAt!);
  }

  Map<String, dynamic> toMap() => {
        'authorId': authorId,
        'title': title,
        'body': body,
        'unlockType': unlockType.name,
        'unlockAt': unlockAt != null ? Timestamp.fromDate(unlockAt!) : null,
        'opened': opened,
        'createdAt': Timestamp.fromDate(createdAt),
      };
}

// ──────────────── Journal ────────────────

class JournalDay {
  final String id; // YYYY-MM-DD
  final String? entryA;
  final String? entryB;
  final String? uidA;
  final String? uidB;
  final bool bothSubmitted;

  const JournalDay({
    required this.id,
    this.entryA,
    this.entryB,
    this.uidA,
    this.uidB,
    this.bothSubmitted = false,
  });

  factory JournalDay.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return JournalDay(
      id: doc.id,
      entryA: d['entryA'],
      entryB: d['entryB'],
      uidA: d['uidA'],
      uidB: d['uidB'],
      bothSubmitted: d['bothSubmitted'] ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
        'entryA': entryA,
        'entryB': entryB,
        'uidA': uidA,
        'uidB': uidB,
        'bothSubmitted': bothSubmitted,
      };
}

// ──────────────── Memory ────────────────

class MemoryModel {
  final String id;
  final String uploaderUid;
  final String imageUrl;
  final String? caption;
  final DateTime? takenAt;
  final String? location;
  final bool favorite;
  final DateTime createdAt;

  const MemoryModel({
    required this.id,
    required this.uploaderUid,
    required this.imageUrl,
    this.caption,
    this.takenAt,
    this.location,
    this.favorite = false,
    required this.createdAt,
  });

  factory MemoryModel.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return MemoryModel(
      id: doc.id,
      uploaderUid: d['uploaderUid'] ?? '',
      imageUrl: d['imageUrl'] ?? '',
      caption: d['caption'],
      takenAt: (d['takenAt'] as Timestamp?)?.toDate(),
      location: d['location'],
      favorite: d['favorite'] ?? false,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'uploaderUid': uploaderUid,
        'imageUrl': imageUrl,
        'caption': caption,
        'takenAt': takenAt != null ? Timestamp.fromDate(takenAt!) : null,
        'location': location,
        'favorite': favorite,
        'createdAt': Timestamp.fromDate(createdAt),
      };
}

// ──────────────── Bucket List ────────────────

enum BucketStatus { someday, planned, done }

class BucketItem {
  final String id;
  final String title;
  final String? note;
  final BucketStatus status;
  final String? linkedMemoryId;
  final DateTime createdAt;

  const BucketItem({
    required this.id,
    required this.title,
    this.note,
    this.status = BucketStatus.someday,
    this.linkedMemoryId,
    required this.createdAt,
  });

  factory BucketItem.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return BucketItem(
      id: doc.id,
      title: d['title'] ?? '',
      note: d['note'],
      status: BucketStatus.values.byName(d['status'] ?? 'someday'),
      linkedMemoryId: d['linkedMemoryId'],
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'title': title,
        'note': note,
        'status': status.name,
        'linkedMemoryId': linkedMemoryId,
        'createdAt': Timestamp.fromDate(createdAt),
      };
}

// ──────────────── Room Object ────────────────

enum RoomObjectType { photoFrame, letterEnvelope, journalBook, bucketTrophy, gift }

class RoomObject {
  final String id;
  final RoomObjectType type;
  final String sourceRef; // id of the source document
  final Map<String, double> position; // x, y, z
  final DateTime createdAt;

  const RoomObject({
    required this.id,
    required this.type,
    required this.sourceRef,
    required this.position,
    required this.createdAt,
  });

  factory RoomObject.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    final pos = d['position'] as Map<String, dynamic>? ?? {};
    return RoomObject(
      id: doc.id,
      type: RoomObjectType.values.byName(d['type'] ?? 'photoFrame'),
      sourceRef: d['sourceRef'] ?? '',
      position: {
        'x': (pos['x'] ?? 0.0).toDouble(),
        'y': (pos['y'] ?? 0.0).toDouble(),
        'z': (pos['z'] ?? 0.0).toDouble(),
      },
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'type': type.name,
        'sourceRef': sourceRef,
        'position': position,
        'createdAt': Timestamp.fromDate(createdAt),
      };
}
