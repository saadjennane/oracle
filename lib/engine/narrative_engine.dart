import 'dart:math';
import '../models/models.dart';
import 'narrative_trace.dart';
import 'narrative_engine_v2/narrative_engine_v2.dart';
import 'pattern_detector.dart';

/// Main narrative engine that orchestrates narrative generation
/// All narrative text comes from custom bank templates (filled via prompts)
class NarrativeEngine {
  /// Last generated trace (for debug panel access)
  NarrativeTrace? lastTrace;

  /// Last matched bank key (for image lookup)
  String? lastBankKey;

  /// Generate narrative for a completed session
  String generate({
    required GameSession session,
    Language? language,
    int? seed,
  }) {
    // For First-To games, check if target score is reached instead of fixed round count
    if (session.isFirstTo) {
      final detector = PatternDetector(session);
      final score = detector.calculateDuelScore();
      if (score.spectatorScore < session.targetScore && score.performerScore < session.targetScore) {
        throw StateError('Session must have all rounds completed');
      }
    } else if (!session.hasAllRounds) {
      throw StateError('Session must have all rounds completed');
    }

    final effectiveLanguage = language ?? session.language;
    final effectiveSeed = seed ?? session.narrativeSeed ?? Random().nextInt(1000000);

    // DUEL
    if (session.gameType == GameType.duel) {
      lastTrace = null;
      return _generateDuelNarrative(
        session: session,
        language: effectiveLanguage,
      );
    }

    // CHOICES: Use V2 modular engine
    final result = generateNarrativeV2(
      session: session.copyWith(language: effectiveLanguage),
      seed: effectiveSeed,
    );

    // Create a trace with V2 data
    if (result.legacyTrace != null) {
      lastTrace = NarrativeTrace(
        mode: result.legacyTrace!.mode,
        language: result.legacyTrace!.language,
        options: result.legacyTrace!.options,
        roundsCount: result.legacyTrace!.roundsCount,
        spectatorChoices: result.legacyTrace!.spectatorChoices,
        performerChoices: result.legacyTrace!.performerChoices,
        hitCount: result.legacyTrace!.hitCount,
        missCount: result.legacyTrace!.missCount,
        missIndices: result.legacyTrace!.missIndices,
        outcomeType: result.legacyTrace!.outcomeType,
        switchCount: result.legacyTrace!.switchCount,
        dominantOption: result.legacyTrace!.dominantOption,
        dominantCount: result.legacyTrace!.dominantCount,
        streakMaxLen: result.legacyTrace!.streakMaxLen,
        streakOption: result.legacyTrace!.streakOption,
        spectatorPattern: result.legacyTrace!.spectatorPattern,
        performerRelation: result.legacyTrace!.performerRelation,
        dominantPerformer: result.legacyTrace!.dominantPerformer,
        seed: effectiveSeed,
        hookIndex: 0,
        middleIndex: 0,
        closerIndex: 0,
        includePerformer: result.legacyTrace!.includePerformer,
        includeIntentionalMiss: result.legacyTrace!.includeIntentionalMiss,
        mentionedMissRounds: result.legacyTrace!.mentionedMissRounds,
        generatedText: result.generatedText,
        wordCount: result.wordCount,
        engineVersion: NarrativeEngineVersion.v2,
        v2Trace: result.assemblyTrace,
      );
    }
    if (result.bankKey != null) lastBankKey = result.bankKey;
    return result.generatedText;
  }

  /// Generate with a new random seed (for regeneration)
  String regenerate({
    required GameSession session,
    Language? language,
  }) {
    final newSeed = Random().nextInt(1000000);
    return generate(
      session: session,
      language: language,
      seed: newSeed,
    );
  }

  /// Duel narrative - routes to appropriate bank based on duelMode
  /// Checks custom templates first (any language), then French default banks.
  String _generateDuelNarrative({
    required GameSession session,
    required Language language,
  }) {
    // Extract common data
    final spectatorMoves = session.rounds.map((r) => r.spectatorChoice).toList();
    final performerMoves = session.rounds.map((r) => r.performerChoice ?? '').toList();
    final detector = PatternDetector(session);
    final duelScore = detector.calculateDuelScore();
    final spectatorWins = duelScore.spectatorScore;
    final performerWins = duelScore.performerScore;

    if (session.duelMode == DuelMode.firstTo) {
      final ties = session.rounds.length - spectatorWins - performerWins;
      final result = _tryDuelFirstTo(
        session: session,
        language: language,
        spectatorMoves: spectatorMoves,
        performerMoves: performerMoves,
        spectatorWins: spectatorWins,
        performerWins: performerWins,
        ties: ties,
      );
      if (result != null) return result;
    } else {
      final ties = session.totalRounds - spectatorWins - performerWins;
      final result = _tryDuelFixedRounds(
        session: session,
        language: language,
        spectatorMoves: spectatorMoves,
        performerMoves: performerMoves,
        spectatorWins: spectatorWins,
        performerWins: performerWins,
        ties: ties,
      );
      if (result != null) return result;
    }

    // No template found for this outcome
    return '[Aucun texte configuré pour ce résultat]';
  }

