import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/models.dart';
import '../engine/engine.dart';
import '../data/data.dart';
import 'settings_provider.dart';

enum GameState {
  idle,
  setup,
  playing,
  roundComplete,
  generatingNarrative,
  preview,
  complete,
}

class GameProvider extends ChangeNotifier {
  final GameEngine _engine = GameEngine();
  final NarrativeEngine _narrativeEngine = NarrativeEngine();
  final SessionRepository? _repository;
  final SettingsProvider? _settingsProvider;

  GameState _state = GameState.idle;
  GameType? _selectedGameType;
  PresetType? _presetType;
  Preset? _currentPreset;
  Preset? get currentPreset => _currentPreset;
  String? _lastBankKey;
  String? get lastBankKey => _lastBankKey;
  InputMode _inputMode = InputMode.preprogrammed;
  PredictionMode _predictionMode = PredictionMode.game;
  StealthInputMethod _stealthInputMethod = StealthInputMethod.assistant;
  List<String> _options = [];
  List<String> _preprogrammedSequence = [];
  int _totalRounds = 3;
  String _player1Name = 'Me';
  String _player2Name = 'You';
  bool _firstPerson = true;
  String? _generatedNarrative;
  ComputedResult? _computedResult;
  String? _error;
  String? _lastFreeTextValue; // Stored from assistant free text ({free_text})
  int _acrosticPosition = 0; // 0=auto, 1-6=fixed, -1=input

  String? get lastFreeTextValue => _lastFreeTextValue;
  int get acrosticPosition => _acrosticPosition;

  void setAcrosticPosition(int pos) {
    _acrosticPosition = pos;
    notifyListeners();
  }

  // Routine chaining
  List<String> _chainedNarratives = [];
  Map<String, String> _chainNarrativesByPresetId = {}; // presetId -> narrative
  bool _isChaining = false;
  int _chainTotal = 0;
  int _chainCurrentIndex = 0;
  List<String> _routineInputOrder = [];  // preset IDs in input order
  List<String> _routineOutputOrder = []; // preset IDs in output order

  bool get isChaining => _isChaining;
  int get chainTotal => _chainTotal;
  int get chainCurrentIndex => _chainCurrentIndex;
  List<String> get routineInputOrder => _routineInputOrder;
  List<String> get routineOutputOrder => _routineOutputOrder;
  bool get hasNextPreset => _isChaining && _chainCurrentIndex < _chainTotal - 1;

  /// Get the next preset ID in the routine input order
  String? getNextPresetId() {
    if (!_isChaining) return null;
    final nextIndex = _chainCurrentIndex + 1;
    if (nextIndex >= _routineInputOrder.length) return null;
    return _routineInputOrder[nextIndex];
  }

  /// Accumulate the current narrative and return the next preset ID
  String? completeChainStep() {
    if (_generatedNarrative != null && _currentPreset != null) {
      _chainNarrativesByPresetId[_currentPreset!.id] = _generatedNarrative!;
    }
    _chainCurrentIndex++;
    return getNextPresetId();
  }

  /// Finalize the chain: concatenate narratives in OUTPUT order
  void finalizeChain() {
    // Add the last narrative
    if (_generatedNarrative != null && _currentPreset != null) {
      _chainNarrativesByPresetId[_currentPreset!.id] = _generatedNarrative!;
    }

    // Assemble narratives in output order
    final orderedNarratives = <String>[];
    for (final presetId in _routineOutputOrder) {
      final narrative = _chainNarrativesByPresetId[presetId];
      if (narrative != null && narrative.isNotEmpty) {
        orderedNarratives.add(narrative);
      }
    }

    if (orderedNarratives.isNotEmpty) {
      _generatedNarrative = orderedNarratives.join('\n\n');
    }

    _isChaining = false;
    _chainedNarratives = [];
    _chainNarrativesByPresetId = {};
    _chainTotal = 0;
    _chainCurrentIndex = 0;
    _routineInputOrder = [];
    _routineOutputOrder = [];

    // Auto-copy
    if (_effectiveAutoCopy && _generatedNarrative != null) {
      Clipboard.setData(ClipboardData(text: _generatedNarrative!));
      _launchShortcutIfConfigured();
    }

    _state = GameState.preview;
    notifyListeners();
  }

  /// Set narrative directly from free text (assistant mode)
  void setFreeTextNarrative(String text) {
    _lastFreeTextValue = text;
    _generatedNarrative = text;

    if (!_isChaining) {
      if (_effectiveAutoCopy) {
        Clipboard.setData(ClipboardData(text: text));
        _launchShortcutIfConfigured();
      }
    }

    _state = GameState.preview;
    notifyListeners();
  }

