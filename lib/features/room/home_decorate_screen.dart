import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../core/firebase/models.dart';
import '../../core/providers/providers.dart';
import '../../core/theme/app_theme.dart';
import 'home_decor_catalog.dart';

// ─── Geometry helpers ───────────────────────────────────────────────────────

const double _kWallHeight = 110;
const double _kCanvasW = kIsoGridSize * kIsoTileW;
const double _kCanvasH = _kWallHeight + kIsoGridSize * kIsoTileH + 30;
const Offset _kOrigin = Offset(_kCanvasW / 2, _kWallHeight + 10);

class _IsoBox {
  final Offset topLeft; // relative to the scene origin
  final Size size;
  const _IsoBox(this.topLeft, this.size);
}

_IsoBox _isoBoxFor(int col, int row, int cols, int rows, double heightPx) {
  final dx = (col - row - rows) * (kIsoTileW / 2);
  final dy = (col + row) * (kIsoTileH / 2) - heightPx;
  final w = (cols + rows) * (kIsoTileW / 2);
  final h = (cols + rows) * (kIsoTileH / 2) + heightPx;
  return _IsoBox(Offset(dx, dy), Size(w, h));
}

List<Widget> _buildPhotoThumbs(_PlacedRender r) {
  final box = _isoBoxFor(r.item.col, r.item.row, r.cols, r.rows, r.entry.heightPx);
  final localCenter =
      Offset((r.rows + r.cols) * kIsoTileW / 4, (r.cols + r.rows) * kIsoTileH / 4);
  final center = _kOrigin + box.topLeft + localCenter;
  final urls = r.photoUrls.take(3).toList();
  final widgets = <Widget>[];
  for (var i = 0; i < urls.length; i++) {
    final dx = (i - (urls.length - 1) / 2) * 20.0;
    widgets.add(Positioned(
      key: ValueKey('photo_thumb_${r.item.id}_$i'),
      left: center.dx + dx - 9,
      top: center.dy - 13,
      child: IgnorePointer(
        child: Container(
          width: 18,
          height: 18,
          padding: const EdgeInsets.all(1.5),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(3)),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: CachedNetworkImage(imageUrl: urls[i], fit: BoxFit.cover),
          ),
        ),
      ),
    ));
  }
  return widgets;
}

Color _lighten(Color c, double amt) => Color.lerp(c, Colors.white, amt)!;
Color _darken(Color c, double amt) => Color.lerp(c, Colors.black, amt)!;
Offset _lerpOffset(Offset a, Offset b, double t) =>
    Offset(a.dx + (b.dx - a.dx) * t, a.dy + (b.dy - a.dy) * t);

(int, int) _effectiveFootprint(HomeCatalogEntry entry, int rotation) {
  final flip = entry.rotatable && rotation % 180 == 90;
  return flip ? (entry.footprintRows, entry.footprintCols) : (entry.footprintCols, entry.footprintRows);
}

// ─── A placed item, resolved with its catalog entry + any real-data extras ─

class _PlacedRender {
  final HomeDecorItem item;
  final HomeCatalogEntry entry;
  final int cols;
  final int rows;
  final int? trophyCount;
  final List<String> photoUrls;

  const _PlacedRender({
    required this.item,
    required this.entry,
    required this.cols,
    required this.rows,
    this.trophyCount,
    this.photoUrls = const [],
  });

  int get depth => item.col + item.row;
}

// ─── Main screen ─────────────────────────────────────────────────────────

class HomeDecorateScreen extends ConsumerStatefulWidget {
  const HomeDecorateScreen({super.key});

  @override
  ConsumerState<HomeDecorateScreen> createState() => _HomeDecorateScreenState();
}

