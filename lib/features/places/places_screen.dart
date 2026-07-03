import 'dart:async';
import 'dart:ui';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:uuid/uuid.dart';
import '../../core/firebase/models.dart';
import '../../core/providers/providers.dart';
import '../../core/theme/app_theme.dart';

const _kEmojis = ['🍜', '🏕️', '🌊', '🎡', '🛍️', '🏛️', '✨'];

// ── Pulse animation for unvisited markers ─────────────────────────────────

class _PulseMarker extends StatefulWidget {
  final Color color;
  final String? emoji;
  final bool visited;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _PulseMarker({
    required this.color,
    this.emoji,
    required this.visited,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  State<_PulseMarker> createState() => _PulseMarkerState();
}

class _PulseMarkerState extends State<_PulseMarker>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _scale = Tween<double>(begin: 1.0, end: 2.5).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
    _opacity = Tween<double>(begin: 0.6, end: 0.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
    if (!widget.visited) _ctrl.repeat();
  }

  @override
  void didUpdateWidget(_PulseMarker old) {
    super.didUpdateWidget(old);
    if (widget.visited && _ctrl.isAnimating) _ctrl.stop();
    if (!widget.visited && !_ctrl.isAnimating) _ctrl.repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pinColor = widget.visited ? const Color(0xFF4CAF50) : AppColors.rose;
    return GestureDetector(
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: SizedBox(
        width: 48,
        height: 48,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (!widget.visited)
              AnimatedBuilder(
                animation: _ctrl,
                builder: (ctx, child) => Transform.scale(
                  scale: _scale.value,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: pinColor.withValues(alpha: _opacity.value),
                    ),
                  ),
                ),
              ),
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: pinColor,
                boxShadow: [
                  BoxShadow(
                    color: pinColor.withValues(alpha: 0.6),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: widget.visited
                    ? const Icon(Icons.check_rounded,
                        color: Colors.white, size: 18)
                    : Text(
                        widget.emoji ?? '📍',
                        style: const TextStyle(fontSize: 16),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Main Screen ───────────────────────────────────────────────────────────

class PlacesScreen extends ConsumerStatefulWidget {
  const PlacesScreen({super.key});

  @override
  ConsumerState<PlacesScreen> createState() => _PlacesScreenState();
}

class _PlacesScreenState extends ConsumerState<PlacesScreen> {
  final _mapController = MapController();
  bool _addingMode = false;

  // Add-pin sheet fields
  final _nameCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  String _selectedEmoji = '✨';

  @override
  void dispose() {
    _nameCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  void _enterAddMode() {
    setState(() {
      _addingMode = true;
    });
    HapticFeedback.mediumImpact();
  }

  void _cancelAddMode() => setState(() => _addingMode = false);

  Future<void> _confirmAdd() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    final coupleId = ref.read(coupleIdProvider);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (coupleId == null || uid == null) return;

    final center = _mapController.camera.center;
    final pin = PlacePin(
      id: const Uuid().v4(),
      name: name,
      note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      lat: center.latitude,
      lng: center.longitude,
      emoji: _selectedEmoji,
      visited: false,
      createdAt: DateTime.now(),
      createdBy: uid,
    );

    _nameCtrl.clear();
    _noteCtrl.clear();
    setState(() {
      _addingMode = false;
      _selectedEmoji = '✨';
    });

    await ref.read(firestoreServiceProvider).addPlace(coupleId, pin);
    HapticFeedback.lightImpact();
  }

  void _showPinDetail(PlacePin pin) {
    _showDetailSheet(pin);
  }

  void _showDetailSheet(PlacePin pin) {
    final coupleId = ref.read(coupleIdProvider);
    if (coupleId == null) return;
    final container = ProviderScope.containerOf(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => UncontrolledProviderScope(
        container: container,
        child: _PinDetailSheet(
          pin: pin,
          coupleId: coupleId,
          onToggleVisited: (v) => ref
              .read(firestoreServiceProvider)
              .toggleVisited(coupleId, pin.id, v),
          onDelete: () => ref
              .read(firestoreServiceProvider)
              .deletePlace(coupleId, pin.id),
        ),
      ),
    );
  }

  void _longPressDelete(PlacePin pin) {
    final coupleId = ref.read(coupleIdProvider);
    if (coupleId == null) return;
    HapticFeedback.heavyImpact();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Remove pin?',
            style: TextStyle(color: AppColors.textPrimary)),
        content: Text('Delete "${pin.name}"?',
            style: const TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref
                  .read(firestoreServiceProvider)
                  .deletePlace(coupleId, pin.id);
            },
            child: const Text('Delete',
                style: TextStyle(color: AppColors.rose)),
          ),
        ],
      ),
    );
  }

  void _flyTo(PlacePin pin) {
    _mapController.move(LatLng(pin.lat, pin.lng), 14.0);
  }

  @override
  Widget build(BuildContext context) {
    final accent = ref.watch(accentColorProvider);
    final placesAsync = ref.watch(placesProvider);
    final places = placesAsync.valueOrNull ?? [];
    final visited = places.where((p) => p.visited).length;
    final toGo = places.length - visited;

    return Scaffold(
      body: Stack(
        children: [
          // ── Map ────────────────────────────────────────────────────────
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: const LatLng(20.0, 0.0),
              initialZoom: 2.5,
              onTap: (tapPos, point) {},
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.twohearts.app',
              ),
              MarkerLayer(
                markers: places.map((pin) {
                  return Marker(
                    point: LatLng(pin.lat, pin.lng),
                    width: 48,
                    height: 48,
                    child: _PulseMarker(
                      color: accent,
                      emoji: pin.emoji,
                      visited: pin.visited,
                      onTap: () => _showPinDetail(pin),
                      onLongPress: () => _longPressDelete(pin),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),

          // ── Crosshair reticle ──────────────────────────────────────────
          if (_addingMode)
            const Center(
              child: _Crosshair(),
            ),

          // ── Top overlay: stats ─────────────────────────────────────────
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 16,
            right: 72,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.12)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Places to Visit',
                              style: TextStyle(
                                color:
                                    Colors.white.withValues(alpha: 0.9),
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              places.isEmpty
                                  ? 'Pin your first spot'
                                  : '$visited visited • $toGo to go',
                              style: TextStyle(
                                color:
                                    Colors.white.withValues(alpha: 0.6),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                              colors: [accent, AppColors.coral]),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${places.length} pins',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ).animate().fadeIn().slideY(begin: -0.3),
          ),

          // ── Back button ────────────────────────────────────────────────
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            right: 16,
            child: ClipOval(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: GestureDetector(
                  onTap: () => Navigator.maybePop(context),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.4),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.12)),
                    ),
                    child: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: Colors.white70, size: 18),
                  ),
                ),
              ),
            ),
          ),

          // ── Bottom: horizontal chip list ───────────────────────────────
          if (places.isNotEmpty && !_addingMode)
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 96,
              left: 0,
              right: 0,
              child: SizedBox(
                height: 44,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: places.length,
                  separatorBuilder: (_, i) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final p = places[i];
                    return GestureDetector(
                      onTap: () => _flyTo(p),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: p.visited
                                ? const Color(0xFF4CAF50).withValues(alpha: 0.6)
                                : accent.withValues(alpha: 0.5),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(p.emoji ?? '📍',
                                style: const TextStyle(fontSize: 14)),
                            const SizedBox(width: 6),
                            Text(
                              p.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

          // ── FAB: add / confirm / cancel ───────────────────────────────
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 24,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_addingMode) ...[
                  FloatingActionButton(
                    heroTag: 'cancel_place',
                    mini: true,
                    backgroundColor: AppColors.bgCard,
                    onPressed: _cancelAddMode,
                    child: const Icon(Icons.close_rounded,
                        color: Colors.white70),
                  ),
                  const SizedBox(height: 10),
                ],
                FloatingActionButton(
                  heroTag: 'add_place',
                  backgroundColor:
                      _addingMode ? const Color(0xFF4CAF50) : accent,
                  onPressed:
                      _addingMode ? _showAddSheet : _enterAddMode,
                  child: Icon(
                    _addingMode ? Icons.check_rounded : Icons.add_rounded,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAddSheet() {
    final container = ProviderScope.containerOf(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => UncontrolledProviderScope(
        container: container,
        child: _AddPinSheet(
          nameCtrl: _nameCtrl,
          noteCtrl: _noteCtrl,
          selectedEmoji: _selectedEmoji,
          onEmojiSelected: (e) => setState(() => _selectedEmoji = e),
          onConfirm: _confirmAdd,
        ),
      ),
    );
  }
}

// ── Crosshair widget ──────────────────────────────────────────────────────

class _Crosshair extends StatelessWidget {
  const _Crosshair();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox(
        width: 60,
        height: 60,
        child: CustomPaint(painter: _CrosshairPainter()),
      ),
    );
  }
}

class _CrosshairPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.rose
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    final cx = size.width / 2;
    final cy = size.height / 2;
    const gap = 8.0;
    const arm = 14.0;
    canvas.drawLine(Offset(cx - arm - gap, cy), Offset(cx - gap, cy), paint);
    canvas.drawLine(Offset(cx + gap, cy), Offset(cx + arm + gap, cy), paint);
    canvas.drawLine(Offset(cx, cy - arm - gap), Offset(cx, cy - gap), paint);
    canvas.drawLine(Offset(cx, cy + gap), Offset(cx, cy + arm + gap), paint);
    canvas.drawCircle(Offset(cx, cy), 4, paint..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(_) => false;
}

// ── Add pin bottom sheet ──────────────────────────────────────────────────

class _AddPinSheet extends StatefulWidget {
  final TextEditingController nameCtrl;
  final TextEditingController noteCtrl;
  final String selectedEmoji;
  final void Function(String) onEmojiSelected;
  final VoidCallback onConfirm;

  const _AddPinSheet({
    required this.nameCtrl,
    required this.noteCtrl,
    required this.selectedEmoji,
    required this.onEmojiSelected,
    required this.onConfirm,
  });

  @override
  State<_AddPinSheet> createState() => _AddPinSheetState();
}

class _AddPinSheetState extends State<_AddPinSheet> {
  late String _emoji;

  @override
  void initState() {
    super.initState();
    _emoji = widget.selectedEmoji;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: EdgeInsets.fromLTRB(
            24, 20, 24, MediaQuery.of(context).padding.bottom + 24),
        decoration: const BoxDecoration(
          color: AppColors.bgMid,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(top: BorderSide(color: AppColors.divider)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text('Pin this spot',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextField(
              controller: widget.nameCtrl,
              autofocus: true,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                hintText: 'Name this place…',
                prefixIcon:
                    Icon(Icons.place_rounded, color: AppColors.rose),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: widget.noteCtrl,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                hintText: 'Add a note (optional)…',
                prefixIcon:
                    Icon(Icons.notes_rounded, color: AppColors.textMuted),
              ),
            ),
            const SizedBox(height: 16),
            Text('Category',
                style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _kEmojis.map((e) {
                final selected = _emoji == e;
                return GestureDetector(
                  onTap: () {
                    setState(() => _emoji = e);
                    widget.onEmojiSelected(e);
                  },
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.rose.withValues(alpha: 0.2)
                          : AppColors.bgCard,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected
                            ? AppColors.rose
                            : AppColors.divider,
                        width: selected ? 1.5 : 0.5,
                      ),
                    ),
                    child: Center(
                        child: Text(e,
                            style: const TextStyle(fontSize: 22))),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            GradientButton(
              label: 'Pin it here',
              onTap: () {
                Navigator.pop(context);
                widget.onConfirm();
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ── Pin detail sheet ──────────────────────────────────────────────────────

class _PinDetailSheet extends ConsumerWidget {
  final PlacePin pin;
  final String coupleId;
  final void Function(bool) onToggleVisited;
  final VoidCallback onDelete;

  const _PinDetailSheet({
    required this.pin,
    required this.coupleId,
    required this.onToggleVisited,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentUserProvider).valueOrNull;
    final partner = ref.watch(partnerUserProvider).valueOrNull;
    final pinnedBy = pin.createdBy == me?.uid
        ? (me?.displayName ?? 'You')
        : (partner?.displayName ?? 'Partner');

    return Container(
      padding: EdgeInsets.fromLTRB(
          24, 20, 24, MediaQuery.of(context).padding.bottom + 24),
      decoration: const BoxDecoration(
        color: AppColors.bgMid,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              if (pin.emoji != null)
                Text(pin.emoji!, style: const TextStyle(fontSize: 36)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(pin.name,
                        style: Theme.of(context).textTheme.titleLarge),
                    Text(
                      'Pinned by $pinnedBy · ${DateFormat('MMM d, yyyy').format(pin.createdAt)}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (pin.note != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.bgCard,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                pin.note!,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    onToggleVisited(!pin.visited);
                    HapticFeedback.lightImpact();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: pin.visited
                          ? const Color(0xFF4CAF50).withValues(alpha: 0.15)
                          : AppColors.bgCard,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: pin.visited
                            ? const Color(0xFF4CAF50)
                            : AppColors.divider,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          pin.visited
                              ? Icons.check_circle_rounded
                              : Icons.radio_button_unchecked_rounded,
                          color: pin.visited
                              ? const Color(0xFF4CAF50)
                              : AppColors.textMuted,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          pin.visited ? 'Visited!' : 'Mark visited',
                          style: TextStyle(
                            color: pin.visited
                                ? const Color(0xFF4CAF50)
                                : AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  onDelete();
                },
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.rose.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: AppColors.rose.withValues(alpha: 0.4)),
                  ),
                  child: const Icon(Icons.delete_outline_rounded,
                      color: AppColors.rose, size: 22),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
