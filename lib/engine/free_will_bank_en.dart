/// FREE_WILL Narrative Bank EN
///
/// 6 buckets for the 6 permutations of (TAKE, GIVE, TABLE)
/// Style: English, future tense, teasing, direct
///
/// Placeholders:
/// - {TAKE}: object the spectator takes
/// - {GIVE}: object given to performer
/// - {TABLE}: object left on table

import 'dart:math';

/// Entry for a FREE_WILL narrative bucket
class FreeWillBankEntryEN {
  /// Setup lines (1-3 variants)
  final List<String> setupLines;

  /// Reveal lines with placeholders (1-3 variants)
  final List<String> revealLines;

  /// Free will punch lines (1-3 variants)
  final List<String> freeWillLines;

  /// Closer lines (1-3 variants)
  final List<String> closerLines;

  const FreeWillBankEntryEN({
    required this.setupLines,
    required this.revealLines,
    required this.freeWillLines,
    required this.closerLines,
  });
}

/// Lines for when spectator changed their mind (swapCount > 0)
const List<String> changeMindLinesEN = [
  "At first, you'll think I got it wrong. Then you'll change your mind, as expected.",
  "You'll hesitate, change your mind. Exactly what I was waiting for.",
  "You'll backtrack. That was planned too.",
];

/// Lines for when spectator didn't change their mind but suggestChangeOfMind is ON
const List<String> noChangeMindLinesEN = [
  "I'll offer you a chance to change your mind. You won't take it.",
  "You'll have the choice to change everything. You won't.",
  "I'll give you a chance to reverse it all. You'll refuse.",
];

/// The 6 bucket entries for FREE_WILL (EN)
/// Indexed by permutation (which object gets which role)
const List<FreeWillBankEntryEN> freeWillBankEN = [
  // Permutation 0: canonical order (obj0=take, obj1=give, obj2=table)
  FreeWillBankEntryEN(
    setupLines: [
      "You'll distribute these three objects without realizing it.",
      "Three objects, three fates. You'll decide without knowing.",
      "You think you'll choose freely. Let's see.",
    ],
    revealLines: [
      "You'll take {TAKE}, give me {GIVE}, leave {TABLE} on the table.",
      "{TAKE} for you, {GIVE} for me, {TABLE} stays there.",
      "You'll keep {TAKE}, offer me {GIVE}, abandon {TABLE}.",
    ],
    freeWillLines: [
      "You'll think it was your choice. Perfect.",
      "Free will, they say.",
      "You'll think you decided. That's the point.",
    ],
    closerLines: [
      "In the end, you chose or you just thought you were choosing.",
      "In the end, was it you or was it me.",
      "In the end, who really decided.",
    ],
  ),

  // Permutation 1: (obj0=take, obj2=give, obj1=table)
  FreeWillBankEntryEN(
    setupLines: [
      "You'll distribute these three objects without realizing it.",
      "Three objects in front of you. You'll sort them your way.",
      "You think you'll choose freely. Let's see.",
    ],
    revealLines: [
      "You'll take {TAKE}, give me {GIVE}, leave {TABLE} on the table.",
      "{TAKE} ends up in your hand, {GIVE} in mine, {TABLE} stays.",
      "You'll keep {TAKE}, offer me {GIVE}, forget {TABLE}.",
    ],
    freeWillLines: [
      "You'll think it was your choice. Perfect.",
      "Your free will, my prediction.",
      "You'll think you decided alone. Exactly.",
    ],
    closerLines: [
      "In the end, you chose or you just thought you were choosing.",
      "In the end, free or programmed.",
      "In the end, who was really deciding.",
    ],
  ),

  // Permutation 2: (obj1=take, obj0=give, obj2=table)
  FreeWillBankEntryEN(
    setupLines: [
      "You'll distribute these three objects without realizing it.",
      "Three choices to make. You'll think you're making them yourself.",
      "You think you'll choose freely. Let's find out.",
    ],
    revealLines: [
      "You'll take {TAKE}, give me {GIVE}, leave {TABLE} on the table.",
      "{TAKE} will be for you, {GIVE} for me, {TABLE} forgotten.",
      "You'll grab {TAKE}, hand me {GIVE}, ignore {TABLE}.",
    ],
    freeWillLines: [
      "You'll think it was your choice. Perfect.",
      "Your decision, my anticipation.",
      "You'll think you're in control. Interesting.",
    ],
    closerLines: [
      "In the end, you chose or you just thought you were choosing.",
      "In the end, choice or illusion of choice.",
      "In the end, decision or destination.",
    ],
  ),

  // Permutation 3: (obj1=take, obj2=give, obj0=table)
  FreeWillBankEntryEN(
    setupLines: [
      "You'll distribute these three objects without realizing it.",
      "Three objects, three directions. Your move.",
      "You think you'll choose freely. Let's see.",
    ],
    revealLines: [
      "You'll take {TAKE}, give me {GIVE}, leave {TABLE} on the table.",
      "{TAKE} goes with you, {GIVE} comes to me, {TABLE} doesn't move.",
      "You'll choose {TAKE}, entrust me with {GIVE}, neglect {TABLE}.",
    ],
    freeWillLines: [
      "You'll think it was your choice. Perfect.",
      "Free as a bird, they say.",
      "You'll think you decided everything. Normal.",
    ],
    closerLines: [
      "In the end, you chose or you just thought you were choosing.",
      "In the end, master of your fate or not.",
      "In the end, you'll never really know.",
    ],
  ),

  // Permutation 4: (obj2=take, obj0=give, obj1=table)
  FreeWillBankEntryEN(
    setupLines: [
      "You'll distribute these three objects without realizing it.",
      "Three possibilities. You'll think you're choosing.",
      "You think you'll choose freely. Really.",
    ],
    revealLines: [
      "You'll take {TAKE}, give me {GIVE}, leave {TABLE} on the table.",
      "{TAKE} for you, {GIVE} for me, {TABLE} waits.",
      "You'll seize {TAKE}, grant me {GIVE}, abandon {TABLE}.",
    ],
    freeWillLines: [
      "You'll think it was your choice. Perfect.",
      "Free choice. Or not.",
      "You'll think it's you. Of course.",
    ],
    closerLines: [
      "In the end, you chose or you just thought you were choosing.",
      "In the end, free will or coincidence.",
      "In the end, chance or certainty.",
    ],
  ),

  // Permutation 5: (obj2=take, obj1=give, obj0=table)
  FreeWillBankEntryEN(
    setupLines: [
      "You'll distribute these three objects without realizing it.",
      "Three objects. Three decisions. Your call.",
      "You think you'll choose freely. Maybe.",
    ],
    revealLines: [
      "You'll take {TAKE}, give me {GIVE}, leave {TABLE} on the table.",
      "{TAKE} is yours, {GIVE} is mine, {TABLE} waits.",
      "You'll opt for {TAKE}, hand me {GIVE}, leave behind {TABLE}.",
    ],
    freeWillLines: [
      "You'll think it was your choice. Perfect.",
      "Your choice, my prediction.",
      "You'll think you decided alone. Obviously.",
    ],
    closerLines: [
      "In the end, you chose or you just thought you were choosing.",
      "In the end, will or manipulation.",
      "In the end, who's pulling the strings.",
    ],
  ),
];