class _HomeDecorateScreenState extends ConsumerState<HomeDecorateScreen>
    with SingleTickerProviderStateMixin {
  String? _placingCatalogId;
  String? _movingItemId;
  late final AnimationController _glow;

  @override
  void initState() {
    super.initState();
    _glow = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _glow.dispose();
    super.dispose();
  }

  bool get _isPlacing => _placingCatalogId != null || _movingItemId != null;

  void _cancelPlacing() => setState(() {
        _placingCatalogId = null;
        _movingItemId = null;
      });

  Set<String> _occupiedTiles(List<HomeDecorItem> items, {String? excludeId}) {
    final occ = <String>{};
    for (final it in items) {
      if (it.id == excludeId) continue;
      final entry = catalogEntryFor(it.catalogId);
      if (entry == null || entry.isRug) continue;
      final (cols, rows) = _effectiveFootprint(entry, it.rotation);
      for (var c = it.col; c < it.col + cols; c++) {
        for (var r = it.row; r < it.row + rows; r++) {
          occ.add('$c,$r');
        }
      }
    }
    return occ;
  }

  bool _fits(int col, int row, int cols, int rows) =>
      col >= 0 && row >= 0 && col + cols <= kIsoGridSize && row + rows <= kIsoGridSize;

  bool _overlaps(int col, int row, int cols, int rows, Set<String> occ) {
    for (var c = col; c < col + cols; c++) {
      for (var r = row; r < row + rows; r++) {
        if (occ.contains('$c,$r')) return true;
      }
    }
    return false;
  }

  Future<void> _handleTileTap(int col, int row, List<HomeDecorItem> items) async {
    final coupleId = ref.read(coupleIdProvider);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (coupleId == null || uid == null) return;

    if (_movingItemId != null) {
      final movingId = _movingItemId!;
      final moving = items.where((i) => i.id == movingId).firstOrNull;
      if (moving == null) {
        _cancelPlacing();
        return;
      }
      final entry = catalogEntryFor(moving.catalogId);
      if (entry == null) return;
      if (!entry.isRug) {
        final (cols, rows) = _effectiveFootprint(entry, moving.rotation);
        final occ = _occupiedTiles(items, excludeId: movingId);
        if (!_fits(col, row, cols, rows) || _overlaps(col, row, cols, rows, occ)) return;
      } else if (!_fits(col, row, entry.footprintCols, entry.footprintRows)) {
        return;
      }
      HapticFeedback.lightImpact();
      await ref.read(firestoreServiceProvider).moveHomeDecorItem(coupleId, movingId, col, row);
      _cancelPlacing();
      return;
    }

    if (_placingCatalogId != null) {
      final entry = catalogEntryFor(_placingCatalogId!);
      if (entry == null) return;
      if (!entry.isRug) {
        final occ = _occupiedTiles(items);
        if (!_fits(col, row, entry.footprintCols, entry.footprintRows) ||
            _overlaps(col, row, entry.footprintCols, entry.footprintRows, occ)) {
          return;
        }
      } else if (!_fits(col, row, entry.footprintCols, entry.footprintRows)) {
        return;
      }
      HapticFeedback.mediumImpact();
      final newItem = HomeDecorItem(
        id: const Uuid().v4(),
        catalogId: entry.id,
        col: col,
        row: row,
        placedBy: uid,
        placedAt: DateTime.now(),
      );
      await ref.read(firestoreServiceProvider).placeHomeDecorItem(coupleId, newItem);
      _cancelPlacing();
    }
  }

  void _handleSceneTap(Offset local, List<_PlacedRender> renders, List<HomeDecorItem> rawItems) {
    final lx = local.dx - _kOrigin.dx;
    final ly = local.dy - _kOrigin.dy;
    final a = lx / (kIsoTileW / 2);
    final b = ly / (kIsoTileH / 2);
    final col = ((a + b) / 2).floor();
    final row = ((b - a) / 2).floor();

    if (_isPlacing) {
      _handleTileTap(col, row, rawItems);
      return;
    }

    // Hit-test placed items, front-most first.
    final sorted = [...renders]..sort((x, y) => y.depth.compareTo(x.depth));
    for (final r in sorted) {
      final box = _isoBoxFor(r.item.col, r.item.row, r.cols, r.rows, r.entry.heightPx);
      final rect = box.topLeft & box.size;
      if (rect.contains(local)) {
        _showItemActions(r);
        return;
      }
    }
  }

  Future<bool?> _confirmRemove(String label) => showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.bgCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Remove item?', style: TextStyle(color: AppColors.textPrimary)),
          content: Text('"$label"', style: const TextStyle(color: AppColors.textSecondary)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Remove', style: TextStyle(color: AppColors.rose)),
            ),
          ],
        ),
      );

  void _showItemActions(_PlacedRender r) {
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
              Text(r.entry.emoji, style: const TextStyle(fontSize: 26)),
              const SizedBox(width: 12),
              Text(r.entry.label,
                  style: const TextStyle(
                      color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 14),
            if (r.entry.routeTo != null)
              _ActionTile(
                icon: Icons.open_in_new_rounded,
                label: r.entry.routeLabel ?? 'Open',
                onTap: () {
                  Navigator.pop(sheetCtx);
                  context.push(r.entry.routeTo!);
                },
              ),
            _ActionTile(
              icon: Icons.open_with_rounded,
              label: 'Move',
              onTap: () {
                Navigator.pop(sheetCtx);
                setState(() {
                  _movingItemId = r.item.id;
                  _placingCatalogId = null;
                });
              },
            ),
            if (r.entry.rotatable)
              _ActionTile(
                icon: Icons.rotate_right_rounded,
                label: 'Rotate',
                onTap: () async {
                  Navigator.pop(sheetCtx);
                  if (coupleId == null) return;
                  await ref.read(firestoreServiceProvider).rotateHomeDecorItem(
                      coupleId, r.item.id, (r.item.rotation + 90) % 360);
                },
              ),
            _ActionTile(
              icon: Icons.delete_outline_rounded,
              label: 'Remove',
              color: AppColors.rose,
              onTap: () async {
                Navigator.pop(sheetCtx);
                final confirm = await _confirmRemove(r.entry.label);
                if (confirm == true && coupleId != null) {
                  await ref.read(firestoreServiceProvider).removeHomeDecorItem(coupleId, r.item.id);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showStylePicker(HomeRoomStyle style) {
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
            _StyleRow(
              label: 'Floor',
              swatches: kHomeFloorOptions
                  .map((o) => _Swatch(
                        id: o.id,
                        label: o.label,
                        color: o.primary,
                        selected: o.id == style.floorId,
                        onTap: () => coupleId == null
                            ? null
                            : ref.read(firestoreServiceProvider).setHomeRoomStyle(coupleId, floorId: o.id),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 14),
            _StyleRow(
              label: 'Wall',
              swatches: kHomeWallOptions
                  .map((o) => _Swatch(
                        id: o.id,
                        label: o.label,
                        color: o.color,
                        selected: o.id == style.wallId,
                        onTap: () => coupleId == null
                            ? null
                            : ref.read(firestoreServiceProvider).setHomeRoomStyle(coupleId, wallId: o.id),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 14),
            _StyleRow(
              label: 'Lighting',
              swatches: kHomeLightingOptions
                  .map((o) => _Swatch(
                        id: o.id,
                        label: o.label,
                        color: Color.alphaBlend(o.tint, AppColors.bgCard),
                        selected: o.id == style.lightingId,
                        onTap: () => coupleId == null
                            ? null
                            : ref.read(firestoreServiceProvider)
                                .setHomeRoomStyle(coupleId, lightingId: o.id),
                      ))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  void _showMyItems(List<HomeDecorItem> initialItems) {
    final coupleId = ref.read(coupleIdProvider);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetCtx) {
        final items = List<HomeDecorItem>.from(initialItems);
        return StatefulBuilder(
          builder: (ctx, setSheetState) => Container(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.7),
            padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).padding.bottom + 20),
            decoration: const BoxDecoration(
              color: AppColors.bgMid,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              border: Border(top: BorderSide(color: AppColors.divider, width: 0.5)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('My Items',
                        style: TextStyle(
                            color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
                    const Spacer(),
                    Text('${items.length}', style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 12),
                if (items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 30),
                    child: Text('Nothing placed yet — tap an item below to add it.',
                        style: TextStyle(color: AppColors.textMuted)),
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: items.length,
                      separatorBuilder: (_, _) =>
                          const Divider(color: AppColors.divider, height: 1),
                      itemBuilder: (_, i) {
                        final item = items[i];
                        final entry = catalogEntryFor(item.catalogId);
                        if (entry == null) return const SizedBox.shrink();
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Text(entry.emoji, style: const TextStyle(fontSize: 22)),
                          title: Text(entry.label,
                              style: const TextStyle(
                                  color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, color: AppColors.rose),
                            onPressed: () async {
                              final confirm = await _confirmRemove(entry.label);
                              if (confirm == true && coupleId != null) {
                                await ref
                                    .read(firestoreServiceProvider)
                                    .removeHomeDecorItem(coupleId, item.id);
                                setSheetState(() => items.removeAt(i));
                              }
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
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final placed = ref.watch(homeDecorProvider).valueOrNull ?? [];
    final style = ref.watch(homeRoomStyleProvider).valueOrNull ?? const HomeRoomStyle();
    final floor = floorOptionFor(style.floorId);
    final wall = wallOptionFor(style.wallId);
    final lighting = lightingOptionFor(style.lightingId);
    final roomObjects = ref.watch(roomObjectsProvider).valueOrNull ?? [];
    final memories = ref.watch(memoriesProvider).valueOrNull ?? [];

    final photoFrameRefs = roomObjects
        .where((o) => o.type == RoomObjectType.photoFrame)
        .map((o) => o.sourceRef)
        .toList();
    final photoUrls = <String>[];
    for (final sourceRef in photoFrameRefs.reversed) {
      final mem = memories.where((m) => m.id == sourceRef).firstOrNull;
      if (mem != null) photoUrls.add(mem.imageUrl);
      if (photoUrls.length >= 3) break;
    }
    final trophyCount = roomObjects.where((o) => o.type == RoomObjectType.bucketTrophy).length;

    final renders = placed.map((it) {
      final entry = catalogEntryFor(it.catalogId);
      if (entry == null) return null;
      final (cols, rows) = _effectiveFootprint(entry, it.rotation);
      return _PlacedRender(
        item: it,
        entry: entry,
        cols: cols,
        rows: rows,
        trophyCount: entry.id == 'trophy_shelf' ? trophyCount : null,
        photoUrls: entry.id == 'photo_wall' ? photoUrls : const [],
      );
    }).whereType<_PlacedRender>().toList()
      ..sort((a, b) => a.depth.compareTo(b.depth));

    final occupiedForHighlight = _occupiedTiles(placed, excludeId: _movingItemId);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            _Header(
              isPlacing: _isPlacing,
              onCancel: _cancelPlacing,
              onBack: () => Navigator.maybePop(context),
              onStyleTap: () => _showStylePicker(style),
              onMyItemsTap: () => _showMyItems(placed),
            ),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: GestureDetector(
                      onTapUp: (d) => _handleSceneTap(d.localPosition, renders, placed),
                      child: SizedBox(
                        width: _kCanvasW,
                        height: _kCanvasH,
                        child: Stack(
                          children: [
                            AnimatedBuilder(
                              animation: _glow,
                              builder: (_, _) => CustomPaint(
                                size: const Size(_kCanvasW, _kCanvasH),
                                painter: _IsoScenePainter(
                                  floor: floor,
                                  wall: wall,
                                  lighting: lighting,
                                  glowT: _glow.value,
                                  items: renders,
                                  highlightTiles: _isPlacing ? occupiedForHighlight : null,
                                ),
                              ),
                            ),
                            for (final r in renders)
                              if (r.entry.id == 'photo_wall' && r.photoUrls.isNotEmpty)
                                ..._buildPhotoThumbs(r),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            _InventoryDrawer(
              placingId: _placingCatalogId,
              onSelect: (id) => setState(() {
                _movingItemId = null;
                _placingCatalogId = _placingCatalogId == id ? null : id;
              }),
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
                ? Text('Tap a tile to place it',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textPrimary.withValues(alpha: 0.9), fontSize: 14))
                : Text('Our Home',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.displayMedium?.copyWith(fontSize: 22)),
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

class _InventoryDrawer extends StatefulWidget {
  final String? placingId;
  final ValueChanged<String> onSelect;

  const _InventoryDrawer({required this.placingId, required this.onSelect});

  @override
  State<_InventoryDrawer> createState() => _InventoryDrawerState();
}

class _InventoryDrawerState extends State<_InventoryDrawer> {
  HomeCategory _category = HomeCategory.furniture;

  @override
  Widget build(BuildContext context) {
    final items = itemsInCategory(_category);
    return Container(
      height: 178,
      decoration: const BoxDecoration(
        color: AppColors.bgMid,
        border: Border(top: BorderSide(color: AppColors.divider, width: 0.5)),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              children: HomeCategory.values
                  .map((c) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: _CategoryChip(
                          category: c,
                          selected: _category == c,
                          onTap: () => setState(() => _category = c),
                        ),
                      ))
                  .toList(),
            ),
          ),
          const Divider(height: 1, color: AppColors.divider),
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              children: items
                  .map((e) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        child: _CatalogChip(
                          entry: e,
                          selected: widget.placingId == e.id,
                          onTap: () => widget.onSelect(e.id),
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

class _CategoryChip extends StatelessWidget {
  final HomeCategory category;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryChip({required this.category, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SquishyTap(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.rose.withValues(alpha: 0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? AppColors.rose : AppColors.divider),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(homeCategoryEmoji(category), style: const TextStyle(fontSize: 13)),
            const SizedBox(width: 5),
            Text(homeCategoryLabel(category),
                style: TextStyle(
                  color: selected ? AppColors.rose : AppColors.textSecondary,
                  fontSize: 11.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
                )),
          ],
        ),
      ),
    );
  }
}

class _CatalogChip extends StatelessWidget {
  final HomeCatalogEntry entry;
  final bool selected;
  final VoidCallback onTap;

  const _CatalogChip({required this.entry, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SquishyTap(
      onTap: onTap,
      child: Container(
        width: 68,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: selected ? entry.color.withValues(alpha: 0.28) : AppColors.bgCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? entry.color : AppColors.divider,
            width: selected ? 1.5 : 0.5,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(entry.emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(height: 4),
            Text(entry.label,
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

// ─── Action sheet row ────────────────────────────────────────────────────

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback onTap;

  const _ActionTile({required this.icon, required this.label, this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.textPrimary;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: c),
      title: Text(label, style: TextStyle(color: c, fontWeight: FontWeight.w600)),
      onTap: onTap,
    );
  }
}

// ─── Style picker rows ───────────────────────────────────────────────────

class _StyleRow extends StatelessWidget {
  final String label;
  final List<Widget> swatches;

  const _StyleRow({required this.label, required this.swatches});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(),
            style: const TextStyle(
                color: AppColors.rose, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
        const SizedBox(height: 8),
        SizedBox(
          height: 68,
          child: ListView(scrollDirection: Axis.horizontal, children: swatches),
        ),
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  final String id;
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback? onTap;

  const _Swatch({
    required this.id,
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: SquishyTap(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                    color: selected ? AppColors.textPrimary : Colors.white24,
                    width: selected ? 2.5 : 1),
              ),
              child: selected
                  ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
                  : null,
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: 56,
              child: Text(label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 9)),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── The isometric scene painter ─────────────────────────────────────────

class _IsoScenePainter extends CustomPainter {
  final HomeFloorOption floor;
  final HomeWallOption wall;
  final HomeLightingOption lighting;
  final double glowT;
  final List<_PlacedRender> items;
  final Set<String>? highlightTiles; // non-null while placing

  _IsoScenePainter({
    required this.floor,
    required this.wall,
    required this.lighting,
    required this.glowT,
    required this.items,
    required this.highlightTiles,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _paintWalls(canvas);
    _paintFloor(canvas);
    if (highlightTiles != null) _paintHighlights(canvas);
    for (final r in items) {
      _paintItem(canvas, r);
    }
    _paintLighting(canvas, size);
  }

  void _paintWalls(Canvas canvas) {
    final nTop = isoToScreen(0, 0) + _kOrigin - const Offset(0, _kWallHeight);
    final nRight = isoToScreen(kIsoGridSize.toDouble(), 0) + _kOrigin - const Offset(0, _kWallHeight);
    final nTopGround = isoToScreen(0, 0) + _kOrigin;
    final nRightGround = isoToScreen(kIsoGridSize.toDouble(), 0) + _kOrigin;
    final wBottom = isoToScreen(0, kIsoGridSize.toDouble()) + _kOrigin - const Offset(0, _kWallHeight);
    final wBottomGround = isoToScreen(0, kIsoGridSize.toDouble()) + _kOrigin;

    final northPaint = Paint()..color = _darken(wall.color, 0.06);
    final westPaint = Paint()..color = _darken(wall.color, 0.18);

    final northPath = Path()
      ..moveTo(nTop.dx, nTop.dy)
      ..lineTo(nRight.dx, nRight.dy)
      ..lineTo(nRightGround.dx, nRightGround.dy)
      ..lineTo(nTopGround.dx, nTopGround.dy)
      ..close();
    canvas.drawPath(northPath, northPaint);

    final westPath = Path()
      ..moveTo(nTop.dx, nTop.dy)
      ..lineTo(wBottom.dx, wBottom.dy)
      ..lineTo(wBottomGround.dx, wBottomGround.dy)
      ..lineTo(nTopGround.dx, nTopGround.dy)
      ..close();
    canvas.drawPath(westPath, westPaint);

    final lineColor = Colors.black.withValues(alpha: 0.15);
    _drawWallLines(canvas, nTop, nRight, nTopGround, nRightGround, lineColor);
    _drawWallLines(canvas, nTop, wBottom, nTopGround, wBottomGround, lineColor);
  }

  void _drawWallLines(
      Canvas canvas, Offset topLeft, Offset topRight, Offset botLeft, Offset botRight, Color color) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    if (wall.pattern == WallPattern.brick) {
      for (var i = 1; i < 6; i++) {
        final t = i / 6;
        canvas.drawLine(_lerpOffset(topLeft, botLeft, t), _lerpOffset(topRight, botRight, t), paint);
      }
    } else if (wall.pattern == WallPattern.panel) {
      for (var i = 1; i < 4; i++) {
        final t = i / 4;
        canvas.drawLine(_lerpOffset(topLeft, topRight, t), _lerpOffset(botLeft, botRight, t), paint);
      }
    }
  }

  void _paintFloor(Canvas canvas) {
    final border = Paint()
      ..color = Colors.black.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var col = 0; col < kIsoGridSize; col++) {
      for (var row = 0; row < kIsoGridSize; row++) {
        final top = isoToScreen(col.toDouble(), row.toDouble()) + _kOrigin;
        final right = isoToScreen(col + 1.0, row.toDouble()) + _kOrigin;
        final bottom = isoToScreen(col + 1.0, row + 1.0) + _kOrigin;
        final left = isoToScreen(col.toDouble(), row + 1.0) + _kOrigin;
        final path = Path()
          ..moveTo(top.dx, top.dy)
          ..lineTo(right.dx, right.dy)
          ..lineTo(bottom.dx, bottom.dy)
          ..lineTo(left.dx, left.dy)
          ..close();
        Color fill;
        switch (floor.pattern) {
          case FloorPattern.checker:
            fill = (col + row).isEven ? floor.primary : floor.secondary;
          case FloorPattern.planks:
          case FloorPattern.solid:
            fill = floor.primary;
        }
        canvas.drawPath(path, Paint()..color = fill);
        canvas.drawPath(path, border);
        if (floor.pattern == FloorPattern.planks) {
          final mid1 = _lerpOffset(left, top, 0.5);
          final mid2 = _lerpOffset(bottom, right, 0.5);
          canvas.drawLine(
              mid1, mid2, Paint()..color = floor.secondary.withValues(alpha: 0.4)..strokeWidth = 1);
        }
      }
    }
  }

  void _paintHighlights(Canvas canvas) {
    final okPaint = Paint()..color = const Color(0x555FBF77);
    final blockedPaint = Paint()..color = const Color(0x55E05555);
    for (var col = 0; col < kIsoGridSize; col++) {
      for (var row = 0; row < kIsoGridSize; row++) {
        final occupied = highlightTiles!.contains('$col,$row');
        final top = isoToScreen(col.toDouble(), row.toDouble()) + _kOrigin;
        final right = isoToScreen(col + 1.0, row.toDouble()) + _kOrigin;
        final bottom = isoToScreen(col + 1.0, row + 1.0) + _kOrigin;
        final left = isoToScreen(col.toDouble(), row + 1.0) + _kOrigin;
        final path = Path()
          ..moveTo(top.dx, top.dy)
          ..lineTo(right.dx, right.dy)
          ..lineTo(bottom.dx, bottom.dy)
          ..lineTo(left.dx, left.dy)
          ..close();
        canvas.drawPath(path, occupied ? blockedPaint : okPaint);
      }
    }
  }

  void _paintItem(Canvas canvas, _PlacedRender r) {
    final box = _isoBoxFor(r.item.col, r.item.row, r.cols, r.rows, r.entry.heightPx);
    final o = _kOrigin + box.topLeft;
    final cols = r.cols.toDouble();
    final rows = r.rows.toDouble();
    final h = r.entry.heightPx;

    Offset p(double dx, double dy) => o + Offset(dx, dy);

    final top = p(rows * kIsoTileW / 2, 0);
    final right = p(rows * kIsoTileW / 2 + cols * kIsoTileW / 2, cols * kIsoTileH / 2);
    final bottom = p(cols * kIsoTileW / 2, (cols + rows) * kIsoTileH / 2);
    final left = p(0, rows * kIsoTileH / 2);
    final groundBottom = bottom + Offset(0, h);
    final groundLeft = left + Offset(0, h);
    final groundRight = right + Offset(0, h);
    final center = Offset((top.dx + bottom.dx) / 2, (top.dy + bottom.dy) / 2);

    final g = _ItemGeom(
      top: top,
      right: right,
      bottom: bottom,
      left: left,
      groundBottom: groundBottom,
      groundLeft: groundLeft,
      groundRight: groundRight,
      center: center,
      h: h,
      base: r.entry.color,
      accent: r.entry.accent ?? _lighten(r.entry.color, 0.45),
    );

    if (r.entry.isRug) {
      _drawRug(canvas, g);
      return;
    }

    if (r.entry.glow) {
      _drawGlowHalo(canvas, g.center, g.accent);
    }

    switch (r.entry.shape) {
      case HomeItemShape.seating:
        _drawSeating(canvas, g);
      case HomeItemShape.table:
        _drawTable(canvas, g);
      case HomeItemShape.shelfUnit:
        _drawShelfUnit(canvas, g);
      case HomeItemShape.plant:
        _drawPlant(canvas, g);
      case HomeItemShape.vase:
        _drawVase(canvas, g);
      case HomeItemShape.lampGlow:
        _drawLampGlow(canvas, g);
      case HomeItemShape.wallFlat:
        _drawWallFlat(canvas, g);
      case HomeItemShape.postBox:
        _drawPostBox(canvas, g);
      case HomeItemShape.electronics:
        _drawElectronics(canvas, g);
      case HomeItemShape.instrument:
        _drawInstrument(canvas, g);
      case HomeItemShape.blob:
        _drawBlob(canvas, g);
      case HomeItemShape.box:
      case HomeItemShape.rug:
        _drawBox(canvas, g);
    }

    final emojiOffset = r.entry.shape == HomeItemShape.wallFlat
        ? g.center
        : g.center + const Offset(0, -6);
    _drawEmoji(canvas, emojiOffset, r.entry.emoji, 15);

    if (r.trophyCount != null && r.trophyCount! > 0) {
      _drawBadge(canvas, g.center + const Offset(18, -16), '${r.trophyCount}', AppColors.gold);
    }
  }

  // ── Shape drawers ─────────────────────────────────────────────────────

  Path _quad(Offset a, Offset b, Offset c, Offset d) => Path()
    ..moveTo(a.dx, a.dy)
    ..lineTo(b.dx, b.dy)
    ..lineTo(c.dx, c.dy)
    ..lineTo(d.dx, d.dy)
    ..close();

  void _strokeEdges(Canvas canvas, List<Path> faces) {
    final paint = Paint()
      ..color = Colors.black.withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final f in faces) {
      canvas.drawPath(f, paint);
    }
  }

  void _drawBoxFaces(Canvas canvas, _ItemGeom g, {double? overrideHeightFraction}) {
    final frac = overrideHeightFraction ?? 1.0;
    final top = g.top + Offset(0, g.h * (1 - frac));
    final right = g.right + Offset(0, g.h * (1 - frac));
    final bottom = g.bottom + Offset(0, g.h * (1 - frac));
    final left = g.left + Offset(0, g.h * (1 - frac));
    final topFace = _quad(top, right, bottom, left);
    final leftFace = _quad(left, bottom, g.groundBottom, g.groundLeft);
    final rightFace = _quad(right, bottom, g.groundBottom, g.groundRight);
    canvas.drawPath(leftFace, Paint()..color = _darken(g.base, 0.3));
    canvas.drawPath(rightFace, Paint()..color = _darken(g.base, 0.45));
    canvas.drawPath(
        topFace, Paint()..shader = ui.Gradient.linear(top, bottom, [_lighten(g.base, 0.24), g.base]));
    _strokeEdges(canvas, [topFace, leftFace, rightFace]);
  }

  void _drawBox(Canvas canvas, _ItemGeom g) => _drawBoxFaces(canvas, g);

  void _drawRug(Canvas canvas, _ItemGeom g) {
    final topFace = _quad(g.top, g.right, g.bottom, g.left);
    canvas.drawPath(topFace, Paint()..color = g.base.withValues(alpha: 0.88));
    canvas.save();
    canvas.clipPath(topFace);
    final inset = Path()
      ..addPolygon([
        Offset.lerp(g.top, g.center, 0.35)!,
        Offset.lerp(g.right, g.center, 0.35)!,
        Offset.lerp(g.bottom, g.center, 0.35)!,
        Offset.lerp(g.left, g.center, 0.35)!,
      ], true);
    canvas.drawPath(
        inset,
        Paint()
          ..color = _darken(g.base, 0.25)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);
    canvas.restore();
    canvas.drawPath(
        topFace,
        Paint()
          ..color = _darken(g.base, 0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);
  }

  void _drawSeating(Canvas canvas, _ItemGeom g) {
    _drawBoxFaces(canvas, g, overrideHeightFraction: 0.55);
    // Backrest shadow along the far edge + two armrest accents on the corners.
    final topFace = _quad(g.top, g.right, g.bottom, g.left);
    canvas.save();
    canvas.clipPath(topFace);
    canvas.drawPath(
        _quad(g.top, Offset.lerp(g.top, g.right, 0.5)!, Offset.lerp(g.left, g.bottom, 0.35)!, g.left),
        Paint()..color = _darken(g.base, 0.2));
    canvas.restore();
    for (final corner in [g.left, g.right]) {
      canvas.drawCircle(Offset.lerp(corner, g.center, 0.55)!, 5, Paint()..color = _lighten(g.base, 0.1));
    }
  }

  void _drawTable(Canvas canvas, _ItemGeom g) {
    _drawBoxFaces(canvas, g);
    final topFace = _quad(g.top, g.right, g.bottom, g.left);
    canvas.save();
    canvas.clipPath(topFace);
    final inset = Path()
      ..addPolygon([
        Offset.lerp(g.top, g.center, 0.3)!,
        Offset.lerp(g.right, g.center, 0.3)!,
        Offset.lerp(g.bottom, g.center, 0.3)!,
        Offset.lerp(g.left, g.center, 0.3)!,
      ], true);
    canvas.drawPath(inset, Paint()..color = _lighten(g.base, 0.18).withValues(alpha: 0.7));
    canvas.restore();
  }

  void _drawShelfUnit(Canvas canvas, _ItemGeom g) {
    _drawBoxFaces(canvas, g);
    final shelfPaint = Paint()
      ..color = _darken(g.base, 0.5)
      ..strokeWidth = 1.4;
    for (var i = 1; i < 4; i++) {
      final t = i / 4;
      final l = Offset.lerp(g.left, g.groundLeft, t)!;
      final b = Offset.lerp(g.bottom, g.groundBottom, t)!;
      final rr = Offset.lerp(g.right, g.groundRight, t)!;
      canvas.drawLine(l, b, shelfPaint);
      canvas.drawLine(rr, b, shelfPaint);
    }
    const bookColors = [Color(0xFF8B3A3A), Color(0xFF2E5E8E), Color(0xFFB5681F), Color(0xFF4A7C59)];
    for (var i = 0; i < 4; i++) {
      final t = 0.15 + i * 0.16;
      final base = Offset.lerp(g.left, g.bottom, t)!;
      final top = base - const Offset(0, 8);
      canvas.drawLine(base, top, Paint()..color = bookColors[i % bookColors.length]..strokeWidth = 3.5);
    }
  }

  void _drawPlant(Canvas canvas, _ItemGeom g) {
    _drawBoxFaces(canvas, g, overrideHeightFraction: 0.4);
    final potTop = g.center + Offset(0, g.h * 0.3);
    final greens = [_darken(g.base, 0.1), g.base, _lighten(g.base, 0.15)];
    for (var i = 0; i < 3; i++) {
      final dx = (i - 1) * 8.0;
      final dy = -g.h * 0.35 - i * 6;
      canvas.drawCircle(potTop + Offset(dx, dy), 11 - i.toDouble(), Paint()..color = greens[i]);
    }
  }

  void _drawVase(Canvas canvas, _ItemGeom g) {
    _drawBoxFaces(canvas, g, overrideHeightFraction: 0.7);
    final neck = g.center + Offset(0, -g.h * 0.35);
    const petalColors = [Color(0xFFFF6B8A), Color(0xFFFFD166), Color(0xFFB8A0D9)];
    for (var i = 0; i < 3; i++) {
      final angle = i * 2.4;
      canvas.drawCircle(neck + Offset(math.cos(angle) * 6, math.sin(angle) * 4 - 6), 6,
          Paint()..color = petalColors[i % petalColors.length]);
    }
  }

  void _drawLampGlow(Canvas canvas, _ItemGeom g) {
    _drawBoxFaces(canvas, g, overrideHeightFraction: 0.5);
  }

  void _drawGlowHalo(Canvas canvas, Offset center, Color color) {
    final radius = 20.0 + 5 * glowT;
    final paint = Paint()
      ..shader = ui.Gradient.radial(
          center, radius, [color.withValues(alpha: 0.5), color.withValues(alpha: 0)]);
    canvas.drawCircle(center, radius, paint);
  }

  void _drawWallFlat(Canvas canvas, _ItemGeom g) {
    const thin = 5.0;
    final top = g.top;
    final right = g.right;
    final bottom = g.bottom;
    final left = g.left;
    final groundBottom = bottom + const Offset(0, thin);
    final groundLeft = left + const Offset(0, thin);
    final groundRight = right + const Offset(0, thin);
    final topFace = _quad(top, right, bottom, left);
    final leftFace = _quad(left, bottom, groundBottom, groundLeft);
    final rightFace = _quad(right, bottom, groundBottom, groundRight);
    canvas.drawPath(leftFace, Paint()..color = _darken(g.base, 0.3));
    canvas.drawPath(rightFace, Paint()..color = _darken(g.base, 0.4));
    canvas.drawPath(topFace, Paint()..color = g.base);
    canvas.save();
    canvas.clipPath(topFace);
    final inset = Path()
      ..addPolygon([
        Offset.lerp(top, g.center, 0.28)!,
        Offset.lerp(right, g.center, 0.28)!,
        Offset.lerp(bottom, g.center, 0.28)!,
        Offset.lerp(left, g.center, 0.28)!,
      ], true);
    canvas.drawPath(
        inset,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);
    canvas.restore();
    _strokeEdges(canvas, [topFace]);
  }

  void _drawPostBox(Canvas canvas, _ItemGeom g) {
    canvas.drawLine(g.center + Offset(0, -g.h * 0.1), g.groundBottom,
        Paint()..color = _darken(g.base, 0.5)..strokeWidth = 3);
    _drawBoxFaces(canvas, g, overrideHeightFraction: 0.45);
  }

  void _drawElectronics(Canvas canvas, _ItemGeom g) {
    _drawBoxFaces(canvas, g);
    final leftFace = _quad(g.left, g.bottom, g.groundBottom, g.groundLeft);
    canvas.save();
    canvas.clipPath(leftFace);
    final inset = Path()
      ..addPolygon([
        Offset.lerp(g.left, g.bottom, 0.2)!,
        Offset.lerp(g.left, g.bottom, 0.8)!,
        Offset.lerp(g.groundLeft, g.groundBottom, 0.8)!,
        Offset.lerp(g.groundLeft, g.groundBottom, 0.2)!,
      ], true);
    canvas.drawPath(inset, Paint()..color = g.accent.withValues(alpha: 0.85));
    canvas.restore();
  }

  void _drawInstrument(Canvas canvas, _ItemGeom g) {
    _drawBoxFaces(canvas, g);
    final topFace = _quad(g.top, g.right, g.bottom, g.left);
    canvas.save();
    canvas.clipPath(topFace);
    for (var i = 0; i < 4; i++) {
      final t = i / 4;
      final a = Offset.lerp(g.top, g.left, t)!;
      final b = Offset.lerp(g.right, g.bottom, t)!;
      canvas.drawLine(a, b,
          Paint()..color = (i.isEven ? g.accent : _darken(g.base, 0.3)).withValues(alpha: 0.8)..strokeWidth = 3);
    }
    canvas.restore();
  }

  void _drawBlob(Canvas canvas, _ItemGeom g) {
    final rect = Rect.fromPoints(g.left, g.right).inflate(4).translate(0, g.h * 0.3);
    canvas.drawOval(rect.shift(const Offset(0, 4)), Paint()..color = Colors.black.withValues(alpha: 0.15));
    canvas.drawOval(rect, Paint()..color = g.base);
    canvas.drawOval(
        rect.deflate(6).shift(const Offset(0, -3)), Paint()..color = _lighten(g.base, 0.15));
  }

  void _drawEmoji(Canvas canvas, Offset center, String emoji, double fontSize) {
    final tp = TextPainter(
      text: TextSpan(text: emoji, style: TextStyle(fontSize: fontSize)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  void _drawBadge(Canvas canvas, Offset center, String text, Color bg) {
    final tp = TextPainter(
      text: TextSpan(
          text: text,
          style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
      textDirection: TextDirection.ltr,
    )..layout();
    final r = math.max(tp.width, tp.height) / 2 + 5;
    canvas.drawCircle(center, r, Paint()..color = bg);
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  void _paintLighting(Canvas canvas, Size size) {
    var tint = lighting.tint;
    if (lighting.animated) {
      final a = (tint.a * (0.6 + 0.4 * glowT)).clamp(0.0, 1.0);
      tint = tint.withValues(alpha: a);
    }
    canvas.drawRect(Offset.zero & size, Paint()..color = tint);
  }

  @override
  bool shouldRepaint(covariant _IsoScenePainter oldDelegate) => true;
}

class _ItemGeom {
  final Offset top, right, bottom, left, groundBottom, groundLeft, groundRight, center;
  final double h;
  final Color base;
  final Color accent;

  const _ItemGeom({
    required this.top,
    required this.right,
    required this.bottom,
    required this.left,
    required this.groundBottom,
    required this.groundLeft,
    required this.groundRight,
    required this.center,
    required this.h,
    required this.base,
    required this.accent,
  });
}
