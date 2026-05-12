import 'package:flutter_test/flutter_test.dart';
import 'package:oracle_poc/engine/starter_packs/choices_bucket_direct_fr.dart';

void main() {
  group('generateChoicesBucketDirectFR', () {
    group('Round 1', () {
      test('generates 2 buckets for round 1', () {
        final bank = generateChoicesBucketDirectFR(rounds: 1);

        expect(bank.length, equals(2));
        expect(bank.containsKey('H0'), isTrue);
        expect(bank.containsKey('H1'), isTrue);
      });

      test('H0 text has correct structure (all miss)', () {
        final bank = generateChoicesBucketDirectFR(rounds: 1);
        final text = bank['H0']!;

        expect(text, contains('{spectatorSequenceLabeled}'));
        expect(text, contains('Je ne vais rien deviner'));
        expect(text, contains('te laisser une fois'));
        expect(text, contains("Et c'était ça le vrai truc"));
      });

      test('H1 text has correct structure (perfect)', () {
        final bank = generateChoicesBucketDirectFR(rounds: 1);
        final text = bank['H1']!;

        expect(text, contains('{spectatorSequenceLabeled}'));
        expect(text, contains('Je vais tout deviner'));
        // No miss line for perfect - check it doesn't have "te laisser une fois" or similar
        expect(text, isNot(contains('te laisser une fois')));
        expect(text, isNot(contains('te laisser 1 fois')));
        expect(text, contains("Et c'était ça le vrai truc"));
      });
    });

    group('Round 3', () {
      test('generates 4 buckets for round 3', () {
        final bank = generateChoicesBucketDirectFR(rounds: 3);

        expect(bank.length, equals(4));
        expect(bank.containsKey('H0'), isTrue);
        expect(bank.containsKey('H1'), isTrue);
        expect(bank.containsKey('H2'), isTrue);
        expect(bank.containsKey('H3'), isTrue);
      });

      test('H0 has 3 misses line', () {
        final bank = generateChoicesBucketDirectFR(rounds: 3);
        final text = bank['H0']!;

        expect(text, contains('Je ne vais rien deviner'));
        expect(text, contains('te laisser 3 fois'));
      });

      test('H1 has 1 hit and 2 misses', () {
        final bank = generateChoicesBucketDirectFR(rounds: 3);
        final text = bank['H1']!;

        expect(text, contains('Je vais deviner une seule fois'));
        expect(text, contains('te laisser 2 fois'));
      });

      test('H2 has 2 hits and 1 miss', () {
        final bank = generateChoicesBucketDirectFR(rounds: 3);
        final text = bank['H2']!;

        expect(text, contains('Je vais deviner 2 fois'));
        expect(text, contains('te laisser une fois'));
      });

      test('H3 is perfect (no miss line)', () {
        final bank = generateChoicesBucketDirectFR(rounds: 3);
        final text = bank['H3']!;

        expect(text, contains('Je vais tout deviner'));
        // No miss line - check it doesn't have "te laisser X fois"
        expect(text, isNot(contains('te laisser une fois')));
        expect(text, isNot(contains(RegExp(r'te laisser \d+ fois'))));
      });
    });

    group('Round 10', () {
      test('generates 11 buckets for round 10', () {
        final bank = generateChoicesBucketDirectFR(rounds: 10);

        expect(bank.length, equals(11));
        for (int i = 0; i <= 10; i++) {
          expect(bank.containsKey('H$i'), isTrue);
        }
      });

      test('H0 has 10 misses', () {
        final bank = generateChoicesBucketDirectFR(rounds: 10);
        final text = bank['H0']!;

        expect(text, contains('Je ne vais rien deviner'));
        expect(text, contains('te laisser 10 fois'));
      });

      test('H5 has 5 hits and 5 misses', () {
        final bank = generateChoicesBucketDirectFR(rounds: 10);
        final text = bank['H5']!;

        expect(text, contains('Je vais deviner 5 fois'));
        expect(text, contains('te laisser 5 fois'));
      });

      test('H10 is perfect', () {
        final bank = generateChoicesBucketDirectFR(rounds: 10);
        final text = bank['H10']!;

        expect(text, contains('Je vais tout deviner'));
        // No miss line - check it doesn't have "te laisser X fois"
        expect(text, isNot(contains('te laisser une fois')));
        expect(text, isNot(contains(RegExp(r'te laisser \d+ fois'))));
      });
    });

    group('Text format constraints', () {
      test('no colon in any text', () {
        for (int rounds = 1; rounds <= 10; rounds++) {
          final bank = generateChoicesBucketDirectFR(rounds: rounds);
          for (final text in bank.values) {
            expect(text, isNot(contains(':')),
                reason: 'Round $rounds contains colon');
          }
        }
      });

      test('no round/tour/manche in any text', () {
        for (int rounds = 1; rounds <= 10; rounds++) {
          final bank = generateChoicesBucketDirectFR(rounds: rounds);
          for (final text in bank.values) {
            expect(text.toLowerCase(), isNot(contains('round')));
            expect(text.toLowerCase(), isNot(contains('tour')));
            expect(text.toLowerCase(), isNot(contains('manche')));
          }
        }
      });

      test('all texts have placeholder', () {
        for (int rounds = 1; rounds <= 10; rounds++) {
          final bank = generateChoicesBucketDirectFR(rounds: rounds);
          for (final entry in bank.entries) {
            expect(entry.value, contains('{spectatorSequenceLabeled}'),
                reason: 'Round $rounds, bucket ${entry.key} missing placeholder');
          }
        }
      });

      test('all texts have signature line', () {
        for (int rounds = 1; rounds <= 10; rounds++) {
          final bank = generateChoicesBucketDirectFR(rounds: rounds);
          for (final text in bank.values) {
            expect(text, contains("Et c'était ça le vrai truc"));
          }
        }
      });

      test('texts have 3-4 lines max', () {
        for (int rounds = 1; rounds <= 10; rounds++) {
          final bank = generateChoicesBucketDirectFR(rounds: rounds);
          for (final entry in bank.entries) {
            final lines = entry.value.split('\n');
            expect(lines.length, lessThanOrEqualTo(4),
                reason:
                    'Round $rounds, bucket ${entry.key} has ${lines.length} lines');
            expect(lines.length, greaterThanOrEqualTo(3),
                reason:
                    'Round $rounds, bucket ${entry.key} has ${lines.length} lines');
          }
        }
      });
    });

    group('Edge cases', () {
      test('assert fails for 0 rounds', () {
        expect(
          () => generateChoicesBucketDirectFR(rounds: 0),
          throwsA(isA<AssertionError>()),
        );
      });

      test('assert fails for 11+ rounds', () {
        expect(
          () => generateChoicesBucketDirectFR(rounds: 11),
          throwsA(isA<AssertionError>()),
        );
      });
    });
  });
}
