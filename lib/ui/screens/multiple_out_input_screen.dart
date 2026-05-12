import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../models/models.dart';
import '../../inputs/volume_input_controller.dart';
import '../../inputs/volume_button_listener.dart';
import '../../inputs/clock_swipe_input_controller.dart';
import '../../inputs/audio_input_controller.dart';
import '../../inputs/remote_key_listener.dart';
import '../../utils/game_provider.dart';
import '../../utils/settings_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/chain_progress_indicator.dart';

/// Input screen for Multiple Out presets.
/// Supports volume buttons, clock swipe, and audio input methods.
class MultipleOutInputScreen extends StatefulWidget {
  final Preset preset;
  final void Function(int selectedIndex) onComplete;

  const MultipleOutInputScreen({
    super.key,
    required this.preset,
    required this.onComplete,
  });

  @override
  State<MultipleOutInputScreen> createState() => _MultipleOutInputScreenState();
}

class _MultipleOutInputScreenState extends State<MultipleOutInputScreen> {
  // Volume
  late VolumeButtonListener _volumeListener;
  VolumeInputController? _volumeController;
  StreamSubscription<VolumeDirection>? _volumeSubscription;
  bool _volumeAvailable = false;

  // ClockSwipe
  ClockSwipeInputController? _clockSwipeController;

  // Audio
  AudioInputController? _audioController;
  String _transcript = '';
  bool _isListening = false;

  bool _isInitialized = false;
  String? _debugMessage;
  int? _selectedIndex;
  bool _showingFeedback = false;