/// Generator class for FREE_WILL narratives (English)
class FreeWillBankGeneratorEN {
  /// Generate complete narrative for a FREE_WILL result
  static String generate({
    required String takeObject,
    required String giveObject,
    required String tableObject,
    required List<String> canonicalObjects,
    required int swapCount,
    required bool suggestChangeOfMind,
    String? changeMindText,
    String? noChangeMindText,
    int? seed,
  }) {
    // Determine permutation index
    final permIdx = _getPermutationIndex(
      takeObject: takeObject,
      giveObject: giveObject,
      tableObject: tableObject,
      canonicalObjects: canonicalObjects,
    );

    final entry = freeWillBankEN[permIdx];
    final random = Random(seed ?? DateTime.now().millisecondsSinceEpoch);

    // Select variants deterministically
    final setup = _selectVariant(entry.setupLines, random);
    final reveal = _selectVariant(entry.revealLines, random);
    final freeWill = _selectVariant(entry.freeWillLines, random);
    final closer = _selectVariant(entry.closerLines, random);

    // Build lines
    final lines = <String>[];

    // L1: Setup
    lines.add(setup);

    // L2: Reveal (with placeholder replacement)
    lines.add(_replacePlaceholders(reveal, takeObject, giveObject, tableObject,
        canonicalObjects: canonicalObjects));

    // L3: Free will punch
    lines.add(freeWill);

    // L4: Optional change of mind line
    if (swapCount > 0) {
      lines.add(changeMindText ?? _selectVariant(changeMindLinesEN, random));
    } else if (suggestChangeOfMind) {
      lines.add(noChangeMindText ?? _selectVariant(noChangeMindLinesEN, random));
    }

    // L5: Closer
    lines.add(closer);

    return lines.join('\n');
  }

