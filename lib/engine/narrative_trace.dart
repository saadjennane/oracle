import '../models/models.dart';
import 'narrative_engine_v2/narrative_assembler.dart';

/// Narrative engine version
enum NarrativeEngineVersion { v1, v2 }

/// Outcome classification for narrative generation
enum OutcomeType {
  allHit,    // 0 misses
  oneMiss,   // exactly 1 miss
  twoMiss,   // exactly 2 misses
  allMiss,   // all rounds are misses
  mixed,     // >2 misses but not all (for 4+ rounds)
}

/// Pattern type for spectator choices
enum SpectatorPattern {
  repeatHeavy,   // Same choice dominates (≥60%)
  alternating,   // Frequent switches (switchCount ≥ rounds-1)
  mixed,         // Neither extreme
}

/// Performer relation to spectator (GAME mode only)
enum PerformerRelation {
  allMatch,      // Performer matched all spectator choices
  allOpposite,   // Performer was opposite on all
  mostlyMatch,   // >50% match
  mostlyOpposite,// >50% opposite
  mixed,         // Roughly equal
}

/// Complete narrative trace for debugging and generation
class NarrativeTrace {
  // ═══════════════════════════════════════════════════════
  // INPUTS
  // ═══════════════════════════════════════════════════════
  final PredictionMode mode;
  final Language language;
  final List<String> options;
  final int roundsCount;
  final List<String> spectatorChoices;
  final List<String> performerChoices; // Empty if DIRECT mode

  // ═══════════════════════════════════════════════════════
  // COMPUTED
  // ═══════════════════════════════════════════════════════
  final int hitCount;
  final int missCount;
  final List<int> missIndices; // 0-indexed internally
  final OutcomeType outcomeType;

  final int switchCount;
  final String dominantOption;
  final int dominantCount;
  final int streakMaxLen;
  final String streakOption;
  final SpectatorPattern spectatorPattern;

  // GAME mode only
  final PerformerRelation? performerRelation;
  final String? dominantPerformer;

  // ═══════════════════════════════════════════════════════
  // PLAN (template selection)
  // ═══════════════════════════════════════════════════════
  final int seed;
  final int hookIndex;
  final int middleIndex;
  final int closerIndex;
  final bool includePerformer;
  final bool includeIntentionalMiss;
  final List<int> mentionedMissRounds; // 0-indexed

  // ═══════════════════════════════════════════════════════
  // OUTPUT
  // ═══════════════════════════════════════════════════════
  final String generatedText;
  final int wordCount;

  // ═══════════════════════════════════════════════════════
  // V2 TRACE (optional, filled when using V2 engine)
  // ═══════════════════════════════════════════════════════
  final NarrativeEngineVersion engineVersion;
  final AssemblyTrace? v2Trace;

  const NarrativeTrace({
    // Inputs
    required this.mode,
    required this.language,
    required this.options,
    required this.roundsCount,
    required this.spectatorChoices,
    required this.performerChoices,
    // Computed
    required this.hitCount,
    required this.missCount,
    required this.missIndices,
    required this.outcomeType,
    required this.switchCount,
    required this.dominantOption,
    required this.dominantCount,
    required this.streakMaxLen,
    required this.streakOption,
    required this.spectatorPattern,
    this.performerRelation,
    this.dominantPerformer,
    // Plan
    required this.seed,
    required this.hookIndex,
    required this.middleIndex,
    required this.closerIndex,
    required this.includePerformer,
    required this.includeIntentionalMiss,
    required this.mentionedMissRounds,
    // Output
    required this.generatedText,
    required this.wordCount,
    // V2
    this.engineVersion = NarrativeEngineVersion.v1,
    this.v2Trace,
  });

  /// Check if this is GAME mode
  bool get isGameMode => mode == PredictionMode.game;

  /// Check if this is DIRECT mode
  bool get isDirectMode => mode == PredictionMode.direct;

  /// Get miss indices as 1-indexed for display
  List<int> get missIndices1Indexed => missIndices.map((i) => i + 1).toList();

