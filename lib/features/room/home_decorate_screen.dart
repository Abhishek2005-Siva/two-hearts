import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../core/firebase/models.dart';
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
  _FurnitureType('bed', 'Bed', '🛏️'),
  _FurnitureType('coffee_table', 'Coffee Table', '🪵'),
  _FurnitureType('bookshelf', 'Bookshelf', '📚'),
  _FurnitureType('lamp', 'Lamp', '💡'),
  _FurnitureType('plant', 'Plant', '🪴'),
  _FurnitureType('rug', 'Rug', '🟤'),
  _FurnitureType('chair', 'Chair', '🪑'),
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

// ─── Main screen ─────────────────────────────────────────────────────────

class HomeDecorateScreen extends ConsumerStatefulWidget {
  const HomeDecorateScreen({super.key});

  @override
  ConsumerState<HomeDecorateScreen> createState() => _HomeDecorateScreenState();
}

class _HomeDecorateScreenState extends ConsumerState<HomeDecorateScreen> {
  late final WebViewController _webCtrl;
  bool _sceneReady = false;
  String? _placingType;
  String? _movingItemId;
  List<Furniture3DItem> _lastItems = const [];
  HomeRoomStyle _lastStyle = const HomeRoomStyle();

  bool get _isPlacing => _placingType != null;

  @override
  void initState() {
    super.initState();
    _webCtrl = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF1A1220))
      ..addJavaScriptChannel('FlutterBridge', onMessageReceived: _onJsMessage)
      ..loadFlutterAsset('assets/room3d/index.html');
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
    }
  }

  void _syncScene() {
    if (!_sceneReady) return;
    final payload = {
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
    _webCtrl.runJavaScript('window.loadRoom($jsArg)');
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
    // Keep the initial snapshot even before ref.listen fires for the first time.
    _lastItems = ref.read(homeDecorProvider).valueOrNull ?? _lastItems;
    _lastStyle = ref.read(homeRoomStyleProvider).valueOrNull ?? _lastStyle;

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
            Expanded(
              child: Stack(
                children: [
                  WebViewWidget(controller: _webCtrl),
                  if (!_sceneReady)
                    const Center(child: CircularProgressIndicator(color: AppColors.rose)),
                ],
              ),
            ),
            _InventoryDrawer(
              placingType: _placingType,
              onSelect: (type) {
                if (_placingType == type) {
                  _cancelPlacing();
                } else {
                  _enterPlacement(type);
                }
              },
            ),
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
                ? Text('Tap the floor to place it',
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
