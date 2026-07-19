import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../core/firebase/models.dart';
import '../../core/presence/activity_announcer.dart';
import '../../core/providers/providers.dart';
import '../../core/theme/app_theme.dart';

// ─── Basic furniture catalog (matches the builder functions in the JS scene) ─

class _FurnitureType {
  final String id;
  final String label;
  final String emoji;
  const _FurnitureType(this.id, this.label, this.emoji);
}

const _kFurnitureTypes = [
  _FurnitureType('sofa', 'Sofa', '🛋️'),
  _FurnitureType('chair', 'Chair', '🪑'),
  _FurnitureType('coffee_table', 'Coffee Table', '🪵'),
  _FurnitureType('tv_stand', 'TV Stand', '📺'),
  _FurnitureType('bookshelf', 'Bookshelf', '📚'),
  _FurnitureType('lamp', 'Lamp', '💡'),
  _FurnitureType('plant', 'Plant', '🪴'),
  _FurnitureType('rug', 'Rug', '🟤'),
  _FurnitureType('bed', 'Bed', '🛏️'),
  _FurnitureType('nightstand', 'Nightstand', '🕯️'),
  _FurnitureType('wardrobe', 'Wardrobe', '🚪'),
  _FurnitureType('desk', 'Desk', '🖥️'),
  _FurnitureType('dining_table', 'Dining Table', '🍽️'),
  _FurnitureType('kitchen_counter', 'Kitchen Counter', '🍳'),
  _FurnitureType('stove', 'Stove', '🔥'),
  _FurnitureType('fridge', 'Fridge', '🧊'),
  _FurnitureType('toilet', 'Toilet', '🚽'),
  _FurnitureType('bathroom_sink', 'Bathroom Sink', '🚰'),
];

String _furnitureEmoji(String type) =>
    _kFurnitureTypes.firstWhere((f) => f.id == type, orElse: () => _kFurnitureTypes.first).emoji;
String _furnitureLabel(String type) =>
    _kFurnitureTypes.firstWhere((f) => f.id == type, orElse: () => _kFurnitureTypes.first).label;

// ─── Style options ──────────────────────────────────────────────────────────

class _StyleOption {
  final String id;
  final String label;
  final Color swatch;
  const _StyleOption(this.id, this.label, this.swatch);
}

const _kFloorOptions = [
  _StyleOption('oak', 'Oak', Color(0xFFC9A874)),
  _StyleOption('white_oak', 'White Oak', Color(0xFFE7DCC6)),
  _StyleOption('walnut', 'Walnut', Color(0xFF6B4226)),
  _StyleOption('slate', 'Slate', Color(0xFF7C8593)),
];
const _kWallOptions = [
  _StyleOption('greige', 'Greige', Color(0xFFE3DACB)),
  _StyleOption('sage', 'Sage', Color(0xFFAFC0A4)),
  _StyleOption('blush', 'Blush', Color(0xFFE8CFC9)),
  _StyleOption('charcoal', 'Charcoal', Color(0xFF3A3640)),
];
const _kLightingOptions = [
  _StyleOption('warm', 'Warm', Color(0xFFFFB877)),
  _StyleOption('cool', 'Cool', Color(0xFFBBD9FF)),
  _StyleOption('evening', 'Evening', Color(0xFFFF9F5A)),
];

// ─── House templates ────────────────────────────────────────────────────────
//
// Walls are grid-snapped and axis-aligned only (never freeform/angled) —
// each wall is stored canonically as a horizontal or vertical grid line so
// "moving" a wall is remove-then-add rather than a drag-to-any-position
// gesture. Rooms are not a sealed graph: walls are independent dividers and
// floor cells independently mark what's "inside" the house — there's no
// flood-fill/room-detection, by design, to keep this robust without any way
// to visually test it in this environment.

class _HouseTemplate {
  final String id;
  final String label;
  final String emoji;
  final HouseLayout Function() build;
  const _HouseTemplate(this.id, this.label, this.emoji, this.build);
}

