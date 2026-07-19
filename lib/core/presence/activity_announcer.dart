import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/providers.dart';

/// Mixin for screens that want to tell the partner (when they're online)
/// what specific thing is happening right now — finer-grained than the
/// tab-level `section` MainShell already tracks (e.g. "Reading The Great
/// Gatsby" rather than just "on the Fun tab"). Call [announceActivity]
/// whenever the label is known or changes (a static label works fine from
/// initState; a dynamic one — e.g. once a book's title loads — can be
/// called again later, it's deduped). Automatically clears on dispose so a
/// stale label never lingers after leaving the screen.
mixin ActivityAnnouncer<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  String? _lastAnnounced;

  void announceActivity(String? label) {
    if (label == _lastAnnounced) return;
    _lastAnnounced = label;
    final coupleId = ref.read(coupleIdProvider);
    if (coupleId == null) return;
    ref.read(firestoreServiceProvider).setActivityLabel(coupleId, label).ignore();
  }

  @override
  void dispose() {
    if (_lastAnnounced != null) {
      final coupleId = ref.read(coupleIdProvider);
      if (coupleId != null) {
        ref.read(firestoreServiceProvider).setActivityLabel(coupleId, null).ignore();
      }
    }
    super.dispose();
  }
}
