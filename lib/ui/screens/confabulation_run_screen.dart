import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import '../../models/confabulation_preset.dart';
import '../../models/stealth_input_method.dart';
import '../../engine/confabulation_engine.dart';
import '../../inputs/volume_input_controller.dart';
import '../../inputs/volume_button_listener.dart';
import '../../inputs/clock_swipe_input_controller.dart';
import '../../inputs/remote_key_listener.dart';
import '../../utils/confabulation_provider.dart';
import '../../utils/settings_provider.dart';
import '../theme/app_theme.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Screen for running a confabulation preset
class ConfabulationRunScreen extends StatefulWidget {
  const ConfabulationRunScreen({super.key});

  @override
  State<ConfabulationRunScreen> createState() => _ConfabulationRunScreenState();
}

class _ConfabulationRunScreenState extends State<ConfabulationRunScreen> {
  // Volume input
  VolumeButtonListener? _volumeListener;
  VolumeInputController? _inputController;
  StreamSubscription<VolumeDirection>? _volumeSubscription;

  // ClockSwipe input
  ClockSwipeInputController? _clockSwipeController;

  // Audio input
  SpeechToText? _speech;
  bool _isListening = false;
  bool _audioWaitingForStart = false;
  String _lastHeard = '';
  Timer? _speechRestartTimer;
  String _audioStartSentence = '';
  String _audioStopSentence = '';

  ConfabulationPreset? _preset;
  bool _isInitialized = false;
  bool _volumeAvailable = false;
  String? _debugMessage;
  bool _showingFeedback = false;

  // 0-slot stealth mode: black screen displayed while we wait for the
  // template's API variables to resolve. Result + copy + shortcut only fire
  // once resolution completes.
  bool _waitingForResolution = false;
  ConfabulationProvider? _waitProvider;
  VoidCallback? _waitListener;