Map<String, String> _fillFloor(int x0, int x1, int z0, int z1, String matId) {
  final m = <String, String>{};
  for (var x = x0; x <= x1; x++) {
    for (var z = z0; z <= z1; z++) {
      m['$x,$z'] = matId;
    }
  }
  return m;
}

HouseLayout _perimeterLayout({
  required int gridW,
  required int gridD,
  required Map<String, String> floors,
  List<int> verticalDividers = const [],
}) {
  final walls = <WallSegment>[];
  for (var x = 0; x < gridW; x++) {
    walls.add(WallSegment(orientation: 'H', line: 0, cell: x));
  }
  final frontDoorX = gridW ~/ 2;
  for (var x = 0; x < gridW; x++) {
    if (x == frontDoorX) continue; // front door gap
    walls.add(WallSegment(orientation: 'H', line: gridD, cell: x));
  }
  for (var z = 0; z < gridD; z++) {
    walls.add(WallSegment(orientation: 'V', line: 0, cell: z));
    walls.add(WallSegment(orientation: 'V', line: gridW, cell: z));
  }
  final interiorDoorZ = gridD ~/ 2;
  for (final vx in verticalDividers) {
    for (var z = 0; z < gridD; z++) {
      if (z == interiorDoorZ) continue; // interior doorway gap
      walls.add(WallSegment(orientation: 'V', line: vx, cell: z));
    }
  }
  return HouseLayout(gridW: gridW, gridD: gridD, walls: walls, floors: floors);
}

final _kHouseTemplates = [
  _HouseTemplate('blank', 'Blank Plot', '🌳', () => const HouseLayout(gridW: 12, gridD: 10)),
  _HouseTemplate(
    'studio',
    'Studio',
    '🏠',
    () => _perimeterLayout(gridW: 8, gridD: 6, floors: _fillFloor(0, 7, 0, 5, 'oak')),
  ),
  _HouseTemplate(
    'one_bed',
    '1-Bedroom',
    '🛏️',
    () => _perimeterLayout(
      gridW: 10,
      gridD: 8,
      floors: {
        ..._fillFloor(0, 4, 0, 7, 'walnut'),
        ..._fillFloor(5, 9, 0, 7, 'oak'),
      },
      verticalDividers: [5],
    ),
  ),
  _HouseTemplate(
    'two_bed',
    '2-Bedroom',
    '🏡',
    () => _perimeterLayout(
      gridW: 13,
      gridD: 9,
      floors: {
        ..._fillFloor(0, 3, 0, 8, 'walnut'),
        ..._fillFloor(4, 8, 0, 8, 'oak'),
        ..._fillFloor(9, 12, 0, 8, 'white_oak'),
      },
      verticalDividers: [4, 9],
    ),
  ),
];

// ─── Plot expansion ─────────────────────────────────────────────────────────
//
// Grows the grid by one row/column at an edge. Growing at the "far" edge
// (South/East) needs no re-indexing — existing wall lines and floor cells
// keep the same coordinates, only the upper bound increases. Growing at the
// "near" edge (North/West) shifts every existing wall line/cell by +1 so
// coordinate (0,0) stays anchored at the new edge instead of the old one.

