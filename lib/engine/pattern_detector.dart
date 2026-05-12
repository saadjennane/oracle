import '../models/models.dart';
import '../models/pattern_facts.dart';

class PatternDetector {
  final GameSession session;

  PatternDetector(this.session);

  PatternSummary analyze() {
    if (session.isDuel) {
      return _analyzeDuel();
    }
    return _analyzeChoiceMatch();
  }

  /// Compute detailed PatternFacts for CHOICES games
  PatternFacts computePatternFacts() {
    final choices = session.rounds.map((r) => r.spectatorChoice).toList();
    final labels = session.options;

    // Convert choices to indices
    final indices = choices.map((c) => labels.indexOf(c)).toList();

    // Count by index
    final countsByIndex = <int, int>{};
    for (final idx in indices) {
      countsByIndex[idx] = (countsByIndex[idx] ?? 0) + 1;
    }

    // Most chosen
    int mostChosenIndex = 0;
    int mostChosenCount = 0;
    for (final entry in countsByIndex.entries) {
      if (entry.value > mostChosenCount) {
        mostChosenCount = entry.value;
        mostChosenIndex = entry.key;
      }
    }

    // Longest streak
    int longestStreakIndex = indices.isNotEmpty ? indices.first : 0;
    int longestStreakLen = 1;
    int currentStreakIndex = indices.isNotEmpty ? indices.first : 0;
    int currentStreakLen = 1;

    for (int i = 1; i < indices.length; i++) {
      if (indices[i] == indices[i - 1]) {
        currentStreakLen++;
        if (currentStreakLen > longestStreakLen) {
          longestStreakLen = currentStreakLen;
          longestStreakIndex = currentStreakIndex;
        }
      } else {
        currentStreakIndex = indices[i];
        currentStreakLen = 1;
      }
    }

    // Switch count
    int switchCount = 0;
    for (int i = 1; i < indices.length; i++) {
      if (indices[i] != indices[i - 1]) {
        switchCount++;
      }
    }

    // First and last
    final firstIndex = indices.isNotEmpty ? indices.first : 0;
    final lastIndex = indices.isNotEmpty ? indices.last : 0;

    // Determine pattern type
    final patternType = _determinePatternType(
      choices: indices,
      mostChosenCount: mostChosenCount,
      longestStreakLen: longestStreakLen,
      switchCount: switchCount,
      firstIndex: firstIndex,
      lastIndex: lastIndex,
    );

    return PatternFacts(
      countsByIndex: countsByIndex,
      mostChosenIndex: mostChosenIndex,
      mostChosenCount: mostChosenCount,
      longestStreakIndex: longestStreakIndex,
      longestStreakLen: longestStreakLen,
      switchCount: switchCount,
      firstIndex: firstIndex,
      lastIndex: lastIndex,
      patternType: patternType,
      labels: labels,
    );
  }

  /// Compute OutcomeFacts for GAME mode (performer vs spectator)
  OutcomeFacts computeOutcomeFacts() {
    int hitCount = 0;
    int missCount = 0;
    final missIndices = <int>[];
    final hitIndices = <int>[];
    final spectatorChoices = <String>[];
    final performerChoices = <String>[];

    for (int i = 0; i < session.rounds.length; i++) {
      final spectatorChoice = session.rounds[i].spectatorChoice;
      final performerChoice = session.getPerformerChoice(i);

      spectatorChoices.add(spectatorChoice);
      performerChoices.add(performerChoice);

      if (spectatorChoice == performerChoice) {
        hitCount++;
        hitIndices.add(i);
      } else {
        missCount++;
        missIndices.add(i);
      }
    }

    final outcomeClass = OutcomeFacts.computeClass(hitCount, session.rounds.length);

    return OutcomeFacts(
      hitCount: hitCount,
      missCount: missCount,
      roundsCount: session.rounds.length,
      outcomeClass: outcomeClass,
      missIndices: missIndices,
      hitIndices: hitIndices,
      spectatorChoices: spectatorChoices,
      performerChoices: performerChoices,
    );
  }

