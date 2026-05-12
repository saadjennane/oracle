import 'dart:async';
import 'package:flutter/services.dart';
import '../utils/haptic_helper.dart';

/// Direction of a swipe gesture
enum SwipeDirection { up, down, left, right }

/// Callback types
typedef OnClockSelectionCommitted = void Function(int index);
typedef OnClockUndoRequested = void Function();
typedef OnClockResetRequested = void Function();
typedef OnClockInvalidInput = void Function();

/// Controller for ClockSwipe input method.
///
/// Two consecutive swipes select a clock position (0-11):
///   UP+UP=0,    UP+RIGHT=1,    UP+LEFT=11
///   RIGHT+UP=2, RIGHT+RIGHT=3, RIGHT+DOWN=4
///   DOWN+RIGHT=5, DOWN+DOWN=6, DOWN+LEFT=7
///   LEFT+DOWN=8,  LEFT+LEFT=9, LEFT+UP=10
class ClockSwipeInputController {
  final int maxTexts;
  final bool hapticFeedback;
  final HapticIntensity hapticIntensity;

  final OnClockSelectionCommitted? onSelectionCommitted;
  final OnClockUndoRequested? onUndoRequested;
  final OnClockResetRequested? onResetRequested;
  final OnClockInvalidInput? onInvalidInput;

  // State
  SwipeDirection? _firstSwipe;
  Timer? _timeoutTimer;
  bool _undoArmed = false;

  // Rapid swipe detection for undo
  int _rapidSwipeCount = 0;
  Timer? _rapidSwipeTimer;
  SwipeDirection? _rapidSwipeDirection;

  static const Duration _swipeTimeout = Duration(milliseconds: 1500);
  static const Duration _rapidSwipeWindow = Duration(milliseconds: 700);
  static const int _rapidSwipeThreshold = 3;

  /// Clock position mapping: (first, second) -> index 0-11
  static const Map<(SwipeDirection, SwipeDirection), int> _clockMap = {
    // Clock positions: 1=HD, 2=DH, 3=DD, ..., 12=HH
    (SwipeDirection.up, SwipeDirection.right): 0,     // 1h  - HD
    (SwipeDirection.right, SwipeDirection.up): 1,     // 2h  - DH
    (SwipeDirection.right, SwipeDirection.right): 2,  // 3h  - DD
    (SwipeDirection.right, SwipeDirection.down): 3,   // 4h  - DB
    (SwipeDirection.down, SwipeDirection.right): 4,   // 5h  - BD
    (SwipeDirection.down, SwipeDirection.down): 5,    // 6h  - BB
    (SwipeDirection.down, SwipeDirection.left): 6,    // 7h  - BG
    (SwipeDirection.left, SwipeDirection.down): 7,    // 8h  - GB
    (SwipeDirection.left, SwipeDirection.left): 8,    // 9h  - GG
    (SwipeDirection.left, SwipeDirection.up): 9,      // 10h - GH
    (SwipeDirection.up, SwipeDirection.left): 10,     // 11h - HG
    (SwipeDirection.up, SwipeDirection.up): 11,       // 12h - HH
    // Cross positions: 13-16
    (SwipeDirection.up, SwipeDirection.down): 12,     // 13  - HB
    (SwipeDirection.right, SwipeDirection.left): 13,  // 14  - DG
    (SwipeDirection.down, SwipeDirection.up): 14,     // 15  - BH
    (SwipeDirection.left, SwipeDirection.right): 15,  // 16  - GD
  };

  ClockSwipeInputController({
    required this.maxTexts,
    this.hapticFeedback = true,
    this.hapticIntensity = HapticIntensity.medium,
    this.onSelectionCommitted,
    this.onUndoRequested,
    this.onResetRequested,
    this.onInvalidInput,
  });

  /// Whether we are waiting for the second swipe
  bool get isWaitingForSecondSwipe => _firstSwipe != null;

  /// Handle a swipe gesture
  void handleSwipe(SwipeDirection direction) {
    // Check for rapid swipe (undo)
    _handleRapidSwipeDetection(direction);

    if (_firstSwipe == null) {
      // First swipe
      _firstSwipe = direction;
      _timeoutTimer?.cancel();
      _timeoutTimer = Timer(_swipeTimeout, _onTimeout);

      if (hapticFeedback) {
        HapticFeedback.lightImpact();
      }
    } else {
      // Second swipe — compute clock index
      _timeoutTimer?.cancel();

      final index = _clockMap[(_firstSwipe!, direction)];
      _firstSwipe = null;

      if (index == null || index >= maxTexts) {
        _triggerInvalidInput();
        return;
      }

      // Valid selection
      _undoArmed = false;
      if (hapticFeedback) {
        HapticHelper.confirmOption(index, intensity: hapticIntensity);
      }
      onSelectionCommitted?.call(index);
    }
  }

  void _handleRapidSwipeDetection(SwipeDirection direction) {
    if (_rapidSwipeDirection == direction) {
      _rapidSwipeCount++;
      _rapidSwipeTimer?.cancel();

      if (_rapidSwipeCount >= _rapidSwipeThreshold) {
        _triggerUndo();
        _resetRapidSwipeState();
        _firstSwipe = null;
        _timeoutTimer?.cancel();
        return;
      }

      _rapidSwipeTimer = Timer(_rapidSwipeWindow, _resetRapidSwipeState);
    } else {
      _resetRapidSwipeState();
      _rapidSwipeDirection = direction;
      _rapidSwipeCount = 1;
      _rapidSwipeTimer = Timer(_rapidSwipeWindow, _resetRapidSwipeState);
    }
  }

  void _resetRapidSwipeState() {
    _rapidSwipeCount = 0;
    _rapidSwipeTimer?.cancel();
    _rapidSwipeTimer = null;
    _rapidSwipeDirection = null;
  }

  void _onTimeout() {
    // First swipe expired without second
    _firstSwipe = null;
    if (hapticFeedback) {
      HapticFeedback.vibrate();
    }
  }

  void _triggerUndo() {
    _timeoutTimer?.cancel();
    _firstSwipe = null;

    if (_undoArmed) {
      _undoArmed = false;
      if (hapticFeedback) {
        HapticFeedback.heavyImpact();
      }
      onResetRequested?.call();
    } else {
      _undoArmed = true;
      if (hapticFeedback) {
        HapticFeedback.lightImpact();
      }
      onUndoRequested?.call();
    }
  }

  void _triggerInvalidInput() {
    if (hapticFeedback) {
      HapticFeedback.vibrate();
    }
    onInvalidInput?.call();
  }

  /// Get a human-readable description of a clock swipe gesture for a given index
  static String getGestureDescription(int index, {bool french = false}) {
    final entry = _clockMap.entries.where((e) => e.value == index).firstOrNull;
    if (entry == null) return '';

    String dirName(SwipeDirection d) {
      switch (d) {
        case SwipeDirection.up:
          return french ? '↑' : '↑';
        case SwipeDirection.down:
          return french ? '↓' : '↓';
        case SwipeDirection.left:
          return french ? '←' : '←';
        case SwipeDirection.right:
          return french ? '→' : '→';
      }
    }

    return '${dirName(entry.key.$1)} ${dirName(entry.key.$2)}';
  }

  void dispose() {
    _timeoutTimer?.cancel();
    _rapidSwipeTimer?.cancel();
  }
}
