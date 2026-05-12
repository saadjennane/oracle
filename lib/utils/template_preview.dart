/// Utility for rendering template previews and validating variables.
class TemplatePreview {
  /// Render a template by replacing all {variable} placeholders with values from the map.
  /// Unreplaced variables are returned as-is (highlighted in output).
  static String render(String template, Map<String, String> variables) {
    var result = template;
    // Two passes to resolve nested variables (e.g. {round1OutcomeText} contains {choiceS1})
    for (int pass = 0; pass < 2; pass++) {
      for (final entry in variables.entries) {
        result = result.replaceAll('{${entry.key}}', entry.value);
      }
    }
    return result;
  }

  /// Find all {variable} placeholders in a template that are NOT in the provided variables map.
  static List<String> findUnresolved(String template, Map<String, String> variables) {
    final pattern = RegExp(r'\{(\w+)\}');
    final unresolved = <String>[];
    for (final match in pattern.allMatches(template)) {
      final varName = match.group(1)!;
      if (!variables.containsKey(varName)) {
        unresolved.add(varName);
      }
    }
    return unresolved;
  }

  /// Check if a template contains any {variable} placeholders.
  static bool hasVariables(String template) {
    return RegExp(r'\{\w+\}').hasMatch(template);
  }

  /// Build a variables map for a Duel sequence context.
  static Map<String, String> buildDuelSequenceVars({
    required List<int> spectatorSeq,
    required List<int> performerSeq,
    required List<String> labels,
    required Map<String, String> templates,
    int Function(int perfIdx, int specIdx, int optCount)? roundResult,
  }) {
    final vars = <String, String>{};
    final optCount = labels.length;
    final spectatorMoves = spectatorSeq.map((i) => i < labels.length ? labels[i] : '?').toList();
    final performerMoves = performerSeq.map((i) => i < labels.length ? labels[i] : '?').toList();

    vars['spectatorSequence'] = spectatorMoves.join(', ').toLowerCase();
    vars['numRounds'] = spectatorSeq.length.toString();

    // Per-round choices
    for (int i = 0; i < spectatorMoves.length; i++) {
      vars['choice${i + 1}'] = spectatorMoves[i].toLowerCase();
    }
    for (int i = 0; i < performerMoves.length; i++) {
      vars['choicePerformer${i + 1}'] = performerMoves[i].toLowerCase();
    }

    // Compute scores and outcomes if roundResult function provided
    if (roundResult != null) {
      int sWins = 0, pWins = 0, ties = 0;
      final tieRounds = <int>[];
      final sWinRounds = <int>[];
      final pWinRounds = <int>[];
      int? firstNoTie;

      for (int i = 0; i < spectatorSeq.length && i < performerSeq.length; i++) {
        final r = roundResult(performerSeq[i], spectatorSeq[i], optCount);
        if (r > 0) {
          pWins++;
          pWinRounds.add(i);
          firstNoTie ??= i;
        } else if (r < 0) {
          sWins++;
          sWinRounds.add(i);
          firstNoTie ??= i;
        } else {
          ties++;
          tieRounds.add(i);
        }
      }

      vars['scoreX'] = sWins.toString();
      vars['scoreY'] = pWins.toString();
      vars['numTies'] = ties.toString();
      vars['tiesSuffix'] = ties == 0 ? '' : ties == 1 ? ', avec 1 égalité' : ', avec $ties égalités';

      if (firstNoTie != null) {
        vars['1stNoTieSpectator'] = spectatorMoves[firstNoTie].toLowerCase();
        vars['1stNoTiePerformer'] = performerMoves[firstNoTie].toLowerCase();
      }

      if (spectatorMoves.isNotEmpty) {
        final last = spectatorMoves.length - 1;
        vars['lastWinSpectator'] = spectatorMoves[last].toLowerCase();
        vars['lastWinPerformer'] = performerMoves[last].toLowerCase();
      }

      if (tieRounds.isNotEmpty) {
        vars['1stTie'] = spectatorMoves[tieRounds.first].toLowerCase();
        vars['lastTie'] = spectatorMoves[tieRounds.last].toLowerCase();
      }

      final ordinals = ['1st', '2nd', '3rd', '4th', '5th'];
      for (int i = 0; i < sWinRounds.length && i < ordinals.length; i++) {
        vars['${ordinals[i]}WinSpectator'] = spectatorMoves[sWinRounds[i]].toLowerCase();
      }
      for (int i = 0; i < pWinRounds.length && i < ordinals.length; i++) {
        vars['${ordinals[i]}WinPerformer'] = spectatorMoves[pWinRounds[i]].toLowerCase();
      }

      // whenTie variables
      final frOrdinals = ['première', 'deuxième', 'troisième', 'quatrième', 'cinquième', 'sixième', 'septième', 'huitième', 'neuvième'];
      for (int t = 0; t < tieRounds.length; t++) {
        final roundIdx = tieRounds[t];
        final roundName = templates['__roundName_${roundIdx + 1}__'] ??
            (roundIdx == spectatorSeq.length - 1 ? 'dernière' :
            roundIdx < frOrdinals.length ? frOrdinals[roundIdx] : '${roundIdx + 1}ème');
        vars['whenTie${t + 1}'] = roundName;
      }

      // tieTextOrNoTieText — 3 tiers: 0 → noTieText, 1-3 → tieText, >3 → tieTextHigh.
      if (ties == 0) {
        vars['tieTextOrNoTieText'] = templates['__noTieText__'] ?? '';
      } else {
        final tieTextLow = templates['__tieText__'] ?? '';
        final tieTextHigh = templates['__tieTextHigh__'] ?? '';
        var tieText = ties > 3
            ? (tieTextHigh.isNotEmpty ? tieTextHigh : tieTextLow)
            : (tieTextLow.isNotEmpty ? tieTextLow : tieTextHigh);
        if (tieRounds.isNotEmpty) {
          tieText = tieText.replaceAll('{numTies}', ties.toString());
          tieText = tieText.replaceAll('{1stTie}', spectatorMoves[tieRounds.first].toLowerCase());
          if (tieRounds.length > 1) {
            tieText = tieText.replaceAll('{lastTie}', spectatorMoves[tieRounds.last].toLowerCase());
          }
        }
        vars['tieTextOrNoTieText'] = tieText;
      }
    }

    return vars;
  }

