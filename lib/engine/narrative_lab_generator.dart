/// Narrative Lab Generator
///
/// Generates canonical scenarios for testing narrative generation.
/// Supports GAME and DIRECT modes with various spectator/performer patterns.

import '../models/models.dart';
import 'narrative_engine_v2/narrative_engine_v2.dart';
import 'narrative_engine_v2/narrative_assembler.dart';

/// A lab scenario with spectator and performer indices
class LabScenario {
  final String id;
  final String name;
  final String description;
  final List<int> spectatorIdx;
  final List<int>? performerIdx; // null for DIRECT mode

  const LabScenario({
    required this.id,
    required this.name,
    required this.description,
    required this.spectatorIdx,
    this.performerIdx,
  });

  /// Get spectator labels from preset options
  List<String> getSpectatorLabels(List<String> labels) {
    return spectatorIdx.map((idx) => labels[idx.clamp(0, labels.length - 1)]).toList();
  }

  /// Get performer labels from preset options (GAME mode only)
  List<String>? getPerformerLabels(List<String> labels) {
    if (performerIdx == null) return null;
    return performerIdx!.map((idx) => labels[idx.clamp(0, labels.length - 1)]).toList();
  }
}

/// A variant of a scenario with different seed
class LabVariant {
  final int seed;
  final String text;
  final String traceString;
  final AssemblyTrace? assemblyTrace;
  final int wordCount;
  final String hookId;
  final String? performerLineId;
  final String patternLineId;
  final String? intentLineId;
  final String? missLineId;
  final String closerId;

  const LabVariant({
    required this.seed,
    required this.text,
    required this.traceString,
    this.assemblyTrace,
    required this.wordCount,
    required this.hookId,
    this.performerLineId,
    required this.patternLineId,
    this.intentLineId,
    this.missLineId,
    required this.closerId,
  });
}

/// Computed summary for a scenario
class LabComputedSummary {
  final int hitCount;
  final int missCount;
  final List<int> missIndices;
  final String outcomeType; // allHit, oneMiss, twoMiss, allMiss, mixed
  final String patternType; // repeatHeavy, alternating, mixed
  final String dominant;
  final int dominantCount;
  final int streakLen;
  final int switchCount;

  const LabComputedSummary({
    required this.hitCount,
    required this.missCount,
    required this.missIndices,
    required this.outcomeType,
    required this.patternType,
    required this.dominant,
    required this.dominantCount,
    required this.streakLen,
    required this.switchCount,
  });

  String toLogString() {
    final buffer = StringBuffer();
    buffer.writeln('Outcome: $outcomeType (hit=$hitCount, miss=$missCount)');
    if (missIndices.isNotEmpty) {
      buffer.writeln('Miss rounds: ${missIndices.map((i) => i + 1).join(", ")}');
    }
    buffer.writeln('Pattern: $patternType');
    buffer.writeln('Dominant: $dominant ($dominantCount times)');
    buffer.writeln('Streak: $streakLen, Switches: $switchCount');
    return buffer.toString();
  }
}

/// A complete scenario result with all variants
class LabScenarioResult {
  final LabScenario scenario;
  final List<String> spectatorLabels;
  final List<String>? performerLabels;
  final LabComputedSummary summary;
  final List<LabVariant> variants;

  const LabScenarioResult({
    required this.scenario,
    required this.spectatorLabels,
    this.performerLabels,
    required this.summary,
    required this.variants,
  });

  /// Generate log string for this scenario
  String toLogString({bool includeVariants = true}) {
    final buffer = StringBuffer();
    buffer.writeln('='.padRight(60, '='));
    buffer.writeln('SCENARIO: ${scenario.name}');
    buffer.writeln('='.padRight(60, '='));
    buffer.writeln('ID: ${scenario.id}');
    buffer.writeln('Description: ${scenario.description}');
    buffer.writeln('');
    buffer.writeln('Spectator: ${spectatorLabels.join(" → ")}');
    if (performerLabels != null) {
      buffer.writeln('Performer: ${performerLabels!.join(" → ")}');
    }
    buffer.writeln('');
    buffer.write(summary.toLogString());

    if (includeVariants) {
      buffer.writeln('');
      buffer.writeln('-'.padRight(40, '-'));
      buffer.writeln('VARIANTS (${variants.length}):');
      for (int i = 0; i < variants.length; i++) {
        final v = variants[i];
        buffer.writeln('');
        buffer.writeln('--- Variant ${i + 1} (seed=${v.seed}) ---');
        buffer.writeln('Hook: ${v.hookId}');
        if (v.performerLineId != null) buffer.writeln('PerformerLine: ${v.performerLineId}');
        buffer.writeln('PatternLine: ${v.patternLineId}');
        if (v.intentLineId != null) buffer.writeln('IntentLine: ${v.intentLineId}');
        if (v.missLineId != null) buffer.writeln('MissLine: ${v.missLineId}');
        buffer.writeln('Closer: ${v.closerId}');
        buffer.writeln('Words: ${v.wordCount}');
        buffer.writeln('');
        buffer.writeln('OUTPUT:');
        buffer.writeln(v.text);
      }
    }

    return buffer.toString();
  }
}

