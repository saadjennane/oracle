import 'package:flutter_test/flutter_test.dart';
import 'package:oracle_poc/engine/starter_packs/choices_bucket_direct_fr.dart';
import 'package:oracle_poc/engine/starter_packs/choices_bucket_direct_en.dart';
import 'package:oracle_poc/engine/starter_packs/choices_bucket_taquin_fr.dart';
import 'package:oracle_poc/engine/starter_packs/choices_bucket_taquin_en.dart';
import 'package:oracle_poc/engine/starter_packs/duel_bucket_direct_fr.dart';
import 'package:oracle_poc/engine/starter_packs/duel_bucket_direct_en.dart';
import 'package:oracle_poc/engine/starter_packs/duel_bucket_taquin_fr.dart';
import 'package:oracle_poc/engine/starter_packs/duel_bucket_taquin_en.dart';
import 'package:oracle_poc/engine/starter_packs/duel_firstto_bucket_direct_fr.dart';
import 'package:oracle_poc/engine/starter_packs/duel_firstto_bucket_direct_en.dart';
import 'package:oracle_poc/engine/starter_packs/duel_firstto_bucket_taquin_fr.dart';
import 'package:oracle_poc/engine/starter_packs/duel_firstto_bucket_taquin_en.dart';
import 'package:oracle_poc/engine/starter_packs/choices_exact_direct_fr.dart';
import 'package:oracle_poc/engine/starter_packs/choices_exact_direct_en.dart';
import 'package:oracle_poc/engine/starter_packs/choices_exact_taquin_fr.dart';
import 'package:oracle_poc/engine/starter_packs/choices_exact_taquin_en.dart';

