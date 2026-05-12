import 'package:flutter_test/flutter_test.dart';
import 'package:oracle_poc/models/models.dart';
import 'package:oracle_poc/engine/pattern_detector.dart';

void main() {
  group('PatternDetector', () {
    group('Binary Game Pattern Detection', () {
      test('detects perfectRun when all rounds match', () {
        final session = _createBinarySession(
          preprogrammed: ['Yes', 'No', 'Yes'],
          spectatorChoices: ['Yes', 'No', 'Yes'],
        );

        final detector = PatternDetector(session);
        final summary = detector.analyze();

        expect(summary.matchPattern, MatchPattern.perfectRun);
        expect(summary.matchCount, 3);
        expect(summary.totalRounds, 3);
        expect(summary.isPerfect, true);
      });

      test('detects oneMiss when 2 rounds match', () {
        final session = _createBinarySession(
          preprogrammed: ['Yes', 'No', 'Yes'],
          spectatorChoices: ['Yes', 'Yes', 'Yes'], // 2nd round mismatch
        );

        final detector = PatternDetector(session);
        final summary = detector.analyze();

        expect(summary.matchPattern, MatchPattern.oneMiss);
        expect(summary.matchCount, 2);
      });

      test('detects multipleMiss when 0-1 rounds match', () {
        final session = _createBinarySession(
          preprogrammed: ['Yes', 'No', 'Yes'],
          spectatorChoices: ['No', 'Yes', 'No'], // All mismatches
        );

        final detector = PatternDetector(session);
        final summary = detector.analyze();

        expect(summary.matchPattern, MatchPattern.multipleMiss);
        expect(summary.matchCount, 0);
        expect(summary.hasNoMatches, true);
      });

      test('detects dominant choice', () {
        final session = _createBinarySession(
          preprogrammed: ['Yes', 'Yes', 'Yes'],
          spectatorChoices: ['Yes', 'Yes', 'Yes'],
        );

        final detector = PatternDetector(session);
        final summary = detector.analyze();

        expect(summary.dominantChoice, 'Yes');
      });
    });

    group('Multi-choice Game Pattern Detection', () {
      test('detects perfectRun for multi-choice', () {
        final session = _createMultiChoiceSession(
          preprogrammed: ['Red', 'Blue', 'Green'],
          spectatorChoices: ['Red', 'Blue', 'Green'],
        );

        final detector = PatternDetector(session);
        final summary = detector.analyze();

        expect(summary.matchPattern, MatchPattern.perfectRun);
        expect(summary.matchCount, 3);
      });

      test('handles partial matches in multi-choice', () {
        final session = _createMultiChoiceSession(
          preprogrammed: ['Red', 'Blue', 'Green'],
          spectatorChoices: ['Red', 'Yellow', 'Purple'],
        );

        final detector = PatternDetector(session);
        final summary = detector.analyze();

        expect(summary.matchPattern, MatchPattern.multipleMiss);
        expect(summary.matchCount, 1);
      });
    });

    group('Duel Game Pattern Detection', () {
      test('detects tieHeavy flow (2+ ties)', () {
        final session = _createDuelSession(
          performerChoices: ['Rock', 'Paper', 'Scissors'],
          spectatorChoices: ['Rock', 'Paper', 'Scissors'], // All ties
        );

        final detector = PatternDetector(session);
        final summary = detector.analyze();

        expect(summary.duelFlow, DuelFlow.tieHeavy);
      });

      test('calculates correct duel scores', () {
        // Rock beats Scissors
        final session = _createDuelSession(
          performerChoices: ['Rock', 'Paper', 'Scissors'],
          spectatorChoices: ['Scissors', 'Rock', 'Paper'], // P wins all 3
        );

        final detector = PatternDetector(session);
        final duelScore = detector.calculateDuelScore();

        expect(duelScore.performerScore, 3);
        expect(duelScore.spectatorScore, 0);
        expect(duelScore.ties, 0);
      });
    });

    group('Edge Cases', () {
      test('handles empty rounds gracefully', () {
        final session = GameSession(
          gameType: GameType.binary,
          inputMode: InputMode.preprogrammed,
          options: ['Yes', 'No'],
          preprogrammedSequence: [],
          rounds: [],
        );

        final detector = PatternDetector(session);
        final summary = detector.analyze();

        expect(summary.matchCount, 0);
        expect(summary.totalRounds, 0);
      });

      test('handles single round', () {
        final session = _createBinarySession(
          preprogrammed: ['Yes'],
          spectatorChoices: ['Yes'],
          roundCount: 1,
        );

        final detector = PatternDetector(session);
        final summary = detector.analyze();

        expect(summary.matchCount, 1);
        expect(summary.totalRounds, 1);
      });
    });
  });
}

// Helper functions to create test sessions

GameSession _createBinarySession({
  required List<String> preprogrammed,
  required List<String> spectatorChoices,
  int roundCount = 3,
}) {
  final rounds = <RoundInput>[];
  final count = spectatorChoices.length < roundCount ? spectatorChoices.length : roundCount;

  for (int i = 0; i < count; i++) {
    rounds.add(RoundInput(
      roundNumber: i + 1,
      spectatorChoice: spectatorChoices[i],
      performerChoice: preprogrammed.length > i ? preprogrammed[i] : null,
    ));
  }

  return GameSession(
    gameType: GameType.binary,
    inputMode: InputMode.preprogrammed,
    options: ['Yes', 'No'],
    preprogrammedSequence: preprogrammed,
    rounds: rounds,
  );
}

GameSession _createMultiChoiceSession({
  required List<String> preprogrammed,
  required List<String> spectatorChoices,
}) {
  final rounds = <RoundInput>[];
  for (int i = 0; i < spectatorChoices.length; i++) {
    rounds.add(RoundInput(
      roundNumber: i + 1,
      spectatorChoice: spectatorChoices[i],
      performerChoice: preprogrammed.length > i ? preprogrammed[i] : null,
    ));
  }

  return GameSession(
    gameType: GameType.multiChoice,
    inputMode: InputMode.preprogrammed,
    options: ['Red', 'Blue', 'Green', 'Yellow'],
    preprogrammedSequence: preprogrammed,
    rounds: rounds,
  );
}

GameSession _createDuelSession({
  required List<String> performerChoices,
  required List<String> spectatorChoices,
}) {
  final rounds = <RoundInput>[];
  for (int i = 0; i < spectatorChoices.length; i++) {
    rounds.add(RoundInput(
      roundNumber: i + 1,
      spectatorChoice: spectatorChoices[i],
      performerChoice: performerChoices.length > i ? performerChoices[i] : null,
    ));
  }

  return GameSession(
    gameType: GameType.duel,
    inputMode: InputMode.twoInputs,
    options: ['Rock', 'Paper', 'Scissors'],
    rounds: rounds,
    player1Name: 'Oracle',
    player2Name: 'Spectator',
  );
}
