import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'desktop_theme_palettes.dart';

const _kAutoLogoutEnabled = 'desktop.auto_logout.enabled';
const _kAutoLogoutMinutes = 'desktop.auto_logout.minutes';
const _kColorTheme = 'desktop.theme.palette';
const _kOverridesPrefix = 'desktop.theme.overrides.';

@immutable
class DesktopAutoLogoutSettings {
  const DesktopAutoLogoutSettings({
    required this.enabled,
    required this.minutesSinceMidnight,
  });

  static const fallback = DesktopAutoLogoutSettings(
    enabled: true,
    minutesSinceMidnight: 18 * 60,
  );

  final bool enabled;
  final int minutesSinceMidnight;

  int get hour => (minutesSinceMidnight ~/ 60).clamp(0, 23);
  int get minute => (minutesSinceMidnight % 60).clamp(0, 59);

  String get label {
    final rawHour = hour % 12 == 0 ? 12 : hour % 12;
    final suffix = hour >= 12 ? 'PM' : 'AM';
    final mm = minute.toString().padLeft(2, '0');
    return '$rawHour:$mm $suffix';
  }

  DesktopAutoLogoutSettings copyWith({
    bool? enabled,
    int? minutesSinceMidnight,
  }) {
    return DesktopAutoLogoutSettings(
      enabled: enabled ?? this.enabled,
      minutesSinceMidnight: minutesSinceMidnight ?? this.minutesSinceMidnight,
    );
  }
}

class DesktopLocalSettings {
  DesktopLocalSettings._();

  static final ValueNotifier<DesktopAutoLogoutSettings> autoLogout =
      ValueNotifier<DesktopAutoLogoutSettings>(
    DesktopAutoLogoutSettings.fallback,
  );

  static final ValueNotifier<DesktopThemeId> colorTheme =
      ValueNotifier<DesktopThemeId>(DesktopThemeId.grayWhite);
  static final ValueNotifier<Map<DesktopThemeId, Map<String, int>>>
      themeColorOverrides =
      ValueNotifier<Map<DesktopThemeId, Map<String, int>>>({});

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_kAutoLogoutEnabled) ?? true;
    final minutes = prefs.getInt(_kAutoLogoutMinutes) ?? (18 * 60);
    autoLogout.value = DesktopAutoLogoutSettings(
      enabled: enabled,
      minutesSinceMidnight: minutes.clamp(0, 1439),
    );
    colorTheme.value =
        DesktopThemeId.fromStorage(prefs.getString(_kColorTheme));

    final overrides = <DesktopThemeId, Map<String, int>>{};
    for (final id in DesktopThemeId.values) {
      final raw = prefs.getString('$_kOverridesPrefix${id.storageKey}');
      if (raw == null || raw.isEmpty) continue;
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          overrides[id] = {
            for (final entry in decoded.entries)
              entry.key.toString(): (entry.value as num).toInt(),
          };
        }
      } catch (_) {}
    }
    themeColorOverrides.value = overrides;
  }

  static Future<void> saveAutoLogout(DesktopAutoLogoutSettings value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kAutoLogoutEnabled, value.enabled);
    await prefs.setInt(
      _kAutoLogoutMinutes,
      value.minutesSinceMidnight.clamp(0, 1439),
    );
    autoLogout.value = value.copyWith(
      minutesSinceMidnight: value.minutesSinceMidnight.clamp(0, 1439),
    );
  }

  static Map<String, int> overridesFor(DesktopThemeId id) =>
      Map<String, int>.from(themeColorOverrides.value[id] ?? const {});

  static Future<void> setColorTheme(DesktopThemeId id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kColorTheme, id.storageKey);
    colorTheme.value = id;
  }

  static Future<void> setThemeColorOverrides(
    DesktopThemeId id,
    Map<String, int> overrides,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final next = Map<DesktopThemeId, Map<String, int>>.from(
      themeColorOverrides.value,
    );
    if (overrides.isEmpty) {
      next.remove(id);
      await prefs.remove('$_kOverridesPrefix${id.storageKey}');
    } else {
      next[id] = Map<String, int>.from(overrides);
      await prefs.setString(
        '$_kOverridesPrefix${id.storageKey}',
        jsonEncode(overrides),
      );
    }
    themeColorOverrides.value = next;
  }

  static Future<void> resetThemeColorOverrides(DesktopThemeId id) async {
    await setThemeColorOverrides(id, const {});
  }
}