HouseLayout _expandLayout(HouseLayout layout, String direction) {
  Map<String, String> shiftFloors({int dx = 0, int dz = 0}) {
    final out = <String, String>{};
    layout.floors.forEach((key, matId) {
      final parts = key.split(',');
      final x = int.parse(parts[0]) + dx;
      final z = int.parse(parts[1]) + dz;
      out['$x,$z'] = matId;
    });
    return out;
  }

  switch (direction) {
    case 'N':
      return HouseLayout(
        gridW: layout.gridW,
        gridD: layout.gridD + 1,
        walls: layout.walls
            .map((w) => w.orientation == 'H'
                ? WallSegment(orientation: 'H', line: w.line + 1, cell: w.cell)
                : WallSegment(orientation: 'V', line: w.line, cell: w.cell + 1))
            .toList(),
        floors: shiftFloors(dz: 1),
      );
    case 'W':
      return HouseLayout(
        gridW: layout.gridW + 1,
        gridD: layout.gridD,
        walls: layout.walls
            .map((w) => w.orientation == 'V'
                ? WallSegment(orientation: 'V', line: w.line + 1, cell: w.cell)
                : WallSegment(orientation: 'H', line: w.line, cell: w.cell + 1))
            .toList(),
        floors: shiftFloors(dx: 1),
      );
    case 'S':
      return HouseLayout(
        gridW: layout.gridW,
        gridD: layout.gridD + 1,
        walls: layout.walls,
        floors: layout.floors,
      );
    case 'E':
    default:
      return HouseLayout(
        gridW: layout.gridW + 1,
        gridD: layout.gridD,
        walls: layout.walls,
        floors: layout.floors,
      );
  }
}

// ─── Main screen ─────────────────────────────────────────────────────────

enum _DecorateMode { furnish, walls, floors }

class HomeDecorateScreen extends ConsumerStatefulWidget {
  const HomeDecorateScreen({super.key});

  @override
  ConsumerState<HomeDecorateScreen> createState() => _HomeDecorateScreenState();
}