/// Narrative Lab Generator
class NarrativeLabGenerator {
  final Preset preset;
  final int permutationsCount;

  NarrativeLabGenerator({
    required this.preset,
    this.permutationsCount = 5,
  });

  /// Generate all canonical scenarios for this preset
  List<LabScenarioResult> generateCanonicalScenarios() {
    final scenarios = _getCanonicalScenarios();
    final results = <LabScenarioResult>[];

    for (final scenario in scenarios) {
      final result = _generateScenarioResult(scenario);
      results.add(result);
    }

    return results;
  }

  /// Get canonical scenarios based on preset configuration
  List<LabScenario> _getCanonicalScenarios() {
    final rounds = preset.nbRounds;
    final optionsCount = preset.nbOptions;

    if (optionsCount < 2) return [];

    // Determine which scenario set to use
    if (rounds <= 3) {
      if (optionsCount >= 3) {
        return _getScenarios3RoundsTriple();
      } else {
        return _getScenarios3RoundsBinary();
      }
    } else {
      // rounds 4-5+
      if (optionsCount >= 3) {
        return _getScenarios5RoundsTriple();
      } else {
        return _getScenarios5RoundsBinary();
      }
    }
  }

  /// Truncate scenario to match preset rounds
  List<int> _truncate(List<int> seq) {
    if (seq.length <= preset.nbRounds) return seq;
    return seq.sublist(0, preset.nbRounds);
  }

  /// Scenarios for 3 rounds, 2 options (A=0, B=1)
  List<LabScenario> _getScenarios3RoundsBinary() {
    final isGame = preset.predictionMode == PredictionMode.game;

    return [
      LabScenario(
        id: 'S1',
        name: 'AllHit + AlwaysSame(A)',
        description: 'Perfect match, spectator always picks A',
        spectatorIdx: _truncate([0, 0, 0]),
        performerIdx: isGame ? _truncate([0, 0, 0]) : null,
      ),
      LabScenario(
        id: 'S2',
        name: 'AllMiss + AlwaysSame(A)',
        description: 'Complete mismatch, spectator picks A, performer picks B',
        spectatorIdx: _truncate([0, 0, 0]),
        performerIdx: isGame ? _truncate([1, 1, 1]) : null,
      ),
      LabScenario(
        id: 'S3',
        name: 'OneMiss (round2) + RepeatHeavy',
        description: 'One deliberate miss at round 2',
        spectatorIdx: _truncate([0, 0, 0]),
        performerIdx: isGame ? _truncate([0, 1, 0]) : null,
      ),
      LabScenario(
        id: 'S4',
        name: 'TwoMiss (round2&3) + SwitchOnce',
        description: 'Spectator switches mid-game, misses at end',
        spectatorIdx: _truncate([0, 1, 1]),
        performerIdx: isGame ? _truncate([0, 0, 0]) : null,
      ),
      LabScenario(
        id: 'S5',
        name: 'Alternating',
        description: 'Spectator alternates A-B-A',
        spectatorIdx: _truncate([0, 1, 0]),
        performerIdx: isGame ? _truncate([0, 0, 0]) : null,
      ),
      LabScenario(
        id: 'S6',
        name: 'LateSwitch',
        description: 'Spectator switches only at the end',
        spectatorIdx: _truncate([0, 0, 1]),
        performerIdx: isGame ? _truncate([0, 0, 0]) : null,
      ),
    ];
  }

