import 'pattern_summary.dart';

enum RoundOutcome {
  exact, // Match
  miss, // Mismatch
  tie, // Duel tie
  performerWin, // Duel: performer wins
  spectatorWin, // Duel: spectator wins
}

class DuelScore {
  final int performerScore;
  final int spectatorScore;
  final int ties;

  const DuelScore({
    required this.performerScore,
    required this.spectatorScore,
    required this.ties,
  });

  int get totalRounds => performerScore + spectatorScore + ties;

  String get winner {
    if (performerScore > spectatorScore) return 'performer';
    if (spectatorScore > performerScore) return 'spectator';
    return 'tie';
  }

  bool get isPerformerWinner => performerScore > spectatorScore;
  bool get isSpectatorWinner => spectatorScore > performerScore;
  bool get isTie => performerScore == spectatorScore;

  String get scoreDisplay => '$performerScore - $spectatorScore';

  Map<String, dynamic> toJson() => {
        'performerScore': performerScore,
        'spectatorScore': spectatorScore,
        'ties': ties,
      };

  factory DuelScore.fromJson(Map<String, dynamic> json) => DuelScore(
        performerScore: json['performerScore'] as int,
        spectatorScore: json['spectatorScore'] as int,
        ties: json['ties'] as int,
      );

  factory DuelScore.empty() => const DuelScore(
        performerScore: 0,
        spectatorScore: 0,
        ties: 0,
      );
}

class ComputedResult {
  final List<RoundOutcome> perRoundOutcome;
  final DuelScore? duelScore;
  final PatternSummary patternSummary;
  final String? generatedText;

  const ComputedResult({
    required this.perRoundOutcome,
    this.duelScore,
    required this.patternSummary,
    this.generatedText,
  });

  bool get hasDuelScore => duelScore != null;

  int get matchCount =>
      perRoundOutcome.where((o) => o == RoundOutcome.exact).length;

  Map<String, dynamic> toJson() => {
        'perRoundOutcome': perRoundOutcome.map((e) => e.name).toList(),
        'duelScore': duelScore?.toJson(),
        'patternSummary': patternSummary.toJson(),
        'generatedText': generatedText,
      };

  factory ComputedResult.fromJson(Map<String, dynamic> json) {
    // Migration: old format had generatedTextByStyle as Map<String, String>
    String? text = json['generatedText'] as String?;
    if (text == null && json['generatedTextByStyle'] is Map) {
      final oldMap = json['generatedTextByStyle'] as Map<String, dynamic>;
      if (oldMap.isNotEmpty) {
        text = oldMap.values.first as String;
      }
    }

    return ComputedResult(
      perRoundOutcome: (json['perRoundOutcome'] as List)
          .map((e) => RoundOutcome.values.firstWhere(
                (o) => o.name == e,
                orElse: () => RoundOutcome.miss,
              ))
          .toList(),
      duelScore: json['duelScore'] != null
          ? DuelScore.fromJson(json['duelScore'] as Map<String, dynamic>)
          : null,
      patternSummary: PatternSummary.fromJson(
          json['patternSummary'] as Map<String, dynamic>),
      generatedText: text,
    );
  }

  ComputedResult copyWith({
    List<RoundOutcome>? perRoundOutcome,
    DuelScore? duelScore,
    PatternSummary? patternSummary,
    String? generatedText,
  }) {
    return ComputedResult(
      perRoundOutcome: perRoundOutcome ?? this.perRoundOutcome,
      duelScore: duelScore ?? this.duelScore,
      patternSummary: patternSummary ?? this.patternSummary,
      generatedText: generatedText ?? this.generatedText,
    );
  }
}
