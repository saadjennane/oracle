import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../inputs/free_will_input_controller.dart';
import '../../inputs/free_will_input_state.dart';
import '../../inputs/free_will_input_mapping.dart';
import '../../inputs/custom_swipe_input_controller.dart';
import '../../inputs/remote_key_listener.dart';
import '../../inputs/clock_swipe_input_controller.dart' show SwipeDirection;
import '../../utils/reveal_provider.dart';
import '../../utils/settings_provider.dart';
import '../theme/app_theme.dart';
import '../theme/note_theme.dart';
import '../widgets/free_will_input_help_panel.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Free Will input screen with support for Volume and Tap modes
class FreeWillInputScreen extends StatefulWidget {
  final FreeWillConfig config;
  final FreeWillInputMethod inputMethod;
  final List<String>? swipePatterns;

  /// Called when the routine completes. `runtimeLabels` is non-null when the
  /// performer overrode the 3 object labels via the long-press fake-note
  /// overlay during this run only — they should be applied to the narrative
  /// post-generation, leaving the saved preset untouched.
  final void Function(FreeWillResult result, List<String>? runtimeLabels) onComplete;

  const FreeWillInputScreen({
    super.key,
    required this.config,
    required this.inputMethod,
    this.swipePatterns,
    required this.onComplete,
  });

  @override
  State<FreeWillInputScreen> createState() => _FreeWillInputScreenState();
}

class _FreeWillInputScreenState extends State<FreeWillInputScreen> {
  late FreeWillInputController _controller;
  bool _isInitialized = false;
  bool _volumeAvailable = true;

  // UI state
  String? _statusMessage;
  Timer? _statusTimer;

  // Runtime label override — only for the current performance.
  // null = use widget.config.objects (the saved labels).
  List<String>? _runtimeLabels;
  bool _showLabelOverlay = false;
  late final List<TextEditingController> _labelControllers;
  bool _inPreScreen = false;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    _labelControllers = List.generate(
      3,
      (i) => TextEditingController(
        text: i < widget.config.objects.length ? widget.config.objects[i] : '',
      ),
    );
    _inPreScreen = context.read<SettingsProvider>().preScreenEnabled;
    _initializeController();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  Future<void> _initializeController() async {
    final settings = context.read<SettingsProvider>();

    _controller = FreeWillInputController(
      inputMethod: widget.inputMethod,
      hapticFeedback: settings.hapticFeedback,
      hapticIntensity: settings.hapticIntensity,
      suggestChangeOfMind: widget.config.suggestChangeOfMind,
      onInputCaptured: _onInputCaptured,
      onDeductionComplete: _onDeductionComplete,
      onSwapPerformed: _onSwapPerformed,
      onLocked: _onLocked,
      onRevealed: _onRevealed,
    );

    final started = await _controller.startListening();
    if (!started && widget.inputMethod == FreeWillInputMethod.volume) {
      _volumeAvailable = false;
    }

    if (mounted) {
      setState(() {
        _isInitialized = true;
      });
    }
  }

  void _showStatus(String message, {Duration duration = const Duration(milliseconds: 800)}) {
    _statusTimer?.cancel();
    setState(() {
      _statusMessage = message;
    });
    _statusTimer = Timer(duration, () {
      if (mounted) {
        setState(() {
          _statusMessage = null;
        });
      }
    });
  }

  void _onInputCaptured(FreeWillInput input, int captureIndex) {
    _showStatus('Input ${input.value}: captured ($captureIndex/2)');
  }

  void _onDeductionComplete(FreeWillInput deduced, List<int> initialSlots) {
    _showStatus('Deduced: ${deduced.value} | Slots: $initialSlots', duration: const Duration(seconds: 1));
  }

  void _onSwapPerformed(FreeWillSwapType swap, List<int> newSlots) {
    _showStatus('${swap.name} | Slots: $newSlots');
  }

  void _onLocked() {
    _showStatus('LOCKED', duration: const Duration(seconds: 2));
  }

  void _onRevealed(List<int> finalSlots, int swapCount, List<int>? lastSwapSlots) {
    // Build result from final slots
    final result = _buildResult(finalSlots, swapCount, lastSwapSlots);
    if (result != null) {
      // Restore UI and call completion
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      widget.onComplete(result, _runtimeLabels);
    }
  }

