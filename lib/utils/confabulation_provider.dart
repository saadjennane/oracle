import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/firebase_service.dart';
import '../models/confabulation_preset.dart';
import '../data/confabulation_repository.dart';
import '../engine/confabulation_engine.dart';
import '../engine/acrostic_engine.dart';
import '../services/external_api_service.dart';
import '../services/icloud_sync_service.dart';
import '../services/tombstone_store.dart';
import 'settings_provider.dart';
import 'acrostic_provider.dart';

/// State for a confabulation run session
class ConfabulationRunState {
  final ConfabulationPreset preset;
  final int currentSlotIndex;
  final Map<String, int> chosenIndexBySlotId;
  final List<String> slotOrder;
  final bool isComplete;

  const ConfabulationRunState({
    required this.preset,
    required this.currentSlotIndex,
    required this.chosenIndexBySlotId,
    required this.slotOrder,
    required this.isComplete,
  });

  factory ConfabulationRunState.start(ConfabulationPreset preset) {
    final slotOrder = ConfabulationEngine.getSlotOrderInTemplate(preset.textTemplate);
    return ConfabulationRunState(
      preset: preset,
      currentSlotIndex: 0,
      chosenIndexBySlotId: {},
      slotOrder: slotOrder,
      isComplete: slotOrder.isEmpty,
    );
  }

  ConfabSlot? get currentSlot {
    if (isComplete || currentSlotIndex >= slotOrder.length) return null;
    return preset.getSlotById(slotOrder[currentSlotIndex]);
  }

  int get totalSlots => slotOrder.length;
  int get completedSlots => currentSlotIndex;
  double get progress => totalSlots > 0 ? completedSlots / totalSlots : 1.0;

  ConfabulationRunState selectOption(int optionIndex) {
    if (isComplete || currentSlot == null) return this;

    final newChoices = Map<String, int>.from(chosenIndexBySlotId);
    newChoices[currentSlot!.id] = optionIndex;

    final nextIndex = currentSlotIndex + 1;
    final complete = nextIndex >= slotOrder.length;

    return ConfabulationRunState(
      preset: preset,
      currentSlotIndex: nextIndex,
      chosenIndexBySlotId: newChoices,
      slotOrder: slotOrder,
      isComplete: complete,
    );
  }

  String get finalText {
    return ConfabulationEngine.renderFinal(preset, chosenIndexBySlotId);
  }

  String get debugLogs {
    return ConfabulationEngine.generateDebugLogs(
      preset: preset,
      chosenIndexBySlotId: chosenIndexBySlotId,
      finalText: finalText,
    );
  }
}

/// Provider for Confabulation preset management and run state
class ConfabulationProvider extends ChangeNotifier {
  final ConfabulationRepository? _repository;
  final SettingsProvider? _settingsProvider;
  List<ConfabulationPreset> _presets = [];
  bool _isLoading = false;
  String? _error;

  // Run state
  ConfabulationRunState? _runState;

  AcrosticProvider? _acrosticProvider;

  /// When the preset's acrosticPosition is -1 (Input), the performer captures
  /// it on a pre-run screen. The value is stashed here until the engine reads
  /// it during text resolution. Reset after each run.
  int? _pendingAcrosticPosition;

  void setPendingAcrosticPosition(int position) {
    _pendingAcrosticPosition = position;
  }

  /// Free text received from the assistant webapp via the URL shortcut
  /// oass.app/{id}/{word}. Used to resolve ((ACROSTIC_URL)).
  String? _pendingFreeText;
  StreamSubscription<Map<String, dynamic>?>? _freeTextSubscription;

  ConfabulationProvider(this._repository, {SettingsProvider? settingsProvider, AcrosticProvider? acrosticProvider})
      : _settingsProvider = settingsProvider,
        _acrosticProvider = acrosticProvider;

  void setAcrosticProvider(AcrosticProvider provider) {
    _acrosticProvider = provider;
  }

  // Getters
  List<ConfabulationPreset> get presets => _presets;
  bool get isLoading => _isLoading;
  bool get isEmpty => _presets.isEmpty;
  String? get error => _error;
  ConfabulationRunState? get runState => _runState;
  bool get isRunning => _runState != null && !_runState!.isComplete;

