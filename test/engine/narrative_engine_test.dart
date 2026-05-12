import 'package:flutter_test/flutter_test.dart';
import 'package:oracle_poc/models/models.dart';
import 'package:oracle_poc/engine/narrative_engine.dart';

void main() {
  group('NarrativeEngine', () {
    late NarrativeEngine engine;

    setUp(() {
      engine = NarrativeEngine();
    });

    group('Binary Game Narratives', () {
      test('generates narrative (non-empty)', () {
        final session = _createBinarySession(
          preprogrammed: ['Yes', 'No', 'Yes'],
          spectatorChoices: ['Yes', 'No', 'Yes'],
        );

        final narrative = engine.generate(
          session: session,
        );

        expect(narrative, isNotEmpty);
      });
    });

    group('Multi-choice Game Narratives', () {
      test('generates narrative for multi-choice', () {
        final session = _createMultiChoiceSession(
          preprogrammed: ['Red', 'Blue', 'Green'],
          spectatorChoices: ['Red', 'Blue', 'Green'],
        );

        final narrative = engine.generate(
          session: session,
        );

        expect(narrative, isNotEmpty);
      });

      test('handles partial matches in multi-choice', () {
        final session = _createMultiChoiceSession(
          preprogrammed: ['Red', 'Blue', 'Green'],
          spectatorChoices: ['Yellow', 'Purple', 'Orange'],
        );

        final narrative = engine.generate(
          session: session,
        );

        expect(narrative, isNotEmpty);
      });
    });

    group('Duel Game Narratives', () {
      test('generates duel narrative', () {
        final session = _createDuelSession(
          performerChoices: ['Rock', 'Paper', 'Scissors'],
          spectatorChoices: ['Scissors', 'Rock', 'Paper'],
          player1Name: 'Oracle',
          player2Name: 'Alex',
        );

        final narrative = engine.generate(
          session: session,
        );

        expect(narrative, isNotEmpty);
      });

      test('generates duel narrative with first person', () {
        final session = _createDuelSession(
          performerChoices: ['Rock', 'Paper', 'Scissors'],
          spectatorChoices: ['Rock', 'Paper', 'Scissors'],
          player1Name: 'I',
          player2Name: 'You',
          firstPerson: true,
        );

        final narrative = engine.generate(
          session: session,
        );

        expect(narrative, isNotEmpty);
      });
    });

    group('Pattern-based Narrative Variations', () {
      test('generates narrative for perfect run', () {
        final perfectSession = _createBinarySession(
          preprogrammed: ['Yes', 'Yes', 'Yes'],
          spectatorChoices: ['Yes', 'Yes', 'Yes'],
        );

        final narrative = engine.generate(
          session: perfectSession,
        );

        expect(narrative, isNotEmpty);
      });

      test('generates narrative for no matches', () {
        final noMatchSession = _createBinarySession(
          preprogrammed: ['Yes', 'Yes', 'Yes'],
          spectatorChoices: ['No', 'No', 'No'],
        );

        final narrative = engine.generate(
          session: noMatchSession,
        );

        expect(narrative, isNotEmpty);
      });
    });

    group('Edge Cases', () {
      test('handles special characters in choices', () {
        final session = _createBinarySession(
          preprogrammed: ['Yes!', 'No?', 'Maybe'],
          spectatorChoices: ['Yes!', 'No?', 'Maybe'],
        );

        final narrative = engine.generate(
          session: session,
        );

        expect(narrative, isNotEmpty);
      });
    });
  });
}

// Helper functions

GameSession _createBinarySession({
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
    gameType: GameType.binary,
    inputMode: InputMode.preprogrammed,
    options: ['Yes', 'No', 'Maybe'],
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
    options: ['Red', 'Blue', 'Green', 'Yellow', 'Purple', 'Orange'],
    preprogrammedSequence: preprogrammed,
    rounds: rounds,
  );
}

GameSession _createDuelSession({
  required List<String> performerChoices,
  required List<String> spectatorChoices,
  String player1Name = 'Oracle',
  String player2Name = 'Spectator',
  bool firstPerson = false,
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
    player1Name: player1Name,
    player2Name: player2Name,
    firstPerson: firstPerson,
  );
}