  void startChain({
    required List<String> inputOrder,
    required List<String> outputOrder,
  }) {
    _chainedNarratives = [];
    _chainNarrativesByPresetId = {};
    _isChaining = true;
    _chainTotal = inputOrder.length;
    _chainCurrentIndex = 0;
    _routineInputOrder = List.from(inputOrder);
    _routineOutputOrder = List.from(outputOrder);
  }

  // Stealth mode support
  String? _temporaryPerformerChoice;
  bool _hasPerformerChoiceThisRound = false;

  GameProvider(this._repository, {SettingsProvider? settingsProvider})
      : _settingsProvider = settingsProvider;

  // Getters
  GameState get state => _state;
  GameSession? get currentSession => _engine.currentSession;
  GameType? get selectedGameType => _selectedGameType;
  PresetType? get presetType => _presetType;
  InputMode get inputMode => _inputMode;
  List<String> get options => _options;
  List<String> get preprogrammedSequence => _preprogrammedSequence;
  int get totalRounds => _totalRounds;
  String get player1Name => _player1Name;
  String get player2Name => _player2Name;
  bool get firstPerson => _firstPerson;
  String? get generatedNarrative => _generatedNarrative;
  ComputedResult? get computedResult => _computedResult;
  String? get error => _error;
  int get currentRound => _engine.currentRound;
  bool get hasActiveGame => _engine.hasActiveSession;
  bool get hasAllRounds => _engine.hasAllRounds;
  PredictionMode get predictionMode => _predictionMode;
  StealthInputMethod get stealthInputMethod => _stealthInputMethod;
  bool get hasPerformerChoiceForCurrentRound => _hasPerformerChoiceThisRound;

  /// Get last narrative trace (for debug panel)
  NarrativeTrace? get lastNarrativeTrace => _narrativeEngine.lastTrace;

  /// Get current narrative engine version (always V2)
  NarrativeEngineVersion get narrativeEngineVersion => NarrativeEngineVersion.v2;

  /// Start a game from a Preset (new primary method)
  void startGameFromPreset(Preset preset) {
    // Map PresetType to GameType
    // choices -> multiChoice (we stop using binary entirely)
    // duel -> duel
    _selectedGameType = preset.type == PresetType.duel
        ? GameType.duel
        : GameType.multiChoice;
    _presetType = preset.type;
    _currentPreset = preset;
    _acrosticPosition = preset.acrosticPosition;

    _inputMode = preset.inputMode;
    _predictionMode = preset.predictionMode;
    _stealthInputMethod = preset.stealthInputMethod;
    _options = List.from(preset.labels);
    _totalRounds = preset.nbRounds;

    // Convert performer sequence from indices to labels if preprogrammed AND game mode
    // In direct mode, no performer sequence is needed
    if (preset.predictionMode == PredictionMode.game &&
        preset.inputMode == InputMode.preprogrammed &&
        preset.performerSequence != null) {
      _preprogrammedSequence = preset.performerSequence!
          .map((idx) => idx < preset.labels.length ? preset.labels[idx] : preset.labels[0])
          .toList();
    } else {
      _preprogrammedSequence = [];
    }

    // Default names for duel, use generic for choices
    if (_selectedGameType == GameType.duel) {
      _player1Name = 'Me';
      _player2Name = 'You';
      _firstPerson = true;
    } else {
      _player1Name = 'Performer';
      _player2Name = 'Spectator';
      _firstPerson = false;
    }

    _state = GameState.setup;
    _error = null;
    _generatedNarrative = null;
    _computedResult = null;

    // Start the game immediately
    try {
      _engine.startNewGame(
        gameType: _selectedGameType!,
        inputMode: _inputMode,
        options: _options,
        player1Name: _player1Name,
        player2Name: _player2Name,
        firstPerson: _firstPerson,
        preprogrammedSequence: (preset.predictionMode == PredictionMode.game && _inputMode == InputMode.preprogrammed)
            ? _preprogrammedSequence
            : null,
        totalRounds: _totalRounds,
        language: preset.language,
        predictionMode: preset.predictionMode,
        narratorVoice: preset.narratorVoice,
        addressMode: preset.addressMode,
        spectatorName: preset.spectatorName,
        actorName: preset.actorName,
        participantName: preset.participantName,
        customPreprogrammedBanks: preset.customPreprogrammedBanks,
        customDuelBankTemplates: preset.customDuelBankTemplates,
        customChoicesBankTemplates: preset.customChoicesBankTemplates,
        choicesNarrativeMode: preset.choicesNarrativeMode,
        duelNarrativeMode: preset.duelNarrativeMode,
        duelMode: preset.duelMode,
        targetScore: preset.targetScore,
        preprogrammedTieStrategy: preset.preprogrammedTieStrategy,
      );
      _state = GameState.playing;
    } catch (e) {
      _error = e.toString();
    }

    notifyListeners();
  }

