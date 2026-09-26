import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Per-device "comfort" preferences — text size, layout density, and
/// reduced motion. Deliberately local (SharedPreferences), not synced via
/// Firestore: unlike the couple's shared accent color, reading comfort is
/// individual — the two partners may want different settings on their own
/// phones. Same persistence pattern as [ThemeModeNotifier] below, which
/// predates this file.

// ── Theme mode (moved here from providers.dart to live with its siblings)──

final themeModeProvider =
    NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);

class ThemeModeNotifier extends Notifier<ThemeMode> {
  static const _prefsKey = 'theme_mode';

  @override
  ThemeMode build() {
    SharedPreferences.getInstance().then((prefs) {
      final saved = prefs.getString(_prefsKey);
      if (saved == 'light') state = ThemeMode.light;
    });
    return ThemeMode.dark;
  }

  void set(ThemeMode mode) {
    state = mode;
    SharedPreferences.getInstance().then((prefs) =>
        prefs.setString(_prefsKey, mode == ThemeMode.light ? 'light' : 'dark'));
  }
}

// ── Text scale ──────────────────────────────────────────────────────────

enum TextScaleStep { small, standard, large, xLarge, xxLarge }

extension TextScaleStepValue on TextScaleStep {
  double get scale => switch (this) {
        TextScaleStep.small => 0.88,
        TextScaleStep.standard => 1.0,
        TextScaleStep.large => 1.12,
        TextScaleStep.xLarge => 1.22,
        TextScaleStep.xxLarge => 1.32,
      };

  String get label => switch (this) {
        TextScaleStep.small => 'Small',
        TextScaleStep.standard => 'Default',
        TextScaleStep.large => 'Large',
        TextScaleStep.xLarge => 'XL',
        TextScaleStep.xxLarge => 'XXL',
      };
}

final textScaleProvider =
    NotifierProvider<TextScaleNotifier, TextScaleStep>(TextScaleNotifier.new);

class TextScaleNotifier extends Notifier<TextScaleStep> {
  static const _prefsKey = 'text_scale_step';

  @override
  TextScaleStep build() {
    SharedPreferences.getInstance().then((prefs) {
      final saved = prefs.getInt(_prefsKey);
      if (saved != null && saved >= 0 && saved < TextScaleStep.values.length) {
        state = TextScaleStep.values[saved];
      }
    });
    return TextScaleStep.standard;
  }

  void set(TextScaleStep step) {
    state = step;
    SharedPreferences.getInstance().then((prefs) => prefs.setInt(_prefsKey, step.index));
  }
}

// ── Layout density ──────────────────────────────────────────────────────

enum AppDensity { compact, comfortable, spacious }

extension AppDensityValue on AppDensity {
  double get factor => switch (this) {
        AppDensity.compact => 0.75,
        AppDensity.comfortable => 1.0,
        AppDensity.spacious => 1.25,
      };

  String get label => switch (this) {
        AppDensity.compact => 'Compact',
        AppDensity.comfortable => 'Comfortable',
        AppDensity.spacious => 'Spacious',
      };

  /// Scaled version of this app's common screen-edge padding
  /// (`EdgeInsets.fromLTRB(20, 8, 20, 40)`-shaped values across most
  /// screens' outer ListView/scroll padding).
  EdgeInsets get screenPadding => EdgeInsets.fromLTRB(
        20 * factor,
        8 * factor,
        20 * factor,
        40 * factor,
      );

  /// Scaled version of a generic mid-size gap used between cards/sections.
  double get gap => 16 * factor;
}

final layoutDensityProvider =
    NotifierProvider<DensityNotifier, AppDensity>(DensityNotifier.new);

class DensityNotifier extends Notifier<AppDensity> {
  static const _prefsKey = 'layout_density';

  @override
  AppDensity build() {
    SharedPreferences.getInstance().then((prefs) {
      final saved = prefs.getString(_prefsKey);
      final match = AppDensity.values.where((d) => d.name == saved);
      if (match.isNotEmpty) state = match.first;
    });
    return AppDensity.comfortable;
  }

  void set(AppDensity density) {
    state = density;
    SharedPreferences.getInstance().then((prefs) => prefs.setString(_prefsKey, density.name));
  }
}

// ── Reduce motion ───────────────────────────────────────────────────────

final reduceMotionProvider =
    NotifierProvider<ReduceMotionNotifier, bool>(ReduceMotionNotifier.new);

class ReduceMotionNotifier extends Notifier<bool> {
  static const _prefsKey = 'reduce_motion';

  @override
  bool build() {
    SharedPreferences.getInstance().then((prefs) {
      final saved = prefs.getBool(_prefsKey);
      if (saved != null) state = saved;
    });
    return false;
  }

  void set(bool value) {
    state = value;
    SharedPreferences.getInstance().then((prefs) => prefs.setBool(_prefsKey, value));
  }
}

/// Reads [reduceMotionProvider] without a [WidgetRef] — for static
/// delight-layer helpers (`FloatingStickers.burst`, etc.) and the two
/// shared tap primitives (`SquishyTap`, `GradientButton`) that are called
/// from hundreds of sites across the app and can't reasonably all become
/// `Consumer`s. Safe because `ProviderScope` wraps the whole app in
/// `main.dart`.
bool isReduceMotion(BuildContext context) =>
    ProviderScope.containerOf(context, listen: false).read(reduceMotionProvider);

// ── Tap sound ───────────────────────────────────────────────────────────

/// 0.0 = off, up to 1.0 = full volume. Default is audible-but-gentle
/// rather than either extreme, so a first-run install isn't silently
/// mute nor startlingly loud.
final tapSoundVolumeProvider =
    NotifierProvider<TapSoundVolumeNotifier, double>(TapSoundVolumeNotifier.new);

class TapSoundVolumeNotifier extends Notifier<double> {
  static const _prefsKey = 'tap_sound_volume';

  @override
  double build() {
    SharedPreferences.getInstance().then((prefs) {
      final saved = prefs.getDouble(_prefsKey);
      if (saved != null) state = saved;
    });
    return 0.45;
  }

  void set(double value) {
    state = value.clamp(0.0, 1.0);
    SharedPreferences.getInstance().then((prefs) => prefs.setDouble(_prefsKey, state));
  }
}

/// Plays the app's one shared tap sound, respecting [tapSoundVolumeProvider]
/// (silently does nothing at 0). Static, for the same reason [isReduceMotion]
/// is: called from `SquishyTap`/`GradientButton`'s tap handlers, which are
/// used at hundreds of call sites and can't all become `Consumer`s.
///
/// Uses one shared low-latency `AudioPlayer` rather than a fresh instance
/// per tap — `PlayerMode.lowLatency` is `audioplayers`' own recommended
/// mode for exactly this "frequent, short UI sound effect" case, and
/// creating a new player per tap would be wasteful and could audibly
/// overlap/glitch on rapid repeated taps.
class TapSound {
  TapSound._();
  static final _player = AudioPlayer()..setPlayerMode(PlayerMode.lowLatency);
  static bool _primed = false;

  static Future<void> _prime() async {
    if (_primed) return;
    _primed = true;
    await _player.setSource(AssetSource('sounds/tap.wav'));
  }

  static void play(BuildContext context) {
    final volume =
        ProviderScope.containerOf(context, listen: false).read(tapSoundVolumeProvider);
    if (volume <= 0) return;
    _prime().then((_) {
      _player.setVolume(volume);
      _player.resume();
    });
  }
}
