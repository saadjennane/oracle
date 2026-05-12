import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../app.dart';
import '../../inputs/tap/tap_layout.dart';
import '../../inputs/tap/tap_input_controller.dart';
import '../../utils/game_provider.dart';
import '../widgets/chain_progress_indicator.dart';
import '../../utils/settings_provider.dart';
import '../theme/app_theme.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Tap stealth input screen with invisible zones on black background
class TapStealthInputScreen extends StatefulWidget {
  final TapLayout2 tapLayout2;
  final TapLayout4 tapLayout4;

  const TapStealthInputScreen({
    super.key,
    this.tapLayout2 = TapLayout2.leftRight,
    this.tapLayout4 = TapLayout4.corners,
  });

  @override
  State<TapStealthInputScreen> createState() => _TapStealthInputScreenState();
}

class _TapStealthInputScreenState extends State<TapStealthInputScreen> {
  late TapInputController _inputController;
  List<TapZone> _zones = [];

  bool _isInitialized = false;
  String? _debugMessage;

  // Current input stage tracking
  bool _isPerformerStage = false;
  bool _showingFeedback = false;

  // Test mode state
  bool _showGridLines = true;
  bool _showLabels = true;
  String? _lastCommitLabel;
  int? _lastCommitIndex;
  List<String> _commitHistory = [];
  static const int _maxHistorySize = 5;

  // Two-finger gesture tracking
  int _pointerCount = 0;
  Timer? _twoFingerLongPressTimer;
  static const _longPressDuration = Duration(milliseconds: 600);

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    _initializeController();

    // Set system UI to immersive for true stealth
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  void _initializeController() {
    final provider = context.read<GameProvider>();
    final settings = context.read<SettingsProvider>();

    _inputController = TapInputController(
      optionsCount: provider.options.length,
      hapticFeedback: settings.hapticFeedback,
      hapticIntensity: settings.hapticIntensity,
      onSelectionCommitted: _onSelectionCommitted,
      onUndoRequested: _onUndoRequested,
      onResetRequested: _onResetRequested,
      onInvalidInput: _onInvalidInput,
    );

    _updateInputStage(provider);
    _isInitialized = true;
  }

  void _updateInputStage(GameProvider provider) {
    final isPreprogrammed = provider.inputMode == InputMode.preprogrammed;
    final isDirectMode = provider.predictionMode == PredictionMode.direct;

    if (isDirectMode || isPreprogrammed) {
      _isPerformerStage = false;
    } else {
      _isPerformerStage = !_hasPerformerChoiceThisRound(provider);
    }
  }

