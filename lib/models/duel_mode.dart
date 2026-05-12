import 'language.dart';

/// Duel game mode - determines how the game ends
enum DuelMode {
  /// Fixed number of rounds (existing behavior)
  fixedRounds,

  /// First player to reach target score wins
  firstTo;

  String toJson() => name;

  static DuelMode fromJson(String? value) {
    if (value == null) return DuelMode.fixedRounds;
    return DuelMode.values.firstWhere(
      (e) => e.name == value,
      orElse: () => DuelMode.fixedRounds,
    );
  }

  String displayName(Language locale) {
    switch (this) {
      case DuelMode.fixedRounds:
        return locale == Language.french ? 'Rounds Fixes' : 'Fixed Rounds';
      case DuelMode.firstTo:
        return locale == Language.french ? 'Premier à' : 'First To';
    }
  }

  String description(Language locale) {
    switch (this) {
      case DuelMode.fixedRounds:
        return locale == Language.french
            ? 'Nombre de rounds défini à l\'avance'
            : 'Predefined number of rounds';
      case DuelMode.firstTo:
        return locale == Language.french
            ? 'Premier joueur à atteindre le score cible'
            : 'First player to reach target score';
    }
  }
}
