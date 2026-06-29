import 'package:cloud_firestore/cloud_firestore.dart';
import '../../features/avatar/avatar_model.dart';

// ──────────────── User ────────────────

class UserModel {
  final String uid;
  final String displayName;
  final String email;
  final String? avatarUrl;
  final String? coupleId;
  final DateTime? birthday;
  final String? gender;
  final AvatarConfig? avatarConfig;

  const UserModel({
    required this.uid,
    required this.displayName,
    required this.email,
    this.avatarUrl,
    this.coupleId,
    this.birthday,
    this.gender,
    this.avatarConfig,
  });

  factory UserModel.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    final avatarMap = d['avatarConfig'] as Map<String, dynamic>?;
    return UserModel(
      uid: doc.id,
      displayName: d['displayName'] ?? '',
      email: d['email'] ?? '',
      avatarUrl: d['avatarUrl'],
      coupleId: d['coupleId'],
      birthday: (d['birthday'] as Timestamp?)?.toDate(),
      gender: d['gender'],
      avatarConfig: avatarMap != null ? AvatarConfig.fromMap(avatarMap) : null,
    );
  }

  Map<String, dynamic> toMap() => {
        'displayName': displayName,
        'email': email,
        'avatarUrl': avatarUrl,
        'coupleId': coupleId,
        'birthday': birthday != null ? Timestamp.fromDate(birthday!) : null,
        if (gender != null) 'gender': gender,
        if (avatarConfig != null) 'avatarConfig': avatarConfig!.toMap(),
      };

  UserModel copyWith({
    String? displayName,
    String? avatarUrl,
    String? coupleId,
    DateTime? birthday,
    String? gender,
    AvatarConfig? avatarConfig,
  }) =>
      UserModel(
        uid: uid,
        displayName: displayName ?? this.displayName,
        email: email,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        coupleId: coupleId ?? this.coupleId,
        birthday: birthday ?? this.birthday,
        gender: gender ?? this.gender,
        avatarConfig: avatarConfig ?? this.avatarConfig,
      );

  DateTime? get nextBirthday {
    if (birthday == null) return null;
    final now = DateTime.now();
    var next = DateTime(now.year, birthday!.month, birthday!.day);
    if (!next.isAfter(now)) next = DateTime(now.year + 1, birthday!.month, birthday!.day);
    return next;
  }
}

// ──────────────── Couple ────────────────

class CoupleModel {
  final String id;
  final List<String> members;
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

enum MessageType { text, image, voice, reaction, video }

class MessageModel {
  final String id;
  final String senderId;
  final String content;
  final MessageType type;
  final DateTime sentAt;
  final bool readByPartner;
  final String? reactionEmoji;
  final bool isSnap;
  final bool snapViewed;
  final bool isWhisper;

