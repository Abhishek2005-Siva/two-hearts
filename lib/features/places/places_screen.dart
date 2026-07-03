import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:uuid/uuid.dart';
import '../../core/firebase/models.dart';
import '../../core/providers/providers.dart';
import '../../core/theme/app_theme.dart';

const _kEmojis = ['🍜', '🏕️', '🌊', '🎡', '🛍️', '🏛️', '✨'];

// ── Colours ──────────────────────────────────────────────────────────────────

const _kGreen = Color(0xFF22C55E);
const _kRose = Color(0xFFF43F5E);

// ── Nominatim search result ───────────────────────────────────────────────────

class _SearchResult {
  final String displayName;
  final double lat;
  final double lon;

  const _SearchResult({
    required this.displayName,
    required this.lat,
    required this.lon,
  });

  factory _SearchResult.fromJson(Map<String, dynamic> json) => _SearchResult(
        displayName: json['display_name'] as String,
        lat: double.parse(json['lat'] as String),
        lon: double.parse(json['lon'] as String),
      );
}

// ── Tear-drop pin painter ─────────────────────────────────────────────────────

class _TearDropPainter extends CustomPainter {
  final Color color;

  const _TearDropPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    // Circle occupies top portion; point at the bottom
    final r = w / 2.0;
    final circleCenter = Offset(w / 2, r);

    final path = Path();
    // Start at bottom tip
    path.moveTo(w / 2, h);
    // Left curve up to circle
    path.quadraticBezierTo(0, h * 0.55, 0, r);
    // Top circle arc
    path.arcToPoint(Offset(w, r), radius: Radius.circular(r), clockwise: false);
    // Right curve down to tip
    path.quadraticBezierTo(w, h * 0.55, w / 2, h);
    path.close();

    canvas.drawShadow(path, color.withValues(alpha: 0.5), 4, false);

    // Fill
    canvas.drawPath(path, Paint()..color = color);

    // White outline
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // Highlight gloss on upper-left of circle
    final glossPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.25)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(circleCenter.dx - r * 0.25, circleCenter.dy - r * 0.25), r * 0.28, glossPaint);
  }

  @override
  bool shouldRepaint(_TearDropPainter old) => old.color != color;
}

// ── Tear-drop pin widget (with optional pulse for unvisited) ──────────────────