  PatternType _determinePatternType({
    required List<int> choices,
    required int mostChosenCount,
    required int longestStreakLen,
    required int switchCount,
    required int firstIndex,
    required int lastIndex,
  }) {
    final total = choices.length;
    if (total == 0) return PatternType.mixed;

    // REPEAT_HEAVY: One choice dominates (>= 60% or streak >= 50% of rounds)
    if (mostChosenCount >= total * 0.6 || longestStreakLen >= total * 0.5) {
      return PatternType.repeatHeavy;
    }

    // ALTERNATE_HEAVY: Many switches (switches >= 70% of possible)
    final maxSwitches = total - 1;
    if (maxSwitches > 0 && switchCount >= maxSwitches * 0.7) {
      return PatternType.alternateHeavy;
    }

    // LATE_SWITCH: Pattern holds then breaks at end
    // Check if last choice is different from the dominant pattern in first N-1 choices
    if (total >= 3) {
      final earlyChoices = choices.sublist(0, total - 1);
      final earlyCounts = <int, int>{};
      for (final c in earlyChoices) {
        earlyCounts[c] = (earlyCounts[c] ?? 0) + 1;
      }
      int earlyDominant = earlyChoices.first;
      int earlyMax = 0;
      for (final entry in earlyCounts.entries) {
        if (entry.value > earlyMax) {
          earlyMax = entry.value;
          earlyDominant = entry.key;
        }
      }
      // If early pattern is clear (>= 50%) and last differs
      if (earlyMax >= earlyChoices.length * 0.5 && lastIndex != earlyDominant) {
        return PatternType.lateSwitch;
      }
    }

    return PatternType.mixed;
  }

  PatternSummary _analyzeChoiceMatch() {
    final matches = <bool>[];

    for (int i = 0; i < session.rounds.length; i++) {
      final spectatorChoice = session.rounds[i].spectatorChoice;
      final performerChoice = session.getPerformerChoice(i);
      matches.add(spectatorChoice == performerChoice);
    }

    final matchCount = matches.where((m) => m).length;
    final pattern = _determineMatchPattern(matchCount, session.totalRounds);
    final hasStreak = _detectStreak(session.rounds.map((r) => r.spectatorChoice).toList());
    final dominantChoice = _getDominantChoice(session.rounds.map((r) => r.spectatorChoice).toList());

    return PatternSummary(
      matchPattern: pattern,
      matchCount: matchCount,
      totalRounds: session.rounds.length,
      hasStreak: hasStreak,
      dominantChoice: dominantChoice,
    );
  }

  PatternSummary _analyzeDuel() {
    int performerWins = 0;
    int spectatorWins = 0;
    int ties = 0;

    for (int i = 0; i < session.rounds.length; i++) {
      final spectatorChoice = session.rounds[i].spectatorChoice;
      final performerChoice = session.getPerformerChoice(i);
      final result = _getDuelResult(performerChoice, spectatorChoice);

      if (result > 0) {
        performerWins++;
      } else if (result < 0) {
        spectatorWins++;
      } else {
        ties++;
      }
    }

    final duelFlow = _determineDuelFlow(performerWins, spectatorWins, ties, session.rounds.length);
    final hasStreak = _detectStreak(session.rounds.map((r) => r.spectatorChoice).toList());

    return PatternSummary(
      duelFlow: duelFlow,
      matchCount: performerWins,
      totalRounds: session.rounds.length,
      hasStreak: hasStreak,
    );
  }

  MatchPattern _determineMatchPattern(int matchCount, int totalRounds) {
    // Perfect = all matches
    if (matchCount == totalRounds) return MatchPattern.perfectRun;
    // One miss = all but one match
    if (matchCount == totalRounds - 1) return MatchPattern.oneMiss;
    // Multiple miss = 2+ misses
    return MatchPattern.multipleMiss;
  }

  DuelFlow _determineDuelFlow(int performerWins, int spectatorWins, int ties, int totalRounds) {
    if (ties >= 2) return DuelFlow.tieHeavy;

    // Check for comeback (won more in later rounds)
    if (session.rounds.length >= 3) {
      final earlyWins = _countEarlyWins();
      final lateWins = _countLateWins();

      if (lateWins > earlyWins) return DuelFlow.comeback;
      if (earlyWins > lateWins) return DuelFlow.lead;
    }

    return DuelFlow.balanced;
  }

  int _countEarlyWins() {
    if (session.rounds.isEmpty) return 0;
    final spectatorChoice = session.rounds[0].spectatorChoice;
    final performerChoice = session.getPerformerChoice(0);
    return _getDuelResult(performerChoice, spectatorChoice) > 0 ? 1 : 0;
  }

