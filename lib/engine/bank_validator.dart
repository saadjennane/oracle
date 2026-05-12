import 'dart:convert';

/// Describes the type of bank being validated.
enum BankType {
  choicesExactSequence,
  choicesBucket,
  duelFixedRounds,
  duelFirstTo,
  duelSequences,
  freewheel,
}

/// Metadata extracted from JSON import.
class BankImportMeta {
  final String preset;
  final String mode;
  final String? language;
  final String? style;
  final int? rounds;
  final List<String>? options;
  final String? performerKey;
  final int? targetScore;

  const BankImportMeta({
    required this.preset,
    required this.mode,
    this.language,
    this.style,
    this.rounds,
    this.options,
    this.performerKey,
    this.targetScore,
  });

  factory BankImportMeta.fromJson(Map<String, dynamic> json) {
    return BankImportMeta(
      preset: json['preset'] as String? ?? '',
      mode: json['mode'] as String? ?? '',
      language: json['language'] as String?,
      style: json['style'] as String?,
      rounds: json['rounds'] as int?,
      options: (json['options'] as List?)?.cast<String>(),
      performerKey: json['performerKey'] as String?,
      targetScore: json['targetScore'] as int?,
    );
  }

  Map<String, dynamic> toJson() => {
        'preset': preset,
        'mode': mode,
        if (language != null) 'language': language,
        if (style != null) 'style': style,
        if (rounds != null) 'rounds': rounds,
        if (options != null) 'options': options,
        if (performerKey != null) 'performerKey': performerKey,
        if (targetScore != null) 'targetScore': targetScore,
      };
}

/// Result of bank validation.
class ValidationResult {
  final List<String> errors;
  final int expectedCount;
  final int foundCount;
  final List<String> missingKeys;
  final List<String> extraKeys;
  final List<MapEntry<String, String>> previewSamples;
  final Map<String, String>? entries;
  final BankImportMeta? meta;

  const ValidationResult({
    required this.errors,
    required this.expectedCount,
    required this.foundCount,
    this.missingKeys = const [],
    this.extraKeys = const [],
    this.previewSamples = const [],
    this.entries,
    this.meta,
  });

  bool get isValid => errors.isEmpty;
}

/// Two-message prompt: system (persona, universal rules) + user (specifics).
/// Sent as a 2-message conversation to OpenAI; combined for clipboard preview.
/// `hasExamples` lets callers lower temperature for stylistic fidelity.
class BankPrompt {
  final String system;
  final String user;
  final bool hasExamples;
  const BankPrompt({
    required this.system,
    required this.user,
    required this.hasExamples,
  });

  String get combined => '## SYSTEM\n\n$system\n\n## USER\n\n$user';
}

/// Service for validating imported bank JSON.
class BankValidator {
  const BankValidator._();

  /// Shared system message — defines persona and universal output rules.
  /// Kept identical across all bank types so the model anchors on the same
  /// voice regardless of preset.
  static String _systemMessage(String languageCode) {
    final isFr = languageCode.startsWith('fr');
    return '''
You are a senior scriptwriter who has written hundreds of mentalism and cold-reading scripts for professional stage magicians. You write in the voice of a confident clairvoyant — first-person, prophetic but conversational, never theatrical or flowery.

Your scripts are read on a phone by a performer BEFORE a live show. Each script reads like a concrete prediction of what the spectator will do. The performer reveals it after the choices are made, so it must feel like it was written in advance with certainty.

OUTPUT RULES (NON-NEGOTIABLE):
- Output ONLY raw JSON. No markdown. No code fences. No commentary. No prose outside the JSON.
- The JSON must validate against the structure provided in the user message.
- All required keys must be present. No extra keys.
- Each entry value is a non-empty string.
- Language: ${isFr ? "French" : languageCode}.

VOICE GUIDELINES (apply to every entry):
- Spoken, fast, informal — as if the performer typed quick notes on their phone.
- Short sentences. Avoid subordinate clauses.
- No colons, no quotation marks, no arrows, no bullet points, no labels for rounds.
- No vague poetic wording. No metaphors that hide what literally happened.
- The narrative must be concrete and specific to the spectator's actions.

When the user message provides PERFORMER EXAMPLES, those examples are the absolute reference for voice, rhythm, vocabulary and sentence structure. You must imitate them as if the performer wrote every entry themselves. Do not invent a different style — extend theirs.
''';
  }

  /// Wrap an examples list with a strong imitation imperative. Returned as
  /// the FIRST section of the user message so the model anchors on it before
  /// reading the rules — examples-first dramatically improves style fidelity.
  static String _examplesBlock(List<MapEntry<String, String>>? examples) {
    if (examples == null || examples.isEmpty) {
      return '';
    }
    final buf = StringBuffer();
    buf.writeln('═══════════════════════════════════════════════');
    buf.writeln('PERFORMER EXAMPLES — MANDATORY VOICE TEMPLATE');
    buf.writeln('═══════════════════════════════════════════════');
    buf.writeln();
    buf.writeln('The performer wrote these example entries personally.');
    buf.writeln('Treat them as the ONLY source of truth for:');
    buf.writeln('  • voice and tone');
    buf.writeln('  • sentence length and rhythm');
    buf.writeln('  • vocabulary and idioms');
    buf.writeln('  • punctuation habits');
    buf.writeln('  • narrative structure');
    buf.writeln();
    buf.writeln('Every entry you generate must read as if written by the same person, on the same day, for the same show. Do not invent a more "polished" or "literary" voice — match these exactly.');
    buf.writeln();
    buf.writeln('Examples:');
    buf.writeln();
    for (int i = 0; i < examples.length; i++) {
      final entry = examples[i];
      buf.writeln('--- Example ${i + 1} (key "${entry.key}") ---');
      buf.writeln(entry.value.trim());
      buf.writeln();
    }
    buf.writeln('Before writing each entry, mentally re-read these examples. Match cadence, vocabulary and sentence length. The more your output diverges from this voice, the worse the result.');
    buf.writeln();
    return buf.toString();
  }

  /// Compute the expected keys for a given bank type and meta.
  static Set<String> computeExpectedKeys({
    required BankType bankType,
    required BankImportMeta meta,
    List<String>? freewheelObjects,
  }) {
    switch (bankType) {
      case BankType.choicesExactSequence:
        return _choicesExactKeys(meta);
      case BankType.choicesBucket:
        return _choicesBucketKeys(meta);
      case BankType.duelFixedRounds:
        return _duelFixedRoundsKeys(meta);
      case BankType.duelFirstTo:
        return _duelFirstToKeys(meta);
      case BankType.duelSequences:
        return _duelSequencesKeys(meta);
      case BankType.freewheel:
        return _freewheelKeys(freewheelObjects ?? []);
    }
  }

  /// Validate a JSON string for a given bank type.
  static ValidationResult validate({
    required String jsonString,
    required BankType expectedBankType,
    List<String>? freewheelObjects,
  }) {
    // 1) Sanitize common iOS/macOS smart punctuation
    final sanitized = jsonString
        .replaceAll('\u201C', '"') // left double quotation mark
        .replaceAll('\u201D', '"') // right double quotation mark
        .replaceAll('\u2018', "'") // left single quotation mark
        .replaceAll('\u2019', "'") // right single quotation mark
        .replaceAll('\u2013', '-') // en dash
        .replaceAll('\u2014', '-') // em dash
        .trim();

    // 2) JSON parse
    final dynamic parsed;
    try {
      parsed = jsonDecode(sanitized);
    } catch (e) {
      return const ValidationResult(
        errors: ['Invalid JSON format'],
        expectedCount: 0,
        foundCount: 0,
      );
    }

    if (parsed is! Map<String, dynamic>) {
      return const ValidationResult(
        errors: ['JSON root must be an object with "meta" and "entries"'],
        expectedCount: 0,
        foundCount: 0,
      );
    }

    // Check required fields
    if (!parsed.containsKey('meta') || !parsed.containsKey('entries')) {
      return const ValidationResult(
        errors: ['JSON must contain "meta" and "entries" fields'],
        expectedCount: 0,
        foundCount: 0,
      );
    }

    // Parse meta
    final BankImportMeta meta;
    try {
      meta = BankImportMeta.fromJson(parsed['meta'] as Map<String, dynamic>);
    } catch (e) {
      return const ValidationResult(
        errors: ['Invalid "meta" format'],
        expectedCount: 0,
        foundCount: 0,
      );
    }

    // 2) Check preset/mode coherence
    final coherenceError = _checkCoherence(meta, expectedBankType);
    if (coherenceError != null) {
      return ValidationResult(
        errors: [coherenceError],
        expectedCount: 0,
        foundCount: 0,
        meta: meta,
      );
    }

    // Parse entries
    final entriesRaw = parsed['entries'];
    if (entriesRaw is! Map<String, dynamic>) {
      return ValidationResult(
        errors: ['\"entries\" must be a JSON object'],
        expectedCount: 0,
        foundCount: 0,
        meta: meta,
      );
    }

    final entries = <String, String>{};
    for (final entry in entriesRaw.entries) {
      entries[entry.key] = entry.value.toString();
    }

    // 3-5) Compute expected keys and compare
    final expectedKeys = computeExpectedKeys(
      bankType: expectedBankType,
      meta: meta,
      freewheelObjects: freewheelObjects,
    );
    final expectedCount = expectedKeys.length;
    final foundKeys = entries.keys.toSet();

    final missingKeys = expectedKeys.difference(foundKeys).toList()..sort();
    final extraKeys = foundKeys.difference(expectedKeys).toList()..sort();

    final errors = <String>[];

    if (entries.length != expectedCount) {
      errors.add(
          'Expected $expectedCount entries, found ${entries.length}');
    }

    if (missingKeys.isNotEmpty) {
      errors.add('Missing keys: ${missingKeys.join(", ")}');
    }

    if (extraKeys.isNotEmpty) {
      errors.add('Extra keys: ${extraKeys.join(", ")}');
    }

    // 6) Check empty values
    final emptyKeys = <String>[];
    for (final entry in entries.entries) {
      if (entry.value.trim().isEmpty) {
        emptyKeys.add(entry.key);
      }
    }
    if (emptyKeys.isNotEmpty) {
      errors.add('Empty values for keys: ${emptyKeys.join(", ")}');
    }

    // 7) Preview samples (up to 3)
    final sampleEntries = entries.entries.take(3).toList();

    return ValidationResult(
      errors: errors,
      expectedCount: expectedCount,
      foundCount: entries.length,
      missingKeys: missingKeys,
      extraKeys: extraKeys,
      previewSamples: sampleEntries,
      entries: errors.isEmpty ? entries : null,
      meta: meta,
    );
  }