class _HomeDecorateScreenState extends ConsumerState<HomeDecorateScreen>
    with ActivityAnnouncer {
  late final WebViewController _webCtrl;
  bool _sceneReady = false;
  String? _placingType;
  String? _movingItemId;
  _DecorateMode _mode = _DecorateMode.furnish;
  String _paintFloorId = 'oak';
  bool _promptedTemplate = false;
  List<Furniture3DItem> _lastItems = const [];
  HomeRoomStyle _lastStyle = const HomeRoomStyle();
  HouseLayout _lastLayout = const HouseLayout();

  bool get _isPlacing => _placingType != null;

  @override
  void initState() {
    super.initState();
    _webCtrl = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF1A1220))
      ..addJavaScriptChannel('FlutterBridge', onMessageReceived: _onJsMessage)
      ..loadFlutterAsset('assets/room3d/index.html');
    announceActivity('Designing the house');
  }

  void _onJsMessage(JavaScriptMessage message) {
    Map<String, dynamic> data;
    try {
      data = jsonDecode(message.message) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    switch (data['type']) {
      case 'ready':
        setState(() => _sceneReady = true);
        _syncScene();
      case 'placed':
        _handlePlaced(data);
      case 'selected':
        _handleSelected(data['id'] as String);
      case 'wallToggled':
        _handleWallToggled(data);
      case 'floorPainted':
        _handleFloorPainted(data);
    }
  }

  void _syncScene() {
    if (!_sceneReady) return;
    final payload = {
      'gridW': _lastLayout.gridW,
      'gridD': _lastLayout.gridD,
      'walls': _lastLayout.walls.map((w) => w.toMap()).toList(),
      'floors': _lastLayout.floors,
      'items': _lastItems
          .map((it) => {
                'id': it.id,
                'type': it.type,
                'x': it.x,
                'z': it.z,
                'rotationY': it.rotationY,
              })
          .toList(),
      'style': {
        'floorId': _lastStyle.floorId,
        'wallId': _lastStyle.wallId,
        'lightingId': _lastStyle.lightingId,
      },
    };
    final jsArg = jsonEncode(jsonEncode(payload));
    _webCtrl.runJavaScript('window.loadHouse($jsArg)');
  }

  Future<void> _handlePlaced(Map<String, dynamic> data) async {
    final coupleId = ref.read(coupleIdProvider);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (coupleId == null || uid == null) return;
    final x = (data['x'] as num).toDouble();
    final z = (data['z'] as num).toDouble();
    final movingId = _movingItemId;
    if (movingId != null) {
      await ref.read(firestoreServiceProvider).moveFurniture3D(coupleId, movingId, x, z);
    } else if (_placingType != null) {
      final item = Furniture3DItem(
        id: const Uuid().v4(),
        type: _placingType!,
        x: x,
        z: z,
        placedBy: uid,
        placedAt: DateTime.now(),
      );
      await ref.read(firestoreServiceProvider).placeFurniture3D(coupleId, item);
    }
    setState(() {
      _placingType = null;
      _movingItemId = null;
    });
  }

  void _handleSelected(String id) {
    final item = _lastItems.where((i) => i.id == id).firstOrNull;
    if (item == null) return;
    _showItemActions(item);
  }

  Future<void> _handleWallToggled(Map<String, dynamic> data) async {
    final coupleId = ref.read(coupleIdProvider);
    if (coupleId == null) return;
    final seg = WallSegment(
      orientation: data['orientation'] as String,
      line: (data['line'] as num).toInt(),
      cell: (data['cell'] as num).toInt(),
    );
    final walls = List<WallSegment>.from(_lastLayout.walls);
    final idx = walls.indexWhere((w) => w.key == seg.key);
    if (idx >= 0) {
      walls.removeAt(idx);
    } else {
      walls.add(seg);
    }
    _lastLayout = HouseLayout(
      gridW: _lastLayout.gridW,
      gridD: _lastLayout.gridD,
      walls: walls,
      floors: _lastLayout.floors,
    );
    _syncScene();
    await ref.read(firestoreServiceProvider).setHouseLayout(coupleId, _lastLayout);
  }

  Future<void> _handleFloorPainted(Map<String, dynamic> data) async {
    final coupleId = ref.read(coupleIdProvider);
    if (coupleId == null) return;
    final x = (data['x'] as num).toInt();
    final z = (data['z'] as num).toInt();
    final materialId = data['materialId'] as String;
    final floors = Map<String, String>.from(_lastLayout.floors);
    floors['$x,$z'] = materialId;
    _lastLayout = HouseLayout(
      gridW: _lastLayout.gridW,
      gridD: _lastLayout.gridD,
      walls: _lastLayout.walls,
      floors: floors,
    );
    _syncScene();
    await ref.read(firestoreServiceProvider).setHouseLayout(coupleId, _lastLayout);
  }

  void _enterPlacement(String type, {String? movingId}) {
    setState(() {
      _placingType = type;
      _movingItemId = movingId;
    });
    _webCtrl.runJavaScript("window.enterPlacementMode('$type')");
  }

  void _cancelPlacing() {
    setState(() {
      _placingType = null;
      _movingItemId = null;
    });
    _webCtrl.runJavaScript('window.exitPlacementMode()');
  }

  void _setMode(_DecorateMode m) {
    if (_mode == m) return;
    _cancelPlacing();
    setState(() => _mode = m);
    final jsMode = switch (m) {
      _DecorateMode.furnish => 'furnish',
      _DecorateMode.walls => 'walls',
      _DecorateMode.floors => 'floors',
    };
    final arg = m == _DecorateMode.floors ? ",'$_paintFloorId'" : '';
    _webCtrl.runJavaScript("window.setEditMode('$jsMode'$arg)");
  }

  void _setPaintFloor(String id) {
    setState(() => _paintFloorId = id);
    if (_mode == _DecorateMode.floors) {
      _webCtrl.runJavaScript("window.setEditMode('floors','$id')");
    }
  }

  Future<void> _expandPlot(String direction) async {
    final coupleId = ref.read(coupleIdProvider);
    if (coupleId == null) return;
    final next = _expandLayout(_lastLayout, direction);
    setState(() => _lastLayout = next);
    _syncScene();
    await ref.read(firestoreServiceProvider).setHouseLayout(coupleId, next);
  }

  void _showExpandSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => Container(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(sheetCtx).padding.bottom + 20),
        decoration: const BoxDecoration(
          color: AppColors.bgMid,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(top: BorderSide(color: AppColors.divider, width: 0.5)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Expand Your Plot',
                style: TextStyle(
                    color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            const Text('Adds space at an edge — switch to Walls or Floors after to open it up.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            const SizedBox(height: 18),
            _ExpandGrid(onExpand: _expandPlot),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(sheetCtx),
              child: const Text('Done', style: TextStyle(color: AppColors.rose)),
            ),
          ],
        ),
      ),
    );
  }

  void _showItemActions(Furniture3DItem item) {
    final coupleId = ref.read(coupleIdProvider);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => Container(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(sheetCtx).padding.bottom + 20),
        decoration: const BoxDecoration(
          color: AppColors.bgMid,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(top: BorderSide(color: AppColors.divider, width: 0.5)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text(_furnitureEmoji(item.type), style: const TextStyle(fontSize: 26)),
              const SizedBox(width: 12),
              Text(_furnitureLabel(item.type),
                  style: const TextStyle(
                      color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 14),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.open_with_rounded, color: AppColors.textPrimary),
              title: const Text('Move',
                  style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(sheetCtx);
                _enterPlacement(item.type, movingId: item.id);
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.rotate_right_rounded, color: AppColors.textPrimary),
              title: const Text('Rotate',
                  style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
              onTap: () async {
                Navigator.pop(sheetCtx);
                _webCtrl.runJavaScript("window.rotateItemMesh('${item.id}')");
                if (coupleId == null) return;
                final newRotation = item.rotationY + 1.5707963267948966; // pi/2
                await ref
                    .read(firestoreServiceProvider)
                    .rotateFurniture3D(coupleId, item.id, newRotation);
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.delete_outline_rounded, color: AppColors.rose),
              title: const Text('Remove',
                  style: TextStyle(color: AppColors.rose, fontWeight: FontWeight.w600)),
              onTap: () async {
                Navigator.pop(sheetCtx);
                if (coupleId == null) return;
                await ref.read(firestoreServiceProvider).removeFurniture3D(coupleId, item.id);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showStylePicker() {
    final coupleId = ref.read(coupleIdProvider);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetCtx) => Container(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(sheetCtx).padding.bottom + 20),
        decoration: const BoxDecoration(
          color: AppColors.bgMid,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(top: BorderSide(color: AppColors.divider, width: 0.5)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Room Style',
                style: TextStyle(
                    color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            _styleRow('Floor', _kFloorOptions, _lastStyle.floorId,
                (id) => _applyStyle(coupleId, floorId: id)),
            const SizedBox(height: 14),
            _styleRow('Wall', _kWallOptions, _lastStyle.wallId,
                (id) => _applyStyle(coupleId, wallId: id)),
            const SizedBox(height: 14),
            _styleRow('Lighting', _kLightingOptions, _lastStyle.lightingId,
                (id) => _applyStyle(coupleId, lightingId: id)),
          ],
        ),
      ),
    );
  }

  Widget _styleRow(
      String label, List<_StyleOption> options, String selectedId, ValueChanged<String> onPick) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(),
            style: const TextStyle(
                color: AppColors.rose, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
        const SizedBox(height: 8),
        SizedBox(
          height: 68,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: options
                .map((o) => Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: SquishyTap(
                        onTap: () => onPick(o.id),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: o.swatch,
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: o.id == selectedId
                                        ? AppColors.textPrimary
                                        : Colors.white24,
                                    width: o.id == selectedId ? 2.5 : 1),
                              ),
                              child: o.id == selectedId
                                  ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
                                  : null,
                            ),
                            const SizedBox(height: 4),
                            SizedBox(
                              width: 56,
                              child: Text(o.label,
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: AppColors.textMuted, fontSize: 9)),
                            ),
                          ],
                        ),
                      ),
                    ))
                .toList(),
          ),
        ),
      ],
    );
  }

  Future<void> _applyStyle(String? coupleId, {String? floorId, String? wallId, String? lightingId}) async {
    // Instant local preview, then persist.
    _webCtrl.runJavaScript(
        "window.setStyle('${floorId ?? _lastStyle.floorId}','${wallId ?? _lastStyle.wallId}','${lightingId ?? _lastStyle.lightingId}')");
    if (coupleId == null) return;
    await ref
        .read(firestoreServiceProvider)
        .setHomeRoomStyle(coupleId, floorId: floorId, wallId: wallId, lightingId: lightingId);
  }

  void _showTemplatePicker({bool initial = false}) {
    final coupleId = ref.read(coupleIdProvider);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      isDismissible: !initial,
      enableDrag: !initial,
      builder: (sheetCtx) => Container(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(sheetCtx).padding.bottom + 20),
        decoration: const BoxDecoration(
          color: AppColors.bgMid,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(top: BorderSide(color: AppColors.divider, width: 0.5)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              initial ? 'Choose your starting layout' : 'House Templates',
              style: const TextStyle(
                  color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
            ),
            if (initial) ...[
              const SizedBox(height: 6),
              const Text('You can move walls and repaint floors together anytime after ♡',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            ] else ...[
              const SizedBox(height: 6),
              const Text('Applying a template replaces the current walls & floors.',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            ],
            const SizedBox(height: 16),
            ..._kHouseTemplates.map((t) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Material(
                    color: AppColors.bgCard,
                    borderRadius: BorderRadius.circular(14),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      leading: Text(t.emoji, style: const TextStyle(fontSize: 24)),
                      title: Text(t.label,
                          style: const TextStyle(
                              color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                      trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                      onTap: () async {
                        Navigator.pop(sheetCtx);
                        if (coupleId == null) return;
                        await ref
                            .read(firestoreServiceProvider)
                            .setHouseLayout(coupleId, t.build());
                      },
                    ),
                  ),
                )),
          ],
        ),
      ),
    );
  }

  void _showMyItems() {
    final coupleId = ref.read(coupleIdProvider);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetCtx) => Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(sheetCtx).size.height * 0.7),
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(sheetCtx).padding.bottom + 20),
        decoration: const BoxDecoration(
          color: AppColors.bgMid,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(top: BorderSide(color: AppColors.divider, width: 0.5)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('My Items (${_lastItems.length})',
                style: const TextStyle(
                    color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            if (_lastItems.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text('Nothing placed yet — tap a piece below to start ♡',
                    style: TextStyle(color: AppColors.textSecondary)),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _lastItems.length,
                  itemBuilder: (_, i) {
                    final item = _lastItems[i];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Text(_furnitureEmoji(item.type), style: const TextStyle(fontSize: 22)),
                      title: Text(_furnitureLabel(item.type),
                          style: const TextStyle(color: AppColors.textPrimary)),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, color: AppColors.rose),
                        onPressed: () async {
                          if (coupleId == null) return;
                          await ref
                              .read(firestoreServiceProvider)
                              .removeFurniture3D(coupleId, item.id);
                        },
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(homeDecorProvider, (_, next) {
      _lastItems = next.valueOrNull ?? _lastItems;
      _syncScene();
    });
    ref.listen(homeRoomStyleProvider, (_, next) {
      _lastStyle = next.valueOrNull ?? _lastStyle;
      _syncScene();
    });
    ref.listen(houseLayoutProvider, (_, next) {
      final layout = next.valueOrNull;
      if (layout == null) return;
      _lastLayout = layout;
      _syncScene();
      if (!_promptedTemplate && layout.floors.isEmpty && layout.walls.isEmpty) {
        _promptedTemplate = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _showTemplatePicker(initial: true);
        });
      }
    });
    // Keep the initial snapshot even before ref.listen fires for the first time.
    _lastItems = ref.read(homeDecorProvider).valueOrNull ?? _lastItems;
    _lastStyle = ref.read(homeRoomStyleProvider).valueOrNull ?? _lastStyle;
    _lastLayout = ref.read(houseLayoutProvider).valueOrNull ?? _lastLayout;

    return Scaffold(
      backgroundColor: const Color(0xFF1A1220),
      body: SafeArea(
        child: Column(
          children: [
            _Header(
              isPlacing: _isPlacing,
              onCancel: _cancelPlacing,
              onBack: () => Navigator.maybePop(context),
              onStyleTap: _showStylePicker,
              onMyItemsTap: _showMyItems,
            ),
            _ModeBar(
              mode: _mode,
              onModeChanged: _setMode,
              onTemplates: () => _showTemplatePicker(),
              onExpand: _showExpandSheet,
            ),
            Expanded(
              child: Stack(
                children: [
                  WebViewWidget(controller: _webCtrl),
                  if (!_sceneReady)
                    const Center(child: CircularProgressIndicator(color: AppColors.rose)),
                ],
              ),
            ),
            if (_mode == _DecorateMode.furnish)
              _InventoryDrawer(
                placingType: _placingType,
                onSelect: (type) {
                  if (_placingType == type) {
                    _cancelPlacing();
                  } else {
                    _enterPlacement(type);
                  }
                },
              )
            else if (_mode == _DecorateMode.walls)
              const _BuildHintBar(text: 'Tap a wall line to add or remove it')
            else
              _FloorPaintDrawer(selected: _paintFloorId, onSelect: _setPaintFloor),
          ],
        ),
      ),
    );
  }
}

// ─── Header ──────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final bool isPlacing;
  final VoidCallback onCancel;
  final VoidCallback onBack;
  final VoidCallback onStyleTap;
  final VoidCallback onMyItemsTap;

  const _Header({
    required this.isPlacing,
    required this.onCancel,
    required this.onBack,
    required this.onStyleTap,
    required this.onMyItemsTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary),
            onPressed: onBack,
          ),
          Expanded(
            child: isPlacing
                ? Text('Tap a floored room to place it',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textPrimary.withValues(alpha: 0.9), fontSize: 14))
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Our Future Home',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.displayMedium?.copyWith(fontSize: 22)),
                      const Text('Design it together — drag to orbit, pinch to zoom ♡',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                    ],
                  ),
          ),
          if (isPlacing)
            TextButton(
              onPressed: onCancel,
              child: const Text('Cancel', style: TextStyle(color: AppColors.rose)),
            )
          else ...[
            IconButton(
              tooltip: 'My Items',
              icon: const Icon(Icons.inventory_2_outlined, color: AppColors.textPrimary),
              onPressed: onMyItemsTap,
            ),
            IconButton(
              tooltip: 'Room Style',
              icon: const Icon(Icons.format_paint_rounded, color: AppColors.textPrimary),
              onPressed: onStyleTap,
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Mode bar (Furnish / Walls / Floors + Templates) ────────────────────────

class _ModeBar extends StatelessWidget {
  final _DecorateMode mode;
  final ValueChanged<_DecorateMode> onModeChanged;
  final VoidCallback onTemplates;
  final VoidCallback onExpand;

  const _ModeBar({
    required this.mode,
    required this.onModeChanged,
    required this.onTemplates,
    required this.onExpand,
  });

  Widget _seg(_DecorateMode m, String label, IconData icon) {
    final selected = mode == m;
    return Expanded(
      child: SquishyTap(
        onTap: () => onModeChanged(m),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 3),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: selected ? AppColors.rose.withValues(alpha: 0.25) : AppColors.bgCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: selected ? AppColors.rose : AppColors.divider, width: selected ? 1.3 : 0.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: selected ? AppColors.rose : AppColors.textSecondary),
              const SizedBox(height: 2),
              Text(label,
                  style: TextStyle(
                      fontSize: 10,
                      color: selected ? AppColors.textPrimary : AppColors.textMuted)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 8, 8),
      child: Row(
        children: [
          _seg(_DecorateMode.furnish, 'Furnish', Icons.chair_rounded),
          _seg(_DecorateMode.walls, 'Walls', Icons.border_all_rounded),
          _seg(_DecorateMode.floors, 'Floors', Icons.grid_view_rounded),
          IconButton(
            tooltip: 'Expand Plot',
            icon: const Icon(Icons.crop_free_rounded, color: AppColors.textPrimary, size: 22),
            onPressed: onExpand,
          ),
          IconButton(
            tooltip: 'Templates',
            icon: const Icon(Icons.dashboard_customize_outlined, color: AppColors.textPrimary, size: 22),
            onPressed: onTemplates,
          ),
        ],
      ),
    );
  }
}

class _ExpandGrid extends StatelessWidget {
  final ValueChanged<String> onExpand;
  const _ExpandGrid({required this.onExpand});

  Widget _btn(IconData icon, String dir) => SquishyTap(
        onTap: () => onExpand(dir),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.divider, width: 0.5),
          ),
          child: Icon(icon, color: AppColors.rose, size: 22),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 168,
      height: 168,
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Icon(Icons.home_rounded, color: AppColors.textMuted, size: 30),
          Positioned(top: 0, child: _btn(Icons.arrow_upward_rounded, 'N')),
          Positioned(bottom: 0, child: _btn(Icons.arrow_downward_rounded, 'S')),
          Positioned(left: 0, child: _btn(Icons.arrow_back_rounded, 'W')),
          Positioned(right: 0, child: _btn(Icons.arrow_forward_rounded, 'E')),
        ],
      ),
    );
  }
}