  /// Load all presets from storage
  Future<void> loadPresets() async {
    if (_repository == null) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _presets = await _repository!.listPresets();
    } catch (e) {
      _error = 'Failed to load presets: $e';
      _presets = [];
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Add a new preset
  Future<bool> addPreset(ConfabulationPreset preset) async {
    if (_repository == null) {
      _error = 'Storage not available';
      notifyListeners();
      return false;
    }

    // Validate preset
    final validation = ConfabulationEngine.validatePreset(preset);
    if (!validation.isValid) {
      _error = validation.errors.first;
      notifyListeners();
      return false;
    }

    try {
      final stamped = preset.copyWith(updatedAt: DateTime.now().toUtc());
      await _repository!.savePreset(stamped);
      // Append at the end — the home screen sorts by createdAt ascending,
      // so newly created confabs land at the bottom of the chronological list.
      _presets.add(stamped);
      _error = null;
      notifyListeners();
      ICloudSyncService.scheduleAutoPush();
      return true;
    } catch (e) {
      _error = 'Failed to save preset: $e';
      notifyListeners();
      return false;
    }
  }

  /// Update a confab preset's createdAt — used by the home-screen drag-reorder
  /// to position the item between its new neighbours in the merged
  /// chronological list (presets + confabs).
  Future<void> setPresetCreatedAt(String id, DateTime createdAt) async {
    final idx = _presets.indexWhere((p) => p.id == id);
    if (idx < 0) return;
    final updated = _presets[idx].copyWith(createdAt: createdAt);
    _presets[idx] = updated;
    notifyListeners();
    if (_repository != null) {
      await _repository!.savePreset(updated);
      ICloudSyncService.scheduleAutoPush();
    }
  }

  /// Update an existing preset
  Future<bool> updatePreset(ConfabulationPreset preset) async {
    if (_repository == null) {
      _error = 'Storage not available';
      notifyListeners();
      return false;
    }

    // Validate preset
    final validation = ConfabulationEngine.validatePreset(preset);
    if (!validation.isValid) {
      _error = validation.errors.first;
      notifyListeners();
      return false;
    }

    try {
      final stamped = preset.copyWith(updatedAt: DateTime.now().toUtc());
      await _repository!.updatePreset(stamped);

      // Update in local list
      final index = _presets.indexWhere((p) => p.id == stamped.id);
      if (index >= 0) {
        _presets[index] = stamped;
      } else {
        _presets.insert(0, stamped);
      }

      _error = null;
      notifyListeners();
      ICloudSyncService.scheduleAutoPush();
      return true;
    } catch (e) {
      _error = 'Failed to update preset: $e';
      notifyListeners();
      return false;
    }
  }

  /// Delete a preset by ID
  Future<bool> deletePreset(String id) async {
    if (_repository == null) {
      _error = 'Storage not available';
      notifyListeners();
      return false;
    }

    try {
      await _repository!.deletePreset(id);
      _presets.removeWhere((p) => p.id == id);
      await TombstoneStore.addDeletedConfab(id);
      _error = null;
      notifyListeners();
      ICloudSyncService.scheduleAutoPush();
      return true;
    } catch (e) {
      _error = 'Failed to delete preset: $e';
      notifyListeners();
      return false;
    }
  }

  /// Get a preset by ID
  ConfabulationPreset? getPresetById(String id) {
    try {
      return _presets.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Validate a preset and return the result
  ConfabValidationResult validatePreset(ConfabulationPreset preset) {
    return ConfabulationEngine.validatePreset(preset);
  }

  /// Start a confabulation run with a preset
  // Baselines captured the moment the preset starts. Resolution polls until
  // the API count strictly exceeds the baseline — i.e. waits for the spectator
  // to submit a NEW value. This way past submissions are not picked up.
  int? _injectBaseline;
  int? _elipsBaseline;

  void startRun(ConfabulationPreset preset) {
    _runState = ConfabulationRunState.start(preset);
    _resolvedFinalText = null;
    _pendingFreeText = null;
    _injectBaseline = null;
    _elipsBaseline = null;
    _captureApiBaselines(preset);
    // If the template needs a word from the spectator URL shortcut
    // (oass.app/{id}/{word}), start polling Firebase so the word can arrive
    // at any time during the run.
    final needsFreeText = preset.textTemplate.contains('((ACROSTIC_URL))');
    if (needsFreeText) {
      final assistantId = _settingsProvider?.assistantId;
      if (assistantId != null && assistantId.isNotEmpty) {
        _freeTextSubscription?.cancel();
        _freeTextSubscription = FirebaseService.pollInput(assistantId).listen((input) {
          if (input == null) return;
          if (input['type'] == 'free_text' && input['value'] is String) {
            _pendingFreeText = input['value'] as String;
            FirebaseService.clearInput(assistantId);
            notifyListeners();
            // If the user has already finished filling slots and we were
            // waiting on this word, re-resolve to substitute it into the text.
            if (_runState != null && _runState!.isComplete) {
              _resolveAndFinalize();
            }
          }
        });
      }
    }
    // 0-slot template (only API/acrostic variables): no input phase, so
    // selectOption() will never run. Trigger resolution + copy/shortcut
    // immediately so the result screen sees a resolved text.
    if (_runState!.isComplete) {
      _resolveAndFinalize();
    }
    notifyListeners();
  }

  /// Select an option for the current slot during a run
  void selectOption(int optionIndex) {
    if (_runState == null) return;
    _runState = _runState!.selectOption(optionIndex);

    // Resolve API/acrostic variables when complete
    if (_runState!.isComplete) {
      _resolveAndFinalize();
    }

    notifyListeners();
  }

  String? _resolvedFinalText;
  String? get resolvedFinalText => _resolvedFinalText;

  /// Fire-and-forget baseline capture. Resolution will use whatever value is
  /// available at the time it runs (null = unknown, treated as "use first
  /// fetched value as baseline" by the polling helpers).
  void _captureApiBaselines(ConfabulationPreset preset) {
    final settings = _settingsProvider;
    if (settings == null) return;
    final template = preset.textTemplate;
    final needsInject = (template.contains('((INJECT))') ||
            template.contains('((ACROSTIC_INJECT))') ||
            template.contains('((AITransformInject))')) &&
        settings.hasInjectConfig;
    final needsElips = (template.contains('((ELIPS') ||
            template.contains('((ACROSTIC_ELIPS') ||
            template.contains('((AITransformElips')) &&
        settings.hasElipsConfig;
    if (needsInject) {
      ExternalApiService.fetchInject(settings.injectId).then((r) {
        if (r != null) _injectBaseline = r.count;
      });
    }
    if (needsElips) {
      ExternalApiService.fetchElips(settings.elipsId, settings.elipsApiKey).then((r) {
        if (r != null) _elipsBaseline = r.count;
      });
    }
  }

  static const Duration _pollInterval = Duration(seconds: 2);
  static const int _pollMaxAttempts = 90; // 3 minutes worst case

  /// Poll Inject API until `count > baseline` (i.e. a new value arrived after
  /// the preset started). If `baseline` is still null when polling starts (e.g.
  /// the baseline fetch failed or was slow), the first fetch becomes the
  /// effective baseline so we still wait for the NEXT submission.
  Future<InjectResult?> _pollNextInject(String id) async {
    int? baseline = _injectBaseline;
    for (int i = 0; i < _pollMaxAttempts; i++) {
      final r = await ExternalApiService.fetchInject(id);
      if (r != null) {
        if (baseline == null) {
          baseline = r.count;
          _injectBaseline = baseline;
        } else if (r.count > baseline && r.value.isNotEmpty) {
          return r;
        }
      }
      if (i < _pollMaxAttempts - 1) await Future.delayed(_pollInterval);
    }
    return null;
  }

  Future<ElipsResult?> _pollNextElips(String id, String apiKey) async {
    int? baseline = _elipsBaseline;
    for (int i = 0; i < _pollMaxAttempts; i++) {
      final r = await ExternalApiService.fetchElips(id, apiKey);
      if (r != null) {
        if (baseline == null) {
          baseline = r.count;
          _elipsBaseline = baseline;
        } else if (r.count > baseline) {
          return r;
        }
      }
      if (i < _pollMaxAttempts - 1) await Future.delayed(_pollInterval);
    }
    return null;
  }

  Future<void> _resolveAndFinalize() async {
    var text = _runState!.finalText;
    final settings = _settingsProvider;
    if (settings == null) {
      _resolvedFinalText = text;
      _copyAndLaunch(text);
      notifyListeners();
      return;
    }

    final preset = _runState!.preset;

    // Inject and Elips are fetched ONCE per resolve via polling helpers that
    // wait for the spectator's NEXT submission (count > baseline). The result
    // is reused across all referenced variants below — direct, transform, and
    // acrostic — so we never poll for the same API twice.
    final needsInject = (text.contains('((INJECT))') ||
            text.contains('((ACROSTIC_INJECT))') ||
            text.contains('((AITransformInject))')) &&
        settings.hasInjectConfig;
    final needsElips = (text.contains('((ELIPS') ||
            text.contains('((ACROSTIC_ELIPS') ||
            text.contains('((AITransformElips')) &&
        settings.hasElipsConfig;

    final injectData = needsInject ? await _pollNextInject(settings.injectId) : null;
    final elipsData = needsElips
        ? await _pollNextElips(settings.elipsId, settings.elipsApiKey)
        : null;

    // ((INJECT))
    if (text.contains('((INJECT))')) {
      text = text.replaceAll('((INJECT))', injectData?.value ?? '');
    }

    // ((ELIPS_*)) — individual fields
    if (text.contains('((ELIPS')) {
      text = text.replaceAll('((ELIPS_ARTIST))', elipsData?.artist ?? '');
      text = text.replaceAll('((ELIPS_SONG))', elipsData?.song ?? '');
      text = text.replaceAll('((ELIPS_WORD))', elipsData?.outputWord ?? '');
    }

    // ((AITransformInject))
    if (text.contains('((AITransformInject))')) {
      if (injectData != null && injectData.value.isNotEmpty && preset.injectTransformPrompt != null) {
        final transformed = await ExternalApiService.transformWithPrompt(
          prompt: preset.injectTransformPrompt!,
          openaiApiKey: settings.openaiApiKey,
          variables: {'value': injectData.value},
        );
        text = text.replaceAll('((AITransformInject))', transformed ?? injectData.value);
      } else {
        text = text.replaceAll('((AITransformInject))', '');
      }
    }

    // ((AITransformElips*))
    if (text.contains('((AITransformElips')) {
      if (elipsData != null) {
        if (text.contains('((AITransformElipsArtist))') && preset.elipsArtistTransformPrompt != null) {
          final t = await ExternalApiService.transformWithPrompt(
            prompt: preset.elipsArtistTransformPrompt!,
            openaiApiKey: settings.openaiApiKey,
            variables: {'value': elipsData.artist},
          );
          text = text.replaceAll('((AITransformElipsArtist))', t ?? elipsData.artist);
        }
        if (text.contains('((AITransformElipsSong))') && preset.elipsSongTransformPrompt != null) {
          final t = await ExternalApiService.transformWithPrompt(
            prompt: preset.elipsSongTransformPrompt!,
            openaiApiKey: settings.openaiApiKey,
            variables: {'value': elipsData.song},
          );
          text = text.replaceAll('((AITransformElipsSong))', t ?? elipsData.song);
        }
        if (text.contains('((AITransformElipsWord))') && preset.elipsWordTransformPrompt != null) {
          final t = await ExternalApiService.transformWithPrompt(
            prompt: preset.elipsWordTransformPrompt!,
            openaiApiKey: settings.openaiApiKey,
            variables: {'value': elipsData.outputWord},
          );
          text = text.replaceAll('((AITransformElipsWord))', t ?? elipsData.outputWord);
        }
      } else {
        text = text.replaceAll('((AITransformElipsArtist))', '');
        text = text.replaceAll('((AITransformElipsSong))', '');
        text = text.replaceAll('((AITransformElipsWord))', '');
      }
    }

    // HighScore variables
    if ((text.contains('((HIGHSCORE_SCORE))') || text.contains('((HIGHSCORE_SCORE+1))') || text.contains('((HIGHSCORE_RANKING))')) && settings.hasHighScoreConfig) {
      final data = await ExternalApiService.fetchHighScore(settings.highScoreApiKey);
      if (data != null) {
        final score = data.effectiveScore;
        text = text.replaceAll('((HIGHSCORE_SCORE))', score.toString());
        text = text.replaceAll('((HIGHSCORE_SCORE+1))', (score + 1).toString());
        text = text.replaceAll('((HIGHSCORE_RANKING))', data.leaderboardRank.toString());
      }
    }

    // Acrostic variants — use preset's bank and position
    final AcrosticEngine acrosticEngine;
    if (_acrosticProvider != null && preset.acrosticLanguage != null) {
      acrosticEngine = _acrosticProvider!.getEngineForLanguage(preset.acrosticLanguage!);
    } else if (_acrosticProvider != null) {
      acrosticEngine = _acrosticProvider!.getEngine();
    } else {
      acrosticEngine = AcrosticEngine(AcrosticEngine.defaultWordBank);
    }
    // If the preset uses "Input" mode (-1), the performer captured the
    // position via AcrosticPositionInputScreen before the run started.
    int acrosticPos = preset.acrosticPosition; // 0=auto, 1-6=fixed, -1=input
    if (acrosticPos == -1) {
      acrosticPos = _pendingAcrosticPosition ?? 0;
    }

    AcrosticResult? _generateAcrostic(String secret) {
      if (acrosticPos > 0) {
        return acrosticEngine.generateAtPosition(secret, acrosticPos);
      }
      return acrosticEngine.generate(secret);
    }

    if (text.contains('((ACROSTIC_INJECT))')) {
      if (injectData != null && injectData.value.isNotEmpty) {
        final acrostic = _generateAcrostic(injectData.value);
        text = text.replaceAll('((ACROSTIC_INJECT))', acrostic?.toDisplayText() ?? injectData.value);
      } else {
        text = text.replaceAll('((ACROSTIC_INJECT))', '');
      }
    }

    if (text.contains('((ACROSTIC_ELIPS')) {
      if (elipsData != null) {
        if (text.contains('((ACROSTIC_ELIPS_ARTIST))') && elipsData.artist.isNotEmpty) {
          final a = _generateAcrostic(elipsData.artist);
          text = text.replaceAll('((ACROSTIC_ELIPS_ARTIST))', a?.toDisplayText() ?? elipsData.artist);
        }
        if (text.contains('((ACROSTIC_ELIPS_SONG))') && elipsData.song.isNotEmpty) {
          final a = _generateAcrostic(elipsData.song);
          text = text.replaceAll('((ACROSTIC_ELIPS_SONG))', a?.toDisplayText() ?? elipsData.song);
        }
        if (text.contains('((ACROSTIC_ELIPS_WORD))') && elipsData.outputWord.isNotEmpty) {
          final a = _generateAcrostic(elipsData.outputWord);
          text = text.replaceAll('((ACROSTIC_ELIPS_WORD))', a?.toDisplayText() ?? elipsData.outputWord);
        }
      } else {
        text = text.replaceAll('((ACROSTIC_ELIPS_ARTIST))', '');
        text = text.replaceAll('((ACROSTIC_ELIPS_SONG))', '');
        text = text.replaceAll('((ACROSTIC_ELIPS_WORD))', '');
      }
    }

    // Resolve URL acrostic using the word received from the spectator URL
    // shortcut (_pendingFreeText). Empty until the word arrives — the UI
    // re-resolves when polling lands.
    if (text.contains('((ACROSTIC_URL))')) {
      final word = _pendingFreeText ?? '';
      if (word.trim().isNotEmpty) {
        final a = _generateAcrostic(word);
        text = text.replaceAll('((ACROSTIC_URL))', a?.toDisplayText() ?? word);
      } else {
        text = text.replaceAll('((ACROSTIC_URL))', '');
      }
    }

    // Clean up
    while (text.contains('\n\n\n')) {
      text = text.replaceAll('\n\n\n', '\n\n');
    }

    _resolvedFinalText = text.trim();
    _copyAndLaunch(_resolvedFinalText!);
    notifyListeners();
  }

  bool get _effectiveAutoCopy => _runState?.preset.autoCopyOverride ?? false;

  String get _effectiveShortcutName => _runState?.preset.shortcutNameOverride ?? '';

  void _copyAndLaunch(String text) {
    if (_effectiveAutoCopy) {
      Clipboard.setData(ClipboardData(text: text));
      _launchShortcutIfConfigured();
    }
  }

  void _launchShortcutIfConfigured() {
    final name = _effectiveShortcutName;
    if (name.trim().isEmpty) return;
    final encoded = Uri.encodeComponent(name.trim());
    final uri = Uri.parse('shortcuts://run-shortcut?name=$encoded');
    launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  /// End the current run
  void endRun() {
    _runState = null;
    _pendingAcrosticPosition = null;
    _pendingFreeText = null;
    _freeTextSubscription?.cancel();
    _freeTextSubscription = null;
    notifyListeners();
  }

  /// Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