  // ─── Private helpers ───────────────────────────────────────────

  static String? _checkCoherence(BankImportMeta meta, BankType expected) {
    switch (expected) {
      case BankType.choicesExactSequence:
        if (meta.preset != 'choices') {
          return 'Expected preset "choices", got "${meta.preset}"';
        }
        if (meta.mode != 'exact_sequence') {
          return 'Expected mode "exact_sequence", got "${meta.mode}"';
        }
        if (meta.rounds == null || meta.rounds! < 1) {
          return 'Missing or invalid "rounds" in meta';
        }
        if (meta.options == null || meta.options!.length < 2) {
          return 'Missing or invalid "options" in meta (need at least 2)';
        }
        break;

      case BankType.choicesBucket:
        if (meta.preset != 'choices') {
          return 'Expected preset "choices", got "${meta.preset}"';
        }
        if (meta.mode != 'bucket') {
          return 'Expected mode "bucket", got "${meta.mode}"';
        }
        if (meta.rounds == null || meta.rounds! < 1) {
          return 'Missing or invalid "rounds" in meta';
        }
        break;

      case BankType.duelFixedRounds:
        if (meta.preset != 'duel') {
          return 'Expected preset "duel", got "${meta.preset}"';
        }
        if (meta.mode != 'bucket') {
          return 'Expected mode "bucket", got "${meta.mode}"';
        }
        if (meta.rounds == null || meta.rounds! < 1) {
          return 'Missing or invalid "rounds" in meta';
        }
        break;

      case BankType.duelFirstTo:
        if (meta.preset != 'duel') {
          return 'Expected preset "duel", got "${meta.preset}"';
        }
        if (meta.mode != 'bucket') {
          return 'Expected mode "bucket", got "${meta.mode}"';
        }
        if (meta.targetScore == null || meta.targetScore! < 1) {
          return 'Missing or invalid "targetScore" in meta';
        }
        break;

      case BankType.duelSequences:
        if (meta.preset != 'duel') {
          return 'Expected preset "duel", got "${meta.preset}"';
        }
        if (meta.mode != 'duel_sequence') {
          return 'Expected mode "duel_sequence", got "${meta.mode}"';
        }
        if (meta.rounds == null || meta.rounds! < 1) {
          return 'Missing or invalid "rounds" in meta';
        }
        if (meta.options == null || meta.options!.length < 2) {
          return 'Missing or invalid "options" in meta (need at least 2)';
        }
        break;

      case BankType.freewheel:
        // Accept legacy "freewheel" as well as current "free will" for back-compat.
        if (meta.preset != 'free will' && meta.preset != 'freewheel') {
          return 'Expected preset "free will", got "${meta.preset}"';
        }
        break;
    }
    return null;
  }

  /// Choices exact_sequence: N^R keys, digits 1..N, length R
  static Set<String> _choicesExactKeys(BankImportMeta meta) {
    final n = meta.options?.length ?? 2;
    final r = meta.rounds ?? 1;
    final total = _pow(n, r);
    final keys = <String>{};

    for (int i = 0; i < total; i++) {
      final buf = StringBuffer();
      int val = i;
      for (int bit = r - 1; bit >= 0; bit--) {
        final divisor = _pow(n, bit);
        final digit = (val ~/ divisor) + 1;
        val = val % divisor;
        buf.write(digit);
      }
      keys.add(buf.toString());
    }
    return keys;
  }

  /// Choices H/M pattern: 2^R keys (e.g. HHH, HHM, HMH, ...)
  static Set<String> _choicesBucketKeys(BankImportMeta meta) {
    final r = meta.rounds ?? 1;
    final total = 1 << r; // 2^R
    final keys = <String>{};
    for (int i = 0; i < total; i++) {
      final buf = StringBuffer();
      for (int bit = r - 1; bit >= 0; bit--) {
        buf.write((i >> bit) & 1 == 0 ? 'H' : 'M');
      }
      keys.add(buf.toString());
    }
    return keys;
  }

  /// Duel fixed rounds: (R+1)(R+2)/2 buckets
  /// Key format: "R|S-P" (e.g. "3|2-1" = 3 rounds, spectator 2, performer 1)
  static Set<String> _duelFixedRoundsKeys(BankImportMeta meta) {
    final r = meta.rounds ?? 1;
    final keys = <String>{};
    for (int s = 0; s <= r; s++) {
      for (int p = 0; p <= r - s; p++) {
        keys.add('$r|$s-$p');
      }
    }
    return keys;
  }

  /// Duel first-to: 2*T buckets
  /// Key format: "FT{T}_{side}_{T}-{loser}" (e.g. "FT3_S_3-0" = first-to 3, spectator wins 3-0)
  static Set<String> _duelFirstToKeys(BankImportMeta meta) {
    final t = meta.targetScore ?? 2;
    final keys = <String>{};
    for (int loserScore = 0; loserScore < t; loserScore++) {
      keys.add('FT${t}_S_$t-$loserScore');
      keys.add('FT${t}_P_$t-$loserScore');
    }
    return keys;
  }

  /// Duel sequences: M^N keys where M = number of options, N = rounds.
  /// Key format: "SEQ_i0_i1_..._iN-1" where each index is 0-based option index.
  static Set<String> _duelSequencesKeys(BankImportMeta meta) {
    final m = meta.options?.length ?? 3;
    final n = meta.rounds ?? 1;
    final total = _pow(m, n);
    final keys = <String>{};

    for (int i = 0; i < total; i++) {
      final indices = <int>[];
      int val = i;
      for (int bit = n - 1; bit >= 0; bit--) {
        final divisor = _pow(m, bit);
        indices.add(val ~/ divisor);
        val = val % divisor;
      }
      keys.add('SEQ_${indices.join("_")}');
    }
    return keys;
  }

  /// Freewheel: 6 permutation keys
  static Set<String> _freewheelKeys(List<String> objects) {
    if (objects.length < 3) {
      return {'TAKE:?|GIVE:?|TABLE:?'};
    }
    final keys = <String>{};
    final perms = [
      [0, 1, 2],
      [0, 2, 1],
      [1, 0, 2],
      [1, 2, 0],
      [2, 0, 1],
      [2, 1, 0],
    ];
    for (final perm in perms) {
      keys.add(
          'TAKE:${objects[perm[0]]}|GIVE:${objects[perm[1]]}|TABLE:${objects[perm[2]]}');
    }
    return keys;
  }

  static int _pow(int base, int exp) {
    int result = 1;
    for (int i = 0; i < exp; i++) {
      result *= base;
    }
    return result;
  }

  /// Generate a prompt for an LLM to produce the JSON bank.
  static BankPrompt generatePrompt({
    required BankType bankType,
    required String languageCode,
    int? rounds,
    List<String>? options,
    int? targetScore,
    List<String>? freewheelObjects,
    String tense = 'future',
    String style = 'direct',
    String? performerKey,
    int linesMin = 3,
    int linesMax = 5,
    List<MapEntry<String, String>>? examples,
  }) {
    switch (bankType) {
      case BankType.choicesExactSequence:
        return _generateChoicesExactPrompt(
          languageCode: languageCode,
          rounds: rounds ?? 3,
          options: options ?? [],
          tense: tense,
          style: style,
          performerKey: performerKey,
          linesMin: linesMin,
          linesMax: linesMax,
          examples: examples,
        );
      case BankType.duelSequences:
        return _generateDuelSequencesPrompt(
          languageCode: languageCode,
          rounds: rounds ?? 3,
          options: options ?? [],
          tense: tense,
          style: style,
          performerKey: performerKey,
          performerSequenceIndices: null,
          linesMin: linesMin,
          linesMax: linesMax,
          examples: examples,
        );
      default:
        return _generateLegacyPrompt(
          bankType: bankType,
          languageCode: languageCode,
          rounds: rounds,
          options: options,
          targetScore: targetScore,
          freewheelObjects: freewheelObjects,
          tense: tense,
          style: style,
          performerKey: performerKey,
          linesMin: linesMin,
          linesMax: linesMax,
          examples: examples,
        );
    }
  }

