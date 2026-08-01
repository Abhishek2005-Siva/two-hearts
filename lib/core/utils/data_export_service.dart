import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';

/// Exports everything the couple has in Firestore to a single JSON file.
///
/// Deliberately a local file the user then shares wherever they want (their
/// own GitHub repo, cloud drive, chat, email) rather than the app pushing
/// anywhere itself: uploading straight to GitHub from the app would mean
/// shipping a GitHub token inside the installed binary, where anyone with
/// the APK could pull it out. Exporting locally keeps the same end result
/// without putting a credential in the app.
///
/// COST: this reads every document in every couple-scoped collection, so
/// it's an expensive one-off. It only ever runs when the user taps Export.
class DataExportService {
  static final _db = FirebaseFirestore.instance;

  /// Every couple-scoped subcollection worth backing up. Live/ephemeral
  /// session state (cinema, listen, scribble strokes) is intentionally
  /// skipped — it's meaningless outside the moment it was created.
  static const _collections = [
    'messages',
    'memories',
    'photoCollections',
    'journal',
    'letters',
    'recipes',
    'books',
    'bucketList',
    'places',
    'dailySnaps',
    'moods',
    'signals',
    'notifications',
    'wildcards',
    'wildcardRequests',
    'homeDecor',
    'roomObjects',
    'notes',
  ];

  /// Firestore types don't survive jsonEncode on their own — convert the
  /// ones the app actually stores into something readable and re-importable.
  static dynamic _encodable(dynamic value) {
    if (value is Timestamp) return value.toDate().toIso8601String();
    if (value is GeoPoint) {
      return {'lat': value.latitude, 'lng': value.longitude};
    }
    if (value is DocumentReference) return value.path;
    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), _encodable(v)));
    }
    if (value is Iterable) return value.map(_encodable).toList();
    return value;
  }

  /// Builds the export and writes it to a temp file, returning that file.
  ///
  /// [onProgress] reports (done, total) collections so the UI can show
  /// real progress rather than a spinner of unknown length.
  static Future<File> exportAll(
    String coupleId, {
    void Function(int done, int total)? onProgress,
  }) async {
    final coupleDoc = await _db.collection('couples').doc(coupleId).get();

    final export = <String, dynamic>{
      'exportedAt': DateTime.now().toIso8601String(),
      'coupleId': coupleId,
      'couple': _encodable(coupleDoc.data() ?? {}),
      'collections': <String, dynamic>{},
    };

    // Pull the members' own user docs too — nicknames, avatars, birthdays
    // live there, not on the couple doc.
    final members = List<String>.from(
        (coupleDoc.data()?['members'] as List?) ?? const []);
    final users = <String, dynamic>{};
    for (final uid in members) {
      final u = await _db.collection('users').doc(uid).get();
      if (u.exists) users[uid] = _encodable(u.data() ?? {});
    }
    export['users'] = users;

    final total = _collections.length;
    for (var i = 0; i < total; i++) {
      final name = _collections[i];
      try {
        final snap = await _db
            .collection('couples')
            .doc(coupleId)
            .collection(name)
            .get();
        export['collections'][name] = [
          for (final doc in snap.docs)
            {'id': doc.id, ...(_encodable(doc.data()) as Map<String, dynamic>)},
        ];
      } catch (e) {
        // One unreadable collection shouldn't sink the whole backup —
        // record what failed and keep going.
        export['collections'][name] = {'error': e.toString()};
      }
      onProgress?.call(i + 1, total);
    }

    final dir = await getTemporaryDirectory();
    final stamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
    final file = File('${dir.path}/two_hearts_backup_$stamp.json');
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(export));
    return file;
  }
}
