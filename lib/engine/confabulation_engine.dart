/// Confabulation Engine
///
/// Handles text rendering, slot extraction, and preset validation
/// for the Confabulation mode.

import '../models/confabulation_preset.dart';

/// Validation result for a confabulation preset
class ConfabValidationResult {
  final bool isValid;
  final List<String> errors;
  final List<String> warnings;

  const ConfabValidationResult({
    required this.isValid,
    required this.errors,
    required this.warnings,
  });

  factory ConfabValidationResult.valid({List<String>? warnings}) {
    return ConfabValidationResult(
      isValid: true,
      errors: [],
      warnings: warnings ?? [],
    );
  }

  factory ConfabValidationResult.invalid(List<String> errors, {List<String>? warnings}) {
    return ConfabValidationResult(
      isValid: false,
      errors: errors,
      warnings: warnings ?? [],
    );
  }
}

/// Engine for confabulation preset operations
class ConfabulationEngine {
  /// Regex pattern for slot tokens: {{slot:id}}
  static final RegExp _slotTokenPattern = RegExp(r'\{\{slot:([a-zA-Z0-9_-]+)\}\}');

  /// Constants
  static const int minSlots = 1;
  static const int maxSlots = 10;
  static const int minOptionsPerSlot = 2;
  static const int maxOptionsPerSlot = 999; // No practical limit

  /// Extract all slot IDs used in the template
  static Set<String> extractSlotIdsUsed(String template) {
    final matches = _slotTokenPattern.allMatches(template);
    return matches.map((m) => m.group(1)!).toSet();
  }

  /// Get the order of slots as they appear in the template
  static List<String> getSlotOrderInTemplate(String template) {
    final matches = _slotTokenPattern.allMatches(template);
    final seen = <String>{};
    final order = <String>[];
    for (final match in matches) {
      final id = match.group(1)!;
      if (!seen.contains(id)) {
        seen.add(id);
        order.add(id);
      }
    }
    return order;
  }

  /// Render preview text (replace tokens with first option)
  static String renderPreview(ConfabulationPreset preset) {
    var result = preset.textTemplate;
    for (final slot in preset.slots) {
      if (slot.options.isNotEmpty) {
        result = result.replaceAll(slot.token, slot.options[0]);
      }
    }
    return result;
  }

  /// Render final text with chosen options
  static String renderFinal(
    ConfabulationPreset preset,
    Map<String, int> chosenIndexBySlotId,
  ) {
    var result = preset.textTemplate;
    for (final slot in preset.slots) {
      final chosenIndex = chosenIndexBySlotId[slot.id] ?? 0;
      final safeIndex = chosenIndex.clamp(0, slot.options.length - 1);
      result = result.replaceAll(slot.token, slot.options[safeIndex]);
    }
    return result;
  }

  /// Get the chosen labels for debug display
  static Map<String, String> getChosenLabels(
    ConfabulationPreset preset,
    Map<String, int> chosenIndexBySlotId,
  ) {
    final labels = <String, String>{};
    for (final slot in preset.slots) {
      final chosenIndex = chosenIndexBySlotId[slot.id] ?? 0;
      final safeIndex = chosenIndex.clamp(0, slot.options.length - 1);
      labels[slot.id] = slot.options[safeIndex];
    }
    return labels;
  }

