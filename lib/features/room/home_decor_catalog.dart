import 'package:flutter/material.dart';

// ─── Isometric projection constants ────────────────────────────────────────

const double kIsoTileW = 64;
const double kIsoTileH = 32;
const int kIsoGridSize = 6;

Offset isoToScreen(double col, double row) =>
    Offset((col - row) * (kIsoTileW / 2), (col + row) * (kIsoTileH / 2));

// ─── Shape families (how an item is actually drawn) ────────────────────────

enum HomeItemShape {
  box, // generic shaded block — the fallback
  seating, // block + raised backrest edge (sofas, chairs, benches)
  table, // low block with a flat highlighted top (tables, desks)
  shelfUnit, // tall block with shelf lines + small "book" accents
  plant, // pot + layered foliage clusters
  vase, // slim pot + flower cluster
  lampGlow, // post/base + soft radial glow (optionally animated)
  wallFlat, // thin flush rectangle with an inner border (frames, windows)
  postBox, // thin post + small box on top (mailboxes, feeders, poles)
  electronics, // flat dark block with a bright inset "screen"
  instrument, // block with light/dark stripe accents
  rug, // flat floor overlay, no height
  blob, // soft rounded cushion (bean bags, pet beds, hammocks)
}

// ─── Categories (for the inventory browser) ────────────────────────────────

enum HomeCategory {
  furniture,
  letterJournal,
  books,
  decorations,
  nature,
  tech,
  music,
  hobby,
  food,
  collectibles,
  relationship,
  pets,
  outdoor,
  magical,
}

String homeCategoryLabel(HomeCategory c) {
  switch (c) {
    case HomeCategory.furniture:
      return 'Furniture';
    case HomeCategory.letterJournal:
      return 'Letter & Journal';
    case HomeCategory.books:
      return 'Books & Knowledge';
    case HomeCategory.decorations:
      return 'Decorations';
    case HomeCategory.nature:
      return 'Nature';
    case HomeCategory.tech:
      return 'Technology';
    case HomeCategory.music:
      return 'Music';
    case HomeCategory.hobby:
      return 'Hobby';
    case HomeCategory.food:
      return 'Food';
    case HomeCategory.collectibles:
      return 'Collectibles';
    case HomeCategory.relationship:
      return 'Relationship';
    case HomeCategory.pets:
      return 'Pets';
    case HomeCategory.outdoor:
      return 'Windows & Outdoor';
    case HomeCategory.magical:
      return 'Magical';
  }
}

String homeCategoryEmoji(HomeCategory c) {
  switch (c) {
    case HomeCategory.furniture:
      return '🛋️';
    case HomeCategory.letterJournal:
      return '💌';
    case HomeCategory.books:
      return '📚';
    case HomeCategory.decorations:
      return '🖼️';
    case HomeCategory.nature:
      return '🪴';
    case HomeCategory.tech:
      return '💻';
    case HomeCategory.music:
      return '🎵';
    case HomeCategory.hobby:
      return '🎨';
    case HomeCategory.food:
      return '☕';
    case HomeCategory.collectibles:
      return '🏆';
    case HomeCategory.relationship:
      return '💞';
    case HomeCategory.pets:
      return '🐾';
    case HomeCategory.outdoor:
      return '🌇';
    case HomeCategory.magical:
      return '✨';
  }
}

// ─── Catalog entry ──────────────────────────────────────────────────────────

class HomeCatalogEntry {
  final String id;
  final String label;
  final String emoji;
  final Color color;
  final Color? accent;
  final HomeCategory category;
  final HomeItemShape shape;
  final int footprintCols;
  final int footprintRows;
  final double heightPx;
  final bool rotatable;
  final bool isRug;
  final bool glow;
  final String? routeTo;
  final String? routeLabel;
  // When set, the item renders as a real pre-rendered sprite image instead of
  // a vector-painted box. `spriteBase` is the asset path with no extension
  // and no direction suffix (e.g. 'assets/images/decor/bed'); if `rotatable`
  // is also true, four direction variants (_NE/_NW/_SE/_SW) are expected,
  // otherwise a single `${spriteBase}.png` is used. `spriteAspect` is the
  // sprite's native width/height ratio, used to size it without distortion.
  final String? spriteBase;
  final double spriteAspect;

  const HomeCatalogEntry({
    required this.id,
    required this.label,
    required this.emoji,
    required this.color,
    this.accent,
    required this.category,
    this.shape = HomeItemShape.box,
    this.footprintCols = 1,
    this.footprintRows = 1,
    this.heightPx = 26,
    this.rotatable = false,
    this.isRug = false,
    this.glow = false,
    this.routeTo,
    this.routeLabel,
    this.spriteBase,
    this.spriteAspect = 1.0,
  });
}

HomeCatalogEntry? catalogEntryFor(String id) {
  for (final e in kHomeDecorCatalog) {
    if (e.id == id) return e;
  }
  return null;
}

List<HomeCatalogEntry> itemsInCategory(HomeCategory c) =>
    kHomeDecorCatalog.where((e) => e.category == c).toList();

// ─── The catalog ────────────────────────────────────────────────────────────
//
// ~190 items across every category from the couple's wishlist. A handful of
// near-duplicate style variants (e.g. many single-word wallpaper/curtain
// variants) were consolidated into one representative entry rather than
// padded out 1:1. Interactive items only deep-link to screens/data that
// genuinely exist in the app (Journal, Letters, Memories, Bucket List,
// Listen Together, Games, Destinations, Profile) — nothing fakes a feature
// that isn't real (no fake "relationship health," "online status," or
// multi-room doors yet).