  /// Complete a FREE_WILL game with the stealth input result.
  ///
  /// When `runtimeLabels` is provided (3 strings), it overrides the saved
  /// object labels for THIS performance only. The narrative is generated
  /// using the original labels (so custom bank templates and the permutation
  /// index keep working), then post-processed to swap original → runtime
  /// labels in the final text. The saved preset is untouched.
  Future<void> completeFreeWill(
    FreeWillResult result,
    Preset preset, {
    List<String>? runtimeLabels,
  }) async {
    final config = preset.freeWillConfig!;
    _lastBankKey = 'TAKE:${result.takeObject}|GIVE:${result.giveObject}|TABLE:${result.tableObject}';

    // Mode-driven: respect the user's explicit choice in the editor. The
    // selected mode wins, even if the other mode also has stored data
    // (kept for safety when toggling back and forth).
    final singleTpl = preset.freeWillBankMode == 'single'
        ? preset.freeWillSingleTemplate
        : null;
    final sixTpls = preset.freeWillBankMode == 'six'
        ? preset.customFreeWillBankTemplates
        : null;

    // Generate narrative directly via bank generators
    String narrative;
    if (preset.language == Language.french) {
      narrative = FreeWillBankGeneratorFR.generateWithCustom(
        takeObject: result.takeObject,
        giveObject: result.giveObject,
        tableObject: result.tableObject,
        canonicalObjects: config.objects,
        swapCount: result.swapCount,
        suggestChangeOfMind: config.suggestChangeOfMind,
        customTemplates: sixTpls,
        singleTemplate: singleTpl,
        changeMindText: config.changeMindText,
        noChangeMindText: config.noChangeMindText,
      );
    } else {
      narrative = FreeWillBankGeneratorEN.generateWithCustom(
        takeObject: result.takeObject,
        giveObject: result.giveObject,
        tableObject: result.tableObject,
        canonicalObjects: config.objects,
        swapCount: result.swapCount,
        suggestChangeOfMind: config.suggestChangeOfMind,
        customTemplates: sixTpls,
        singleTemplate: singleTpl,
        changeMindText: config.changeMindText,
        noChangeMindText: config.noChangeMindText,
      );
    }

    if (runtimeLabels != null && runtimeLabels.length == 3) {
      // Replace longest names first to avoid one name being a substring of
      // another (e.g. "phone" inside "téléphone").
      final indices = [0, 1, 2]
        ..sort((a, b) => config.objects[b].length.compareTo(config.objects[a].length));
      for (final i in indices) {
        final original = config.objects[i];
        final override = runtimeLabels[i].trim();
        if (override.isEmpty || override == original) continue;
        narrative = narrative.replaceAll(original, override);
      }
    }

    _generatedNarrative = narrative;

    // Don't auto-copy if chaining
    if (!_isChaining) {
      if (_effectiveAutoCopy && _generatedNarrative != null) {
        Clipboard.setData(ClipboardData(text: _generatedNarrative!));
        _launchShortcutIfConfigured();
      }
    }

    _state = GameState.preview;
    notifyListeners();
  }

  Future<void> completeMultipleOut(int selectedIndex, Preset preset) async {
    if (preset.multipleOutTexts == null ||
        selectedIndex < 0 ||
        selectedIndex >= preset.multipleOutTexts!.length) {
      _error = 'Invalid selection';
      notifyListeners();
      return;
    }

    _generatedNarrative = preset.multipleOutTexts![selectedIndex];
    _lastBankKey = '$selectedIndex';

    // Auto-copy if enabled
    if (_effectiveAutoCopy && _generatedNarrative != null) {
      Clipboard.setData(ClipboardData(text: _generatedNarrative!));
      _launchShortcutIfConfigured();
    }

    _state = GameState.preview;
    notifyListeners();
  }