  /// Master prompt for CHOICES · EXACT SEQUENCE.
  static BankPrompt _generateChoicesExactPrompt({
    required String languageCode,
    required int rounds,
    required List<String> options,
    required String tense,
    required String style,
    String? performerKey,
    int linesMin = 3,
    int linesMax = 5,
    List<MapEntry<String, String>>? examples,
  }) {
    final buf = StringBuffer();
    final optionCount = options.length;
    final optionsLabelled = options.join(', ');

    // Compute expected keys
    final meta = BankImportMeta(
      preset: 'choices',
      mode: 'exact_sequence',
      rounds: rounds,
      options: options,
    );
    final expectedKeys = computeExpectedKeys(
      bankType: BankType.choicesExactSequence,
      meta: meta,
    ).toList()
      ..sort();

    // ── EXAMPLES FIRST (anchor voice before any rules) ──
    buf.write(_examplesBlock(examples));

    // ── WRITING VARIABLES ──
    buf.writeln('⸻');
    buf.writeln();
    buf.writeln('WRITING VARIABLES');
    buf.writeln();
    buf.writeln('Tense: $tense');
    buf.writeln();
    buf.writeln('Style guidance (free-form, written by the performer):');
    buf.writeln(style);
    buf.writeln();
    if (examples == null || examples.isEmpty) {
      buf.writeln('Apply this guidance closely — it describes tone, attitude, rhythm, vocabulary, personality, mood.');
    } else {
      buf.writeln('Apply this guidance only when it does not contradict the performer examples above. The examples take priority.');
    }
    buf.writeln();

    // ── GAME CONTEXT ──
    buf.writeln('⸻');
    buf.writeln();
    buf.writeln('GAME CONTEXT');
    buf.writeln();
    buf.writeln('Preset type: CHOICES');
    buf.writeln();
    buf.writeln('In this game, a spectator chooses between several options at each round.');
    buf.writeln();
    buf.writeln('Mode: exact_sequence');
    buf.writeln();
    buf.writeln('This means:');
    buf.writeln('\t• Each possible spectator sequence has its own text');
    buf.writeln('\t• Each text describes the full sequence, round by round');
    buf.writeln('\t• There is NO abstraction by score or statistics');
    buf.writeln();
    buf.writeln('Number of rounds: $rounds');
    buf.writeln();
    buf.writeln('Number of options: $optionCount');
    buf.writeln();
    buf.writeln('Option labels (ordered):');
    buf.writeln(optionsLabelled);
    buf.writeln();
    buf.writeln('These labels must be used verbatim in the texts.');
    buf.writeln();

    // ── PERFORMER PRE-PROGRAMMED SEQUENCE ──
    buf.writeln('⸻');
    buf.writeln();
    buf.writeln('PERFORMER PRE-PROGRAMMED SEQUENCE');
    buf.writeln();
    buf.writeln('Before the show, the performer secretly wrote a sequence of options.');
    buf.writeln();
    buf.writeln('Performer sequence:');
    if (performerKey != null && performerKey.isNotEmpty) {
      buf.writeln(performerKey);
    } else {
      buf.writeln('(none)');
    }
    buf.writeln();
    buf.writeln('This sequence represents what the performer predicted or planned in advance.');
    buf.writeln();
    buf.writeln('Your texts must be coherent with this sequence:');
    buf.writeln('\t• If the spectator matches it, the text should reflect a hit');
    buf.writeln('\t• If the spectator diverges from it, the text should reflect a miss');
    buf.writeln('\t• The narrative must clearly reflect when things match or diverge');
    buf.writeln();
    buf.writeln('Do NOT mention the performer\'s sequence explicitly.');
    buf.writeln('It must be implied through the narrative.');
    buf.writeln();

    // ── KEY ENCODING ──
    buf.writeln('⸻');
    buf.writeln();
    buf.writeln('KEY ENCODING (VERY IMPORTANT)');
    buf.writeln();
    buf.writeln('Each JSON key encodes the spectator\'s exact sequence of choices.');
    buf.writeln();
    buf.writeln('Encoding rule:');
    buf.writeln('\t• Digit "1" = first option');
    buf.writeln('\t• Digit "2" = second option');
    if (optionCount >= 3) {
      buf.writeln('\t• Digit "3" = third option');
    }
    if (optionCount >= 4) {
      for (int i = 4; i <= optionCount; i++) {
        buf.writeln('\t• Digit "$i" = option $i');
      }
    }
    buf.writeln('\t• etc.');
    buf.writeln();
    if (options.length >= 2) {
      buf.writeln('Example (with options $optionsLabelled):');
      final sampleKey = List.generate(rounds, (i) => i < rounds - 1 ? '1' : '2').join();
      final sampleLabel = List.generate(rounds, (i) => i < rounds - 1 ? options[0] : options[1]).join(', ');
      buf.writeln('\t• Key "$sampleKey" means $sampleLabel');
      buf.writeln();
    }
    buf.writeln('There must be exactly one entry per possible sequence.');
    buf.writeln();

    // ── SEQUENCE IN TEXT ──
    buf.writeln('⸻');
    buf.writeln();
    buf.writeln('SPECTATOR SEQUENCE IN TEXT');
    buf.writeln();
    buf.writeln('Since this is exact_sequence mode, you already know the spectator\'s full sequence from each key.');
    buf.writeln();
    buf.writeln('Each text MUST begin by stating the spectator\'s sequence using the option labels.');
    buf.writeln('Write it naturally — do NOT use any placeholder or variable like {spectatorSequence}.');
    buf.writeln();
    if (options.length >= 2) {
      final sampleSeq = List.generate(rounds, (i) => i < rounds - 1 ? options[0] : options[1]).join(', ');
      buf.writeln('Example: for a key meaning ${options[0]}, ${options[0]}, ${options[1]}, start with:');
      buf.writeln('"$sampleSeq"');
      buf.writeln('Then continue with the narrative.');
    }
    buf.writeln();

    // ── WRITING RULES ──
    buf.writeln('⸻');
    buf.writeln();
    buf.writeln('WRITING RULES');
    buf.writeln();
    buf.writeln('1. Each entry MUST start by stating the spectator\'s sequence (using the option labels), on its own line');
    buf.writeln('2. Then describe what happens across the rounds in $linesMin–$linesMax short lines');
    buf.writeln('3. Length per entry: 25–60 words. Do not exceed 70 words.');
    buf.writeln('4. It must be clear which moments are hits and which are misses');
    buf.writeln('5. Do NOT number or label rounds explicitly ("round 1", "first round", etc.)');
    buf.writeln('6. Do NOT use colons, arrows, quotation marks, or bullet points');
    buf.writeln('7. Write as if typed quickly on a phone — fast, spoken, no flourish');
    buf.writeln('8. Each entry must be a non-empty string');
    buf.writeln();

    // ── EXPECTED JSON STRUCTURE ──
    buf.writeln('⸻');
    buf.writeln();
    buf.writeln('EXPECTED JSON STRUCTURE');
    buf.writeln();
    buf.writeln('You MUST output exactly this structure:');
    buf.writeln();
    buf.writeln('{');
    buf.writeln('  "meta": {');
    buf.writeln('    "preset": "choices",');
    buf.writeln('    "mode": "exact_sequence",');
    buf.writeln('    "language": "$languageCode",');
    buf.writeln('    "tense": "$tense",');
    buf.writeln('    "style": "$style",');
    buf.writeln('    "rounds": $rounds,');
    buf.writeln('    "options": [${options.map((o) => '"$o"').join(', ')}]');
    buf.writeln('  },');
    buf.writeln('  "entries": {');
    for (int i = 0; i < expectedKeys.length; i++) {
      final comma = i < expectedKeys.length - 1 ? ',' : '';
      buf.writeln('    "${expectedKeys[i]}": "<your text>"$comma');
    }
    buf.writeln('  }');
    buf.writeln('}');
    buf.writeln();

    // ── STRICT VALIDATION CHECK ──
    buf.writeln('⸻');
    buf.writeln();
    buf.writeln('STRICT VALIDATION CHECK (DO THIS BEFORE OUTPUT)');
    buf.writeln();
    buf.writeln('Before outputting, verify that:');
    buf.writeln('\t• All expected keys are present');
    buf.writeln('\t• No extra keys exist');
    buf.writeln('\t• Every entry starts by stating the spectator\'s sequence using option labels');
    buf.writeln('\t• Every entry matches its key\'s spectator sequence');
    buf.writeln('\t• The narrative is coherent with the performer sequence');
    buf.writeln('\t• The style matches the provided examples');
    buf.writeln();
    buf.writeln('If any of these conditions are not met, correct the output before returning it.');
    buf.writeln();
    if (examples != null && examples.isNotEmpty) {
      buf.writeln('Final reminder: every entry must read as if written by the same author as the performer examples above. Match their voice exactly.');
      buf.writeln();
    }
    buf.writeln('Now generate the complete JSON text bank.');

    return BankPrompt(
      system: _systemMessage(languageCode),
      user: buf.toString(),
      hasExamples: examples != null && examples.isNotEmpty,
    );
  }