  /// Standard Duel round result: 0 = tie, +1 = performer wins, -1 = spectator wins.
  /// Mirrors the runtime logic (RPS-style cycle for >2 options, fixed mapping for 2).
  static int _roundResultStd(int performerIdx, int spectatorIdx, int optionCount) {
    if (performerIdx == spectatorIdx) return 0;
    if (optionCount == 2) return performerIdx == 0 ? 1 : -1;
    final winsAgainstPerf = (performerIdx + 2) % optionCount;
    return winsAgainstPerf == spectatorIdx ? 1 : -1;
  }

  /// Find a spectator move that yields [desired] outcome against [perfMove].
  /// desired: -1 = spec wins, 0 = tie, +1 = perf wins.
  static int _spectatorMoveFor(int perfMove, int desired, int optCount) {
    if (desired == 0) return perfMove;
    for (int s = 0; s < optCount; s++) {
      if (s == perfMove) continue;
      if (_roundResultStd(perfMove, s, optCount) == desired) return s;
    }
    return perfMove;
  }

  /// Build a variables map for a Duel bucket context.
  ///
  /// When [performerSequence] is provided (and matches [nbRounds]), the
  /// preview reflects the *actual* scenario: spectator moves are derived to
  /// produce the bucket pattern (spec wins → perf wins → ties, in order)
  /// against the real performer moves. Otherwise falls back to a generic
  /// label sample.
  static Map<String, String> buildDuelBucketSampleVars({
    required int spectatorWins,
    required int performerWins,
    required int ties,
    required int nbRounds,
    required List<String> labels,
    required Map<String, String> templates,
    List<int>? performerSequence,
  }) {
    final vars = <String, String>{};
    final optCount = labels.length;
    final useSeq = performerSequence != null &&
        performerSequence.length >= nbRounds &&
        optCount >= 2 &&
        spectatorWins + performerWins + ties == nbRounds;

    // Per-round outcomes in the order: spec wins, perf wins, ties.
    final outcomes = <String>[]; // 'S', 'P', 'T'
    for (int i = 0; i < spectatorWins; i++) outcomes.add('S');
    for (int i = 0; i < performerWins; i++) outcomes.add('P');
    for (int i = 0; i < ties; i++) outcomes.add('T');

    // Per-round spectator and performer move labels (lowercase).
    final spectatorMoves = <String>[];
    final performerMoves = <String>[];
    for (int i = 0; i < nbRounds; i++) {
      String specLabel;
      String perfLabel;
      if (useSeq) {
        final perfIdx = performerSequence[i].clamp(0, optCount - 1);
        perfLabel = labels[perfIdx];
        final outcome = i < outcomes.length ? outcomes[i] : 'T';
        final desired = outcome == 'S' ? -1 : outcome == 'P' ? 1 : 0;
        final specIdx = _spectatorMoveFor(perfIdx, desired, optCount);
        specLabel = labels[specIdx];
      } else {
        // Legacy sample fallback.
        final outcome = i < outcomes.length ? outcomes[i] : 'T';
        if (outcome == 'S') {
          specLabel = labels.length > 1 ? labels[1] : 'A';
          perfLabel = labels.isNotEmpty ? labels[0] : 'P';
        } else if (outcome == 'P') {
          specLabel = labels.isNotEmpty ? labels[0] : 'B';
          perfLabel = labels.isNotEmpty ? labels[0] : 'P';
        } else {
          specLabel = labels.isNotEmpty ? labels[0] : 'C';
          perfLabel = labels.isNotEmpty ? labels[0] : 'P';
        }
      }
      spectatorMoves.add(specLabel.toLowerCase());
      performerMoves.add(perfLabel.toLowerCase());
    }

    vars['spectatorSequence'] = spectatorMoves.join(', ');
    vars['numRounds'] = nbRounds.toString();
    vars['numTies'] = ties.toString();
    vars['scoreX'] = spectatorWins.toString();
    vars['scoreY'] = performerWins.toString();
    vars['tiesSuffix'] = ties == 0 ? '' : ties == 1 ? ', avec 1 égalité' : ', avec $ties égalités';

    // Legacy
    vars['X'] = spectatorWins.toString();
    vars['Y'] = performerWins.toString();
    vars['ties'] = ties.toString();

    for (int i = 0; i < nbRounds; i++) {
      vars['choice${i + 1}'] = spectatorMoves[i];
      vars['choiceS${i + 1}'] = spectatorMoves[i];
      vars['choiceP${i + 1}'] = performerMoves[i];
    }

    // Win/Loss/Tie choice sample variables
    final frOrdinals = ['première', 'deuxième', 'troisième', 'quatrième', 'cinquième'];
    int sCount = 0, pCount = 0, tCount = 0;
    for (int i = 0; i < nbRounds; i++) {
      final outcome = i < outcomes.length ? outcomes[i] : 'T';
      final roundName = templates['__roundName_${i + 1}__'] ??
          (i < frOrdinals.length ? frOrdinals[i] : '${i + 1}ème');
      if (outcome == 'S') {
        sCount++;
        vars['winChoiceS$sCount'] = spectatorMoves[i];
        vars['whenWinS$sCount'] = roundName;
        vars['loseChoiceP$sCount'] = performerMoves[i];
      } else if (outcome == 'P') {
        pCount++;
        vars['winChoiceP$pCount'] = performerMoves[i];
        vars['whenWinP$pCount'] = roundName;
        vars['loseChoiceS$pCount'] = spectatorMoves[i];
      } else {
        tCount++;
        vars['whenTie$tCount'] = roundName;
        vars['tiePosition$tCount'] = '${i + 1}';
        vars['tieChoice$tCount'] = spectatorMoves[i];
      }
    }

    // tieTextOrNoTieText — 3 tiers: 0 → noTieText, 1-3 → tieText, >3 → tieTextHigh.
    if (ties == 0) {
      vars['tieTextOrNoTieText'] = templates['__noTieText__'] ?? '';
    } else {
      final tieTextLow = templates['__tieText__'] ?? '';
      final tieTextHigh = templates['__tieTextHigh__'] ?? '';
      vars['tieTextOrNoTieText'] = ties > 3
          ? (tieTextHigh.isNotEmpty ? tieTextHigh : tieTextLow)
          : (tieTextLow.isNotEmpty ? tieTextLow : tieTextHigh);
    }

    // Reuse the per-round outcome list built above for the conditional vars.
    final sampleOutcomes = outcomes;

    // Who scores first
    if (spectatorWins > 0) {
      vars['whoScoresFirst'] = templates['__spectatorScoresFirst__'] ?? '';
    } else if (performerWins > 0) {
      vars['whoScoresFirst'] = templates['__performerScoresFirst__'] ?? '';
    } else {
      vars['whoScoresFirst'] = '';
    }

    // Last round outcome
    if (sampleOutcomes.isNotEmpty) {
      final last = sampleOutcomes.last;
      if (last == 'S') vars['lastRoundOutcomeText'] = templates['__lastRoundSpectatorWin__'] ?? '';
      else if (last == 'P') vars['lastRoundOutcomeText'] = templates['__lastRoundPerformerWin__'] ?? '';
      else vars['lastRoundOutcomeText'] = templates['__lastRoundTie__'] ?? '';
    } else {
      vars['lastRoundOutcomeText'] = '';
    }

    vars['comebackText'] = '';
    vars['earlyRoundsText'] = '';

    // Per-round outcome text
    for (int i = 0; i < nbRounds; i++) {
      final roundNum = i + 1;
      String outcomeText = '';
      if (i < sampleOutcomes.length) {
        final outcome = sampleOutcomes[i];
        if (outcome == 'S') outcomeText = templates['__round${roundNum}_spectatorWin__'] ?? '';
        else if (outcome == 'P') outcomeText = templates['__round${roundNum}_performerWin__'] ?? '';
        else outcomeText = templates['__round${roundNum}_tie__'] ?? '';
      }
      vars['round${roundNum}OutcomeText'] = outcomeText;
    }

    return vars;
  }
}
