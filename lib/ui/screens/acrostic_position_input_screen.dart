import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../../inputs/volume_button_listener.dart';
import '../../inputs/volume_input_controller.dart';
import '../../inputs/clock_swipe_input_controller.dart';
import '../../inputs/remote_key_listener.dart';
import '../../models/confabulation_preset.dart';
import '../../models/stealth_input_method.dart';
import '../../services/firebase_service.dart';
import '../../utils/settings_provider.dart';
import '../theme/app_theme.dart';

/// Pre-run screen that captures the acrostic position (1..6) before the
/// performer collects slot selections. Uses the same input method configured
/// on the preset so the experience is consistent with the rest of the routine.
class AcrosticPositionInputScreen extends StatefulWidget {
  final ConfabInputMethod inputMethod;
  final List<int> availablePositions;
  final void Function(int position) onPicked;

  const AcrosticPositionInputScreen({
    super.key,
    required this.inputMethod,
    required this.availablePositions,
    required this.onPicked,
  });

  @override
  State<AcrosticPositionInputScreen> createState() => _AcrosticPositionInputScreenState();
}

class _AcrosticPositionInputScreenState extends State<AcrosticPositionInputScreen> {
  // Volume
  final VolumeButtonListener _volumeListener = VolumeButtonListener();
  StreamSubscription<VolumeDirection>? _volumeSub;
  VolumeInputController? _volumeCtrl;

  // Speech
  stt.SpeechToText? _speech;
  bool _speechListening = false;