  /// Master prompt for DUEL · SEQUENCES.
  static BankPrompt _generateDuelSequencesPrompt({
    required String languageCode,
    required int rounds,
    required List<String> options,
    required String tense,
    required String style,
    String? performerKey,
    List<int>? performerSequenceIndices,
    int linesMin = 3,
    int linesMax = 5,
    List<MapEntry<String, String>>? examples,
  }) {
    final buf = StringBuffer();
    final optionCount = options.length;
    final optionsLabelled = options.join(', ');

    // Compute expected keys
    final meta = BankImportMeta(
      preset: 'duel',
      mode: 'duel_sequence',
      rounds: rounds,
      options: options,
    );
    final expectedKeys = computeExpectedKeys(
      bankType: BankType.duelSequences,
      meta: meta,
    ).toList()
      ..sort();

    // ── EXAMPLES FIRST ──
    buf.write(_examplesBlock(examples));

    // ── WRITING VARIABLES ──
    buf.writeln('⸻');
    buf.writeln();
    buf.writeln('WRITING VARIABLES');
    buf.writeln();
    buf.writeln('Tense: $tense');
    buf.writeln();
    buf.writeln('Style guidance (free-form, written by the performer):');
    buf.writeln(style);
    buf.writeln();
    if (examples == null || examples.isEmpty) {
      buf.writeln('Apply this guidance closely.');
    } else {
      buf.writeln('Apply this guidance only when it does not contradict the performer examples above. The examples take priority.');
    }
    buf.writeln();

    // ── GAME CONTEXT ──
    buf.writeln('⸻');
    buf.writeln();
    buf.writeln('GAME CONTEXT');
    buf.writeln();
    buf.writeln('Preset type: DUEL');
    buf.writeln();
    buf.writeln('In this game, a spectator and a performer play a round-based duel (e.g. Rock-Paper-Scissors).');
    buf.writeln('Both choose simultaneously at each round.');
    buf.writeln();
    buf.writeln('Mode: duel_sequence');
    buf.writeln();
    buf.writeln('This means:');
    buf.writeln('\t• Each possible spectator sequence has its own text');
    buf.writeln('\t• Each text describes the full duel sequence, round by round');
    buf.writeln('\t• The performer\'s sequence is fixed (preprogrammed)');
    buf.writeln('\t• There is NO abstraction by score or statistics');
    buf.writeln();
    buf.writeln('Number of rounds: $rounds');
    buf.writeln();
    buf.writeln('Number of options: $optionCount');
    buf.writeln();
    buf.writeln('Option labels (ordered):');
    buf.writeln(optionsLabelled);
    buf.writeln();
    buf.writeln('These labels must be used verbatim in the texts.');
    buf.writeln();

    // ── PERFORMER PRE-PROGRAMMED SEQUENCE ──
    buf.writeln('⸻');
    buf.writeln();
    buf.writeln('PERFORMER PRE-PROGRAMMED SEQUENCE');
    buf.writeln();
    buf.writeln('Before the show, the performer secretly wrote a sequence of options.');
    buf.writeln();
    buf.writeln('Performer sequence:');
    if (performerKey != null && performerKey.isNotEmpty) {
      buf.writeln(performerKey);
    } else {
      buf.writeln('(none)');
    }
    buf.writeln();
    buf.writeln('This sequence represents what the performer chose in advance for each round.');
    buf.writeln();
    buf.writeln('Your texts must be coherent with this sequence:');
    buf.writeln('\t• Compare each round: spectator choice vs performer choice');
    buf.writeln('\t• Clearly indicate wins, losses, and ties at each round');
    buf.writeln('\t• The final score should be stated or clearly implied');
    buf.writeln();
    buf.writeln('Do NOT mention the performer\'s sequence explicitly.');
    buf.writeln('It must be implied through the narrative.');
    buf.writeln();

    // ── KEY ENCODING ──
    buf.writeln('⸻');
    buf.writeln();
    buf.writeln('KEY ENCODING (VERY IMPORTANT)');
    buf.writeln();
    buf.writeln('Each JSON key encodes the spectator\'s exact sequence of choices.');
    buf.writeln();
    buf.writeln('Format: "SEQ_i0_i1_..._iN" where each number is a 0-based option index.');
    buf.writeln();
    buf.writeln('Encoding rule:');
    for (int i = 0; i < optionCount; i++) {
      buf.writeln('\t• Index "$i" = ${options[i]}');
    }
    buf.writeln();
    if (options.length >= 2) {
      final sampleIndices = List.generate(rounds, (i) => i < rounds - 1 ? 0 : 1);
      final sampleKey = 'SEQ_${sampleIndices.join("_")}';
      final sampleLabel = sampleIndices.map((i) => options[i]).join(', ');
      buf.writeln('Example:');
      buf.writeln('\t• Key "$sampleKey" means spectator chose $sampleLabel');
      buf.writeln();
    }
    buf.writeln('There must be exactly one entry per possible spectator sequence.');
    buf.writeln('Total keys: ${expectedKeys.length} ($optionCount^$rounds)');
    buf.writeln();

    // ── AVAILABLE VARIABLES ──
    buf.writeln('⸻');
    buf.writeln();
    buf.writeln('AVAILABLE VARIABLES (INJECTED AT RUNTIME)');
    buf.writeln();
    buf.writeln('The app replaces these placeholders at display time.');
    buf.writeln('You MUST use them in your texts — do NOT hard-code values.');
    buf.writeln();
    buf.writeln('• {spectatorSequence} — the full spectator sequence (e.g. "Pierre, Ciseaux, Feuille")');
    buf.writeln('  MANDATORY: every entry MUST start with {spectatorSequence} on its own line.');
    buf.writeln();
    for (int i = 1; i <= rounds; i++) {
      buf.writeln('• {choix$i} — spectator\'s choice at round $i');
    }
    buf.writeln();
    for (int i = 1; i <= rounds; i++) {
      buf.writeln('• {choicePerformer$i} — performer\'s choice at round $i');
    }
    buf.writeln();
    buf.writeln('• {numRounds} — total number of rounds ($rounds)');
    buf.writeln('• {scoreX} — spectator\'s final score');
    buf.writeln('• {scoreY} — performer\'s final score');
    buf.writeln('• {numTies} — number of ties');
    buf.writeln();
    buf.writeln('Use per-round variables to describe what happened at specific moments.');
    buf.writeln();

    // ── SEQUENCE IN TEXT ──
    buf.writeln('⸻');
    buf.writeln();
    buf.writeln('SPECTATOR SEQUENCE IN TEXT');
    buf.writeln();
    buf.writeln('Since this is duel_sequence mode, you already know the spectator\'s full sequence from each key.');
    buf.writeln();
    buf.writeln('Each text MUST begin with {spectatorSequence} on its own line.');
    buf.writeln('Then write the narrative describing the duel round by round.');
    buf.writeln();

    // ── WRITING RULES ──
    buf.writeln('⸻');
    buf.writeln();
    buf.writeln('WRITING RULES');
    buf.writeln();
    buf.writeln('1. Each entry MUST start with {spectatorSequence} on its own line');
    buf.writeln('2. Then describe the duel round by round in $linesMin–$linesMax short lines');
    buf.writeln('3. Length per entry: 25–60 words. Do not exceed 70 words.');
    buf.writeln('4. It must be clear which rounds are wins, losses, and ties');
    buf.writeln('5. Do NOT number or label rounds explicitly');
    buf.writeln('6. Do NOT use colons, arrows, quotation marks, or bullet points');
    buf.writeln('7. Write as if typed quickly on a phone — fast, spoken, no flourish');
    buf.writeln('8. Each entry must be a non-empty string');
    buf.writeln('9. Use {scoreX} and {scoreY} to state the final score');
    buf.writeln();

    // ── EXPECTED JSON STRUCTURE ──
    buf.writeln('⸻');
    buf.writeln();
    buf.writeln('EXPECTED JSON STRUCTURE');
    buf.writeln();
    buf.writeln('You MUST output exactly this structure:');
    buf.writeln();
    buf.writeln('{');
    buf.writeln('  "meta": {');
    buf.writeln('    "preset": "duel",');
    buf.writeln('    "mode": "duel_sequence",');
    buf.writeln('    "language": "$languageCode",');
    buf.writeln('    "tense": "$tense",');
    buf.writeln('    "style": "$style",');
    buf.writeln('    "rounds": $rounds,');
    buf.writeln('    "options": [${options.map((o) => '"$o"').join(', ')}]');
    buf.writeln('  },');
    buf.writeln('  "entries": {');
    for (int i = 0; i < expectedKeys.length; i++) {
      final comma = i < expectedKeys.length - 1 ? ',' : '';
      buf.writeln('    "${expectedKeys[i]}": "<your text>"$comma');
    }
    buf.writeln('  }');
    buf.writeln('}');
    buf.writeln();

    // ── STRICT VALIDATION CHECK ──
    buf.writeln('⸻');
    buf.writeln();
    buf.writeln('STRICT VALIDATION CHECK (DO THIS BEFORE OUTPUT)');
    buf.writeln();
    buf.writeln('Before outputting, verify that:');
    buf.writeln('\t• All ${expectedKeys.length} keys are present');
    buf.writeln('\t• No extra keys exist');
    buf.writeln('\t• Every entry starts with {spectatorSequence}');
    buf.writeln('\t• Every entry matches its key\'s spectator sequence');
    buf.writeln('\t• The narrative is coherent with the performer sequence');
    buf.writeln('\t• The style matches the provided examples');
    buf.writeln();
    buf.writeln('If any of these conditions are not met, correct the output before returning it.');
    buf.writeln();
    if (examples != null && examples.isNotEmpty) {
      buf.writeln('Final reminder: every entry must read as if written by the same author as the performer examples above. Match their voice exactly.');
      buf.writeln();
    }
    buf.writeln('Now generate the complete JSON text bank.');

    return BankPrompt(
      system: _systemMessage(languageCode),
      user: buf.toString(),
      hasExamples: examples != null && examples.isNotEmpty,
    );
  }

