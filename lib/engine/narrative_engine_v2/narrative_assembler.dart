/// Narrative Assembler V2 — Trace structures only
///
/// AssemblyResult and AssemblyTrace are used by bank routing for debug output.

import 'casebook_fr.dart';

/// Résultat de l'assemblage avec trace des sélections
class AssemblyResult {
  final String narrative;
  final AssemblyTrace trace;

  const AssemblyResult({
    required this.narrative,
    required this.trace,
  });
}

/// Trace des sélections V2 pour debug
class AssemblyTrace {
  final String hookId;
  final String? performerLineId;
  final String patternLineId;
  final String? intentLineId;
  final String? missLineId;
  final String closerId;
  final NarrativeStyleV2 style;
  final NarrativeToneV2 tone;
  final NarrativeTenseV2 tense;
  final NarrativeFlavorV2? flavor;
  final bool isGameMode;

  const AssemblyTrace({
    required this.hookId,
    this.performerLineId,
    required this.patternLineId,
    this.intentLineId,
    this.missLineId,
    required this.closerId,
    required this.style,
    required this.tone,
    required this.tense,
    this.flavor,
    required this.isGameMode,
  });

  Map<String, dynamic> toJson() => {
    'hookId': hookId,
    'performerLineId': performerLineId,
    'patternLineId': patternLineId,
    'intentLineId': intentLineId,
    'missLineId': missLineId,
    'closerId': closerId,
    'style': style.name,
    'tone': tone.name,
    'tense': tense.name,
    'flavor': flavor?.name,
    'isGameMode': isGameMode,
  };

  String toTraceString() {
    final buffer = StringBuffer();
    buffer.writeln('=== Assembly Trace V2 ===');
    buffer.writeln('Mode: ${isGameMode ? "GAME" : "DIRECT"}');
    buffer.writeln('---');
    buffer.writeln('Hook: $hookId');
    if (performerLineId != null) buffer.writeln('PerformerLine: $performerLineId');
    buffer.writeln('PatternLine: $patternLineId');
    if (intentLineId != null) buffer.writeln('IntentLine: $intentLineId');
    if (missLineId != null) buffer.writeln('MissLine: $missLineId');
    buffer.writeln('Closer: $closerId');
    return buffer.toString();
  }
}
