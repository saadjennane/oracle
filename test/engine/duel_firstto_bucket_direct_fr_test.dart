import 'package:flutter_test/flutter_test.dart';
import 'package:oracle_poc/engine/starter_packs/duel_firstto_bucket_direct_fr.dart';

void main() {
  group('generateDuelFirstToBucketDirectFR', () {
    group('Bucket count formula: 2*T', () {
      test('T=2 generates 4 buckets', () {
        final bank = generateDuelFirstToBucketDirectFR(targetScore: 2);
        expect(bank.length, equals(4));
        expect(firstToBucketCount(2), equals(4));
      });

      test('T=3 generates 6 buckets', () {
        final bank = generateDuelFirstToBucketDirectFR(targetScore: 3);
        expect(bank.length, equals(6));
        expect(firstToBucketCount(3), equals(6));
      });

      test('T=4 generates 8 buckets', () {
        final bank = generateDuelFirstToBucketDirectFR(targetScore: 4);
        expect(bank.length, equals(8));
        expect(firstToBucketCount(4), equals(8));
      });

      test('T=5 generates 10 buckets', () {
        final bank = generateDuelFirstToBucketDirectFR(targetScore: 5);
        expect(bank.length, equals(10));
        expect(firstToBucketCount(5), equals(10));
      });
    });

    group('Key format: {T}|{winner}|{loserScore}', () {
      test('T=2 has correct keys', () {
        final bank = generateDuelFirstToBucketDirectFR(targetScore: 2);

        // Spectateur gagne 2-0, 2-1
        expect(bank.containsKey('2|S|0'), isTrue);
        expect(bank.containsKey('2|S|1'), isTrue);
        // Performer gagne 2-0, 2-1
        expect(bank.containsKey('2|P|0'), isTrue);
        expect(bank.containsKey('2|P|1'), isTrue);
      });

      test('T=3 has correct keys', () {
        final bank = generateDuelFirstToBucketDirectFR(targetScore: 3);

        // Spectateur gagne 3-0, 3-1, 3-2
        expect(bank.containsKey('3|S|0'), isTrue);
        expect(bank.containsKey('3|S|1'), isTrue);
        expect(bank.containsKey('3|S|2'), isTrue);
        // Performer gagne 3-0, 3-1, 3-2
        expect(bank.containsKey('3|P|0'), isTrue);
        expect(bank.containsKey('3|P|1'), isTrue);
        expect(bank.containsKey('3|P|2'), isTrue);
      });

      test('T=5 has correct keys', () {
        final bank = generateDuelFirstToBucketDirectFR(targetScore: 5);

        // Spectateur gagne 5-0 à 5-4
        for (int loser = 0; loser < 5; loser++) {
          expect(bank.containsKey('5|S|$loser'), isTrue);
          expect(bank.containsKey('5|P|$loser'), isTrue);
        }
      });
    });

    group('parseFirstToBucketKey', () {
      test('parses valid key correctly', () {
        final result = parseFirstToBucketKey('3|S|1');
        expect(result, isNotNull);
        expect(result!.targetScore, equals(3));
        expect(result.winner, equals('S'));
        expect(result.loserScore, equals(1));
      });

      test('parses performer win correctly', () {
        final result = parseFirstToBucketKey('5|P|3');
        expect(result, isNotNull);
        expect(result!.targetScore, equals(5));
        expect(result.winner, equals('P'));
        expect(result.loserScore, equals(3));
      });

      test('returns null for invalid format', () {
        expect(parseFirstToBucketKey('invalid'), isNull);
        expect(parseFirstToBucketKey('3|2-1|T0'), isNull); // Fixed rounds format
        expect(parseFirstToBucketKey('H0'), isNull); // CHOICES format
        expect(parseFirstToBucketKey('3|X|1'), isNull); // Invalid winner
      });

      test('returns null for out-of-range targetScore', () {
        expect(parseFirstToBucketKey('1|S|0'), isNull); // T < 2
        expect(parseFirstToBucketKey('6|S|0'), isNull); // T > 5
      });

      test('returns null for invalid loserScore', () {
        expect(parseFirstToBucketKey('3|S|3'), isNull); // loserScore >= T
        expect(parseFirstToBucketKey('3|S|5'), isNull); // loserScore >= T
      });
    });

    group('Text content - Spectateur wins', () {
      test('spectateur wins clean (3-0) has correct text', () {
        final bank = generateDuelFirstToBucketDirectFR(targetScore: 3);
        final text = bank['3|S|0']!;

        expect(text, contains('{spectatorSequence}'));
        expect(text, contains('Score final 3-0'));
        expect(text, contains('Je te laisse gagner'));
        expect(text, contains('juste assez'));
      });

      test('spectateur wins close (3-2) has correct text', () {
        final bank = generateDuelFirstToBucketDirectFR(targetScore: 3);
        final text = bank['3|S|2']!;

        expect(text, contains('Score final 3-2'));
        expect(text, contains('2 points'));
        expect(text, contains('tu y croies'));
      });

      test('spectateur wins with 1 point (3-1) uses singular', () {
        final bank = generateDuelFirstToBucketDirectFR(targetScore: 3);
        final text = bank['3|S|1']!;

        expect(text, contains('Score final 3-1'));
        expect(text, contains('1 point'));
        expect(text, isNot(contains('1 points')));
      });
    });

    group('Text content - Performer wins', () {
      test('performer wins clean (0-3) has correct text', () {
        final bank = generateDuelFirstToBucketDirectFR(targetScore: 3);
        final text = bank['3|P|0']!;

        expect(text, contains('Score final 0-3'));
        expect(text, contains('Je te laisse y croire un peu'));
      });

      test('performer wins close (2-3) has correct text', () {
        final bank = generateDuelFirstToBucketDirectFR(targetScore: 3);
        final text = bank['3|P|2']!;

        expect(text, contains('Score final 2-3'));
        expect(text, contains('2 points'));
        expect(text, contains('confiance'));
      });

      test('performer wins with 1 point (1-3) uses singular', () {
        final bank = generateDuelFirstToBucketDirectFR(targetScore: 3);
        final text = bank['3|P|1']!;

        expect(text, contains('Score final 1-3'));
        expect(text, contains('1 point'));
        expect(text, isNot(contains('1 points')));
      });
    });

    group('Text format constraints', () {
      test('no colon in any text', () {
        for (int t = 2; t <= 5; t++) {
          final bank = generateDuelFirstToBucketDirectFR(targetScore: t);
          for (final entry in bank.entries) {
            expect(entry.value, isNot(contains(':')),
                reason: 'T=$t, key ${entry.key} contains colon');
          }
        }
      });

      test('no round/tour/manche in any text', () {
        for (int t = 2; t <= 5; t++) {
          final bank = generateDuelFirstToBucketDirectFR(targetScore: t);
          for (final text in bank.values) {
            expect(text.toLowerCase(), isNot(contains('round')));
            expect(text.toLowerCase(), isNot(contains('tour')));
            expect(text.toLowerCase(), isNot(contains('manche')));
          }
        }
      });

      test('all texts have placeholder', () {
        for (int t = 2; t <= 5; t++) {
          final bank = generateDuelFirstToBucketDirectFR(targetScore: t);
          for (final entry in bank.entries) {
            expect(entry.value, contains('{spectatorSequence}'),
                reason: 'T=$t, bucket ${entry.key} missing placeholder');
          }
        }
      });

      test('all texts have signature line', () {
        for (int t = 2; t <= 5; t++) {
          final bank = generateDuelFirstToBucketDirectFR(targetScore: t);
          for (final text in bank.values) {
            expect(text, contains("Et c'était ça le vrai truc"));
          }
        }
      });

      test('texts have 4 lines', () {
        for (int t = 2; t <= 5; t++) {
          final bank = generateDuelFirstToBucketDirectFR(targetScore: t);
          for (final entry in bank.entries) {
            final lines = entry.value.split('\n');
            expect(lines.length, equals(4),
                reason: 'T=$t, bucket ${entry.key} has ${lines.length} lines');
          }
        }
      });
    });

    group('generateDuelFirstToBucketDirectFRAll', () {
      test('generates all buckets from T=2 to maxTarget', () {
        final bank = generateDuelFirstToBucketDirectFRAll(maxTarget: 3);

        // Total: 4 + 6 = 10 buckets
        expect(bank.length, equals(10));

        // Check keys from each targetScore
        expect(bank.containsKey('2|S|0'), isTrue);
        expect(bank.containsKey('2|P|1'), isTrue);
        expect(bank.containsKey('3|S|2'), isTrue);
        expect(bank.containsKey('3|P|0'), isTrue);
      });

      test('generates all buckets for T=2 to T=5', () {
        final bank = generateDuelFirstToBucketDirectFRAll(maxTarget: 5);

        // Total: 4 + 6 + 8 + 10 = 28 buckets
        expect(bank.length, equals(28));
      });
    });

    group('Edge cases', () {
      test('assert fails for targetScore < 2', () {
        expect(
          () => generateDuelFirstToBucketDirectFR(targetScore: 1),
          throwsA(isA<AssertionError>()),
        );
      });

      test('assert fails for targetScore > 5', () {
        expect(
          () => generateDuelFirstToBucketDirectFR(targetScore: 6),
          throwsA(isA<AssertionError>()),
        );
      });
    });

    group('Score display format', () {
      test('spectateur win shows spectateur score first', () {
        final bank = generateDuelFirstToBucketDirectFR(targetScore: 3);

        // 3|S|1 means spectateur gagne 3-1
        final text = bank['3|S|1']!;
        expect(text, contains('Score final 3-1'));
      });

      test('performer win shows spectateur score first', () {
        final bank = generateDuelFirstToBucketDirectFR(targetScore: 3);

        // 3|P|1 means performer gagne, spectateur a 1 point => 1-3
        final text = bank['3|P|1']!;
        expect(text, contains('Score final 1-3'));
      });
    });
  });
}