  /// Legacy prompt generator for non-choicesExactSequence bank types.
  static BankPrompt _generateLegacyPrompt({
    required BankType bankType,
    required String languageCode,
    int? rounds,
    List<String>? options,
    int? targetScore,
    List<String>? freewheelObjects,
    String tense = 'future',
    String style = 'direct',
    String? performerKey,
    int linesMin = 3,
    int linesMax = 5,
    List<MapEntry<String, String>>? examples,
  }) {
    final buf = StringBuffer();

    final presetStr = bankType == BankType.freewheel
        ? 'free will'
        : (bankType == BankType.choicesExactSequence ||
                bankType == BankType.choicesBucket)
            ? 'choices'
            : 'duel';
    final modeStr = bankType == BankType.choicesExactSequence
        ? 'exact_sequence'
        : 'bucket';

    final mainPlaceholder = bankType == BankType.choicesBucket
        ? '{spectatorSequenceLabeled}'
        : '{spectatorSequence}';

    // Compute expected keys
    final meta = BankImportMeta(
      preset: presetStr,
      mode: modeStr,
      rounds: rounds,
      options: options,
      targetScore: targetScore,
    );
    final expectedKeys = computeExpectedKeys(
      bankType: bankType,
      meta: meta,
      freewheelObjects: freewheelObjects,
    ).toList()
      ..sort();

    // ── EXAMPLES FIRST (anchor voice) ──
    buf.write(_examplesBlock(examples));

    // ══════════ STYLE ══════════
    buf.writeln('========================');
    buf.writeln('STYLE');
    buf.writeln('========================');
    buf.writeln('Tense: $tense (future / present / past)');
    buf.writeln('Writing style (free text): $style');
    if (examples == null || examples.isEmpty) {
      buf.writeln('Reference styles: direct, taquin, blunt, minimalist, mocking, psychological');
    }
    buf.writeln();
    buf.writeln('Length per entry: 25–60 words ($linesMin–$linesMax short lines). Hard cap: 70 words.');
    if (examples != null && examples.isNotEmpty) {
      buf.writeln('Voice: identical to the performer examples above. Style guidance applies only when not in conflict with the examples.');
    }
    buf.writeln();

    // ══════════ GAME CONTEXT ══════════
    buf.writeln('========================');
    buf.writeln('GAME CONTEXT');
    buf.writeln('========================');

    switch (bankType) {
      case BankType.choicesExactSequence:
        break; // Handled by _generateChoicesExactPrompt

      case BankType.choicesBucket:
        buf.writeln('Preset: CHOICES');
        buf.writeln('Mode: H/M PATTERN');
        buf.writeln();
        buf.writeln('Number of rounds: $rounds');
        if (performerKey != null && performerKey.isNotEmpty) {
          buf.writeln('Performer\'s pre-set sequence: $performerKey');
        }
        buf.writeln();
        buf.writeln('Key encoding:');
        buf.writeln('- Each key is a sequence of H (hit) and M (miss) characters.');
        buf.writeln('- Length = number of rounds ($rounds).');
        buf.writeln('- "H" = spectator matched performer, "M" = spectator did not match.');
        buf.writeln('- Example: "HMH" = hit round 1, miss round 2, hit round 3.');
        buf.writeln('- Total keys: ${1 << (rounds ?? 1)} (2^$rounds).');
        break;

      case BankType.duelFixedRounds:
        buf.writeln('Preset: DUEL');
        buf.writeln('Mode: BUCKET (fixed rounds)');
        buf.writeln();
        buf.writeln('The spectator and performer both choose simultaneously each round.');
        buf.writeln('Number of rounds: $rounds');
        buf.writeln();
        buf.writeln('Key encoding:');
        buf.writeln('- Format: "{rounds}|{spectatorWins}-{performerWins}"');
        buf.writeln('- Example: "3|2-1" means 3 rounds, spectator won 2, performer won 1 (0 ties)');
        buf.writeln('- spectatorWins + performerWins + ties = $rounds');
        break;

      case BankType.duelFirstTo:
        buf.writeln('Preset: DUEL');
        buf.writeln('Mode: BUCKET (first to)');
        buf.writeln();
        buf.writeln('The spectator and performer both choose simultaneously each round.');
        buf.writeln('First player to reach $targetScore wins.');
        buf.writeln();
        buf.writeln('Key encoding:');
        buf.writeln('- Format: "FT{target}_{winner}_{target}-{loserScore}"');
        buf.writeln('- Example: "FT3_S_3-1" means first-to 3, spectator wins 3-1');
        buf.writeln('- Winner is "S" (spectator) or "P" (performer).');
        break;

      case BankType.duelSequences:
        break; // Handled by _generateDuelSequencesPrompt

      case BankType.freewheel:
        buf.writeln('Preset: FREE WILL');
        buf.writeln();
        buf.writeln('The spectator freely assigns 3 objects to 3 actions.');
        if (freewheelObjects != null && freewheelObjects.length >= 3) {
          buf.writeln('Objects: ${freewheelObjects.join(", ")}');
        }
        buf.writeln('Actions: TAKE (keep), GIVE (give to performer), TABLE (leave on table).');
        buf.writeln();
        buf.writeln('Key encoding:');
        buf.writeln('- Format: "TAKE:{obj}|GIVE:{obj}|TABLE:{obj}"');
        buf.writeln('- One key per permutation (6 total).');
        break;
    }
    buf.writeln();

    // ══════════ AVAILABLE VARIABLES ══════════
    buf.writeln('========================');
    buf.writeln('AVAILABLE VARIABLES (INJECTED AT RUNTIME)');
    buf.writeln('========================');
    buf.writeln('The app replaces these placeholders at display time.');
    buf.writeln('You MUST use them in your texts — do NOT hard-code values.');
    buf.writeln();

    switch (bankType) {
      case BankType.choicesExactSequence:
        break; // Handled by _generateChoicesExactPrompt

      case BankType.choicesBucket:
        buf.writeln('IMPORTANT: You MUST use these variable placeholders in EVERY text entry.');
        buf.writeln('Do NOT hard-code choice names — use the variables so values are injected at runtime.');
        buf.writeln();
        for (int i = 1; i <= (rounds ?? 3); i++) {
          buf.writeln('• {choiceS$i} — spectator\'s choice at round $i');
        }
        buf.writeln();
        for (int i = 1; i <= (rounds ?? 3); i++) {
          buf.writeln('• {choiceP$i} — performer\'s choice at round $i');
        }
        buf.writeln();
        buf.writeln('Use {choiceS1}, {choiceS2}, etc. to reference the spectator\'s choice at each round.');
        buf.writeln('Use {choiceP1}, {choiceP2}, etc. to reference the performer\'s prediction at each round.');
        buf.writeln('EVERY entry MUST use these variables — never write literal option names.');
        break;

      case BankType.duelFixedRounds:
        buf.writeln('IMPORTANT: You MUST use these variable placeholders in EVERY text entry.');
        buf.writeln('Do NOT hard-code choice names — use the variables so values are injected at runtime.');
        buf.writeln();
        buf.writeln('### Choices per round');
        for (int i = 1; i <= (rounds ?? 3); i++) {
          buf.writeln('• {choiceS$i} — spectator\'s choice at round $i');
        }
        for (int i = 1; i <= (rounds ?? 3); i++) {
          buf.writeln('• {choiceP$i} — performer\'s choice at round $i');
        }
        buf.writeln();
        buf.writeln('### Scores');
        buf.writeln('• {X} — spectator\'s win count');
        buf.writeln('• {Y} — performer\'s win count');
        buf.writeln('• {numTies} — number of ties');
        buf.writeln();
        buf.writeln('### Dynamics');
        buf.writeln('• {whoScoresFirstText} — text describing who scored first (optional)');
        buf.writeln('• {lastRoundOutcomeText} — text describing the last round outcome (optional)');
        buf.writeln();
        buf.writeln('### Per-round outcome text');
        for (int i = 1; i <= (rounds ?? 3); i++) {
          buf.writeln('• {round${i}OutcomeText} — narrative text for round $i outcome (optional)');
        }
        buf.writeln();
        buf.writeln('EVERY entry MUST use {choiceS}/{choiceP} variables — never write literal option names.');
        buf.writeln('Use {round1OutcomeText}, {round2OutcomeText}, etc. to compose round-by-round narration.');
        break;

      case BankType.duelFirstTo:
        buf.writeln('IMPORTANT: You MUST use these variable placeholders in EVERY text entry.');
        buf.writeln('Do NOT hard-code choice names — use the variables so values are injected at runtime.');
        buf.writeln();
        buf.writeln('• {numRounds} — total number of rounds played');
        buf.writeln();
        final maxRounds = (targetScore != null) ? (targetScore * 2 - 1) : 5;
        for (int i = 1; i <= maxRounds; i++) {
          buf.writeln('• {choiceS$i} — spectator\'s choice at round $i');
        }
        buf.writeln();
        for (int i = 1; i <= maxRounds; i++) {
          buf.writeln('• {choiceP$i} — performer\'s choice at round $i');
        }
        buf.writeln();
        buf.writeln('• {scoreX} — spectator\'s score');
        buf.writeln('• {scoreY} — performer\'s score');
        buf.writeln();
        buf.writeln('IMPORTANT: since the number of rounds varies, only reference {choiceSN}/{choicePN} up to {numRounds}.');
        buf.writeln('EVERY entry MUST use these variables — never write literal option names.');
        break;

      case BankType.duelSequences:
        break; // Handled by _generateDuelSequencesPrompt

      case BankType.freewheel:
        buf.writeln('No placeholder variables are available for free will mode.');
        buf.writeln('Write the object names and actions directly in the text.');
        buf.writeln('The key already encodes which object goes where.');
        break;
    }
    buf.writeln();

    // ══════════ STRUCTURE RULES ══════════
    buf.writeln('========================');
    buf.writeln('STRUCTURE RULES (VERY IMPORTANT)');
    buf.writeln('========================');
    buf.writeln('Each entry MUST follow this logic:');
    buf.writeln();
    switch (bankType) {
      case BankType.duelFirstTo:
        buf.writeln('1) Line 1: Use {numRounds} naturally (e.g. "En {numRounds} manches" or "It took {numRounds} rounds")');
        break;
      case BankType.duelSequences:
        break; // Handled by _generateDuelSequencesPrompt
      case BankType.freewheel:
        buf.writeln('1) Line 1: State which object the spectator chose for each action');
        break;
      case BankType.choicesBucket:
        buf.writeln('1) Use {choiceS1}, {choiceS2}, etc. and {choiceP1}, {choiceP2}, etc. to reference choices.');
        buf.writeln('   NEVER hard-code option names — ALWAYS use {choiceS}/{choiceP} variables.');
        break;
      case BankType.duelFixedRounds:
        buf.writeln('1) Use {choiceS1}, {choiceS2}, etc. and {choiceP1}, {choiceP2}, etc. to reference choices.');
        buf.writeln('   NEVER hard-code option names — ALWAYS use {choiceS}/{choiceP} variables.');
        break;
      default:
        buf.writeln('1) Line 1: use variables to reference choices (never hard-code option names)');
        break;
    }

    switch (bankType) {
      case BankType.choicesExactSequence:
        break;
      case BankType.choicesBucket:
        buf.writeln('2) One or more lines that EXPLICITLY describe:');
        buf.writeln('   - the exact hit/miss pattern (which rounds were hits, which were misses)');
        buf.writeln('   - whether the overall result was expected or surprising');
        buf.writeln('   - the narrative impact of WHERE hits and misses fell (beginning, middle, end)');
        buf.writeln('3) A final signature line that questions control or free will');
        break;
      case BankType.duelFixedRounds:
        buf.writeln('2) One or more lines that EXPLICITLY describe:');
        buf.writeln('   - how many rounds the spectator won vs the performer');
        buf.writeln('   - how ties played out');
        buf.writeln('   - WHEN the wins happened (beginning, middle, end)');
        buf.writeln('3) A final signature line that questions control or free will');
        break;
      case BankType.duelFirstTo:
        buf.writeln('2) One or more lines that EXPLICITLY describe:');
        buf.writeln('   - who won and by how much');
        buf.writeln('   - whether the loser had a chance');
        buf.writeln('   - WHEN the decisive moment happened');
        buf.writeln('3) A final signature line that questions control or free will');
        break;
      case BankType.duelSequences:
        break; // Handled by _generateDuelSequencesPrompt
      case BankType.freewheel:
        buf.writeln('2) One or more lines that EXPLICITLY describe:');
        buf.writeln('   - which object the spectator kept, gave, and left');
        buf.writeln('   - why that choice feels meaningful');
        buf.writeln('3) A final signature line that questions control or free will');
        break;
    }
    buf.writeln();
    buf.writeln('You MUST clearly indicate:');
    buf.writeln('- "at the beginning"');
    buf.writeln('- "in the middle"');
    buf.writeln('- "at the end"');
    buf.writeln('or equivalent natural phrasing');
    buf.writeln();
    buf.writeln('DO NOT use round numbers.');
    buf.writeln();

    // ══════════ WRITING CONSTRAINTS ══════════
    buf.writeln('========================');
    buf.writeln('WRITING CONSTRAINTS');
    buf.writeln('========================');
    buf.writeln('- No colons');
    buf.writeln('- No quotation marks');
    buf.writeln('- No arrows');
    buf.writeln('- No metaphors that hide the action');
    buf.writeln('- No vague poetic wording');
    buf.writeln('- Make it sound like notes typed quickly on a phone');
    buf.writeln();
    buf.writeln('BAD EXAMPLES (DO NOT DO THIS)');
    buf.writeln('- "A frisson appears"');
    buf.writeln('- "Rideau"');
    buf.writeln('- "Clin d\'oeil final"');
    buf.writeln('- "Tout en douceur"');
    buf.writeln();
    buf.writeln('GOOD EXAMPLES (STYLE ONLY)');
    buf.writeln('- "I will let you win once, at the end"');
    buf.writeln('- "I will be right at the beginning, then step back"');
    buf.writeln('- "I will miss on purpose, just to give you that feeling"');
    buf.writeln();

    // ══════════ EXPECTED JSON ══════════
    buf.writeln('========================');
    buf.writeln('EXPECTED JSON (STRICT)');
    buf.writeln('========================');
    buf.writeln('{');
    buf.writeln('  "meta": {');
    buf.writeln('    "preset": "$presetStr",');
    buf.writeln('    "mode": "$modeStr",');
    buf.writeln('    "language": "$languageCode",');
    buf.writeln('    "tense": "$tense",');
    buf.writeln('    "style": "$style",');

    switch (bankType) {
      case BankType.choicesExactSequence:
        break;
      case BankType.choicesBucket:
        buf.writeln('    "rounds": $rounds');
        break;
      case BankType.duelFixedRounds:
        buf.writeln('    "rounds": $rounds');
        break;
      case BankType.duelFirstTo:
        buf.writeln('    "targetScore": $targetScore');
        break;
      case BankType.duelSequences:
        break; // Handled by _generateDuelSequencesPrompt
      case BankType.freewheel:
        buf.write('    "rounds": 1');
        break;
    }

    buf.writeln('  },');
    buf.writeln('  "entries": {');

    for (int i = 0; i < expectedKeys.length; i++) {
      final comma = i < expectedKeys.length - 1 ? ',' : '';
      buf.writeln('    "${expectedKeys[i]}": "<your text>"$comma');
    }

    buf.writeln('  }');
    buf.writeln('}');
    buf.writeln();
    buf.writeln('Final reminders:');
    buf.writeln('- One entry per key');
    buf.writeln('- No missing keys');
    buf.writeln('- Each value must be a non-empty string');
    buf.writeln('- Output JSON only');
    if (examples != null && examples.isNotEmpty) {
      buf.writeln('- Every entry must read as if written by the same author as the performer examples above. Match their voice exactly.');
    }

    return BankPrompt(
      system: _systemMessage(languageCode),
      user: buf.toString(),
      hasExamples: examples != null && examples.isNotEmpty,
    );
  }

