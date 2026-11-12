// App theming (Noor Glass 1.1.0) | FULL theming, unlike Prayer YEG
// where the Quran palette was fixed by design. Here the picked
// theme drives every surface: library, Now Playing sleeve, lyrics
// (including the playing-ayah card), mini player, Mushaf reader
// and the home-screen widgets. The deep green and gold look is
// simply the default preset (Mosque Green), not a hardcode.
//
// Adapted from Prayer YEG's AppSettings (same keys style, same
// contrast guards): stored with shared_preferences, which on
// Android writes into FlutterSharedPreferences.xml (keys get a
// "flutter." prefix there); the Kotlin widgets read the flat
// widget hex keys from that file, exactly like Prayer YEG.
//
// Copyright (c) 2026 c12n Apps.

import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Applies the stored alternate launcher icon natively
/// (activity-alias switching in MainActivity.kt). Safe when the
/// channel is unavailable (tests, other platforms).
Future<void> applyLauncherIcon(String name) async {
  try {
    await const MethodChannel('noorglass/icons')
        .invokeMethod<void>('setIcon', {'name': name});
  } catch (_) {
    // The pick is still persisted and applies on next launch.
  }
}

class NoorThemePreset {
  final String id;
  final String name;
  final int primaryHex;
  final int accentHex;
  final int textHex;
  final ThemeMode mode;
  const NoorThemePreset({
    required this.id,
    required this.name,
    required this.primaryHex,
    required this.accentHex,
    required this.textHex,
    required this.mode,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'primaryHex': primaryHex,
        'accentHex': accentHex,
        'textHex': textHex,
        'mode': mode.name,
      };

  static NoorThemePreset fromJson(Map<String, dynamic> json) =>
      NoorThemePreset(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? 'Theme',
        primaryHex: (json['primaryHex'] as num?)?.toInt() ??
            AppThemeSettings.defaultPrimary,
        accentHex: (json['accentHex'] as num?)?.toInt() ??
            AppThemeSettings.defaultAccent,
        textHex:
            (json['textHex'] as num?)?.toInt() ?? AppThemeSettings.defaultText,
        mode: ThemeMode.values.asNameMap()[json['mode'] as String?] ??
            ThemeMode.system,
      );
}

/// The eight theme presets (primary + accent pairs). Values mirror
/// Prayer YEG's preset family so both apps feel related; Mosque
/// Green is the default.
const noorThemePresets = <NoorThemePreset>[
  NoorThemePreset(
      id: 'mosque',
      name: 'Mosque Green',
      primaryHex: 0x0B3D2E,
      accentHex: 0xD4AF37,
      textHex: 0xFFFFFF,
      mode: ThemeMode.system),
  NoorThemePreset(
      id: 'ocean',
      name: 'Ocean Depths',
      primaryHex: 0x083344,
      accentHex: 0x67E8F9,
      textHex: 0xECFEFF,
      mode: ThemeMode.dark),
  NoorThemePreset(
      id: 'desert',
      name: 'Desert Dunes',
      primaryHex: 0x6B4420,
      accentHex: 0xF2C14E,
      textHex: 0xFFF8E7,
      mode: ThemeMode.system),
  NoorThemePreset(
      id: 'emerald',
      name: 'Emerald Night',
      primaryHex: 0x052E22,
      accentHex: 0x34D399,
      textHex: 0xECFDF5,
      mode: ThemeMode.dark),
  NoorThemePreset(
      id: 'crimson',
      name: 'Crimson Dusk',
      primaryHex: 0x450A0A,
      accentHex: 0xFCA5A5,
      textHex: 0xFEF2F2,
      mode: ThemeMode.dark),
  NoorThemePreset(
      id: 'sapphire',
      name: 'Sapphire Noor',
      primaryHex: 0x172554,
      accentHex: 0x93C5FD,
      textHex: 0xEFF6FF,
      mode: ThemeMode.dark),
  NoorThemePreset(
      id: 'plum',
      name: 'Plum Velvet',
      primaryHex: 0x3B0764,
      accentHex: 0xF0ABFC,
      textHex: 0xFAF5FF,
      mode: ThemeMode.dark),
  NoorThemePreset(
      id: 'contrast',
      name: 'High Contrast',
      primaryHex: 0x000000,
      accentHex: 0xFFD60A,
      textHex: 0xFFFFFF,
      mode: ThemeMode.dark),
];

/// Accent choices offered next to the custom color picker.
const noorAccentPresets = <(String, int)>[
  ('Gold', 0xD4AF37),
  ('Emerald', 0x10B981),
  ('Teal', 0x14B8A6),
  ('Sky', 0x38BDF8),
  ('Blue', 0x3B82F6),
  ('Violet', 0x8B5CF6),
  ('Rose', 0xF43F5E),
  ('Orange', 0xF97316),
];

/// Alternate launcher icons, one per theme family (plus the
/// default). Switched natively through activity-alias entries;
/// see MainActivity.kt ('noorglass/icons' channel).
const kNoorIconNames = [
  'default',
  'ocean',
  'desert',
  'emerald',
  'crimson',
  'sapphire',
  'plum',
  'contrast',
];

class AppThemeSettings extends ChangeNotifier {
  static const modeKey = 'appearance.mode';
  static const primaryKey = 'appearance.primaryHex';
  static const accentKey = 'appearance.accentHex';
  static const textKey = 'appearance.textHex';
  static const dynamicColorKey = 'appearance.dynamicColor';
  static const appIconKey = 'appearance.appIcon';
  // Widget colors: 'match' (widgets follow the app theme) or
  // 'separate' (widgets get their own palette). The flat hex keys
  // mirror the effective widget colors for the Kotlin widgets,
  // which read raw values out of FlutterSharedPreferences.
  static const widgetColorModeKey = 'appearance.widgetColorMode';
  static const widgetThemeJsonKey = 'appearance.partTheme.home';
  static const widgetHomePrimaryKey = 'appearance.widgetTheme.home.primaryHex';
  static const widgetHomeAccentKey = 'appearance.widgetTheme.home.accentHex';
  static const widgetHomeTextKey = 'appearance.widgetTheme.home.textHex';