const List<HomeCatalogEntry> kHomeDecorCatalog = [
  // ── Furniture ──────────────────────────────────────────────────────────
  HomeCatalogEntry(id: 'bed', label: 'Bed', emoji: '🛏️', color: Color(0xFF6B3F5E), category: HomeCategory.furniture, shape: HomeItemShape.seating, footprintCols: 2, footprintRows: 2, heightPx: 24, spriteBase: 'assets/images/decor/bed', spriteAspect: 1.132),
  HomeCatalogEntry(id: 'sofa', label: 'Sofa', emoji: '🛋️', color: Color(0xFF8B4A6A), category: HomeCategory.furniture, shape: HomeItemShape.seating, footprintCols: 2, footprintRows: 1, heightPx: 28, rotatable: true, spriteBase: 'assets/images/decor/sofa', spriteAspect: 1.0),
  HomeCatalogEntry(id: 'loveseat', label: 'Loveseat', emoji: '🛋️', color: Color(0xFFB06A7A), category: HomeCategory.furniture, shape: HomeItemShape.seating, footprintCols: 2, footprintRows: 1, heightPx: 26, rotatable: true, spriteBase: 'assets/images/decor/loveseat', spriteAspect: 1.099),
  HomeCatalogEntry(id: 'armchair', label: 'Armchair', emoji: '🪑', color: Color(0xFF7B5A4A), category: HomeCategory.furniture, shape: HomeItemShape.seating, heightPx: 28, spriteBase: 'assets/images/decor/armchair', spriteAspect: 0.858),
  HomeCatalogEntry(id: 'bean_bag', label: 'Bean Bag', emoji: '🟤', color: Color(0xFF6B4A7A), category: HomeCategory.furniture, shape: HomeItemShape.blob, heightPx: 16),
  HomeCatalogEntry(id: 'ottoman', label: 'Ottoman', emoji: '🪑', color: Color(0xFFA07850), category: HomeCategory.furniture, shape: HomeItemShape.table, heightPx: 14, spriteBase: 'assets/images/decor/ottoman', spriteAspect: 1.057),
  HomeCatalogEntry(id: 'rocking_chair', label: 'Rocking Chair', emoji: '🪑', color: Color(0xFF6B4226), category: HomeCategory.furniture, shape: HomeItemShape.seating, heightPx: 30, spriteBase: 'assets/images/decor/rocking_chair', spriteAspect: 0.789),
  HomeCatalogEntry(id: 'window_seat', label: 'Window Seat', emoji: '🪟', color: Color(0xFFD8C4A0), category: HomeCategory.furniture, shape: HomeItemShape.seating, footprintCols: 2, heightPx: 18, spriteBase: 'assets/images/decor/window_seat', spriteAspect: 0.667),
  HomeCatalogEntry(id: 'hammock', label: 'Hammock', emoji: '🕸️', color: Color(0xFFD8B888), category: HomeCategory.furniture, shape: HomeItemShape.blob, footprintCols: 2, heightPx: 12),
  HomeCatalogEntry(id: 'swing_chair', label: 'Swing Chair', emoji: '🪑', color: Color(0xFFB5681F), category: HomeCategory.furniture, shape: HomeItemShape.seating, heightPx: 34),
  HomeCatalogEntry(id: 'coffee_table', label: 'Coffee Table', emoji: '🪵', color: Color(0xFF6B4226), category: HomeCategory.furniture, shape: HomeItemShape.table, heightPx: 16, spriteBase: 'assets/images/decor/coffee_table', spriteAspect: 1.078),
  HomeCatalogEntry(id: 'side_table', label: 'Side Table', emoji: '🪵', color: Color(0xFF7A5230), category: HomeCategory.furniture, shape: HomeItemShape.table, heightPx: 18, spriteBase: 'assets/images/decor/side_table', spriteAspect: 0.821),
  HomeCatalogEntry(id: 'study_desk', label: 'Study Desk', emoji: '📝', color: Color(0xFF8B5A2B), category: HomeCategory.furniture, shape: HomeItemShape.table, footprintCols: 2, heightPx: 22, spriteBase: 'assets/images/decor/study_desk', spriteAspect: 0.951),
  HomeCatalogEntry(id: 'vanity', label: 'Vanity', emoji: '💄', color: Color(0xFFEDE0C8), category: HomeCategory.furniture, shape: HomeItemShape.table, heightPx: 24, spriteBase: 'assets/images/decor/vanity', spriteAspect: 0.716),
  HomeCatalogEntry(id: 'dining_table', label: 'Dining Table', emoji: '🍽️', color: Color(0xFF6B3A22), category: HomeCategory.furniture, shape: HomeItemShape.table, footprintCols: 2, footprintRows: 2, heightPx: 20, spriteBase: 'assets/images/decor/dining_table', spriteAspect: 1.031),
  HomeCatalogEntry(id: 'breakfast_bar', label: 'Breakfast Bar', emoji: '🍳', color: Color(0xFF8B5A2B), category: HomeCategory.furniture, shape: HomeItemShape.table, footprintCols: 2, heightPx: 26, spriteBase: 'assets/images/decor/breakfast_bar', spriteAspect: 0.761),
  HomeCatalogEntry(id: 'nightstand', label: 'Nightstand', emoji: '🛌', color: Color(0xFF7A5230), category: HomeCategory.furniture, shape: HomeItemShape.table, heightPx: 16, spriteBase: 'assets/images/decor/nightstand', spriteAspect: 0.821),
  HomeCatalogEntry(id: 'tv_cabinet', label: 'TV Cabinet', emoji: '📺', color: Color(0xFF5A3A22), category: HomeCategory.furniture, shape: HomeItemShape.shelfUnit, footprintCols: 2, heightPx: 18, spriteBase: 'assets/images/decor/tv_cabinet', spriteAspect: 0.991),
  HomeCatalogEntry(id: 'console_table', label: 'Console Table', emoji: '🪞', color: Color(0xFFEDE0C8), category: HomeCategory.furniture, shape: HomeItemShape.table, footprintCols: 2, heightPx: 18, spriteBase: 'assets/images/decor/console_table', spriteAspect: 0.821),
  HomeCatalogEntry(id: 'shelf', label: 'Shelf', emoji: '📚', color: Color(0xFF8B5A2B), category: HomeCategory.furniture, shape: HomeItemShape.shelfUnit, heightPx: 32, spriteBase: 'assets/images/decor/shelf', spriteAspect: 0.744),
  HomeCatalogEntry(id: 'floating_shelves', label: 'Floating Shelves', emoji: '📚', color: Color(0xFF8B5A2B), category: HomeCategory.furniture, shape: HomeItemShape.shelfUnit, footprintCols: 2, heightPx: 10),
  HomeCatalogEntry(
    id: 'bookshelf',
    label: 'Bookshelf',
    emoji: '📚',
    color: Color(0xFF6B4226),
    category: HomeCategory.furniture,
    shape: HomeItemShape.shelfUnit,
    heightPx: 48,
    routeTo: '/together/journal',
    routeLabel: 'Open Journal',
    spriteBase: 'assets/images/decor/bookshelf',
    spriteAspect: 0.479,
  ),
  HomeCatalogEntry(id: 'display_cabinet', label: 'Display Cabinet', emoji: '🏺', color: Color(0xFF5A3A22), category: HomeCategory.furniture, shape: HomeItemShape.shelfUnit, heightPx: 40, spriteBase: 'assets/images/decor/display_cabinet', spriteAspect: 0.489),
  HomeCatalogEntry(id: 'wardrobe', label: 'Wardrobe', emoji: '👗', color: Color(0xFF4A2E18), category: HomeCategory.furniture, shape: HomeItemShape.shelfUnit, heightPx: 52, spriteBase: 'assets/images/decor/wardrobe', spriteAspect: 0.681),
  HomeCatalogEntry(id: 'drawer_chest', label: 'Drawer Chest', emoji: '🗄️', color: Color(0xFF7A5230), category: HomeCategory.furniture, shape: HomeItemShape.shelfUnit, heightPx: 28, spriteBase: 'assets/images/decor/drawer_chest', spriteAspect: 0.806),
  HomeCatalogEntry(id: 'shoe_rack', label: 'Shoe Rack', emoji: '👟', color: Color(0xFFA07850), category: HomeCategory.furniture, shape: HomeItemShape.shelfUnit, heightPx: 16),
  HomeCatalogEntry(id: 'coat_stand', label: 'Coat Stand', emoji: '🧥', color: Color(0xFF4A2E18), category: HomeCategory.furniture, shape: HomeItemShape.postBox, heightPx: 46, spriteBase: 'assets/images/decor/coat_stand', spriteAspect: 0.32),

  // ── Letter & Journal ───────────────────────────────────────────────────
  HomeCatalogEntry(
    id: 'mailbox',
    label: 'Vintage Mailbox',
    emoji: '📮',
    color: Color(0xFF2E5E8E),
    category: HomeCategory.letterJournal,
    shape: HomeItemShape.postBox,
    heightPx: 38,
    routeTo: '/together/letter/new',
    routeLabel: 'Write a Letter',
  ),
  HomeCatalogEntry(
    id: 'wall_mailbox',
    label: 'Wall Mailbox',
    emoji: '📬',
    color: Color(0xFF3D4A5C),
    category: HomeCategory.letterJournal,
    shape: HomeItemShape.wallFlat,
    heightPx: 18,
    routeTo: '/together/letter/new',
    routeLabel: 'Write a Letter',
  ),
  HomeCatalogEntry(id: 'parcel_box', label: 'Parcel Box', emoji: '📦', color: Color(0xFF8B6B4A), category: HomeCategory.letterJournal, heightPx: 20),
  HomeCatalogEntry(
    id: 'writing_desk',
    label: 'Writing Desk',
    emoji: '🖋️',
    color: Color(0xFF8B5A2B),
    category: HomeCategory.letterJournal,
    shape: HomeItemShape.table,
    footprintCols: 2,
    heightPx: 24,
    routeTo: '/together/letter/new',
    routeLabel: 'Write a Letter',
    spriteBase: 'assets/images/decor/writing_desk',
    spriteAspect: 0.951,
  ),
  HomeCatalogEntry(id: 'fountain_pen', label: 'Fountain Pen', emoji: '🖋️', color: Color(0xFF1A1A1A), accent: Color(0xFFD4A84B), category: HomeCategory.letterJournal, heightPx: 8),
  HomeCatalogEntry(id: 'feather_pen', label: 'Feather Pen', emoji: '🪶', color: Color(0xFFEDE4D3), category: HomeCategory.letterJournal, heightPx: 10),
  HomeCatalogEntry(id: 'ink_bottle', label: 'Ink Bottle', emoji: '🫙', color: Color(0xFF1A2A4A), category: HomeCategory.letterJournal, heightPx: 12),
  HomeCatalogEntry(id: 'ink_well', label: 'Ink Well', emoji: '🖋️', color: Color(0xFF2A1A0A), category: HomeCategory.letterJournal, heightPx: 10),
  HomeCatalogEntry(id: 'wax_seal_kit', label: 'Wax Seal Kit', emoji: '🔴', color: Color(0xFFB33A3A), category: HomeCategory.letterJournal, heightPx: 10),
  HomeCatalogEntry(id: 'wax_stamp_collection', label: 'Wax Stamp Collection', emoji: '🟥', color: Color(0xFF8B2323), category: HomeCategory.letterJournal, shape: HomeItemShape.shelfUnit, heightPx: 14),
  HomeCatalogEntry(id: 'envelope_stack', label: 'Envelope Stack', emoji: '✉️', color: Color(0xFFEDE4D3), category: HomeCategory.letterJournal, heightPx: 8),
  HomeCatalogEntry(id: 'letter_rack', label: 'Letter Rack', emoji: '📨', color: Color(0xFF2E5E8E), category: HomeCategory.letterJournal, shape: HomeItemShape.wallFlat, heightPx: 14),
  HomeCatalogEntry(id: 'paper_tray', label: 'Paper Tray', emoji: '📄', color: Color(0xFFEDE4D3), category: HomeCategory.letterJournal, heightPx: 8),
  HomeCatalogEntry(id: 'scroll_holder', label: 'Scroll Holder', emoji: '📜', color: Color(0xFFB5681F), category: HomeCategory.letterJournal, shape: HomeItemShape.postBox, heightPx: 22),
  HomeCatalogEntry(id: 'paper_cutter', label: 'Paper Cutter', emoji: '✂️', color: Color(0xFF7A7A7A), category: HomeCategory.letterJournal, heightPx: 10),
  HomeCatalogEntry(id: 'typewriter', label: 'Typewriter', emoji: '⌨️', color: Color(0xFF2F5F3F), accent: Color(0xFF1A1A1A), category: HomeCategory.letterJournal, shape: HomeItemShape.electronics, heightPx: 18),
  HomeCatalogEntry(id: 'journal_stack', label: 'Journal Stack', emoji: '📓', color: Color(0xFF8B3A3A), category: HomeCategory.letterJournal, shape: HomeItemShape.shelfUnit, heightPx: 16),
  HomeCatalogEntry(id: 'bookmark_holder', label: 'Bookmark Holder', emoji: '🔖', color: Color(0xFFD4A84B), category: HomeCategory.letterJournal, heightPx: 10),
  HomeCatalogEntry(id: 'stamp_album', label: 'Stamp Album', emoji: '📮', color: Color(0xFF6B1A2F), category: HomeCategory.letterJournal, shape: HomeItemShape.shelfUnit, heightPx: 14),
  HomeCatalogEntry(id: 'postcard_display', label: 'Postcard Display', emoji: '🖼️', color: Color(0xFFEDE4D3), category: HomeCategory.letterJournal, shape: HomeItemShape.wallFlat, heightPx: 12),

  // ── Books & Knowledge ───────────────────────────────────────────────────
  HomeCatalogEntry(id: 'large_library', label: 'Large Library', emoji: '📚', color: Color(0xFF4A2E18), category: HomeCategory.books, shape: HomeItemShape.shelfUnit, footprintCols: 2, heightPx: 54, spriteBase: 'assets/images/decor/large_library', spriteAspect: 0.489),
  HomeCatalogEntry(id: 'open_books', label: 'Open Books', emoji: '📖', color: Color(0xFFEDE4D3), category: HomeCategory.books, heightPx: 8),
  HomeCatalogEntry(
    id: 'globe',
    label: 'Globe',
    emoji: '🌍',
    color: Color(0xFF3D6E8E),
    accent: Color(0xFF4A7C59),
    category: HomeCategory.books,
    heightPx: 24,
    routeTo: '/places',
    routeLabel: 'Open Destinations',
  ),
  HomeCatalogEntry(id: 'ladder', label: 'Ladder', emoji: '🪜', color: Color(0xFF8B5A2B), category: HomeCategory.books, heightPx: 50),
  HomeCatalogEntry(id: 'reading_lamp', label: 'Reading Lamp', emoji: '💡', color: Color(0xFFD4A84B), category: HomeCategory.books, shape: HomeItemShape.lampGlow, heightPx: 30, glow: true),
  HomeCatalogEntry(id: 'book_cart', label: 'Book Cart', emoji: '📚', color: Color(0xFF6B4226), category: HomeCategory.books, shape: HomeItemShape.shelfUnit, heightPx: 22),
  HomeCatalogEntry(id: 'encyclopedia', label: 'Encyclopedia', emoji: '📗', color: Color(0xFF2F5F3F), category: HomeCategory.books, heightPx: 16),
  HomeCatalogEntry(id: 'dictionary', label: 'Dictionary', emoji: '📘', color: Color(0xFF2E5E8E), category: HomeCategory.books, heightPx: 12),
  HomeCatalogEntry(
    id: 'map_stand',
    label: 'Map Stand',
    emoji: '🗺️',
    color: Color(0xFFB5681F),
    category: HomeCategory.books,
    shape: HomeItemShape.postBox,
    heightPx: 30,
    routeTo: '/places',
    routeLabel: 'Open Destinations',
  ),
  HomeCatalogEntry(id: 'ancient_scrolls', label: 'Ancient Scrolls', emoji: '📜', color: Color(0xFFD8C4A0), category: HomeCategory.books, heightPx: 14),

  // ── Decorations ─────────────────────────────────────────────────────────
  HomeCatalogEntry(id: 'paintings', label: 'Paintings', emoji: '🖼️', color: Color(0xFF8B2323), category: HomeCategory.decorations, shape: HomeItemShape.wallFlat, heightPx: 30),
  HomeCatalogEntry(id: 'portraits', label: 'Portraits', emoji: '🖼️', color: Color(0xFFD4A84B), category: HomeCategory.decorations, shape: HomeItemShape.wallFlat, heightPx: 30),
  HomeCatalogEntry(id: 'photo_frames', label: 'Photo Frames', emoji: '🖼️', color: Color(0xFFFDF0F5), category: HomeCategory.decorations, shape: HomeItemShape.wallFlat, heightPx: 18),
  HomeCatalogEntry(id: 'floating_frames', label: 'Floating Frames', emoji: '🖼️', color: Color(0xFF2A2A2A), category: HomeCategory.decorations, shape: HomeItemShape.wallFlat, heightPx: 16),
  HomeCatalogEntry(id: 'polaroids', label: 'Polaroids', emoji: '📷', color: Color(0xFFFDF0F5), category: HomeCategory.decorations, shape: HomeItemShape.wallFlat, heightPx: 14),
  HomeCatalogEntry(id: 'cork_board', label: 'Cork Board', emoji: '📌', color: Color(0xFFC9A876), category: HomeCategory.decorations, shape: HomeItemShape.wallFlat, heightPx: 18),
  HomeCatalogEntry(id: 'fairy_lights', label: 'Fairy Lights', emoji: '✨', color: Color(0xFFFFD166), category: HomeCategory.decorations, shape: HomeItemShape.lampGlow, heightPx: 20, glow: true),
  HomeCatalogEntry(id: 'string_lights', label: 'String Lights', emoji: '💡', color: Color(0xFFFFD166), category: HomeCategory.decorations, shape: HomeItemShape.lampGlow, heightPx: 20, glow: true),
  HomeCatalogEntry(id: 'lantern', label: 'Lantern', emoji: '🏮', color: Color(0xFFB5681F), category: HomeCategory.decorations, shape: HomeItemShape.lampGlow, heightPx: 34, glow: true),
  HomeCatalogEntry(id: 'chandelier', label: 'Chandelier', emoji: '💡', color: Color(0xFFD4A84B), category: HomeCategory.decorations, shape: HomeItemShape.lampGlow, heightPx: 36, glow: true),
  HomeCatalogEntry(id: 'neon_sign', label: 'Neon Sign', emoji: '💡', color: Color(0xFFFF3D9A), category: HomeCategory.decorations, shape: HomeItemShape.wallFlat, heightPx: 22, glow: true),
  HomeCatalogEntry(id: 'wall_clock', label: 'Wall Clock', emoji: '🕐', color: Color(0xFF2A2A2A), accent: Color(0xFFD4A84B), category: HomeCategory.decorations, shape: HomeItemShape.wallFlat, heightPx: 16),
  HomeCatalogEntry(id: 'grandfather_clock', label: 'Grandfather Clock', emoji: '🕰️', color: Color(0xFF4A2E18), category: HomeCategory.decorations, shape: HomeItemShape.shelfUnit, heightPx: 54),
  HomeCatalogEntry(id: 'dream_catcher', label: 'Dream Catcher', emoji: '🕸️', color: Color(0xFFD8C4A0), category: HomeCategory.decorations, shape: HomeItemShape.wallFlat, heightPx: 20),
  HomeCatalogEntry(id: 'wind_chime', label: 'Wind Chime', emoji: '🎐', color: Color(0xFFB8C4C8), category: HomeCategory.decorations, shape: HomeItemShape.lampGlow, heightPx: 24),
  HomeCatalogEntry(id: 'hanging_plants', label: 'Hanging Plants', emoji: '🪴', color: Color(0xFF4A7C59), category: HomeCategory.decorations, shape: HomeItemShape.plant, heightPx: 26),
  HomeCatalogEntry(id: 'wall_vines', label: 'Wall Vines', emoji: '🌿', color: Color(0xFF2F5F3F), category: HomeCategory.decorations, shape: HomeItemShape.wallFlat, heightPx: 20),
  HomeCatalogEntry(
    id: 'mirrors',
    label: 'Mirror',
    emoji: '🪞',
    color: Color(0xFFB8C4C8),
    category: HomeCategory.decorations,
    shape: HomeItemShape.wallFlat,
    heightPx: 26,
    routeTo: '/you',
    routeLabel: 'Open Profile',
    spriteBase: 'assets/images/decor/mirrors',
    spriteAspect: 0.622,
  ),
  HomeCatalogEntry(id: 'curtains', label: 'Curtains', emoji: '🪟', color: Color(0xFFB06A7A), category: HomeCategory.decorations, shape: HomeItemShape.wallFlat, heightPx: 40),
  HomeCatalogEntry(id: 'blinds', label: 'Blinds', emoji: '🪟', color: Color(0xFF9E9E9E), category: HomeCategory.decorations, shape: HomeItemShape.wallFlat, heightPx: 34),
  HomeCatalogEntry(id: 'wallpaper_art', label: 'Wallpaper Art', emoji: '🎨', color: Color(0xFF7B4E9E), category: HomeCategory.decorations, shape: HomeItemShape.wallFlat, heightPx: 24),
  HomeCatalogEntry(id: 'tapestries', label: 'Tapestries', emoji: '🧵', color: Color(0xFF8E4A6A), category: HomeCategory.decorations, shape: HomeItemShape.wallFlat, heightPx: 30),
  HomeCatalogEntry(id: 'candles', label: 'Candles', emoji: '🕯️', color: Color(0xFFEDE4D3), category: HomeCategory.decorations, shape: HomeItemShape.lampGlow, heightPx: 14, glow: true),
  HomeCatalogEntry(id: 'candle_stand', label: 'Candle Stand', emoji: '🕯️', color: Color(0xFFD4A84B), category: HomeCategory.decorations, shape: HomeItemShape.lampGlow, heightPx: 22, glow: true),
  HomeCatalogEntry(id: 'crystal', label: 'Crystal', emoji: '💎', color: Color(0xFFB8A0D9), category: HomeCategory.decorations, heightPx: 12),
  HomeCatalogEntry(id: 'snow_globe', label: 'Snow Globe', emoji: '🔮', color: Color(0xFF5B9BD5), category: HomeCategory.decorations, heightPx: 14),
  HomeCatalogEntry(id: 'hourglass', label: 'Hourglass', emoji: '⏳', color: Color(0xFFD4A84B), category: HomeCategory.decorations, heightPx: 16),
  HomeCatalogEntry(id: 'music_box', label: 'Music Box', emoji: '🎵', color: Color(0xFFB06A7A), category: HomeCategory.decorations, heightPx: 14),

  // ── Nature ──────────────────────────────────────────────────────────────
  HomeCatalogEntry(id: 'plant', label: 'Indoor Plant', emoji: '🪴', color: Color(0xFF4A7C59), category: HomeCategory.nature, shape: HomeItemShape.plant, heightPx: 38, spriteBase: 'assets/images/decor/plant', spriteAspect: 0.329),
  HomeCatalogEntry(id: 'bonsai', label: 'Bonsai', emoji: '🌳', color: Color(0xFF2F5F3F), category: HomeCategory.nature, shape: HomeItemShape.plant, heightPx: 20),
  HomeCatalogEntry(id: 'bamboo', label: 'Bamboo', emoji: '🎋', color: Color(0xFF6FBFA0), category: HomeCategory.nature, shape: HomeItemShape.plant, heightPx: 42),
  HomeCatalogEntry(id: 'fern', label: 'Fern', emoji: '🌿', color: Color(0xFF2F5F3F), category: HomeCategory.nature, shape: HomeItemShape.plant, heightPx: 22),
  HomeCatalogEntry(id: 'cactus', label: 'Cactus', emoji: '🌵', color: Color(0xFF5C6E3E), category: HomeCategory.nature, shape: HomeItemShape.plant, heightPx: 24),
  HomeCatalogEntry(id: 'succulent', label: 'Succulent', emoji: '🪴', color: Color(0xFF6FBFA0), category: HomeCategory.nature, shape: HomeItemShape.plant, heightPx: 14),
  HomeCatalogEntry(id: 'rose_vase', label: 'Rose Vase', emoji: '🌹', color: Color(0xFFFF6B8A), category: HomeCategory.nature, shape: HomeItemShape.vase, heightPx: 20),
  HomeCatalogEntry(id: 'tulips', label: 'Tulips', emoji: '🌷', color: Color(0xFFFF8C42), category: HomeCategory.nature, shape: HomeItemShape.vase, heightPx: 18),
  HomeCatalogEntry(id: 'lavender', label: 'Lavender', emoji: '💜', color: Color(0xFFB8A0D9), category: HomeCategory.nature, shape: HomeItemShape.vase, heightPx: 16),
  HomeCatalogEntry(id: 'cherry_blossom', label: 'Cherry Blossom', emoji: '🌸', color: Color(0xFFFFB7C5), category: HomeCategory.nature, shape: HomeItemShape.plant, heightPx: 40),
  HomeCatalogEntry(id: 'tree_stump', label: 'Tree Stump', emoji: '🪵', color: Color(0xFF6B4226), category: HomeCategory.nature, shape: HomeItemShape.table, heightPx: 18),
  HomeCatalogEntry(id: 'terrarium', label: 'Terrarium', emoji: '🔮', color: Color(0xFF6FBFA0), category: HomeCategory.nature, heightPx: 16),
  HomeCatalogEntry(id: 'moss_wall', label: 'Moss Wall', emoji: '🌿', color: Color(0xFF2F5F3F), category: HomeCategory.nature, shape: HomeItemShape.wallFlat, heightPx: 20),
  HomeCatalogEntry(id: 'aquarium', label: 'Aquarium', emoji: '🐠', color: Color(0xFF5B9BD5), category: HomeCategory.nature, heightPx: 26),
  HomeCatalogEntry(id: 'fish_pond', label: 'Fish Pond', emoji: '🐟', color: Color(0xFF5B9BD5), category: HomeCategory.nature, footprintCols: 2, footprintRows: 2, heightPx: 3, isRug: true),
  HomeCatalogEntry(id: 'mini_waterfall', label: 'Mini Waterfall', emoji: '💧', color: Color(0xFF8B8B8B), accent: Color(0xFF5B9BD5), category: HomeCategory.nature, heightPx: 30),
  HomeCatalogEntry(id: 'bird_cage', label: 'Bird Cage', emoji: '🐦', color: Color(0xFFD4A84B), category: HomeCategory.nature, shape: HomeItemShape.postBox, heightPx: 30),
  HomeCatalogEntry(id: 'butterfly_terrarium', label: 'Butterfly Terrarium', emoji: '🦋', color: Color(0xFFB8A0D9), category: HomeCategory.nature, heightPx: 20),

  // ── Technology ──────────────────────────────────────────────────────────
  HomeCatalogEntry(id: 'desktop_pc', label: 'Desktop PC', emoji: '🖥️', color: Color(0xFF2A2A2A), accent: Color(0xFF5B9BD5), category: HomeCategory.tech, shape: HomeItemShape.electronics, heightPx: 26, spriteBase: 'assets/images/decor/desktop_pc', spriteAspect: 0.797),
  HomeCatalogEntry(id: 'laptop', label: 'Laptop', emoji: '💻', color: Color(0xFFB8C4C8), accent: Color(0xFF5B9BD5), category: HomeCategory.tech, shape: HomeItemShape.electronics, heightPx: 12, spriteBase: 'assets/images/decor/laptop', spriteAspect: 0.962),
  HomeCatalogEntry(id: 'tablet', label: 'Tablet', emoji: '📱', color: Color(0xFF2A2A2A), accent: Color(0xFF5B9BD5), category: HomeCategory.tech, shape: HomeItemShape.electronics, heightPx: 8),
  HomeCatalogEntry(id: 'phone_dock', label: 'Phone Dock', emoji: '📱', color: Color(0xFFEDE4D3), category: HomeCategory.tech, heightPx: 10),
  HomeCatalogEntry(id: 'smart_speaker', label: 'Smart Speaker', emoji: '🔊', color: Color(0xFF7A7A7A), category: HomeCategory.tech, heightPx: 16),
  HomeCatalogEntry(id: 'vr_headset', label: 'VR Headset', emoji: '🥽', color: Color(0xFF2A2A2A), category: HomeCategory.tech, heightPx: 12),
  HomeCatalogEntry(id: 'camera', label: 'Camera', emoji: '📷', color: Color(0xFF2A2A2A), category: HomeCategory.tech, heightPx: 12),
  HomeCatalogEntry(id: 'instant_camera', label: 'Instant Camera', emoji: '📸', color: Color(0xFFEDE4D3), accent: Color(0xFFFF8C42), category: HomeCategory.tech, heightPx: 12),
  HomeCatalogEntry(id: 'printer', label: 'Printer', emoji: '🖨️', color: Color(0xFFEDEDED), category: HomeCategory.tech, heightPx: 16),
  HomeCatalogEntry(id: 'projector', label: 'Projector', emoji: '📽️', color: Color(0xFF2A2A2A), accent: Color(0xFFFFD166), category: HomeCategory.tech, heightPx: 14, glow: true),
  HomeCatalogEntry(id: 'television', label: 'Television', emoji: '📺', color: Color(0xFF1A1A1A), accent: Color(0xFF5B9BD5), category: HomeCategory.tech, shape: HomeItemShape.electronics, footprintCols: 2, heightPx: 30, spriteBase: 'assets/images/decor/television', spriteAspect: 0.796),
  HomeCatalogEntry(id: 'gaming_console', label: 'Gaming Console', emoji: '🎮', color: Color(0xFF2A2A2A), category: HomeCategory.tech, heightPx: 10),
  HomeCatalogEntry(id: 'keyboard', label: 'Keyboard', emoji: '⌨️', color: Color(0xFF3D3D3D), category: HomeCategory.tech, heightPx: 6, spriteBase: 'assets/images/decor/keyboard', spriteAspect: 1.242),
  HomeCatalogEntry(id: 'mouse', label: 'Mouse', emoji: '🖱️', color: Color(0xFF2A2A2A), category: HomeCategory.tech, heightPx: 6, spriteBase: 'assets/images/decor/mouse', spriteAspect: 1.0),
  HomeCatalogEntry(id: 'headphones', label: 'Headphones', emoji: '🎧', color: Color(0xFF2A2A2A), category: HomeCategory.tech, heightPx: 10),
  HomeCatalogEntry(id: 'smart_display', label: 'Smart Display', emoji: '🖥️', color: Color(0xFFEDEDED), accent: Color(0xFF5B9BD5), category: HomeCategory.tech, shape: HomeItemShape.electronics, heightPx: 14, spriteBase: 'assets/images/decor/smart_display', spriteAspect: 0.797),

  // ── Music ───────────────────────────────────────────────────────────────
  HomeCatalogEntry(id: 'piano', label: 'Piano', emoji: '🎹', color: Color(0xFF1A1A1A), accent: Color(0xFFFDF0F5), category: HomeCategory.music, shape: HomeItemShape.instrument, footprintCols: 2, heightPx: 32),
  HomeCatalogEntry(id: 'guitar', label: 'Guitar', emoji: '🎸', color: Color(0xFF9E5A2A), category: HomeCategory.music, heightPx: 40),
  HomeCatalogEntry(id: 'violin', label: 'Violin', emoji: '🎻', color: Color(0xFF7A4A2A), category: HomeCategory.music, heightPx: 20),
  HomeCatalogEntry(id: 'ukulele', label: 'Ukulele', emoji: '🎸', color: Color(0xFFD8B888), category: HomeCategory.music, heightPx: 16),
  HomeCatalogEntry(id: 'drum_set', label: 'Drum Set', emoji: '🥁', color: Color(0xFF8B2323), accent: Color(0xFFD4A84B), category: HomeCategory.music, heightPx: 26),
  HomeCatalogEntry(
    id: 'vinyl_player',
    label: 'Vinyl Player',
    emoji: '🎵',
    color: Color(0xFF3D6E8E),
    category: HomeCategory.music,
    heightPx: 24,
    routeTo: '/listen',
    routeLabel: 'Listen Together',
  ),
  HomeCatalogEntry(
    id: 'vinyl_shelf',
    label: 'Vinyl Shelf',
    emoji: '💿',
    color: Color(0xFF4A2E18),
    category: HomeCategory.music,
    shape: HomeItemShape.shelfUnit,
    heightPx: 24,
    routeTo: '/listen',
    routeLabel: 'Listen Together',
  ),
  HomeCatalogEntry(id: 'cassette_player', label: 'Cassette Player', emoji: '📻', color: Color(0xFF7A7A7A), accent: Color(0xFFFF8C42), category: HomeCategory.music, shape: HomeItemShape.electronics, heightPx: 14),
  HomeCatalogEntry(
    id: 'cd_rack',
    label: 'CD Rack',
    emoji: '💿',
    color: Color(0xFF2A2A2A),
    category: HomeCategory.music,
    shape: HomeItemShape.shelfUnit,
    heightPx: 20,
    routeTo: '/listen',
    routeLabel: 'Listen Together',
  ),
  HomeCatalogEntry(id: 'music_stand', label: 'Music Stand', emoji: '🎼', color: Color(0xFF2A2A2A), category: HomeCategory.music, shape: HomeItemShape.postBox, heightPx: 30),
  HomeCatalogEntry(id: 'speaker', label: 'Speaker', emoji: '🔊', color: Color(0xFF1A1A1A), category: HomeCategory.music, heightPx: 22, spriteBase: 'assets/images/decor/speaker', spriteAspect: 0.337),
  HomeCatalogEntry(id: 'microphone', label: 'Microphone', emoji: '🎤', color: Color(0xFFB8C4C8), category: HomeCategory.music, shape: HomeItemShape.postBox, heightPx: 26),

  // ── Hobby ───────────────────────────────────────────────────────────────
  HomeCatalogEntry(id: 'easel', label: 'Easel', emoji: '🎨', color: Color(0xFF8B5A2B), accent: Color(0xFFFDF0F5), category: HomeCategory.hobby, shape: HomeItemShape.postBox, heightPx: 36),
  HomeCatalogEntry(id: 'paint_palette', label: 'Paint Palette', emoji: '🎨', color: Color(0xFFB8A0D9), category: HomeCategory.hobby, heightPx: 8),
  HomeCatalogEntry(id: 'sketchbook', label: 'Sketchbook', emoji: '📓', color: Color(0xFFD8C4A0), category: HomeCategory.hobby, heightPx: 8),
  HomeCatalogEntry(id: 'sewing_machine', label: 'Sewing Machine', emoji: '🧵', color: Color(0xFF1A1A1A), accent: Color(0xFFD4A84B), category: HomeCategory.hobby, shape: HomeItemShape.instrument, heightPx: 18),
  HomeCatalogEntry(id: 'knitting_basket', label: 'Knitting Basket', emoji: '🧶', color: Color(0xFFD8B888), category: HomeCategory.hobby, heightPx: 14),
  HomeCatalogEntry(id: 'chess_table', label: 'Chess Table', emoji: '♟️', color: Color(0xFF2A2A2A), accent: Color(0xFFEDEDED), category: HomeCategory.hobby, shape: HomeItemShape.table, heightPx: 20),
  HomeCatalogEntry(id: 'puzzle_table', label: 'Puzzle Table', emoji: '🧩', color: Color(0xFF5B9BD5), category: HomeCategory.hobby, shape: HomeItemShape.table, heightPx: 20),
  HomeCatalogEntry(id: 'model_train', label: 'Model Train', emoji: '🚂', color: Color(0xFF8B2323), category: HomeCategory.hobby, heightPx: 12),
  HomeCatalogEntry(id: 'lego_shelf', label: 'Lego Shelf', emoji: '🧱', color: Color(0xFFFF8C42), category: HomeCategory.hobby, shape: HomeItemShape.shelfUnit, heightPx: 24),
  HomeCatalogEntry(id: 'telescope', label: 'Telescope', emoji: '🔭', color: Color(0xFF2A2A2A), accent: Color(0xFFD4A84B), category: HomeCategory.hobby, shape: HomeItemShape.postBox, heightPx: 46),
  HomeCatalogEntry(id: 'microscope', label: 'Microscope', emoji: '🔬', color: Color(0xFF2A2A2A), category: HomeCategory.hobby, heightPx: 20),
  HomeCatalogEntry(id: 'drone_dock', label: 'Drone Dock', emoji: '🛸', color: Color(0xFF7A7A7A), category: HomeCategory.hobby, heightPx: 10),

  // ── Food ────────────────────────────────────────────────────────────────
  HomeCatalogEntry(id: 'coffee_machine', label: 'Coffee Machine', emoji: '☕', color: Color(0xFF2A2A2A), accent: Color(0xFF8B5A2B), category: HomeCategory.food, heightPx: 20, spriteBase: 'assets/images/decor/coffee_machine', spriteAspect: 0.814),
  HomeCatalogEntry(id: 'tea_set', label: 'Tea Set', emoji: '🫖', color: Color(0xFFFDF0F5), category: HomeCategory.food, heightPx: 12),
  HomeCatalogEntry(id: 'kettle', label: 'Kettle', emoji: '🫖', color: Color(0xFF8B2323), category: HomeCategory.food, heightPx: 14),
  HomeCatalogEntry(id: 'mug_rack', label: 'Mug Rack', emoji: '☕', color: Color(0xFF8B5A2B), category: HomeCategory.food, shape: HomeItemShape.shelfUnit, heightPx: 16),
  HomeCatalogEntry(id: 'cookie_jar', label: 'Cookie Jar', emoji: '🍪', color: Color(0xFFD8C4A0), category: HomeCategory.food, heightPx: 16),
  HomeCatalogEntry(id: 'fruit_basket', label: 'Fruit Basket', emoji: '🍎', color: Color(0xFFD8B888), category: HomeCategory.food, heightPx: 14),
  HomeCatalogEntry(id: 'wine_rack', label: 'Wine Rack', emoji: '🍷', color: Color(0xFF4A2E18), category: HomeCategory.food, shape: HomeItemShape.shelfUnit, heightPx: 22),
  HomeCatalogEntry(id: 'snack_shelf', label: 'Snack Shelf', emoji: '🍿', color: Color(0xFFD8C4A0), category: HomeCategory.food, shape: HomeItemShape.shelfUnit, heightPx: 20),
  HomeCatalogEntry(id: 'mini_fridge', label: 'Mini Fridge', emoji: '🧊', color: Color(0xFFEDEDED), accent: Color(0xFFFF6B8A), category: HomeCategory.food, shape: HomeItemShape.electronics, heightPx: 26, spriteBase: 'assets/images/decor/mini_fridge', spriteAspect: 0.643),
  HomeCatalogEntry(id: 'cake_stand', label: 'Cake Stand', emoji: '🍰', color: Color(0xFFFDF0F5), accent: Color(0xFFD4A84B), category: HomeCategory.food, shape: HomeItemShape.table, heightPx: 16),

  // ── Collectibles ────────────────────────────────────────────────────────
  HomeCatalogEntry(
    id: 'trophy_shelf',
    label: 'Trophy Shelf',
    emoji: '🏆',
    color: Color(0xFF9E7B1A),
    category: HomeCategory.collectibles,
    shape: HomeItemShape.shelfUnit,
    heightPx: 40,
    routeTo: '/together/bucket',
    routeLabel: 'Open Bucket List',
  ),
  HomeCatalogEntry(id: 'medal_display', label: 'Medal Display', emoji: '🏅', color: Color(0xFFD4A84B), category: HomeCategory.collectibles, shape: HomeItemShape.wallFlat, heightPx: 18),
  HomeCatalogEntry(id: 'certificate_frame', label: 'Certificate Frame', emoji: '📜', color: Color(0xFFD4A84B), category: HomeCategory.collectibles, shape: HomeItemShape.wallFlat, heightPx: 20),
  HomeCatalogEntry(id: 'souvenir_shelf', label: 'Souvenir Shelf', emoji: '🗿', color: Color(0xFF8B5A2B), category: HomeCategory.collectibles, shape: HomeItemShape.shelfUnit, heightPx: 22),
  HomeCatalogEntry(id: 'movie_tickets', label: 'Movie Tickets', emoji: '🎬', color: Color(0xFF8B2323), category: HomeCategory.collectibles, shape: HomeItemShape.wallFlat, heightPx: 10),
  HomeCatalogEntry(
    id: 'flight_tickets',
    label: 'Flight Tickets',
    emoji: '✈️',
    color: Color(0xFF2E5E8E),
    category: HomeCategory.collectibles,
    shape: HomeItemShape.wallFlat,
    heightPx: 10,
    routeTo: '/places',
    routeLabel: 'Open Destinations',
  ),
  HomeCatalogEntry(id: 'concert_tickets', label: 'Concert Tickets', emoji: '🎫', color: Color(0xFF7B4E9E), category: HomeCategory.collectibles, shape: HomeItemShape.wallFlat, heightPx: 10),
  HomeCatalogEntry(id: 'gift_boxes', label: 'Gift Boxes', emoji: '🎁', color: Color(0xFFFF6B8A), accent: Color(0xFFD4A84B), category: HomeCategory.collectibles, heightPx: 16),
  HomeCatalogEntry(id: 'plush_toys', label: 'Plush Toys', emoji: '🧸', color: Color(0xFF9E7B5A), category: HomeCategory.collectibles, heightPx: 20),
  HomeCatalogEntry(id: 'figurine_collection', label: 'Figurine Collection', emoji: '🗿', color: Color(0xFF7B4E9E), category: HomeCategory.collectibles, shape: HomeItemShape.shelfUnit, heightPx: 18),
  HomeCatalogEntry(id: 'coin_collection', label: 'Coin Collection', emoji: '🪙', color: Color(0xFFD4A84B), category: HomeCategory.collectibles, heightPx: 10),
  HomeCatalogEntry(id: 'stamp_collection', label: 'Stamp Collection', emoji: '📮', color: Color(0xFF6B1A2F), category: HomeCategory.collectibles, shape: HomeItemShape.shelfUnit, heightPx: 12),

  // ── Relationship Objects ────────────────────────────────────────────────
  HomeCatalogEntry(id: 'anniversary_calendar', label: 'Anniversary Calendar', emoji: '📅', color: Color(0xFFFF6B8A), category: HomeCategory.relationship, shape: HomeItemShape.wallFlat, heightPx: 20),
  HomeCatalogEntry(id: 'couple_portrait', label: 'Couple Portrait', emoji: '💑', color: Color(0xFFD4A84B), category: HomeCategory.relationship, shape: HomeItemShape.wallFlat, heightPx: 26),
  HomeCatalogEntry(id: 'memory_tree', label: 'Memory Tree', emoji: '🌳', color: Color(0xFF4A7C59), category: HomeCategory.relationship, shape: HomeItemShape.plant, heightPx: 42),
  HomeCatalogEntry(id: 'love_jar', label: 'Love Jar', emoji: '💌', color: Color(0xFFFF6B8A), category: HomeCategory.relationship, heightPx: 14),
  HomeCatalogEntry(id: 'memory_bottle', label: 'Memory Bottle', emoji: '🍾', color: Color(0xFF6FBFA0), category: HomeCategory.relationship, heightPx: 16),
  HomeCatalogEntry(id: 'time_capsule', label: 'Time Capsule', emoji: '📦', color: Color(0xFF9E7B1A), category: HomeCategory.relationship, heightPx: 18),
  HomeCatalogEntry(
    id: 'bucket_list_board',
    label: 'Bucket List Board',
    emoji: '🗒️',
    color: Color(0xFFEDE4D3),
    category: HomeCategory.relationship,
    shape: HomeItemShape.wallFlat,
    heightPx: 20,
    routeTo: '/together/bucket',
    routeLabel: 'Open Bucket List',
  ),
  HomeCatalogEntry(
    id: 'date_jar',
    label: 'Date Jar',
    emoji: '🎲',
    color: Color(0xFFFF8C42),
    category: HomeCategory.relationship,
    heightPx: 14,
    routeTo: '/dates',
    routeLabel: 'Spin a Date Idea',
  ),
  HomeCatalogEntry(id: 'mood_board', label: 'Mood Board', emoji: '🎨', color: Color(0xFFB8A0D9), category: HomeCategory.relationship, shape: HomeItemShape.wallFlat, heightPx: 22),
  HomeCatalogEntry(id: 'vision_board', label: 'Shared Vision Board', emoji: '🖼️', color: Color(0xFFD4A84B), category: HomeCategory.relationship, shape: HomeItemShape.wallFlat, heightPx: 22),
  HomeCatalogEntry(id: 'promise_ring_stand', label: 'Promise Ring Stand', emoji: '💍', color: Color(0xFFD4A84B), category: HomeCategory.relationship, heightPx: 12),
  HomeCatalogEntry(id: 'gift_cabinet', label: 'Gift Cabinet', emoji: '🎁', color: Color(0xFFB06A7A), category: HomeCategory.relationship, shape: HomeItemShape.shelfUnit, heightPx: 26),
  HomeCatalogEntry(id: 'relationship_timeline', label: 'Relationship Timeline', emoji: '📈', color: Color(0xFFFF6B8A), category: HomeCategory.relationship, shape: HomeItemShape.wallFlat, heightPx: 20),
  HomeCatalogEntry(id: 'countdown_clock', label: 'Countdown Clock', emoji: '⏰', color: Color(0xFFD4A84B), category: HomeCategory.relationship, shape: HomeItemShape.wallFlat, heightPx: 18),
  HomeCatalogEntry(
    id: 'memory_map',
    label: 'Memory Map',
    emoji: '🗺️',
    color: Color(0xFFD8C4A0),
    category: HomeCategory.relationship,
    shape: HomeItemShape.wallFlat,
    heightPx: 20,
    routeTo: '/places',
    routeLabel: 'Open Destinations',
  ),
  HomeCatalogEntry(
    id: 'adventure_map',
    label: 'Adventure Map',
    emoji: '🗺️',
    color: Color(0xFF4A7C59),
    category: HomeCategory.relationship,
    shape: HomeItemShape.wallFlat,
    heightPx: 20,
    routeTo: '/places',
    routeLabel: 'Open Destinations',
  ),
  HomeCatalogEntry(
    id: 'couple_passport',
    label: 'Couple Passport',
    emoji: '🛂',
    color: Color(0xFF1A2A4A),
    accent: Color(0xFFD4A84B),
    category: HomeCategory.relationship,
    heightPx: 10,
    routeTo: '/places',
    routeLabel: 'Open Destinations',
  ),

  // ── Pets ────────────────────────────────────────────────────────────────
  HomeCatalogEntry(id: 'pet_cat', label: 'Cat', emoji: '🐱', color: Color(0xFF9E7B5A), category: HomeCategory.pets, heightPx: 14),
  HomeCatalogEntry(id: 'pet_dog', label: 'Dog', emoji: '🐶', color: Color(0xFFB5681F), category: HomeCategory.pets, heightPx: 16),
  HomeCatalogEntry(id: 'pet_rabbit', label: 'Rabbit', emoji: '🐰', color: Color(0xFFEDE4D3), category: HomeCategory.pets, heightPx: 12),
  HomeCatalogEntry(id: 'pet_hamster', label: 'Hamster', emoji: '🐹', color: Color(0xFFD8B888), category: HomeCategory.pets, heightPx: 8),
  HomeCatalogEntry(id: 'pet_bird', label: 'Bird', emoji: '🐦', color: Color(0xFF5B9BD5), category: HomeCategory.pets, heightPx: 14),
  HomeCatalogEntry(id: 'pet_turtle', label: 'Turtle', emoji: '🐢', color: Color(0xFF4A7C59), category: HomeCategory.pets, heightPx: 8),
  HomeCatalogEntry(id: 'pet_fish_tank', label: 'Fish Tank', emoji: '🐠', color: Color(0xFF5B9BD5), category: HomeCategory.pets, heightPx: 22),
  HomeCatalogEntry(id: 'pet_bed', label: 'Pet Bed', emoji: '🛏️', color: Color(0xFFD8B888), category: HomeCategory.pets, shape: HomeItemShape.blob, heightPx: 10),
  HomeCatalogEntry(id: 'pet_food_bowl', label: 'Food Bowl', emoji: '🥣', color: Color(0xFFB8C4C8), category: HomeCategory.pets, heightPx: 6),
  HomeCatalogEntry(id: 'pet_toy_basket', label: 'Toy Basket', emoji: '🧸', color: Color(0xFFD8B888), category: HomeCategory.pets, heightPx: 12),

  // ── Windows & Outdoor ───────────────────────────────────────────────────
  HomeCatalogEntry(id: 'balcony', label: 'Balcony', emoji: '🌇', color: Color(0xFF5B9BD5), category: HomeCategory.outdoor, shape: HomeItemShape.wallFlat, footprintCols: 2, heightPx: 30),
  HomeCatalogEntry(id: 'bay_window', label: 'Bay Window', emoji: '🪟', color: Color(0xFFEDE4D3), category: HomeCategory.outdoor, shape: HomeItemShape.wallFlat, heightPx: 34),
  HomeCatalogEntry(id: 'garden', label: 'Garden', emoji: '🌻', color: Color(0xFF4A7C59), category: HomeCategory.outdoor, footprintCols: 2, footprintRows: 2, heightPx: 3, isRug: true),
  HomeCatalogEntry(id: 'patio', label: 'Patio', emoji: '🪑', color: Color(0xFF9E9E9E), category: HomeCategory.outdoor, footprintCols: 2, footprintRows: 2, heightPx: 3, isRug: true),
  HomeCatalogEntry(id: 'deck', label: 'Deck', emoji: '🪵', color: Color(0xFFB5681F), category: HomeCategory.outdoor, footprintCols: 2, footprintRows: 2, heightPx: 3, isRug: true),
  HomeCatalogEntry(id: 'porch', label: 'Porch', emoji: '🏡', color: Color(0xFFEDE4D3), category: HomeCategory.outdoor, heightPx: 16),
  HomeCatalogEntry(id: 'gazebo', label: 'Gazebo', emoji: '⛺', color: Color(0xFFFDF0F5), category: HomeCategory.outdoor, footprintCols: 2, footprintRows: 2, heightPx: 44),
  HomeCatalogEntry(id: 'outdoor_swing', label: 'Swing', emoji: '🎠', color: Color(0xFF8B5A2B), category: HomeCategory.outdoor, shape: HomeItemShape.seating, heightPx: 30),
  HomeCatalogEntry(id: 'bench', label: 'Bench', emoji: '🪑', color: Color(0xFF6B4226), category: HomeCategory.outdoor, shape: HomeItemShape.seating, footprintCols: 2, heightPx: 20, spriteBase: 'assets/images/decor/bench', spriteAspect: 0.66),
  HomeCatalogEntry(id: 'bird_feeder', label: 'Bird Feeder', emoji: '🐦', color: Color(0xFF8B5A2B), category: HomeCategory.outdoor, shape: HomeItemShape.postBox, heightPx: 28),
  HomeCatalogEntry(id: 'fountain', label: 'Fountain', emoji: '⛲', color: Color(0xFFB8C4C8), accent: Color(0xFF5B9BD5), category: HomeCategory.outdoor, heightPx: 26),
  HomeCatalogEntry(id: 'campfire', label: 'Campfire', emoji: '🔥', color: Color(0xFFFF8C42), category: HomeCategory.outdoor, shape: HomeItemShape.lampGlow, heightPx: 18, glow: true),
  HomeCatalogEntry(id: 'bbq_grill', label: 'BBQ Grill', emoji: '🍖', color: Color(0xFF2A2A2A), category: HomeCategory.outdoor, heightPx: 22),
  HomeCatalogEntry(id: 'flower_bed', label: 'Flower Bed', emoji: '🌷', color: Color(0xFFFF6B8A), category: HomeCategory.outdoor, footprintCols: 2, heightPx: 3, isRug: true),
  HomeCatalogEntry(id: 'vegetable_patch', label: 'Vegetable Patch', emoji: '🥕', color: Color(0xFF8B5A2B), category: HomeCategory.outdoor, footprintCols: 2, heightPx: 3, isRug: true),

  // ── Magical / Fantasy ───────────────────────────────────────────────────
  HomeCatalogEntry(id: 'floating_candles', label: 'Floating Candles', emoji: '🕯️', color: Color(0xFFFDF0F5), category: HomeCategory.magical, shape: HomeItemShape.lampGlow, heightPx: 26, glow: true),
  HomeCatalogEntry(id: 'floating_books', label: 'Floating Books', emoji: '📚', color: Color(0xFF7B4E9E), category: HomeCategory.magical, heightPx: 22, glow: true),
  HomeCatalogEntry(id: 'crystal_ball', label: 'Crystal Ball', emoji: '🔮', color: Color(0xFF7B4E9E), category: HomeCategory.magical, heightPx: 18, glow: true),
  HomeCatalogEntry(id: 'magic_mirror', label: 'Magic Mirror', emoji: '🪞', color: Color(0xFF7B4E9E), category: HomeCategory.magical, shape: HomeItemShape.wallFlat, heightPx: 28, glow: true),
  HomeCatalogEntry(id: 'glowing_mushrooms', label: 'Glowing Mushrooms', emoji: '🍄', color: Color(0xFF1E5E5E), category: HomeCategory.magical, shape: HomeItemShape.plant, heightPx: 14, glow: true),
  HomeCatalogEntry(id: 'potion_shelf', label: 'Potion Shelf', emoji: '🧪', color: Color(0xFF7B4E9E), category: HomeCategory.magical, shape: HomeItemShape.shelfUnit, heightPx: 22),
  HomeCatalogEntry(id: 'star_projector', label: 'Star Projector', emoji: '⭐', color: Color(0xFF1A2A4A), category: HomeCategory.magical, shape: HomeItemShape.lampGlow, heightPx: 20, glow: true),
  HomeCatalogEntry(id: 'moon_lamp', label: 'Moon Lamp', emoji: '🌙', color: Color(0xFFEDE4D3), category: HomeCategory.magical, shape: HomeItemShape.lampGlow, heightPx: 22, glow: true),
  HomeCatalogEntry(id: 'galaxy_globe', label: 'Galaxy Globe', emoji: '🌌', color: Color(0xFF4B2E83), category: HomeCategory.magical, heightPx: 20, glow: true),
  HomeCatalogEntry(id: 'floating_island', label: 'Floating Island', emoji: '🏝️', color: Color(0xFF4A7C59), category: HomeCategory.magical, heightPx: 26, glow: true),
  HomeCatalogEntry(id: 'mini_planet', label: 'Mini Planet', emoji: '🪐', color: Color(0xFFB5681F), category: HomeCategory.magical, heightPx: 18, glow: true),
  HomeCatalogEntry(id: 'fireflies', label: 'Fireflies', emoji: '✨', color: Color(0xFFFFD166), category: HomeCategory.magical, shape: HomeItemShape.lampGlow, heightPx: 12, glow: true),
  HomeCatalogEntry(id: 'aurora_window', label: 'Aurora Window', emoji: '🌌', color: Color(0xFF6FBFA0), accent: Color(0xFF7B4E9E), category: HomeCategory.magical, shape: HomeItemShape.wallFlat, heightPx: 30, glow: true),
  HomeCatalogEntry(id: 'constellation_ceiling', label: 'Constellation Ceiling', emoji: '✨', color: Color(0xFF1A2A4A), category: HomeCategory.magical, shape: HomeItemShape.wallFlat, heightPx: 16, glow: true),

  // ── Rugs (floor overlays) ───────────────────────────────────────────────
  HomeCatalogEntry(id: 'rug', label: 'Rug', emoji: '🟫', color: Color(0xFFB5681F), category: HomeCategory.furniture, footprintCols: 2, footprintRows: 2, heightPx: 2, isRug: true),
];

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