  /// Build human-readable trace string
  String toTraceString() {
    final buffer = StringBuffer();

    buffer.writeln('═══════════════════════════════════════════════════════');
    buffer.writeln('           ORACLE NARRATIVE TRACE');
    buffer.writeln('═══════════════════════════════════════════════════════');
    buffer.writeln();

    // INPUTS
    buffer.writeln('┌─────────────────────────────────────────────────────┐');
    buffer.writeln('│  SECTION A — INPUTS                                 │');
    buffer.writeln('└─────────────────────────────────────────────────────┘');
    buffer.writeln();
    buffer.writeln('Mode:           ${mode == PredictionMode.game ? "GAME" : "DIRECT"}');
    buffer.writeln('Language:       ${language == Language.french ? "FR" : "EN"}');
    buffer.writeln('Options:        [${options.join(", ")}]');
    buffer.writeln('Rounds:         $roundsCount');
    buffer.writeln();
    buffer.writeln('Spectator:      [${spectatorChoices.join(" → ")}]');
    if (isGameMode) {
      buffer.writeln('Performer:      [${performerChoices.join(" → ")}]');
    }
    buffer.writeln();

    // COMPUTED
    buffer.writeln('┌─────────────────────────────────────────────────────┐');
    buffer.writeln('│  SECTION B — COMPUTED                               │');
    buffer.writeln('└─────────────────────────────────────────────────────┘');
    buffer.writeln();
    if (isGameMode) {
      buffer.writeln('hitCount:       $hitCount');
      buffer.writeln('missCount:      $missCount');
      buffer.writeln('missIndices:    ${missIndices.isEmpty ? "[]" : "[${missIndices1Indexed.join(", ")}]"} (1-indexed)');
      buffer.writeln('outcomeType:    ${outcomeType.name}');
      if (performerRelation != null) {
        buffer.writeln('performerRel:   ${performerRelation!.name}');
      }
      if (dominantPerformer != null) {
        buffer.writeln('dominantPerf:   $dominantPerformer');
      }
      buffer.writeln();
    }
    buffer.writeln('switchCount:    $switchCount');
    buffer.writeln('dominantOpt:    $dominantOption ($dominantCount/$roundsCount)');
    buffer.writeln('streakMaxLen:   $streakMaxLen ($streakOption)');
    buffer.writeln('spectPattern:   ${spectatorPattern.name}');
    buffer.writeln();

    // PLAN
    buffer.writeln('┌─────────────────────────────────────────────────────┐');
    buffer.writeln('│  SECTION C — PLAN                                   │');
    buffer.writeln('└─────────────────────────────────────────────────────┘');
    buffer.writeln();
    buffer.writeln('engine:         ${engineVersion.name}');
    buffer.writeln('seed:           $seed');
    if (engineVersion == NarrativeEngineVersion.v2 && v2Trace != null) {
      buffer.writeln('v2Style:        ${v2Trace!.style.name}');
      buffer.writeln('v2Tone:         ${v2Trace!.tone.name}');
      buffer.writeln('hookId:         ${v2Trace!.hookId}');
      if (v2Trace!.performerLineId != null) {
        buffer.writeln('performerLine:  ${v2Trace!.performerLineId}');
      }
      buffer.writeln('patternLine:    ${v2Trace!.patternLineId}');
      if (v2Trace!.intentLineId != null) {
        buffer.writeln('intentLine:     ${v2Trace!.intentLineId}');
      }
      if (v2Trace!.missLineId != null) {
        buffer.writeln('missLine:       ${v2Trace!.missLineId}');
      }
      buffer.writeln('closer:         ${v2Trace!.closerId}');
    } else {
      buffer.writeln('hookIndex:      $hookIndex');
      buffer.writeln('middleIndex:    $middleIndex');
      buffer.writeln('closerIndex:    $closerIndex');
      buffer.writeln('inclPerformer:  $includePerformer');
      buffer.writeln('inclMissLine:   $includeIntentionalMiss');
      if (mentionedMissRounds.isNotEmpty) {
        buffer.writeln('mentionedMiss:  [${mentionedMissRounds.map((i) => i + 1).join(", ")}]');
      }
    }
    buffer.writeln();

    // OUTPUT
    buffer.writeln('┌─────────────────────────────────────────────────────┐');
    buffer.writeln('│  SECTION D — OUTPUT                                 │');
    buffer.writeln('└─────────────────────────────────────────────────────┘');
    buffer.writeln();
    buffer.writeln('wordCount:      $wordCount');
    buffer.writeln();
    buffer.writeln('─────────────────────────────────────────────────────');
    buffer.writeln(generatedText);
    buffer.writeln('─────────────────────────────────────────────────────');
    buffer.writeln();

    buffer.writeln('═══════════════════════════════════════════════════════');
    buffer.writeln('           END OF TRACE');
    buffer.writeln('═══════════════════════════════════════════════════════');

    return buffer.toString();
  }

