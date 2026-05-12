/// Pattern types for spectator choices (CHOICES games only)
enum PatternType {
  /// Spectator heavily repeats one choice (e.g., A A A B)
  repeatHeavy,

  /// Spectator alternates frequently between choices
  alternateHeavy,

  /// Spectator maintains pattern then switches at the end
  lateSwitch,

  /// Mixed behavior, no dominant pattern
  mixed,
}

/// Outcome classification for GAME mode
enum OutcomeClass {
  /// All rounds match (0 misses)
  allHit,

  /// Most rounds match (1 miss max)
  mostlyHit,

  /// Mixed results (roughly half)
  mixed,

  /// Most rounds miss (1-2 hits max)
  mostlyMiss,

  /// All rounds miss (0 hits)
  allMiss,
}

/// Pattern facts extracted from spectator choices (CHOICES games only)
class PatternFacts {
  /// Count of each choice by index
  final Map<int, int> countsByIndex;

  /// Most frequently chosen index
  final int mostChosenIndex;

  /// How many times the most chosen was picked
  final int mostChosenCount;

  /// Index with longest consecutive streak
  final int longestStreakIndex;

  /// Length of longest streak
  final int longestStreakLen;

  /// Number of times spectator switched between choices
  final int switchCount;

  /// First choice index
  final int firstIndex;

  /// Last choice index
  final int lastIndex;

  /// Detected pattern type
  final PatternType patternType;

  /// Labels for choices (for placeholder replacement)
  final List<String> labels;

  const PatternFacts({
    required this.countsByIndex,
    required this.mostChosenIndex,
    required this.mostChosenCount,
    required this.longestStreakIndex,
    required this.longestStreakLen,
    required this.switchCount,
    required this.firstIndex,
    required this.lastIndex,
    required this.patternType,
    required this.labels,
  });

  /// Get label for most chosen
  String get mostChosenLabel =>
      mostChosenIndex < labels.length ? labels[mostChosenIndex] : '?';

  /// Get label for first choice
  String get firstLabel =>
      firstIndex < labels.length ? labels[firstIndex] : '?';

  /// Get label for last choice
  String get lastLabel => lastIndex < labels.length ? labels[lastIndex] : '?';

  /// Get label for longest streak
  String get longestStreakLabel =>
      longestStreakIndex < labels.length ? labels[longestStreakIndex] : '?';
}

/// Outcome facts for GAME mode (performer vs spectator comparison)
class OutcomeFacts {
  /// Number of hits (matches)
  final int hitCount;

  /// Number of misses
  final int missCount;

  /// Total rounds
  final int roundsCount;

  /// Outcome classification
  final OutcomeClass outcomeClass;

  /// Indices of rounds where there was a miss (0-based)
  final List<int> missIndices;

  /// Indices of rounds where there was a hit (0-based)
  final List<int> hitIndices;

  /// Spectator choices for each round
  final List<String> spectatorChoices;

  /// Performer choices for each round
  final List<String> performerChoices;

  const OutcomeFacts({
    required this.hitCount,
    required this.missCount,
    required this.roundsCount,
    required this.outcomeClass,
    this.missIndices = const [],
    this.hitIndices = const [],
    this.spectatorChoices = const [],
    this.performerChoices = const [],
  });

  /// Get miss position description (first, middle, last)
  MissPosition get missPosition {
    if (missIndices.isEmpty) return MissPosition.none;
    if (missIndices.length == roundsCount) return MissPosition.all;

    final firstMiss = missIndices.first;
    final lastMiss = missIndices.last;

    if (missIndices.length == 1) {
      if (firstMiss == 0) return MissPosition.first;
      if (firstMiss == roundsCount - 1) return MissPosition.last;
      return MissPosition.middle;
    }

    // Multiple misses
    if (firstMiss == 0 && lastMiss == roundsCount - 1) {
      return MissPosition.firstAndLast;
    }
    if (firstMiss == 0) return MissPosition.startHeavy;
    if (lastMiss == roundsCount - 1) return MissPosition.endHeavy;
    return MissPosition.scattered;
  }

  /// Compute outcome class from counts
  static OutcomeClass computeClass(int hits, int total) {
    if (total == 0) return OutcomeClass.mixed;

    final ratio = hits / total;

    if (hits == total) return OutcomeClass.allHit;
    if (hits == 0) return OutcomeClass.allMiss;
    if (ratio >= 0.75) return OutcomeClass.mostlyHit;
    if (ratio <= 0.25) return OutcomeClass.mostlyMiss;
    return OutcomeClass.mixed;
  }
}

/// Position of miss(es) in the sequence
enum MissPosition {
  none,        // No misses
  all,         // All rounds are misses
  first,       // Only first round is miss
  middle,      // Single miss in middle
  last,        // Only last round is miss
  firstAndLast, // First and last are misses
  startHeavy,  // Misses concentrated at start
  endHeavy,    // Misses concentrated at end
  scattered,   // Misses scattered throughout
}