  /// Try Fixed Rounds: custom templates (any language) → default FR bank
  String? _tryDuelFixedRounds({
    required GameSession session,
    required Language language,
    required List<String> spectatorMoves,
    required List<String> performerMoves,
    required int spectatorWins,
    required int performerWins,
    required int ties,
  }) {
    // Build bucket key: "rounds|spectatorWins-performerWins"
    final bucketKey = '${session.totalRounds}|$spectatorWins-$performerWins';
    lastBankKey = bucketKey;

    // 1. Try custom template (any language)
    final customText = session.getCustomDuelBankText(bucketKey);
    if (customText != null && customText.trim().isNotEmpty) {
      return _renderDuelTemplate(
        template: customText,
        spectatorMoves: spectatorMoves,
        performerMoves: performerMoves,
        spectatorWins: spectatorWins,
        performerWins: performerWins,
        ties: ties,
        session: session,
      );
    }

    // No default fallback bank for Fixed Rounds — empty banks force the
    // user to author per-bucket templates explicitly.
    return null;
  }

  /// Try First-To: custom templates (any language) → default FR bank
  String? _tryDuelFirstTo({
    required GameSession session,
    required Language language,
    required List<String> spectatorMoves,
    required List<String> performerMoves,
    required int spectatorWins,
    required int performerWins,
    required int ties,
  }) {
    // Build bucket key: "FT{target}_{side}_{target}-{loser}"
    final spectatorWon = spectatorWins >= session.targetScore;
    final side = spectatorWon ? 'S' : 'P';
    final loserScore = spectatorWon ? performerWins : spectatorWins;
    final bucketKey = 'FT${session.targetScore}_${side}_${session.targetScore}-$loserScore';
    lastBankKey = bucketKey;

    // 1. Try custom template (any language)
    final customText = session.getCustomDuelBankText(bucketKey);
    if (customText != null && customText.trim().isNotEmpty) {
      return _renderDuelTemplate(
        template: customText,
        spectatorMoves: spectatorMoves,
        performerMoves: performerMoves,
        spectatorWins: spectatorWins,
        performerWins: performerWins,
        ties: ties,
        session: session,
      );
    }

    // No default First-To bank — banks start empty, user authors text per bucket.
    return null;
  }

