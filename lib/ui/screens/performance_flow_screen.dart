import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../inputs/volume_button_listener.dart';
import '../../inputs/volume_input_controller.dart';
import '../../inputs/tap/tap_layout.dart';
import '../../inputs/tap/tap_input_controller.dart';
import '../../inputs/custom_swipe_input_controller.dart';
import '../../inputs/remote_key_listener.dart';
import '../../inputs/clock_swipe_input_controller.dart' show SwipeDirection;
import '../../utils/game_provider.dart';
import '../../utils/settings_provider.dart';
import '../../utils/reveal_provider.dart';
import '../theme/app_theme.dart';
import '../theme/note_theme.dart';
import '../widgets/chain_progress_indicator.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Performance flow stages
enum PerformanceStage {
  /// PRE_SCREEN: Optional fake screen (Notes or Homescreen)
  preScreen,
  /// STEALTH_INPUT: Black screen for volume/tap inputs
  stealthInput,
  /// FINAL_REVEAL: Background + generated narrative
  finalReveal,
}

/// Which screen is currently showing in stealth mode (list or note)
enum StealthScreenView {
  /// Showing the notes list screenshot
  list,
  /// Showing the individual note screenshot
  note,
}

/// Unified performance flow screen that handles all stages
/// NOTE: This screen is for Production Mode only.
/// Test Mode uses existing StealthInputScreen/TapStealthInputScreen directly.
class PerformanceFlowScreen extends StatefulWidget {
  final StealthInputMethod stealthMethod;
  final TapLayout2 tapLayout2;
  final TapLayout4 tapLayout4;
  final List<String>? swipePatterns;

  const PerformanceFlowScreen({
    super.key,
    required this.stealthMethod,
    this.tapLayout2 = TapLayout2.leftRight,
    this.tapLayout4 = TapLayout4.corners,
    this.swipePatterns,
  });

  @override
  State<PerformanceFlowScreen> createState() => _PerformanceFlowScreenState();
}

class _PerformanceFlowScreenState extends State<PerformanceFlowScreen> {
  late PerformanceStage _stage;

  // Volume button listener
  late VolumeButtonListener _volumeListener;
  VolumeInputController? _volumeInputController;
  StreamSubscription<VolumeDirection>? _volumeSubscription;
  bool _volumeAvailable = false;

  // Tap input controller (for stealth input)
  TapInputController? _tapInputController;
  List<TapZone> _tapZones = [];

  // Custom swipe input controller
  CustomSwipeInputController? _swipeInputController;

  // Current input stage tracking (for two-inputs mode)
  bool _isPerformerStage = false;
  bool _showingFeedback = false;

  // Test mode state (for overlay in stealth input)
  bool _mappingVisible = false;
  final bool _showGridLines = true;
  final bool _showLabels = false;
  String? _lastCommitLabel;
  int? _lastCommitIndex;
  final List<String> _commitHistory = [];
  static const int _maxHistorySize = 5;

  // Two-finger gesture tracking
  int _pointerCount = 0;
  Timer? _twoFingerLongPressTimer;
  static const _longPressDuration = Duration(milliseconds: 600);

  // List/Note navigation state
  StealthScreenView _currentScreenView = StealthScreenView.list;
  StealthScreenView _screenViewAtInput = StealthScreenView.list;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    _volumeListener = VolumeButtonListener();
    _initializeVolumeListener();

    // Determine starting stage based on preScreen setting
    final settings = context.read<SettingsProvider>();
    _stage = settings.preScreenEnabled
        ? PerformanceStage.preScreen
        : PerformanceStage.stealthInput;