  // Assistant polling
  StreamSubscription<Map<String, dynamic>?>? _assistantSub;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _startForMethod();
  }

  Future<void> _startForMethod() async {
    switch (widget.inputMethod) {
      case ConfabInputMethod.volume:
        _volumeCtrl = VolumeInputController(
          optionsCount: 6,
          hapticFeedback: context.read<SettingsProvider>().hapticFeedback,
          onSelectionCommitted: _onPositionCaptured,
        );
        final ok = await _volumeListener.startListening();
        if (!ok) break;
        _volumeSub = _volumeListener.onVolumeButtonPressed.listen((dir) {
          _volumeCtrl?.handleVolumePress(dir);
        });
        break;
      case ConfabInputMethod.audio:
        await _initSpeech();
        break;
      case ConfabInputMethod.assistant:
        _startAssistantPoll();
        break;
      case ConfabInputMethod.tap:
      case ConfabInputMethod.clockSwipe:
        // Handled directly in build via GestureDetector / ClockSwipeInputController
        break;
    }
  }

  Future<void> _initSpeech() async {
    _speech = stt.SpeechToText();
    final available = await _speech!.initialize();
    if (!available || !mounted) return;
    _speechListening = true;
    _speech!.listen(
      onResult: (result) {
        final text = result.recognizedWords.toLowerCase();
        final pos = _parseDigit(text);
        if (pos != null) _onPositionCaptured(pos);
      },
      partialResults: true,
    );
  }

  int? _parseDigit(String text) {
    const digits = {
      '1': 1, 'un': 1, 'one': 1,
      '2': 2, 'deux': 2, 'two': 2,
      '3': 3, 'trois': 3, 'three': 3,
      '4': 4, 'quatre': 4, 'four': 4,
      '5': 5, 'cinq': 5, 'five': 5,
      '6': 6, 'six': 6,
    };
    for (final entry in digits.entries) {
      final re = RegExp(r'\b' + entry.key + r'\b');
      if (re.hasMatch(text) && widget.availablePositions.contains(entry.value)) {
        return entry.value;
      }
    }
    return null;
  }

  void _startAssistantPoll() {
    final settings = context.read<SettingsProvider>();
    // Publish a state instructing the assistant webapp to present a position picker.
    FirebaseService.pushSession(settings.assistantId, {
      'state': 'acrostic_position_pick',
      'availablePositions': widget.availablePositions,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
    _assistantSub = FirebaseService.pollInput(settings.assistantId).listen((input) {
      if (input == null) return;
      if (input['type'] == 'acrostic_position' && input['value'] is int) {
        final v = input['value'] as int;
        if (widget.availablePositions.contains(v)) {
          FirebaseService.clearInput(settings.assistantId);
          _onPositionCaptured(v);
        }
      }
    });
  }

  void _onPositionCaptured(int position) {
    if (!mounted) return;
    if (context.read<SettingsProvider>().hapticFeedback) {
      HapticFeedback.mediumImpact();
    }
    widget.onPicked(position);
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _volumeSub?.cancel();
    _volumeListener.stopListening();
    _volumeCtrl?.dispose();
    if (_speechListening) _speech?.stop();
    _assistantSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final testMode = context.watch<SettingsProvider>().testModeEnabled;

    Widget methodView;
    switch (widget.inputMethod) {
      case ConfabInputMethod.volume:
        methodView = _buildVolumeView(testMode);
        break;
      case ConfabInputMethod.tap:
        methodView = _buildTapGrid(testMode);
        break;
      case ConfabInputMethod.clockSwipe:
        methodView = _buildSwipeView(testMode);
        break;
      case ConfabInputMethod.audio:
        methodView = _buildAudioView(testMode);
        break;
      case ConfabInputMethod.assistant:
        methodView = _buildAssistantWaitView(testMode);
        break;
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: RemoteKeyListener(
        onVolumeKey: widget.inputMethod == ConfabInputMethod.volume
            ? (dir) => _volumeCtrl?.handleVolumePress(dir)
            : null,
        onSwipeKey: widget.inputMethod == ConfabInputMethod.clockSwipe
            ? (dir) => _swipeCtrl?.handleSwipe(dir)
            : null,
        child: Stack(
          children: [
            Positioned.fill(child: methodView),
            // Long-press top-left to cancel
            Positioned(
              top: 0,
              left: 0,
              child: GestureDetector(
                onLongPress: () => Navigator.of(context).pop(),
                child: Container(width: 60, height: 60, color: Colors.transparent),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _testLabel(String text) => Center(
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white30, fontSize: 13, height: 1.4),
        ),
      );

  Widget _buildVolumeView(bool testMode) {
    return Container(
      color: Colors.black,
      child: testMode
          ? _testLabel(
              'ACROSTIC POSITION\nUP ×1=1  DOWN ×1=2\nUP ×2=3  DOWN ×2=4\nUP ×3=5  DOWN ×3=6',
            )
          : null,
    );
  }

  Widget _buildTapGrid(bool testMode) {
    // 2 rows × 3 columns = 6 zones
    return LayoutBuilder(builder: (ctx, c) {
      final w = c.maxWidth / 3;
      final h = c.maxHeight / 2;
      int zoneFor(int row, int col) => row * 3 + col + 1; // 1..6
      return Stack(
        children: [
          for (int r = 0; r < 2; r++)
            for (int col = 0; col < 3; col++)
              Positioned(
                top: r * h,
                left: col * w,
                width: w,
                height: h,
                child: GestureDetector(
                  onTap: () {
                    final z = zoneFor(r, col);
                    if (widget.availablePositions.contains(z)) _onPositionCaptured(z);
                  },
                  child: Container(
                    color: Colors.black,
                    child: testMode
                        ? Center(
                            child: Text(
                              '${zoneFor(r, col)}',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.3),
                                fontSize: 20,
                              ),
                            ),
                          )
                        : null,
                  ),
                ),
              ),
          if (testMode) ...[
            Positioned(top: h, left: 0, right: 0, child: Container(height: 1, color: Colors.white12)),
            Positioned(top: 0, bottom: 0, left: w, child: Container(width: 1, color: Colors.white12)),
            Positioned(top: 0, bottom: 0, left: w * 2, child: Container(width: 1, color: Colors.white12)),
          ],
        ],
      );
    });
  }

  ClockSwipeInputController? _swipeCtrl;

  Widget _buildSwipeView(bool testMode) {
    _swipeCtrl ??= ClockSwipeInputController(
      maxTexts: 6,
      hapticFeedback: context.read<SettingsProvider>().hapticFeedback,
      onSelectionCommitted: (index) {
        // index is 0-based from the controller; map 0..5 to positions 1..6
        final pos = index + 1;
        if (widget.availablePositions.contains(pos)) _onPositionCaptured(pos);
      },
    );
    return GestureDetector(
      onPanEnd: (d) {
        final dx = d.velocity.pixelsPerSecond.dx;
        final dy = d.velocity.pixelsPerSecond.dy;
        if (dx.abs() < 200 && dy.abs() < 200) return;
        SwipeDirection dir;
        if (dx.abs() > dy.abs()) {
          dir = dx > 0 ? SwipeDirection.right : SwipeDirection.left;
        } else {
          dir = dy > 0 ? SwipeDirection.down : SwipeDirection.up;
        }
        _swipeCtrl?.handleSwipe(dir);
      },
      child: Container(
        color: Colors.black,
        child: testMode
            ? _testLabel(
                'ACROSTIC POSITION (SWIPE)\n'
                'UP+RIGHT=1  RIGHT+UP=2  RIGHT+RIGHT=3\n'
                'RIGHT+DOWN=4  DOWN+RIGHT=5  DOWN+DOWN=6',
              )
            : null,
      ),
    );
  }

  Widget _buildAudioView(bool testMode) {
    return Container(
      color: Colors.black,
      child: testMode
          ? _testLabel('ACROSTIC POSITION (AUDIO)\nSay: one / two / three / four / five / six')
          : null,
    );
  }

  Widget _buildAssistantWaitView(bool testMode) {
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Colors.white24, strokeWidth: 2),
            const SizedBox(height: 16),
            Text(
              testMode ? 'Waiting for assistant (acrostic position)…' : 'Waiting…',
              style: TextStyle(color: Colors.white.withOpacity(0.25), fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