class _BuildHintBar extends StatelessWidget {
  final String text;
  const _BuildHintBar({required this.text});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: const BoxDecoration(
          color: AppColors.bgMid,
          border: Border(top: BorderSide(color: AppColors.divider, width: 0.5)),
        ),
        child: Text(text,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
      );
}

class _FloorPaintDrawer extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelect;

  const _FloorPaintDrawer({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 108,
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        color: AppColors.bgMid,
        border: Border(top: BorderSide(color: AppColors.divider, width: 0.5)),
      ),
      child: Column(
        children: [
          const Text('Drag over the floor to paint',
              style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
          const SizedBox(height: 8),
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: _kFloorOptions
                  .map((o) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: SquishyTap(
                          onTap: () => onSelect(o.id),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: o.swatch,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: o.id == selected
                                          ? AppColors.textPrimary
                                          : Colors.white24,
                                      width: o.id == selected ? 2.5 : 1),
                                ),
                                child: o.id == selected
                                    ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
                                    : null,
                              ),
                              const SizedBox(height: 4),
                              Text(o.label,
                                  style: const TextStyle(color: AppColors.textMuted, fontSize: 9)),
                            ],
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Inventory drawer ────────────────────────────────────────────────────

class _InventoryDrawer extends StatelessWidget {
  final String? placingType;
  final ValueChanged<String> onSelect;

  const _InventoryDrawer({required this.placingType, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 104,
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        color: AppColors.bgMid,
        border: Border(top: BorderSide(color: AppColors.divider, width: 0.5)),
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: _kFurnitureTypes
            .map((f) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: _CatalogChip(
                    furniture: f,
                    selected: placingType == f.id,
                    onTap: () => onSelect(f.id),
                  ),
                ))
            .toList(),
      ),
    );
  }
}

class _CatalogChip extends StatelessWidget {
  final _FurnitureType furniture;
  final bool selected;
  final VoidCallback onTap;

  const _CatalogChip({required this.furniture, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SquishyTap(
      onTap: onTap,
      cuteStickers: selected ? null : const ['✨'],
      child: Container(
        width: 68,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.rose.withValues(alpha: 0.28) : AppColors.bgCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.rose : AppColors.divider,
            width: selected ? 1.5 : 0.5,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(furniture.emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(height: 4),
            Text(furniture.label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 9.5)),
          ],
        ),
      ),
    );
  }
}