  bool _hasPerformerChoiceThisRound(GameProvider provider) {
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

    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() => _showingFeedback = false);
      }
    });

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
      if (_isPerformerStage) {
        provider.setTemporaryPerformerChoice(choice);
        setState(() {
          _isPerformerStage = false;
        });
      } else {
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
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      navigateAfterPresetComplete(context);
    } else {
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

    if (!_isPerformerStage && provider.getTemporaryPerformerChoice() != null) {
      provider.clearTemporaryPerformerChoice();
      setState(() {
        _isPerformerStage = true;
      });
    } else if (provider.currentRound > 1) {
      provider.undoLastRound();
      setState(() {
        _updateInputStage(provider);
      });
    } else {
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

  void _handleTapDown(TapDownDetails details) {
    if (_zones.isEmpty) return;

    final zone = TapLayoutCalculator.findZoneAtPoint(_zones, details.localPosition);
    if (zone != null) {
      _inputController.handleTap(zone);
    }
  }

  void _handlePointerDown(PointerDownEvent event) {
    _pointerCount++;
    if (_pointerCount == 2) {
      // Start two-finger long press timer
      _twoFingerLongPressTimer?.cancel();
      _twoFingerLongPressTimer = Timer(_longPressDuration, () {
        if (_pointerCount >= 2) {
          _inputController.handleUndoGesture();
        }
      });
    }
  }

  void _handlePointerUp(PointerUpEvent event) {
    _pointerCount = (_pointerCount - 1).clamp(0, 10);
    if (_pointerCount < 2) {
      _twoFingerLongPressTimer?.cancel();
    }
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
    _twoFingerLongPressTimer?.cancel();
    _inputController.dispose();
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

        return Scaffold(
          backgroundColor: Colors.black,
          body: LayoutBuilder(
            builder: (context, constraints) {
              // Compute zones based on screen size
              final size = Size(constraints.maxWidth, constraints.maxHeight);
              _zones = TapLayoutCalculator.computeZones(
                screenSize: size,
                optionsCount: provider.options.length,
                layout2: widget.tapLayout2,
                layout4: widget.tapLayout4,
              );

              return Stack(
                children: [
                  // Main tap area (full screen)
                  Positioned.fill(
                    child: Listener(
                      onPointerDown: _handlePointerDown,
                      onPointerUp: _handlePointerUp,
                      child: GestureDetector(
                        onTapDown: _handleTapDown,
                        onLongPress: _exitStealth,
                        child: Container(
                          color: Colors.black,
                          child: testMode
                              ? CustomPaint(
                                  painter: _TapZonePainter(
                                    zones: _zones,
                                    options: provider.options,
                                    showGridLines: _showGridLines,
                                    showLabels: _showLabels,
                                  ),
                                  child: Container(),
                                )
                              : Container(),
                        ),
                      ),
                    ),
                  ),

                  // Test Mode Overlay
                  if (testMode) _buildTestModeOverlay(provider),

                  // Very subtle feedback indicator (non-test mode)
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

                  // Debug message (non-test mode)
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
                      onTap: () {},
                      onLongPress: _confirmExit,
                      child: Container(
                        width: 60,
                        height: 60,
                        color: Colors.transparent,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  /// Minimal test-mode overlay: a single top line showing the round and the
  /// per-round spectator choices recorded so far. The body (zone painter)
  /// already shows option labels in each zone, which is the main practice
  /// signal — the overlay is just a state indicator.
  Widget _buildTestModeOverlay(GameProvider provider) {
    final total = provider.totalRounds;
    final round = provider.currentRound;
    final session = provider.currentSession;
    final rounds = session?.rounds ?? const [];

    // Build a compact `[ a, b, _, _, _ ]` strip from spectator choices.
    String shortFor(String label) => label.isEmpty ? '?' : label.substring(0, 1).toUpperCase();
    final cells = List<String>.generate(total, (i) {
      if (i < rounds.length) return shortFor(rounds[i].spectatorChoice);
      return '_';
    });
    final stateLine = 'R $round/$total   [ ${cells.join('  ')} ]';

    return IgnorePointer(
      ignoring: true,
      child: SafeArea(
        child: Padding(
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
      ),
    );
  }

  Widget _buildPerformerSequencePanel(GameProvider provider) {
    final preprogrammedChoices = provider.preprogrammedSequence;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.primary.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.primary.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.auto_fix_high, color: AppTheme.primary, size: 16),
              SizedBox(width: 6),
              Text(
                'Performer Sequence',
                style: TextStyle(
                  color: AppTheme.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: List.generate(preprogrammedChoices.length, (index) {
              final choice = preprogrammedChoices[index];
              final isCurrent = index == provider.currentRound - 1;
              final isCompleted = index < provider.currentRound - 1;

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isCurrent
                      ? AppTheme.primary
                      : isCompleted
                          ? Colors.green.withOpacity(0.3)
                          : Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${index + 1}: $choice',
                  style: TextStyle(
                    color: isCurrent ? Colors.white : Colors.white.withOpacity(0.7),
                    fontSize: 11,
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recent History',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          ...List.generate(_commitHistory.length, (index) {
            return Text(
              _commitHistory[index],
              style: TextStyle(
                color: Colors.white.withOpacity(0.4),
                fontSize: 11,
              ),
            );
          }),
        ],
      ),
    );
  }
}

/// Custom painter for drawing tap zones in test mode
class _TapZonePainter extends CustomPainter {
  final List<TapZone> zones;
  final List<String> options;
  final bool showGridLines;
  final bool showLabels;

  _TapZonePainter({
    required this.zones,
    required this.options,
    required this.showGridLines,
    required this.showLabels,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (!showGridLines && !showLabels) return;

    final linePaint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final disabledPaint = Paint()
      ..color = Colors.red.withOpacity(0.15)
      ..style = PaintingStyle.fill;

    for (final zone in zones) {
      // Draw disabled zone background
      if (zone.isDisabled) {
        canvas.drawRect(zone.rect, disabledPaint);
      }

      // Draw grid lines
      if (showGridLines) {
        canvas.drawRect(zone.rect, linePaint);
      }

      // Draw labels
      if (showLabels) {
        final label = zone.optionIndex < options.length
            ? '${zone.optionIndex + 1}: ${options[zone.optionIndex]}'
            : zone.isDisabled
                ? 'X'
                : '?';

        final textStyle = TextStyle(
          color: zone.isDisabled
              ? Colors.red.withOpacity(0.5)
              : Colors.white.withOpacity(0.6),
          fontSize: 14,
          fontWeight: FontWeight.w500,
        );

        final textSpan = TextSpan(text: label, style: textStyle);
        final textPainter = TextPainter(
          text: textSpan,
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.center,
        );

        textPainter.layout();

        final offset = Offset(
          zone.rect.center.dx - textPainter.width / 2,
          zone.rect.center.dy - textPainter.height / 2,
        );

        textPainter.paint(canvas, offset);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TapZonePainter oldDelegate) {
    return oldDelegate.showGridLines != showGridLines ||
        oldDelegate.showLabels != showLabels ||
        oldDelegate.zones != zones;
  }
}