  /// Render a duel template with all placeholder replacements
  /// Supports: {spectatorSequence}, {choice1}..{choiceN}, {choicePerformer1}..{choicePerformerN},
  /// {numRounds}, {numTies}, {1stNoTieSpectator}, {1stNoTiePerformer},
  /// {lastWinSpectator}, {lastWinPerformer}, {1stTie}, {lastTie},
  /// {1stWinSpectator}, {2ndWinSpectator}..., {1stWinPerformer}, {2ndWinPerformer}...,
  /// and legacy placeholders ({X}, {Y}, {ties}, {scoreX}, {scoreY}, {tiesSuffix})
  String _renderDuelTemplate({
    required String template,
    required List<String> spectatorMoves,
    List<String> performerMoves = const [],
    required int spectatorWins,
    required int performerWins,
    required int ties,
    GameSession? session,
  }) {
    final isFirstTo = session?.isFirstTo ?? false;
    var result = template;
    final dynBankTemplates = session?.customDuelBankTemplates ?? const <String, String>{};

    // ── PASS 1 — inject bucket-supplied texts (which may themselves contain
    // `{choiceS{N}}` etc.). Done before per-round substitutions so vars
    // embedded inside the injected texts get resolved in the next pass.
    const int kRoundCap = 5;

    // {round1OutcomeText}…{round5OutcomeText}
    if (session != null && result.contains('{round')) {
      final detector = PatternDetector(session);
      final outcomes = detector.computeRoundOutcomes();
      for (int r = 0; r < outcomes.length && r < kRoundCap; r++) {
        final placeholder = '{round${r + 1}OutcomeText}';
        if (!result.contains(placeholder)) continue;
        String text = '';
        switch (outcomes[r]) {
          case RoundOutcome.spectatorWin:
            text = dynBankTemplates['__round${r + 1}_spectatorWin__'] ?? '';
            break;
          case RoundOutcome.performerWin:
            text = dynBankTemplates['__round${r + 1}_performerWin__'] ?? '';
            break;
          case RoundOutcome.tie:
            text = dynBankTemplates['__round${r + 1}_tie__'] ?? '';
            break;
          default:
            break;
        }
        result = result.replaceAll(placeholder, text);
      }
    }

    // {samePattern} — `__samePatternText__` if the spectator played the same
    // gesture every round, else `__mixedPatternText__`. Available in both modes.
    if (result.contains('{samePattern}')) {
      final allSame = spectatorMoves.isNotEmpty &&
          spectatorMoves.every((m) => m.toLowerCase() == spectatorMoves.first.toLowerCase());
      final picked = allSame
          ? (dynBankTemplates['__samePatternText__'] ?? '')
          : (dynBankTemplates['__mixedPatternText__'] ?? '');
      result = result.replaceAll('{samePattern}', picked);
    }

    // First-To-only bucket-supplied texts.
    if (isFirstTo) {
      // {tieTextOrNoTieText} — 3 tiers: 0 → noTieText, 1-3 → tieText, >3 → tieTextHigh.
      // Falls back to tieText if tieTextHigh is empty (and vice-versa) so users
      // who only filled one of the two tie tiers still get something.
      if (result.contains('{tieTextOrNoTieText}')) {
        final tieText = dynBankTemplates['__tieText__'] ?? '';
        final noTieText = dynBankTemplates['__noTieText__'] ?? '';
        final tieTextHigh = dynBankTemplates['__tieTextHigh__'] ?? '';
        String picked;
        if (ties == 0) {
          picked = noTieText;
        } else if (ties > 3) {
          picked = tieTextHigh.isNotEmpty ? tieTextHigh : tieText;
        } else {
          picked = tieText.isNotEmpty ? tieText : tieTextHigh;
        }
        result = result.replaceAll('{tieTextOrNoTieText}', picked);
      }

      // {comebackText}
      if (session != null && result.contains('{comebackText}')) {
        final detector = PatternDetector(session);
        final outcomes = detector.computeRoundOutcomes();
        final score = detector.calculateDuelScore();
        final isSpectatorWinner = score.spectatorScore > score.performerScore;
        int sScore = 0, pScore = 0;
        bool winnerWasTrailing = false;
        for (final o in outcomes) {
          if (o == RoundOutcome.spectatorWin) sScore++;
          else if (o == RoundOutcome.performerWin) pScore++;
          if (isSpectatorWinner && pScore > sScore) winnerWasTrailing = true;
          if (!isSpectatorWinner && sScore > pScore) winnerWasTrailing = true;
        }
        final remontadaText = winnerWasTrailing
            ? (isSpectatorWinner
                ? (dynBankTemplates['__remontadaSpectator__'] ?? '')
                : (dynBankTemplates['__remontadaPerformer__'] ?? ''))
            : '';
        result = result.replaceAll('{comebackText}', remontadaText);
      }
    }

    // ── PASS 2 — per-round canonical choice substitutions. Runs AFTER the
    // bucket-text injections so vars embedded in those texts get resolved too.
    for (int i = 0; i < spectatorMoves.length && i < kRoundCap; i++) {
      result = result.replaceAll('{choiceS${i + 1}}', spectatorMoves[i].toLowerCase());
    }
    for (int i = 0; i < performerMoves.length && i < kRoundCap; i++) {
      if (performerMoves[i].isNotEmpty) {
        result = result.replaceAll('{choiceP${i + 1}}', performerMoves[i].toLowerCase());
      }
    }

    // ── First-To-only vars (Fixed Rounds doesn't need any of these).
    if (!isFirstTo) return result;

    // Totals
    result = result.replaceAll('{numRounds}', spectatorMoves.length.toString());
    result = result.replaceAll('{numTies}', ties.toString());
    // +1 variants — handy for "you'll need {numRounds+1} rounds to beat that"
    result = result.replaceAll('{numRounds+1}', (spectatorMoves.length + 1).toString());
    result = result.replaceAll('{numTies+1}', (ties + 1).toString());

    // Highlight hooks: first decisive round + clinching round + first tie
    if (session != null) {
      final detector = PatternDetector(session);
      final outcomes = detector.computeRoundOutcomes();
      int? firstNoTieRound;
      int? firstTieRound;
      for (int i = 0; i < outcomes.length; i++) {
        if (firstNoTieRound == null &&
            (outcomes[i] == RoundOutcome.spectatorWin || outcomes[i] == RoundOutcome.performerWin)) {
          firstNoTieRound = i;
        }
        if (firstTieRound == null && outcomes[i] == RoundOutcome.tie) {
          firstTieRound = i;
        }
        if (firstNoTieRound != null && firstTieRound != null) break;
      }
      if (firstNoTieRound != null) {
        result = result.replaceAll('{1stNoTieSpectator}', spectatorMoves[firstNoTieRound].toLowerCase());
        final perfChoice = firstNoTieRound < performerMoves.length ? performerMoves[firstNoTieRound] : '';
        result = result.replaceAll('{1stNoTiePerformer}', perfChoice.toLowerCase());
      }
      if (spectatorMoves.isNotEmpty) {
        final lastIdx = spectatorMoves.length - 1;
        result = result.replaceAll('{lastWinSpectator}', spectatorMoves[lastIdx].toLowerCase());
        final perfChoice = lastIdx < performerMoves.length ? performerMoves[lastIdx] : '';
        result = result.replaceAll('{lastWinPerformer}', perfChoice.toLowerCase());
      }
      if (firstTieRound != null) {
        // Spectator's choice when the first tie happened.
        result = result.replaceAll(
          '{1stTieChoice}',
          firstTieRound < spectatorMoves.length ? spectatorMoves[firstTieRound].toLowerCase() : '',
        );
        // Round number (1-indexed) of the first tie.
        result = result.replaceAll('{When1stTie}', (firstTieRound + 1).toString());
      }
    }

    return result;
  }
}
