import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/providers.dart';

// The shell is now a transparent passthrough — all navigation lives in the
// spatial Room screen. The only shell responsibility is pinging presence so
// the partner-online indicator stays fresh.
class MainShell extends ConsumerStatefulWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  Timer? _presenceTimer;

  @override
  void initState() {
    super.initState();
    _ping();
    _presenceTimer = Timer.periodic(const Duration(minutes: 3), (_) => _ping());
  }

  void _ping() {
    final coupleId = ref.read(coupleIdProvider);
    if (coupleId != null) {
      ref.read(firestoreServiceProvider).setPresence(coupleId).ignore();
    }
  }

  @override
  void dispose() {
    _presenceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
