import '../models/models.dart';
import 'pattern_detector.dart';

class GameEngine {
  GameSession? _currentSession;

  GameSession? get currentSession => _currentSession;
  bool get hasActiveSession => _currentSession != null;
  bool get isSessionComplete => _currentSession?.isComplete ?? false;
  int get currentRound => _currentSession?.currentRoundNumber ?? 1;
  int get totalRounds => _currentSession?.totalRounds ?? 3;

  /// Check if all rounds are complete
  /// For Fixed Rounds: rounds.length == totalRounds
  /// For First-To: one player has reached targetScore
  bool get hasAllRounds {
    if (_currentSession == null) return false;

    if (_currentSession!.isFirstTo) {
      return isFirstToComplete;
    }

    return _currentSession!.hasAllRounds;
  }

  /// Check if a First-To game is complete (one player reached target)
  bool get isFirstToComplete {
    if (_currentSession == null) return false;
    if (!_currentSession!.isFirstTo) return false;

    final detector = PatternDetector(_currentSession!);
    final score = detector.calculateDuelScore();

    return score.spectatorScore >= _currentSession!.targetScore ||
        score.performerScore >= _currentSession!.targetScore;
  }

  /// Initialize a new game session
  GameSession startNewGame({
    required GameType gameType,
    required InputMode inputMode,
    required List<String> options,
    String player1Name = 'Me',
    String player2Name = 'You',
    bool firstPerson = true,
    List<String>? preprogrammedSequence,
    int totalRounds = 3,
    Language language = Language.english,
    PredictionMode predictionMode = PredictionMode.game,
    NarratorVoice narratorVoice = NarratorVoice.firstPerson,
    AddressMode addressMode = AddressMode.you,
    String? spectatorName,
    String? actorName,
    String? participantName,
    Map<String, Map<String, String>>? customPreprogrammedBanks,
    Map<String, String>? customDuelBankTemplates,
    Map<String, String>? customChoicesBankTemplates,
    ChoicesNarrativeMode choicesNarrativeMode = ChoicesNarrativeMode.buckets,
    ChoicesNarrativeMode duelNarrativeMode = ChoicesNarrativeMode.buckets,
    DuelMode duelMode = DuelMode.fixedRounds,
    int targetScore = 3,
    PreprogrammedTieStrategy preprogrammedTieStrategy = PreprogrammedTieStrategy.repeat,
  }) {
    // Validate based on duel mode
    if (duelMode == DuelMode.firstTo) {
      // First-To mode: clamp targetScore to valid range
      if (targetScore < 1) targetScore = 1;
      if (targetScore > 5) targetScore = 5;
      // For First-To preprogrammed: sequence needs enough moves for worst case
      // Worst case: (targetScore - 1) + (targetScore - 1) + unlimited ties
      // We require at least enough moves for a close game without ties
      if (predictionMode == PredictionMode.game && inputMode == InputMode.preprogrammed) {
        final minMoves = (targetScore * 2) - 1;
        // Pad sequence if too short
        if (preprogrammedSequence != null && preprogrammedSequence.length < minMoves && options.isNotEmpty) {
          preprogrammedSequence = [
            ...preprogrammedSequence,
            ...List.filled(minMoves - preprogrammedSequence.length, options[0]),
          ];
        }
      }
    } else {
      // Fixed Rounds mode: clamp totalRounds to valid range
      if (totalRounds < 1) totalRounds = 1;
      if (totalRounds > 5) totalRounds = 5;

      // Validate/truncate preprogrammed sequence if in preprogrammed mode AND game mode
      if (predictionMode == PredictionMode.game && inputMode == InputMode.preprogrammed) {
        if (preprogrammedSequence != null && preprogrammedSequence.length > totalRounds) {
          preprogrammedSequence = preprogrammedSequence.sublist(0, totalRounds);
        }
        if (preprogrammedSequence == null || preprogrammedSequence.length != totalRounds) {
          throw ArgumentError('Preprogrammed sequence must have exactly $totalRounds choices');
        }
        for (final choice in preprogrammedSequence) {
          if (!options.contains(choice)) {
            throw ArgumentError('Invalid preprogrammed choice: $choice');
          }
        }
      }
    }

    _currentSession = GameSession(
      gameType: gameType,
      inputMode: inputMode,
      options: options,
      player1Name: player1Name,
      player2Name: player2Name,
      firstPerson: firstPerson,
      preprogrammedSequence: preprogrammedSequence,
      totalRounds: totalRounds,
      language: language,
      predictionMode: predictionMode,
      narratorVoice: narratorVoice,
      addressMode: addressMode,
      spectatorName: spectatorName,
      actorName: actorName,
      participantName: participantName,
      customPreprogrammedBanks: customPreprogrammedBanks,
      customDuelBankTemplates: customDuelBankTemplates,
      customChoicesBankTemplates: customChoicesBankTemplates,
      choicesNarrativeMode: choicesNarrativeMode,
      duelNarrativeMode: duelNarrativeMode,
      duelMode: duelMode,
      targetScore: targetScore,
      preprogrammedTieStrategy: preprogrammedTieStrategy,
    );

    return _currentSession!;
  }

