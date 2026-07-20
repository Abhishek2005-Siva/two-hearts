import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/delight/couple_character.dart';
import '../../core/presence/activity_announcer.dart';
import '../../core/providers/providers.dart';
import '../../core/theme/app_theme.dart';

// ── Date idea groups ──────────────────────────────────────────────────────
const _kDefaultGroups = {
  'Romantic 🌹': ['Candlelit dinner at home', 'Sunset picnic', 'Star gazing', 'Dance in the kitchen', 'Write love letters', 'Couples massage', 'Cook a new recipe together', 'Watch the sunrise'],
  'Adventure 🏕️': ['Hiking trail', 'Road trip', 'Try a new sport', 'Camping overnight', 'Escape room', 'Rock climbing', 'Kayaking', 'Explore a new city'],
  'Cozy 🛋️': ['Movie marathon', 'Board game night', 'Bake together', 'Build a blanket fort', 'Read books together', 'Puzzle night', 'Indoor picnic', 'Watch old photos'],
  'Foodie 🍜': ['Try a new restaurant', 'Street food tour', 'Cook a 3-course meal', 'Sushi making class', 'Brunch date', 'Ice cream tasting', 'Wine/mocktail tasting', 'Recreate a memory meal'],
  'Creative 🎨': ['Paint together', 'Take photos around the city', 'Make a scrapbook', 'Learn a dance', 'Write a short story together', 'DIY craft project', 'Pottery class', 'Make a playlist for each other'],
  'Long Distance 🌍': ['Video call dinner date', 'Watch a movie in sync', 'Online game night', 'Virtual museum tour', 'Cook the same recipe apart', 'Send surprise delivery', 'Stargaze on call together', 'Plan the next visit'],
};

class DateIdeasScreen extends ConsumerStatefulWidget {
  const DateIdeasScreen({super.key});

  @override
  ConsumerState<DateIdeasScreen> createState() => _DateIdeasScreenState();
}