  /// Generate with custom bank templates (for preset customization).
  /// See FR variant for resolution order — single → six → default.
  static String generateWithCustom({
    required String takeObject,
    required String giveObject,
    required String tableObject,
    required List<String> canonicalObjects,
    required int swapCount,
    required bool suggestChangeOfMind,
    Map<String, String>? customTemplates,
    String? singleTemplate,
    String? changeMindText,
    String? noChangeMindText,
    int? seed,
  }) {
    final random = Random(seed ?? DateTime.now().millisecondsSinceEpoch);

    String appendChangeMindLine(String body) {
      if (swapCount > 0) {
        return '$body\n\n${changeMindText ?? _selectVariant(changeMindLinesEN, random)}';
      } else if (suggestChangeOfMind) {
        return '$body\n\n${noChangeMindText ?? _selectVariant(noChangeMindLinesEN, random)}';
      }
      return body;
    }

    if (singleTemplate != null && singleTemplate.trim().isNotEmpty) {
      final body = _replacePlaceholders(
        singleTemplate,
        takeObject,
        giveObject,
        tableObject,
        canonicalObjects: canonicalObjects,
      );
      return appendChangeMindLine(body);
    }

    if (customTemplates != null && customTemplates.isNotEmpty) {
      final bucketKey = 'TAKE:$takeObject|GIVE:$giveObject|TABLE:$tableObject';
      final customTemplate = customTemplates[bucketKey];
      if (customTemplate != null && customTemplate.trim().isNotEmpty) {
        final body = _replacePlaceholders(
          customTemplate,
          takeObject,
          giveObject,
          tableObject,
          canonicalObjects: canonicalObjects,
        );
        return appendChangeMindLine(body);
      }
    }

    return generate(
      takeObject: takeObject,
      giveObject: giveObject,
      tableObject: tableObject,
      canonicalObjects: canonicalObjects,
      swapCount: swapCount,
      suggestChangeOfMind: suggestChangeOfMind,
      changeMindText: changeMindText,
      noChangeMindText: noChangeMindText,
      seed: seed,
    );
  }

  /// Fallback minimal narrative if bank not found
  static String generateFallback({
    required String takeObject,
    required String giveObject,
    required String tableObject,
  }) {
    return '''You'll take $takeObject, give me $giveObject, leave $tableObject on the table.
In the end, you chose or you just thought you were choosing.''';
  }

  static String _selectVariant(List<String> variants, Random random) {
    if (variants.isEmpty) return '';
    if (variants.length == 1) return variants[0];
    return variants[random.nextInt(variants.length)];
  }

  static String _replacePlaceholders(
    String template,
    String takeObject,
    String giveObject,
    String tableObject, {
    List<String>? canonicalObjects,
  }) {
    var result = template
        .replaceAll('{TAKE}', takeObject)
        .replaceAll('{GIVE}', giveObject)
        .replaceAll('{TABLE}', tableObject);
    if (canonicalObjects != null) {
      for (int i = 0; i < canonicalObjects.length && i < 3; i++) {
        result = result.replaceAll('((Label${i + 1}))', canonicalObjects[i]);
      }
    }
    return result;
  }

  static int _getPermutationIndex({
    required String takeObject,
    required String giveObject,
    required String tableObject,
    required List<String> canonicalObjects,
  }) {
    final takeIdx = canonicalObjects.indexOf(takeObject);
    final giveIdx = canonicalObjects.indexOf(giveObject);
    final tableIdx = canonicalObjects.indexOf(tableObject);

    // Handle case where objects aren't in canonical list
    if (takeIdx == -1 || giveIdx == -1 || tableIdx == -1) {
      return 0;
    }

    // Map to permutation index (0-5)
    if (takeIdx == 0 && giveIdx == 1 && tableIdx == 2) return 0;
    if (takeIdx == 0 && giveIdx == 2 && tableIdx == 1) return 1;
    if (takeIdx == 1 && giveIdx == 0 && tableIdx == 2) return 2;
    if (takeIdx == 1 && giveIdx == 2 && tableIdx == 0) return 3;
    if (takeIdx == 2 && giveIdx == 0 && tableIdx == 1) return 4;
    if (takeIdx == 2 && giveIdx == 1 && tableIdx == 0) return 5;

    return 0;
  }

  /// Get all 6 bucket keys for given objects
  static List<String> generateAllBucketKeys(List<String> objects) {
    if (objects.length != 3) return [];

    final permutations = [
      [0, 1, 2], [0, 2, 1], [1, 0, 2], [1, 2, 0], [2, 0, 1], [2, 1, 0]
    ];

    return permutations.map((p) {
      return 'TAKE:${objects[p[0]]}|GIVE:${objects[p[1]]}|TABLE:${objects[p[2]]}';
    }).toList();
  }
}
