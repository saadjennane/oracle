import 'package:flutter_test/flutter_test.dart';
import 'package:oracle_poc/engine/starter_packs/choices_exact_minimal_fr.dart';

void main() {
  group('generateChoicesExactMinimalFR', () {
    group('Round 1', () {
      test('generates 2 entries for round 1', () {
        final bank = generateChoicesExactMinimalFR(
          label1: 'Gauche',
          label2: 'Droite',
          performerSeq: [1], // Gauche
        );

        expect(bank.length, equals(2));
        expect(bank.containsKey('1'), isTrue);
        expect(bank.containsKey('2'), isTrue);
      });

      test('perfect match text for round 1', () {
        final bank = generateChoicesExactMinimalFR(
          label1: 'Gauche',
          label2: 'Droite',
          performerSeq: [1], // Gauche
        );

        // Spectator chooses Gauche (1) = perfect match
        final text = bank['1']!;
        expect(text, contains('Tu vas faire Gauche.'));
        expect(text, contains('deviner'));
        expect(text, contains('Et si c\'était ça, le vrai truc'));
      });

      test('miss text for round 1', () {
        final bank = generateChoicesExactMinimalFR(
          label1: 'Gauche',
          label2: 'Droite',
          performerSeq: [1], // Gauche
        );

        // Spectator chooses Droite (2) = miss
        final text = bank['2']!;
        expect(text, contains('Tu vas faire Droite.'));
        expect(text, contains('tromper'));
        expect(text, contains('Et si c\'était ça, le vrai truc'));
      });
    });

    group('Round 3', () {
      test('generates 8 entries for round 3', () {
        final bank = generateChoicesExactMinimalFR(
          label1: 'Gauche',
          label2: 'Droite',
          performerSeq: [1, 1, 2], // G, G, D
        );

        expect(bank.length, equals(8));
        expect(bank.containsKey('111'), isTrue);
        expect(bank.containsKey('112'), isTrue);
        expect(bank.containsKey('121'), isTrue);
        expect(bank.containsKey('122'), isTrue);
        expect(bank.containsKey('211'), isTrue);
        expect(bank.containsKey('212'), isTrue);
        expect(bank.containsKey('221'), isTrue);
        expect(bank.containsKey('222'), isTrue);
      });

      test('perfect match (3 hits) text', () {
        final bank = generateChoicesExactMinimalFR(
          label1: 'Gauche',
          label2: 'Droite',
          performerSeq: [1, 1, 2], // G, G, D
        );

        // Spectator chooses G, G, D (112) = perfect match
        final text = bank['112']!;
        expect(text, contains('Tu vas faire Gauche, Gauche, Droite.'));
        expect(text, contains('deviner à chaque fois'));
        expect(text, contains('Et si c\'était ça, le vrai truc'));
      });

      test('all miss (0 hits) text', () {
        final bank = generateChoicesExactMinimalFR(
          label1: 'Gauche',
          label2: 'Droite',
          performerSeq: [1, 1, 2], // G, G, D
        );

        // Spectator chooses D, D, G (221) = all miss
        final text = bank['221']!;
        expect(text, contains('Tu vas faire Droite, Droite, Gauche.'));
        expect(text, contains('tromper à chaque fois'));
        expect(text, contains('Et si c\'était ça, le vrai truc'));
      });

      test('partial hits (2 hits, 1 miss) text', () {
        final bank = generateChoicesExactMinimalFR(
          label1: 'Gauche',
          label2: 'Droite',
          performerSeq: [1, 1, 2], // G, G, D
        );

        // Spectator chooses G, G, G (111) = 2 hits (pos 0,1), 1 miss (pos 2)
        final text = bank['111']!;
        expect(text, contains('Tu vas faire Gauche, Gauche, Gauche.'));
        expect(text, contains('deviner 2 fois'));
        expect(text, contains('laisser gagner une fois'));
        expect(text, contains('Et si c\'était ça, le vrai truc'));
      });

      test('partial hits (1 hit, 2 misses) text', () {
        final bank = generateChoicesExactMinimalFR(
          label1: 'Gauche',
          label2: 'Droite',
          performerSeq: [1, 1, 2], // G, G, D
        );

        // Spectator chooses D, G, G (211) = 1 hit (pos 1), 2 misses (pos 0,2)
        final text = bank['211']!;
        expect(text, contains('Tu vas faire Droite, Gauche, Gauche.'));
        expect(text, contains('deviner 1 fois'));
        expect(text, contains('laisser gagner 2 fois'));
        expect(text, contains('Et si c\'était ça, le vrai truc'));
      });
    });

    group('Round 5', () {
      test('generates 32 entries for round 5', () {
        final bank = generateChoicesExactMinimalFR(
          label1: 'A',
          label2: 'B',
          performerSeq: [1, 2, 1, 2, 1], // A, B, A, B, A
        );

        expect(bank.length, equals(32));
      });

      test('perfect match (5 hits) text', () {
        final bank = generateChoicesExactMinimalFR(
          label1: 'A',
          label2: 'B',
          performerSeq: [1, 2, 1, 2, 1], // A, B, A, B, A
        );

        // Spectator chooses same sequence (12121) = perfect match
        final text = bank['12121']!;
        expect(text, contains('Tu vas faire A, B, A, B, A.'));
        expect(text, contains('deviner à chaque fois'));
        expect(text, contains('Et si c\'était ça, le vrai truc'));
      });

      test('all miss (0 hits) text', () {
        final bank = generateChoicesExactMinimalFR(
          label1: 'A',
          label2: 'B',
          performerSeq: [1, 2, 1, 2, 1], // A, B, A, B, A
        );

        // Spectator chooses opposite (21212) = all miss
        final text = bank['21212']!;
        expect(text, contains('Tu vas faire B, A, B, A, B.'));
        expect(text, contains('tromper à chaque fois'));
        expect(text, contains('Et si c\'était ça, le vrai truc'));
      });

      test('partial hits (4 hits, 1 miss) text', () {
        final bank = generateChoicesExactMinimalFR(
          label1: 'A',
          label2: 'B',
          performerSeq: [1, 2, 1, 2, 1], // A, B, A, B, A
        );

        // Spectator chooses (12111) = 4 hits (pos 0,1,2,4), 1 miss (pos 3)
        // Performer: A B A B A
        // Spectator: A B A A A
        //            H H H M H
        final text = bank['12111']!;
        expect(text, contains('Tu vas faire A, B, A, A, A.'));
        expect(text, contains('deviner 4 fois'));
        expect(text, contains('laisser gagner une fois'));
        expect(text, contains('Et si c\'était ça, le vrai truc'));
      });
    });

    group('Custom labels', () {
      test('works with custom labels', () {
        final bank = generateChoicesExactMinimalFR(
          label1: 'Telephone',
          label2: 'Cle',
          performerSeq: [1, 2], // Telephone, Cle
        );

        expect(bank.length, equals(4));
        expect(bank['12'], contains('Tu vas faire Telephone, Cle.'));
        expect(bank['21'], contains('Tu vas faire Cle, Telephone.'));
      });
    });

    group('Edge cases', () {
      test('assert fails for 0 rounds', () {
        expect(
          () => generateChoicesExactMinimalFR(
            label1: 'A',
            label2: 'B',
            performerSeq: [],
          ),
          throwsA(isA<AssertionError>()),
        );
      });

      test('assert fails for 6+ rounds', () {
        expect(
          () => generateChoicesExactMinimalFR(
            label1: 'A',
            label2: 'B',
            performerSeq: [1, 2, 1, 2, 1, 2],
          ),
          throwsA(isA<AssertionError>()),
        );
      });

      test('assert fails for invalid performer values', () {
        expect(
          () => generateChoicesExactMinimalFR(
            label1: 'A',
            label2: 'B',
            performerSeq: [1, 3, 1], // 3 is invalid
          ),
          throwsA(isA<AssertionError>()),
        );
      });
    });
  });

  group('Helper functions', () {
    test('choicesToSequenceKey converts labels to key', () {
      final key = choicesToSequenceKey(
        ['Gauche', 'Droite', 'Gauche'],
        'Gauche',
        'Droite',
      );
      expect(key, equals('121'));
    });

    test('sequenceKeyToLabels converts key to labels', () {
      final labels = sequenceKeyToLabels('121', 'Gauche', 'Droite');
      expect(labels, equals(['Gauche', 'Droite', 'Gauche']));
    });
  });
}
