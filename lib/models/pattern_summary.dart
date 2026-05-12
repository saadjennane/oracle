enum MatchPattern {
  perfectRun, // All 3 rounds match
  oneMiss, // 2 matches, 1 mismatch
  multipleMiss, // 0-1 matches
}

enum DuelFlow {
  lead, // Early wins
  comeback, // Late wins
  tieHeavy, // 2+ ties
  balanced, // Mixed
}

class PatternSummary {
  final MatchPattern? matchPattern;
  final DuelFlow? duelFlow;
  final int matchCount;
  final int totalRounds;
  final bool hasStreak;
  final String? dominantChoice;

  const PatternSummary({
    this.matchPattern,
    this.duelFlow,
    required this.matchCount,
    required this.totalRounds,
    this.hasStreak = false,
    this.dominantChoice,
  });

  double get matchPercentage =>
      totalRounds > 0 ? matchCount / totalRounds * 100 : 0;

  bool get isPerfect => matchPattern == MatchPattern.perfectRun;
  bool get hasNoMatches => matchCount == 0;

  Map<String, dynamic> toJson() => {
        'matchPattern': matchPattern?.name,
        'duelFlow': duelFlow?.name,
        'matchCount': matchCount,
        'totalRounds': totalRounds,
        'hasStreak': hasStreak,
        'dominantChoice': dominantChoice,
      };

  factory PatternSummary.fromJson(Map<String, dynamic> json) => PatternSummary(
        matchPattern: json['matchPattern'] != null
            ? MatchPattern.values.firstWhere(
                (e) => e.name == json['matchPattern'],
                orElse: () => MatchPattern.multipleMiss,
              )
            : null,
        duelFlow: json['duelFlow'] != null
            ? DuelFlow.values.firstWhere(
                (e) => e.name == json['duelFlow'],
                orElse: () => DuelFlow.balanced,
              )
            : null,
        matchCount: json['matchCount'] as int,
        totalRounds: json['totalRounds'] as int,
        hasStreak: json['hasStreak'] as bool? ?? false,
        dominantChoice: json['dominantChoice'] as String?,
      );

  @override
  String toString() =>
      'PatternSummary(pattern: $matchPattern, matches: $matchCount/$totalRounds)';
}
