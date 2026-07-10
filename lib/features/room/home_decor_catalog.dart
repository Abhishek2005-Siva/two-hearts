import 'package:flutter/material.dart';

// ─── Isometric projection constants ────────────────────────────────────────

const double kIsoTileW = 64;
const double kIsoTileH = 32;
const int kIsoGridSize = 6;

Offset isoToScreen(double col, double row) =>
    Offset((col - row) * (kIsoTileW / 2), (col + row) * (kIsoTileH / 2));

// ─── Furniture / decor catalog ─────────────────────────────────────────────

class HomeCatalogEntry {
  final String id;
  final String label;
  final String emoji;
  final Color color;
  final int footprintCols;
  final int footprintRows;
  final double heightPx;
  final bool rotatable;
  final bool isRug;
  final String? routeTo;
  final String? routeLabel;

  const HomeCatalogEntry({
    required this.id,
    required this.label,
    required this.emoji,
    required this.color,
    this.footprintCols = 1,
    this.footprintRows = 1,
    this.heightPx = 34,
    this.rotatable = false,
    this.isRug = false,
    this.routeTo,
    this.routeLabel,
  });
}

const List<HomeCatalogEntry> kHomeDecorCatalog = [
  HomeCatalogEntry(
    id: 'sofa',
    label: 'Sofa',
    emoji: '🛋️',
    color: Color(0xFF8B4A6A),
    footprintCols: 2,
    footprintRows: 1,
    heightPx: 30,
    rotatable: true,
  ),
  HomeCatalogEntry(
    id: 'rug',
    label: 'Rug',
    emoji: '🟫',
    color: Color(0xFFB5681F),
    footprintCols: 2,
    footprintRows: 2,
    heightPx: 2,
    isRug: true,
  ),
  HomeCatalogEntry(
    id: 'coffee_table',
    label: 'Coffee Table',
    emoji: '🪵',
    color: Color(0xFF6B4226),
    heightPx: 20,
  ),
  HomeCatalogEntry(
    id: 'plant',
    label: 'Indoor Plant',
    emoji: '🪴',
    color: Color(0xFF4A7C59),
    heightPx: 40,
  ),
  HomeCatalogEntry(
    id: 'lantern',
    label: 'Lantern',
    emoji: '🏮',
    color: Color(0xFFB5681F),
    heightPx: 36,
  ),
  HomeCatalogEntry(
    id: 'bookshelf',
    label: 'Bookshelf',
    emoji: '📚',
    color: Color(0xFF6B4226),
    heightPx: 50,
    routeTo: '/together/journal',
    routeLabel: 'Open Journal',
  ),
  HomeCatalogEntry(
    id: 'mailbox',
    label: 'Vintage Mailbox',
    emoji: '📮',
    color: Color(0xFF2E5E8E),
    heightPx: 38,
    routeTo: '/together/letter/new',
    routeLabel: 'Write a Letter',
  ),
  HomeCatalogEntry(
    id: 'photo_wall',
    label: 'Photo Wall',
    emoji: '🖼️',
    color: Color(0xFF7B4E9E),
    footprintCols: 2,
    footprintRows: 1,
    heightPx: 44,
    routeTo: '/memory',
    routeLabel: 'Open Memories',
  ),
  HomeCatalogEntry(
    id: 'trophy_shelf',
    label: 'Trophy Shelf',
    emoji: '🏆',
    color: Color(0xFF9E7B1A),
    heightPx: 42,
    routeTo: '/together/bucket',
    routeLabel: 'Open Bucket List',
  ),
  HomeCatalogEntry(
    id: 'vinyl_player',
    label: 'Vinyl Player',
    emoji: '🎵',
    color: Color(0xFF3D6E8E),
    heightPx: 26,
    routeTo: '/listen',
    routeLabel: 'Listen Together',
  ),
];

HomeCatalogEntry? catalogEntryFor(String id) {
  for (final e in kHomeDecorCatalog) {
    if (e.id == id) return e;
  }
  return null;
}

// ─── Floor styles ───────────────────────────────────────────────────────────

enum FloorPattern { solid, checker, planks }

class HomeFloorOption {
  final String id;
  final String label;
  final Color primary;
  final Color secondary;
  final FloorPattern pattern;

  const HomeFloorOption({
    required this.id,
    required this.label,
    required this.primary,
    required this.secondary,
    required this.pattern,
  });
}

const List<HomeFloorOption> kHomeFloorOptions = [
  HomeFloorOption(
    id: 'oak',
    label: 'Oak Wood',
    primary: Color(0xFF8B5A2B),
    secondary: Color(0xFF6B4226),
    pattern: FloorPattern.planks,
  ),
  HomeFloorOption(
    id: 'marble',
    label: 'Marble',
    primary: Color(0xFFE8E4DC),
    secondary: Color(0xFFD4CFC4),
    pattern: FloorPattern.solid,
  ),
  HomeFloorOption(
    id: 'checker',
    label: 'Checkerboard',
    primary: Color(0xFF2A2A2A),
    secondary: Color(0xFFE8E4DC),
    pattern: FloorPattern.checker,
  ),
  HomeFloorOption(
    id: 'slate',
    label: 'Slate Stone',
    primary: Color(0xFF4A5259),
    secondary: Color(0xFF3A4046),
    pattern: FloorPattern.solid,
  ),
];

HomeFloorOption floorOptionFor(String id) =>
    kHomeFloorOptions.firstWhere((o) => o.id == id, orElse: () => kHomeFloorOptions.first);

// ─── Wall styles ────────────────────────────────────────────────────────────

enum WallPattern { solid, brick, panel }

class HomeWallOption {
  final String id;
  final String label;
  final Color color;
  final WallPattern pattern;

  const HomeWallOption({
    required this.id,
    required this.label,
    required this.color,
    required this.pattern,
  });
}

const List<HomeWallOption> kHomeWallOptions = [
  HomeWallOption(
    id: 'cream_paint',
    label: 'Cream Paint',
    color: Color(0xFFEDE4D3),
    pattern: WallPattern.solid,
  ),
  HomeWallOption(
    id: 'sage_paint',
    label: 'Sage Paint',
    color: Color(0xFF6FBFA0),
    pattern: WallPattern.solid,
  ),
  HomeWallOption(
    id: 'brick',
    label: 'Exposed Brick',
    color: Color(0xFF8B4A3A),
    pattern: WallPattern.brick,
  ),
  HomeWallOption(
    id: 'wood_panel',
    label: 'Wood Panels',
    color: Color(0xFF6B4226),
    pattern: WallPattern.panel,
  ),
];

HomeWallOption wallOptionFor(String id) =>
    kHomeWallOptions.firstWhere((o) => o.id == id, orElse: () => kHomeWallOptions.first);

// ─── Lighting moods ─────────────────────────────────────────────────────────

class HomeLightingOption {
  final String id;
  final String label;
  final Color tint;
  final bool animated;

  const HomeLightingOption({
    required this.id,
    required this.label,
    required this.tint,
    this.animated = false,
  });
}

const List<HomeLightingOption> kHomeLightingOptions = [
  HomeLightingOption(id: 'warm', label: 'Warm', tint: Color(0x2EFFB74D)),
  HomeLightingOption(id: 'cool', label: 'Cool', tint: Color(0x2E4FC3F7)),
  HomeLightingOption(
      id: 'candlelight', label: 'Candlelight', tint: Color(0x40FF8A3D), animated: true),
];

HomeLightingOption lightingOptionFor(String id) =>
    kHomeLightingOptions.firstWhere((o) => o.id == id, orElse: () => kHomeLightingOptions.first);