  // ─── Example scenario generation ────────────────────────────────

  /// Generate representative example scenarios for the performer to fill.
  static List<ExampleScenario> generateExampleScenarios({
    required BankType bankType,
    required String languageCode,
    int? rounds,
    List<String>? options,
    int? targetScore,
    List<String>? freewheelObjects,
    String? performerKey,
    List<int>? performerSequenceIndices,
  }) {
    final isFr = languageCode.startsWith('fr');

    switch (bankType) {
      case BankType.choicesExactSequence:
        return _choicesExactScenarios(
            isFr, rounds ?? 3, options ?? [], performerKey,
            performerSequenceIndices);
      case BankType.choicesBucket:
        return _choicesBucketScenarios(isFr, rounds ?? 3);
      case BankType.duelFixedRounds:
        return _duelFixedScenarios(isFr, rounds ?? 3);
      case BankType.duelFirstTo:
        return _duelFirstToScenarios(isFr, targetScore ?? 3);
      case BankType.duelSequences:
        return _duelSequencesScenarios(
            isFr, rounds ?? 3, options ?? [], performerKey,
            performerSequenceIndices);
      case BankType.freewheel:
        return _freewheelScenarios(isFr, freewheelObjects ?? []);
    }
  }

  // ── Choices exact_sequence scenarios ──

  static List<ExampleScenario> _choicesExactScenarios(
    bool isFr,
    int rounds,
    List<String> options,
    String? performerKey,
    List<int>? performerSequenceIndices,
  ) {
    if (options.length < 2 || rounds < 1) return [];

    // Convert performer sequence indices to digit key (e.g. [1,0,1] → "212")
    String? perfDigits;
    if (performerSequenceIndices != null &&
        performerSequenceIndices.length == rounds) {
      perfDigits = performerSequenceIndices.map((i) => i + 1).join();
    } else if (performerKey != null && performerKey.isNotEmpty) {
      // Fallback: try display-format conversion (e.g. "GDG" → "212")
      final buf = StringBuffer();
      for (final ch in performerKey.split('')) {
        final idx = options.indexWhere(
            (o) => o.isNotEmpty && o[0].toUpperCase() == ch.toUpperCase());
        if (idx >= 0) {
          buf.write(idx + 1);
        } else {
          break;
        }
      }
      if (buf.length == rounds) {
        perfDigits = buf.toString();
      }
    }

    String labelKey(String key) {
      return key
          .split('')
          .map((d) {
            final idx = int.parse(d) - 1;
            return idx < options.length ? options[idx] : '?';
          })
          .join(', ');
    }

    // Build a token for each option: initial letter, with number suffix if collisions
    final initials = options.map((o) => o.isNotEmpty ? o[0].toUpperCase() : '?').toList();
    final letterCount = <String, int>{};
    for (final l in initials) {
      letterCount[l] = (letterCount[l] ?? 0) + 1;
    }
    final letterIndex = <String, int>{};
    final optionTokens = <String>[];
    for (final l in initials) {
      if (letterCount[l]! > 1) {
        letterIndex[l] = (letterIndex[l] ?? 0) + 1;
        optionTokens.add('$l${letterIndex[l]}');
      } else {
        optionTokens.add(l);
      }
    }

    String displayKeyFor(String key) {
      return key.split('').map((d) {
        final idx = int.parse(d) - 1;
        return idx < optionTokens.length ? optionTokens[idx] : d;
      }).join();
    }

    List<bool> hitPositions(String key) {
      if (perfDigits == null) return List.filled(rounds, false);
      return List.generate(
          key.length, (i) => i < perfDigits!.length && key[i] == perfDigits[i]);
    }

    String flipDigit(String digit) {
      final d = int.parse(digit);
      for (int n = 1; n <= options.length; n++) {
        if (n != d) return '$n';
      }
      return digit;
    }

    final scenarios = <ExampleScenario>[];
    final usedKeys = <String>{};

    void addScenario(String key) {
      if (usedKeys.contains(key)) return;
      usedKeys.add(key);
      final label = labelKey(key);
      final hp = hitPositions(key);
      final hits = hp.where((h) => h).length;
      final misses = rounds - hits;
      final perfLabel = perfDigits != null ? labelKey(perfDigits!) : null;

      scenarios.add(_buildChoicesExactScenario(
        isFr: isFr,
        key: key,
        displayKey: displayKeyFor(key),
        label: label,
        performerLabel: perfLabel,
        hits: hits,
        misses: misses,
        hitPos: hp,
        rounds: rounds,
        options: options,
      ));
    }

    if (perfDigits != null) {
      // 1. All hits
      addScenario(perfDigits);

      // 2. All misses
      addScenario(perfDigits.split('').map(flipDigit).join());

      // 3. One miss at start
      if (rounds >= 2) {
        addScenario(flipDigit(perfDigits[0]) + perfDigits.substring(1));
      }

      // 4. Two misses (start + end) if rounds >= 3
      if (rounds >= 3) {
        addScenario(flipDigit(perfDigits[0]) +
            perfDigits.substring(1, rounds - 1) +
            flipDigit(perfDigits[rounds - 1]));
      }

      // 5. One miss at end
      if (rounds >= 2) {
        addScenario(perfDigits.substring(0, rounds - 1) +
            flipDigit(perfDigits[rounds - 1]));
      }
    } else {
      // No performer key: pick diverse sequences with descriptive summaries
      final allSame = List.filled(rounds, '1').join();
      final alternating =
          List.generate(rounds, (i) => i.isEven ? '1' : '2').join();
      final reversed =
          List.generate(rounds, (i) => i.isEven ? '2' : '1').join();

      for (final key in [allSame, alternating, reversed]) {
        if (usedKeys.contains(key)) continue;
        usedKeys.add(key);
        final label = labelKey(key);
        scenarios.add(_buildChoicesExactNoPerformerScenario(
          isFr: isFr,
          key: key,
          displayKey: displayKeyFor(key),
          label: label,
          rounds: rounds,
          options: options,
        ));
      }
    }

    return scenarios.take(5).toList();
  }