  static const defaultPrimary = 0x0B3D2E;
  static const defaultAccent = 0xD4AF37;
  static const defaultText = 0xFFFFFF;

  ThemeMode mode = ThemeMode.system;
  int primaryHex = defaultPrimary;
  int accentHex = defaultAccent;
  int textHex = defaultText;
  bool textIsCustom = false;

  /// Material You dynamic color: ON means the wallpaper scheme
  /// overrides the preset primary (the picked accent still applies
  /// to accents and highlights). Default ON, as shipped in 1.0.0.
  bool dynamicColor = true;

  /// Runtime hint (never persisted): whether the platform
  /// actually provided a dynamic scheme this run. Set by the app
  /// root from DynamicColorBuilder; sleeve surfaces read it.
  bool dynamicAvailable = false;

  String widgetColorMode = 'match';
  NoorThemePreset? homeWidgetTheme;

  String appIcon = 'default';

  int get effectiveWidgetPrimary =>
      (widgetColorMode == 'separate' ? homeWidgetTheme?.primaryHex : null) ??
      primaryHex;
  int get effectiveWidgetAccent =>
      (widgetColorMode == 'separate' ? homeWidgetTheme?.accentHex : null) ??
      accentHex;
  int get effectiveWidgetText =>
      (widgetColorMode == 'separate' ? homeWidgetTheme?.textHex : null) ??
      textHex;

  SharedPreferences? _prefs;

  static Future<AppThemeSettings> load(SharedPreferences prefs) async {
    final s = AppThemeSettings();
    s._prefs = prefs;
    s.mode = switch (prefs.getString(modeKey)) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    s.primaryHex = prefs.getInt(primaryKey) ?? defaultPrimary;
    s.accentHex = prefs.getInt(accentKey) ?? defaultAccent;
    final storedText = prefs.getInt(textKey);
    if (storedText != null) {
      s.textHex = storedText;
      s.textIsCustom = true;
    }
    s.dynamicColor = prefs.getBool(dynamicColorKey) ?? true;
    s.widgetColorMode =
        prefs.getString(widgetColorModeKey) == 'separate' ? 'separate' : 'match';
    final rawWidget = prefs.getString(widgetThemeJsonKey);
    if (rawWidget != null) {
      try {
        s.homeWidgetTheme = NoorThemePreset.fromJson(
            jsonDecode(rawWidget) as Map<String, dynamic>);
      } catch (_) {
        s.homeWidgetTheme = null;
      }
    }
    final storedIcon = prefs.getString(appIconKey);
    s.appIcon =
        storedIcon != null && kNoorIconNames.contains(storedIcon)
            ? storedIcon
            : 'default';
    return s;
  }

  Future<void> _save() async {
    final prefs = _prefs;
    if (prefs == null) return;
    await prefs.setString(modeKey, mode.name);
    await prefs.setInt(primaryKey, primaryHex);
    await prefs.setInt(accentKey, accentHex);
    if (textIsCustom) {
      await prefs.setInt(textKey, textHex);
    } else {
      await prefs.remove(textKey);
    }
    await prefs.setBool(dynamicColorKey, dynamicColor);
    await prefs.setString(appIconKey, appIcon);
    await prefs.setString(widgetColorModeKey, widgetColorMode);
    final widgetTheme = homeWidgetTheme;
    if (widgetTheme != null) {
      await prefs.setString(
          widgetThemeJsonKey, jsonEncode(widgetTheme.toJson()));
    } else {
      await prefs.remove(widgetThemeJsonKey);
    }
    await prefs.setInt(widgetHomePrimaryKey, effectiveWidgetPrimary);
    await prefs.setInt(widgetHomeAccentKey, effectiveWidgetAccent);
    await prefs.setInt(widgetHomeTextKey, effectiveWidgetText);
  }