  const MessageModel({
    required this.id,
    required this.senderId,
    required this.content,
    required this.type,
    required this.sentAt,
    this.readByPartner = false,
    this.reactionEmoji,
    this.isSnap = false,
    this.snapViewed = false,
    this.isWhisper = false,
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
      isSnap: d['isSnap'] ?? false,
      snapViewed: d['snapViewed'] ?? false,
      isWhisper: d['isWhisper'] ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
        'senderId': senderId,
        'content': content,
        'type': type.name,
        'sentAt': Timestamp.fromDate(sentAt),
        'readByPartner': readByPartner,
        if (reactionEmoji != null) 'reactionEmoji': reactionEmoji,
        if (isSnap) 'isSnap': true,
        if (snapViewed) 'snapViewed': true,
        if (isWhisper) 'isWhisper': true,
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

  String get color {
    switch (this) {
      case MoodType.happy: return '#FFD166';
      case MoodType.excited: return '#FF6B8A';
      case MoodType.tired: return '#B8A0D9';
      case MoodType.sad: return '#5B9BD5';
      case MoodType.angry: return '#FF5252';
      case MoodType.stressed: return '#FF8C42';
      case MoodType.inLove: return '#FF6B8A';
    }
  }
}

String moodComboMessage(MoodType a, MoodType b) {
  if (a == b) {
    switch (a) {
      case MoodType.happy: return "You're both glowing today ✨";
      case MoodType.excited: return 'Double the energy! Go do something wild 🎉';
      case MoodType.tired: return 'Movie night, blankets, no plans 🛋️';
      case MoodType.sad: return "Hold each other tight. You'll get through it 💙";
      case MoodType.angry: return 'Mutual chaos mode. Breathe together 🌊';
      case MoodType.stressed: return 'Tag team stress — you handle it better together 💪';
      case MoodType.inLove: return "You're BOTH head over heels. Disgusting. Perfect. 💕";
    }
  }
  final combo = {a, b};
  if (combo.containsAll([MoodType.inLove, MoodType.tired])) return 'Tired but still completely in love 🥰';
  if (combo.containsAll([MoodType.happy, MoodType.sad])) return "One sunshine, one rain — you balance each other 🌦️";
  if (combo.containsAll([MoodType.excited, MoodType.tired])) return 'One is ready to GO, one needs coffee ☕';
  if (combo.containsAll([MoodType.stressed, MoodType.inLove])) return "Stressed but still thinking of them 💌";
  if (combo.containsAll([MoodType.angry, MoodType.inLove])) return 'Annoyed at the world, but not at each other 💪';
  if (combo.containsAll([MoodType.sad, MoodType.inLove])) return 'Love is the comfort on hard days 💙';
  if (combo.containsAll([MoodType.happy, MoodType.tired])) return "One's caffeinated, one's napping — perfect team ☀️";
  return 'Two different worlds, one shared heart 💫';
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
  final String? receiverId;
  final String title;
  final String body;
  final LetterUnlockType unlockType;
  final DateTime? unlockAt;
  final bool opened;
  final DateTime createdAt;

  const LetterModel({
    required this.id,
    required this.authorId,
    this.receiverId,
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
      receiverId: d['receiverId'],
      title: d['title'] ?? '',
      body: d['body'] ?? '',
      unlockType: LetterUnlockType.values.byName(d['unlockType'] ?? 'tomorrow'),
      unlockAt: (d['unlockAt'] as Timestamp?)?.toDate(),
      opened: d['opened'] ?? false,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  bool get isUnlocked {
    if (unlockType == LetterUnlockType.openWhenSad) return true;
    if (unlockAt == null) return true;
    return DateTime.now().isAfter(unlockAt!);
  }

  Map<String, dynamic> toMap() => {
        'authorId': authorId,
        if (receiverId != null) 'receiverId': receiverId,
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
  final String id;
  final String? title;
  final String? entryA;
  final String? entryB;
  final String? uidA;
  final String? uidB;
  final bool bothSubmitted;

  const JournalDay({
    required this.id,
    this.title,
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
      title: d['title'],
      entryA: d['entryA'],
      entryB: d['entryB'],
      uidA: d['uidA'],
      uidB: d['uidB'],
      bothSubmitted: d['bothSubmitted'] ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
        if (title != null) 'title': title,
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
  final String? deletionRequestedBy;
  final String? collectionId;

  const MemoryModel({
    required this.id,
    required this.uploaderUid,
    required this.imageUrl,
    this.caption,
    this.takenAt,
    this.location,
    this.favorite = false,
    required this.createdAt,
    this.deletionRequestedBy,
    this.collectionId,
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
      deletionRequestedBy: d['deletionRequestedBy'],
      collectionId: d['collectionId'],
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
        'deletionRequestedBy': deletionRequestedBy,
        if (collectionId != null) 'collectionId': collectionId,
      };
}

// ──────────────── Photo Collection ────────────────

class PhotoCollection {
  final String id;
  final String name;
  final String? coverUrl;
  final String createdBy;
  final DateTime createdAt;
  final int photoCount;

  const PhotoCollection({
    required this.id,
    required this.name,
    this.coverUrl,
    required this.createdBy,
    required this.createdAt,
    this.photoCount = 0,
  });

  factory PhotoCollection.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return PhotoCollection(
      id: doc.id,
      name: d['name'] ?? '',
      coverUrl: d['coverUrl'],
      createdBy: d['createdBy'] ?? '',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      photoCount: d['photoCount'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        if (coverUrl != null) 'coverUrl': coverUrl,
        'createdBy': createdBy,
        'createdAt': Timestamp.fromDate(createdAt),
        'photoCount': photoCount,
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
  final String? addedBy;

  const BucketItem({
    required this.id,
    required this.title,
    this.note,
    this.status = BucketStatus.someday,
    this.linkedMemoryId,
    required this.createdAt,
    this.addedBy,
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
      addedBy: d['addedBy'],
    );
  }

  Map<String, dynamic> toMap() => {
        'title': title,
        'note': note,
        'status': status.name,
        'linkedMemoryId': linkedMemoryId,
        'createdAt': Timestamp.fromDate(createdAt),
        if (addedBy != null) 'addedBy': addedBy,
      };
}

// ──────────────── Room Object ────────────────

enum RoomObjectType { photoFrame, letterEnvelope, journalBook, bucketTrophy, gift }

class RoomObject {
  final String id;
  final RoomObjectType type;
  final String sourceRef;
  final Map<String, double> position;
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

// ──────────────── Game Round (Would You Rather) ────────────────

class GameRound {
  final String date;
  final int questionIndex;
  final String optionA;
  final String optionB;
  final Map<String, String> picks;

  const GameRound({
    required this.date,
    required this.questionIndex,
    required this.optionA,
    required this.optionB,
    required this.picks,
  });

  bool get bothPicked => picks.length >= 2;
  bool get matched => bothPicked && picks.values.toSet().length == 1;

  factory GameRound.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return GameRound(
      date: doc.id,
      questionIndex: d['questionIndex'] ?? 0,
      optionA: d['optionA'] ?? '',
      optionB: d['optionB'] ?? '',
      picks: Map<String, String>.from(d['picks'] ?? {}),
    );
  }

  Map<String, dynamic> toMap() => {
        'questionIndex': questionIndex,
        'optionA': optionA,
        'optionB': optionB,
        'picks': picks,
      };
}
