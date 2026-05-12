// Basic smoke test for Oracle POC app
// Full widget tests require mock providers setup

import 'package:flutter_test/flutter_test.dart';
import 'package:oracle_poc/models/models.dart';

void main() {
  group('Model Tests', () {
    test('GameType has correct option counts', () {
      expect(GameType.binary.optionCount, 2);
      expect(GameType.multiChoice.optionCount, 4);
      expect(GameType.duel.optionCount, 3);
    });

    test('GameSession can be created', () {
      final session = GameSession(
        gameType: GameType.binary,
        inputMode: InputMode.preprogrammed,
        options: ['Yes', 'No'],
        preprogrammedSequence: ['Yes', 'No', 'Yes'],
      );

      expect(session.gameType, GameType.binary);
      expect(session.options.length, 2);
    });

    test('RoundInput stores choices correctly', () {
      final round = RoundInput(
        roundNumber: 1,
        spectatorChoice: 'Yes',
        performerChoice: 'No',
      );

      expect(round.roundNumber, 1);
      expect(round.spectatorChoice, 'Yes');
      expect(round.performerChoice, 'No');
    });

    test('PatternSummary calculates percentage', () {
      const summary = PatternSummary(
        matchCount: 2,
        totalRounds: 3,
      );

      expect(summary.matchPercentage, closeTo(66.67, 0.01));
    });
  });
}
