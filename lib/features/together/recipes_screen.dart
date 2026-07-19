import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';
import '../../core/firebase/models.dart';
import '../../core/presence/activity_announcer.dart';
import '../../core/providers/providers.dart';
import '../../core/theme/app_theme.dart';

// ─── Cookbook color palette (same visual language as the Journal shelf) ───

const List<Color> _kBookColors = [
  Color(0xFF8B3A3A),
  Color(0xFF2E5E8E),
  Color(0xFF4A7C59),
  Color(0xFF7B4E9E),
  Color(0xFFB5681F),
  Color(0xFF3D6E8E),
  Color(0xFF8E4A6A),
  Color(0xFF5C6E3E),
  Color(0xFF6B4226),
  Color(0xFF1E5E5E),
  Color(0xFF9E4545),
  Color(0xFF3B5998),
];

Color _bookColor(String id) => _kBookColors[id.hashCode.abs() % _kBookColors.length];
double _bookWidth(String id) => (id.hashCode.abs() % 25) + 34.0;
double _bookHeight(String id) => (id.hashCode.abs() % 54) + 85.0;

enum _BookDesign { plain, striped, gilded, embossed }

_BookDesign _bookDesign(String id) =>
    _BookDesign.values[(id.hashCode.abs() ~/ 3) % _BookDesign.values.length];

const _kGold = Color(0xFFF5DEB3);

String _categoryLabel(RecipeCategory c) {
  switch (c) {
    case RecipeCategory.breakfast: return 'Breakfast';
    case RecipeCategory.lunch: return 'Lunch';
    case RecipeCategory.dinner: return 'Dinner';
    case RecipeCategory.dessert: return 'Dessert';
    case RecipeCategory.drink: return 'Drinks';
    case RecipeCategory.snack: return 'Snacks';
    case RecipeCategory.other: return 'Other';
  }
}

IconData _categoryIcon(RecipeCategory c) {
  switch (c) {
    case RecipeCategory.breakfast: return Icons.free_breakfast_rounded;
    case RecipeCategory.lunch: return Icons.lunch_dining_rounded;
    case RecipeCategory.dinner: return Icons.dinner_dining_rounded;
    case RecipeCategory.dessert: return Icons.cake_rounded;
    case RecipeCategory.drink: return Icons.local_bar_rounded;
    case RecipeCategory.snack: return Icons.icecream_rounded;
    case RecipeCategory.other: return Icons.restaurant_rounded;
  }
}

// ─── Main screen ───────────────────────────────────────────────────────────

enum _RecipeFilter { all, breakfast, lunch, dinner, dessert, drink, snack, favorites }

class RecipesScreen extends ConsumerStatefulWidget {
  const RecipesScreen({super.key});

  @override
  ConsumerState<RecipesScreen> createState() => _RecipesScreenState();
}