    // If starting directly at stealthInput, initialize input controller after first frame
    if (_stage == PerformanceStage.stealthInput) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _initializeStealthInputController();
      });
    }

    // Set system UI to immersive
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  Future<void> _initializeVolumeListener() async {
    _volumeAvailable = await _volumeListener.isAvailable();
    if (_volumeAvailable) {
      final started = await _volumeListener.startListening();
      if (started) {
        _volumeSubscription = _volumeListener.onVolumeButtonPressed.listen(_handleVolumePress);
      }
    }

    if (mounted) {
      setState(() {});
    }
  }

  void _handleVolumePress(VolumeDirection direction) {
    if (direction == VolumeDirection.down) {
      // Volume Down transitions from preScreen to stealth input
      if (_stage == PerformanceStage.preScreen) {
        _transitionToStealthInput();
      }
    }

    // Forward volume presses to input controller during stealth input
    if (_stage == PerformanceStage.stealthInput && widget.stealthMethod == StealthInputMethod.volume) {
      _volumeInputController?.handleVolumePress(direction);
    }
  }

  /// Get list background path with fallback logic:
  /// 1. Try system theme (dark/light)
  /// 2. Fallback to opposite theme
  /// 3. If none uploaded, return null (no list screenshot available)
  /// Returns (path, isActuallyDark) - isActuallyDark indicates which theme the screenshot is
  (String? path, bool isActuallyDark) _getListBackgroundPathWithTheme(RevealProvider revealProvider, bool systemIsDark) {
    final hasDark = revealProvider.config.hasDarkListBackground;
    final hasLight = revealProvider.config.hasLightListBackground;

    // No list screenshots at all
    if (!hasDark && !hasLight) {
      return (null, systemIsDark);
    }

    // Try system theme first
    if (systemIsDark && hasDark) {
      final path = revealProvider.config.darkListBackgroundPath;
      if (path != null && File(path).existsSync()) {
        return (path, true);
      }
    } else if (!systemIsDark && hasLight) {
      final path = revealProvider.config.lightListBackgroundPath;
      if (path != null && File(path).existsSync()) {
        return (path, false);
      }
    }

    // Fallback to opposite theme
    if (systemIsDark && hasLight) {
      final path = revealProvider.config.lightListBackgroundPath;
      if (path != null && File(path).existsSync()) {
        return (path, false);
      }
    } else if (!systemIsDark && hasDark) {
      final path = revealProvider.config.darkListBackgroundPath;
      if (path != null && File(path).existsSync()) {
        return (path, true);
      }
    }

    return (null, systemIsDark);
  }

  /// Get note background path with fallback logic:
  /// 1. Try system theme (dark/light)
  /// 2. Fallback to opposite theme
  /// 3. If none uploaded, return null (will show classic Notes UI)
  /// Returns (path, isActuallyDark) - isActuallyDark indicates which theme the screenshot is
  (String? path, bool isActuallyDark) _getBackgroundPathWithTheme(RevealProvider revealProvider, bool systemIsDark) {
    // Check which backgrounds are actually available
    final hasDark = revealProvider.config.hasDarkBackground;
    final hasLight = revealProvider.config.hasLightBackground;

    // No screenshots at all - fallback to classic Notes UI
    if (!hasDark && !hasLight) {
      return (null, systemIsDark);
    }

    // Try system theme first (if that screenshot exists)
    if (systemIsDark && hasDark) {
      final path = revealProvider.config.darkBackgroundPath;
      if (path != null && File(path).existsSync()) {
        return (path, true); // Dark screenshot, actually dark
      }
    } else if (!systemIsDark && hasLight) {
      final path = revealProvider.config.lightBackgroundPath;
      if (path != null && File(path).existsSync()) {
        return (path, false); // Light screenshot, actually light
      }
    }

    // Fallback to opposite theme
    if (systemIsDark && hasLight) {
      final path = revealProvider.config.lightBackgroundPath;
      if (path != null && File(path).existsSync()) {
        return (path, false); // Using light screenshot even though system is dark
      }
    } else if (!systemIsDark && hasDark) {
      final path = revealProvider.config.darkBackgroundPath;
      if (path != null && File(path).existsSync()) {
        return (path, true); // Using dark screenshot even though system is light
      }
    }

    // No valid screenshots found
    return (null, systemIsDark);
  }

  // ============ LIST/NOTE NAVIGATION ============

  void _navigateToNote() {
    setState(() {
      _currentScreenView = StealthScreenView.note;
    });
  }

  void _navigateToList() {
    setState(() {
      _currentScreenView = StealthScreenView.list;
    });
  }

  /// Handle double tap to enter stealth input (when enabled in settings)
  void _onDoubleTapToStealth() {
    if (_stage == PerformanceStage.preScreen) {
      _transitionToStealthInput();
    }
  }

  // ============ HOTSPOT HANDLING ============

  /// Hotspot tap in preScreen transitions to stealthInput
  void _onHotspotTap() {
    final settings = context.read<SettingsProvider>();
    if (settings.hapticFeedback) {
      HapticFeedback.lightImpact();
    }

    if (_stage == PerformanceStage.preScreen) {
      _transitionToStealthInput();
    }
  }

  // ============ TRANSITIONS ============

  void _transitionToStealthInput() {
    setState(() {
      _stage = PerformanceStage.stealthInput;
      // Memorize which screen we're on when entering stealth input
      _screenViewAtInput = _currentScreenView;
    });

    _initializeStealthInputController();
  }

  /// Initialize stealth input controller based on method
  void _initializeStealthInputController() {
    final provider = context.read<GameProvider>();
    final settings = context.read<SettingsProvider>();

    if (widget.stealthMethod == StealthInputMethod.volume) {
      _volumeInputController = VolumeInputController(
        optionsCount: provider.options.length,
        hapticFeedback: settings.hapticFeedback,
        hapticIntensity: settings.hapticIntensity,
        onSelectionCommitted: _onSelectionCommitted,
        onUndoRequested: _onUndoRequested,
        onResetRequested: _onResetRequested,
        onInvalidInput: _onInvalidInput,
      );
    } else if (widget.stealthMethod == StealthInputMethod.tap) {
      _tapInputController = TapInputController(
        optionsCount: provider.options.length,
        hapticFeedback: settings.hapticFeedback,
        hapticIntensity: settings.hapticIntensity,
        onSelectionCommitted: _onSelectionCommitted,
        onUndoRequested: _onUndoRequested,
        onResetRequested: _onResetRequested,
        onInvalidInput: _onInvalidInput,
      );
    } else if (widget.stealthMethod == StealthInputMethod.clockSwipe) {
      // Fallback to a sensible default mapping when patterns are missing —
      // otherwise picking Swipe in the builder without ever opening the
      // pattern editor would leave swipes silently ignored at showtime.
      final patterns = (widget.swipePatterns != null && widget.swipePatterns!.isNotEmpty)
          ? CustomSwipeInputController.parsePatterns(widget.swipePatterns!)
          : _defaultClockSwipePatterns(provider.options.length);
      _swipeInputController = CustomSwipeInputController(
        patterns: patterns,
        hapticFeedback: settings.hapticFeedback,
        onSelectionCommitted: _onSelectionCommitted,
        onUndoRequested: _onUndoRequested,
        onResetRequested: _onResetRequested,
        onInvalidInput: _onInvalidInput,
      );
    }

    _updateInputStage(provider);
  }

  /// Default 1-swipe-per-option mapping used when a clockSwipe preset has no
  /// stored patterns. Cycles `up, right, down, left` and pads with two-step
  /// patterns starting at index 4 (covers up to ~16 options via clockMap-ish
  /// pairs).
  List<List<String>> _defaultClockSwipePatterns(int count) {
    const dirs = ['up', 'right', 'down', 'left'];
    if (count <= 4) {
      return List.generate(count, (i) => [dirs[i]]);
    }
    // Pair patterns (a, b) where a != b — 12 unique combos.
    final pairs = <List<String>>[];
    for (final a in dirs) {
      for (final b in dirs) {
        if (a != b) pairs.add([a, b]);
      }
    }
    return List.generate(count, (i) => pairs[i % pairs.length]);
  }

  void _transitionToFinalReveal() {
    setState(() {
      _stage = PerformanceStage.finalReveal;
    });
  }

  void _updateInputStage(GameProvider provider) {
    final isPreprogrammed = provider.inputMode == InputMode.preprogrammed;
    final isDirectMode = provider.predictionMode == PredictionMode.direct;

    if (isDirectMode || isPreprogrammed) {
      _isPerformerStage = false;
    } else {
      _isPerformerStage = !provider.hasPerformerChoiceForCurrentRound;
    }
  }

  // ============ INPUT HANDLING ============

  void _onSelectionCommitted(int optionIndex) {
    final provider = context.read<GameProvider>();
    final options = provider.options;

    if (optionIndex < 0 || optionIndex >= options.length) {
      _onInvalidInput();
      return;
    }

    final selectedOption = options[optionIndex];

    setState(() {
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
      // Auto-transition to final reveal when all rounds complete
      _transitionToFinalReveal();
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
      _addToHistory('\u21b6 Undo');
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
  }

  void _onResetRequested() {
    final provider = context.read<GameProvider>();

    setState(() {
      _commitHistory.clear();
      _addToHistory('\u21b6 Reset to Round 1');
      _lastCommitIndex = null;
      _lastCommitLabel = null;
    });

    provider.resetAllRounds();
    setState(() {
      _isPerformerStage = false;
      _updateInputStage(provider);
    });
  }

  void _onInvalidInput() {
    setState(() {
      _addToHistory('\u2717 Invalid');
    });
  }

  void _handleTapDown(TapDownDetails details) {
    if (_tapZones.isEmpty || _tapInputController == null) return;

    final zone = TapLayoutCalculator.findZoneAtPoint(_tapZones, details.localPosition);
    if (zone != null) {
      _tapInputController!.handleTap(zone);
    }
  }

  void _handlePointerDown(PointerDownEvent event) {
    _pointerCount++;
    if (_pointerCount == 2) {
      _twoFingerLongPressTimer?.cancel();
      _twoFingerLongPressTimer = Timer(_longPressDuration, () {
        if (_pointerCount >= 2) {
          // Two-finger long press fallback
          if (_stage == PerformanceStage.preScreen) {
            _transitionToStealthInput();
          } else if (_stage == PerformanceStage.stealthInput) {
            _tapInputController?.handleUndoGesture();
          }
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

  void _exitToHome() {
    final provider = context.read<GameProvider>();
    provider.reset();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _confirmExit() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text(
          'Exit Performance?',
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
              Navigator.pop(ctx);
              _exitToHome();
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
    _volumeInputController?.dispose();
    _tapInputController?.dispose();
    _swipeInputController?.dispose();
    _volumeListener.dispose();
    _twoFingerLongPressTimer?.cancel();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer3<GameProvider, SettingsProvider, RevealProvider>(
      builder: (context, gameProvider, settingsProvider, revealProvider, child) {
        switch (_stage) {
          case PerformanceStage.preScreen:
            return _buildPreScreenStage(context, gameProvider, settingsProvider, revealProvider);
          case PerformanceStage.stealthInput:
            return _buildStealthInputStage(context, gameProvider, settingsProvider);
          case PerformanceStage.finalReveal:
            return _buildFinalRevealStage(context, gameProvider, settingsProvider, revealProvider);
        }
      },
    );
  }

  // ============ PRE-SCREEN STAGE ============

  Widget _buildPreScreenStage(
    BuildContext context,
    GameProvider gameProvider,
    SettingsProvider settingsProvider,
    RevealProvider revealProvider,
  ) {
    final brightness = MediaQuery.of(context).platformBrightness;
    final systemIsDark = brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;

    // Determine which fake screen to show
    final isHomescreen = settingsProvider.preScreenType == 'homescreen';

    if (isHomescreen) {
      // Show homescreen screenshot
      final homescreenPath = settingsProvider.homescreenPath;
      return _buildPreScreenWithImage(
        context: context,
        settingsProvider: settingsProvider,
        imagePath: homescreenPath,
        isDark: systemIsDark,
      );
    }

    // Show Notes list (default)
    final (listBackgroundPath, listActuallyDark) = _getListBackgroundPathWithTheme(revealProvider, systemIsDark);
    final (noteBackgroundPath, noteActuallyDark) = _getBackgroundPathWithTheme(revealProvider, systemIsDark);

    // If no list background, try showing note background directly
    final hasListScreen = listBackgroundPath != null;

    if (!hasListScreen && noteBackgroundPath == null) {
      // Fallback: no screenshots at all, show minimal Notes UI
      return _buildFallbackPreScreen(context, settingsProvider);
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Listener(
        onPointerDown: _handlePointerDown,
        onPointerUp: _handlePointerUp,
        child: Stack(
          children: [
            // List screen (if available and currently showing list)
            if (hasListScreen)
              AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                left: _currentScreenView == StealthScreenView.list ? 0 : -screenWidth,
                top: 0,
                bottom: 0,
                width: screenWidth,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _navigateToNote,
                  onDoubleTap: settingsProvider.doubleTapFallbackEnabled ? _onDoubleTapToStealth : null,
                  child: Image.file(
                    File(listBackgroundPath),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(color: Colors.black),
                  ),
                ),
              ),

            // Note screen (slides in from right, or shown directly if no list)
            if (noteBackgroundPath != null)
              AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                left: hasListScreen && _currentScreenView == StealthScreenView.list ? screenWidth : 0,
                top: 0,
                bottom: 0,
                width: screenWidth,
                child: Stack(
                  children: [
                    // Background image with double tap support
                    Positioned.fill(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onDoubleTap: settingsProvider.doubleTapFallbackEnabled ? _onDoubleTapToStealth : null,
                        child: Image.file(
                          File(noteBackgroundPath),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(color: Colors.black),
                        ),
                      ),
                    ),

                    // Back button zone (top-left, invisible) - only if we have list screen
                    if (hasListScreen && _currentScreenView == StealthScreenView.note)
                      Positioned(
                        top: 0,
                        left: 0,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: _navigateToList,
                          child: Container(
                            width: 100,
                            height: 100,
                            decoration: settingsProvider.testModeEnabled
                                ? BoxDecoration(
                                    border: Border.all(color: Colors.yellow.withOpacity(0.5), width: 1),
                                  )
                                : null,
                          ),
                        ),
                      ),

                    // Top-right hotspot (TAP to transition to stealth input)
                    Positioned(
                      top: MediaQuery.of(context).padding.top,
                      right: 0,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _onHotspotTap,
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: settingsProvider.testModeEnabled
                              ? BoxDecoration(
                                  border: Border.all(color: Colors.red.withOpacity(0.5), width: 1),
                                )
                              : null,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Hidden exit hotspot (top-left, long press) - always accessible
            Positioned(
              top: 0,
              left: 0,
              child: GestureDetector(
                onLongPress: _confirmExit,
                child: Container(
                  width: 60,
                  height: 60,
                  color: Colors.transparent,
                ),
              ),
            ),

            // Hint at bottom
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  'Volume Down to continue',
                  style: TextStyle(
                    color: (noteActuallyDark ? Colors.white : Colors.black).withOpacity(0.3),
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build preScreen with a single full-screen image (e.g. homescreen screenshot)
  Widget _buildPreScreenWithImage({
    required BuildContext context,
    required SettingsProvider settingsProvider,
    required String? imagePath,
    required bool isDark,
  }) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Listener(
        onPointerDown: _handlePointerDown,
        onPointerUp: _handlePointerUp,
        child: Stack(
          children: [
            // Full-screen image
            if (imagePath != null && File(imagePath).existsSync())
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onDoubleTap: settingsProvider.doubleTapFallbackEnabled ? _onDoubleTapToStealth : null,
                  child: Image.file(
                    File(imagePath),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(color: Colors.black),
                  ),
                ),
              )
            else
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onDoubleTap: settingsProvider.doubleTapFallbackEnabled ? _onDoubleTapToStealth : null,
                  child: Container(color: Colors.black),
                ),
              ),

            // Top-right hotspot (TAP to transition to stealth input)
            Positioned(
              top: MediaQuery.of(context).padding.top,
              right: 0,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _onHotspotTap,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: settingsProvider.testModeEnabled
                      ? BoxDecoration(
                          border: Border.all(color: Colors.red.withOpacity(0.5), width: 1),
                        )
                      : null,
                ),
              ),
            ),

            // Hidden exit hotspot (top-left, long press)
            Positioned(
              top: 0,
              left: 0,
              child: GestureDetector(
                onLongPress: _confirmExit,
                child: Container(
                  width: 60,
                  height: 60,
                  color: Colors.transparent,
                ),
              ),
            ),

            // Hint at bottom
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  'Volume Down to continue',
                  style: TextStyle(
                    color: (isDark ? Colors.white : Colors.black).withOpacity(0.3),
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Fallback preScreen UI when no background images are available
  Widget _buildFallbackPreScreen(
    BuildContext context,
    SettingsProvider settingsProvider,
  ) {
    return Scaffold(
      backgroundColor: NoteTheme.noteBackground,
      body: Listener(
        onPointerDown: _handlePointerDown,
        onPointerUp: _handlePointerUp,
        child: SafeArea(
          child: Stack(
            children: [
              // Main content with double tap support
              GestureDetector(
                behavior: HitTestBehavior.translucent,
                onDoubleTap: settingsProvider.doubleTapFallbackEnabled ? _onDoubleTapToStealth : null,
                child: Column(
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: NoteTheme.headerDecoration,
                      child: Row(
                        children: [
                          Text('Notes', style: NoteTheme.noteTimestamp),
                          const Spacer(),
                          Icon(Icons.folder_outlined, color: Colors.grey[600], size: 16),
                        ],
                      ),
                    ),

                    // Empty body area
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              NoteTheme.formatDate(DateTime.now()),
                              style: NoteTheme.noteTimestamp,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Top-right hotspot (TAP to transition to stealth input)
              Positioned(
                top: MediaQuery.of(context).padding.top,
                right: 0,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _onHotspotTap,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: settingsProvider.testModeEnabled
                        ? BoxDecoration(
                            border: Border.all(color: Colors.red.withOpacity(0.5), width: 1),
                          )
                        : null,
                  ),
                ),
              ),

              // Hidden exit hotspot
              Positioned(
                top: 0,
                left: 0,
                child: GestureDetector(
                  onLongPress: _confirmExit,
                  child: Container(
                    width: 60,
                    height: 60,
                    color: Colors.transparent,
                  ),
                ),
              ),

              // Hint at bottom
              Positioned(
                bottom: 40,
                left: 0,
                right: 0,
                child: Center(
                  child: Text(
                    'Volume Down to continue',
                    style: TextStyle(
                      color: Colors.grey.withOpacity(0.5),
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============ STEALTH INPUT STAGE ============

  Widget _buildStealthInputStage(
    BuildContext context,
    GameProvider gameProvider,
    SettingsProvider settingsProvider,
  ) {
    final testMode = settingsProvider.testModeEnabled;

    if (widget.stealthMethod == StealthInputMethod.tap) {
      return _buildTapStealthInput(context, gameProvider, testMode);
    } else if (widget.stealthMethod == StealthInputMethod.clockSwipe && _swipeInputController != null) {
      return _buildSwipeStealthInput(context, gameProvider, testMode);
    } else {
      return _buildVolumeStealthInput(context, gameProvider, testMode);
    }
  }

  Widget _buildVolumeStealthInput(BuildContext context, GameProvider provider, bool testMode) {
    return RemoteKeyListener(
      onVolumeKey: (dir) => _volumeInputController?.handleVolumePress(dir),
      child: GestureDetector(
      onLongPress: _confirmExit,
      child: Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Container(color: Colors.black),

          // Test Mode Overlay
          if (testMode) _buildTestModeOverlay(provider),

          // Subtle feedback indicator (non-test mode)
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

          // Chain progress indicator
          Consumer<GameProvider>(
            builder: (_, gp, __) => gp.isChaining
                ? ChainProgressIndicator(total: gp.chainTotal, currentIndex: gp.chainCurrentIndex)
                : const SizedBox.shrink(),
          ),

          // Hidden exit button (top-left)
          Positioned(
            top: 0,
            left: 0,
            child: GestureDetector(
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
    ),
    );
  }

  Widget _buildSwipeStealthInput(BuildContext context, GameProvider provider, bool testMode) {
    return RemoteKeyListener(
      onSwipeKey: (dir) => _swipeInputController?.handleSwipe(_swipeDirString(dir)),
      child: Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Swipe detection area. Uses only `velocity` from onPanEnd — no
          // start-point bookkeeping (the previous `_startX/Y` locals were
          // reset on rebuild, silently dropping swipes when a parent setState
          // fired between onPanStart and onPanEnd).
          GestureDetector(
            onLongPress: _confirmExit,
            behavior: HitTestBehavior.opaque,
            onPanEnd: (d) {
              final dx = d.velocity.pixelsPerSecond.dx;
              final dy = d.velocity.pixelsPerSecond.dy;
              final pdx = dx.abs();
              final pdy = dy.abs();

              if (pdx < 100 && pdy < 100) return; // too slow

              final String dir;
              if (pdx > pdy) {
                dir = dx > 0 ? 'right' : 'left';
              } else {
                dir = dy > 0 ? 'down' : 'up';
              }
              _swipeInputController?.handleSwipe(dir);
            },
            child: Container(color: Colors.black),
          ),

          // Test Mode Overlay
          if (testMode) _buildTestModeOverlay(provider),

          // Subtle feedback indicator (non-test mode)
          if (_showingFeedback && !testMode)
            Center(
              child: Container(
                width: 4, height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
              ),
            ),

          // Chain progress indicator
          Consumer<GameProvider>(
            builder: (_, gp, __) => gp.isChaining
                ? ChainProgressIndicator(total: gp.chainTotal, currentIndex: gp.chainCurrentIndex)
                : const SizedBox.shrink(),
          ),

          // Hidden exit button (top-left)
          Positioned(
            top: 0, left: 0,
            child: GestureDetector(
              onLongPress: _confirmExit,
              child: Container(width: 60, height: 60, color: Colors.transparent),
            ),
          ),
        ],
      ),
    ),
    );
  }

  /// Convert remote-key SwipeDirection enum to the string convention used by
  /// the swipe input controllers in this app.
  String _swipeDirString(SwipeDirection d) {
    switch (d) {
      case SwipeDirection.up: return 'up';
      case SwipeDirection.down: return 'down';
      case SwipeDirection.left: return 'left';
      case SwipeDirection.right: return 'right';
    }
  }

  Widget _buildTapStealthInput(BuildContext context, GameProvider provider, bool testMode) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          _tapZones = TapLayoutCalculator.computeZones(
            screenSize: size,
            optionsCount: provider.options.length,
            layout2: widget.tapLayout2,
            layout4: widget.tapLayout4,
          );

          return Stack(
            children: [
              // Main tap area
              Positioned.fill(
                child: Listener(
                  onPointerDown: _handlePointerDown,
                  onPointerUp: _handlePointerUp,
                  child: GestureDetector(
                    onTapDown: _handleTapDown,
                    child: Container(
                      color: Colors.black,
                      child: testMode
                          ? CustomPaint(
                              painter: _TapZonePainter(
                                zones: _tapZones,
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

              // Subtle feedback indicator (non-test mode)
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

              // Hidden exit button
              Positioned(
                top: 0,
                left: 0,
                child: GestureDetector(
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
  }

  /// Minimal test-mode overlay: a top status line with per-round commits
  /// plus a centered mapping body (gesture → option label) appropriate to
  /// the input method. Tap mode skips the mapping body (zones already
  /// labelled by the painter).
  Widget _buildTestModeOverlay(GameProvider provider) {
    final total = provider.totalRounds;
    final round = provider.currentRound;
    final session = provider.currentSession;
    final rounds = session?.rounds ?? const [];
    final options = provider.options;
    final method = widget.stealthMethod;

    String shortFor(String label) => label.isEmpty ? '?' : label.substring(0, 1).toUpperCase();
    final cells = List<String>.generate(total, (i) {
      if (i < rounds.length) return shortFor(rounds[i].spectatorChoice);
      return '_';
    });
    final stateLine = 'R $round/$total   [ ${cells.join('  ')} ]';

    Widget? mappingBody;
    if (method == StealthInputMethod.volume) {
      mappingBody = _buildSimpleMappingList(
        options.length,
        (i) {
          // 3-option presets share double-up & double-down for option 3.
          if (options.length == 3 && i == 2) return '↑↑ / ↓↓';
          final gesture = VolumeGesture.fromOptionIndex(i);
          if (gesture == null) return null;
          final arrow = gesture.direction == VolumeDirection.up ? '↑' : '↓';
          return gesture.tapCount == 1 ? arrow : List.filled(gesture.tapCount, arrow).join('');
        },
        options,
      );
    } else if (method == StealthInputMethod.clockSwipe) {
      final patterns = (widget.swipePatterns != null && widget.swipePatterns!.isNotEmpty)
          ? CustomSwipeInputController.parsePatterns(widget.swipePatterns!)
          : _defaultClockSwipePatterns(options.length);
      mappingBody = _buildSimpleMappingList(
        options.length,
        (i) => i < patterns.length
            ? patterns[i].map(_swipeDirArrow).join('')
            : null,
        options,
      );
    }

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
            if (mappingBody != null) Expanded(child: Center(child: mappingBody)),
          ],
        ),
      ),
    );
  }

  static String _swipeDirArrow(String dir) {
    switch (dir) {
      case 'up': return '↑';
      case 'down': return '↓';
      case 'left': return '←';
      case 'right': return '→';
      default: return '?';
    }
  }

  /// Compact gesture → label list used by both volume and swipe test modes.
  /// [gestureFor] returns the rendered gesture (or null to skip the row).
  Widget _buildSimpleMappingList(
    int count,
    String? Function(int i) gestureFor,
    List<String> labels,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(count, (i) {
        final gesture = gestureFor(i);
        if (gesture == null) return const SizedBox.shrink();
        final label = i < labels.length ? labels[i] : '?';
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 110,
                child: Text(
                  gesture,
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
                label,
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
    );
  }

  Widget _buildVolumeMappingPanel(GameProvider provider) {
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

            final directionIcon = gesture.direction == VolumeDirection.up ? '\u25b2' : '\u25bc';
            final label = index < options.length ? options[index] : '?';

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
                    ' \u2192 ',
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

  // ============ FINAL REVEAL ============

  Widget _buildFinalRevealStage(
    BuildContext context,
    GameProvider gameProvider,
    SettingsProvider settingsProvider,
    RevealProvider revealProvider,
  ) {
    final narrative = gameProvider.generatedNarrative ?? '';
    final brightness = MediaQuery.of(context).platformBrightness;
    final systemIsDark = brightness == Brightness.dark;

    // Determine which background to show based on the screen that was active during input
    final (noteBackgroundPath, noteActuallyDark) = _getBackgroundPathWithTheme(revealProvider, systemIsDark);
    final (listBackgroundPath, listActuallyDark) = _getListBackgroundPathWithTheme(revealProvider, systemIsDark);

    // Use list screenshot if input was made from list screen and list screenshot exists
    final shouldShowList = _screenViewAtInput == StealthScreenView.list && listBackgroundPath != null;
    final backgroundPath = shouldShowList ? listBackgroundPath : noteBackgroundPath;
    final actuallyDark = shouldShowList ? listActuallyDark : noteActuallyDark;

    final layout = revealProvider.getTextLayout(isDarkMode: actuallyDark);
    final screenWidth = MediaQuery.of(context).size.width;
    final effectiveMaxWidth = layout.maxWidth > 0 ? layout.maxWidth : screenWidth - 48;

    if (backgroundPath == null) {
      // Fallback to simple black background with text
      return Scaffold(
        backgroundColor: Colors.black,
        body: GestureDetector(
          onTap: _exitToHome,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                narrative,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  height: 1.4,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Background image (tappable to exit)
          Positioned.fill(
            child: GestureDetector(
              onTap: _exitToHome,
              child: Image.file(
                File(backgroundPath),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(color: Colors.black),
              ),
            ),
          ),

          // Narrative text overlay at calibrated position
          Positioned(
            left: layout.offsetX,
            top: layout.offsetY,
            child: Container(
              constraints: BoxConstraints(maxWidth: effectiveMaxWidth),
              child: Text(
                narrative,
                style: TextStyle(
                  fontSize: layout.fontSize,
                  height: layout.lineHeight,
                  color: actuallyDark ? Colors.white : Colors.black,
                  fontFamily: '.SF Pro Text',
                ),
              ),
            ),
          ),

          // Hint at bottom
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                'Tap anywhere to exit',
                style: TextStyle(
                  color: (actuallyDark ? Colors.white : Colors.black).withOpacity(0.3),
                  fontSize: 12,
                ),
              ),
            ),
          ),
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
      if (zone.isDisabled) {
        canvas.drawRect(zone.rect, disabledPaint);
      }

      if (showGridLines) {
        canvas.drawRect(zone.rect, linePaint);
      }

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