  /// Build just inputs section
  String toInputsString() {
    final buffer = StringBuffer();
    buffer.writeln('INPUTS');
    buffer.writeln('------');
    buffer.writeln('Mode:       ${mode == PredictionMode.game ? "GAME" : "DIRECT"}');
    buffer.writeln('Language:   ${language == Language.french ? "FR" : "EN"}');
    buffer.writeln('Options:    [${options.join(", ")}]');
    buffer.writeln('Rounds:     $roundsCount');
    buffer.writeln('Spectator:  [${spectatorChoices.join(" → ")}]');
    if (isGameMode) {
      buffer.writeln('Performer:  [${performerChoices.join(" → ")}]');
    }
    return buffer.toString();
  }

  /// Build just computed section
  String toComputedString() {
    final buffer = StringBuffer();
    buffer.writeln('COMPUTED');
    buffer.writeln('--------');
    if (isGameMode) {
      buffer.writeln('hitCount:     $hitCount');
      buffer.writeln('missCount:    $missCount');
      buffer.writeln('missIndices:  ${missIndices.isEmpty ? "[]" : "[${missIndices1Indexed.join(", ")}]"}');
      buffer.writeln('outcomeType:  ${outcomeType.name}');
      if (performerRelation != null) {
        buffer.writeln('performerRel: ${performerRelation!.name}');
      }
    }
    buffer.writeln('switchCount:  $switchCount');
    buffer.writeln('dominantOpt:  $dominantOption ($dominantCount/$roundsCount)');
    buffer.writeln('streakMax:    $streakMaxLen ($streakOption)');
    buffer.writeln('spectPattern: ${spectatorPattern.name}');
    return buffer.toString();
  }

  /// Build just output section
  String toOutputString() {
    final buffer = StringBuffer();
    buffer.writeln('OUTPUT');
    buffer.writeln('------');
    buffer.writeln('wordCount: $wordCount');
    buffer.writeln();
    buffer.writeln(generatedText);
    return buffer.toString();
  }
}

/// Computes all trace fields from session data
class NarrativeTraceComputer {
  final GameSession session;
  final int seed;

  NarrativeTraceComputer({
    required this.session,
    required this.seed,
  });

  /// Extract spectator choices from rounds
  List<String> get spectatorChoices =>
      session.rounds.map((r) => r.spectatorChoice).toList();

  /// Extract performer choices from rounds (GAME mode)
  List<String> get performerChoices {
    if (session.predictionMode != PredictionMode.game) return [];
    return List.generate(
      session.rounds.length,
      (i) => session.getPerformerChoice(i),
    );
  }

  /// Compute hit/miss data
  (int hits, int misses, List<int> missIdx) computeHitsMisses() {
    if (session.predictionMode != PredictionMode.game) {
      return (0, 0, []);
    }

    int hits = 0;
    int misses = 0;
    final missIdx = <int>[];

    for (int i = 0; i < session.rounds.length; i++) {
      final spec = session.rounds[i].spectatorChoice;
      final perf = session.getPerformerChoice(i);
      if (spec == perf) {
        hits++;
      } else {
        misses++;
        missIdx.add(i);
      }
    }

    return (hits, misses, missIdx);
  }

  /// Classify outcome type
  OutcomeType computeOutcomeType(int hits, int misses, int total) {
    if (misses == 0) return OutcomeType.allHit;
    if (hits == 0) return OutcomeType.allMiss;
    if (misses == 1) return OutcomeType.oneMiss;
    if (misses == 2) return OutcomeType.twoMiss;
    return OutcomeType.mixed;
  }

  /// Count switches in spectator choices
  int computeSwitchCount() {
    int switches = 0;
    final choices = spectatorChoices;
    for (int i = 1; i < choices.length; i++) {
      if (choices[i] != choices[i - 1]) switches++;
    }
    return switches;
  }

  /// Find dominant option and count
  (String option, int count) computeDominant() {
    final counts = <String, int>{};
    for (final choice in spectatorChoices) {
      counts[choice] = (counts[choice] ?? 0) + 1;
    }

    String dominant = spectatorChoices.first;
    int maxCount = 0;
    for (final entry in counts.entries) {
      if (entry.value > maxCount) {
        maxCount = entry.value;
        dominant = entry.key;
      }
    }
    return (dominant, maxCount);
  }