class _RecipesScreenState extends ConsumerState<RecipesScreen>
    with SingleTickerProviderStateMixin, ActivityAnnouncer {
  bool _newestFirst = true;
  _RecipeFilter _filter = _RecipeFilter.all;
  bool _searching = false;
  final _searchCtrl = TextEditingController();
  String _query = '';
  late final AnimationController _twinkle;

  @override
  void initState() {
    super.initState();
    _twinkle = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
    announceActivity('Browsing Recipes');
  }

  @override
  void dispose() {
    _twinkle.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _openNewRecipe(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => const _RecipeView(recipe: null),
    ));
  }

  List<RecipeModel> _filtered(List<RecipeModel> recipes) {
    List<RecipeModel> out;
    switch (_filter) {
      case _RecipeFilter.all:
        out = recipes;
      case _RecipeFilter.favorites:
        out = recipes.where((r) => r.favorite).toList();
      case _RecipeFilter.breakfast:
        out = recipes.where((r) => r.category == RecipeCategory.breakfast).toList();
      case _RecipeFilter.lunch:
        out = recipes.where((r) => r.category == RecipeCategory.lunch).toList();
      case _RecipeFilter.dinner:
        out = recipes.where((r) => r.category == RecipeCategory.dinner).toList();
      case _RecipeFilter.dessert:
        out = recipes.where((r) => r.category == RecipeCategory.dessert).toList();
      case _RecipeFilter.drink:
        out = recipes.where((r) => r.category == RecipeCategory.drink).toList();
      case _RecipeFilter.snack:
        out = recipes.where((r) => r.category == RecipeCategory.snack).toList();
    }
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      out = out.where((r) => r.title.toLowerCase().contains(q)).toList();
    }
    out = List.of(out);
    if (!_newestFirst) out = out.reversed.toList();
    return out;
  }

  int _yearsTogether(dynamic couple) {
    if (couple == null) return 0;
    final DateTime since = couple.anniversary ?? couple.createdAt;
    final days = DateTime.now().difference(since).inDays;
    return (days / 365).floor();
  }

  @override
  Widget build(BuildContext context) {
    final recipesAsync = ref.watch(recipesProvider);
    final recipes = recipesAsync.valueOrNull ?? [];
    final couple = ref.watch(coupleProvider).valueOrNull;

    final favCount = recipes.where((r) => r.favorite).length;
    final categoriesUsed = recipes.map((r) => r.category).toSet().length;
    final years = _yearsTogether(couple);
    final filtered = _filtered(recipes);

    return Scaffold(
      backgroundColor: const Color(0xFF2A1F14),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset('assets/images/journal_bookshelf_bg.png', fit: BoxFit.cover),
          ),
          Positioned.fill(
            child: Container(color: Colors.black.withValues(alpha: 0.4)),
          ),
          SafeArea(
            child: Column(
              children: [
                _RecipesHeader(
                  searching: _searching,
                  searchCtrl: _searchCtrl,
                  onSearchToggle: () => setState(() {
                    _searching = !_searching;
                    if (!_searching) {
                      _query = '';
                      _searchCtrl.clear();
                    }
                  }),
                  onQueryChanged: (v) => setState(() => _query = v),
                  onOrderToggle: () => setState(() => _newestFirst = !_newestFirst),
                  newestFirst: _newestFirst,
                  twinkle: _twinkle,
                ),
                if (!_searching) ...[
                  _RecipeStatsPlaque(
                    recipes: recipes.length,
                    favorites: favCount,
                    categories: categoriesUsed,
                    years: years,
                  ),
                  const SizedBox(height: 10),
                  _RecipeFilterChipsRow(
                    value: _filter,
                    onChanged: (f) => setState(() => _filter = f),
                  ),
                ],
                Expanded(
                  child: recipesAsync.isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : Stack(
                          children: [
                            _CookbookShelfBody(recipes: filtered),
                            if (!_searching)
                              Positioned(
                                left: 0,
                                right: 0,
                                bottom: 0,
                                child: _RecipeWritingStation(
                                  onTap: () => _openNewRecipe(context),
                                ),
                              ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Header ─────────────────────────────────────────────────────────────

class _RecipesHeader extends StatelessWidget {
  final bool searching;
  final TextEditingController searchCtrl;
  final VoidCallback onSearchToggle;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onOrderToggle;
  final bool newestFirst;
  final AnimationController twinkle;

  const _RecipesHeader({
    required this.searching,
    required this.searchCtrl,
    required this.onSearchToggle,
    required this.onQueryChanged,
    required this.onOrderToggle,
    required this.newestFirst,
    required this.twinkle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _kGold),
            onPressed: () => context.go('/together'),
          ),
          Expanded(
            child: searching
                ? TextField(
                    controller: searchCtrl,
                    autofocus: true,
                    style: const TextStyle(color: _kGold),
                    onChanged: onQueryChanged,
                    decoration: const InputDecoration(
                      hintText: 'Search recipes…',
                      hintStyle: TextStyle(color: Color(0x99F5DEB3)),
                      border: InputBorder.none,
                    ),
                  )
                : Center(
                    child: AnimatedBuilder(
                      animation: twinkle,
                      builder: (_, _) {
                        final t = twinkle.value;
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Opacity(
                              opacity: 0.4 + 0.6 * t,
                              child: const Text('✦', style: TextStyle(fontSize: 12, color: _kGold)),
                            ),
                            const SizedBox(width: 8),
                            Text('Our Recipes',
                                style: GoogleFonts.playfairDisplay(
                                  color: _kGold,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  shadows: const [Shadow(color: Colors.black54, blurRadius: 6)],
                                )),
                            const SizedBox(width: 8),
                            Opacity(
                              opacity: 0.4 + 0.6 * (1 - t),
                              child: const Text('✧', style: TextStyle(fontSize: 12, color: _kGold)),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
          ),
          if (searching)
            IconButton(
              icon: const Icon(Icons.close_rounded, color: _kGold),
              onPressed: onSearchToggle,
            )
          else ...[
            IconButton(
              tooltip: newestFirst ? 'Newest first' : 'Oldest first',
              icon: Icon(newestFirst ? Icons.south_rounded : Icons.north_rounded,
                  color: _kGold, size: 20),
              onPressed: onOrderToggle,
            ),
            IconButton(
              icon: const Icon(Icons.search_rounded, color: _kGold),
              onPressed: onSearchToggle,
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Stats plaque ─────────────────────────────────────────────────────────

class _RecipeStatsPlaque extends StatelessWidget {
  final int recipes;
  final int favorites;
  final int categories;
  final int years;

  const _RecipeStatsPlaque({
    required this.recipes,
    required this.favorites,
    required this.categories,
    required this.years,
  });

  @override
  Widget build(BuildContext context) {
    Widget stat(IconData icon, int value, String label) {
      return Expanded(
        child: Column(
          children: [
            Icon(icon, color: const Color(0xFF6B4226), size: 16),
            const SizedBox(height: 4),
            Text('$value',
                style: GoogleFonts.playfairDisplay(
                    color: const Color(0xFF2A1A0A), fontSize: 17, fontWeight: FontWeight.bold)),
            Text(label, style: GoogleFonts.lato(color: const Color(0xFF5C3D1E), fontSize: 10)),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFE8D4B8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF8B6340).withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          stat(Icons.menu_book_rounded, recipes, 'Recipes'),
          stat(Icons.star_rounded, favorites, 'Favorites'),
          stat(Icons.category_rounded, categories, 'Categories'),
          stat(Icons.favorite_rounded, years, years == 1 ? 'Year' : 'Years'),
        ],
      ),
    );
  }
}

// ─── Filter chips ─────────────────────────────────────────────────────────

class _RecipeFilterChipsRow extends StatelessWidget {
  final _RecipeFilter value;
  final ValueChanged<_RecipeFilter> onChanged;
  const _RecipeFilterChipsRow({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    Widget chip(_RecipeFilter f, String label) {
      final selected = value == f;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: SquishyTap(
          onTap: () => onChanged(f),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: selected ? _kGold : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: selected ? _kGold : _kGold.withValues(alpha: 0.4)),
            ),
            child: Text(label,
                style: GoogleFonts.lato(
                    color: selected ? const Color(0xFF2A1A0A) : _kGold,
                    fontSize: 12.5,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.normal)),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: SizedBox(
        height: 36,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            chip(_RecipeFilter.all, 'All'),
            chip(_RecipeFilter.breakfast, 'Breakfast'),
            chip(_RecipeFilter.lunch, 'Lunch'),
            chip(_RecipeFilter.dinner, 'Dinner'),
            chip(_RecipeFilter.dessert, 'Dessert'),
            chip(_RecipeFilter.drink, 'Drinks'),
            chip(_RecipeFilter.snack, 'Snacks'),
            chip(_RecipeFilter.favorites, 'Favorites'),
          ],
        ),
      ),
    );
  }
}

// ─── Cookbook shelf body ──────────────────────────────────────────────────

const _kBookContainerHeight = 150.0;
const _kShelfSidePad = 16.0;

List<List<T>> _chunk<T>(List<T> items, int size) {
  final out = <List<T>>[];
  for (var i = 0; i < items.length; i += size) {
    out.add(items.sublist(i, (i + size).clamp(0, items.length)));
  }
  return out;
}

class _CookbookShelfBody extends StatelessWidget {
  final List<RecipeModel> recipes;
  const _CookbookShelfBody({required this.recipes});

  @override
  Widget build(BuildContext context) {
    if (recipes.isEmpty) {
      return Center(
        child: Text(
          'No recipes here yet 🍳',
          style: GoogleFonts.lato(color: _kGold.withValues(alpha: 0.5), fontSize: 14, fontStyle: FontStyle.italic),
        ),
      );
    }

    final byCategory = <RecipeCategory, List<RecipeModel>>{};
    for (final r in recipes) {
      byCategory.putIfAbsent(r.category, () => []).add(r);
    }
    final orderedCategories = RecipeCategory.values.where(byCategory.containsKey);

    return LayoutBuilder(builder: (context, constraints) {
      final shelfW = constraints.maxWidth - _kShelfSidePad * 2;
      final maxPerShelf = (shelfW / 46).floor().clamp(4, 14);

      return ListView(
        padding: const EdgeInsets.fromLTRB(0, 12, 0, 210),
        children: [
          for (final cat in orderedCategories) ...[
            _CategoryLabel(category: cat),
            for (final chunkList in _chunk(byCategory[cat]!, maxPerShelf))
              _ShelfRow(recipes: chunkList),
          ],
          const _RecipeOfTheDayCard(),
          const SizedBox(height: 12),
        ],
      );
    });
  }
}

class _CategoryLabel extends StatelessWidget {
  final RecipeCategory category;
  const _CategoryLabel({required this.category});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(_kShelfSidePad, 18, _kShelfSidePad, 10),
      child: Row(
        children: [
          Expanded(child: Container(height: 1, color: _kGold.withValues(alpha: 0.25))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_categoryIcon(category), color: _kGold, size: 14),
                const SizedBox(width: 6),
                Text(
                  _categoryLabel(category),
                  style: GoogleFonts.playfairDisplay(
                      color: _kGold, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1),
                ),
              ],
            ),
          ),
          Expanded(child: Container(height: 1, color: _kGold.withValues(alpha: 0.25))),
        ],
      ),
    );
  }
}

class _ShelfRow extends StatelessWidget {
  final List<RecipeModel> recipes;
  const _ShelfRow({required this.recipes});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _kShelfSidePad, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: _kBookContainerHeight,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [for (final r in recipes) _BookSpine(recipe: r)],
              ),
            ),
          ),
          const _WoodPlank(),
        ],
      ),
    );
  }
}

class _WoodPlank extends StatelessWidget {
  const _WoodPlank();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 14,
      margin: const EdgeInsets.only(top: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(2),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF6B4226), Color(0xFF4A2E18), Color(0xFF2E1B0E)],
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 8, offset: const Offset(0, 4)),
        ],
      ),
      child: Align(
        alignment: Alignment.topCenter,
        child: Container(
          height: 2,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          color: const Color(0xFF8B6340).withValues(alpha: 0.6),
        ),
      ),
    );
  }
}

