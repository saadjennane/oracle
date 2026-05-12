import 'package:flutter_test/flutter_test.dart';
import 'package:oracle_poc/models/free_will_config.dart';
import 'package:oracle_poc/engine/free_will_bank_fr.dart';
import 'package:oracle_poc/engine/free_will_bank_en.dart';
import 'package:oracle_poc/inputs/free_will_input_state.dart';
import 'package:oracle_poc/models/stealth_input_method.dart';

void main() {
  const objects = ['le téléphone', 'la clé', 'la pièce'];

  group('FREE_WILL - All 6 permutations produce correct revelation', () {
    // 6 permutations of (take, give, table) from 3 objects
    final permutations = [
      (take: objects[0], give: objects[1], table: objects[2]),
      (take: objects[0], give: objects[2], table: objects[1]),
      (take: objects[1], give: objects[0], table: objects[2]),
      (take: objects[1], give: objects[2], table: objects[0]),
      (take: objects[2], give: objects[0], table: objects[1]),
      (take: objects[2], give: objects[1], table: objects[0]),
    ];

    for (int i = 0; i < permutations.length; i++) {
      final p = permutations[i];
      test('FR permutation $i: take=${p.take}, give=${p.give}, table=${p.table}', () {
        final narrative = FreeWillBankGeneratorFR.generate(
          takeObject: p.take,
          giveObject: p.give,
          tableObject: p.table,
          canonicalObjects: objects,
          swapCount: 0,
          suggestChangeOfMind: false,
          seed: 42,
        );

        expect(narrative, isNotEmpty);
        // Reveal line must contain all 3 objects
        expect(narrative, contains(p.take));
        expect(narrative, contains(p.give));
        expect(narrative, contains(p.table));
      });

      test('EN permutation $i: take=${p.take}, give=${p.give}, table=${p.table}', () {
        final narrative = FreeWillBankGeneratorEN.generate(
          takeObject: p.take,
          giveObject: p.give,
          tableObject: p.table,
          canonicalObjects: objects,
          swapCount: 0,
          suggestChangeOfMind: false,
          seed: 42,
        );

        expect(narrative, isNotEmpty);
        expect(narrative, contains(p.take));
        expect(narrative, contains(p.give));
        expect(narrative, contains(p.table));
      });
    }
  });

  group('FREE_WILL - changeMindLine when swapCount > 0', () {
    test('FR: swapCount > 0 injects changeMindLine', () {
      final narrative = FreeWillBankGeneratorFR.generate(
        takeObject: objects[0],
        giveObject: objects[1],
        tableObject: objects[2],
        canonicalObjects: objects,
        swapCount: 2,
        suggestChangeOfMind: true,
        seed: 42,
      );

      // Must contain one of the changeMindLines
      final hasChangeMind = changeMindLinesFR.any((line) => narrative.contains(line));
      expect(hasChangeMind, isTrue, reason: 'Should contain a changeMindLine when swapCount > 0');
    });

    test('EN: swapCount > 0 injects changeMindLine', () {
      final narrative = FreeWillBankGeneratorEN.generate(
        takeObject: objects[0],
        giveObject: objects[1],
        tableObject: objects[2],
        canonicalObjects: objects,
        swapCount: 2,
        suggestChangeOfMind: true,
        seed: 42,
      );

      final hasChangeMind = changeMindLinesEN.any((line) => narrative.contains(line));
      expect(hasChangeMind, isTrue, reason: 'Should contain a changeMindLine when swapCount > 0');
    });

    test('FR: custom changeMindText is used when provided', () {
      const customText = 'Tu as changé d\'avis, comme prévu.';
      final narrative = FreeWillBankGeneratorFR.generate(
        takeObject: objects[0],
        giveObject: objects[1],
        tableObject: objects[2],
        canonicalObjects: objects,
        swapCount: 1,
        suggestChangeOfMind: true,
        changeMindText: customText,
        seed: 42,
      );

      expect(narrative, contains(customText));
    });
  });

  group('FREE_WILL - noChangeMindLine when swapCount == 0 + suggestChangeOfMind ON', () {
    test('FR: swapCount == 0, suggestChangeOfMind ON → noChangeMindLine', () {
      final narrative = FreeWillBankGeneratorFR.generate(
        takeObject: objects[0],
        giveObject: objects[1],
        tableObject: objects[2],
        canonicalObjects: objects,
        swapCount: 0,
        suggestChangeOfMind: true,
        seed: 42,
      );

      final hasNoChangeMind = noChangeMindLinesFR.any((line) => narrative.contains(line));
      expect(hasNoChangeMind, isTrue, reason: 'Should contain a noChangeMindLine when suggestChangeOfMind ON and swapCount == 0');
    });

    test('EN: swapCount == 0, suggestChangeOfMind ON → noChangeMindLine', () {
      final narrative = FreeWillBankGeneratorEN.generate(
        takeObject: objects[0],
        giveObject: objects[1],
        tableObject: objects[2],
        canonicalObjects: objects,
        swapCount: 0,
        suggestChangeOfMind: true,
        seed: 42,
      );

      final hasNoChangeMind = noChangeMindLinesEN.any((line) => narrative.contains(line));
      expect(hasNoChangeMind, isTrue, reason: 'Should contain a noChangeMindLine when suggestChangeOfMind ON and swapCount == 0');
    });

    test('FR: custom noChangeMindText is used when provided', () {
      const customText = 'Tu n\'as pas changé d\'avis. Normal.';
      final narrative = FreeWillBankGeneratorFR.generate(
        takeObject: objects[0],
        giveObject: objects[1],
        tableObject: objects[2],
        canonicalObjects: objects,
        swapCount: 0,
        suggestChangeOfMind: true,
        noChangeMindText: customText,
        seed: 42,
      );

      expect(narrative, contains(customText));
    });
  });

  group('FREE_WILL - suggestChangeOfMind OFF, swapCount == 0 → no extra line', () {
    test('FR: no changeMind/noChangeMind line injected', () {
      final narrative = FreeWillBankGeneratorFR.generate(
        takeObject: objects[0],
        giveObject: objects[1],
        tableObject: objects[2],
        canonicalObjects: objects,
        swapCount: 0,
        suggestChangeOfMind: false,
        seed: 42,
      );

      // Should NOT contain any changeMind or noChangeMind lines
      for (final line in changeMindLinesFR) {
        expect(narrative, isNot(contains(line)));
      }
      for (final line in noChangeMindLinesFR) {
        expect(narrative, isNot(contains(line)));
      }

      // Without the optional line, narrative should have exactly 4 lines
      // (setup, reveal, freeWill, closer)
      final lines = narrative.split('\n');
      expect(lines.length, equals(4), reason: 'Should have 4 lines (no changeMind line)');
    });

    test('EN: no changeMind/noChangeMind line injected', () {
      final narrative = FreeWillBankGeneratorEN.generate(
        takeObject: objects[0],
        giveObject: objects[1],
        tableObject: objects[2],
        canonicalObjects: objects,
        swapCount: 0,
        suggestChangeOfMind: false,
        seed: 42,
      );

      for (final line in changeMindLinesEN) {
        expect(narrative, isNot(contains(line)));
      }
      for (final line in noChangeMindLinesEN) {
        expect(narrative, isNot(contains(line)));
      }

      final lines = narrative.split('\n');
      expect(lines.length, equals(4));
    });

    test('FR: with suggestChangeOfMind ON, narrative has 5 lines', () {
      final narrative = FreeWillBankGeneratorFR.generate(
        takeObject: objects[0],
        giveObject: objects[1],
        tableObject: objects[2],
        canonicalObjects: objects,
        swapCount: 0,
        suggestChangeOfMind: true,
        seed: 42,
      );

      final lines = narrative.split('\n');
      expect(lines.length, equals(5), reason: 'Should have 5 lines (with noChangeMind line)');
    });
  });

  group('FREE_WILL - Input state machine', () {
    test('byAction: captures 2 inputs, deduces 3rd, allows swaps', () {
      final state = FreeWillInputState(
        inputMethod: FreeWillInputMethod.volume,
      );

      expect(state.phase, FreeWillPhaseState.capturing);

      // First input
      var result = state.handleInput(FreeWillInput.input1);
      expect(result, FreeWillInputResult.captured);
      expect(state.phase, FreeWillPhaseState.capturing);

      // Duplicate ignored
      result = state.handleInput(FreeWillInput.input1);
      expect(result, FreeWillInputResult.duplicateIgnored);

      // Second input → transitions to swapping
      result = state.handleInput(FreeWillInput.input2);
      expect(result, FreeWillInputResult.capturedAndTransitioned);
      expect(state.phase, FreeWillPhaseState.swapping);
      expect(state.deducedInput, FreeWillInput.input3);

      // Initial slots: [1, 2, 3] (captured1, captured2, deduced)
      expect(state.slots, [1, 2, 3]);

      // Swap: input 1 keeps object 1 (value 1, at pos 0), swaps the other two
      result = state.handleInput(FreeWillInput.input1);
      expect(result, FreeWillInputResult.swapped);
      expect(state.slots, [1, 3, 2]);
      expect(state.swapCount, 1);

      // Lock
      expect(state.lock(), isTrue);
      expect(state.phase, FreeWillPhaseState.locked);

      // Input ignored when locked
      result = state.handleInput(FreeWillInput.input1);
      expect(result, FreeWillInputResult.ignored);

      // Reveal
      expect(state.reveal(), isTrue);
      expect(state.phase, FreeWillPhaseState.revealed);
    });

    test('all 6 capture permutations produce valid final slots', () {
      final captureOrders = [
        [FreeWillInput.input1, FreeWillInput.input2], // deduced: 3
        [FreeWillInput.input1, FreeWillInput.input3], // deduced: 2
        [FreeWillInput.input2, FreeWillInput.input1], // deduced: 3
        [FreeWillInput.input2, FreeWillInput.input3], // deduced: 1
        [FreeWillInput.input3, FreeWillInput.input1], // deduced: 2
        [FreeWillInput.input3, FreeWillInput.input2], // deduced: 1
      ];

      for (final order in captureOrders) {
        final state = FreeWillInputState(
          inputMethod: FreeWillInputMethod.volume,
        );

        state.handleInput(order[0]);
        state.handleInput(order[1]);

        expect(state.phase, FreeWillPhaseState.swapping);
        // Slots must contain all 3 values
        expect(state.slots.toSet(), {1, 2, 3});
        // First two slots = captured inputs, third = deduced
        expect(state.slots[0], order[0].value);
        expect(state.slots[1], order[1].value);
      }
    });
  });

  group('FREE_WILL - generateWithCustom', () {
    test('FR: uses custom template when provided', () {
      final customTemplates = {
        'TAKE:${objects[0]}|GIVE:${objects[1]}|TABLE:${objects[2]}':
            'Setup custom.\n{TAKE} à toi, {GIVE} à moi, {TABLE} reste.\nLibre arbitre custom.\nCloser custom.',
      };

      final narrative = FreeWillBankGeneratorFR.generateWithCustom(
        takeObject: objects[0],
        giveObject: objects[1],
        tableObject: objects[2],
        canonicalObjects: objects,
        swapCount: 0,
        suggestChangeOfMind: false,
        customTemplates: customTemplates,
        seed: 42,
      );

      expect(narrative, contains('Setup custom.'));
      expect(narrative, contains(objects[0]));
    });

    test('FR: falls back to default when no custom template matches', () {
      final customTemplates = {
        'TAKE:other|GIVE:stuff|TABLE:here': 'Should not appear',
      };

      final narrative = FreeWillBankGeneratorFR.generateWithCustom(
        takeObject: objects[0],
        giveObject: objects[1],
        tableObject: objects[2],
        canonicalObjects: objects,
        swapCount: 0,
        suggestChangeOfMind: false,
        customTemplates: customTemplates,
        seed: 42,
      );

      // Should use default bank, not the custom template
      expect(narrative, isNot(contains('Should not appear')));
      expect(narrative, contains(objects[0]));
    });
  });
}
