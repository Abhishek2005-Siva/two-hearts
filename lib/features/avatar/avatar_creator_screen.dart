import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/providers.dart';
import '../../core/theme/app_theme.dart';
import 'avatar_model.dart';
import 'avatar_painter.dart';
import 'avatar_widget.dart';

// ── Category enum ─────────────────────────────────────────────────────────

enum _Category { skin, face, hair, eyes, outfit, extras }

extension _CategoryLabel on _Category {
  String get label {
    switch (this) {
      case _Category.skin:   return 'Skin';
      case _Category.face:   return 'Face';
      case _Category.hair:   return 'Hair';
      case _Category.eyes:   return 'Eyes';
      case _Category.outfit: return 'Outfit';
      case _Category.extras: return 'Extras';
    }
  }

  String get icon {
    switch (this) {
      case _Category.skin:   return '🎨';
      case _Category.face:   return '🫦';
      case _Category.hair:   return '💇';
      case _Category.eyes:   return '👁';
      case _Category.outfit: return '👕';
      case _Category.extras: return '✨';
    }
  }
}

// ── Creator Screen ────────────────────────────────────────────────────────

class AvatarCreatorScreen extends ConsumerStatefulWidget {
  const AvatarCreatorScreen({super.key});

  @override
  ConsumerState<AvatarCreatorScreen> createState() => _AvatarCreatorScreenState();
}