  // Legacy: Setup Phase (kept for compatibility)
  void initializeSetup(GameType gameType) {
    _selectedGameType = gameType;
    _presetType = gameType == GameType.duel ? PresetType.duel : PresetType.choices;
    _inputMode = InputMode.preprogrammed;
    _options = List.from(gameType.defaultOptions);
    _totalRounds = 3;
    _preprogrammedSequence = List.filled(_totalRounds, gameType.defaultOptions[0]);
    _player1Name = 'Me';
    _player2Name = 'You';
    _firstPerson = true;
    _state = GameState.setup;
    _error = null;
    notifyListeners();
  }

  void updateInputMode(InputMode mode) {
    _inputMode = mode;
    notifyListeners();
  }

  void updateOptions(List<String> newOptions) {
    _options = newOptions;
    // Reset preprogrammed sequence with new options
    if (_options.isNotEmpty) {
      _preprogrammedSequence = List.filled(_totalRounds, _options[0]);
    }
    notifyListeners();
  }

  void updateOption(int index, String value) {
    if (index >= 0 && index < _options.length) {
      _options[index] = value;
      notifyListeners();
    }
  }

  void updatePreprogrammedChoice(int roundIndex, String choice) {
    if (roundIndex >= 0 && roundIndex < _totalRounds && _options.contains(choice)) {
      if (roundIndex < _preprogrammedSequence.length) {
        _preprogrammedSequence[roundIndex] = choice;
      }
      notifyListeners();
    }
  }

  void updatePlayerNames(String player1, String player2) {
    _player1Name = player1;
    _player2Name = player2;
    notifyListeners();
  }

  void updateFirstPerson(bool value) {
    _firstPerson = value;
    notifyListeners();
  }

