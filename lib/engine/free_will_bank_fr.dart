/// FREE_WILL Narrative Bank FR
///
/// 6 buckets for the 6 permutations of (TAKE, GIVE, TABLE)
/// Style: French, future tense, teasing, direct
/// No arrows, no quotes, no words: ecrit/valide/schema/alternance
///
/// Placeholders:
/// - {TAKE}: object the spectator takes
/// - {GIVE}: object given to performer
/// - {TABLE}: object left on table

import 'dart:math';

/// Entry for a FREE_WILL narrative bucket
class FreeWillBankEntry {
  /// Setup lines (1-3 variants)
  final List<String> setupLines;

  /// Reveal lines with placeholders (1-3 variants)
  final List<String> revealLines;

  /// Free will punch lines (1-3 variants)
  final List<String> freeWillLines;

  /// Closer lines (1-3 variants)
  final List<String> closerLines;

  const FreeWillBankEntry({
    required this.setupLines,
    required this.revealLines,
    required this.freeWillLines,
    required this.closerLines,
  });
}

/// Lines for when spectator changed their mind (swapCount > 0)
const List<String> changeMindLinesFR = [
  "Au debut, tu vas croire que je me suis trompe. Puis tu vas changer d'avis, comme prevu.",
  "Tu vas hesiter, changer d'avis. Exactement ce que j'attendais.",
  "Tu vas revenir en arriere. Ca aussi, c'etait prevu.",
];

/// Lines for when spectator didn't change their mind but suggestChangeOfMind is ON
const List<String> noChangeMindLinesFR = [
  "Je vais te proposer de changer d'avis. Tu ne vas pas le faire.",
  "Tu auras le choix de tout changer. Tu ne le feras pas.",
  "Je vais t'offrir une chance de tout inverser. Tu vas refuser.",
];

/// The 6 bucket entries for FREE_WILL (FR)
/// Indexed by permutation (which object gets which role)
const List<FreeWillBankEntry> freeWillBankFR = [
  // Permutation 0: canonical order (obj0=take, obj1=give, obj2=table)
  FreeWillBankEntry(
    setupLines: [
      "Tu vas repartir ces trois objets sans t'en rendre compte.",
      "Trois objets, trois destins. Tu vas decider sans savoir.",
      "Tu crois que tu vas choisir librement. On va voir.",
    ],
    revealLines: [
      "Tu vas prendre {TAKE}, me donner {GIVE}, laisser {TABLE} sur la table.",
      "{TAKE} pour toi, {GIVE} pour moi, {TABLE} reste la.",
      "Tu vas garder {TAKE}, m'offrir {GIVE}, abandonner {TABLE}.",
    ],
    freeWillLines: [
      "Tu vas croire que c'etait ton choix. Parfait.",
      "Libre arbitre, qu'ils disent.",
      "Tu vas penser avoir decide. C'est tout l'interet.",
    ],
    closerLines: [
      "Au final, t'as choisi ou t'as cru choisir.",
      "Au final, c'etait toi ou c'etait moi.",
      "Au final, qui a vraiment decide.",
    ],
  ),

  // Permutation 1: (obj0=take, obj2=give, obj1=table)
  FreeWillBankEntry(
    setupLines: [
      "Tu vas repartir ces trois objets sans t'en rendre compte.",
      "Trois objets devant toi. Tu vas les distribuer a ta facon.",
      "Tu crois que tu vas choisir librement. On va voir.",
    ],
    revealLines: [
      "Tu vas prendre {TAKE}, me donner {GIVE}, laisser {TABLE} sur la table.",
      "{TAKE} finit dans ta main, {GIVE} dans la mienne, {TABLE} reste.",
      "Tu vas garder {TAKE}, m'offrir {GIVE}, oublier {TABLE}.",
    ],
    freeWillLines: [
      "Tu vas croire que c'etait ton choix. Parfait.",
      "Ton libre arbitre, ma prediction.",
      "Tu vas penser avoir decide seul. Exactement.",
    ],
    closerLines: [
      "Au final, t'as choisi ou t'as cru choisir.",
      "Au final, libre ou programme.",
      "Au final, qui decidait vraiment.",
    ],
  ),

  // Permutation 2: (obj1=take, obj0=give, obj2=table)
  FreeWillBankEntry(
    setupLines: [
      "Tu vas repartir ces trois objets sans t'en rendre compte.",
      "Trois choix a faire. Tu vas croire les faire toi-meme.",
      "Tu crois que tu vas choisir librement. Voyons ca.",
    ],
    revealLines: [
      "Tu vas prendre {TAKE}, me donner {GIVE}, laisser {TABLE} sur la table.",
      "{TAKE} sera pour toi, {GIVE} pour moi, {TABLE} oublie.",
      "Tu vas t'emparer de {TAKE}, me ceder {GIVE}, ignorer {TABLE}.",
    ],
    freeWillLines: [
      "Tu vas croire que c'etait ton choix. Parfait.",
      "Ta decision, mon anticipation.",
      "Tu vas penser controler. Interessant.",
    ],
    closerLines: [
      "Au final, t'as choisi ou t'as cru choisir.",
      "Au final, choix ou illusion de choix.",
      "Au final, decision ou destination.",
    ],
  ),

  // Permutation 3: (obj1=take, obj2=give, obj0=table)
  FreeWillBankEntry(
    setupLines: [
      "Tu vas repartir ces trois objets sans t'en rendre compte.",
      "Trois objets, trois directions. A toi de jouer.",
      "Tu crois que tu vas choisir librement. On va voir.",
    ],
    revealLines: [
      "Tu vas prendre {TAKE}, me donner {GIVE}, laisser {TABLE} sur la table.",
      "{TAKE} part avec toi, {GIVE} vient a moi, {TABLE} ne bouge pas.",
      "Tu vas choisir {TAKE}, me confier {GIVE}, negliger {TABLE}.",
    ],
    freeWillLines: [
      "Tu vas croire que c'etait ton choix. Parfait.",
      "Libre comme l'air, qu'on dit.",
      "Tu vas penser avoir tout decide. Normal.",
    ],
    closerLines: [
      "Au final, t'as choisi ou t'as cru choisir.",
      "Au final, maitre de ton destin ou pas.",
      "Au final, tu sauras jamais vraiment.",
    ],
  ),

  // Permutation 4: (obj2=take, obj0=give, obj1=table)
  FreeWillBankEntry(
    setupLines: [
      "Tu vas repartir ces trois objets sans t'en rendre compte.",
      "Trois possibilites. Tu vas croire choisir.",
      "Tu crois que tu vas choisir librement. Vraiment.",
    ],
    revealLines: [
      "Tu vas prendre {TAKE}, me donner {GIVE}, laisser {TABLE} sur la table.",
      "{TAKE} pour toi, {GIVE} pour moi, {TABLE} attend.",
      "Tu vas saisir {TAKE}, m'accorder {GIVE}, delaisser {TABLE}.",
    ],
    freeWillLines: [
      "Tu vas croire que c'etait ton choix. Parfait.",
      "Choix libre. Ou pas.",
      "Tu vas penser que c'est toi. Bien sur.",
    ],
    closerLines: [
      "Au final, t'as choisi ou t'as cru choisir.",
      "Au final, libre arbitre ou coincidence.",
      "Au final, hasard ou evidence.",
    ],
  ),

  // Permutation 5: (obj2=take, obj1=give, obj0=table)
  FreeWillBankEntry(
    setupLines: [
      "Tu vas repartir ces trois objets sans t'en rendre compte.",
      "Trois objets. Trois decisions. A toi.",
      "Tu crois que tu vas choisir librement. Peut-etre.",
    ],
    revealLines: [
      "Tu vas prendre {TAKE}, me donner {GIVE}, laisser {TABLE} sur la table.",
      "{TAKE} te revient, {GIVE} m'echoit, {TABLE} patiente.",
      "Tu vas opter pour {TAKE}, me remettre {GIVE}, abandonner {TABLE}.",
    ],
    freeWillLines: [
      "Tu vas croire que c'etait ton choix. Parfait.",
      "Ton choix, ma prevision.",
      "Tu vas penser decider seul. Evidemment.",
    ],
    closerLines: [
      "Au final, t'as choisi ou t'as cru choisir.",
      "Au final, volonte ou manipulation.",
      "Au final, qui tire les ficelles.",
    ],
  ),
];

