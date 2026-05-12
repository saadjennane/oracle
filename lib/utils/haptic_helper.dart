import 'package:flutter/services.dart';

enum HapticIntensity {
  light,
  medium;

  String get displayName {
    switch (this) {
      case HapticIntensity.light:
        return 'Light';
      case HapticIntensity.medium:
        return 'Medium';
    }
  }
}

/// Plays a haptic confirmation pattern based on the option index (0-based).
///
/// Mapping:
///   option 0 → 1 pulse
///   option 1 → 2 pulses
///   option 2 → 3 pulses
///   option 3 → 3 pulses, pause, 1 pulse
///   option 4 → 3 pulses, pause, 2 pulses
///   option 5 → 3 pulses, pause, 3 pulses
class HapticHelper {
  static const _pulseDuration = Duration(milliseconds: 150);
  static const _groupPause = Duration(milliseconds: 400);

  static Future<void> confirmOption(int optionIndex, {HapticIntensity intensity = HapticIntensity.medium}) async {
    final pattern = _patternForOption(optionIndex);
    await _playPattern(pattern, intensity);
  }

  /// Returns a list of int groups representing the haptic pattern.
  /// e.g. [3, 2] means 3 pulses, pause, then 2 pulses.
  static List<int> _patternForOption(int optionIndex) {
    switch (optionIndex) {
      case 0:
        return [1];
      case 1:
        return [2];
      case 2:
        return [3];
      case 3:
        return [3, 1];
      case 4:
        return [3, 2];
      case 5:
        return [3, 3];
      default:
        return [1];
    }
  }

  static Future<void> _playPattern(List<int> groups, HapticIntensity intensity) async {
    for (int g = 0; g < groups.length; g++) {
      if (g > 0) {
        await Future.delayed(_groupPause);
      }
      for (int i = 0; i < groups[g]; i++) {
        if (i > 0) {
          await Future.delayed(_pulseDuration);
        }
        switch (intensity) {
          case HapticIntensity.light:
            HapticFeedback.lightImpact();
            break;
          case HapticIntensity.medium:
            HapticFeedback.mediumImpact();
            break;
        }
      }
    }
  }
}