  static ExampleScenario _buildChoicesExactScenario({
    required bool isFr,
    required String key,
    required String displayKey,
    required String label,
    required String? performerLabel,
    required int hits,
    required int misses,
    required List<bool> hitPos,
    required int rounds,
    required List<String> options,
  }) {
    // Summary
    String summary;
    if (hits == rounds) {
      summary = isFr
          ? '$hits/$rounds — Correspondance parfaite'
          : '$hits/$rounds — Perfect match';
    } else if (hits == 0) {
      summary = isFr
          ? '0/$rounds — Aucune correspondance'
          : '0/$rounds — No match';
    } else {
      summary = isFr
          ? '$hits/$rounds — $misses ${misses == 1 ? "écart" : "écarts"}'
          : '$hits/$rounds — $misses ${misses == 1 ? "miss" : "misses"}';
    }

    // Tooltip — rich round-by-round description
    final tb = StringBuffer();
    final spectLabels = label.split(', ');
    final perfLabels = performerLabel?.split(', ');

    // Header: sequences
    tb.writeln(isFr
        ? 'Spectateur : $label'
        : 'Spectator: $label');
    if (performerLabel != null) {
      tb.writeln(isFr
          ? 'Performer : $performerLabel'
          : 'Performer: $performerLabel');
    }
    tb.writeln();

    // Round-by-round detail
    for (int i = 0; i < rounds; i++) {
      final pos = _positionLabel(i, rounds, isFr);
      final spectChoice = i < spectLabels.length ? spectLabels[i] : '?';
      final perfChoice = perfLabels != null && i < perfLabels.length
          ? perfLabels[i]
          : null;
      final isHit = hitPos[i];
      final mark = isHit ? (isFr ? 'HIT' : 'HIT') : (isFr ? 'MISS' : 'MISS');

      if (perfChoice != null) {
        tb.writeln('$pos $spectChoice vs $perfChoice — $mark');
      } else {
        tb.writeln('$pos $spectChoice');
      }
    }

    // Summary line
    tb.writeln();
    if (hits == rounds) {
      tb.write(isFr
          ? 'Résultat : correspondance parfaite ($hits/$rounds)'
          : 'Result: perfect match ($hits/$rounds)');
    } else if (hits == 0) {
      tb.write(isFr
          ? 'Résultat : aucune correspondance (0/$rounds)'
          : 'Result: no match (0/$rounds)');
    } else {
      final missPositions = <String>[];
      final hitPositions = <String>[];
      for (int i = 0; i < hitPos.length; i++) {
        final pos = _positionLabel(i, rounds, isFr);
        if (hitPos[i]) {
          hitPositions.add(pos.toLowerCase());
        } else {
          missPositions.add(pos.toLowerCase());
        }
      }
      tb.write(isFr
          ? 'Résultat : $hits/$rounds — MISS ${missPositions.join(", ")}'
          : 'Result: $hits/$rounds — MISS ${missPositions.join(", ")}');
    }

    return ExampleScenario(
      key: key,
      displayKey: displayKey,
      sequenceLabelled: label,
      summary: summary,
      tooltip: tb.toString(),
    );
  }

  static ExampleScenario _buildChoicesExactNoPerformerScenario({
    required bool isFr,
    required String key,
    required String displayKey,
    required String label,
    required int rounds,
    required List<String> options,
  }) {
    // Describe the pattern
    final digits = key.split('').map(int.parse).toList();
    final allSame = digits.every((d) => d == digits[0]);
    final uniqueCount = digits.toSet().length;

    String summary;
    String tooltip;

    if (allSame) {
      final choiceName = digits[0] - 1 < options.length
          ? options[digits[0] - 1]
          : '?';
      summary = isFr
          ? 'Toujours $choiceName'
          : 'Always $choiceName';
      tooltip = isFr
          ? 'Le spectateur choisit $choiceName à chaque round\nSéquence $label'
          : 'The spectator picks $choiceName every round\nSequence $label';
    } else if (uniqueCount == 2) {
      summary = isFr
          ? 'Alternance — $label'
          : 'Alternating — $label';
      tooltip = isFr
          ? 'Le spectateur alterne entre les options\nSéquence $label'
          : 'The spectator alternates between options\nSequence $label';
    } else {
      summary = isFr
          ? 'Mixte — $label'
          : 'Mixed — $label';
      tooltip = isFr
          ? 'Le spectateur fait des choix variés\nSéquence $label'
          : 'The spectator makes varied choices\nSequence $label';
    }

    return ExampleScenario(
      key: key,
      displayKey: displayKey,
      sequenceLabelled: label,
      summary: summary,
      tooltip: tooltip,
    );
  }

  // ── Choices bucket scenarios ──

  static List<ExampleScenario> _choicesBucketScenarios(
      bool isFr, int rounds) {
    final scenarios = <ExampleScenario>[];

    void add(String pattern) {
      final hits = pattern.split('').where((c) => c == 'H').length;
      final misses = rounds - hits;
      final summary = isFr
          ? '$pattern — $hits H / $misses M'
          : '$pattern — $hits H / $misses M';

      final tooltip = isFr
          ? 'Pattern: ${pattern.split('').asMap().entries.map((e) => 'Round ${e.key + 1}: ${e.value == 'H' ? 'Hit' : 'Miss'}').join('\n')}'
          : 'Pattern: ${pattern.split('').asMap().entries.map((e) => 'Round ${e.key + 1}: ${e.value == 'H' ? 'Hit' : 'Miss'}').join('\n')}';

      scenarios.add(ExampleScenario(
        key: pattern,
        displayKey: pattern,
        sequenceLabelled: pattern,
        summary: summary,
        tooltip: tooltip,
      ));
    }

    // Show a few representative patterns
    add('H' * rounds); // all hits
    add('M' * rounds); // all misses
    if (rounds >= 2) add('H' + 'M' * (rounds - 1)); // hit then misses
    if (rounds >= 2) add('M' * (rounds - 1) + 'H'); // misses then hit
    if (rounds >= 3) add('H' + 'M' + 'H' * (rounds - 2)); // HMH...

    return scenarios.take(5).toList();
  }

  // ── Duel fixed rounds scenarios ──

  static List<ExampleScenario> _duelFixedScenarios(bool isFr, int rounds) {
    final scenarios = <ExampleScenario>[];

    void add(int sWins, int pWins) {
      final ties = rounds - sWins - pWins;
      final key = '$rounds|$sWins-$pWins';

      String summary;
      if (sWins == rounds) {
        summary = isFr ? 'Spectateur gagne tout' : 'Spectator wins all';
      } else if (pWins == rounds) {
        summary = isFr ? 'Performer gagne tout' : 'Performer wins all';
      } else if (sWins == pWins) {
        summary = isFr ? 'Égalité $sWins-$pWins' : 'Tie $sWins-$pWins';
      } else {
        summary = isFr
            ? 'Spectateur $sWins — Performer $pWins'
            : 'Spectator $sWins — Performer $pWins';
      }
      if (ties > 0) {
        summary += isFr ? ' ($ties ${ties == 1 ? "nul" : "nuls"})' : ' ($ties ${ties == 1 ? "tie" : "ties"})';
      }

      final tb = StringBuffer();
      tb.writeln(isFr
          ? 'Le spectateur a gagné $sWins ${sWins == 1 ? "round" : "rounds"}'
          : 'The spectator won $sWins ${sWins == 1 ? "round" : "rounds"}');
      tb.writeln(isFr
          ? 'Le performer a gagné $pWins ${pWins == 1 ? "round" : "rounds"}'
          : 'The performer won $pWins ${pWins == 1 ? "round" : "rounds"}');
      if (ties > 0) {
        tb.write(isFr
            ? '$ties ${ties == 1 ? "round s\'est terminé en égalité" : "rounds se sont terminés en égalité"}'
            : '$ties ${ties == 1 ? "round ended in a tie" : "rounds ended in a tie"}');
      }

      scenarios.add(ExampleScenario(
        key: key,
        displayKey: key,
        sequenceLabelled: key,
        summary: summary,
        tooltip: tb.toString().trimRight(),
      ));
    }

    add(rounds, 0); // spectator dominates
    add(0, rounds); // performer dominates
    if (rounds >= 2) add(1, rounds - 1);
    if (rounds >= 3) add(rounds - 1, 1);
    if (rounds >= 3) {
      final half = rounds ~/ 2;
      add(half, half); // close + ties
    }

    return scenarios.take(5).toList();
  }

