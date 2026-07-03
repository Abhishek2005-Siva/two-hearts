import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';
import '../../features/chat/video_call_screen.dart';

class MainShell extends ConsumerStatefulWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  bool _dialogShowing = false;

  static const _tabs = [
    _Tab(icon: Icons.house_rounded, label: 'Home', path: '/room'),
    _Tab(icon: Icons.chat_bubble_rounded, label: 'Chat', path: '/chat'),
    _Tab(icon: Icons.photo_library_rounded, label: 'Memories', path: '/memory'),
    _Tab(icon: Icons.favorite_rounded, label: 'Fun', path: '/together'),
    _Tab(icon: Icons.settings_rounded, label: 'Settings', path: '/you'),
  ];

  int _currentIndex(BuildContext context) {
    final loc = GoRouterState.of(context).matchedLocation;
    for (int i = 0; i < _tabs.length; i++) {
      if (loc.startsWith(_tabs[i].path)) return i;
    }
    return 0;
  }

  void _showIncomingCall(BuildContext context, Map<String, dynamic> call) {
    if (_dialogShowing) return;
    _dialogShowing = true;

    final coupleId = ref.read(coupleIdProvider);
    final partnerName =
        ref.read(partnerUserProvider).valueOrNull?.displayName ?? 'Your Person';

    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (dialogCtx) => _IncomingCallDialog(
        partnerName: partnerName,
        onAccept: () {
          Navigator.of(dialogCtx).pop();
          _dialogShowing = false;
          if (coupleId == null || !mounted) return;
          Navigator.of(context).push(MaterialPageRoute(
            fullscreenDialog: true,
            builder: (_) => VideoCallScreen(
              coupleId: coupleId,
              callId: call['id'] as String,
              isCaller: false,
              partnerName: partnerName,
            ),
          ));
        },
        onDecline: () {
          Navigator.of(dialogCtx).pop();
          _dialogShowing = false;
          if (coupleId == null) return;
          FirebaseFirestore.instance
              .collection('couples')
              .doc(coupleId)
              .collection('calls')
              .doc(call['id'] as String)
              .update({'status': 'declined'}).ignore();
        },
      ),
    ).then((_) => _dialogShowing = false);
  }

  @override
  Widget build(BuildContext context) {
    final accent = ref.watch(accentColorProvider);
    final idx = _currentIndex(context);

    ref.listen<AsyncValue<Map<String, dynamic>?>>(
      incomingCallProvider,
      (_, next) {
        final call = next.valueOrNull;
        if (call != null && !_dialogShowing && mounted) {
          _showIncomingCall(context, call);
        } else if (call == null && _dialogShowing) {
          // Partner cancelled before we answered
          if (mounted && Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          }
          _dialogShowing = false;
        }
      },
    );

    return Scaffold(
      body: widget.child,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.bgMid,
          border: Border(top: BorderSide(color: AppColors.divider, width: 0.5)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(_tabs.length, (i) {
                final selected = idx == i;
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => context.go(_tabs[i].path),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: selected
                          ? accent.withValues(alpha: 0.12)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _tabs[i].icon,
                          color: selected ? accent : AppColors.textMuted,
                          size: 22,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _tabs[i].label,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: selected
                                ? FontWeight.w600
                                : FontWeight.normal,
                            color: selected ? accent : AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Incoming call dialog ──────────────────────────────────────────────────

class _IncomingCallDialog extends StatefulWidget {
  final String partnerName;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const _IncomingCallDialog({
    required this.partnerName,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  State<_IncomingCallDialog> createState() => _IncomingCallDialogState();
}

class _IncomingCallDialogState extends State<_IncomingCallDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
        decoration: BoxDecoration(
          color: const Color(0xFF120509),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white12, width: 0.5),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFD4667A).withValues(alpha: 0.15),
              blurRadius: 40,
              spreadRadius: 8,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ScaleTransition(
              scale: Tween<double>(begin: 0.88, end: 1.0).animate(
                CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
              ),
              child: Container(
                width: 76,
                height: 76,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Color(0xFFE8896A), Color(0xFFD4667A)],
                  ),
                ),
                child: const Icon(Icons.videocam_rounded,
                    color: Colors.white, size: 38),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Incoming video call',
              style: TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                  letterSpacing: 0.8),
            ),
            const SizedBox(height: 6),
            Text(
              widget.partnerName,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _CallBtn(
                  icon: Icons.call_end_rounded,
                  label: 'Decline',
                  color: const Color(0xFFE53935),
                  onTap: widget.onDecline,
                ),
                _CallBtn(
                  icon: Icons.videocam_rounded,
                  label: 'Accept',
                  color: const Color(0xFF43A047),
                  onTap: widget.onAccept,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CallBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _CallBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 8),
          Text(label,
              style: const TextStyle(color: Colors.white60, fontSize: 12)),
        ],
      ),
    );
  }
}

class _Tab {
  final IconData icon;
  final String label;
  final String path;
  const _Tab({required this.icon, required this.label, required this.path});
}
