import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../app.dart';
import '../../models/models.dart';
import '../../engine/acrostic_engine.dart';
import '../../services/firebase_service.dart';
import '../../services/external_api_service.dart';
import '../../inputs/free_will_input_state.dart';
import '../../models/stealth_input_method.dart' as fw_im;
import '../../utils/game_provider.dart';
import '../widgets/chain_progress_indicator.dart';
import '../../utils/settings_provider.dart';
import '../../utils/presets_provider.dart';
import '../theme/app_theme.dart';

/// Screen that waits for assistant input via Firebase.
/// The performer sees a waiting screen while the assistant uses the webapp.
class AssistantInputScreen extends StatefulWidget {
  const AssistantInputScreen({super.key});

  @override
  State<AssistantInputScreen> createState() => _AssistantInputScreenState();
}

class _AssistantInputScreenState extends State<AssistantInputScreen> {
  StreamSubscription<Map<String, dynamic>?>? _inputSubscription;
  bool _isInitialized = false;
  String? _statusMessage;
  Preset? _preset;
  int _currentRound = 1;
  int _totalRounds = 1;
  List<String> _chainNames = [];
  int _chainIndex = 0;
  final List<int> _freeWillSelections = [];
  Timer? _freeTextPollTimer;
  int? _lastFreeTextTimestamp;