  // ── Duel first-to scenarios ──

  static List<ExampleScenario> _duelFirstToScenarios(
      bool isFr, int target) {
    final scenarios = <ExampleScenario>[];

    void add(String winner, int loserScore) {
      final key = 'FT${target}_${winner}_$target-$loserScore';
      final isSpectator = winner == 'S';
      final winnerName = isSpectator
          ? (isFr ? 'spectateur' : 'spectator')
          : (isFr ? 'performer' : 'performer');

      final summary = isFr
          ? '${isSpectator ? "Spectateur" : "Performer"} gagne $target-$loserScore'
          : '${isSpectator ? "Spectator" : "Performer"} wins $target-$loserScore';

      final tb = StringBuffer();
      tb.writeln(isFr
          ? 'Le $winnerName gagne en atteignant $target en premier'
          : 'The $winnerName wins by reaching $target first');
      tb.writeln(isFr
          ? 'Le perdant avait $loserScore ${loserScore == 1 ? "point" : "points"}'
          : 'The loser had $loserScore ${loserScore == 1 ? "point" : "points"}');
      if (loserScore == 0) {
        tb.write(isFr
            ? 'Victoire écrasante sans opposition'
            : 'Dominant win with no opposition');
      } else if (loserScore == target - 1) {
        tb.write(isFr
            ? 'Match très serré, un seul point d\'écart'
            : 'Very close match, only one point apart');
      }

      scenarios.add(ExampleScenario(
        key: key,
        displayKey: key,
        sequenceLabelled: key,
        summary: summary,
        tooltip: tb.toString().trimRight(),
      ));
    }

    add('S', 0); // spectator dominates
    add('P', 0); // performer dominates
    add('S', target - 1); // spectator barely wins
    add('P', target - 1); // performer barely wins
    if (target >= 3) add('S', target ~/ 2); // medium

    return scenarios.take(5).toList();
  }

  // ── Duel sequences scenarios ──

  static List<ExampleScenario> _duelSequencesScenarios(
    bool isFr,
    int rounds,
    List<String> options,
    String? performerKey,
    List<int>? performerSequenceIndices,
  ) {
    if (options.length < 2 || rounds < 1) return [];

    final m = options.length;

    // Resolve performer sequence indices
    List<int>? perfIndices;
    if (performerSequenceIndices != null &&
        performerSequenceIndices.length == rounds) {
      perfIndices = performerSequenceIndices;
    } else if (performerKey != null && performerKey.isNotEmpty) {
      // Try to parse from display key
      final parts = performerKey.split(RegExp(r'[,\s]+'));
      if (parts.length == rounds) {
        final indices = <int>[];
        for (final part in parts) {
          final idx = options.indexWhere(
              (o) => o.toLowerCase() == part.trim().toLowerCase());
          if (idx >= 0) {
            indices.add(idx);
          } else {
            break;
          }
        }
        if (indices.length == rounds) perfIndices = indices;
      }
    }

    String seqKey(List<int> indices) => 'SEQ_${indices.join("_")}';

    String labelFor(List<int> indices) =>
        indices.map((i) => i < options.length ? options[i] : '?').join(', ');

    final scenarios = <ExampleScenario>[];
    final usedKeys = <String>{};

    void addScenario(List<int> spectIndices) {
      final key = seqKey(spectIndices);
      if (usedKeys.contains(key)) return;
      usedKeys.add(key);

      final spectLabel = labelFor(spectIndices);
      final perfLabel = perfIndices != null ? labelFor(perfIndices) : null;

      String summary;
      String tooltip;

      if (perfIndices != null) {
        int sWins = 0;
        int pWins = 0;
        int ties = 0;
        for (int i = 0; i < rounds; i++) {
          if (spectIndices[i] == perfIndices[i]) {
            ties++;
          } else if ((spectIndices[i] - perfIndices[i]) % m == 1) {
            sWins++;
          } else {
            pWins++;
          }
        }
        summary = isFr
            ? 'Spectateur $sWins — Performer $pWins${ties > 0 ? " ($ties ${ties == 1 ? "nul" : "nuls"})" : ""}'
            : 'Spectator $sWins — Performer $pWins${ties > 0 ? " ($ties ${ties == 1 ? "tie" : "ties"})" : ""}';

        final tb = StringBuffer();
        tb.writeln(isFr
            ? 'Spectateur : $spectLabel'
            : 'Spectator: $spectLabel');
        tb.writeln(isFr
            ? 'Performer : $perfLabel'
            : 'Performer: $perfLabel');
        tb.writeln();
        for (int i = 0; i < rounds; i++) {
          final pos = _positionLabel(i, rounds, isFr);
          final sChoice = spectIndices[i] < options.length ? options[spectIndices[i]] : '?';
          final pChoice = perfIndices[i] < options.length ? options[perfIndices[i]] : '?';
          String result;
          if (spectIndices[i] == perfIndices[i]) {
            result = isFr ? 'EGALITE' : 'TIE';
          } else if ((spectIndices[i] - perfIndices[i]) % m == 1) {
            result = isFr ? 'SPECTATEUR GAGNE' : 'SPECTATOR WINS';
          } else {
            result = isFr ? 'PERFORMER GAGNE' : 'PERFORMER WINS';
          }
          tb.writeln('$pos $sChoice vs $pChoice — $result');
        }
        tooltip = tb.toString().trimRight();
      } else {
        summary = isFr
            ? 'Séquence : $spectLabel'
            : 'Sequence: $spectLabel';
        tooltip = isFr
            ? 'Séquence spectateur : $spectLabel'
            : 'Spectator sequence: $spectLabel';
      }

      scenarios.add(ExampleScenario(
        key: key,
        displayKey: key,
        sequenceLabelled: spectLabel,
        summary: summary,
        tooltip: tooltip,
      ));
    }

    if (perfIndices != null) {
      // 1. Same as performer (all ties)
      addScenario(List<int>.from(perfIndices));

      // 2. All different from performer
      addScenario(perfIndices.map((i) => (i + 1) % m).toList());

      // 3. One difference at start
      if (rounds >= 2) {
        final seq = List<int>.from(perfIndices);
        seq[0] = (seq[0] + 1) % m;
        addScenario(seq);
      }

      // 4. One difference at end
      if (rounds >= 2) {
        final seq = List<int>.from(perfIndices);
        seq[rounds - 1] = (seq[rounds - 1] + 1) % m;
        addScenario(seq);
      }

      // 5. Two differences (start + end) if rounds >= 3
      if (rounds >= 3) {
        final seq = List<int>.from(perfIndices);
        seq[0] = (seq[0] + 1) % m;
        seq[rounds - 1] = (seq[rounds - 1] + 1) % m;
        addScenario(seq);
      }
    } else {
      // No performer key: diverse sequences
      addScenario(List.filled(rounds, 0));
      addScenario(List.generate(rounds, (i) => i % m));
      addScenario(List.generate(rounds, (i) => (m - 1 - (i % m))));
    }

    return scenarios.take(5).toList();
  }

  // ── Freewheel scenarios ──

  static List<ExampleScenario> _freewheelScenarios(
      bool isFr, List<String> objects) {
    if (objects.length < 3) return [];

    final perms = [
      [0, 1, 2],
      [0, 2, 1],
      [1, 0, 2],
      [2, 0, 1],
    ];
    final scenarios = <ExampleScenario>[];

    for (final perm in perms) {
      final key =
          'TAKE:${objects[perm[0]]}|GIVE:${objects[perm[1]]}|TABLE:${objects[perm[2]]}';

      final tb = StringBuffer();
      tb.writeln(isFr
          ? 'Le spectateur garde ${objects[perm[0]]}'
          : 'The spectator keeps ${objects[perm[0]]}');
      tb.writeln(isFr
          ? 'Il donne ${objects[perm[1]]} au performer'
          : 'They give ${objects[perm[1]]} to the performer');
      tb.write(isFr
          ? 'Il laisse ${objects[perm[2]]} sur la table'
          : 'They leave ${objects[perm[2]]} on the table');

      final summary = isFr
          ? 'Garde ${objects[perm[0]]}, donne ${objects[perm[1]]}'
          : 'Keeps ${objects[perm[0]]}, gives ${objects[perm[1]]}';

      scenarios.add(ExampleScenario(
        key: key,
        displayKey: key,
        sequenceLabelled: key,
        summary: summary,
        tooltip: tb.toString(),
      ));
    }

    return scenarios;
  }

  /// Human-readable position label for a round index.
  static String _positionLabel(int index, int total, bool isFr) {
    if (total <= 1) return isFr ? 'Round 1' : 'Round 1';
    if (index == 0) return isFr ? 'Début' : 'Start';
    if (index == total - 1) return isFr ? 'Fin' : 'End';
    return isFr ? 'Milieu' : 'Middle';
  }
}

/// A representative scenario for the performer to write an example text.
class ExampleScenario {
  final String key;
  final String displayKey;
  final String sequenceLabelled;
  final String summary;
  final String tooltip;

  const ExampleScenario({
    required this.key,
    required this.displayKey,
    required this.sequenceLabelled,
    required this.summary,
    required this.tooltip,
  });
}
