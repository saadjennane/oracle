import 'package:flutter_test/flutter_test.dart';
import 'package:oracle_poc/engine/starter_packs/duel_bucket_direct_fr.dart';

void main() {
  group('generateDuelBucketDirectFR', () {
    group('Bucket count formula: (R+1)(R+2)/2', () {
      test('R=1 generates 3 buckets', () {
        final bank = generateDuelBucketDirectFR(rounds: 1);
        expect(bank.length, equals(3));
        expect(bucketCountForRounds(1), equals(3));
      });

      test('R=2 generates 6 buckets', () {
        final bank = generateDuelBucketDirectFR(rounds: 2);
        expect(bank.length, equals(6));
        expect(bucketCountForRounds(2), equals(6));
      });

      test('R=3 generates 10 buckets', () {
        final bank = generateDuelBucketDirectFR(rounds: 3);
        expect(bank.length, equals(10));
        expect(bucketCountForRounds(3), equals(10));
      });

      test('R=5 generates 21 buckets', () {
        final bank = generateDuelBucketDirectFR(rounds: 5);
        expect(bank.length, equals(21));
        expect(bucketCountForRounds(5), equals(21));
      });

      test('R=10 generates 66 buckets', () {
        final bank = generateDuelBucketDirectFR(rounds: 10);
        expect(bank.length, equals(66));
        expect(bucketCountForRounds(10), equals(66));
      });
    });

    group('Key format: {R}|{S}-{P}|T{ties}', () {
      test('R=1 has correct keys', () {
        final bank = generateDuelBucketDirectFR(rounds: 1);

        // S=1, P=0, T=0
        expect(bank.containsKey('1|1-0|T0'), isTrue);
        // S=0, P=1, T=0
        expect(bank.containsKey('1|0-1|T0'), isTrue);
        // S=0, P=0, T=1
        expect(bank.containsKey('1|0-0|T1'), isTrue);
      });

      test('R=3 has expected keys', () {
        final bank = generateDuelBucketDirectFR(rounds: 3);

        // All spectator wins
        expect(bank.containsKey('3|3-0|T0'), isTrue);
        // All performer wins
        expect(bank.containsKey('3|0-3|T0'), isTrue);
        // All ties
        expect(bank.containsKey('3|0-0|T3'), isTrue);
        // Mixed: 1 each
        expect(bank.containsKey('3|1-1|T1'), isTrue);
        // 2-1 spectator wins
        expect(bank.containsKey('3|2-1|T0'), isTrue);
      });
    });

    group('Invariant: S + P + ties = R', () {
      test('all keys respect invariant for R=1 to R=10', () {
        for (int r = 1; r <= 10; r++) {
          final bank = generateDuelBucketDirectFR(rounds: r);

          for (final key in bank.keys) {
            final parsed = parseBucketKey(key);
            expect(parsed, isNotNull, reason: 'Key $key should be parseable');
            expect(
              parsed!.spectatorWins + parsed.performerWins + parsed.ties,
              equals(parsed.rounds),
              reason:
                  'Invariant violated for key $key: ${parsed.spectatorWins}+${parsed.performerWins}+${parsed.ties} != ${parsed.rounds}',
            );
          }
        }
      });
    });

    group('parseBucketKey', () {
      test('parses valid key correctly', () {
        final result = parseBucketKey('3|2-1|T0');
        expect(result, isNotNull);
        expect(result!.rounds, equals(3));
        expect(result.spectatorWins, equals(2));
        expect(result.performerWins, equals(1));
        expect(result.ties, equals(0));
      });

      test('parses key with ties', () {
        final result = parseBucketKey('5|1-2|T2');
        expect(result, isNotNull);
        expect(result!.rounds, equals(5));
        expect(result.spectatorWins, equals(1));
        expect(result.performerWins, equals(2));
        expect(result.ties, equals(2));
      });

      test('returns null for invalid format', () {
        expect(parseBucketKey('invalid'), isNull);
        expect(parseBucketKey('H0'), isNull);
        expect(parseBucketKey('3|2-1'), isNull);
        expect(parseBucketKey('3|2-1|0'), isNull);
      });

      test('returns null for broken invariant', () {
        // 2+1+1 = 4, but rounds = 3
        expect(parseBucketKey('3|2-1|T1'), isNull);
      });
    });

    group('Text content - Spectator wins', () {
      test('spectator wins clean has correct text', () {
        final bank = generateDuelBucketDirectFR(rounds: 3);
        final text = bank['3|3-0|T0']!;

        expect(text, contains('{spectatorSequence}'));
        expect(text, contains('Score final 3-0'));
        expect(text, contains('Je te laisse gagner'));
        expect(text, isNot(contains('égalité')));
      });

      test('spectator wins with ties has correct text', () {
        final bank = generateDuelBucketDirectFR(rounds: 3);
        final text = bank['3|2-0|T1']!;

        expect(text, contains('Score final 2-0'));
        expect(text, contains('1 égalité'));
        expect(text, contains('suspense'));
      });
    });

    group('Text content - Performer wins', () {
      test('performer wins clean has correct text', () {
        final bank = generateDuelBucketDirectFR(rounds: 3);
        final text = bank['3|0-3|T0']!;

        expect(text, contains('Score final 0-3'));
        expect(text, contains('quelques points'));
        expect(text, contains('confiance'));
      });

      test('performer wins with ties has correct text', () {
        final bank = generateDuelBucketDirectFR(rounds: 3);
        final text = bank['3|1-1|T1']!;

        expect(text, contains('Score final 1-1'));
        expect(text, contains('1 égalité'));
      });
    });

    group('Text content - Perfect tie', () {
      test('perfect tie (S==P) no ties has correct text', () {
        final bank = generateDuelBucketDirectFR(rounds: 2);
        final text = bank['2|1-1|T0']!;

        expect(text, contains('Score final 1-1'));
        expect(text, contains('égalité parfaite'));
        expect(text, contains('doutes'));
      });

      test('perfect tie (S==P) with ties has correct text', () {
        final bank = generateDuelBucketDirectFR(rounds: 4);
        final text = bank['4|1-1|T2']!;

        expect(text, contains('Score final 1-1'));
        expect(text, contains('2 égalités'));
        expect(text, contains('égalité globale'));
      });
    });

    group('Text format constraints', () {
      test('no colon in any text', () {
        for (int rounds = 1; rounds <= 10; rounds++) {
          final bank = generateDuelBucketDirectFR(rounds: rounds);
          for (final entry in bank.entries) {
            expect(entry.value, isNot(contains(':')),
                reason: 'Round $rounds, key ${entry.key} contains colon');
          }
        }
      });

      test('no round/tour/manche in any text', () {
        for (int rounds = 1; rounds <= 10; rounds++) {
          final bank = generateDuelBucketDirectFR(rounds: rounds);
          for (final text in bank.values) {
            expect(text.toLowerCase(), isNot(contains('round')));
            expect(text.toLowerCase(), isNot(contains('tour')));
            expect(text.toLowerCase(), isNot(contains('manche')));
          }
        }
      });

      test('all texts have placeholder', () {
        for (int rounds = 1; rounds <= 10; rounds++) {
          final bank = generateDuelBucketDirectFR(rounds: rounds);
          for (final entry in bank.entries) {
            expect(entry.value, contains('{spectatorSequence}'),
                reason:
                    'Round $rounds, bucket ${entry.key} missing placeholder');
          }
        }
      });

      test('all texts have signature line', () {
        for (int rounds = 1; rounds <= 10; rounds++) {
          final bank = generateDuelBucketDirectFR(rounds: rounds);
          for (final text in bank.values) {
            expect(text, contains("Et c'était ça le vrai truc"));
          }
        }
      });

      test('texts have 4 lines', () {
        for (int rounds = 1; rounds <= 10; rounds++) {
          final bank = generateDuelBucketDirectFR(rounds: rounds);
          for (final entry in bank.entries) {
            final lines = entry.value.split('\n');
            expect(lines.length, equals(4),
                reason:
                    'Round $rounds, bucket ${entry.key} has ${lines.length} lines');
          }
        }
      });
    });

    group('generateDuelBucketDirectFRAll', () {
      test('generates all buckets from 1 to maxRounds', () {
        final bank = generateDuelBucketDirectFRAll(maxRounds: 3);

        // Total: 3 + 6 + 10 = 19 buckets
        expect(bank.length, equals(19));

        // Check keys from each round
        expect(bank.containsKey('1|1-0|T0'), isTrue);
        expect(bank.containsKey('2|2-0|T0'), isTrue);
        expect(bank.containsKey('3|3-0|T0'), isTrue);
      });
    });

    group('Edge cases', () {
      test('assert fails for 0 rounds', () {
        expect(
          () => generateDuelBucketDirectFR(rounds: 0),
          throwsA(isA<AssertionError>()),
        );
      });

      test('assert fails for 11+ rounds', () {
        expect(
          () => generateDuelBucketDirectFR(rounds: 11),
          throwsA(isA<AssertionError>()),
        );
      });
    });
  });
}