/// Generator class for FREE_WILL narratives
class FreeWillBankGeneratorFR {
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

    final entry = freeWillBankFR[permIdx];
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
      lines.add(changeMindText ?? _selectVariant(changeMindLinesFR, random));
    } else if (suggestChangeOfMind) {
      lines.add(noChangeMindText ?? _selectVariant(noChangeMindLinesFR, random));
    }

    // L5: Closer
    lines.add(closer);

    return lines.join('\n');
  }

  /// Generate with custom bank templates (for preset customization).
  ///
  /// Resolution order:
  ///   1. `singleTemplate` (mode "single") — one text covers all 6 permutations,
  ///      uses {TAKE}/{GIVE}/{TABLE} for substitution.
  ///   2. `customTemplates[bucketKey]` (mode "six") — per-permutation text,
  ///      uses {TAKE}/{GIVE}/{TABLE} or ((Label1/2/3)) for substitution.
  ///   3. Default canned bank for the matching permutation.
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
        return '$body\n\n${changeMindText ?? _selectVariant(changeMindLinesFR, random)}';
      } else if (suggestChangeOfMind) {
        return '$body\n\n${noChangeMindText ?? _selectVariant(noChangeMindLinesFR, random)}';
      }
      return body;
    }

    // 1) Single-template mode wins if the performer set one.
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

    // 2) Per-permutation custom text.
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

    // 3) Default canned bank.
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
    return '''Tu vas prendre $takeObject, me donner $giveObject, laisser $tableObject sur la table.
Au final, t'as choisi ou t'as cru choisir.''';
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
    // ((Label1)), ((Label2)), ((Label3)) → canonical object at that position.
    // Lets bank texts reference an object by its position regardless of which
    // action it ended up with — useful for "as I told you, the {{Label1}}…"
    // type lines. The runtime label-override step (in completeFreeWill) then
    // swaps these names for the per-show overrides if any.
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