  // Game Phase
  bool startGame() {
    if (_selectedGameType == null) {
      _error = 'No game type selected';
      notifyListeners();
      return false;
    }

    // Validate options
    if (_options.any((o) => o.trim().isEmpty)) {
      _error = 'All options must have a value';
      notifyListeners();
      return false;
    }

    try {
      _engine.startNewGame(
        gameType: _selectedGameType!,
        inputMode: _inputMode,
        options: _options,
        player1Name: _player1Name,
        player2Name: _player2Name,
        firstPerson: _firstPerson,
        preprogrammedSequence:
            _inputMode == InputMode.preprogrammed ? _preprogrammedSequence : null,
        totalRounds: _totalRounds,
      );
      _state = GameState.playing;
      _error = null;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  bool recordChoice({
    required String spectatorChoice,
    String? performerChoice,
  }) {
    try {
      _engine.recordRound(
        spectatorChoice: spectatorChoice,
        performerChoice: performerChoice,
      );

      if (_engine.hasAllRounds) {
        _computeAndGenerateNarrative();
      } else {
        _state = GameState.roundComplete;
      }

      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  void proceedToNextRound() {
    _state = GameState.playing;
    notifyListeners();
  }

  // Narrative Phase
  Future<void> _computeAndGenerateNarrative({NarrativeEngineVersion? engineVersion}) async {
    _state = GameState.generatingNarrative;
    notifyListeners();

    try {
      // Compute results
      _computedResult = _engine.computeResults();

      // Generate narrative using session's language
      _generatedNarrative = _narrativeEngine.generate(
        session: _engine.currentSession!,
      );
      _lastBankKey = _narrativeEngine.lastBankKey;

      // Store narrative in computed result
      _computedResult = _computedResult!.copyWith(
        generatedText: _generatedNarrative,
      );

      // Don't auto-copy if chaining (will be done at finalize)
      if (!_isChaining) {
        if (_effectiveAutoCopy && _generatedNarrative != null) {
          Clipboard.setData(ClipboardData(text: _generatedNarrative!));
          _launchShortcutIfConfigured();
        }
      }

      _state = GameState.preview;
    } catch (e) {
      _error = e.toString();
    }
    notifyListeners();
  }

  /// Auto-copy enabled? Per-preset only — no global fallback.
  bool get _effectiveAutoCopy => _currentPreset?.autoCopyOverride ?? false;

  /// Shortcut name to launch — per-preset only (empty = no shortcut).
  String get _effectiveShortcutName => _currentPreset?.shortcutNameOverride ?? '';

  void _launchShortcutIfConfigured() {
    // In 'both' mode, shortcut is launched after image save (handled by navigation)
    // In 'image' mode, no shortcut needed
    if (_currentPreset?.outputMode == 'both' || _currentPreset?.outputMode == 'image') return;
    final name = _effectiveShortcutName;
    if (name.trim().isEmpty) return;
    final encoded = Uri.encodeComponent(name.trim());
    final uri = Uri.parse('shortcuts://run-shortcut?name=$encoded');
    launchUrl(uri, mode: LaunchMode.externalApplication);
  }


  void regenerateNarrative() {
    if (_engine.currentSession == null) return;

    // Use regenerate for a new random seed
    _generatedNarrative = _narrativeEngine.regenerate(
      session: _engine.currentSession!,
    );

    // Update computed result
    _computedResult = _computedResult?.copyWith(generatedText: _generatedNarrative);

    notifyListeners();
  }

  /// Regenerate narrative with live cues override
  void regenerateWithCues(LiveCues cues) {
    if (_engine.currentSession == null) return;

    // Create a modified session with cues applied
    GameSession modifiedSession = _engine.currentSession!;

    // Apply spectator name if provided
    if (cues.hasSpectatorName) {
      modifiedSession = modifiedSession.copyWith(
        spectatorName: cues.spectatorName,
        participantName: cues.spectatorName, // For duel mode
      );
    }

    // Apply reference mode if provided
    if (cues.referenceMode != null) {
      modifiedSession = modifiedSession.copyWith(
        narratorVoice: cues.referenceMode!.toNarratorVoice(),
        addressMode: cues.referenceMode!.toAddressMode(),
      );
    }

    // Generate with modified session
    _generatedNarrative = _narrativeEngine.regenerate(
      session: modifiedSession,
    );

    // Update computed result
    _computedResult = _computedResult?.copyWith(generatedText: _generatedNarrative);

    notifyListeners();
  }

  // Completion Phase
  Future<void> confirmAndSave() async {
    if (_generatedNarrative == null || _computedResult == null) return;

    try {
      final session = _engine.finalizeSession(_computedResult!);
      await _repository?.saveSession(session);
      _state = GameState.complete;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  // Load existing session (for viewing history)
  void loadSession(GameSession session) {
    _selectedGameType = session.gameType;
    _presetType = session.gameType == GameType.duel ? PresetType.duel : PresetType.choices;
    _inputMode = session.inputMode;
    _options = List.from(session.options);
    _preprogrammedSequence = session.preprogrammedSequence ?? [];
    _totalRounds = session.totalRounds;
    _player1Name = session.player1Name;
    _player2Name = session.player2Name;
    _firstPerson = session.firstPerson;
    _computedResult = session.computed;

    // Get narrative from computed result if available
    if (_computedResult != null && _computedResult!.generatedText != null) {
      _generatedNarrative = _computedResult!.generatedText;
    }

    _engine.loadSession(session);
    _state = GameState.preview;
    notifyListeners();
  }

  // Reset
  void reset() {
    _engine.reset();
    _state = GameState.idle;
    _selectedGameType = null;
    _presetType = null;
    _inputMode = InputMode.preprogrammed;
    _options = [];
    _preprogrammedSequence = [];
    _totalRounds = 3;
    _player1Name = 'Me';
    _player2Name = 'You';
    _firstPerson = true;
    _generatedNarrative = null;
    _computedResult = null;
    _error = null;
    notifyListeners();
  }

  // Get session JSON for debug
  String getSessionJson() {
    if (_engine.currentSession == null) return '{}';
    return _engine.currentSession!.toJson().toString();
  }

  // ============ STEALTH MODE SUPPORT ============

  /// Set temporary performer choice (for two-inputs stealth mode)
  void setTemporaryPerformerChoice(String choice) {
    _temporaryPerformerChoice = choice;
    _hasPerformerChoiceThisRound = true;
    notifyListeners();
  }

  /// Get temporary performer choice
  String? getTemporaryPerformerChoice() {
    return _temporaryPerformerChoice;
  }

  /// Clear temporary performer choice
  void clearTemporaryPerformerChoice() {
    _temporaryPerformerChoice = null;
    _hasPerformerChoiceThisRound = false;
  }

  /// Undo the last round (go back one round)
  void undoLastRound() {
    if (_engine.currentRound <= 1) return;

    // Clear any temporary state
    clearTemporaryPerformerChoice();

    // Engine should handle removing the last recorded round
    _engine.undoLastRound();
    _state = GameState.playing;
    notifyListeners();
  }

  /// Reset all rounds and start from beginning
  void resetAllRounds() {
    // Clear any temporary state
    clearTemporaryPerformerChoice();

    // Engine should clear all recorded rounds but keep session active
    _engine.resetRounds();
    _state = GameState.playing;
    notifyListeners();
  }
}