  FreeWillResult? _buildResult(List<int> slots, int swapCount, List<int>? lastSwapSlots) {
    if (slots.length != 3) return null;

    final config = widget.config;
    final objects = config.objects;
    final actionOrder = config.actionOrder;

    String? takeObject, giveObject, tableObject;

    if (config.inputMode == FreeWillInputMode.byObject) {
      // byObject: value = action (via actionOrder), position = object (via objectOrder)
      for (int pos = 0; pos < 3; pos++) {
        final actionIndex = slots[pos] - 1; // value → action index
        if (actionIndex < 0 || actionIndex >= actionOrder.length) return null;
        final action = actionOrder[actionIndex];
        final objIdx = config.objectOrder[pos]; // position → object index
        if (objIdx < 0 || objIdx >= objects.length) return null;
        final obj = objects[objIdx];
        switch (action) {
          case FreeWillAction.take:
            takeObject = obj;
          case FreeWillAction.give:
            giveObject = obj;
          case FreeWillAction.table:
            tableObject = obj;
        }
      }
    } else {
      // byAction: value = object, position = action (via actionOrder)
      for (int pos = 0; pos < 3; pos++) {
        final objectIndex = slots[pos] - 1; // value → object index
        if (objectIndex < 0 || objectIndex >= objects.length) return null;
        final obj = objects[objectIndex];
        final action = actionOrder[pos]; // position → action
        switch (action) {
          case FreeWillAction.take:
            takeObject = obj;
          case FreeWillAction.give:
            giveObject = obj;
          case FreeWillAction.table:
            tableObject = obj;
        }
      }
    }

    if (takeObject == null || giveObject == null || tableObject == null) {
      return null;
    }

    // Resolve {lastSwap1}/{lastSwap2} object names from the swap's slot
    // positions. The slot → object mapping after all swaps lines up with
    // the action order: slot 0 ↔ take, slot 1 ↔ give, slot 2 ↔ table.
    String? lastSwap1Obj, lastSwap2Obj;
    if (lastSwapSlots != null && lastSwapSlots.length == 2) {
      final slotObjects = [takeObject, giveObject, tableObject];
      lastSwap1Obj = slotObjects[lastSwapSlots[0]];
      lastSwap2Obj = slotObjects[lastSwapSlots[1]];
    }

    return FreeWillResult(
      takeObject: takeObject,
      giveObject: giveObject,
      tableObject: tableObject,
      swapCount: swapCount,
      lastSwap1Object: lastSwap1Obj,
      lastSwap2Object: lastSwap2Obj,
    );
  }

  void _handleScreenTap() {
    if (widget.inputMethod == FreeWillInputMethod.volume) {
      _controller.handleScreenTap();
    } else {
      // In tap mode, tap after lock = reveal
      _controller.handleAnyTap();
    }
  }

  void _handleTapZone(int zone) {
    if (widget.inputMethod != FreeWillInputMethod.tap) return;

    // Once volume has locked the selection, any tap on a zone reveals the
    // result — same UX as volume mode where the screen tap reveals after
    // lock. Without this fallback the locked state was a dead end.
    if (_controller.isLocked) {
      _controller.handleAnyTap();
      return;
    }

    switch (zone) {
      case 1:
        _controller.handleTapZone1();
        break;
      case 2:
        _controller.handleTapZone2();
        break;
      case 3:
        _controller.handleTapZone3();
        break;
    }
  }

  void _confirmExit() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text(
          'Exit Free Will?',
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
              SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
              Navigator.of(context).pop();
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
    _statusTimer?.cancel();
    _controller.dispose();
    for (final c in _labelControllers) {
      c.dispose();
    }
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _openLabelOverlay() {
    if (_controller.phase != FreeWillPhaseState.capturing ||
        _controller.state.capturedInputs.isNotEmpty) {
      // Only allow editing labels before any input has been captured.
      return;
    }
    if (context.read<SettingsProvider>().hapticFeedback) {
      HapticFeedback.mediumImpact();
    }
    setState(() => _showLabelOverlay = true);
  }

  void _closeLabelOverlayAndApply() {
    final edited = _labelControllers.map((c) => c.text.trim()).toList();
    final hasOverride = List.generate(3, (i) {
      return i < widget.config.objects.length &&
          edited[i].isNotEmpty &&
          edited[i] != widget.config.objects[i];
    }).any((b) => b);
    setState(() {
      _runtimeLabels = hasOverride ? edited : null;
      _showLabelOverlay = false;
    });
    if (context.read<SettingsProvider>().hapticFeedback) {
      HapticFeedback.lightImpact();
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final testMode = settings.testModeEnabled;

    if (!_isInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Colors.white24),
        ),
      );
    }

