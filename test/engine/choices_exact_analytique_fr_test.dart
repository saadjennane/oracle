import 'package:flutter_test/flutter_test.dart';
import 'package:oracle_poc/engine/starter_packs/choices_exact_analytique_fr.dart';

void main() {
  group('generateChoicesExactAnalytiqueFR', () {
    group('Round 1', () {
      test('generates 2 entries for round 1', () {
        final bank = generateChoicesExactAnalytiqueFR(
          label1: 'Gauche',
          label2: 'Droite',
          performerSeq: [1], // Gauche
        );

        expect(bank.length, equals(2));
        expect(bank.containsKey('1'), isTrue);
        expect(bank.containsKey('2'), isTrue);
      });

      test('all texts have 4 lines', () {
        final bank = generateChoicesExactAnalytiqueFR(
          label1: 'Gauche',
          label2: 'Droite',
          performerSeq: [1],
        );

        for (final text in bank.values) {
          final lines = text.split('\n');
          expect(lines.length, equals(4), reason: 'Text: $text');
        }
      });

      test('perfect match (1 hit) text', () {
        final bank = generateChoicesExactAnalytiqueFR(
          label1: 'Gauche',
          label2: 'Droite',
          performerSeq: [1], // Gauche
        );

        final text = bank['1']!;
        expect(text, contains('Tu vas faire Gauche.'));
        expect(text, contains('laisser passer tous les signaux'));
        expect(text, contains('trop propre'));
      });

      test('all miss (0 hits) text', () {
        final bank = generateChoicesExactAnalytiqueFR(
          label1: 'Gauche',
          label2: 'Droite',
          performerSeq: [1], // Gauche
        );

        final text = bank['2']!;
        expect(text, contains('Tu vas faire Droite.'));
        expect(text, contains('imprévisible sur toute la ligne'));
        // With 1 miss at position 0 which is also last position (rounds=1)
        // Logic checks "last" first, so uses "Le dernier"
        expect(text, contains('Le dernier, je vais le rater'));
      });
    });

    group('Round 3', () {
      test('generates 8 entries for round 3', () {
        final bank = generateChoicesExactAnalytiqueFR(
          label1: 'Gauche',
          label2: 'Droite',
          performerSeq: [1, 1, 2], // G, G, D
        );

        expect(bank.length, equals(8));
      });

      test('perfect match (3 hits) text', () {
        final bank = generateChoicesExactAnalytiqueFR(
          label1: 'Gauche',
          label2: 'Droite',
          performerSeq: [1, 1, 2], // G, G, D
        );

        final text = bank['112']!;
        expect(text, contains('Tu vas faire Gauche, Gauche, Droite.'));
        expect(text, contains('laisser passer tous les signaux'));
        expect(text, contains('trop propre'));
      });

      test('all miss (0 hits) text', () {
        final bank = generateChoicesExactAnalytiqueFR(
          label1: 'Gauche',
          label2: 'Droite',
          performerSeq: [1, 1, 2], // G, G, D
        );

        // Spectator: D, D, G (221) = all miss
        final text = bank['221']!;
        expect(text, contains('Tu vas faire Droite, Droite, Gauche.'));
        expect(text, contains('imprévisible sur toute la ligne'));
        expect(text, contains('laisser passer trois fois'));
      });

      test('streak of 2 hits from start', () {
        final bank = generateChoicesExactAnalytiqueFR(
          label1: 'Gauche',
          label2: 'Droite',
          performerSeq: [1, 1, 2], // G, G, D
        );

        // Spectator: G, G, G (111) = 2 hits at start, 1 miss at end
        final text = bank['111']!;
        expect(text, contains('Tu vas faire Gauche, Gauche, Gauche.'));
        expect(text, contains('Les deux premiers choix'));
        expect(text, contains('Le dernier, je vais le rater'));
      });

      test('streak of 1 hit from start', () {
        final bank = generateChoicesExactAnalytiqueFR(
          label1: 'Gauche',
          label2: 'Droite',
          performerSeq: [1, 1, 2], // G, G, D
        );

        // Spectator: G, D, G (121) = 1 hit at start, miss, miss
        final text = bank['121']!;
        expect(text, contains('Tu vas faire Gauche, Droite, Gauche.'));
        expect(text, contains('Le premier choix'));
        expect(text, contains('laisser passer deux fois'));
      });

      test('no streak from start (first is miss)', () {
        final bank = generateChoicesExactAnalytiqueFR(
          label1: 'Gauche',
          label2: 'Droite',
          performerSeq: [1, 1, 2], // G, G, D
        );

        // Spectator: D, G, D (212) = miss, hit, hit (2 hits but no streak from start)
        final text = bank['212']!;
        expect(text, contains('Tu vas faire Droite, Gauche, Droite.'));
        expect(text, contains('Au début, tu vas casser le rythme'));
        // Miss at first position
        expect(text, contains('Le premier, je vais le rater'));
      });
    });

    group('Round 5', () {
      test('generates 32 entries for round 5', () {
        final bank = generateChoicesExactAnalytiqueFR(
          label1: 'A',
          label2: 'B',
          performerSeq: [1, 2, 1, 2, 1], // A, B, A, B, A
        );

        expect(bank.length, equals(32));
      });

      test('all texts have 4 lines', () {
        final bank = generateChoicesExactAnalytiqueFR(
          label1: 'A',
          label2: 'B',
          performerSeq: [1, 2, 1, 2, 1],
        );

        for (final text in bank.values) {
          final lines = text.split('\n');
          expect(lines.length, equals(4), reason: 'Text: $text');
        }
      });

      test('perfect match text', () {
        final bank = generateChoicesExactAnalytiqueFR(
          label1: 'A',
          label2: 'B',
          performerSeq: [1, 2, 1, 2, 1],
        );

        final text = bank['12121']!;
        expect(text, contains('Tu vas faire A, B, A, B, A.'));
        expect(text, contains('laisser passer tous les signaux'));
        expect(text, contains('trop propre'));
      });

      test('all miss text', () {
        final bank = generateChoicesExactAnalytiqueFR(
          label1: 'A',
          label2: 'B',
          performerSeq: [1, 2, 1, 2, 1],
        );

        final text = bank['21212']!;
        expect(text, contains('Tu vas faire B, A, B, A, B.'));
        expect(text, contains('imprévisible sur toute la ligne'));
        expect(text, contains('laisser passer cinq fois'));
      });
    });

    group('Line 4 deterministic endings', () {
      test('uses 3 different endings based on key index', () {
        final bank = generateChoicesExactAnalytiqueFR(
          label1: 'A',
          label2: 'B',
          performerSeq: [1, 1], // A, A
        );

        // Check that we have deterministic endings
        // Key 0 (11) should have ending 0
        // Key 1 (12) should have ending 1
        // Key 2 (21) should have ending 2
        // Key 3 (22) should have ending 0 again

        expect(bank['11'], contains('Tu vas décider, ou tu vas juste croire décider.'));
        expect(bank['12'], contains('Tu vas choisir, mais le plus important'));
        expect(bank['21'], contains('Tu vas penser que c\'est toi'));
        expect(bank['22'], contains('Tu vas décider, ou tu vas juste croire décider.'));
      });
    });

    group('Edge cases', () {
      test('assert fails for 0 rounds', () {
        expect(
          () => generateChoicesExactAnalytiqueFR(
            label1: 'A',
            label2: 'B',
            performerSeq: [],
          ),
          throwsA(isA<AssertionError>()),
        );
      });

      test('assert fails for 6+ rounds', () {
        expect(
          () => generateChoicesExactAnalytiqueFR(
            label1: 'A',
            label2: 'B',
            performerSeq: [1, 2, 1, 2, 1, 2],
          ),
          throwsA(isA<AssertionError>()),
        );
      });

      test('assert fails for invalid performer values', () {
        expect(
          () => generateChoicesExactAnalytiqueFR(
            label1: 'A',
            label2: 'B',
            performerSeq: [1, 3, 1], // 3 is invalid
          ),
          throwsA(isA<AssertionError>()),
        );
      });
    });
  });
}