  int _countLateWins() {
    if (session.rounds.length < 2) return 0;
    // Check last round
    final lastIndex = session.rounds.length - 1;
    final spectatorChoice = session.rounds[lastIndex].spectatorChoice;
    final performerChoice = session.getPerformerChoice(lastIndex);
    return _getDuelResult(performerChoice, spectatorChoice) > 0 ? 1 : 0;
  }

  /// Returns: 1 = performer wins, -1 = spectator wins, 0 = tie
  /// Uses INDEX-BASED RPS rules:
  /// - index 0 beats index 2
  /// - index 2 beats index 1
  /// - index 1 beats index 0
  int _getDuelResult(String performerChoice, String spectatorChoice) {
    if (performerChoice == spectatorChoice) return 0;

    // Get indices of choices in options
    final performerIndex = session.options.indexOf(performerChoice);
    final spectatorIndex = session.options.indexOf(spectatorChoice);

    // If choices not found in options, fallback to label-based comparison
    if (performerIndex == -1 || spectatorIndex == -1) {
      return _getLabelBasedDuelResult(performerChoice, spectatorChoice);
    }

    // Index-based RPS rules:
    // 0 beats 2, 2 beats 1, 1 beats 0
    // This creates: Rock(0) beats Scissors(2), Scissors(2) beats Paper(1), Paper(1) beats Rock(0)
    final winsAgainst = {
      0: 2, // index 0 beats index 2
      2: 1, // index 2 beats index 1
      1: 0, // index 1 beats index 0
    };

    if (winsAgainst[performerIndex] == spectatorIndex) return 1;
    return -1;
  }

  /// Fallback: label-based duel result for backwards compatibility
  int _getLabelBasedDuelResult(String performerChoice, String spectatorChoice) {
    if (performerChoice == spectatorChoice) return 0;

    // Rock beats Scissors, Scissors beats Paper, Paper beats Rock
    final winsAgainst = {
      'Rock': 'Scissors',
      'Scissors': 'Paper',
      'Paper': 'Rock',
    };

    if (winsAgainst[performerChoice] == spectatorChoice) return 1;
    return -1;
  }

  bool _detectStreak(List<String> choices) {
    if (choices.length < 2) return false;
    for (int i = 0; i < choices.length - 1; i++) {
      if (choices[i] == choices[i + 1]) return true;
    }
    return false;
  }

  String? _getDominantChoice(List<String> choices) {
    if (choices.isEmpty) return null;

    final counts = <String, int>{};
    for (final choice in choices) {
      counts[choice] = (counts[choice] ?? 0) + 1;
    }

    final maxCount = counts.values.reduce((a, b) => a > b ? a : b);
    if (maxCount < 2) return null;

    return counts.entries.firstWhere((e) => e.value == maxCount).key;
  }

  /// Calculate duel score from session
  DuelScore calculateDuelScore() {
    int performerWins = 0;
    int spectatorWins = 0;
    int ties = 0;

    for (int i = 0; i < session.rounds.length; i++) {
      final spectatorChoice = session.rounds[i].spectatorChoice;
      final performerChoice = session.getPerformerChoice(i);
      final result = _getDuelResult(performerChoice, spectatorChoice);

      if (result > 0) {
        performerWins++;
      } else if (result < 0) {
        spectatorWins++;
      } else {
        ties++;
      }
    }

    return DuelScore(
      performerScore: performerWins,
      spectatorScore: spectatorWins,
      ties: ties,
    );
  }

  /// Get outcome for each round
  List<RoundOutcome> computeRoundOutcomes() {
    final outcomes = <RoundOutcome>[];

    for (int i = 0; i < session.rounds.length; i++) {
      final spectatorChoice = session.rounds[i].spectatorChoice;
      final performerChoice = session.getPerformerChoice(i);

      if (session.isDuel) {
        final result = _getDuelResult(performerChoice, spectatorChoice);
        if (result > 0) {
          outcomes.add(RoundOutcome.performerWin);
        } else if (result < 0) {
          outcomes.add(RoundOutcome.spectatorWin);
        } else {
          outcomes.add(RoundOutcome.tie);
        }
      } else {
        if (spectatorChoice == performerChoice) {
          outcomes.add(RoundOutcome.exact);
        } else {
          outcomes.add(RoundOutcome.miss);
        }
      }
    }

    return outcomes;
  }
}
