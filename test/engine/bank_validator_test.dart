import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:oracle_poc/engine/bank_validator.dart';

void main() {
  // ========== COMPUTE EXPECTED KEYS ==========

  group('computeExpectedKeys', () {
    test('choices exact_sequence N=2 R=3 => 8 keys', () {
      final meta = BankImportMeta(
        preset: 'choices',
        mode: 'exact_sequence',
        rounds: 3,
        options: ['Gauche', 'Droite'],
      );
      final keys = BankValidator.computeExpectedKeys(
        bankType: BankType.choicesExactSequence,
        meta: meta,
      );
      expect(keys.length, equals(8));
      expect(keys, contains('111'));
      expect(keys, contains('112'));
      expect(keys, contains('121'));
      expect(keys, contains('122'));
      expect(keys, contains('211'));
      expect(keys, contains('212'));
      expect(keys, contains('221'));
      expect(keys, contains('222'));
    });

    test('choices exact_sequence N=3 R=2 => 9 keys', () {
      final meta = BankImportMeta(
        preset: 'choices',
        mode: 'exact_sequence',
        rounds: 2,
        options: ['A', 'B', 'C'],
      );
      final keys = BankValidator.computeExpectedKeys(
        bankType: BankType.choicesExactSequence,
        meta: meta,
      );
      expect(keys.length, equals(9));
      expect(keys, contains('11'));
      expect(keys, contains('12'));
      expect(keys, contains('13'));
      expect(keys, contains('21'));
      expect(keys, contains('22'));
      expect(keys, contains('23'));
      expect(keys, contains('31'));
      expect(keys, contains('32'));
      expect(keys, contains('33'));
    });

    test('choices bucket R=3 => 4 keys (H0..H3)', () {
      final meta = BankImportMeta(
        preset: 'choices',
        mode: 'bucket',
        rounds: 3,
      );
      final keys = BankValidator.computeExpectedKeys(
        bankType: BankType.choicesBucket,
        meta: meta,
      );
      expect(keys.length, equals(4));
      expect(keys, containsAll(['H0', 'H1', 'H2', 'H3']));
    });

    test('choices bucket R=5 => 6 keys', () {
      final meta = BankImportMeta(
        preset: 'choices',
        mode: 'bucket',
        rounds: 5,
      );
      final keys = BankValidator.computeExpectedKeys(
        bankType: BankType.choicesBucket,
        meta: meta,
      );
      expect(keys.length, equals(6));
    });

    test('duel fixedRounds R=3 => 10 keys', () {
      final meta = BankImportMeta(
        preset: 'duel',
        mode: 'bucket',
        rounds: 3,
      );
      final keys = BankValidator.computeExpectedKeys(
        bankType: BankType.duelFixedRounds,
        meta: meta,
      );
      expect(keys.length, equals(10));
      // Verify key format: "R|S-P"
      expect(keys, contains('3|0-0'));
      expect(keys, contains('3|3-0'));
      expect(keys, contains('3|0-3'));
      expect(keys, contains('3|1-1'));
    });

    test('duel fixedRounds R=1 => 3 keys', () {
      final meta = BankImportMeta(
        preset: 'duel',
        mode: 'bucket',
        rounds: 1,
      );
      final keys = BankValidator.computeExpectedKeys(
        bankType: BankType.duelFixedRounds,
        meta: meta,
      );
      expect(keys.length, equals(3));
      expect(keys, containsAll(['1|0-0', '1|0-1', '1|1-0']));
    });

    test('duel firstTo T=3 => 6 keys', () {
      final meta = BankImportMeta(
        preset: 'duel',
        mode: 'bucket',
        targetScore: 3,
      );
      final keys = BankValidator.computeExpectedKeys(
        bankType: BankType.duelFirstTo,
        meta: meta,
      );
      expect(keys.length, equals(6));
      expect(keys, containsAll([
        'FT3_S_3-0', 'FT3_S_3-1', 'FT3_S_3-2',
        'FT3_P_3-0', 'FT3_P_3-1', 'FT3_P_3-2',
      ]));
    });

    test('duel firstTo T=2 => 4 keys', () {
      final meta = BankImportMeta(
        preset: 'duel',
        mode: 'bucket',
        targetScore: 2,
      );
      final keys = BankValidator.computeExpectedKeys(
        bankType: BankType.duelFirstTo,
        meta: meta,
      );
      expect(keys.length, equals(4));
    });

    test('freewheel => 6 keys', () {
      final meta = BankImportMeta(preset: 'freewheel', mode: 'bucket');
      final keys = BankValidator.computeExpectedKeys(
        bankType: BankType.freewheel,
        meta: meta,
        freewheelObjects: ['Pièce', 'Clé', 'Dé'],
      );
      expect(keys.length, equals(6));
      expect(keys, contains('TAKE:Pièce|GIVE:Clé|TABLE:Dé'));
      expect(keys, contains('TAKE:Dé|GIVE:Clé|TABLE:Pièce'));
    });
  });

  // ========== VALIDATION ==========

  group('validate', () {
    test('invalid JSON returns error', () {
      final result = BankValidator.validate(
        jsonString: 'not json',
        expectedBankType: BankType.choicesBucket,
      );
      expect(result.isValid, isFalse);
      expect(result.errors, contains('Invalid JSON format'));
    });

    test('missing meta/entries returns error', () {
      final result = BankValidator.validate(
        jsonString: '{"foo": "bar"}',
        expectedBankType: BankType.choicesBucket,
      );
      expect(result.isValid, isFalse);
      expect(result.errors.first, contains('meta'));
    });

    test('wrong preset returns error', () {
      final json = jsonEncode({
        'meta': {'preset': 'duel', 'mode': 'bucket', 'rounds': 3},
        'entries': {},
      });
      final result = BankValidator.validate(
        jsonString: json,
        expectedBankType: BankType.choicesBucket,
      );
      expect(result.isValid, isFalse);
      expect(result.errors.first, contains('preset'));
    });

    test('wrong mode returns error', () {
      final json = jsonEncode({
        'meta': {'preset': 'choices', 'mode': 'exact_sequence', 'rounds': 3, 'options': ['A', 'B']},
        'entries': {},
      });
      final result = BankValidator.validate(
        jsonString: json,
        expectedBankType: BankType.choicesBucket,
      );
      expect(result.isValid, isFalse);
      expect(result.errors.first, contains('mode'));
    });

    test('valid choices bucket R=3', () {
      final entries = <String, String>{};
      for (int i = 0; i <= 3; i++) {
        entries['H$i'] = 'Text for H$i';
      }
      final json = jsonEncode({
        'meta': {'preset': 'choices', 'mode': 'bucket', 'rounds': 3},
        'entries': entries,
      });
      final result = BankValidator.validate(
        jsonString: json,
        expectedBankType: BankType.choicesBucket,
      );
      expect(result.isValid, isTrue);
      expect(result.expectedCount, equals(4));
      expect(result.foundCount, equals(4));
      expect(result.entries, isNotNull);
      expect(result.previewSamples.length, equals(3));
    });

    test('valid choices exact_sequence N=2 R=3', () {
      final entries = <String, String>{};
      for (final k in ['111','112','121','122','211','212','221','222']) {
        entries[k] = 'Text for $k';
      }
      final json = jsonEncode({
        'meta': {
          'preset': 'choices',
          'mode': 'exact_sequence',
          'rounds': 3,
          'options': ['Gauche', 'Droite'],
        },
        'entries': entries,
      });
      final result = BankValidator.validate(
        jsonString: json,
        expectedBankType: BankType.choicesExactSequence,
      );
      expect(result.isValid, isTrue);
      expect(result.expectedCount, equals(8));
      expect(result.foundCount, equals(8));
    });

    test('valid duel fixedRounds R=3', () {
      final meta = BankImportMeta(preset: 'duel', mode: 'bucket', rounds: 3);
      final expectedKeys = BankValidator.computeExpectedKeys(
        bankType: BankType.duelFixedRounds,
        meta: meta,
      );
      final entries = <String, String>{};
      for (final k in expectedKeys) {
        entries[k] = 'Text for $k';
      }
      final json = jsonEncode({
        'meta': {'preset': 'duel', 'mode': 'bucket', 'rounds': 3},
        'entries': entries,
      });
      final result = BankValidator.validate(
        jsonString: json,
        expectedBankType: BankType.duelFixedRounds,
      );
      expect(result.isValid, isTrue);
      expect(result.expectedCount, equals(10));
      expect(result.foundCount, equals(10));
    });

    test('valid duel firstTo T=3', () {
      final entries = <String, String>{};
      for (int i = 0; i < 3; i++) {
        entries['FT3_S_3-$i'] = 'Spectator wins, loser $i';
        entries['FT3_P_3-$i'] = 'Performer wins, loser $i';
      }
      final json = jsonEncode({
        'meta': {'preset': 'duel', 'mode': 'bucket', 'targetScore': 3},
        'entries': entries,
      });
      final result = BankValidator.validate(
        jsonString: json,
        expectedBankType: BankType.duelFirstTo,
      );
      expect(result.isValid, isTrue);
      expect(result.expectedCount, equals(6));
      expect(result.foundCount, equals(6));
    });

    test('missing keys detected', () {
      final entries = <String, String>{
        'H0': 'Text 0',
        'H1': 'Text 1',
        // Missing H2 and H3
      };
      final json = jsonEncode({
        'meta': {'preset': 'choices', 'mode': 'bucket', 'rounds': 3},
        'entries': entries,
      });
      final result = BankValidator.validate(
        jsonString: json,
        expectedBankType: BankType.choicesBucket,
      );
      expect(result.isValid, isFalse);
      expect(result.missingKeys, containsAll(['H2', 'H3']));
      expect(result.entries, isNull);
    });

    test('extra keys detected', () {
      final entries = <String, String>{
        'H0': 'Text 0',
        'H1': 'Text 1',
        'H2': 'Text 2',
        'H3': 'Text 3',
        'H4': 'Extra key',
      };
      final json = jsonEncode({
        'meta': {'preset': 'choices', 'mode': 'bucket', 'rounds': 3},
        'entries': entries,
      });
      final result = BankValidator.validate(
        jsonString: json,
        expectedBankType: BankType.choicesBucket,
      );
      expect(result.isValid, isFalse);
      expect(result.extraKeys, contains('H4'));
    });

    test('empty values detected', () {
      final entries = <String, String>{
        'H0': 'Text 0',
        'H1': '',
        'H2': 'Text 2',
        'H3': '   ',
      };
      final json = jsonEncode({
        'meta': {'preset': 'choices', 'mode': 'bucket', 'rounds': 3},
        'entries': entries,
      });
      final result = BankValidator.validate(
        jsonString: json,
        expectedBankType: BankType.choicesBucket,
      );
      expect(result.isValid, isFalse);
      expect(result.errors.any((e) => e.contains('Empty values')), isTrue);
    });

    test('preview samples capped at 3', () {
      final entries = <String, String>{};
      for (final k in ['111','112','121','122','211','212','221','222']) {
        entries[k] = 'Text for $k';
      }
      final json = jsonEncode({
        'meta': {
          'preset': 'choices',
          'mode': 'exact_sequence',
          'rounds': 3,
          'options': ['A', 'B'],
        },
        'entries': entries,
      });
      final result = BankValidator.validate(
        jsonString: json,
        expectedBankType: BankType.choicesExactSequence,
      );
      expect(result.previewSamples.length, equals(3));
    });
  });

  // ========== META SERIALIZATION ==========

  group('BankImportMeta', () {
    test('round-trip toJson/fromJson', () {
      final meta = BankImportMeta(
        preset: 'choices',
        mode: 'bucket',
        language: 'fr',
        style: 'direct',
        rounds: 3,
        options: ['Gauche', 'Droite'],
      );
      final json = meta.toJson();
      final restored = BankImportMeta.fromJson(json);
      expect(restored.preset, equals('choices'));
      expect(restored.mode, equals('bucket'));
      expect(restored.language, equals('fr'));
      expect(restored.style, equals('direct'));
      expect(restored.rounds, equals(3));
      expect(restored.options, equals(['Gauche', 'Droite']));
    });
  });

  // ========== PROMPT GENERATION ==========

  group('generatePrompt', () {
    test('choices bucket prompt contains expected keys', () {
      final prompt = BankValidator.generatePrompt(
        bankType: BankType.choicesBucket,
        languageCode: 'fr',
        rounds: 3,
      );
      expect(prompt, contains('"H0"'));
      expect(prompt, contains('"H3"'));
      expect(prompt, contains('No missing keys'));
    });

    test('duel firstTo prompt contains expected keys', () {
      final prompt = BankValidator.generatePrompt(
        bankType: BankType.duelFirstTo,
        languageCode: 'en',
        targetScore: 3,
      );
      expect(prompt, contains('"FT3_S_3-0"'));
      expect(prompt, contains('"FT3_P_3-2"'));
      expect(prompt, contains('One entry per key'));
    });

    test('duel fixedRounds prompt contains expected keys', () {
      final prompt = BankValidator.generatePrompt(
        bankType: BankType.duelFixedRounds,
        languageCode: 'fr',
        rounds: 3,
      );
      expect(prompt, contains('"3|0-0"'));
      expect(prompt, contains('"3|3-0"'));
    });

    test('freewheel prompt contains object keys', () {
      final prompt = BankValidator.generatePrompt(
        bankType: BankType.freewheel,
        languageCode: 'fr',
        freewheelObjects: ['Pièce', 'Clé', 'Dé'],
      );
      expect(prompt, contains('TAKE:'));
      expect(prompt, contains('GIVE:'));
      expect(prompt, contains('TABLE:'));
    });
  });

  // ========== COHERENCE CHECKS ==========

  group('coherence checks', () {
    test('choicesExactSequence requires options', () {
      final json = jsonEncode({
        'meta': {'preset': 'choices', 'mode': 'exact_sequence', 'rounds': 3},
        'entries': {},
      });
      final result = BankValidator.validate(
        jsonString: json,
        expectedBankType: BankType.choicesExactSequence,
      );
      expect(result.isValid, isFalse);
      expect(result.errors.first, contains('options'));
    });

    test('duelFirstTo requires targetScore', () {
      final json = jsonEncode({
        'meta': {'preset': 'duel', 'mode': 'bucket'},
        'entries': {},
      });
      final result = BankValidator.validate(
        jsonString: json,
        expectedBankType: BankType.duelFirstTo,
      );
      expect(result.isValid, isFalse);
      expect(result.errors.first, contains('targetScore'));
    });

    test('duelFixedRounds requires rounds', () {
      final json = jsonEncode({
        'meta': {'preset': 'duel', 'mode': 'bucket'},
        'entries': {},
      });
      final result = BankValidator.validate(
        jsonString: json,
        expectedBankType: BankType.duelFixedRounds,
      );
      expect(result.isValid, isFalse);
      expect(result.errors.first, contains('rounds'));
    });

    test('choicesBucket requires rounds', () {
      final json = jsonEncode({
        'meta': {'preset': 'choices', 'mode': 'bucket'},
        'entries': {},
      });
      final result = BankValidator.validate(
        jsonString: json,
        expectedBankType: BankType.choicesBucket,
      );
      expect(result.isValid, isFalse);
      expect(result.errors.first, contains('rounds'));
    });

    test('freewheel requires preset freewheel', () {
      final json = jsonEncode({
        'meta': {'preset': 'choices', 'mode': 'bucket'},
        'entries': {},
      });
      final result = BankValidator.validate(
        jsonString: json,
        expectedBankType: BankType.freewheel,
      );
      expect(result.isValid, isFalse);
      expect(result.errors.first, contains('preset'));
    });
  });
}
