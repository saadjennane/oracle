import 'package:flutter_test/flutter_test.dart';
import 'package:oracle_poc/engine/starter_packs/choices_exact_taquin_fr.dart';

void main() {
  group('generateChoicesExactTaquinFR', () {
    group('Round 1', () {
      test('generates 2 entries for round 1', () {
        final bank = generateChoicesExactTaquinFR(
          label1: 'Gauche',
          label2: 'Droite',
          performerSeq: [1], // Gauche
        );

        expect(bank.length, equals(2));
        expect(bank.containsKey('1'), isTrue);
        expect(bank.containsKey('2'), isTrue);
      });

      test('perfect match (all hits) text for round 1', () {
        final bank = generateChoicesExactTaquinFR(
          label1: 'Gauche',
          label2: 'Droite',
          performerSeq: [1], // Gauche
        );

        // Spectator chooses Gauche (1) = perfect match
        final text = bank['1']!;
        expect(text, contains('Tu vas faire Gauche.'));
        expect(text, contains('Je vais deviner tout.'));
        // No miss line for perfect match
        expect(text, isNot(contains('rater')));
        expect(text, isNot(contains('tromper')));
        expect(text, contains('J\'espère que ça t\'a fait plaisir.'));
      });

      test('all miss (0 hits) text for round 1', () {
        final bank = generateChoicesExactTaquinFR(
          label1: 'Gauche',
          label2: 'Droite',
          performerSeq: [1], // Gauche
        );

        // Spectator chooses Droite (2) = miss
        final text = bank['2']!;
        expect(text, contains('Tu vas faire Droite.'));
        expect(text, contains('Je ne vais rien deviner.'));
        expect(text, contains('me tromper une fois'));
        expect(text, contains('petit plaisir d\'avoir eu un mentaliste'));
        expect(text, contains('J\'espère que ça t\'a fait plaisir.'));
      });
    });

    group('Round 3', () {
      test('generates 8 entries for round 3', () {
        final bank = generateChoicesExactTaquinFR(
          label1: 'Gauche',
          label2: 'Droite',
          performerSeq: [1, 1, 2], // G, G, D
        );

        expect(bank.length, equals(8));
      });

      test('perfect match (3 hits) text', () {
        final bank = generateChoicesExactTaquinFR(
          label1: 'Gauche',
          label2: 'Droite',
          performerSeq: [1, 1, 2], // G, G, D
        );

        // Spectator chooses G, G, D (112) = perfect match
        final text = bank['112']!;
        expect(text, contains('Tu vas faire Gauche, Gauche, Droite.'));
        expect(text, contains('Je vais deviner tout.'));
        expect(text, isNot(contains('rater')));
        expect(text, isNot(contains('tromper')));
        expect(text, contains('J\'espère que ça t\'a fait plaisir.'));
      });

      test('all miss (0 hits) text', () {
        final bank = generateChoicesExactTaquinFR(
          label1: 'Gauche',
          label2: 'Droite',
          performerSeq: [1, 1, 2], // G, G, D
        );

        // Spectator chooses D, D, G (221) = all miss
        final text = bank['221']!;
        expect(text, contains('Tu vas faire Droite, Droite, Gauche.'));
        expect(text, contains('Je ne vais rien deviner.'));
        expect(text, contains('me tromper trois fois'));
        expect(text, contains('petit plaisir d\'avoir eu un mentaliste'));
        expect(text, contains('J\'espère que ça t\'a fait plaisir.'));
      });

      test('one miss (2 hits, 1 miss) uses "la dernière" phrasing', () {
        final bank = generateChoicesExactTaquinFR(
          label1: 'Gauche',
          label2: 'Droite',
          performerSeq: [1, 1, 2], // G, G, D
        );

        // Spectator chooses G, G, G (111) = 2 hits (pos 0,1), 1 miss (pos 2)
        final text = bank['111']!;
        expect(text, contains('Tu vas faire Gauche, Gauche, Gauche.'));
        expect(text, contains('Je vais deviner deux fois.'));
        expect(text, contains('Et la dernière, je vais la rater exprès'));
        expect(text, contains('petit plaisir d\'avoir eu un mentaliste'));
        expect(text, contains('J\'espère que ça t\'a fait plaisir.'));
      });

      test('two misses (1 hit, 2 misses) uses "me tromper" phrasing', () {
        final bank = generateChoicesExactTaquinFR(
          label1: 'Gauche',
          label2: 'Droite',
          performerSeq: [1, 1, 2], // G, G, D
        );

        // Spectator chooses D, G, G (211) = 1 hit (pos 1), 2 misses (pos 0,2)
        final text = bank['211']!;
        expect(text, contains('Tu vas faire Droite, Gauche, Gauche.'));
        expect(text, contains('Je vais deviner une fois.'));
        expect(text, contains('me tromper deux fois'));
        expect(text, contains('petit plaisir d\'avoir eu un mentaliste'));
        expect(text, contains('J\'espère que ça t\'a fait plaisir.'));
      });
    });

    group('Round 5', () {
      test('generates 32 entries for round 5', () {
        final bank = generateChoicesExactTaquinFR(
          label1: 'A',
          label2: 'B',
          performerSeq: [1, 2, 1, 2, 1], // A, B, A, B, A
        );

        expect(bank.length, equals(32));
      });

      test('perfect match (5 hits) text', () {
        final bank = generateChoicesExactTaquinFR(
          label1: 'A',
          label2: 'B',
          performerSeq: [1, 2, 1, 2, 1], // A, B, A, B, A
        );

        // Spectator chooses same sequence (12121) = perfect match
        final text = bank['12121']!;
        expect(text, contains('Tu vas faire A, B, A, B, A.'));
        expect(text, contains('Je vais deviner tout.'));
        expect(text, isNot(contains('rater')));
        expect(text, isNot(contains('tromper')));
        expect(text, contains('J\'espère que ça t\'a fait plaisir.'));
      });

      test('all miss (0 hits) text', () {
        final bank = generateChoicesExactTaquinFR(
          label1: 'A',
          label2: 'B',
          performerSeq: [1, 2, 1, 2, 1], // A, B, A, B, A
        );

        // Spectator chooses opposite (21212) = all miss
        final text = bank['21212']!;
        expect(text, contains('Tu vas faire B, A, B, A, B.'));
        expect(text, contains('Je ne vais rien deviner.'));
        expect(text, contains('me tromper cinq fois'));
        expect(text, contains('petit plaisir d\'avoir eu un mentaliste'));
        expect(text, contains('J\'espère que ça t\'a fait plaisir.'));
      });

      test('one miss uses "la dernière" phrasing', () {
        final bank = generateChoicesExactTaquinFR(
          label1: 'A',
          label2: 'B',
          performerSeq: [1, 2, 1, 2, 1], // A, B, A, B, A
        );

        // Spectator chooses (12122) = 4 hits, 1 miss at pos 4
        final text = bank['12122']!;
        expect(text, contains('Tu vas faire A, B, A, B, B.'));
        expect(text, contains('Je vais deviner quatre fois.'));
        expect(text, contains('Et la dernière, je vais la rater exprès'));
        expect(text, contains('petit plaisir d\'avoir eu un mentaliste'));
        expect(text, contains('J\'espère que ça t\'a fait plaisir.'));
      });

      test('multiple misses uses "me tromper" phrasing', () {
        final bank = generateChoicesExactTaquinFR(
          label1: 'A',
          label2: 'B',
          performerSeq: [1, 2, 1, 2, 1], // A, B, A, B, A
        );

        // Spectator chooses (12111) = 4 hits (pos 0,1,2,4), 1 miss at pos 3
        // Wait, let me recalculate:
        // Performer: 1 2 1 2 1
        // Spectator: 1 2 1 1 1
        // Pos 0: 1 vs 1 = HIT
        // Pos 1: 2 vs 2 = HIT
        // Pos 2: 1 vs 1 = HIT
        // Pos 3: 2 vs 1 = MISS
        // Pos 4: 1 vs 1 = HIT
        // So 4 hits, 1 miss
        // But since misses == 1 and hits == N-1, we use "la dernière" phrasing

        // Let's use a case with 2 misses instead
        // Spectator chooses (12211)
        // Performer: 1 2 1 2 1
        // Spectator: 1 2 2 1 1
        // Pos 0: 1 vs 1 = HIT
        // Pos 1: 2 vs 2 = HIT
        // Pos 2: 1 vs 2 = MISS
        // Pos 3: 2 vs 1 = MISS
        // Pos 4: 1 vs 1 = HIT
        // So 3 hits, 2 misses
        final text2 = bank['12211']!;
        expect(text2, contains('Tu vas faire A, B, B, A, A.'));
        expect(text2, contains('Je vais deviner trois fois.'));
        expect(text2, contains('me tromper deux fois'));
        expect(text2, contains('petit plaisir d\'avoir eu un mentaliste'));
        expect(text2, contains('J\'espère que ça t\'a fait plaisir.'));
      });
    });

    group('Custom labels', () {
      test('works with custom labels', () {
        final bank = generateChoicesExactTaquinFR(
          label1: 'Pile',
          label2: 'Face',
          performerSeq: [1, 2], // Pile, Face
        );

        expect(bank.length, equals(4));
        expect(bank['12'], contains('Tu vas faire Pile, Face.'));
        expect(bank['21'], contains('Tu vas faire Face, Pile.'));
      });
    });

    group('Edge cases', () {
      test('assert fails for 0 rounds', () {
        expect(
          () => generateChoicesExactTaquinFR(
            label1: 'A',
            label2: 'B',
            performerSeq: [],
          ),
          throwsA(isA<AssertionError>()),
        );
      });

      test('assert fails for 6+ rounds', () {
        expect(
          () => generateChoicesExactTaquinFR(
            label1: 'A',
            label2: 'B',
            performerSeq: [1, 2, 1, 2, 1, 2],
          ),
          throwsA(isA<AssertionError>()),
        );
      });

      test('assert fails for invalid performer values', () {
        expect(
          () => generateChoicesExactTaquinFR(
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
