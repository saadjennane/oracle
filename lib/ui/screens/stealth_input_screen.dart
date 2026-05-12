import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../inputs/volume_input_controller.dart';
import '../../inputs/volume_button_listener.dart';
import '../../utils/game_provider.dart';
import '../../utils/settings_provider.dart';
import '../../app.dart';
import '../theme/app_theme.dart';
import '../../inputs/remote_key_listener.dart';
import '../widgets/chain_progress_indicator.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Stealth input screen with black background for volume button input
class StealthInputScreen extends StatefulWidget {
  const StealthInputScreen({super.key});

  @override
  State<StealthInputScreen> createState() => _StealthInputScreenState();
}

class _StealthInputScreenState extends State<StealthInputScreen> {
  late VolumeButtonListener _volumeListener;
  late VolumeInputController _inputController;
  StreamSubscription<VolumeDirection>? _volumeSubscription;

  bool _isInitialized = false;
  bool _volumeAvailable = false;
  String? _debugMessage;

  // Current input stage tracking
  bool _isPerformerStage = false;
  bool _showingFeedback = false;

  // Test mode state
  bool _mappingVisible = false;
  String? _lastCommitLabel;
  int? _lastCommitIndex;
  List<String> _commitHistory = [];
  static const int _maxHistorySize = 5;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    _volumeListener = VolumeButtonListener();
    _initializeVolumeListener();

    // Set system UI to immersive for true stealth
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  Future<void> _initializeVolumeListener() async {
    final provider = context.read<GameProvider>();
    final settings = context.read<SettingsProvider>();

    _inputController = VolumeInputController(
      optionsCount: provider.options.length,
      hapticFeedback: settings.hapticFeedback,
      hapticIntensity: settings.hapticIntensity,
      onSelectionCommitted: _onSelectionCommitted,
      onUndoRequested: _onUndoRequested,
      onResetRequested: _onResetRequested,
      onInvalidInput: _onInvalidInput,
    );

    _volumeAvailable = await _volumeListener.isAvailable();

    if (_volumeAvailable) {
      final started = await _volumeListener.startListening();
      if (started) {
        _volumeSubscription = _volumeListener.onVolumeButtonPressed.listen((direction) {
          _inputController.handleVolumePress(direction);
        });
      }
    }

    if (mounted) {
      setState(() {
        _isInitialized = true;
        _updateInputStage(provider);
      });
    }
  }

  void _updateInputStage(GameProvider provider) {
    final isPreprogrammed = provider.inputMode == InputMode.preprogrammed;
    final isDirectMode = provider.predictionMode == PredictionMode.direct;

    // In direct mode or preprogrammed mode, only spectator input
    // In two-inputs game mode, performer first
    if (isDirectMode || isPreprogrammed) {
      _isPerformerStage = false;
    } else {
      // Two-inputs mode: check if we need performer or spectator input
      // This depends on whether we've already recorded performer choice this round
      _isPerformerStage = !_hasPerformerChoiceThisRound(provider);
    }
  }

  bool _hasPerformerChoiceThisRound(GameProvider provider) {
    // Check if current round already has performer choice recorded
    // For stealth mode, we track this locally
    return provider.hasPerformerChoiceForCurrentRound;
  }

