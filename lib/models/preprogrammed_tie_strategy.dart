import 'language.dart';

/// Strategy for handling ties in preprogrammed First-To duel mode
enum PreprogrammedTieStrategy {
  /// On tie, repeat the same choice until it scores
  repeat,

  /// On tie, cycle through options (next option each tie) until it scores
  cycle;

  String toJson() => name;

  static PreprogrammedTieStrategy fromJson(String? value) {
    if (value == null) return PreprogrammedTieStrategy.repeat;
    return PreprogrammedTieStrategy.values.firstWhere(
      (e) => e.name == value,
      orElse: () => PreprogrammedTieStrategy.repeat,
    );
  }

  String displayName(Language locale) {
    switch (this) {
      case PreprogrammedTieStrategy.repeat:
        return locale == Language.french ? 'Répéter' : 'Repeat';
      case PreprogrammedTieStrategy.cycle:
        return locale == Language.french ? 'Cycle' : 'Cycle';
    }
  }

  String description(Language locale) {
    switch (this) {
      case PreprogrammedTieStrategy.repeat:
        return locale == Language.french
            ? 'En cas d\'égalité, répéter le même choix'
            : 'On tie, repeat the same choice';
      case PreprogrammedTieStrategy.cycle:
        return locale == Language.french
            ? 'En cas d\'égalité, passer à l\'option suivante'
            : 'On tie, cycle to the next option';
    }
  }
}