    if (!_volumeAvailable && widget.inputMethod == FreeWillInputMethod.volume) {
      return _buildUnavailableScreen();
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: RemoteKeyListener(
        onVolumeKey: widget.inputMethod == FreeWillInputMethod.volume
            ? (dir) => _controller.handleVolumePress(dir)
            : null,
        onSwipeKey: widget.inputMethod == FreeWillInputMethod.swipe
            ? (dir) => _handleRemoteSwipe(dir)
            : null,
        child: Stack(
        children: [
          // Main interaction area
          if (widget.inputMethod == FreeWillInputMethod.volume)
            _buildVolumeMode(testMode)
          else if (widget.inputMethod == FreeWillInputMethod.swipe)
            _buildSwipeMode(testMode)
          else
            _buildTapMode(testMode),

          // Test mode overlay — IgnorePointer so taps reach the zones below.
          if (testMode) IgnorePointer(ignoring: true, child: _buildTestModeOverlay()),

          // Status message (non-test mode)
          if (_statusMessage != null && !testMode)
            Positioned(
              bottom: 50,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  _statusMessage!,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.15),
                    fontSize: 12,
                  ),
                ),
              ),
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

          // Subtle dot in top-right when override is active so the performer
          // sees that the labels have been changed for this run.
          if (_runtimeLabels != null && !testMode && !_showLabelOverlay)
            Positioned(
              top: MediaQuery.of(context).padding.top + 6,
              right: 8,
              child: Container(
                width: 5,
                height: 5,
                decoration: const BoxDecoration(
                  color: Colors.amber,
                  shape: BoxShape.circle,
                ),
              ),
            ),

          // Long-press label-edit overlay rendered on top of the fake note.
          if (_showLabelOverlay) _buildLabelOverlay(context),
          if (_inPreScreen) _buildPreScreenOverlay(context),
        ],
        ),
      ),
    );
  }

  Widget _buildPreScreenOverlay(BuildContext context) {
    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _inPreScreen = false),
        child: Container(
          color: Colors.black,
          alignment: Alignment.center,
          child: Text(
            'Tap to continue',
            style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 13),
          ),
        ),
      ),
    );
  }

  /// Replays the same swipe → input + lock-direction logic used by the
  /// on-screen pan handler when the spectator presses a Bluetooth remote
  /// key. Keeps the lock-gesture semantics identical between physical
  /// swipes and remote presses.
  void _handleRemoteSwipe(SwipeDirection direction) {
    if (widget.inputMethod != FreeWillInputMethod.swipe) return;
    final dir = direction.name;
    final patterns = _swipeController?.patterns ?? const <List<String>>[];
    final usedDirs = <String>{};
    for (final p in patterns) {
      for (final d in p) { usedDirs.add(d); }
    }
    final allDirs = ['up', 'right', 'down', 'left'];
    final lockDir = allDirs.firstWhere((d) => !usedDirs.contains(d), orElse: () => '');
    if (lockDir.isNotEmpty && dir == lockDir &&
        _controller.phase == FreeWillPhaseState.swapping) {
      _controller.handleSwipeLock();
      return;
    }
    _swipeController?.handleSwipe(dir);
  }

  Widget _buildLabelOverlay(BuildContext context) {
    final reveal = context.watch<RevealProvider>();
    final settings = context.watch<SettingsProvider>();
    final isDark = settings.revealIsDarkMode;
    final bgPath = reveal.getBackgroundPath(isDarkMode: isDark);

    return Positioned.fill(
      child: Stack(
        children: [
          // Fake note background — uses the user's uploaded image when set,
          // otherwise falls back to the default Notes-style yellow/dark.
          Positioned.fill(
            child: bgPath != null
                ? Image.file(File(bgPath), fit: BoxFit.cover)
                : Container(color: NoteTheme.noteBackground),
          ),

          // Three editable labels stacked like lines of a written note.
          Positioned.fill(
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(28, 80, 28, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: List.generate(3, (i) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: TextField(
                        controller: _labelControllers[i],
                        style: TextStyle(
                          color: bgPath != null
                              ? Colors.black87
                              : (isDark ? Colors.white : Colors.black87),
                          fontSize: 22,
                          height: 1.4,
                        ),
                        cursorColor: Colors.black54,
                        decoration: InputDecoration(
                          hintText: i < widget.config.objects.length
                              ? widget.config.objects[i]
                              : 'Label ${i + 1}',
                          hintStyle: TextStyle(
                            color: (bgPath != null
                                    ? Colors.black54
                                    : (isDark ? Colors.white54 : Colors.black54))
                                .withOpacity(0.5),
                            fontSize: 22,
                          ),
                          isDense: true,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 4),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
          ),

          // Invisible dismiss zone — top-right, just under the battery icon.
          Positioned(
            top: 0,
            right: 0,
            child: GestureDetector(
              onTap: _closeLabelOverlayAndApply,
              behavior: HitTestBehavior.opaque,
              child: SizedBox(
                width: 64,
                height: MediaQuery.of(context).padding.top + 48,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVolumeMode(bool testMode) {
    return GestureDetector(
      onTap: _handleScreenTap,
      onLongPress: _openLabelOverlay,
      child: Container(
        color: Colors.black,
        alignment: Alignment.center,
        child: testMode
            ? _buildMappingList(const [
                ['↑', 'Input 1'],
                ['↓', 'Input 2'],
                ['↑↑ / ↓↓', 'Input 3'],
                ['TAP', 'LOCK'],
              ])
            : Container(),
      ),
    );
  }

  /// Compact two-column mapping list used by Volume / Swipe test-mode bodies.
  /// First column = input gesture, second column = effect. Large enough to
  /// be read at arm's length, no decorations.
  Widget _buildMappingList(List<List<String>> rows) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: rows.map((r) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 110,
              child: Text(
                r[0],
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
              r[1],
              style: TextStyle(
                color: Colors.white.withOpacity(0.55),
                fontSize: 22,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      )).toList(),
    );
  }

  CustomSwipeInputController? _swipeController;

  static String _dirArrow(String dir) {
    switch (dir) {
      case 'up': return '↑';
      case 'down': return '↓';
      case 'left': return '←';
      case 'right': return '→';
      default: return '?';
    }
  }

  Widget _buildSwipeMode(bool testMode) {
    _swipeController ??= CustomSwipeInputController(
      patterns: widget.swipePatterns != null
          ? CustomSwipeInputController.parsePatterns(widget.swipePatterns!)
          : [['up'], ['right'], ['down']], // default 3 patterns
      hapticFeedback: context.read<SettingsProvider>().hapticFeedback,
      // Free Will lets the spectator do many same-direction swipes during
      // swap phase. The "3 rapid identical swipes = undo" shortcut would
      // silently swallow legitimate swap inputs, so disable it here.
      disableRapidUndo: true,
      onSelectionCommitted: (index) {
        _controller.handleSwipeSelection(index);
      },
    );

    // Find the lock gesture = direction NOT used by any pattern
    final usedDirs = <String>{};
    final patterns = _swipeController!.patterns;
    for (final p in patterns) {
      for (final d in p) { usedDirs.add(d); }
    }
    final allDirs = ['up', 'right', 'down', 'left'];
    final lockDir = allDirs.firstWhere((d) => !usedDirs.contains(d), orElse: () => '');

    return GestureDetector(
      onPanEnd: (d) {
        final dx = d.velocity.pixelsPerSecond.dx;
        final dy = d.velocity.pixelsPerSecond.dy;
        if (dx.abs() < 100 && dy.abs() < 100) return;
        String dir;
        if (dx.abs() > dy.abs()) {
          dir = dx > 0 ? 'right' : 'left';
        } else {
          dir = dy > 0 ? 'down' : 'up';
        }
        // Lock gesture
        if (lockDir.isNotEmpty && dir == lockDir &&
            _controller.phase == FreeWillPhaseState.swapping) {
          _controller.handleSwipeLock();
          return;
        }
        _swipeController?.handleSwipe(dir);
      },
      onTap: () {
        if (_controller.isLocked) {
          _controller.handleAnyTap();
        }
      },
      onLongPress: _openLabelOverlay,
      child: Container(
        color: Colors.black,
        alignment: Alignment.center,
        child: testMode
            ? _buildMappingList([
                for (int i = 0; i < patterns.length; i++)
                  [_dirArrow(patterns[i].first), 'Input ${i + 1}'],
                [lockDir.isNotEmpty ? _dirArrow(lockDir) : 'VOL', 'LOCK'],
                ['TAP', 'REVEAL'],
              ])
            : Container(),
      ),
    );
  }

  Widget _buildTapMode(bool testMode) {
    final isHorizontal = widget.config.tapOrientation == TapOrientation.horizontal;
    final zoneNames = widget.config.tapOrientation.zoneNamesFR;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;

        if (isHorizontal) {
          // Horizontal layout: 3 horizontal bands (top, middle, bottom)
          final zoneHeight = height / 3;

          return Stack(
            children: [
              // Zone 1 (top)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: zoneHeight,
                child: _buildTapZone(1, zoneNames[0], testMode),
              ),

              // Zone 2 (middle)
              Positioned(
                top: zoneHeight,
                left: 0,
                right: 0,
                height: zoneHeight,
                child: _buildTapZone(2, zoneNames[1], testMode),
              ),

              // Zone 3 (bottom)
              Positioned(
                top: zoneHeight * 2,
                left: 0,
                right: 0,
                height: zoneHeight,
                child: _buildTapZone(3, zoneNames[2], testMode),
              ),

              // Grid lines in test mode
              if (testMode) ...[
                Positioned(
                  top: zoneHeight,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 1,
                    color: Colors.white.withOpacity(0.2),
                  ),
                ),
                Positioned(
                  top: zoneHeight * 2,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 1,
                    color: Colors.white.withOpacity(0.2),
                  ),
                ),
              ],
            ],
          );
        } else {
          // Vertical layout: 3 vertical bands (left, center, right)
          final zoneWidth = width / 3;

          return Stack(
            children: [
              // Zone 1 (left)
              Positioned(
                top: 0,
                left: 0,
                bottom: 0,
                width: zoneWidth,
                child: _buildTapZone(1, zoneNames[0], testMode),
              ),

              // Zone 2 (center)
              Positioned(
                top: 0,
                left: zoneWidth,
                bottom: 0,
                width: zoneWidth,
                child: _buildTapZone(2, zoneNames[1], testMode),
              ),

              // Zone 3 (right)
              Positioned(
                top: 0,
                left: zoneWidth * 2,
                bottom: 0,
                width: zoneWidth,
                child: _buildTapZone(3, zoneNames[2], testMode),
              ),

              // Grid lines in test mode
              if (testMode) ...[
                Positioned(
                  top: 0,
                  left: zoneWidth,
                  bottom: 0,
                  child: Container(
                    width: 1,
                    color: Colors.white.withOpacity(0.2),
                  ),
                ),
                Positioned(
                  top: 0,
                  left: zoneWidth * 2,
                  bottom: 0,
                  child: Container(
                    width: 1,
                    color: Colors.white.withOpacity(0.2),
                  ),
                ),
              ],
            ],
          );
        }
      },
    );
  }

  Widget _buildTapZone(int zone, String zoneName, bool testMode) {
    return GestureDetector(
      onTap: () => _handleTapZone(zone),
      child: Container(
        color: Colors.black,
        child: testMode
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$zone',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.55),
                        fontSize: 32,
                        fontWeight: FontWeight.w300,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      zoneName,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.4),
                        fontSize: 13,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              )
            : null,
      ),
    );
  }

  /// Minimal test-mode overlay: a single top line showing the current state.
  /// During capture the captured inputs are listed (`[2, _, _]`), once the
  /// state machine deduces the third input the slots are shown (`[2, 3, 1]`)
  /// and they update live as the spectator swaps. The rest of the screen
  /// stays free for the input gestures.
  Widget _buildTestModeOverlay() {
    final state = _controller.state;
    final phase = _controller.phase;

    String stateLine;
    if (phase == FreeWillPhaseState.capturing) {
      final captured = state.capturedInputs.map((i) => i.value.toString()).toList();
      while (captured.length < 3) captured.add('_');
      stateLine = '[ ${captured.join('  ')} ]';
    } else {
      stateLine = '[ ${state.slots.join('  ')} ]';
    }
    final phaseColor = _getPhaseColor(phase);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        child: Center(
          child: Text(
            stateLine,
            style: TextStyle(
              color: phaseColor.withOpacity(0.85),
              fontSize: 24,
              fontFamily: 'monospace',
              fontWeight: FontWeight.w600,
              letterSpacing: 2,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentStatePanel(FreeWillInputState state, FreeWillPhaseState phase) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _getPhaseColor(phase).withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _getPhaseColor(phase).withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _buildStateItem('Captured', state.capturedInputs.map((i) => i.value).join(', '), Colors.cyan)),
              Expanded(child: _buildStateItem('Deduced', state.deducedInput?.value.toString() ?? '-', Colors.green)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _buildStateItem('Slots', state.slots.join(' | '), Colors.yellow)),
              Expanded(child: _buildStateItem('Swaps', state.swapCount.toString(), Colors.purple)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStateItem(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 10,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value.isEmpty ? '-' : value,
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Color _getPhaseColor(FreeWillPhaseState phase) {
    switch (phase) {
      case FreeWillPhaseState.capturing:
        return Colors.cyan;
      case FreeWillPhaseState.swapping:
        return Colors.yellow;
      case FreeWillPhaseState.locked:
        return Colors.orange;
      case FreeWillPhaseState.revealed:
        return Colors.green;
    }
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