  void _onSelectionCommitted(int optionIndex) {
    final provider = context.read<GameProvider>();
    final options = provider.options;

    if (optionIndex < 0 || optionIndex >= options.length) {
      _onInvalidInput();
      return;
    }

    final selectedOption = options[optionIndex];

    setState(() {
      _debugMessage = 'Selected: $selectedOption';
      _showingFeedback = true;
      _lastCommitIndex = optionIndex;
      _lastCommitLabel = selectedOption;
      _addToHistory('${optionIndex + 1}: $selectedOption');
    });

    // Brief visual feedback (very subtle)
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() => _showingFeedback = false);
      }
    });

    // Record the choice
    _recordChoice(provider, selectedOption);
  }

  void _addToHistory(String entry) {
    _commitHistory.insert(0, entry);
    if (_commitHistory.length > _maxHistorySize) {
      _commitHistory.removeLast();
    }
  }

  void _recordChoice(GameProvider provider, String choice) {
    final isPreprogrammed = provider.inputMode == InputMode.preprogrammed;
    final isDirectMode = provider.predictionMode == PredictionMode.direct;

    if (isDirectMode || isPreprogrammed) {
      // Single input per round (spectator only)
      // In preprogrammed mode, attach the performer's pre-set choice for this round
      String? performerChoice;
      if (isPreprogrammed) {
        final roundIdx = provider.currentRound - 1;
        performerChoice = provider.currentSession?.getPerformerChoice(roundIdx);
      }
      final success = provider.recordChoice(
        spectatorChoice: choice,
        performerChoice: performerChoice,
      );

      if (success) {
        _checkGameComplete(provider);
      }
    } else {
      // Two-inputs mode
      if (_isPerformerStage) {
        // Record performer choice and switch to spectator stage
        provider.setTemporaryPerformerChoice(choice);
        setState(() {
          _isPerformerStage = false;
        });
      } else {
        // Record spectator choice with the stored performer choice
        final performerChoice = provider.getTemporaryPerformerChoice();
        final success = provider.recordChoice(
          spectatorChoice: choice,
          performerChoice: performerChoice,
        );

        if (success) {
          provider.clearTemporaryPerformerChoice();
          _checkGameComplete(provider);
        }
      }
    }
  }

  void _checkGameComplete(GameProvider provider) {
    if (provider.hasAllRounds) {
      // Restore system UI and navigate to preview
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      navigateAfterPresetComplete(context);
    } else {
      // Move to next round
      provider.proceedToNextRound();
      setState(() {
        _updateInputStage(provider);
      });
    }
  }

  void _onUndoRequested() {
    final provider = context.read<GameProvider>();

    setState(() {
      _debugMessage = 'Undo';
      _addToHistory('⟲ Undo');
    });

    // Undo logic
    if (!_isPerformerStage && provider.getTemporaryPerformerChoice() != null) {
      // We're in spectator stage with a temporary performer choice - undo to performer stage
      provider.clearTemporaryPerformerChoice();
      setState(() {
        _isPerformerStage = true;
      });
    } else if (provider.currentRound > 1) {
      // Go back to previous round
      provider.undoLastRound();
      setState(() {
        _updateInputStage(provider);
      });
    } else {
      // Nothing to undo
      if (context.read<SettingsProvider>().hapticFeedback) {
        HapticFeedback.vibrate();
      }
    }

    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() => _debugMessage = null);
      }
    });
  }

  void _onResetRequested() {
    final provider = context.read<GameProvider>();

    setState(() {
      _debugMessage = 'Reset';
      _commitHistory.clear();
      _addToHistory('⟲ Reset to Round 1');
      _lastCommitIndex = null;
      _lastCommitLabel = null;
    });

    // Reset all rounds
    provider.resetAllRounds();
    setState(() {
      _isPerformerStage = false;
      _updateInputStage(provider);
    });

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

  void _exitStealth() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text(
          'Exit Stealth Mode?',
          style: TextStyle(color: AppTheme.textPrimary),
        ),
        content: const Text(
          'Switch to normal input mode?',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
              Navigator.pushReplacementNamed(context, '/rounds');
            },
            child: const Text('Exit'),
          ),
        ],
      ),
    );
  }

  void _confirmExit() {
    final provider = context.read<GameProvider>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text(
          'Exit Game?',
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
              provider.reset();
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
    WakelockPlus.disable();
    _volumeSubscription?.cancel();
    _inputController.dispose();
    _volumeListener.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final testMode = settings.testModeEnabled;

    return Consumer<GameProvider>(
      builder: (context, provider, child) {
        if (!_isInitialized) {
          return const Scaffold(
            backgroundColor: Colors.black,
            body: Center(
              child: CircularProgressIndicator(color: Colors.white24),
            ),
          );
        }

        if (!_volumeAvailable) {
          return _buildUnavailableScreen();
        }

        return RemoteKeyListener(
          onVolumeKey: (dir) => _inputController.handleVolumePress(dir),
          child: GestureDetector(
          // Two-finger long press to exit stealth
          onLongPress: _exitStealth,
          // Single tap to show brief status (dev only)
          onDoubleTap: () {
            if (!testMode) {
              setState(() {
                _debugMessage = 'R${provider.currentRound}/${provider.totalRounds}';
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
                // Main black screen
                Container(color: Colors.black),

                // Test Mode Overlay
                if (testMode)
                  _buildTestModeOverlay(provider),

                // Very subtle feedback indicator (almost invisible) - only in non-test mode
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

                // Chain progress indicator
                Consumer<GameProvider>(
                  builder: (_, gp, __) => gp.isChaining
                      ? ChainProgressIndicator(total: gp.chainTotal, currentIndex: gp.chainCurrentIndex)
                      : const SizedBox.shrink(),
                ),

                // Hidden exit button (top-left corner, long press)
                Positioned(
                  top: 0,
                  left: 0,
                  child: GestureDetector(
                    onTap: () {}, // Absorb single taps
                    onLongPress: _confirmExit,
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
        ));
      },
    );
  }

  /// Minimal test-mode overlay: top status line (round + per-round choices)
  /// and a centered list of volume → option mappings, all labels in big
  /// monospaced text. No history, no debug panels.
  Widget _buildTestModeOverlay(GameProvider provider) {
    final total = provider.totalRounds;
    final round = provider.currentRound;
    final session = provider.currentSession;
    final rounds = session?.rounds ?? const [];
    final options = provider.options;

    String shortFor(String label) => label.isEmpty ? '?' : label.substring(0, 1).toUpperCase();
    final cells = List<String>.generate(total, (i) {
      if (i < rounds.length) return shortFor(rounds[i].spectatorChoice);
      return '_';
    });
    final stateLine = 'R $round/$total   [ ${cells.join('  ')} ]';

    return IgnorePointer(
      ignoring: true,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Center(
                child: Text(
                  stateLine,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.75),
                    fontSize: 18,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: List.generate(options.length, (i) {
                    final gesture = VolumeGesture.fromOptionIndex(i);
                    if (gesture == null) return const SizedBox.shrink();
                    final arrow = gesture.direction == VolumeDirection.up ? '↑' : '↓';
                    String repeat = gesture.tapCount == 1 ? arrow : List.filled(gesture.tapCount, arrow).join('');
                    // 3-option presets: option 3 accepts EITHER double-up or
                    // double-down (see VolumeGesture.toOptionIndex). Reflect
                    // that in the displayed gesture.
                    if (options.length == 3 && i == 2) repeat = '↑↑ / ↓↓';
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 110,
                            child: Text(
                              repeat,
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.85),
                                fontSize: 28,
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(width: 18),
                          Text(
                            options[i],
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.55),
                              fontSize: 22,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMappingPanel(GameProvider provider) {
    final optionsCount = provider.options.length;
    final options = provider.options;

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
          ...List.generate(optionsCount, (index) {
            final gesture = VolumeGesture.fromOptionIndex(index);
            if (gesture == null) return const SizedBox.shrink();

            final directionIcon = gesture.direction == VolumeDirection.up ? '▲' : '▼';
            final label = index < options.length ? options[index] : '?';

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Container(
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
                  Text(
                    'Option ${index + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    ' ($label)',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 14,
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

  Widget _buildPerformerSequencePanel(GameProvider provider) {
    final preprogrammedChoices = provider.preprogrammedSequence;
    if (preprogrammedChoices.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primary.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primary.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.auto_fix_high, color: AppTheme.primary, size: 18),
              SizedBox(width: 8),
              Text(
                'Performer Sequence',
                style: TextStyle(
                  color: AppTheme.primary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(preprogrammedChoices.length, (index) {
              final choice = preprogrammedChoices[index];
              final isCurrent = index == provider.currentRound - 1;
              final isCompleted = index < provider.currentRound - 1;

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isCurrent
                      ? AppTheme.primary
                      : isCompleted
                          ? Colors.green.withOpacity(0.3)
                          : Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: isCurrent
                      ? null
                      : Border.all(
                          color: isCompleted
                              ? Colors.green.withOpacity(0.5)
                              : Colors.white.withOpacity(0.3),
                        ),
                ),
                child: Text(
                  '${index + 1}: $choice',
                  style: TextStyle(
                    color: isCurrent ? Colors.white : Colors.white.withOpacity(0.8),
                    fontSize: 13,
                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              );
            }),
          ),
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
                  Navigator.pushReplacementNamed(context, '/rounds');
                },
                child: const Text('Use Standard Input'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