class _AvatarCreatorScreenState extends ConsumerState<AvatarCreatorScreen> {
  late AvatarConfig _config;
  _Category _selectedCategory = _Category.skin;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // Start from existing config or default
    final existing = ref.read(currentUserProvider).valueOrNull?.avatarConfig;
    _config = existing ?? AvatarConfig.defaultConfig();
  }

  void _setCategory(_Category c) {
    setState(() => _selectedCategory = c);
  }

  Future<void> _save() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    setState(() => _saving = true);
    try {
      await ref.read(firestoreServiceProvider).updateAvatarConfig(uid, _config);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Your Avatar'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: _saving ? null : _save,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.rose, AppColors.coral],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: _saving
                    ? const SizedBox(width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Save',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Preview ──────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            color: AppColors.bgMid,
            child: Column(
              children: [
                AvatarWidget(config: _config, size: 180)
                    .animate(key: ValueKey(_config.hashCode))
                    .fadeIn(duration: 200.ms)
                    .scale(begin: const Offset(0.92, 0.92), duration: 220.ms, curve: Curves.easeOut),
                const SizedBox(height: 8),
                const Text(
                  'Your avatar',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
              ],
            ),
          ),

          // ── Category tabs ─────────────────────────────────────────────────
          Container(
            height: 54,
            color: AppColors.bgCard,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: _Category.values.map((cat) {
                final selected = cat == _selectedCategory;
                return GestureDetector(
                  onTap: () => _setCategory(cat),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: selected
                          ? const LinearGradient(
                              colors: [AppColors.rose, AppColors.coral],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            )
                          : null,
                      color: selected ? null : AppColors.bgCardLight,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: selected ? Colors.transparent : AppColors.divider,
                        width: 0.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(cat.icon, style: const TextStyle(fontSize: 13)),
                        const SizedBox(width: 5),
                        Text(
                          cat.label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                            color: selected ? Colors.white : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          // ── Options grid ──────────────────────────────────────────────────
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 280),
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.06, 0),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              ),
              child: _OptionsPanel(
                key: ValueKey(_selectedCategory),
                category: _selectedCategory,
                config: _config,
                onChanged: (cfg) => setState(() => _config = cfg),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Options panel ─────────────────────────────────────────────────────────

class _OptionsPanel extends StatelessWidget {
  final _Category category;
  final AvatarConfig config;
  final ValueChanged<AvatarConfig> onChanged;

  const _OptionsPanel({
    super.key,
    required this.category,
    required this.config,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    switch (category) {
      case _Category.skin:
        return _ColorSwatchList(
          colors: kSkinTones,
          selected: config.skinTone,
          onSelect: (i) => onChanged(config.copyWith(skinTone: i)),
        );
      case _Category.face:
        return _AvatarOptionList(
          count: 4,
          selected: config.faceShape,
          labels: const ['Round', 'Oval', 'Square', 'Heart'],
          configFor: (i) => config.copyWith(faceShape: i),
          onSelect: (i) => onChanged(config.copyWith(faceShape: i)),
        );
      case _Category.hair:
        return Column(
          children: [
            _SubLabel(label: 'Style'),
            Expanded(
              child: _AvatarOptionList(
                count: 8,
                selected: config.hairStyle,
                labels: const [
                  'Short Crop', 'Side Part', 'Wavy', 'Long Straight',
                  'Curly Afro', 'Bun', 'Ponytail', 'Buzz Cut',
                ],
                configFor: (i) => config.copyWith(hairStyle: i),
                onSelect: (i) => onChanged(config.copyWith(hairStyle: i)),
              ),
            ),
            _SubLabel(label: 'Color'),
            SizedBox(
              height: 72,
              child: _ColorSwatchList(
                colors: kHairColors,
                selected: config.hairColor,
                onSelect: (i) => onChanged(config.copyWith(hairColor: i)),
              ),
            ),
          ],
        );
      case _Category.eyes:
        return Column(
          children: [
            _SubLabel(label: 'Style'),
            Expanded(
              child: _AvatarOptionList(
                count: 5,
                selected: config.eyeStyle,
                labels: const ['Round', 'Almond', 'Wide Anime', 'Hooded', 'Lashes'],
                configFor: (i) => config.copyWith(eyeStyle: i),
                onSelect: (i) => onChanged(config.copyWith(eyeStyle: i)),
              ),
            ),
            _SubLabel(label: 'Color'),
            SizedBox(
              height: 72,
              child: _ColorSwatchList(
                colors: kEyeColors,
                selected: config.eyeColor,
                onSelect: (i) => onChanged(config.copyWith(eyeColor: i)),
              ),
            ),
          ],
        );
      case _Category.outfit:
        return Column(
          children: [
            _SubLabel(label: 'Style'),
            Expanded(
              child: _AvatarOptionList(
                count: 6,
                selected: config.outfitStyle,
                labels: const ['T-Shirt', 'Hoodie', 'Dress', 'Collar Shirt', 'Sweater', 'Jacket'],
                configFor: (i) => config.copyWith(outfitStyle: i),
                onSelect: (i) => onChanged(config.copyWith(outfitStyle: i)),
              ),
            ),
            _SubLabel(label: 'Color'),
            SizedBox(
              height: 72,
              child: _ColorSwatchList(
                colors: kOutfitColors,
                selected: config.outfitColor,
                onSelect: (i) => onChanged(config.copyWith(outfitColor: i)),
              ),
            ),
          ],
        );
      case _Category.extras:
        return _AvatarOptionList(
          count: 5,
          selected: config.accessory,
          labels: const ['None', 'Glasses', 'Sunglasses', 'Headband', 'Crown'],
          configFor: (i) => config.copyWith(accessory: i),
          onSelect: (i) => onChanged(config.copyWith(accessory: i)),
        );
    }
  }
}

// ── Sub-label ──────────────────────────────────────────────────────────────

class _SubLabel extends StatelessWidget {
  final String label;
  const _SubLabel({required this.label});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
            ),
          ),
        ),
      );
}

// ── Color swatch list ─────────────────────────────────────────────────────

class _ColorSwatchList extends StatelessWidget {
  final List<Color> colors;
  final int selected;
  final ValueChanged<int> onSelect;

  const _ColorSwatchList({
    required this.colors,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: colors.length,
      itemBuilder: (_, i) {
        final isSelected = i == selected;
        return GestureDetector(
          onTap: () => onSelect(i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 52,
            height: 52,
            margin: const EdgeInsets.only(right: 10),
            decoration: BoxDecoration(
              color: colors[i],
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? Colors.white : Colors.transparent,
                width: 3,
              ),
              boxShadow: isSelected
                  ? [BoxShadow(color: colors[i].withValues(alpha: 0.6), blurRadius: 12, spreadRadius: 2)]
                  : null,
            ),
            child: isSelected
                ? const Icon(Icons.check_rounded, color: Colors.white, size: 22)
                : null,
          ),
        );
      },
    );
  }
}

// ── Avatar option list ────────────────────────────────────────────────────

class _AvatarOptionList extends StatelessWidget {
  final int count;
  final int selected;
  final List<String> labels;
  final AvatarConfig Function(int) configFor;
  final ValueChanged<int> onSelect;

  const _AvatarOptionList({
    required this.count,
    required this.selected,
    required this.labels,
    required this.configFor,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      itemCount: count,
      itemBuilder: (_, i) {
        final isSelected = i == selected;
        final previewConfig = configFor(i);
        return GestureDetector(
          onTap: () => onSelect(i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 80,
            margin: const EdgeInsets.only(right: 10),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.rose.withValues(alpha: 0.15) : AppColors.bgCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? AppColors.rose : AppColors.divider,
                width: isSelected ? 2.0 : 0.5,
              ),
              boxShadow: isSelected
                  ? [BoxShadow(color: AppColors.rose.withValues(alpha: 0.25), blurRadius: 10)]
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  height: 80,
                  child: AvatarWidget(config: previewConfig, size: 72),
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    labels.length > i ? labels[i] : '${i + 1}',
                    style: TextStyle(
                      fontSize: 10,
                      color: isSelected ? AppColors.rose : AppColors.textMuted,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 4),
              ],
            ),
          ),
        );
      },
    );
  }
}