  /// Applies a change, notifies the UI and persists everything.
  void update(void Function() change) {
    change();
    notifyListeners();
    _save();
  }

  bool isActivePreset(NoorThemePreset p) =>
      primaryHex == p.primaryHex &&
      accentHex == p.accentHex &&
      textHex == p.textHex &&
      mode == p.mode;

  void applyPreset(NoorThemePreset p) => update(() {
        primaryHex = p.primaryHex;
        accentHex = p.accentHex;
        textHex = p.textHex;
        textIsCustom = true;
        mode = p.mode;
      });

  void resetToDefaults() => update(() {
        mode = ThemeMode.system;
        primaryHex = defaultPrimary;
        accentHex = defaultAccent;
        textHex = defaultText;
        textIsCustom = false;
        dynamicColor = true;
        widgetColorMode = 'match';
        homeWidgetTheme = null;
      });
}

/// Gives the widget tree access to the current [AppThemeSettings].
class ThemeScope extends InheritedWidget {
  final AppThemeSettings settings;
  const ThemeScope({super.key, required this.settings, required super.child});

  static AppThemeSettings of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ThemeScope>()!.settings;

  @override
  bool updateShouldNotify(ThemeScope oldWidget) =>
      settings != oldWidget.settings;
}

// MARK: - Color helpers (ports of Prayer YEG's contrast guards)

Color colorFromHex(int hex) => Color(0xFF000000 | (hex & 0xFFFFFF));

int hexFromColor(Color c) =>
    ((c.r * 255).round() << 16) | ((c.g * 255).round() << 8) | (c.b * 255).round();

Color lightenColor(Color c, double fraction) {
  final hsv = HSVColor.fromColor(c);
  return hsv
      .withValue(hsv.value + (1 - hsv.value) * fraction)
      .withSaturation(hsv.saturation * (1 - fraction * 0.35))
      .toColor();
}

Color darkenColor(Color c, double fraction) {
  final hsv = HSVColor.fromColor(c);
  return hsv.withValue(hsv.value * (1 - fraction)).toColor();
}

/// Brighten for dark surfaces (brightness at least 0.82).
Color adjustAccentForDark(Color c) {
  final hsv = HSVColor.fromColor(c);
  return hsv
      .withValue(math.max(hsv.value, 0.82))
      .withSaturation(math.min(hsv.saturation, 0.9))
      .toColor();
}

/// Deepen for light surfaces (brightness at most 0.42).
Color adjustAccentForLight(Color c) {
  final hsv = HSVColor.fromColor(c);
  return hsv
      .withValue(math.min(hsv.value, 0.42))
      .withSaturation(hsv.saturation.clamp(0.55, 1.0))
      .toColor();
}

/// The picked accent adjusted so it stays readable on a surface
/// of the given brightness.
Color accentFor(Brightness brightness, AppThemeSettings s) {
  final base = colorFromHex(s.accentHex);
  return brightness == Brightness.dark
      ? adjustAccentForDark(base)
      : adjustAccentForLight(base);
}

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = math.max(la, lb);
  final lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

Color _ensureContrast(Color fg, Color bg, Color toward, double minimum) {
  if (_contrast(fg, bg) >= minimum) return fg;
  for (var step = 1; step <= 10; step++) {
    final blended = Color.lerp(fg, toward, step / 10)!;
    if (_contrast(blended, bg) >= minimum) return blended;
  }
  return toward;
}

/// The text color worn on the primary ("sleeve") surfaces: Now
/// Playing, the mini player, the playing ayah card, the widgets.
/// Defaults to white; a picked text color is contrast-guarded to
/// about 4.5:1 against the primary, like Prayer YEG.
Color onPrimaryTextColor(AppThemeSettings s) {
  final primary = colorFromHex(s.primaryHex);
  if (!s.textIsCustom) return Colors.white;
  return _ensureContrast(colorFromHex(s.textHex), primary, Colors.white, 4.5);
}

/// Secondary text on sleeve surfaces: the on-primary text at 72%,
/// floored by the same contrast guard against the primary.
Color onPrimaryMutedColor(AppThemeSettings s) {
  final primary = colorFromHex(s.primaryHex);
  final base = onPrimaryTextColor(s).withValues(alpha: 0.72);
  return _ensureContrast(base, primary, Colors.white, 3.0);
}

/// The sleeve gradient for Now Playing and the mini player:
/// the theme primary, lightened at the top, deepened at the foot.
List<Color> sleeveGradient(AppThemeSettings s) {
  final primary = colorFromHex(s.primaryHex);
  return [lightenColor(primary, 0.13), primary, darkenColor(primary, 0.38)];
}