  /// Scenarios for 3 rounds, 3+ options (A=0, B=1, C=2)
  List<LabScenario> _getScenarios3RoundsTriple() {
    final isGame = preset.predictionMode == PredictionMode.game;

    return [
      LabScenario(
        id: 'T1',
        name: 'AllHit + AlwaysSame(A)',
        description: 'Perfect match, spectator always picks A',
        spectatorIdx: _truncate([0, 0, 0]),
        performerIdx: isGame ? _truncate([0, 0, 0]) : null,
      ),
      LabScenario(
        id: 'T2',
        name: 'AllMiss (A vs B)',
        description: 'Complete mismatch using different options',
        spectatorIdx: _truncate([0, 0, 0]),
        performerIdx: isGame ? _truncate([1, 1, 1]) : null,
      ),
      LabScenario(
        id: 'T3',
        name: 'Alternating A-B-A',
        description: 'Spectator alternates between two options',
        spectatorIdx: _truncate([0, 1, 0]),
        performerIdx: isGame ? _truncate([0, 0, 0]) : null,
      ),
      LabScenario(
        id: 'T4',
        name: 'Dominant + Deviation',
        description: 'Spectator mostly A, deviates to B at end',
        spectatorIdx: _truncate([0, 0, 1]),
        performerIdx: isGame ? _truncate([0, 0, 0]) : null,
      ),
      LabScenario(
        id: 'T5',
        name: 'Three Distinct (A-B-C)',
        description: 'Spectator uses all three options',
        spectatorIdx: _truncate([0, 1, 2]),
        performerIdx: isGame ? _truncate([0, 0, 0]) : null,
      ),
    ];
  }

  /// Scenarios for 5 rounds, 2 options
  List<LabScenario> _getScenarios5RoundsBinary() {
    final isGame = preset.predictionMode == PredictionMode.game;
    final rounds = preset.nbRounds.clamp(1, 5);

    List<int> t(List<int> seq) => seq.sublist(0, rounds);

    return [
      LabScenario(
        id: 'R1',
        name: 'AllHit + AlwaysSame(A)',
        description: 'Perfect match, always A',
        spectatorIdx: t([0, 0, 0, 0, 0]),
        performerIdx: isGame ? t([0, 0, 0, 0, 0]) : null,
      ),
      LabScenario(
        id: 'R2',
        name: 'AllMiss + AlwaysSame(A)',
        description: 'Complete mismatch',
        spectatorIdx: t([0, 0, 0, 0, 0]),
        performerIdx: isGame ? t([1, 1, 1, 1, 1]) : null,
      ),
      LabScenario(
        id: 'R3',
        name: 'OneMiss (round3)',
        description: 'Single miss in the middle',
        spectatorIdx: t([0, 0, 0, 0, 0]),
        performerIdx: isGame ? t([0, 0, 1, 0, 0]) : null,
      ),
      LabScenario(
        id: 'R4',
        name: 'TwoMiss (round2&4)',
        description: 'Two misses spread out',
        spectatorIdx: t([0, 0, 0, 0, 0]),
        performerIdx: isGame ? t([0, 1, 0, 1, 0]) : null,
      ),
      LabScenario(
        id: 'R5',
        name: 'Alternating Strong',
        description: 'Full alternation pattern',
        spectatorIdx: t([0, 1, 0, 1, 0]),
        performerIdx: isGame ? t([0, 0, 0, 0, 0]) : null,
      ),
      LabScenario(
        id: 'R6',
        name: 'Mostly Same + Last Switch',
        description: 'Repeat then switch at end',
        spectatorIdx: t([0, 0, 0, 0, 1]),
        performerIdx: isGame ? t([0, 0, 0, 0, 0]) : null,
      ),
      LabScenario(
        id: 'R7',
        name: 'Early Switch Then Repeat',
        description: 'Switch early then stick',
        spectatorIdx: t([0, 1, 1, 1, 1]),
        performerIdx: isGame ? t([0, 0, 0, 0, 0]) : null,
      ),
      LabScenario(
        id: 'R8',
        name: 'AllHit (B)',
        description: 'Perfect match with option B',
        spectatorIdx: t([1, 1, 1, 1, 1]),
        performerIdx: isGame ? t([1, 1, 1, 1, 1]) : null,
      ),
    ];
  }