  // Test mode state
  bool _mappingVisible = false;
  List<String> _commitHistory = [];
  static const int _maxHistorySize = 5;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    _initializeRun();
  }

  Future<void> _initializeRun() async {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is! ConfabulationPreset) {
      // No preset provided, go back
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context);
      });
      return;
    }

    final preset = args;
    _preset = preset;
    final provider = context.read<ConfabulationProvider>();
    final settings = context.read<SettingsProvider>();

    // Start the run
    provider.startRun(preset);

    // 0-slot preset: nothing to capture. Two cases:
    //  - Template has API/acrostic variables (`((` tokens): black screen,
    //    wait for resolution to finish, THEN navigate to result.
    //  - Pure static template: navigate immediately.
    if (provider.runState?.isComplete ?? false) {
      final hasVariables = preset.textTemplate.contains('((');
      if (hasVariables) {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
        setState(() {
          _waitingForResolution = true;
          _isInitialized = true;
        });
        _waitForResolutionThenComplete(provider);
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _onComplete();
        });
      }
      return;
    }

    // Initialize input based on method
    if (preset.inputMethod == ConfabInputMethod.volume) {
      await _initializeVolumeInput(provider, settings);
    } else if (preset.inputMethod == ConfabInputMethod.clockSwipe) {
      await _initializeClockSwipeInput(provider, settings);
    } else if (preset.inputMethod == ConfabInputMethod.audio) {
      await _initializeAudioInput(preset);
    }

    // Set system UI to immersive for stealth mode (volume/clockSwipe)
    if (preset.inputMethod == ConfabInputMethod.volume || preset.inputMethod == ConfabInputMethod.clockSwipe) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }

    if (mounted) {
      setState(() {
        _isInitialized = true;
      });
    }
  }

  Future<void> _initializeVolumeInput(
    ConfabulationProvider provider,
    SettingsProvider settings,
  ) async {
    final runState = provider.runState;
    if (runState == null) return;

    final currentSlot = runState.currentSlot;
    if (currentSlot == null) return;

    _volumeListener = VolumeButtonListener();

    _inputController = VolumeInputController(
      optionsCount: currentSlot.options.length,
      hapticFeedback: settings.hapticFeedback,
      hapticIntensity: settings.hapticIntensity,
      onSelectionCommitted: _onVolumeSelectionCommitted,
      onUndoRequested: _onUndoRequested,
      onResetRequested: _onResetRequested,
      onInvalidInput: _onInvalidInput,
    );

    _volumeAvailable = await _volumeListener!.isAvailable();

    if (_volumeAvailable) {
      final started = await _volumeListener!.startListening();
      if (started) {
        _volumeSubscription = _volumeListener!.onVolumeButtonPressed.listen((direction) {
          _inputController?.handleVolumePress(direction);
        });
      }
    }
  }

  void _updateVolumeController() {
    final provider = context.read<ConfabulationProvider>();
    final settings = context.read<SettingsProvider>();
    final runState = provider.runState;

    if (runState == null || runState.isComplete) return;

    final currentSlot = runState.currentSlot;
    if (currentSlot == null) return;

    // Update options count for the new slot
    _inputController?.dispose();
    _inputController = VolumeInputController(
      optionsCount: currentSlot.options.length,
      hapticFeedback: settings.hapticFeedback,
      hapticIntensity: settings.hapticIntensity,
      onSelectionCommitted: _onVolumeSelectionCommitted,
      onUndoRequested: _onUndoRequested,
      onResetRequested: _onResetRequested,
      onInvalidInput: _onInvalidInput,
    );
  }

  // ─── ClockSwipe Input ───

  Future<void> _initializeClockSwipeInput(
    ConfabulationProvider provider,
    SettingsProvider settings,
  ) async {
    final runState = provider.runState;
    if (runState == null) return;
    final currentSlot = runState.currentSlot;
    if (currentSlot == null) return;

    _clockSwipeController = ClockSwipeInputController(
      maxTexts: currentSlot.options.length,
      hapticFeedback: settings.hapticFeedback,
      hapticIntensity: settings.hapticIntensity,
      onSelectionCommitted: _onVolumeSelectionCommitted,
      onUndoRequested: _onUndoRequested,
      onResetRequested: _onResetRequested,
      onInvalidInput: _onInvalidInput,
    );

    // Volume buttons still available for undo
    _volumeListener = VolumeButtonListener();
    _volumeAvailable = await _volumeListener!.isAvailable();
    if (_volumeAvailable) {
      await _volumeListener!.startListening();
    }
  }

  void _updateClockSwipeController() {
    final provider = context.read<ConfabulationProvider>();
    final settings = context.read<SettingsProvider>();
    final runState = provider.runState;
    if (runState == null || runState.isComplete) return;
    final currentSlot = runState.currentSlot;
    if (currentSlot == null) return;

    _clockSwipeController?.dispose();
    _clockSwipeController = ClockSwipeInputController(
      maxTexts: currentSlot.options.length,
      hapticFeedback: settings.hapticFeedback,
      hapticIntensity: settings.hapticIntensity,
      onSelectionCommitted: _onVolumeSelectionCommitted,
      onUndoRequested: _onUndoRequested,
      onResetRequested: _onResetRequested,
      onInvalidInput: _onInvalidInput,
    );
  }

  // ─── Audio Input ───

  Future<void> _initializeAudioInput(ConfabulationPreset preset) async {
    _audioStartSentence = (preset.audioStartSentence ?? '').trim().toLowerCase();
    _audioStopSentence = (preset.audioStopSentence ?? '').trim().toLowerCase();
    _audioWaitingForStart = _audioStartSentence.isNotEmpty;

    _speech = SpeechToText();
    final available = await _speech!.initialize(
      onError: (error) {
        if (mounted && !_showingFeedback) {
          _scheduleAudioRestart();
        }
      },
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          if (mounted && !_showingFeedback) {
            _scheduleAudioRestart();
          }
        }
      },
    );

    if (available && mounted) {
      _startAudioListening();
    }
  }

  void _startAudioListening() {
    if (_speech == null || !mounted) return;
    final provider = context.read<ConfabulationProvider>();
    final runState = provider.runState;
    if (runState == null || runState.isComplete) return;

    final locale = _preset?.audioLocale ?? 'fr_FR';
    _speech!.listen(
      onResult: _onAudioResult,
      localeId: locale,
      listenMode: ListenMode.dictation,
      partialResults: true,
    );
    setState(() => _isListening = true);
  }

  void _scheduleAudioRestart() {
    _speechRestartTimer?.cancel();
    _speechRestartTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) _startAudioListening();
    });
  }

  void _onAudioResult(SpeechRecognitionResult result) {
    final text = result.recognizedWords.toLowerCase();
    if (text.isEmpty) return;

    setState(() => _lastHeard = text);

    // Check for stop sentence
    if (_audioStopSentence.isNotEmpty && text.contains(_audioStopSentence)) {
      _speech?.stop();
      setState(() => _isListening = false);
      return;
    }

    // Check for start sentence (if waiting)
    if (_audioWaitingForStart) {
      if (text.contains(_audioStartSentence)) {
        setState(() {
          _audioWaitingForStart = false;
          _debugMessage = '▶ Start detected';
        });
      }
      return;
    }

    final provider = context.read<ConfabulationProvider>();
    final runState = provider.runState;
    if (runState == null || runState.isComplete || _showingFeedback) return;

    final currentSlot = runState.currentSlot;
    if (currentSlot == null) return;

    // Check if any option keyword is detected in the transcript
    for (int i = 0; i < currentSlot.options.length; i++) {
      final option = currentSlot.options[i].toLowerCase();
      if (text.contains(option)) {
        _speech?.stop();
        setState(() {
          _isListening = false;
          _debugMessage = '✓ ${currentSlot.options[i]}';
        });
        _selectOption(i);

        // Restart listening after feedback delay for next slot
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            final newState = provider.runState;
            if (newState != null && !newState.isComplete) {
              _startAudioListening();
            }
          }
        });
        return;
      }
    }
  }

  void _onVolumeSelectionCommitted(int optionIndex) {
    _selectOption(optionIndex);
  }

  void _selectOption(int optionIndex) {
    final provider = context.read<ConfabulationProvider>();
    final runState = provider.runState;

    if (runState == null || runState.isComplete) return;

    final currentSlot = runState.currentSlot;
    if (currentSlot == null) return;

    if (optionIndex < 0 || optionIndex >= currentSlot.options.length) {
      _onInvalidInput();
      return;
    }

    setState(() {
      _debugMessage = 'Selected: ${currentSlot.options[optionIndex]}';
      _showingFeedback = true;
      _addToHistory('${currentSlot.label}: ${currentSlot.options[optionIndex]}');
    });

    // Brief visual feedback
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() => _showingFeedback = false);
      }
    });

    // Record the selection
    provider.selectOption(optionIndex);

    // Check if complete or update for next slot
    final newRunState = provider.runState;
    if (newRunState != null && newRunState.isComplete) {
      _onComplete();
    } else {
      _updateVolumeController();
      _updateClockSwipeController();
    }
  }

  void _onComplete() {
    // Restore system UI and navigate to result
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    Navigator.pushReplacementNamed(context, '/confabulation/result');
  }

  /// Subscribe to the provider until `resolvedFinalText` becomes non-null
  /// (or the listener is cancelled by dispose / user exit). Then navigate
  /// to the result screen so copy + shortcut fire on a fully resolved text.
  void _waitForResolutionThenComplete(ConfabulationProvider provider) {
    if (provider.resolvedFinalText != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _onComplete();
      });
      return;
    }
    _waitProvider = provider;
    _waitListener = () {
      if (provider.resolvedFinalText != null) {
        _cancelWaitListener();
        if (mounted) _onComplete();
      }
    };
    provider.addListener(_waitListener!);
  }

  void _cancelWaitListener() {
    if (_waitListener != null && _waitProvider != null) {
      _waitProvider!.removeListener(_waitListener!);
    }
    _waitListener = null;
    _waitProvider = null;
  }

  void _onUndoRequested() {
    setState(() {
      _debugMessage = 'Undo';
      _addToHistory('⟲ Undo');
    });

    // Undo not supported in confabulation - just show feedback
    if (context.read<SettingsProvider>().hapticFeedback) {
      HapticFeedback.vibrate();
    }

    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() => _debugMessage = null);
      }
    });
  }

  void _onResetRequested() {
    final provider = context.read<ConfabulationProvider>();
    final args = ModalRoute.of(context)?.settings.arguments;

    if (args is! ConfabulationPreset) return;

    setState(() {
      _debugMessage = 'Reset';
      _commitHistory.clear();
      _addToHistory('⟲ Reset');
    });

    // Restart the run
    provider.startRun(args);
    _updateVolumeController();

    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() => _debugMessage = null);
      }
    });
  }

  void _onInvalidInput() {
    setState(() {
      _debugMessage = 'Invalid';
      _addToHistory('✗ Invalid');
    });

    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() => _debugMessage = null);
      }
    });
  }

  void _addToHistory(String entry) {
    _commitHistory.insert(0, entry);
    if (_commitHistory.length > _maxHistorySize) {
      _commitHistory.removeLast();
    }
  }

  void _exitRun() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text(
          'Exit Confabulation?',
          style: TextStyle(color: AppTheme.textPrimary),
        ),
        content: const Text(
          'Your progress will be lost.',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final provider = context.read<ConfabulationProvider>();
              provider.endRun();
              Navigator.pop(ctx);
              SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Exit'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _cancelWaitListener();
    WakelockPlus.disable();
    _volumeSubscription?.cancel();
    _inputController?.dispose();
    _clockSwipeController?.dispose();
    _volumeListener?.dispose();
    _speechRestartTimer?.cancel();
    _speech?.stop();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final testMode = settings.testModeEnabled;

    return Consumer<ConfabulationProvider>(
      builder: (context, provider, child) {
        final runState = provider.runState;

        if (!_isInitialized || runState == null) {
          return const Scaffold(
            backgroundColor: Colors.black,
            body: Center(
              child: CircularProgressIndicator(color: Colors.white24),
            ),
          );
        }

        // 0-slot stealth: black screen until API resolution finishes.
        // Long-press anywhere to abort if resolution hangs.
        if (_waitingForResolution) {
          return Scaffold(
            backgroundColor: Colors.black,
            body: GestureDetector(
              onLongPress: () {
                _cancelWaitListener();
                Navigator.of(context).popUntil((r) => r.isFirst);
              },
              child: testMode
                  ? const Center(
                      child: Text(
                        'Waiting for API resolution…\nLong press to abort',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white24, fontSize: 12),
                      ),
                    )
                  : Container(color: Colors.black),
            ),
          );
        }

        final preset = runState.preset;
        final isVolumeInput = preset.inputMethod == ConfabInputMethod.volume;
        final isClockSwipeInput = preset.inputMethod == ConfabInputMethod.clockSwipe;
        final isAudioInput = preset.inputMethod == ConfabInputMethod.audio;

        // For volume input, check availability
        if (isVolumeInput && !_volumeAvailable && _isInitialized) {
          return _buildUnavailableScreen();
        }

        // Tap or Audio input mode - show visible options
        if (!isVolumeInput && !isClockSwipeInput) {
          return _buildTapInputScreen(runState, testMode, isAudioInput: isAudioInput);
        }

        // Volume / ClockSwipe input mode - stealth screen
        return RemoteKeyListener(
          onVolumeKey: isVolumeInput ? (dir) => _inputController?.handleVolumePress(dir) : null,
          onSwipeKey: isClockSwipeInput ? (dir) => _clockSwipeController?.handleSwipe(dir) : null,
          child: GestureDetector(
          onLongPress: _exitRun,
          onPanEnd: isClockSwipeInput ? (details) {
            final dx = details.velocity.pixelsPerSecond.dx;
            final dy = details.velocity.pixelsPerSecond.dy;
            if (dx.abs() < 100 && dy.abs() < 100) return;
            SwipeDirection dir;
            if (dx.abs() > dy.abs()) {
              dir = dx > 0 ? SwipeDirection.right : SwipeDirection.left;
            } else {
              dir = dy > 0 ? SwipeDirection.down : SwipeDirection.up;
            }
            _clockSwipeController?.handleSwipe(dir);
          } : null,
          onDoubleTap: () {
            if (!testMode) {
              setState(() {
                _debugMessage = 'Slot ${runState.currentSlotIndex + 1}/${runState.totalSlots}';
              });
              Future.delayed(const Duration(milliseconds: 800), () {
                if (mounted) {
                  setState(() => _debugMessage = null);
                }
              });
            }
          },
          child: Scaffold(
            backgroundColor: Colors.black,
            body: Stack(
              children: [
                Container(color: Colors.black),

                // Test Mode Overlay
                if (testMode)
                  _buildTestModeOverlay(runState),

                // Very subtle feedback indicator (only in non-test mode)
                if (_showingFeedback && !testMode)
                  Center(
                    child: Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),

                // Debug message (only in non-test mode)
                if (_debugMessage != null && !testMode)
                  Positioned(
                    bottom: 50,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Text(
                        _debugMessage!,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.15),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),

                // Hidden exit button
                Positioned(
                  top: 0,
                  left: 0,
                  child: GestureDetector(
                    onTap: () {},
                    onLongPress: _exitRun,
                    child: Container(
                      width: 60,
                      height: 60,
                      color: Colors.transparent,
                    ),
                  ),
                ),
              ],
            ),
          ),
          ),
        );
      },
    );
  }

  Widget _buildTapInputScreen(ConfabulationRunState runState, bool testMode, {bool isAudioInput = false}) {
    final currentSlot = runState.currentSlot;
    if (currentSlot == null) {
      return const Scaffold(
        backgroundColor: AppTheme.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: testMode ? Colors.black : AppTheme.background,
      body: SafeArea(
        child: GestureDetector(
          onLongPress: _exitRun,
          child: Column(
            children: [
              // Test mode header
              if (testMode) ...[
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange),
                        ),
                        child: const Text(
                          'TEST MODE',
                          style: TextStyle(
                            color: Colors.orange,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: _exitRun,
                        icon: const Icon(Icons.close, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                // Normal header
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: _exitRun,
                        icon: const Icon(Icons.close),
                      ),
                      Expanded(
                        child: Text(
                          runState.preset.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(width: 48), // Balance for close button
                    ],
                  ),
                ),
              ],

              // Progress indicator
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: LinearProgressIndicator(
                  value: runState.progress,
                  backgroundColor: testMode
                      ? Colors.white.withOpacity(0.1)
                      : AppTheme.surface,
                  valueColor: AlwaysStoppedAnimation(
                    testMode ? Colors.orange : AppTheme.primary,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Slot ${runState.currentSlotIndex + 1} of ${runState.totalSlots}',
                style: TextStyle(
                  fontSize: 12,
                  color: testMode ? Colors.white54 : AppTheme.textSecondary,
                ),
              ),

              const SizedBox(height: 32),

              // Slot label
              Text(
                currentSlot.label,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: testMode ? Colors.white : AppTheme.textPrimary,
                ),
              ),

              const SizedBox(height: 24),

              // Audio listening indicator
              if (isAudioInput) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: _isListening ? Colors.green.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _isListening ? Colors.green.withValues(alpha: 0.3) : Colors.orange.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(_isListening ? Icons.mic : Icons.mic_off, size: 16,
                          color: _isListening ? (_audioWaitingForStart ? Colors.orange : Colors.green) : Colors.grey),
                        const SizedBox(width: 8),
                        Text(
                          _audioWaitingForStart
                              ? 'En attente du déclencheur...'
                              : (_isListening ? 'Écoute en cours...' : 'En attente...'),
                          style: TextStyle(fontSize: 12, color: _isListening ? (_audioWaitingForStart ? Colors.orange : Colors.green) : Colors.grey),
                        ),
                        if (_lastHeard.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              '"$_lastHeard"',
                              style: TextStyle(fontSize: 10, color: AppTheme.textTertiary, fontStyle: FontStyle.italic),
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Options
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  itemCount: currentSlot.options.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    return _buildOptionButton(
                      currentSlot.options[index],
                      index,
                      testMode,
                    );
                  },
                ),
              ),

              // History in test mode
              if (testMode && _commitHistory.isNotEmpty) ...[
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'History',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...List.generate(_commitHistory.length, (index) {
                        return Text(
                          _commitHistory[index],
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 11,
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptionButton(String option, int index, bool testMode) {
    return Material(
      color: testMode
          ? Colors.white.withOpacity(0.1)
          : AppTheme.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => _selectOption(index),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: testMode
                      ? Colors.orange.withOpacity(0.3)
                      : AppTheme.primary.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      color: testMode ? Colors.orange : AppTheme.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  option,
                  style: TextStyle(
                    fontSize: 16,
                    color: testMode ? Colors.white : AppTheme.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTestModeOverlay(ConfabulationRunState runState) {
    final currentSlot = runState.currentSlot;

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange),
                  ),
                  child: const Text(
                    'TEST MODE',
                    style: TextStyle(
                      color: Colors.orange,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () {
                    setState(() {
                      _mappingVisible = !_mappingVisible;
                    });
                  },
                  icon: Icon(
                    _mappingVisible ? Icons.visibility : Icons.visibility_off,
                    color: Colors.white70,
                    size: 28,
                  ),
                ),
              ],
            ),
          ),

          // Status info
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Slot ${runState.currentSlotIndex + 1}/${runState.totalSlots}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (currentSlot != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Current: ${currentSlot.label}',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 14,
                    ),
                  ),
                ],

                // Debug message
                if (_debugMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _debugMessage == 'Invalid'
                            ? Colors.red.withOpacity(0.2)
                            : Colors.green.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _debugMessage == 'Invalid'
                              ? Colors.red.withOpacity(0.5)
                              : Colors.green.withOpacity(0.5),
                        ),
                      ),
                      child: Text(
                        _debugMessage!,
                        style: TextStyle(
                          color: _debugMessage == 'Invalid' ? Colors.red : Colors.green,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Mapping Panel
          if (_mappingVisible && currentSlot != null) ...[
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildVolumeMappingPanel(currentSlot),
                    const SizedBox(height: 16),

                    // Choices made so far
                    if (runState.chosenIndexBySlotId.isNotEmpty)
                      _buildChoicesPanel(runState),

                    // History
                    if (_commitHistory.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _buildHistoryPanel(),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVolumeMappingPanel(ConfabSlot slot) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Volume Mapping',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          ...List.generate(slot.options.length, (index) {
            final gesture = VolumeGesture.fromOptionIndex(index);
            if (gesture == null) return const SizedBox.shrink();

            final directionIcon = gesture.direction == VolumeDirection.up ? '▲' : '▼';

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 80,
                    child: Text(
                      '$directionIcon x${gesture.tapCount}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  const Text(
                    ' → ',
                    style: TextStyle(color: Colors.white54, fontSize: 14),
                  ),
                  Expanded(
                    child: Text(
                      slot.options[index],
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildChoicesPanel(ConfabulationRunState runState) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 18),
              SizedBox(width: 8),
              Text(
                'Choices Made',
                style: TextStyle(
                  color: Colors.green,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...runState.chosenIndexBySlotId.entries.map((entry) {
            final slot = runState.preset.getSlotById(entry.key);
            if (slot == null) return const SizedBox.shrink();
            final chosenOption = slot.options[entry.value.clamp(0, slot.options.length - 1)];
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                '${slot.label}: $chosenOption',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 13,
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildHistoryPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recent History',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          ...List.generate(_commitHistory.length, (index) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                _commitHistory[index],
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 12,
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildUnavailableScreen() {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        title: const Text('Volume Input Unavailable'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
            Navigator.pop(context);
          },
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.volume_off,
                size: 64,
                color: AppTheme.textSecondary,
              ),
              const SizedBox(height: 24),
              const Text(
                'Volume button input is not available on this device.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
                  Navigator.pop(context);
                },
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
