import '../models/models.dart';
import '../models/pattern_facts.dart';

/// Debug trace data collected during narrative generation
class NarrativeTraceData {
  // Section A - INPUTS
  final PredictionMode predictionMode;
  final Language language;
  final List<String> options;
  final int roundsCount;
  final List<String> spectatorChoices;
  final List<String> performerChoices;

  // Section B - COMPUTED
  final int hitCount;
  final int missCount;
  final List<int> missIndices;
  final int switchCount;
  final String dominantOption;
  final int streakMaxLen;
  final PatternType patternType;
  final OutcomeClass outcomeClass;
  final MissPosition missPosition;

  // Section C - NARRATIVE PLAN
  final int hookIndex;
  final int closerIndex;
  final String? missLineUsed;
  final List<int> mentionedRounds;

  // Section D - OUTPUT
  final String generatedNarrative;
  final int wordCount;
  final int seed;

  const NarrativeTraceData({
    required this.predictionMode,
    required this.language,
    required this.options,
    required this.roundsCount,
    required this.spectatorChoices,
    required this.performerChoices,
    required this.hitCount,
    required this.missCount,
    required this.missIndices,
    required this.switchCount,
    required this.dominantOption,
    required this.streakMaxLen,
    required this.patternType,
    required this.outcomeClass,
    required this.missPosition,
    required this.hookIndex,
    required this.closerIndex,
    this.missLineUsed,
    required this.mentionedRounds,
    required this.generatedNarrative,
    required this.wordCount,
    required this.seed,
  });
}

/// Builds a human-readable trace string for debugging
String buildNarrativeTrace(NarrativeTraceData data) {
  final buffer = StringBuffer();

  // Header
  buffer.writeln('═══════════════════════════════════════════════════════');
  buffer.writeln('           ORACLE NARRATIVE TRACE');
  buffer.writeln('═══════════════════════════════════════════════════════');
  buffer.writeln();

  // Section A - INPUTS
  buffer.writeln('┌─────────────────────────────────────────────────────┐');
  buffer.writeln('│  SECTION A — INPUTS                                 │');
  buffer.writeln('└─────────────────────────────────────────────────────┘');
  buffer.writeln();
  buffer.writeln('Mode:      ${data.predictionMode == PredictionMode.game ? "GAME" : "DIRECT"}');
  buffer.writeln('Language:  ${data.language == Language.french ? "FR" : "EN"}');
  buffer.writeln('Options:   [${data.options.join(", ")}]');
  buffer.writeln('Rounds:    ${data.roundsCount}');
  buffer.writeln();
  buffer.writeln('Spectator: [${data.spectatorChoices.join(", ")}]');
  if (data.predictionMode == PredictionMode.game) {
    buffer.writeln('Performer: [${data.performerChoices.join(", ")}]');
  }
  buffer.writeln();

  // Section B - COMPUTED
  buffer.writeln('┌─────────────────────────────────────────────────────┐');
  buffer.writeln('│  SECTION B — COMPUTED                               │');
  buffer.writeln('└─────────────────────────────────────────────────────┘');
  buffer.writeln();
  if (data.predictionMode == PredictionMode.game) {
    buffer.writeln('hitCount:       ${data.hitCount}');
    buffer.writeln('missCount:      ${data.missCount}');
    buffer.writeln('missIndices:    ${data.missIndices.isEmpty ? "[]" : "[${data.missIndices.map((i) => i + 1).join(", ")}]"} (1-indexed)');
    buffer.writeln('missPosition:   ${data.missPosition.name}');
    buffer.writeln('outcomeClass:   ${data.outcomeClass.name}');
    buffer.writeln();
  }
  buffer.writeln('switchCount:    ${data.switchCount}');
  buffer.writeln('dominantOption: ${data.dominantOption}');
  buffer.writeln('streakMaxLen:   ${data.streakMaxLen}');
  buffer.writeln('patternType:    ${data.patternType.name}');
  buffer.writeln();

  // Section C - NARRATIVE PLAN
  buffer.writeln('┌─────────────────────────────────────────────────────┐');
  buffer.writeln('│  SECTION C — NARRATIVE PLAN                         │');
  buffer.writeln('└─────────────────────────────────────────────────────┘');
  buffer.writeln();
  buffer.writeln('seed:           ${data.seed}');
  buffer.writeln('hookIndex:      ${data.hookIndex}');
  buffer.writeln('closerIndex:    ${data.closerIndex}');
  if (data.missLineUsed != null) {
    buffer.writeln('missLineUsed:   "${data.missLineUsed}"');
  }
  if (data.mentionedRounds.isNotEmpty) {
    buffer.writeln('mentionedRnds:  [${data.mentionedRounds.map((i) => i + 1).join(", ")}] (1-indexed)');
  }
  buffer.writeln();

  // Section D - OUTPUT
  buffer.writeln('┌─────────────────────────────────────────────────────┐');
  buffer.writeln('│  SECTION D — OUTPUT                                 │');
  buffer.writeln('└─────────────────────────────────────────────────────┘');
  buffer.writeln();
  buffer.writeln('wordCount:      ${data.wordCount}');
  buffer.writeln();
  buffer.writeln('─────────────────────────────────────────────────────');
  buffer.writeln(data.generatedNarrative);
  buffer.writeln('─────────────────────────────────────────────────────');
  buffer.writeln();

  // Footer
  buffer.writeln('═══════════════════════════════════════════════════════');
  buffer.writeln('           END OF TRACE');
  buffer.writeln('═══════════════════════════════════════════════════════');

  return buffer.toString();
}