class _TearDropPin extends StatefulWidget {
  final bool visited;
  final String? emoji;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _TearDropPin({
    required this.visited,
    this.emoji,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  State<_TearDropPin> createState() => _TearDropPinState();
}

class _TearDropPinState extends State<_TearDropPin>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _scale = Tween<double>(begin: 1.0, end: 2.8).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
    _opacity = Tween<double>(begin: 0.55, end: 0.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
    if (!widget.visited) _ctrl.repeat();
  }

  @override
  void didUpdateWidget(_TearDropPin old) {
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
    const pinW = 28.0;
    const pinH = 40.0;
    const totalW = 56.0;
    const totalH = 60.0;
    final color = widget.visited ? _kGreen : _kRose;

    return GestureDetector(
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: SizedBox(
        width: totalW,
        height: totalH,
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            // Pulse ring behind the pin (unvisited only)
            if (!widget.visited)
              Positioned(
                top: totalH / 2 - pinW / 2,
                left: totalW / 2 - pinW / 2,
                child: AnimatedBuilder(
                  animation: _ctrl,
                  builder: (_, child) => Transform.scale(
                    scale: _scale.value,
                    child: Container(
                      width: pinW,
                      height: pinW,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color.withValues(alpha: _opacity.value),
                      ),
                    ),
                  ),
                ),
              ),
            // Tear-drop pin
            Positioned(
              top: 4,
              left: (totalW - pinW) / 2,
              child: SizedBox(
                width: pinW,
                height: pinH,
                child: CustomPaint(
                  painter: _TearDropPainter(color: color),
                  child: Align(
                    alignment: const Alignment(0, -0.35),
                    child: widget.visited
                        ? const Icon(Icons.check_rounded,
                            color: Colors.white, size: 14)
                        : Text(
                            widget.emoji ?? '📍',
                            style: const TextStyle(fontSize: 12),
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Location dot ─────────────────────────────────────────────────────────────

class _LocationDot extends StatelessWidget {
  const _LocationDot();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 20,
      height: 20,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.blue.withValues(alpha: 0.22),
              border: Border.all(
                  color: Colors.blue.withValues(alpha: 0.3), width: 1),
            ),
          ),
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.blue,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: const [
                BoxShadow(
                    color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Main Screen ───────────────────────────────────────────────────────────────

class PlacesScreen extends ConsumerStatefulWidget {
  const PlacesScreen({super.key});

  @override
  ConsumerState<PlacesScreen> createState() => _PlacesScreenState();
}

class _PlacesScreenState extends ConsumerState<PlacesScreen> {
  final _mapController = MapController();

  // Current location
  LatLng? _currentLocation;

  // Search
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();
  List<_SearchResult> _searchResults = [];
  bool _searchLoading = false;
  Timer? _searchDebounce;

  // Add-pin sheet fields (managed by screen so we can pre-fill coords)
  final _nameCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  String _selectedEmoji = '✨';

  @override
  void dispose() {
    _nameCtrl.dispose();
    _noteCtrl.dispose();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  // ── Long-press → open add sheet immediately ──────────────────────────────

  void _onMapLongPress(TapPosition tapPos, LatLng point) {
    HapticFeedback.mediumImpact();
    _searchResults = [];
    _searchFocus.unfocus();
    setState(() => _searchResults = []);
    _showAddSheet(point);
  }

  // ── Confirm add ──────────────────────────────────────────────────────────

  Future<void> _confirmAdd(LatLng latlng) async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    final coupleId = ref.read(coupleIdProvider);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (coupleId == null || uid == null) return;

    final pin = PlacePin(
      id: const Uuid().v4(),
      name: name,
      note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      lat: latlng.latitude,
      lng: latlng.longitude,
      emoji: _selectedEmoji,
      visited: false,
      createdAt: DateTime.now(),
      createdBy: uid,
    );

    _nameCtrl.clear();
    _noteCtrl.clear();
    setState(() => _selectedEmoji = '✨');

    await ref.read(firestoreServiceProvider).addPlace(coupleId, pin);
    HapticFeedback.lightImpact();
  }

  // ── Detail sheet ─────────────────────────────────────────────────────────

  void _showPinDetail(PlacePin pin) {
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
          onDelete: () =>
              ref.read(firestoreServiceProvider).deletePlace(coupleId, pin.id),
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
                style: TextStyle(color: _kRose)),
          ),
        ],
      ),
    );
  }

  void _flyTo(PlacePin pin) {
    _mapController.move(LatLng(pin.lat, pin.lng), 14.0);
  }

  // ── Location ─────────────────────────────────────────────────────────────

  Future<void> _flyToCurrentLocation() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Location permission is permanently denied. Enable it in app settings.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }
    if (permission == LocationPermission.denied) return;

    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      final loc = LatLng(pos.latitude, pos.longitude);
      if (mounted) setState(() => _currentLocation = loc);
      _mapController.move(loc, 15.0);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not get current location.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // ── Search ───────────────────────────────────────────────────────────────

  void _onSearchChanged(String query) {
    _searchDebounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 500), () {
      _runSearch(query.trim());
    });
  }

  Future<void> _runSearch(String query) async {
    setState(() => _searchLoading = true);
    try {
      final encoded = Uri.encodeQueryComponent(query);
      final uri = Uri.parse(
          'https://nominatim.openstreetmap.org/search?q=$encoded&format=json&limit=5');
      final response = await http.get(
        uri,
        headers: {
          'User-Agent': 'TwoHeartsApp/1.0 (abhishek2005.siva@gmail.com)'
        },
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
        final results = data
            .map((e) => _SearchResult.fromJson(e as Map<String, dynamic>))
            .toList();
        if (mounted) setState(() => _searchResults = results);
      }
    } catch (_) {
      // Silently ignore network errors
    } finally {
      if (mounted) setState(() => _searchLoading = false);
    }
  }

  void _selectSearchResult(_SearchResult result) {
    final loc = LatLng(result.lat, result.lon);
    _mapController.move(loc, 13.0);
    setState(() {
      _searchResults = [];
      _searchCtrl.clear();
    });
    _searchFocus.unfocus();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final placesAsync = ref.watch(placesProvider);
    final places = placesAsync.valueOrNull ?? [];
    final visited = places.where((p) => p.visited).toList();
    final toGo = places.length - visited.length;
    final topPad = MediaQuery.of(context).padding.top;
    final botPad = MediaQuery.of(context).padding.bottom;

    // Love trail: visited pins sorted by createdAt
    final trailPoints = (List<PlacePin>.from(visited)
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt)))
        .map((p) => LatLng(p.lat, p.lng))
        .toList();

    // Header height: topPad + row(~44) + gap(10) + line(2) + gap(10) + search(48) + padding(10+12)
    const searchBarH = 48.0;
    final statsBarBottom = topPad + 146.0;

    return Scaffold(
      body: Stack(
        children: [
          // ── Map ─────────────────────────────────────────────────────────
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: const LatLng(20.0, 0.0),
              initialZoom: 2.5,
              minZoom: 2.0,
              maxZoom: 18.0,
              cameraConstraint: CameraConstraint.unconstrained(),
              onTap: (tapPos, point) {
                if (_searchResults.isNotEmpty) {
                  setState(() => _searchResults = []);
                  _searchFocus.unfocus();
                }
              },
              onLongPress: _onMapLongPress,
            ),
            children: [
              // Satellite imagery base
              TileLayer(
                urlTemplate:
                    'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
                userAgentPackageName: 'com.twohearts.app',
              ),
              // Reference labels overlay
              TileLayer(
                urlTemplate:
                    'https://server.arcgisonline.com/ArcGIS/rest/services/Reference/World_Boundaries_and_Places/MapServer/tile/{z}/{y}/{x}',
                userAgentPackageName: 'com.twohearts.app',
              ),
              // Love trail polyline
              if (trailPoints.length >= 2)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: trailPoints,
                      strokeWidth: 2.5,
                      color: _kRose.withValues(alpha: 0.6),
                      pattern: StrokePattern.dashed(segments: const [12, 6]),
                      strokeCap: StrokeCap.round,
                      strokeJoin: StrokeJoin.round,
                    ),
                  ],
                ),
              // Current location marker
              if (_currentLocation != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _currentLocation!,
                      width: 20,
                      height: 20,
                      child: const _LocationDot(),
                    ),
                  ],
                ),
              // Place pin markers
              MarkerLayer(
                markers: places.map((pin) {
                  return Marker(
                    point: LatLng(pin.lat, pin.lng),
                    width: 56,
                    height: 60,
                    alignment: Alignment.topCenter,
                    child: _TearDropPin(
                      visited: pin.visited,
                      emoji: pin.emoji,
                      onTap: () => _showPinDetail(pin),
                      onLongPress: () => _longPressDelete(pin),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),

          // ── Stats header ─────────────────────────────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                child: Container(
                  padding: EdgeInsets.only(
                      top: topPad + 10, bottom: 12, left: 16, right: 16),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.60),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Back button
                          GestureDetector(
                            onTap: () => Navigator.maybePop(context),
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withValues(alpha: 0.1),
                              ),
                              child: const Icon(Icons.arrow_back_ios_new_rounded,
                                  color: Colors.white70, size: 16),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Title + count
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Destination Wishlist',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  height: 1.1,
                                ),
                              ),
                              Text(
                                '${places.length} spot${places.length == 1 ? '' : 's'} pinned',
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          // Micro stats
                          _MicroStat(
                            icon: '✓',
                            count: visited.length,
                            label: 'visited',
                            color: _kGreen,
                          ),
                          const SizedBox(width: 14),
                          _MicroStat(
                            icon: '♡',
                            count: toGo,
                            label: 'to go',
                            color: _kRose,
                          ),
                        ],
                      ),
                      // Rose gradient line
                      const SizedBox(height: 10),
                      Container(
                        height: 1.5,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              _kRose,
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                      // Search bar inside header
                      const SizedBox(height: 10),
                      Container(
                        height: searchBarH,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(searchBarH / 2),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.15),
                              width: 0.8),
                        ),
                        child: Row(
                          children: [
                            const SizedBox(width: 14),
                            const Icon(Icons.search_rounded,
                                color: _kRose, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: _searchCtrl,
                                focusNode: _searchFocus,
                                onChanged: _onSearchChanged,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Search places…',
                                  hintStyle: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.45),
                                      fontSize: 14),
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                            ),
                            if (_searchLoading)
                              const Padding(
                                padding: EdgeInsets.only(right: 14),
                                child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: _kRose),
                                ),
                              )
                            else if (_searchCtrl.text.isNotEmpty)
                              GestureDetector(
                                onTap: () {
                                  _searchCtrl.clear();
                                  setState(() => _searchResults = []);
                                },
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 14),
                                  child: Icon(Icons.close_rounded,
                                      color: Colors.white.withValues(alpha: 0.5),
                                      size: 18),
                                ),
                              )
                            else
                              const SizedBox(width: 14),
                          ],
                        ),
                      ),
                      const SizedBox(height: 2),
                    ],
                  ),
                ),
              ),
            ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.4, duration: 400.ms),
          ),

          // ── Search dropdown results (below header) ───────────────────────
          if (_searchResults.isNotEmpty)
            Positioned(
              top: statsBarBottom + 4,
              left: 12,
              right: 12,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1C24),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.40),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _searchResults.length,
                  separatorBuilder: (_, i) => Divider(
                      height: 1, color: Colors.white.withValues(alpha: 0.08)),
                  itemBuilder: (_, i) {
                    final r = _searchResults[i];
                    return InkWell(
                      onTap: () => _selectSearchResult(r),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        child: Row(
                          children: [
                            const Icon(Icons.location_on_rounded,
                                color: _kRose, size: 16),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                r.displayName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
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

          // ── Bottom destination cards ─────────────────────────────────────
          if (places.isNotEmpty)
            Positioned(
              bottom: botPad + 90,
              left: 0,
              right: 0,
              child: Container(
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 20,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: SizedBox(
                  height: 80,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: places.length,
                    separatorBuilder: (_, i) => const SizedBox(width: 10),
                    itemBuilder: (_, i) {
                      final p = places[i];
                      return GestureDetector(
                        onTap: () => _flyTo(p),
                        child: Container(
                          width: 160,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            gradient: LinearGradient(
                              colors: [
                                Colors.black.withValues(alpha: 0.72),
                                Colors.black.withValues(alpha: 0.55),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            border: Border(
                              left: BorderSide(
                                color: p.visited ? _kGreen : _kRose,
                                width: 3,
                              ),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: (p.visited ? _kGreen : _kRose)
                                    .withValues(alpha: 0.18),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          child: Row(
                            children: [
                              Text(
                                p.emoji ?? '📍',
                                style: const TextStyle(fontSize: 28),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      p.name,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: (p.visited ? _kGreen : _kRose)
                                            .withValues(alpha: 0.18),
                                        borderRadius:
                                            BorderRadius.circular(6),
                                        border: Border.all(
                                          color: p.visited ? _kGreen : _kRose,
                                          width: 0.5,
                                        ),
                                      ),
                                      child: Text(
                                        p.visited ? 'Visited' : 'To visit',
                                        style: TextStyle(
                                          color: p.visited ? _kGreen : _kRose,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.3, duration: 350.ms),
            ),

          // ── FABs ─────────────────────────────────────────────────────────
          Positioned(
            bottom: botPad + 24,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Location button above + button
                FloatingActionButton.small(
                  heroTag: 'locate_me',
                  backgroundColor: AppColors.bgCard,
                  onPressed: _flyToCurrentLocation,
                  child: const Icon(Icons.my_location_rounded,
                      color: _kRose, size: 20),
                ),
                const SizedBox(height: 10),
                // + button — shows hint snackbar
                FloatingActionButton(
                  heroTag: 'add_place',
                  backgroundColor: _kRose,
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Long press on the map to drop a pin'),
                        behavior: SnackBarBehavior.floating,
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  child: const Icon(Icons.add_rounded,
                      color: Colors.white, size: 26),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAddSheet(LatLng latlng) {
    final container = ProviderScope.containerOf(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => UncontrolledProviderScope(
        container: container,
        child: _AddPinSheet(
          latlng: latlng,
          nameCtrl: _nameCtrl,
          noteCtrl: _noteCtrl,
          selectedEmoji: _selectedEmoji,
          onEmojiSelected: (e) => setState(() => _selectedEmoji = e),
          onConfirm: () => _confirmAdd(latlng),
        ),
      ),
    );
  }
}

// ── Micro stat widget ─────────────────────────────────────────────────────────

class _MicroStat extends StatelessWidget {
  final String icon;
  final int count;
  final String label;
  final Color color;

  const _MicroStat({
    required this.icon,
    required this.count,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$icon $count',
          style: TextStyle(
            color: color,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white38,
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// ── Add pin bottom sheet ──────────────────────────────────────────────────────

class _AddPinSheet extends StatefulWidget {
  final LatLng latlng;
  final TextEditingController nameCtrl;
  final TextEditingController noteCtrl;
  final String selectedEmoji;
  final void Function(String) onEmojiSelected;
  final VoidCallback onConfirm;

  const _AddPinSheet({
    required this.latlng,
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

  String _formatCoord(double val, bool isLat) {
    final dir = isLat ? (val >= 0 ? 'N' : 'S') : (val >= 0 ? 'E' : 'W');
    return '${val.abs().toStringAsFixed(4)}° $dir';
  }

  @override
  Widget build(BuildContext context) {
    final lat = widget.latlng.latitude;
    final lng = widget.latlng.longitude;

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: EdgeInsets.fromLTRB(
            24, 0, 24, MediaQuery.of(context).padding.bottom + 24),
        decoration: const BoxDecoration(
          color: AppColors.bgMid,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(top: BorderSide(color: AppColors.divider)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 8),
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),

            // Minimap preview / GPS readout
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: AppColors.bgCard,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: _kRose.withValues(alpha: 0.3)),
                boxShadow: [
                  BoxShadow(
                    color: _kRose.withValues(alpha: 0.1),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _kRose.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'GPS COORDINATES',
                          style: TextStyle(
                            color: _kRose,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.4,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: _kGreen,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'LOCKED',
                        style: TextStyle(
                          color: _kGreen,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Text('📍 ', style: TextStyle(fontSize: 18)),
                      Expanded(
                        child: Text(
                          '${_formatCoord(lat, true)},  ${_formatCoord(lng, false)}',
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            fontFeatures: [FontFeature.tabularFigures()],
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            Text('Pin this spot ♡',
                style: Theme.of(context).textTheme.titleLarge),

            const SizedBox(height: 14),

            TextField(
              controller: widget.nameCtrl,
              autofocus: true,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                hintText: 'Name this place…',
                prefixIcon: Icon(Icons.place_rounded, color: _kRose),
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

            Text('Category', style: Theme.of(context).textTheme.labelSmall),
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
                          ? _kRose.withValues(alpha: 0.2)
                          : AppColors.bgCard,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected ? _kRose : AppColors.divider,
                        width: selected ? 1.5 : 0.5,
                      ),
                    ),
                    child: Center(
                        child: Text(e, style: const TextStyle(fontSize: 22))),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 20),

            GradientButton(
              label: 'Pin this spot ♡',
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

// ── Pin detail sheet ──────────────────────────────────────────────────────────

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
                          ? _kGreen.withValues(alpha: 0.15)
                          : AppColors.bgCard,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: pin.visited ? _kGreen : AppColors.divider,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          pin.visited
                              ? Icons.check_circle_rounded
                              : Icons.radio_button_unchecked_rounded,
                          color:
                              pin.visited ? _kGreen : AppColors.textMuted,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          pin.visited ? 'Visited!' : 'Mark visited',
                          style: TextStyle(
                            color: pin.visited
                                ? _kGreen
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
                    color: _kRose.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border:
                        Border.all(color: _kRose.withValues(alpha: 0.4)),
                  ),
                  child: const Icon(Icons.delete_outline_rounded,
                      color: _kRose, size: 22),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Unused import guard ───────────────────────────────────────────────────────
// dart:math is used by _TearDropPainter indirectly; kept for safety
final _kMathPi = math.pi; // ignore: unused_element