  /// Record a round's choices
  GameSession recordRound({
    required String spectatorChoice,
    String? performerChoice,
  }) {
    if (_currentSession == null) {
      throw StateError('No active session');
    }
    // Use engine's hasAllRounds for First-To support
    if (hasAllRounds) {
      throw StateError('All rounds already completed');
    }

    // Validate spectator choice
    if (!_currentSession!.options.contains(spectatorChoice)) {
      throw ArgumentError('Invalid spectator choice: $spectatorChoice');
    }

    // For two-inputs mode, performer choice is required
    if (_currentSession!.inputMode == InputMode.twoInputs) {
      if (performerChoice == null) {
        throw ArgumentError('Performer choice required in two-inputs mode');
      }
      if (!_currentSession!.options.contains(performerChoice)) {
        throw ArgumentError('Invalid performer choice: $performerChoice');
      }
    }

    final round = RoundInput(
      roundNumber: _currentSession!.currentRoundNumber,
      spectatorChoice: spectatorChoice,
      performerChoice: performerChoice,
    );

    _currentSession = _currentSession!.addRound(round);
    return _currentSession!;
  }

  /// Compute results after all rounds are complete
  ComputedResult computeResults() {
    if (_currentSession == null) {
      throw StateError('No active session');
    }
    // Use engine's hasAllRounds for First-To support
    if (!hasAllRounds) {
      throw StateError('Not all rounds completed');
    }

    final detector = PatternDetector(_currentSession!);
    final patternSummary = detector.analyze();
    final outcomes = detector.computeRoundOutcomes();
    final duelScore = _currentSession!.isDuel ? detector.calculateDuelScore() : null;

    return ComputedResult(
      perRoundOutcome: outcomes,
      duelScore: duelScore,
      patternSummary: patternSummary,
    );
  }

  /// Finalize session with computed result
  GameSession finalizeSession(ComputedResult computed) {
    if (_currentSession == null) {
      throw StateError('No active session');
    }
    // Use engine's hasAllRounds for First-To support
    if (!hasAllRounds) {
      throw StateError('Not all rounds completed');
    }

    _currentSession = _currentSession!.copyWith(computed: computed);
    return _currentSession!;
  }

  /// Reset engine state
  void reset() {
    _currentSession = null;
  }

  /// Load an existing session (for viewing history)
  void loadSession(GameSession session) {
    _currentSession = session;
  }

  /// Get current session for UI display
  GameSession getSession() {
    if (_currentSession == null) {
      throw StateError('No active session');
    }
    return _currentSession!;
  }

  /// Check if a choice is valid
  bool isValidChoice(String choice) {
    return _currentSession?.options.contains(choice) ?? false;
  }

  /// Undo the last recorded round
  void undoLastRound() {
    if (_currentSession == null) return;
    if (_currentSession!.rounds.isEmpty) return;

    _currentSession = _currentSession!.removeLastRound();
  }

  /// Reset all rounds but keep session active
  void resetRounds() {
    if (_currentSession == null) return;

    _currentSession = _currentSession!.clearRounds();
  }
}