  /// Set when the spectator is interacting via the decoy webapp using the
  /// Free Will tap pattern (multi-tap for swap, long-press for lock). Each
  /// 'selection' input feeds the state machine; a 'lock' input finalises.
  FreeWillInputState? _decoyFwState;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initialize());
  }

  Future<void> _initialize() async {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is! Preset) {
      Navigator.pop(context);
      return;
    }

    _preset = args;
    final settings = context.read<SettingsProvider>();
    final gameProvider = context.read<GameProvider>();
    final assistantId = settings.assistantId;

    _totalRounds = _preset!.type == PresetType.multipleOut ? 1
        : _preset!.type == PresetType.freeWill ? 2
        : _preset!.nbRounds;

    // Build chain info from routine
    _chainNames = [_preset!.name];
    _chainIndex = 0;
    if (gameProvider.isChaining) {
      final presetsProvider = context.read<PresetsProvider>();
      _chainNames = gameProvider.routineInputOrder.map((id) {
        final p = presetsProvider.getPresetById(id);
        return p?.name ?? '?';
      }).toList();
      _chainIndex = gameProvider.chainCurrentIndex;
    }

    // Determine input mode for webapp
    final inputMode = _preset!.assistantInputMode ?? 'buttons';

    // Build options (use titles if available for Multiple Out)
    List<String> options;
    if (_preset!.type == PresetType.multipleOut) {
      final titles = _preset!.multipleOutTitles;
      final count = _preset!.multipleOutTexts?.length ?? 0;
      options = List.generate(count, (i) {
        if (titles != null && i < titles.length && titles[i].trim().isNotEmpty) {
          return titles[i];
        }
        return 'Text ${i + 1}';
      });
    } else if (_preset!.type == PresetType.freeWill && _preset!.freeWillConfig != null) {
      final config = _preset!.freeWillConfig!;
      if (config.inputMode == FreeWillInputMode.byAction) {
        // Show objects as options (action is fixed per round)
        options = config.objects;
      } else {
        // Show actions as options (object is fixed per round)
        final isFR = _preset!.language == Language.french;
        options = config.actionOrder.map((a) => isFR ? a.shortNameFR : a.shortNameEN).toList();
      }
    } else {
      options = _preset!.labels;
    }

    // Check if preset uses free text variables
    final presetTextsContainFreeText = _presetContainsFreeTextVar();

    // Resolve effective decoy template: per-preset > global default.
    final perPresetTplId = _preset!.decoyTemplateId?.trim() ?? '';
    final effectiveTplId = perPresetTplId.isNotEmpty ? perPresetTplId : settings.defaultDecoyTemplateId;
    final decoyTpl = settings.decoyTemplateById(effectiveTplId);

    if (decoyTpl != null) {
      // DECOY mode: spectator's webapp shows the image, captures gestures,
      // pushes them as standard 'selection' inputs. The redirect happens
      // automatically on the webapp after the last expected input.
      final perPresetRedirect = _preset!.assistantRedirectUrl?.trim() ?? '';
      final redirect = perPresetRedirect.isNotEmpty
          ? perPresetRedirect
          : settings.decoyRedirectUrl;
      final inputType = _preset!.decoyInputType ?? 'tap';
      // Free Will tap mode uses the swap+lock pattern: capture 2 taps then
      // accept unlimited swaps until the spectator long-presses (LOCK).
      // We arm the state machine here and tell the webapp not to auto-redirect
      // by count (sentinel `expectedInputs = 999`); redirect happens after the
      // app clears the session post-lock.
      final useFwSwapLock = _preset!.type == PresetType.freeWill && inputType == 'tap';
      final lockGesture = useFwSwapLock;
      if (useFwSwapLock) {
        _decoyFwState = FreeWillInputState(inputMethod: fw_im.FreeWillInputMethod.tap);
      }
      final optionCount = _computeDecoyOptionCount(options);
      final expectedInputs = useFwSwapLock ? 999 : _computeDecoyExpectedInputs();
      await FirebaseService.pushDecoySession(
        assistantId: assistantId,
        template: decoyTpl,
        inputType: inputType,
        optionCount: optionCount,
        expectedInputs: expectedInputs,
        redirectUrl: redirect,
        lockGesture: lockGesture,
        showIndicator: settings.decoyShowIndicator,
      );
    } else {
      // No decoy template configured: fall back to the standard assistant UI.
      final sessionData = <String, dynamic>{
        'state': 'active',
        'currentPreset': {
          'name': _preset!.name,
          'type': _preset!.type.name,
          'options': options,
          'currentRound': 1,
          'totalRounds': _totalRounds,
          'inputMode': inputMode,
        },
        'chain': _chainNames.length > 1 ? _chainNames : null,
        'chainIndex': _chainIndex,
        'redirectUrl': _preset!.assistantRedirectUrl,
        'hasFreeTextField': presetTextsContainFreeText,
      };
      await FirebaseService.pushSession(assistantId, sessionData);
    }

    // Start polling for input
    _inputSubscription = FirebaseService.pollInput(assistantId).listen(_onInputReceived);

    // Also poll for free text if needed
    if (presetTextsContainFreeText) {
      _startFreeTextPolling(assistantId);
    }

    setState(() {
      _isInitialized = true;
      _statusMessage = 'Waiting for assistant...';
    });
  }

  void _onInputReceived(Map<String, dynamic>? input) {
    if (input == null || _preset == null) return;

    final type = input['type'] as String?;
    final value = input['value'];

    // Decoy Free Will swap+lock pattern.
    if (_decoyFwState != null) {
      if (type == 'lock') {
        _handleDecoyFwLock();
        return;
      }
      if (type == 'selection' && value is int) {
        _handleDecoyFwSelection(value);
        return;
      }
      return;
    }

    if (type == 'selection' && value is int) {
      _handleSelection(value);
    } else if (type == 'free_text' && value is String) {
      _handleFreeText(value);
    }
  }

  Future<void> _handleSelection(int optionIndex) async {
    final gameProvider = context.read<GameProvider>();
    final settings = context.read<SettingsProvider>();

    // Clear the input so we don't process it again
    await FirebaseService.clearInput(settings.assistantId);

    if (_preset!.type == PresetType.multipleOut) {
      // Multiple Out: direct completion
      await gameProvider.completeMultipleOut(optionIndex, _preset!);
      _onComplete();
      return;
    }

    // Free Will: collect 2 inputs, auto-deduce 3rd
    if (_preset!.type == PresetType.freeWill && _preset!.freeWillConfig != null) {
      _freeWillSelections.add(optionIndex);
      if (_freeWillSelections.length >= 2) {
        // Build result from 2 selections
        final config = _preset!.freeWillConfig!;
        final result = _buildFreeWillResult(config, _freeWillSelections);
        if (result != null) {
          gameProvider.completeFreeWill(result, _preset!);
          _onComplete();
        }
      } else {
        // Update UI for second input
        setState(() {
          _currentRound = 2;
          _statusMessage = 'Input 2/2 — Waiting...';
        });
        await FirebaseService.updateSession(settings.assistantId, {
          'currentPreset/currentRound': 2,
        });
      }
      return;
    }

    // Standard game flow: record the choice
    final options = gameProvider.options;
    if (optionIndex >= 0 && optionIndex < options.length) {
      final choice = options[optionIndex];

      // Get performer choice for preprogrammed mode
      String? performerChoice;
      final isPreprogrammed = gameProvider.inputMode == InputMode.preprogrammed;
      if (isPreprogrammed) {
        final roundIdx = gameProvider.currentRound - 1;
        performerChoice = gameProvider.currentSession?.getPerformerChoice(roundIdx);
      }

      final success = gameProvider.recordChoice(
        spectatorChoice: choice,
        performerChoice: performerChoice,
      );

      if (success && gameProvider.hasAllRounds) {
        _onComplete();
      } else if (success) {
        gameProvider.proceedToNextRound();
        setState(() {
          _currentRound = gameProvider.currentRound;
          _statusMessage = 'Round $_currentRound/$_totalRounds — Waiting...';
        });

        // Update Firebase with new round
        await FirebaseService.updateSession(settings.assistantId, {
          'currentPreset/currentRound': _currentRound,
        });
      } else {
        // recordChoice swallowed an exception (e.g. twoInputs mode without a
        // performer choice — assistant flow can't supply one). Surface it so
        // the operator isn't stuck on a silent "Round 1" screen.
        final err = gameProvider.error ?? 'recordChoice failed';
        setState(() => _statusMessage = 'Error: $err');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(err), backgroundColor: Colors.red, duration: const Duration(seconds: 5)),
          );
        }
      }
    }
  }

  /// Decoy Free Will tap+lock: each spectator tap is a value 1/2/3 fed to the
  /// state machine. First two distinct values are captured and the third is
  /// auto-deduced; further taps perform swaps. Webapp doesn't redirect until
  /// the lock signal arrives and we clear the session.
  Future<void> _handleDecoyFwSelection(int zoneIndex) async {
    final settings = context.read<SettingsProvider>();
    await FirebaseService.clearInput(settings.assistantId);
    final state = _decoyFwState;
    if (state == null) return;
    // Map zone index 0..2 → input 1..3; clamp out-of-range.
    final clamped = zoneIndex.clamp(0, 2);
    final input = FreeWillInput.fromValue(clamped + 1);
    state.handleInput(input);
    setState(() {
      _statusMessage = state.phase == FreeWillPhaseState.capturing
          ? 'Captured ${state.capturedInputs.length}/2'
          : 'Swaps: ${state.swapCount} — long-press to lock';
    });
  }

  Future<void> _handleDecoyFwLock() async {
    final state = _decoyFwState;
    if (state == null || _preset?.freeWillConfig == null) return;
    final settings = context.read<SettingsProvider>();
    await FirebaseService.clearInput(settings.assistantId);
    if (state.phase != FreeWillPhaseState.swapping) return;
    state.lock();
    final config = _preset!.freeWillConfig!;
    final result = _buildResultFromFwState(config, state);
    if (result != null) {
      final gameProvider = context.read<GameProvider>();
      gameProvider.completeFreeWill(result, _preset!);
      _onComplete();
    }
  }

  /// Build a [FreeWillResult] from the locked state's slot assignments.
  /// slot 0 → first action in actionOrder, etc. Each slot value is a 1-based
  /// object index into `config.objects`.
  FreeWillResult? _buildResultFromFwState(FreeWillConfig config, FreeWillInputState state) {
    final slots = state.slots; // length 3, values 1/2/3
    if (slots.length != 3) return null;
    final objects = config.objects;
    final assignments = <FreeWillAction, String>{};
    for (var i = 0; i < 3; i++) {
      final action = config.actionOrder[i];
      final objectIndex = (slots[i] - 1).clamp(0, objects.length - 1);
      assignments[action] = objects[objectIndex];
    }
    return FreeWillResult(
      takeObject: assignments[FreeWillAction.take]!,
      giveObject: assignments[FreeWillAction.give]!,
      tableObject: assignments[FreeWillAction.table]!,
      swapCount: state.swapCount,
    );
  }

  void _handleFreeText(String text) {
    final gameProvider = context.read<GameProvider>();
    gameProvider.setFreeTextNarrative(text);
    _onComplete();
  }

  /// Build FreeWillResult from 2 assistant selections
  FreeWillResult? _buildFreeWillResult(FreeWillConfig config, List<int> selections) {
    if (selections.length < 2) return null;
    final objects = config.objects;
    final actions = [FreeWillAction.take, FreeWillAction.give, FreeWillAction.table];

    if (config.inputMode == FreeWillInputMode.byAction) {
      // selections are object indices for each action in actionOrder
      // action[0] → objects[selections[0]], action[1] → objects[selections[1]]
      final assignments = <FreeWillAction, String>{};
      assignments[config.actionOrder[0]] = objects[selections[0]];
      assignments[config.actionOrder[1]] = objects[selections[1]];
      // Deduce 3rd
      final usedObjects = {objects[selections[0]], objects[selections[1]]};
      final remaining = objects.firstWhere((o) => !usedObjects.contains(o));
      final usedActions = {config.actionOrder[0], config.actionOrder[1]};
      final remainingAction = actions.firstWhere((a) => !usedActions.contains(a));
      assignments[remainingAction] = remaining;
      return FreeWillResult(
        takeObject: assignments[FreeWillAction.take]!,
        giveObject: assignments[FreeWillAction.give]!,
        tableObject: assignments[FreeWillAction.table]!,
        swapCount: 0,
      );
    } else {
      // byObject: selections are action indices for each object in objectOrder
      final assignments = <int, FreeWillAction>{};
      assignments[config.objectOrder[0]] = config.actionOrder[selections[0]];
      assignments[config.objectOrder[1]] = config.actionOrder[selections[1]];
      // Deduce 3rd
      final usedActions = {config.actionOrder[selections[0]], config.actionOrder[selections[1]]};
      final remainingAction = actions.firstWhere((a) => !usedActions.contains(a));
      final usedObjIdxs = {config.objectOrder[0], config.objectOrder[1]};
      final remainingObjIdx = [0, 1, 2].firstWhere((i) => !usedObjIdxs.contains(i));
      assignments[remainingObjIdx] = remainingAction;

      String objForAction(FreeWillAction a) =>
          objects[assignments.entries.firstWhere((e) => e.value == a).key];
      return FreeWillResult(
        takeObject: objForAction(FreeWillAction.take),
        giveObject: objForAction(FreeWillAction.give),
        tableObject: objForAction(FreeWillAction.table),
        swapCount: 0,
      );
    }
  }

  /// Number of distinct options the decoy webapp lays out as zones (tap)
  /// or drives via clockMap (swipe). Caps at the longest option set.
  int _computeDecoyOptionCount(List<String> options) {
    if (_preset == null) return 1;
    if (_preset!.type == PresetType.freeWill) return 3;
    if (_preset!.type == PresetType.multipleOut) {
      return _preset!.multipleOutTexts?.length ?? 1;
    }
    return options.isEmpty ? _preset!.nbOptions : options.length;
  }

  /// Total number of inputs the spectator must produce on the decoy page
  /// before the webapp redirects automatically.
  int _computeDecoyExpectedInputs() {
    if (_preset == null) return 1;
    if (_preset!.type == PresetType.multipleOut) return 1;
    if (_preset!.type == PresetType.freeWill) return 2;
    return _totalRounds;
  }

  /// Check if preset texts contain {free_text} (assistant-supplied free text).
  bool _presetContainsFreeTextVar() {
    if (_preset == null) return false;
    if (_preset!.multipleOutTexts != null) {
      for (final t in _preset!.multipleOutTexts!) {
        if (t.contains('{free_text}')) return true;
      }
    }
    if (_preset!.customDuelBankTemplates != null) {
      for (final t in _preset!.customDuelBankTemplates!.values) {
        if (t.contains('{free_text}')) return true;
      }
    }
    return false;
  }

  void _startFreeTextPolling(String assistantId) {
    _freeTextPollTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      final data = await FirebaseService.readFreeText(assistantId);
      if (data != null) {
        final timestamp = data['timestamp'] as int?;
        if (timestamp != null && timestamp != _lastFreeTextTimestamp) {
          _lastFreeTextTimestamp = timestamp;
          final text = data['text'] as String? ?? '';
          if (text.isNotEmpty) {
            final gameProvider = context.read<GameProvider>();
            gameProvider.setFreeTextNarrative(text);
            // Clear it from Firebase
            await FirebaseService.updateSession(assistantId, {'freeText': null});
            setState(() => _statusMessage = 'Free text received: $text');
          }
        }
      }
    });
  }

  void _onComplete() {
    final settings = context.read<SettingsProvider>();
    // Clear Firebase session
    FirebaseService.clearSession(settings.assistantId);
    // Navigate (handles chaining)
    navigateAfterPresetComplete(context);
  }

  void _cancelAndExit() {
    final settings = context.read<SettingsProvider>();
    FirebaseService.clearSession(settings.assistantId);
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  void dispose() {
    _inputSubscription?.cancel();
    _freeTextPollTimer?.cancel();
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final testMode = settings.testModeEnabled;

    return GestureDetector(
      onLongPress: _cancelAndExit,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            Container(color: Colors.black),

            // Test mode: show info overlay
            if (testMode)
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange),
                        ),
                        child: Text(
                          'TEST — Remote Input',
                          style: const TextStyle(color: Colors.orange, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(_preset?.name ?? '', style: const TextStyle(color: Colors.white, fontSize: 16)),
                      const SizedBox(height: 8),
                      Text(
                        _statusMessage ?? 'Initializing...',
                        style: const TextStyle(color: Colors.white54, fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      if (_isInitialized)
                        Text(
                          'Round $_currentRound/$_totalRounds',
                          style: const TextStyle(color: Colors.white38, fontSize: 12),
                        ),
                      if (_chainNames.length > 1) ...[
                        const SizedBox(height: 12),
                        Text(
                          _chainNames.asMap().entries.map((e) =>
                            e.key == _chainIndex ? '**${e.value}**' : e.value
                          ).join(' > '),
                          style: const TextStyle(color: Colors.white24, fontSize: 11),
                        ),
                      ],
                      const Spacer(),
                      Text('Long press to exit', style: TextStyle(color: Colors.white24, fontSize: 10)),
                    ],
                  ),
                ),
              ),

            // Chain progress pixels (stealth mode)
            if (!testMode)
              Consumer<GameProvider>(
                builder: (_, gp, __) => gp.isChaining
                    ? ChainProgressIndicator(total: gp.chainTotal, currentIndex: gp.chainCurrentIndex)
                    : const SizedBox.shrink(),
              ),
          ],
        ),
      ),
    );
  }
}