/// Builds just the INPUTS section for partial copy
String buildInputsSection(NarrativeTraceData data) {
  final buffer = StringBuffer();
  buffer.writeln('INPUTS');
  buffer.writeln('------');
  buffer.writeln('Mode:      ${data.predictionMode == PredictionMode.game ? "GAME" : "DIRECT"}');
  buffer.writeln('Language:  ${data.language == Language.french ? "FR" : "EN"}');
  buffer.writeln('Options:   [${data.options.join(", ")}]');
  buffer.writeln('Rounds:    ${data.roundsCount}');
  buffer.writeln('Spectator: [${data.spectatorChoices.join(", ")}]');
  if (data.predictionMode == PredictionMode.game) {
    buffer.writeln('Performer: [${data.performerChoices.join(", ")}]');
  }
  return buffer.toString();
}

/// Builds just the COMPUTED section for partial copy
String buildComputedSection(NarrativeTraceData data) {
  final buffer = StringBuffer();
  buffer.writeln('COMPUTED');
  buffer.writeln('--------');
  if (data.predictionMode == PredictionMode.game) {
    buffer.writeln('hitCount:       ${data.hitCount}');
    buffer.writeln('missCount:      ${data.missCount}');
    buffer.writeln('missIndices:    ${data.missIndices.isEmpty ? "[]" : "[${data.missIndices.map((i) => i + 1).join(", ")}]"}');
    buffer.writeln('missPosition:   ${data.missPosition.name}');
    buffer.writeln('outcomeClass:   ${data.outcomeClass.name}');
  }
  buffer.writeln('switchCount:    ${data.switchCount}');
  buffer.writeln('dominantOption: ${data.dominantOption}');
  buffer.writeln('streakMaxLen:   ${data.streakMaxLen}');
  buffer.writeln('patternType:    ${data.patternType.name}');
  return buffer.toString();
}

/// Builds just the OUTPUT section for partial copy
String buildOutputSection(NarrativeTraceData data) {
  final buffer = StringBuffer();
  buffer.writeln('OUTPUT');
  buffer.writeln('------');
  buffer.writeln('wordCount: ${data.wordCount}');
  buffer.writeln();
  buffer.writeln(data.generatedNarrative);
  return buffer.toString();
}