void main() {
  // ========== CHOICES EXACT SEQUENCE ==========

  group('Choices exact_sequence — Direct + Taquin — FR + EN', () {
    final label1 = 'Gauche';
    final label2 = 'Droite';
    final performerSeq = [1, 2, 1]; // 3 rounds

    test('FR Direct: 8 entries for 3 rounds', () {
      final bank = generateChoicesExactDirectFR(
        label1: label1,
        label2: label2,
        performerSeq: performerSeq,
      );
      expect(bank.length, equals(8));
    });

    test('FR Taquin: 8 entries for 3 rounds', () {
      final bank = generateChoicesExactTaquinFR(
        label1: label1,
        label2: label2,
        performerSeq: performerSeq,
      );
      expect(bank.length, equals(8));
    });

    test('EN Direct: 8 entries for 3 rounds', () {
      final bank = generateChoicesExactDirectEN(
        label1: 'Left',
        label2: 'Right',
        performerSeq: performerSeq,
      );
      expect(bank.length, equals(8));
    });

    test('EN Taquin: 8 entries for 3 rounds', () {
      final bank = generateChoicesExactTaquinEN(
        label1: 'Left',
        label2: 'Right',
        performerSeq: performerSeq,
      );
      expect(bank.length, equals(8));
    });

    test('EN Direct has English signature', () {
      final bank = generateChoicesExactDirectEN(
        label1: 'Left',
        label2: 'Right',
        performerSeq: [1],
      );
      for (final text in bank.values) {
        expect(text, contains('the real trick'));
      }
    });

    test('EN Taquin has English taquin signature', () {
      final bank = generateChoicesExactTaquinEN(
        label1: 'Left',
        label2: 'Right',
        performerSeq: [1],
      );
      for (final text in bank.values) {
        expect(text, contains('I hope you enjoyed it'));
      }
    });
  });

  // ========== CHOICES BUCKETS ==========

  group('Choices buckets — Direct + Taquin — FR + EN', () {
    test('FR Direct: R=3 => H0..H3 (4 buckets)', () {
      final bank = generateChoicesBucketDirectFR(rounds: 3);
      expect(bank.length, equals(4));
      for (int i = 0; i <= 3; i++) {
        expect(bank.containsKey('H$i'), isTrue);
        expect(bank['H$i'], contains('{spectatorSequenceLabeled}'));
      }
    });

    test('FR Taquin: R=3 => H0..H3 (4 buckets)', () {
      final bank = generateChoicesBucketTaquinFR(rounds: 3);
      expect(bank.length, equals(4));
      for (int i = 0; i <= 3; i++) {
        expect(bank.containsKey('H$i'), isTrue);
        expect(bank['H$i'], contains('{spectatorSequenceLabeled}'));
      }
    });

    test('EN Direct: R=3 => H0..H3 (4 buckets)', () {
      final bank = generateChoicesBucketDirectEN(rounds: 3);
      expect(bank.length, equals(4));
      for (int i = 0; i <= 3; i++) {
        expect(bank.containsKey('H$i'), isTrue);
        expect(bank['H$i'], contains('{spectatorSequenceLabeled}'));
      }
    });

    test('EN Taquin: R=3 => H0..H3 (4 buckets)', () {
      final bank = generateChoicesBucketTaquinEN(rounds: 3);
      expect(bank.length, equals(4));
      for (int i = 0; i <= 3; i++) {
        expect(bank.containsKey('H$i'), isTrue);
        expect(bank['H$i'], contains('{spectatorSequenceLabeled}'));
      }
    });

    test('FR Taquin has taquin signature', () {
      final bank = generateChoicesBucketTaquinFR(rounds: 3);
      for (final text in bank.values) {
        expect(text, contains("J'espère que ça t'a fait plaisir"));
      }
    });

    test('EN Taquin has taquin EN signature', () {
      final bank = generateChoicesBucketTaquinEN(rounds: 3);
      for (final text in bank.values) {
        expect(text, contains('I hope you enjoyed it'));
      }
    });

    test('FR Direct has direct signature', () {
      final bank = generateChoicesBucketDirectFR(rounds: 3);
      for (final text in bank.values) {
        expect(text, contains("Et c'était ça le vrai truc"));
      }
    });

    test('EN Direct has direct EN signature', () {
      final bank = generateChoicesBucketDirectEN(rounds: 3);
      for (final text in bank.values) {
        expect(text, contains('the real trick'));
      }
    });
  });

  // ========== DUEL FIXED ROUNDS ==========

  group('Duel fixed rounds — Direct + Taquin — FR + EN', () {
    test('FR Direct: R=3 => 10 buckets', () {
      final bank = generateDuelBucketDirectFR(rounds: 3);
      expect(bank.length, equals(10));
    });

    test('FR Taquin: R=3 => 10 buckets', () {
      final bank = generateDuelBucketTaquinFR(rounds: 3);
      expect(bank.length, equals(10));
    });

    test('EN Direct: R=3 => 10 buckets', () {
      final bank = generateDuelBucketDirectEN(rounds: 3);
      expect(bank.length, equals(10));
    });

    test('EN Taquin: R=3 => 10 buckets', () {
      final bank = generateDuelBucketTaquinEN(rounds: 3);
      expect(bank.length, equals(10));
    });

    test('All styles have same keys for R=3', () {
      final directFR = generateDuelBucketDirectFR(rounds: 3);
      final taquinFR = generateDuelBucketTaquinFR(rounds: 3);
      final directEN = generateDuelBucketDirectEN(rounds: 3);
      final taquinEN = generateDuelBucketTaquinEN(rounds: 3);

      final keys = directFR.keys.toSet();
      expect(taquinFR.keys.toSet(), equals(keys));
      expect(directEN.keys.toSet(), equals(keys));
      expect(taquinEN.keys.toSet(), equals(keys));
    });

    test('FR Taquin has taquin signature', () {
      final bank = generateDuelBucketTaquinFR(rounds: 3);
      for (final text in bank.values) {
        expect(text, contains("J'espère que ça t'a fait plaisir"));
      }
    });

    test('EN Taquin has taquin EN signature', () {
      final bank = generateDuelBucketTaquinEN(rounds: 3);
      for (final text in bank.values) {
        expect(text, contains('I hope you enjoyed it'));
      }
    });

    test('All styles have {spectatorSequence} placeholder', () {
      final banks = [
        generateDuelBucketDirectFR(rounds: 3),
        generateDuelBucketTaquinFR(rounds: 3),
        generateDuelBucketDirectEN(rounds: 3),
        generateDuelBucketTaquinEN(rounds: 3),
      ];

      for (final bank in banks) {
        for (final text in bank.values) {
          expect(text, contains('{spectatorSequence}'));
        }
      }
    });
  });

  // ========== DUEL FIRST-TO ==========

  group('Duel first-to — Direct + Taquin — FR + EN', () {
    test('FR Direct: T=3 => 6 buckets', () {
      final bank = generateDuelFirstToBucketDirectFR(targetScore: 3);
      expect(bank.length, equals(6));
    });

    test('FR Taquin: T=3 => 6 buckets', () {
      final bank = generateDuelFirstToBucketTaquinFR(targetScore: 3);
      expect(bank.length, equals(6));
    });

    test('EN Direct: T=3 => 6 buckets', () {
      final bank = generateDuelFirstToBucketDirectEN(targetScore: 3);
      expect(bank.length, equals(6));
    });

    test('EN Taquin: T=3 => 6 buckets', () {
      final bank = generateDuelFirstToBucketTaquinEN(targetScore: 3);
      expect(bank.length, equals(6));
    });

    test('All styles have same keys for T=3', () {
      final directFR = generateDuelFirstToBucketDirectFR(targetScore: 3);
      final taquinFR = generateDuelFirstToBucketTaquinFR(targetScore: 3);
      final directEN = generateDuelFirstToBucketDirectEN(targetScore: 3);
      final taquinEN = generateDuelFirstToBucketTaquinEN(targetScore: 3);

      final keys = directFR.keys.toSet();
      expect(taquinFR.keys.toSet(), equals(keys));
      expect(directEN.keys.toSet(), equals(keys));
      expect(taquinEN.keys.toSet(), equals(keys));
    });

    test('FR Taquin has taquin signature', () {
      final bank = generateDuelFirstToBucketTaquinFR(targetScore: 3);
      for (final text in bank.values) {
        expect(text, contains("J'espère que ça t'a fait plaisir"));
      }
    });

    test('EN Taquin has taquin EN signature', () {
      final bank = generateDuelFirstToBucketTaquinEN(targetScore: 3);
      for (final text in bank.values) {
        expect(text, contains('I hope you enjoyed it'));
      }
    });

    test('All styles have {spectatorSequence} placeholder', () {
      final banks = [
        generateDuelFirstToBucketDirectFR(targetScore: 3),
        generateDuelFirstToBucketTaquinFR(targetScore: 3),
        generateDuelFirstToBucketDirectEN(targetScore: 3),
        generateDuelFirstToBucketTaquinEN(targetScore: 3),
      ];

      for (final bank in banks) {
        for (final text in bank.values) {
          expect(text, contains('{spectatorSequence}'));
        }
      }
    });
  });

  // ========== CROSS-CUTTING: NO COLONS ==========

  group('No colon in any generated text', () {
    test('Choices buckets — all styles — no colons', () {
      for (int r = 1; r <= 10; r++) {
        for (final bank in [
          generateChoicesBucketDirectFR(rounds: r),
          generateChoicesBucketTaquinFR(rounds: r),
          generateChoicesBucketDirectEN(rounds: r),
          generateChoicesBucketTaquinEN(rounds: r),
        ]) {
          for (final text in bank.values) {
            expect(text, isNot(contains(':')),
                reason: 'Colon found in R=$r');
          }
        }
      }
    });

    test('Duel fixed — all styles — no colons', () {
      for (int r = 1; r <= 5; r++) {
        for (final bank in [
          generateDuelBucketDirectFR(rounds: r),
          generateDuelBucketTaquinFR(rounds: r),
          generateDuelBucketDirectEN(rounds: r),
          generateDuelBucketTaquinEN(rounds: r),
        ]) {
          for (final text in bank.values) {
            expect(text, isNot(contains(':')),
                reason: 'Colon found in R=$r');
          }
        }
      }
    });

    test('Duel first-to — all styles — no colons', () {
      for (int t = 2; t <= 5; t++) {
        for (final bank in [
          generateDuelFirstToBucketDirectFR(targetScore: t),
          generateDuelFirstToBucketTaquinFR(targetScore: t),
          generateDuelFirstToBucketDirectEN(targetScore: t),
          generateDuelFirstToBucketTaquinEN(targetScore: t),
        ]) {
          for (final text in bank.values) {
            expect(text, isNot(contains(':')),
                reason: 'Colon found in T=$t');
          }
        }
      }
    });
  });
}