class _BookSpine extends StatefulWidget {
  final RecipeModel recipe;
  const _BookSpine({required this.recipe});

  @override
  State<_BookSpine> createState() => _BookSpineState();
}

class _BookSpineState extends State<_BookSpine> {
  bool _lifted = false;

  @override
  Widget build(BuildContext context) {
    final recipe = widget.recipe;
    final color = _bookColor(recipe.id);
    final width = _bookWidth(recipe.id);
    final height = _bookHeight(recipe.id);
    final design = _bookDesign(recipe.id);

    return GestureDetector(
      onTapDown: (_) => setState(() => _lifted = true),
      onTapCancel: () => setState(() => _lifted = false),
      onTapUp: (_) => setState(() => _lifted = false),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => _RecipeView(recipe: recipe),
      )),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(0, _lifted ? -10 : 0, 0),
        width: width,
        height: height,
        margin: const EdgeInsets.only(right: 3),
        decoration: BoxDecoration(
          gradient: _spineGradient(design, color),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(3),
            topRight: Radius.circular(3),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: _lifted ? 0.7 : 0.55),
              blurRadius: _lifted ? 12 : 5,
              offset: Offset(2, _lifted ? 8 : 3),
            ),
            if (_lifted) BoxShadow(color: _kGold.withValues(alpha: 0.35), blurRadius: 14),
          ],
        ),
        child: Stack(
          children: [
            if (design == _BookDesign.gilded)
              Positioned(
                left: 0, top: 0, bottom: 0,
                child: Container(
                  width: 4,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFFFFD700), Color(0xFFB8860B)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ),
            if (design == _BookDesign.embossed)
              Positioned(
                top: 8, left: 0, right: 0,
                child: Center(
                  child: Container(
                    width: width * 0.55,
                    height: width * 0.55,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 1.5),
                    ),
                  ),
                ),
              ),
            Positioned(
              top: 6,
              left: 0,
              right: 0,
              child: Icon(_categoryIcon(recipe.category), color: Colors.white.withValues(alpha: 0.7), size: 12),
            ),
            if (recipe.favorite)
              const Positioned(
                top: 6,
                right: 4,
                child: Icon(Icons.star_rounded, color: Color(0xFFFFD700), size: 12),
              ),
            Positioned(
              bottom: -8,
              left: width / 2 - 5,
              child: Container(
                width: 10,
                height: 16,
                decoration: BoxDecoration(
                  color: _kGold.withValues(alpha: 0.85),
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(2)),
                ),
              ),
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: Center(
                    child: RotatedBox(
                      quarterTurns: 3,
                      child: Text(
                        recipe.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.lato(
                          fontSize: 10,
                          color: Colors.white.withValues(alpha: 0.92),
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Gradient _spineGradient(_BookDesign design, Color color) {
    switch (design) {
      case _BookDesign.striped:
        return LinearGradient(
          colors: [color, color.withValues(alpha: 0.75)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        );
      case _BookDesign.gilded:
        return LinearGradient(
          colors: [color.withValues(alpha: 0.9), color, color.withValues(alpha: 0.8)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        );
      case _BookDesign.embossed:
        return RadialGradient(
          center: const Alignment(-0.3, -0.5),
          radius: 1.4,
          colors: [color.withValues(alpha: 0.95), color.withValues(alpha: 0.65)],
        );
      case _BookDesign.plain:
        return LinearGradient(
          colors: [color.withValues(alpha: 0.9), color, color.withValues(alpha: 0.7)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        );
    }
  }
}

// ─── Recipe of the day ────────────────────────────────────────────────────

class _RecipeOfTheDayCard extends ConsumerWidget {
  const _RecipeOfTheDayCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recipes = ref.watch(recipesProvider).valueOrNull ?? [];
    if (recipes.isEmpty) return const SizedBox.shrink();

    final dayKey = DateTime.now().toIso8601String().substring(0, 10);
    final pick = recipes[dayKey.hashCode.abs() % recipes.length];

    return Padding(
      padding: const EdgeInsets.fromLTRB(_kShelfSidePad, 8, _kShelfSidePad, 0),
      child: GestureDetector(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => _RecipeView(recipe: pick),
        )),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF3A2A18),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _kGold.withValues(alpha: 0.4), width: 1.5),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 10, offset: const Offset(0, 5))],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.auto_awesome_rounded, color: _kGold, size: 14),
                        const SizedBox(width: 6),
                        Text('Recipe of the Day',
                            style: GoogleFonts.playfairDisplay(
                                color: _kGold, fontSize: 13, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('"${pick.title}"',
                        style: GoogleFonts.lato(
                            color: _kGold.withValues(alpha: 0.85),
                            fontSize: 13,
                            fontStyle: FontStyle.italic,
                            height: 1.4)),
                    const SizedBox(height: 6),
                    Text('Tap to cook it up',
                        style: GoogleFonts.lato(color: _kGold.withValues(alpha: 0.5), fontSize: 10.5)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(_categoryIcon(pick.category), color: _kGold.withValues(alpha: 0.7), size: 40),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Writing station ──────────────────────────────────────────────────────

class _RecipeWritingStation extends StatelessWidget {
  final VoidCallback onTap;
  const _RecipeWritingStation({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF2A1F14).withValues(alpha: 0),
            const Color(0xFF1D1610),
            const Color(0xFF120D08),
          ],
          stops: const [0, 0.4, 1],
        ),
      ),
      child: Row(
        children: [
          const Text('🍳', style: TextStyle(fontSize: 26)),
          const SizedBox(width: 10),
          const Text('🥄', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 14),
          Expanded(
            child: SquishyTap(
              onTap: onTap,
              cuteStickers: const ['🍰', '✨'],
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 15),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF6B4226), Color(0xFF4A2E18)]),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _kGold.withValues(alpha: 0.4)),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('📝', style: TextStyle(fontSize: 16)),
                    const SizedBox(width: 8),
                    Text('Add a Recipe',
                        style: GoogleFonts.playfairDisplay(
                            color: _kGold, fontSize: 15, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Recipe view / editor ─────────────────────────────────────────────────

class _RecipeView extends ConsumerStatefulWidget {
  final RecipeModel? recipe;
  const _RecipeView({required this.recipe});

  @override
  ConsumerState<_RecipeView> createState() => _RecipeViewState();
}

class _RecipeViewState extends ConsumerState<_RecipeView> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _ingredientsCtrl;
  late final TextEditingController _instructionsCtrl;
  late RecipeCategory _category;
  late bool _favorite;
  bool _editing = false;
  bool _saving = false;

  bool get _isNew => widget.recipe == null;

  @override
  void initState() {
    super.initState();
    final r = widget.recipe;
    _titleCtrl = TextEditingController(text: r?.title ?? '');
    _ingredientsCtrl = TextEditingController(text: r?.ingredients ?? '');
    _instructionsCtrl = TextEditingController(text: r?.instructions ?? '');
    _category = r?.category ?? RecipeCategory.other;
    _favorite = r?.favorite ?? false;
    if (_isNew) _editing = true;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _ingredientsCtrl.dispose();
    _instructionsCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) return;
    final coupleId = ref.read(coupleIdProvider);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (coupleId == null) return;
    setState(() => _saving = true);
    try {
      final recipe = RecipeModel(
        id: widget.recipe?.id ?? const Uuid().v4(),
        title: title,
        category: _category,
        ingredients: _ingredientsCtrl.text.trim().isEmpty ? null : _ingredientsCtrl.text.trim(),
        instructions: _instructionsCtrl.text.trim().isEmpty ? null : _instructionsCtrl.text.trim(),
        favorite: _favorite,
        addedBy: widget.recipe?.addedBy ?? uid ?? '',
        createdAt: widget.recipe?.createdAt ?? DateTime.now(),
      );
      if (_isNew) {
        await ref.read(firestoreServiceProvider).addRecipe(coupleId, recipe);
      } else {
        await ref.read(firestoreServiceProvider).updateRecipe(coupleId, recipe);
      }
      if (mounted) {
        if (_isNew) {
          Navigator.of(context).pop();
        } else {
          setState(() {
            _editing = false;
            _saving = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving: $e')));
      }
    }
  }

  Future<void> _delete() async {
    final coupleId = ref.read(coupleIdProvider);
    final recipe = widget.recipe;
    if (coupleId == null || recipe == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete this recipe?', style: TextStyle(color: AppColors.textPrimary)),
        content: Text('"${recipe.title}"', style: const TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: AppColors.rose)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await ref.read(firestoreServiceProvider).deleteRecipe(coupleId, recipe.id);
      if (mounted) Navigator.of(context).pop();
    }
  }

  Future<void> _toggleFavorite() async {
    setState(() => _favorite = !_favorite);
    final coupleId = ref.read(coupleIdProvider);
    if (coupleId == null || _isNew) return;
    await ref.read(firestoreServiceProvider).toggleFavoriteRecipe(coupleId, widget.recipe!.id, _favorite);
  }

  @override
  Widget build(BuildContext context) {
    final color = _bookColor(widget.recipe?.id ?? 'new');

    return Scaffold(
      backgroundColor: const Color(0xFF1A1208),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1208),
        iconTheme: const IconThemeData(color: _kGold),
        title: _editing
            ? TextField(
                controller: _titleCtrl,
                style: GoogleFonts.playfairDisplay(color: _kGold, fontSize: 18, fontWeight: FontWeight.bold),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Recipe title…',
                  hintStyle: TextStyle(color: Color(0x55F5DEB3)),
                ),
              )
            : Text(_titleCtrl.text,
                style: GoogleFonts.playfairDisplay(color: _kGold, fontSize: 18, fontWeight: FontWeight.bold)),
        actions: [
          if (!_isNew)
            IconButton(
              icon: Icon(_favorite ? Icons.star_rounded : Icons.star_border_rounded,
                  color: _favorite ? const Color(0xFFFFD700) : _kGold),
              onPressed: _toggleFavorite,
            ),
          if (!_isNew && !_editing)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: AppColors.rose),
              onPressed: _delete,
            ),
          if (_editing)
            if (_saving)
              const Padding(
                padding: EdgeInsets.all(16),
                child: SizedBox(
                    width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: _kGold)),
              )
            else
              TextButton(
                onPressed: _save,
                child: Text('Save', style: GoogleFonts.lato(color: color, fontWeight: FontWeight.bold)),
              )
          else
            IconButton(
              icon: const Icon(Icons.edit_rounded, color: _kGold),
              onPressed: () => setState(() => _editing = true),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: RecipeCategory.values.map((c) {
                final selected = c == _category;
                return GestureDetector(
                  onTap: _editing ? () => setState(() => _category = c) : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: selected ? color.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: selected ? color : Colors.white24),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_categoryIcon(c), size: 14, color: selected ? _kGold : Colors.white54),
                        const SizedBox(width: 6),
                        Text(_categoryLabel(c),
                            style: TextStyle(
                                color: selected ? _kGold : Colors.white54,
                                fontSize: 12,
                                fontWeight: selected ? FontWeight.w700 : FontWeight.normal)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            _PaperSection(
              label: 'Ingredients',
              controller: _ingredientsCtrl,
              editing: _editing,
              hint: 'One per line…',
            ),
            const SizedBox(height: 16),
            _PaperSection(
              label: 'Instructions',
              controller: _instructionsCtrl,
              editing: _editing,
              hint: 'Step by step…',
            ),
          ],
        ),
      ),
    );
  }
}

class _PaperSection extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool editing;
  final String hint;

  const _PaperSection({
    required this.label,
    required this.controller,
    required this.editing,
    required this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(),
            style: GoogleFonts.lato(
                color: _kGold, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 90),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFBF3E3),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: editing
              ? TextField(
                  controller: controller,
                  maxLines: null,
                  style: GoogleFonts.lato(color: const Color(0xFF2A1A0A), fontSize: 14, height: 1.6),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    // Without this, the field inherits the app's global
                    // dark-fill InputDecorationTheme, which is nearly as
                    // dark as this editor's own text color — hiding
                    // whatever's typed against its own background.
                    filled: false,
                    hintText: hint,
                    hintStyle: TextStyle(color: const Color(0xFF2A1A0A).withValues(alpha: 0.4)),
                  ),
                )
              : Text(
                  controller.text.isEmpty ? 'Nothing here yet' : controller.text,
                  style: GoogleFonts.lato(
                      color: const Color(0xFF2A1A0A).withValues(alpha: controller.text.isEmpty ? 0.4 : 1),
                      fontSize: 14,
                      height: 1.6,
                      fontStyle: controller.text.isEmpty ? FontStyle.italic : FontStyle.normal),
                ),
        ),
      ],
    );
  }
}