class _DateIdeasScreenState extends ConsumerState<DateIdeasScreen>
    with ActivityAnnouncer {
  late Map<String, List<String>> _groups;
  late String _selectedGroup;
  int _selectedIndex = 0;
  late FixedExtentScrollController _scrollCtrl;

  @override
  void initState() {
    super.initState();
    announceActivity('Picking a date idea');
    _groups = Map<String, List<String>>.fromEntries(
      _kDefaultGroups.entries.map(
        (e) => MapEntry(e.key, List<String>.from(e.value)),
      ),
    );
    _selectedGroup = _groups.keys.first;
    _scrollCtrl = FixedExtentScrollController();
  }

  void _showPickMoment() {
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => const IgnorePointer(
        child: Center(
          child: CoupleCharacter(
            character: CoupleCharacterId.wren, pose: 'excited', height: 110),
        ),
      ),
    );
    overlay.insert(entry);
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (entry.mounted) entry.remove();
    });
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  List<String> get _ideas => _groups[_selectedGroup] ?? [];

  void _onGroupTap(String group) {
    if (group == _selectedGroup) return;
    setState(() {
      _selectedGroup = group;
      _selectedIndex = 0;
    });
    _scrollCtrl.jumpToItem(0);
  }

  Future<void> _spin() async {
    if (_ideas.isEmpty) return;
    HapticFeedback.mediumImpact();
    final target = Random().nextInt(_ideas.length);
    await _scrollCtrl.animateToItem(
      target,
      duration: const Duration(milliseconds: 1500),
      curve: Curves.easeOut,
    );
  }

  void _pickThis() {
    if (_ideas.isEmpty) return;
    final idea = _ideas[_selectedIndex];
    HapticFeedback.heavyImpact();
    _showPickMoment();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Locked in: $idea 🎉'),
        backgroundColor: ref.read(accentColorProvider),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _addIdea() async {
    final accent = ref.read(accentColorProvider);
    final ctrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Add idea to $_selectedGroup',
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 16)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: const InputDecoration(
            hintText: 'Your date idea…',
            hintStyle: TextStyle(color: AppColors.textMuted),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.divider),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.rose),
            ),
          ),
          onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()),
            child: Text('Add', style: TextStyle(color: accent,
                fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (result != null && result.isNotEmpty) {
      setState(() => _groups[_selectedGroup]!.add(result));
    }
  }

  void _removeIdea() {
    if (_ideas.isEmpty) return;
    final accent = ref.read(accentColorProvider);
    final removed = _ideas[_selectedIndex];
    setState(() {
      _groups[_selectedGroup]!.removeAt(_selectedIndex);
      if (_selectedIndex >= _ideas.length && _selectedIndex > 0) {
        _selectedIndex = _ideas.length - 1;
      }
    });
    if (_ideas.isNotEmpty) {
      _scrollCtrl.jumpToItem(_selectedIndex);
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Removed "$removed"'),
        backgroundColor: AppColors.bgCard,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        action: SnackBarAction(
          label: 'Undo',
          textColor: accent,
          onPressed: () {
            setState(() {
              _groups[_selectedGroup]!.insert(_selectedIndex, removed);
            });
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accent = ref.watch(accentColorProvider);
    final ideas = _ideas;
    final selectedIdea = ideas.isNotEmpty ? ideas[_selectedIndex] : '';

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: AppColors.bgGradient,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 20, 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: AppColors.textPrimary),
                      onPressed: () => Navigator.maybePop(context),
                    ),
                    Expanded(
                      child: Text('Date Idea',
                          style: Theme.of(context).textTheme.titleLarge),
                    ),
                    const Text('💡', style: TextStyle(fontSize: 24)),
                  ],
                ),
              ),
              // Group chips
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: _groups.keys.map((group) {
                    final isSelected = group == _selectedGroup;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () => _onGroupTap(group),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            gradient: isSelected
                                ? LinearGradient(
                                    colors: [accent, AppColors.coral])
                                : null,
                            color: isSelected ? null : AppColors.bgCard,
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                              color: isSelected
                                  ? Colors.transparent
                                  : AppColors.divider,
                              width: 0.5,
                            ),
                          ),
                          child: Text(
                            group,
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : AppColors.textSecondary,
                              fontSize: 13,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 12),

              // Wheel
              Expanded(
                child: ideas.isEmpty
                    ? const Center(
                        child: Text('No ideas yet. Add one below!',
                            style: TextStyle(color: AppColors.textMuted)))
                    : ListWheelScrollView.useDelegate(
                        key: ValueKey(_selectedGroup),
                        controller: _scrollCtrl,
                        itemExtent: 52,
                        perspective: 0.003,
                        diameterRatio: 2.5,
                        physics: const FixedExtentScrollPhysics(),
                        onSelectedItemChanged: (i) =>
                            setState(() => _selectedIndex = i),
                        childDelegate: ListWheelChildBuilderDelegate(
                          childCount: ideas.length,
                          builder: (ctx, i) => _IdeaTile(
                            index: i + 1,
                            text: ideas[i],
                            selected: i == _selectedIndex,
                            accent: accent,
                          ),
                        ),
                      ),
              ),

              // Selected idea highlight
              if (selectedIdea.isNotEmpty)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          accent.withValues(alpha: 0.18),
                          AppColors.coral.withValues(alpha: 0.10)
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border:
                          Border.all(color: accent.withValues(alpha: 0.35)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('✦ ',
                            style: TextStyle(color: accent, fontSize: 14)),
                        Flexible(
                          child: Text(
                            selectedIdea,
                            style: TextStyle(
                              color: accent,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        Text(' ✦',
                            style: TextStyle(color: accent, fontSize: 14)),
                      ],
                    ),
                  ),
                ),

              // Action buttons
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: _spin,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                                colors: [accent, AppColors.coral]),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                  color: accent.withValues(alpha: 0.4),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4))
                            ],
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('🎲', style: TextStyle(fontSize: 18)),
                              SizedBox(width: 8),
                              Text('Spin',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: _pickThis,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: AppColors.bgCard,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: accent.withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check_circle_rounded,
                                  color: accent, size: 18),
                              const SizedBox(width: 8),
                              Text('Pick This',
                                  style: TextStyle(
                                      color: accent,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Add / Remove row
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: _addIdea,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: AppColors.bgCard,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: AppColors.divider, width: 0.5),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_rounded,
                                  color: AppColors.textSecondary, size: 18),
                              SizedBox(width: 6),
                              Text('Add Idea',
                                  style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 13)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: ideas.isEmpty ? null : _removeIdea,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: AppColors.bgCard,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: AppColors.divider, width: 0.5),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.close_rounded,
                                  color: ideas.isEmpty
                                      ? AppColors.textMuted
                                      : AppColors.textSecondary,
                                  size: 18),
                              const SizedBox(width: 6),
                              Text('Remove',
                                  style: TextStyle(
                                      color: ideas.isEmpty
                                          ? AppColors.textMuted
                                          : AppColors.textSecondary,
                                      fontSize: 13)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IdeaTile extends StatelessWidget {
  final int index;
  final String text;
  final bool selected;
  final Color accent;

  const _IdeaTile({
    required this.index,
    required this.text,
    required this.selected,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: selected ? accent.withValues(alpha: 0.2) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: selected
            ? Border.all(color: accent.withValues(alpha: 0.5))
            : null,
      ),
      child: Text(
        '$index. $text',
        style: TextStyle(
          color: selected ? accent : AppColors.textMuted,
          fontSize: selected ? 16 : 13,
          fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
        ),
        textAlign: TextAlign.center,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