  int get _textCount => widget.preset.multipleOutTexts?.length ?? 0;
  bool get _isVolume => widget.preset.stealthInputMethod == StealthInputMethod.volume;
  bool get _isClockSwipe => widget.preset.stealthInputMethod == StealthInputMethod.clockSwipe;
  bool get _isAudio => widget.preset.stealthInputMethod == StealthInputMethod.audio;
  bool get _isTap => widget.preset.stealthInputMethod == StealthInputMethod.tap;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _volumeListener = VolumeButtonListener();
    _initializeInputs();
  }

  Future<void> _initializeInputs() async {
    final settings = context.read<SettingsProvider>();

    if (_isVolume) {
      _volumeController = VolumeInputController(
        optionsCount: _textCount,
        hapticFeedback: settings.hapticFeedback,
        hapticIntensity: settings.hapticIntensity,
        onSelectionCommitted: _onSelectionCommitted,
        onUndoRequested: _onUndo,
        onResetRequested: _onReset,
        onInvalidInput: _onInvalid,
      );

      _volumeAvailable = await _volumeListener.isAvailable();
      if (_volumeAvailable) {
        final started = await _volumeListener.startListening();
        if (started) {
          _volumeSubscription = _volumeListener.onVolumeButtonPressed.listen((direction) {
            _volumeController?.handleVolumePress(direction);
          });
        }
      }
    } else if (_isClockSwipe) {
      _clockSwipeController = ClockSwipeInputController(
        maxTexts: _textCount,
        hapticFeedback: settings.hapticFeedback,
        hapticIntensity: settings.hapticIntensity,
        onSelectionCommitted: _onSelectionCommitted,
        onUndoRequested: _onUndo,
        onResetRequested: _onReset,
        onInvalidInput: _onInvalid,
      );

      // Also listen to volume buttons for potential undo in clock swipe mode
      _volumeAvailable = await _volumeListener.isAvailable();
      if (_volumeAvailable) {
        await _volumeListener.startListening();
      }
    } else if (_isAudio) {
      // Build keyword overrides from preset
      final keywords = widget.preset.multipleOutKeywords;
      final keywordOverrides = <int, List<String>>{};
      if (keywords != null) {
        for (int i = 0; i < keywords.length; i++) {
          final kw = keywords[i].trim();
          if (kw.isNotEmpty) {
            keywordOverrides[i] = kw.split(',').map((k) => k.trim()).where((k) => k.isNotEmpty).toList();
          }
        }
      }

      // Use labels as option names for the controller
      final options = List.generate(_textCount, (i) => 'Text ${i + 1}');
      _audioController = AudioInputController(
        options: options,
        expectedRounds: 1,
        startSentence: widget.preset.audioStartSentence ?? '',
        stopSentence: widget.preset.audioStopSentence ?? '',
        locale: widget.preset.language == Language.french ? 'fr_FR' : 'en_US',
        keywordOverrides: keywordOverrides,
        onChoiceDetected: (optionIndex, matchedWord) {
          _onSelectionCommitted(optionIndex);
        },
        onTranscriptUpdate: (full, last) {
          if (mounted) setState(() => _transcript = full);
        },
        onStateChange: (state) {
          if (mounted) setState(() => _isListening = state == AudioInputState.listening);
        },
      );
      await _audioController!.initialize();

      // Listen to volume buttons for start/stop
      _volumeAvailable = await _volumeListener.isAvailable();
      if (_volumeAvailable) {
        final started = await _volumeListener.startListening();
        if (started) {
          _volumeSubscription = _volumeListener.onVolumeButtonPressed.listen((_) {
            // Toggle listening on any volume press
            if (_audioController?.state == AudioInputState.listening ||
                _audioController?.state == AudioInputState.active) {
              _audioController?.stopListening();
            } else if (_audioController?.state == AudioInputState.idle) {
              _audioController?.startListening();
            }
          });
        }
      }
    }

    if (mounted) {
      setState(() => _isInitialized = true);
    }
  }

  void _onSelectionCommitted(int index) {
    setState(() {
      _selectedIndex = index;
      _debugMessage = 'Selected: ${index + 1}';
      _showingFeedback = true;
    });

    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) {
        setState(() => _showingFeedback = false);
        // Navigate to result
        widget.onComplete(index);
      }
    });
  }

  void _onUndo() {
    setState(() {
      _debugMessage = 'Undo';
      _selectedIndex = null;
    });
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) setState(() => _debugMessage = null);
    });
  }

  void _onReset() {
    setState(() {
      _debugMessage = 'Reset';
      _selectedIndex = null;
    });
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) setState(() => _debugMessage = null);
    });
  }

  void _onInvalid() {
    setState(() => _debugMessage = 'Invalid');
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _debugMessage = null);
    });
  }

  /// Detect swipe direction from pan velocity
  SwipeDirection? _swipeDirectionFromVelocity(Velocity velocity) {
    final dx = velocity.pixelsPerSecond.dx;
    final dy = velocity.pixelsPerSecond.dy;

    // Minimum velocity threshold
    if (dx.abs() < 100 && dy.abs() < 100) return null;

    if (dx.abs() > dy.abs()) {
      return dx > 0 ? SwipeDirection.right : SwipeDirection.left;
    } else {
      return dy > 0 ? SwipeDirection.down : SwipeDirection.up;
    }
  }

  void _confirmExit() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Exit?', style: TextStyle(color: AppTheme.textPrimary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
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
    _volumeController?.dispose();
    _clockSwipeController?.dispose();
    _audioController?.dispose();
    _volumeListener.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final testMode = settings.testModeEnabled;

    if (!_isInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white24)),
      );
    }

    return RemoteKeyListener(
      onVolumeKey: _isVolume ? (dir) => _volumeController?.handleVolumePress(dir) : null,
      onSwipeKey: _isClockSwipe ? (dir) => _clockSwipeController?.handleSwipe(dir) : null,
      child: GestureDetector(
      onLongPress: _confirmExit,
      onPanEnd: _isClockSwipe
          ? (details) {
              final dir = _swipeDirectionFromVelocity(details.velocity);
              if (dir != null) {
                _clockSwipeController?.handleSwipe(dir);
              }
            }
          : null,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            Container(color: Colors.black),

            // Tap mode: invisible tap zones (one per text)
            if (_isTap) _buildTapZones(testMode),

            // Test mode overlay
            if (testMode)
              _buildTestModeOverlay(),

            // Subtle feedback dot (non-test mode)
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

            // Debug message (non-test mode)
            if (_debugMessage != null && !testMode)
              Positioned(
                bottom: 50, left: 0, right: 0,
                child: Center(
                  child: Text(
                    _debugMessage!,
                    style: TextStyle(color: Colors.white.withOpacity(0.15), fontSize: 12),
                  ),
                ),
              ),

            // Chain progress indicator
            Consumer<GameProvider>(
              builder: (_, gp, __) => gp.isChaining
                  ? ChainProgressIndicator(total: gp.chainTotal, currentIndex: gp.chainCurrentIndex)
                  : const SizedBox.shrink(),
            ),

            // Hidden exit button (top-left corner)
            Positioned(
              top: 0, left: 0,
              child: GestureDetector(
                onTap: () {},
                onLongPress: _confirmExit,
                child: Container(width: 60, height: 60, color: Colors.transparent),
              ),
            ),
          ],
        ),
      ),
    ));
  }

  /// Tap zones arranged the same way as the preset-builder mockup.
  /// Layouts: 2 top/bottom · 3 horizontal bands · 4 2x2 corners ·
  /// 5 2x3 grid with 1 disabled (last cell) · 6 2x3 grid.
  /// Counts outside 2..6 are not supported for tap (builder prevents it).
  Widget _buildTapZones(bool testMode) {
    final n = _textCount;
    if (n < 2 || n > 6) return const SizedBox.shrink();

    List<(double x, double y, double w, double h)> rects() {
      // Returns fractions of the screen (x, y, w, h).
      switch (n) {
        case 2:
          return const [(0, 0, 1, 0.5), (0, 0.5, 1, 0.5)];
        case 3:
          return const [
            (0, 0, 1, 1 / 3),
            (0, 1 / 3, 1, 1 / 3),
            (0, 2 / 3, 1, 1 / 3),
          ];
        case 4:
          return const [
            (0, 0, 0.5, 0.5),
            (0.5, 0, 0.5, 0.5),
            (0, 0.5, 0.5, 0.5),
            (0.5, 0.5, 0.5, 0.5),
          ];
        case 5:
          return const [
            (0, 0, 0.5, 1 / 3),
            (0.5, 0, 0.5, 1 / 3),
            (0, 1 / 3, 0.5, 1 / 3),
            (0.5, 1 / 3, 0.5, 1 / 3),
            (0, 2 / 3, 0.5, 1 / 3),
            // 6th cell disabled
          ];
        case 6:
          return const [
            (0, 0, 0.5, 1 / 3),
            (0.5, 0, 0.5, 1 / 3),
            (0, 1 / 3, 0.5, 1 / 3),
            (0.5, 1 / 3, 0.5, 1 / 3),
            (0, 2 / 3, 0.5, 1 / 3),
            (0.5, 2 / 3, 0.5, 1 / 3),
          ];
      }
      return const [];
    }

    final zones = rects();
    final titles = widget.preset.multipleOutTitles;
    String label(int i) {
      final t = (titles != null && i < titles.length) ? titles[i].trim() : '';
      return t.isNotEmpty ? t : 'Text ${i + 1}';
    }

    return LayoutBuilder(builder: (ctx, c) {
      final w = c.maxWidth;
      final h = c.maxHeight;
      return Stack(
        children: [
          for (int i = 0; i < zones.length; i++)
            Positioned(
              left: zones[i].$1 * w,
              top: zones[i].$2 * h,
              width: zones[i].$3 * w,
              height: zones[i].$4 * h,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _volumeController == null
                    ? _onSelectionCommitted(i)
                    : _onSelectionCommitted(i),
                child: testMode
                    ? Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.04),
                          border: Border.all(color: Colors.white24, width: 1),
                        ),
                        child: Center(
                          child: Text(
                            '${i + 1} · ${label(i)}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
        ],
      );
    });
  }

  Widget _buildTestModeOverlay() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // TEST MODE badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange),
              ),
              child: Text(
                'TEST MODE — Multiple Out (${_isVolume ? "Volume" : _isAudio ? "Audio" : _isTap ? "Tap" : "ClockSwipe"})',
                style: const TextStyle(color: Colors.orange, fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 16),

            // Texts count
            Text(
              '$_textCount texts configured',
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),

            // ClockSwipe state
            if (_isClockSwipe && _clockSwipeController != null)
              Text(
                _clockSwipeController!.isWaitingForSecondSwipe
                    ? 'Waiting for 2nd swipe...'
                    : 'Swipe to select',
                style: TextStyle(
                  color: _clockSwipeController!.isWaitingForSecondSwipe
                      ? Colors.yellow
                      : Colors.white70,
                  fontSize: 14,
                ),
              ),

            // Audio state
            if (_isAudio) ...[
              Text(
                _isListening ? 'Listening...' : 'Press volume to start/stop',
                style: TextStyle(
                  color: _isListening ? Colors.green : Colors.white70,
                  fontSize: 14,
                ),
              ),
              if (_transcript.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    _transcript,
                    style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],

            const SizedBox(height: 12),

            // Selection result
            if (_selectedIndex != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.withOpacity(0.5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Selected: Text ${_selectedIndex! + 1}',
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ],
                ),
              ),

            // Debug message
            if (_debugMessage != null && _selectedIndex == null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _debugMessage == 'Invalid'
                      ? Colors.red.withOpacity(0.2)
                      : Colors.blue.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _debugMessage!,
                  style: TextStyle(
                    color: _debugMessage == 'Invalid' ? Colors.red : Colors.blue,
                    fontSize: 14, fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
