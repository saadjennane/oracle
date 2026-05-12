import 'package:flutter_test/flutter_test.dart';
import 'package:oracle_poc/engine/banks/choices_starter_fr_minimal_exact_ddg.dart';
import 'package:oracle_poc/models/models.dart';

void main() {
  // Options binaires: Droite = D, Gauche = G
  final options = ['Droite', 'Gauche'];

  group('canUseChoicesStarterDDG', () {
    test('returns true for valid FR 1 round DDG conditions', () {
      expect(
        canUseChoicesStarterDDG(
          languageCode: 'french',
          rounds: 1,
          isPreprogrammed: true,
          performerSequence: ['Droite'], // D
          options: options,
        ),
        isTrue,
      );
    });

    test('returns true for valid FR 2 rounds DDG conditions', () {
      expect(
        canUseChoicesStarterDDG(
          languageCode: 'french',
          rounds: 2,
          isPreprogrammed: true,
          performerSequence: ['Droite', 'Droite'], // DD
          options: options,
        ),
        isTrue,
      );
    });

    test('returns true for valid FR 3 rounds DDG conditions', () {
      expect(
        canUseChoicesStarterDDG(
          languageCode: 'french',
          rounds: 3,
          isPreprogrammed: true,
          performerSequence: ['Droite', 'Droite', 'Gauche'], // DDG
          options: options,
        ),
        isTrue,
      );
    });

    test('returns false for English language', () {
      expect(
        canUseChoicesStarterDDG(
          languageCode: 'english',
          rounds: 3,
          isPreprogrammed: true,
          performerSequence: ['Droite', 'Droite', 'Gauche'],
          options: options,
        ),
        isFalse,
      );
    });

    test('returns false for 4 rounds', () {
      expect(
        canUseChoicesStarterDDG(
          languageCode: 'french',
          rounds: 4,
          isPreprogrammed: true,
          performerSequence: ['Droite', 'Droite', 'Gauche', 'Droite'],
          options: options,
        ),
        isFalse,
      );
    });

    test('returns false for non-preprogrammed mode', () {
      expect(
        canUseChoicesStarterDDG(
          languageCode: 'french',
          rounds: 3,
          isPreprogrammed: false,
          performerSequence: ['Droite', 'Droite', 'Gauche'],
          options: options,
        ),
        isFalse,
      );
    });

    test('returns false for wrong performer sequence (GDD instead of DDG)', () {
      expect(
        canUseChoicesStarterDDG(
          languageCode: 'french',
          rounds: 3,
          isPreprogrammed: true,
          performerSequence: ['Gauche', 'Droite', 'Droite'], // GDD not DDG
          options: options,
        ),
        isFalse,
      );
    });

    test('returns false for 3 options (not binary)', () {
      expect(
        canUseChoicesStarterDDG(
          languageCode: 'french',
          rounds: 3,
          isPreprogrammed: true,
          performerSequence: ['Droite', 'Droite', 'Gauche'],
          options: ['Option A', 'Option B', 'Option C'],
        ),
        isFalse,
      );
    });
  });

  group('getChoicesStarterDDGText - Round 1', () {
    test('returns text for spectator D', () {
      final text = getChoicesStarterDDGText(['Droite'], options);
      expect(text, isNotNull);
      expect(text, contains('Tu vas faire droite.'));
      expect(text, contains('Et si c\'était ça le vrai truc'));
    });

    test('returns text for spectator G', () {
      final text = getChoicesStarterDDGText(['Gauche'], options);
      expect(text, isNotNull);
      expect(text, contains('Tu vas faire gauche.'));
      expect(text, contains('me tromper exprès'));
    });
  });

  group('getChoicesStarterDDGText - Round 2', () {
    test('returns text for spectator DD', () {
      final text = getChoicesStarterDDGText(['Droite', 'Droite'], options);
      expect(text, isNotNull);
      expect(text, contains('Tu vas faire droite, droite.'));
      expect(text, contains('deviner deux fois'));
    });

    test('returns text for spectator DG', () {
      final text = getChoicesStarterDDGText(['Droite', 'Gauche'], options);
      expect(text, isNotNull);
      expect(text, contains('Tu vas faire droite, gauche.'));
    });

    test('returns text for spectator GD', () {
      final text = getChoicesStarterDDGText(['Gauche', 'Droite'], options);
      expect(text, isNotNull);
      expect(text, contains('Tu vas faire gauche, droite.'));
    });

    test('returns text for spectator GG', () {
      final text = getChoicesStarterDDGText(['Gauche', 'Gauche'], options);
      expect(text, isNotNull);
      expect(text, contains('Tu vas faire gauche, gauche.'));
    });
  });

  group('getChoicesStarterDDGText - Round 3', () {
    test('returns text for spectator DDD', () {
      final text = getChoicesStarterDDGText(['Droite', 'Droite', 'Droite'], options);
      expect(text, isNotNull);
      expect(text, contains('Tu vas faire droite, droite, droite.'));
    });

    test('returns text for spectator DDG (perfect match)', () {
      final text = getChoicesStarterDDGText(['Droite', 'Droite', 'Gauche'], options);
      expect(text, isNotNull);
      expect(text, contains('Tu vas faire droite, droite, gauche.'));
      expect(text, contains('deviner les trois fois'));
    });

    test('returns text for spectator DGD', () {
      final text = getChoicesStarterDDGText(['Droite', 'Gauche', 'Droite'], options);
      expect(text, isNotNull);
      expect(text, contains('Tu vas faire droite, gauche, droite.'));
    });

    test('returns text for spectator DGG', () {
      final text = getChoicesStarterDDGText(['Droite', 'Gauche', 'Gauche'], options);
      expect(text, isNotNull);
      expect(text, contains('Tu vas faire droite, gauche, gauche.'));
    });

    test('returns text for spectator GDD', () {
      final text = getChoicesStarterDDGText(['Gauche', 'Droite', 'Droite'], options);
      expect(text, isNotNull);
      expect(text, contains('Tu vas faire gauche, droite, droite.'));
    });

    test('returns text for spectator GDG', () {
      final text = getChoicesStarterDDGText(['Gauche', 'Droite', 'Gauche'], options);
      expect(text, isNotNull);
      expect(text, contains('Tu vas faire gauche, droite, gauche.'));
    });

    test('returns text for spectator GGD', () {
      final text = getChoicesStarterDDGText(['Gauche', 'Gauche', 'Droite'], options);
      expect(text, isNotNull);
      expect(text, contains('Tu vas faire gauche, gauche, droite.'));
    });

    test('returns text for spectator GGG', () {
      final text = getChoicesStarterDDGText(['Gauche', 'Gauche', 'Gauche'], options);
      expect(text, isNotNull);
      expect(text, contains('Tu vas faire gauche, gauche, gauche.'));
    });
  });

  group('Bank completeness', () {
    test('all 2 entries exist for round 1', () {
      expect(choicesStarterFrMinimalExactDDG['D'], isNotNull);
      expect(choicesStarterFrMinimalExactDDG['G'], isNotNull);
    });

    test('all 4 entries exist for round 2', () {
      expect(choicesStarterFrMinimalExactDDG['DD'], isNotNull);
      expect(choicesStarterFrMinimalExactDDG['DG'], isNotNull);
      expect(choicesStarterFrMinimalExactDDG['GD'], isNotNull);
      expect(choicesStarterFrMinimalExactDDG['GG'], isNotNull);
    });

    test('all 8 entries exist for round 3', () {
      expect(choicesStarterFrMinimalExactDDG['DDD'], isNotNull);
      expect(choicesStarterFrMinimalExactDDG['DDG'], isNotNull);
      expect(choicesStarterFrMinimalExactDDG['DGD'], isNotNull);
      expect(choicesStarterFrMinimalExactDDG['DGG'], isNotNull);
      expect(choicesStarterFrMinimalExactDDG['GDD'], isNotNull);
      expect(choicesStarterFrMinimalExactDDG['GDG'], isNotNull);
      expect(choicesStarterFrMinimalExactDDG['GGD'], isNotNull);
      expect(choicesStarterFrMinimalExactDDG['GGG'], isNotNull);
    });

    test('total entries = 14 (2 + 4 + 8)', () {
      expect(choicesStarterFrMinimalExactDDG.length, equals(14));
    });
  });
}