  /// Scenarios for 5 rounds, 3+ options
  List<LabScenario> _getScenarios5RoundsTriple() {
    final isGame = preset.predictionMode == PredictionMode.game;
    final rounds = preset.nbRounds.clamp(1, 5);

    List<int> t(List<int> seq) => seq.sublist(0, rounds);

    return [
      LabScenario(
        id: 'U1',
        name: 'AllHit + AlwaysSame(A)',
        description: 'Perfect match, always A',
        spectatorIdx: t([0, 0, 0, 0, 0]),
        performerIdx: isGame ? t([0, 0, 0, 0, 0]) : null,
      ),
      LabScenario(
        id: 'U2',
        name: 'AllMiss (A vs B)',
        description: 'Complete mismatch',
        spectatorIdx: t([0, 0, 0, 0, 0]),
        performerIdx: isGame ? t([1, 1, 1, 1, 1]) : null,
      ),
      LabScenario(
        id: 'U3',
        name: 'Dominant + Deviation',
        description: 'Mostly A, deviation at end',
        spectatorIdx: t([0, 0, 0, 0, 1]),
        performerIdx: isGame ? t([0, 0, 0, 0, 0]) : null,
      ),
      LabScenario(
        id: 'U4',
        name: 'Alternating A-B',
        description: 'Alternation between two options',
        spectatorIdx: t([0, 1, 0, 1, 0]),
        performerIdx: isGame ? t([0, 0, 0, 0, 0]) : null,
      ),
      LabScenario(
        id: 'U5',
        name: 'Cycle A-B-C-A-B',
        description: 'Cyclic pattern through options',
        spectatorIdx: t([0, 1, 2, 0, 1]),
        performerIdx: isGame ? t([0, 0, 0, 0, 0]) : null,
      ),
    ];
  }

  /// Generate result for a single scenario
  LabScenarioResult _generateScenarioResult(LabScenario scenario) {
    final spectatorLabels = scenario.getSpectatorLabels(preset.labels);
    final performerLabels = scenario.getPerformerLabels(preset.labels);

    // Create a mock session
    final session = _createMockSession(spectatorLabels, performerLabels);

    // Compute summary
    final summary = _computeSummary(session, spectatorLabels, performerLabels);

    // Generate variants
    final variants = <LabVariant>[];
    final baseSeed = '${preset.id}_${scenario.id}'.hashCode.abs();

    for (int i = 0; i < permutationsCount; i++) {
      final seed = baseSeed + i;
      final variant = _generateVariant(session, seed);
      variants.add(variant);
    }

    return LabScenarioResult(
      scenario: scenario,
      spectatorLabels: spectatorLabels,
      performerLabels: performerLabels,
      summary: summary,
      variants: variants,
    );
  }

  /// Create a mock GameSession for narrative generation
  GameSession _createMockSession(
    List<String> spectatorLabels,
    List<String>? performerLabels,
  ) {
    final rounds = <RoundInput>[];

    for (int i = 0; i < spectatorLabels.length; i++) {
      rounds.add(RoundInput(
        roundNumber: i + 1,
        spectatorChoice: spectatorLabels[i],
        performerChoice: performerLabels?[i],
      ));
    }

    return GameSession(
      gameType: GameType.multiChoice,
      inputMode: preset.inputMode,
      options: preset.labels,
      player1Name: 'Performer',
      player2Name: 'Spectator',
      firstPerson: false,
      preprogrammedSequence: performerLabels,
      rounds: rounds,
      totalRounds: rounds.length,
      language: preset.language,
      predictionMode: preset.predictionMode,
      narratorVoice: preset.narratorVoice,
      addressMode: preset.addressMode,
      spectatorName: preset.spectatorName,
      actorName: preset.actorName,
      participantName: preset.participantName,
    );
  }