/// Screen that waits for free text from assistant via Firebase.
class AssistantFreeTextScreen extends StatefulWidget {
  const AssistantFreeTextScreen({super.key});

  @override
  State<AssistantFreeTextScreen> createState() => _AssistantFreeTextScreenState();
}

class _AssistantFreeTextScreenState extends State<AssistantFreeTextScreen> {
  StreamSubscription<Map<String, dynamic>?>? _subscription;
  String? _receivedText;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    _startListening();
  }

  void _startListening() {
    final settings = context.read<SettingsProvider>();
    _subscription = FirebaseService.pollInput(settings.assistantId).listen((input) async {
      if (input != null && input['type'] == 'free_text' && input['value'] is String) {
        var text = input['value'] as String;
        FirebaseService.clearInput(settings.assistantId);
        FirebaseService.clearSession(settings.assistantId);

        // Apply transform prompt if configured
        if (settings.hasFreeTextTransformPrompt && settings.hasOpenaiApiKey) {
          setState(() => _receivedText = '...');
          final transformed = await ExternalApiService.transformWithPrompt(
            prompt: settings.freeTextTransformPrompt,
            openaiApiKey: settings.openaiApiKey,
            variables: {'value': text},
          );
          if (transformed != null) text = transformed;
        }

        // Generate acrostic if enabled in settings
        if (settings.freeTextAcrosticEnabled) {
          final word = text.trim().split(' ').first; // Use first word
          final engine = AcrosticEngine(AcrosticEngine.defaultWordBank);
          final acrostic = engine.generate(word);
          if (acrostic != null) {
            text = acrostic.toDisplayText();
          }
        }

        setState(() => _receivedText = text);

        // Copy and launch shortcut
        Clipboard.setData(ClipboardData(text: text));
        if (settings.autoCopyNarrative) {
          // Launch shortcut if configured
          final name = settings.shortcutName;
          if (name.isNotEmpty) {
            final encoded = Uri.encodeComponent(name.trim());
            launchUrl(Uri.parse('shortcuts://run-shortcut?name=$encoded'),
                mode: LaunchMode.externalApplication);
          }
        }
      }
    });
  }

  void _cancel() {
    final settings = context.read<SettingsProvider>();
    FirebaseService.clearSession(settings.assistantId);
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        title: const Text('Free Text Mode'),
        leading: IconButton(icon: const Icon(Icons.close), onPressed: _cancel),
      ),
      body: Center(
        child: _receivedText != null
            ? Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green, size: 48),
                    const SizedBox(height: 16),
                    Text(_receivedText!, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16), textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    const Text('Copied to clipboard', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Done'),
                    ),
                  ],
                ),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: AppTheme.primary),
                  const SizedBox(height: 24),
                  const Text('Waiting for text from assistant...', style: TextStyle(color: AppTheme.textSecondary, fontSize: 16)),
                  const SizedBox(height: 32),
                  TextButton.icon(
                    onPressed: _cancel,
                    icon: const Icon(Icons.cancel_outlined, size: 18),
                    label: const Text('Cancel'),
                    style: TextButton.styleFrom(foregroundColor: AppTheme.textSecondary),
                  ),
                ],
              ),
      ),
    );
  }
}