  /// Validate a confabulation preset
  static ConfabValidationResult validatePreset(ConfabulationPreset preset) {
    final errors = <String>[];
    final warnings = <String>[];

    // Name validation
    if (preset.name.trim().isEmpty) {
      errors.add('Preset name cannot be empty');
    }

    // Slots count validation.
    // Exception: a preset with zero slots is allowed when the template relies
    // only on a standalone API/acrostic variable that provides its own input
    // (ACROSTIC_URL, INJECT, ACROSTIC_INJECT, ELIPS_*,
    // ACROSTIC_ELIPS_*, HIGHSCORE_*, AITransform*). Those produce content
    // without requiring any per-slot selection.
    final standaloneVariables = [
      '((ACROSTIC_URL))',
      '((INJECT))', '((ACROSTIC_INJECT))', '((AITransformInject))',
      '((ELIPS_ARTIST))', '((ELIPS_SONG))', '((ELIPS_WORD))',
      '((ACROSTIC_ELIPS_ARTIST))', '((ACROSTIC_ELIPS_SONG))', '((ACROSTIC_ELIPS_WORD))',
      '((AITransformElipsArtist))', '((AITransformElipsSong))', '((AITransformElipsWord))',
      '((HIGHSCORE_SCORE))', '((HIGHSCORE_SCORE+1))', '((HIGHSCORE_RANKING))',
    ];
    final hasStandalone = standaloneVariables.any((v) => preset.textTemplate.contains(v));
    if (preset.slots.isEmpty) {
      if (!hasStandalone) {
        errors.add('At least $minSlots slot is required (or use a standalone variable like ((ACROSTIC_URL)))');
      }
    } else if (preset.slots.length > maxSlots) {
      errors.add('Maximum $maxSlots slots allowed');
    }

    // Validate each slot
    final slotIds = <String>{};
    for (final slot in preset.slots) {
      // Check for duplicate IDs
      if (slotIds.contains(slot.id)) {
        errors.add('Duplicate slot ID: ${slot.id}');
      }
      slotIds.add(slot.id);

      // Label validation
      if (slot.label.trim().isEmpty) {
        errors.add('Slot label cannot be empty');
      }

      // Options count validation
      if (slot.options.length < minOptionsPerSlot) {
        errors.add('Slot "${slot.label}" must have at least $minOptionsPerSlot options');
      } else if (slot.options.length > maxOptionsPerSlot) {
        errors.add('Slot "${slot.label}" can have at most $maxOptionsPerSlot options');
      }

      // Options content validation
      for (int i = 0; i < slot.options.length; i++) {
        if (slot.options[i].trim().isEmpty) {
          errors.add('Slot "${slot.label}" has empty option at position ${i + 1}');
        }
      }

      // Options uniqueness validation
      final uniqueOptions = slot.options.map((o) => o.trim().toLowerCase()).toSet();
      if (uniqueOptions.length != slot.options.length) {
        errors.add('Slot "${slot.label}" has duplicate options');
      }
    }

    // Template validation
    if (preset.textTemplate.trim().isEmpty) {
      errors.add('Text template cannot be empty');
    }

    // Check that all used tokens exist
    final usedSlotIds = extractSlotIdsUsed(preset.textTemplate);
    final definedSlotIds = preset.slots.map((s) => s.id).toSet();

    for (final usedId in usedSlotIds) {
      if (!definedSlotIds.contains(usedId)) {
        errors.add('Token {{slot:$usedId}} references undefined slot');
      }
    }

    // Warning: slots defined but never used
    for (final slot in preset.slots) {
      if (!usedSlotIds.contains(slot.id)) {
        warnings.add('Slot "${slot.label}" is defined but never used in template');
      }
    }

    return errors.isEmpty
        ? ConfabValidationResult.valid(warnings: warnings)
        : ConfabValidationResult.invalid(errors, warnings: warnings);
  }

  /// Generate debug logs for a confabulation run
  static String generateDebugLogs({
    required ConfabulationPreset preset,
    required Map<String, int> chosenIndexBySlotId,
    required String finalText,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('=== CONFABULATION DEBUG LOGS ===');
    buffer.writeln('');
    buffer.writeln('--- PRESET INFO ---');
    buffer.writeln('name:         ${preset.name}');
    buffer.writeln('inputMethod:  ${preset.inputMethod.displayName}');
    buffer.writeln('slotsCount:   ${preset.slots.length}');
    buffer.writeln('');
    buffer.writeln('--- SLOTS ---');

    final slotOrder = getSlotOrderInTemplate(preset.textTemplate);
    for (int i = 0; i < slotOrder.length; i++) {
      final slotId = slotOrder[i];
      final slot = preset.getSlotById(slotId);
      if (slot != null) {
        final chosenIndex = chosenIndexBySlotId[slotId] ?? 0;
        final chosenOption = slot.options[chosenIndex.clamp(0, slot.options.length - 1)];
        buffer.writeln('[$i] ${slot.label}:');
        buffer.writeln('    options: ${slot.options.join(", ")}');
        buffer.writeln('    chosen:  [$chosenIndex] $chosenOption');
      }
    }

    buffer.writeln('');
    buffer.writeln('--- CHOSEN INDICES ---');
    for (final entry in chosenIndexBySlotId.entries) {
      final slot = preset.getSlotById(entry.key);
      final label = slot?.label ?? entry.key;
      buffer.writeln('$label: ${entry.value}');
    }

    buffer.writeln('');
    buffer.writeln('--- FINAL TEXT ---');
    buffer.writeln(finalText);

    return buffer.toString();
  }
}