  /// Compute summary statistics for a session
  LabComputedSummary _computeSummary(
    GameSession session,
    List<String> spectatorLabels,
    List<String>? performerLabels,
  ) {
    // Calculate hits/misses
    int hitCount = 0;
    int missCount = 0;
    final missIndices = <int>[];

    if (performerLabels != null) {
      for (int i = 0; i < spectatorLabels.length; i++) {
        if (spectatorLabels[i] == performerLabels[i]) {
          hitCount++;
        } else {
          missCount++;
          missIndices.add(i);
        }
      }
    }

    // Determine outcome type
    String outcomeType;
    if (performerLabels == null) {
      outcomeType = 'direct';
    } else if (missCount == 0) {
      outcomeType = 'allHit';
    } else if (hitCount == 0) {
      outcomeType = 'allMiss';
    } else if (missCount == 1) {
      outcomeType = 'oneMiss';
    } else if (missCount == 2) {
      outcomeType = 'twoMiss';
    } else {
      outcomeType = 'mixed';
    }

    // Calculate pattern statistics
    final counts = <String, int>{};
    for (final choice in spectatorLabels) {
      counts[choice] = (counts[choice] ?? 0) + 1;
    }

    String dominant = spectatorLabels.first;
    int dominantCount = 0;
    for (final entry in counts.entries) {
      if (entry.value > dominantCount) {
        dominantCount = entry.value;
        dominant = entry.key;
      }
    }

    // Switch count
    int switchCount = 0;
    for (int i = 1; i < spectatorLabels.length; i++) {
      if (spectatorLabels[i] != spectatorLabels[i - 1]) switchCount++;
    }

    // Streak
    int maxStreak = 1, currentStreak = 1;
    for (int i = 1; i < spectatorLabels.length; i++) {
      if (spectatorLabels[i] == spectatorLabels[i - 1]) {
        currentStreak++;
        if (currentStreak > maxStreak) maxStreak = currentStreak;
      } else {
        currentStreak = 1;
      }
    }

    // Determine pattern type according to new rules:
    // - switchCount == 0 → repeatHeavy
    // - switchCount == 1 → oneSwitch
    // - switchCount == rounds-1 AND streakMaxLen == 1 → alternating
    // - else → mixed
    String patternType;
    final total = spectatorLabels.length;
    if (switchCount == 0) {
      patternType = 'repeatHeavy';
    } else if (switchCount == 1) {
      patternType = 'oneSwitch';
    } else if (switchCount == total - 1 && maxStreak == 1) {
      patternType = 'alternating';
    } else {
      patternType = 'mixed';
    }

    return LabComputedSummary(
      hitCount: hitCount,
      missCount: missCount,
      missIndices: missIndices,
      outcomeType: outcomeType,
      patternType: patternType,
      dominant: dominant,
      dominantCount: dominantCount,
      streakLen: maxStreak,
      switchCount: switchCount,
    );
  }

  /// Generate a single variant with a specific seed
  LabVariant _generateVariant(GameSession session, int seed) {
    final result = generateNarrativeV2(
      session: session,
      seed: seed,
    );

    final trace = result.assemblyTrace;

    return LabVariant(
      seed: seed,
      text: result.generatedText,
      traceString: trace.toTraceString(),
      assemblyTrace: trace,
      wordCount: result.wordCount,
      hookId: trace.hookId,
      performerLineId: trace.performerLineId,
      patternLineId: trace.patternLineId,
      intentLineId: trace.intentLineId,
      missLineId: trace.missLineId,
      closerId: trace.closerId,
    );
  }

  /// Generate full log for all scenarios
  static String generateFullLog({
    required Preset preset,
    required List<LabScenarioResult> results,
  }) {
    final buffer = StringBuffer();

    // Header
    buffer.writeln('#'.padRight(70, '#'));
    buffer.writeln('# NARRATIVE LAB - FULL LOG');
    buffer.writeln('#'.padRight(70, '#'));
    buffer.writeln('');
    buffer.writeln('PRESET SUMMARY:');
    buffer.writeln('  Name: ${preset.name}');
    buffer.writeln('  Mode: ${preset.predictionMode.name.toUpperCase()}');
    buffer.writeln('  Language: ${preset.language.code}');
    buffer.writeln('  Options: ${preset.labels.join(", ")} (${preset.nbOptions})');
    buffer.writeln('  Rounds: ${preset.nbRounds}');
    buffer.writeln('  InputMode: ${preset.inputMode.name}');
    buffer.writeln('');
    buffer.writeln('SCENARIOS: ${results.length}');
    buffer.writeln('');

    // Each scenario
    for (final result in results) {
      buffer.writeln(result.toLogString());
      buffer.writeln('');
    }

    buffer.writeln('#'.padRight(70, '#'));
    buffer.writeln('# END OF LOG');
    buffer.writeln('#'.padRight(70, '#'));

    return buffer.toString();
  }
}