  /// Find longest streak
  (int length, String option) computeLongestStreak() {
    if (spectatorChoices.isEmpty) return (0, '');

    int maxLen = 1;
    String maxOpt = spectatorChoices.first;
    int currentLen = 1;

    for (int i = 1; i < spectatorChoices.length; i++) {
      if (spectatorChoices[i] == spectatorChoices[i - 1]) {
        currentLen++;
        if (currentLen > maxLen) {
          maxLen = currentLen;
          maxOpt = spectatorChoices[i];
        }
      } else {
        currentLen = 1;
      }
    }

    return (maxLen, maxOpt);
  }

  /// Classify spectator pattern
  SpectatorPattern computeSpectatorPattern(int switchCount, int dominantCount, int total) {
    // repeatHeavy: dominant option appears ≥60% of time
    if (dominantCount >= (total * 0.6).ceil()) {
      return SpectatorPattern.repeatHeavy;
    }
    // alternating: switches nearly every round
    if (switchCount >= total - 1) {
      return SpectatorPattern.alternating;
    }
    return SpectatorPattern.mixed;
  }

  /// Compute performer relation (GAME mode only)
  (PerformerRelation, String?) computePerformerRelation() {
    if (session.predictionMode != PredictionMode.game) {
      return (PerformerRelation.mixed, null);
    }

    final perfChoices = performerChoices;
    final specChoices = spectatorChoices;

    // Count matches
    int matches = 0;
    for (int i = 0; i < specChoices.length; i++) {
      if (specChoices[i] == perfChoices[i]) matches++;
    }

    // Find dominant performer choice
    final counts = <String, int>{};
    for (final choice in perfChoices) {
      counts[choice] = (counts[choice] ?? 0) + 1;
    }
    String? dominant;
    int maxCount = 0;
    for (final entry in counts.entries) {
      if (entry.value > maxCount) {
        maxCount = entry.value;
        dominant = entry.key;
      }
    }

    final total = specChoices.length;
    final ratio = matches / total;

    PerformerRelation relation;
    if (matches == total) {
      relation = PerformerRelation.allMatch;
    } else if (matches == 0) {
      relation = PerformerRelation.allOpposite;
    } else if (ratio > 0.5) {
      relation = PerformerRelation.mostlyMatch;
    } else if (ratio < 0.5) {
      relation = PerformerRelation.mostlyOpposite;
    } else {
      relation = PerformerRelation.mixed;
    }

    return (relation, dominant);
  }

  /// Build complete trace (without generated text - that comes later)
  NarrativeTrace buildPartialTrace() {
    final (hits, misses, missIdx) = computeHitsMisses();
    final outcomeType = computeOutcomeType(hits, misses, session.rounds.length);
    final switchCount = computeSwitchCount();
    final (dominant, dominantCount) = computeDominant();
    final (streakLen, streakOpt) = computeLongestStreak();
    final pattern = computeSpectatorPattern(switchCount, dominantCount, session.rounds.length);
    final (perfRelation, perfDominant) = computePerformerRelation();

    final isGame = session.predictionMode == PredictionMode.game;

    return NarrativeTrace(
      // Inputs
      mode: session.predictionMode,
      language: session.language,
      options: session.options,
      roundsCount: session.rounds.length,
      spectatorChoices: spectatorChoices,
      performerChoices: performerChoices,
      // Computed
      hitCount: hits,
      missCount: misses,
      missIndices: missIdx,
      outcomeType: outcomeType,
      switchCount: switchCount,
      dominantOption: dominant,
      dominantCount: dominantCount,
      streakMaxLen: streakLen,
      streakOption: streakOpt,
      spectatorPattern: pattern,
      performerRelation: isGame ? perfRelation : null,
      dominantPerformer: isGame ? perfDominant : null,
      // Plan (will be filled during generation)
      seed: seed,
      hookIndex: 0,
      middleIndex: 0,
      closerIndex: 0,
      includePerformer: isGame,
      includeIntentionalMiss: isGame && misses > 0,
      mentionedMissRounds: missIdx,
      // Output (placeholder)
      generatedText: '',
      wordCount: 0,
    );
  }
}
