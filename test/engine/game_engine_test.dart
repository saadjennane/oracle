import 'package:flutter_test/flutter_test.dart';
import 'package:oracle_poc/models/models.dart';
import 'package:oracle_poc/engine/game_engine.dart';

void main() {
  group('GameEngine', () {
    late GameEngine engine;

    setUp(() {
      engine = GameEngine();
    });

    group('startNewGame', () {
      test('initializes binary game correctly', () {
        engine.startNewGame(
          gameType: GameType.binary,
          inputMode: InputMode.preprogrammed,
          options: ['Yes', 'No'],
          preprogrammedSequence: ['Yes', 'No', 'Yes'],
        );

        expect(engine.currentSession, isNotNull);
        expect(engine.currentSession!.gameType, GameType.binary);
        expect(engine.currentSession!.inputMode, InputMode.preprogrammed);
        expect(engine.currentSession!.options, ['Yes', 'No']);
        expect(engine.currentSession!.preprogrammedSequence, ['Yes', 'No', 'Yes']);
        expect(engine.currentSession!.rounds, isEmpty);
      });

      test('initializes duel game with player names', () {
        engine.startNewGame(
          gameType: GameType.duel,
          inputMode: InputMode.twoInputs,
          options: ['Rock', 'Paper', 'Scissors'],
          player1Name: 'Magician',
          player2Name: 'Volunteer',
        );

        expect(engine.currentSession!.gameType, GameType.duel);
        expect(engine.currentSession!.player1Name, 'Magician');
        expect(engine.currentSession!.player2Name, 'Volunteer');
      });

      test('initializes multi-choice game with 4 options', () {
        engine.startNewGame(
          gameType: GameType.multiChoice,
          inputMode: InputMode.preprogrammed,
          options: ['Red', 'Blue', 'Green', 'Yellow'],
          preprogrammedSequence: ['Red', 'Blue', 'Green'],
        );

        expect(engine.currentSession!.gameType, GameType.multiChoice);
        expect(engine.currentSession!.options.length, 4);
      });
    });

    group('recordRound', () {
      test('records spectator choice in preprogrammed mode', () {
        engine.startNewGame(
          gameType: GameType.binary,
          inputMode: InputMode.preprogrammed,
          options: ['Yes', 'No'],
          preprogrammedSequence: ['Yes', 'No', 'Yes'],
        );

        engine.recordRound(spectatorChoice: 'Yes');

        expect(engine.currentSession!.rounds.length, 1);
        expect(engine.currentSession!.rounds[0].spectatorChoice, 'Yes');
        expect(engine.currentSession!.rounds[0].roundNumber, 1);
      });

      test('records both choices in two-input mode', () {
        engine.startNewGame(
          gameType: GameType.duel,
          inputMode: InputMode.twoInputs,
          options: ['Rock', 'Paper', 'Scissors'],
        );

        engine.recordRound(spectatorChoice: 'Rock', performerChoice: 'Paper');

        expect(engine.currentSession!.rounds.length, 1);
        expect(engine.currentSession!.rounds[0].spectatorChoice, 'Rock');
        expect(engine.currentSession!.rounds[0].performerChoice, 'Paper');
      });

      test('increments round number correctly', () {
        engine.startNewGame(
          gameType: GameType.duel,
          inputMode: InputMode.twoInputs,
          options: ['Rock', 'Paper', 'Scissors'],
        );

        engine.recordRound(spectatorChoice: 'Rock', performerChoice: 'Rock');
        engine.recordRound(spectatorChoice: 'Paper', performerChoice: 'Paper');
        engine.recordRound(spectatorChoice: 'Scissors', performerChoice: 'Scissors');

        expect(engine.currentSession!.rounds[0].roundNumber, 1);
        expect(engine.currentSession!.rounds[1].roundNumber, 2);
        expect(engine.currentSession!.rounds[2].roundNumber, 3);
      });
    });

    group('computeResults', () {
      test('computes binary match outcomes', () {
        engine.startNewGame(
          gameType: GameType.binary,
          inputMode: InputMode.preprogrammed,
          options: ['Yes', 'No'],
          preprogrammedSequence: ['Yes', 'No', 'Yes'],
        );

        engine.recordRound(spectatorChoice: 'Yes'); // Match
        engine.recordRound(spectatorChoice: 'Yes'); // Mismatch (expected No)
        engine.recordRound(spectatorChoice: 'Yes'); // Match

        final result = engine.computeResults();

        expect(result.perRoundOutcome[0], RoundOutcome.exact);
        expect(result.perRoundOutcome[1], RoundOutcome.miss);
        expect(result.perRoundOutcome[2], RoundOutcome.exact);
      });

      test('computes duel scores correctly', () {
        engine.startNewGame(
          gameType: GameType.duel,
          inputMode: InputMode.twoInputs,
          options: ['Rock', 'Paper', 'Scissors'],
        );

        // Rock beats Scissors
        engine.recordRound(spectatorChoice: 'Scissors', performerChoice: 'Rock');
        // Paper beats Rock
        engine.recordRound(spectatorChoice: 'Rock', performerChoice: 'Paper');
        // Tie
        engine.recordRound(spectatorChoice: 'Rock', performerChoice: 'Rock');

        final result = engine.computeResults();
        final duelScore = result.duelScore!;

        expect(duelScore.performerScore, 2);
        expect(duelScore.spectatorScore, 0);
        expect(duelScore.ties, 1);
      });
    });

    group('reset', () {
      test('clears current session', () {
        engine.startNewGame(
          gameType: GameType.binary,
          inputMode: InputMode.preprogrammed,
          options: ['Yes', 'No'],
          preprogrammedSequence: ['Yes', 'No', 'Yes'],
        );

        engine.reset();

        expect(engine.currentSession, isNull);
      });
    });

    group('currentRound', () {
      test('returns correct current round number', () {
        engine.startNewGame(
          gameType: GameType.duel,
          inputMode: InputMode.twoInputs,
          options: ['Rock', 'Paper', 'Scissors'],
        );

        expect(engine.currentRound, 1);

        engine.recordRound(spectatorChoice: 'Rock', performerChoice: 'Rock');
        expect(engine.currentRound, 2);

        engine.recordRound(spectatorChoice: 'Paper', performerChoice: 'Paper');
        expect(engine.currentRound, 3);
      });
    });

    group('hasAllRounds', () {
      test('returns true after 3 rounds', () {
        engine.startNewGame(
          gameType: GameType.duel,
          inputMode: InputMode.twoInputs,
          options: ['Rock', 'Paper', 'Scissors'],
        );

        expect(engine.hasAllRounds, false);

        engine.recordRound(spectatorChoice: 'Rock', performerChoice: 'Rock');
        expect(engine.hasAllRounds, false);

        engine.recordRound(spectatorChoice: 'Paper', performerChoice: 'Paper');
        expect(engine.hasAllRounds, false);

        engine.recordRound(spectatorChoice: 'Scissors', performerChoice: 'Scissors');
        expect(engine.hasAllRounds, true);
      });
    });

    group('Edge cases', () {
      test('throws when recording round without session', () {
        expect(
          () => engine.recordRound(spectatorChoice: 'Yes'),
          throwsA(isA<StateError>()),
        );
      });

      test('throws when computing results without session', () {
        expect(
          () => engine.computeResults(),
          throwsA(isA<StateError>()),
        );
      });
    });
  });
}
