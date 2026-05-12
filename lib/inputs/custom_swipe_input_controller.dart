import 'dart:async';
import 'package:flutter/services.dart';
enum SwipeDir { up, down, left, right }

typedef OnSwipeSelectionCommitted = void Function(int index);
typedef OnSwipeUndoRequested = void Function();
typedef OnSwipeResetRequested = void Function();
typedef OnSwipeInvalidInput = void Function();

/// Controller for custom swipe input on Choices presets.
/// Uses configurable patterns instead of fixed clock positions.
class CustomSwipeInputController {
  final List<List<String>> patterns; // e.g. [['up','right'], ['right','up'], ...]
  final bool hapticFeedback;
  /// When true, the "3 rapid same-direction swipes = undo" shortcut is
  /// suppressed. Use for flows where rapid same-direction swipes are
  /// expected (e.g. Free Will swap phase) so legitimate swipes aren't
  /// silently swallowed by the undo trigger.
  final bool disableRapidUndo;

  final OnSwipeSelectionCommitted? onSelectionCommitted;
  final OnSwipeUndoRequested? onUndoRequested;
  final OnSwipeResetRequested? onResetRequested;
  final OnSwipeInvalidInput? onInvalidInput;

  // State
  List<String> _currentSwipes = [];
  Timer? _timeoutTimer;
  bool _undoArmed = false;

  // Rapid swipe detection for undo
  int _rapidSwipeCount = 0;
  Timer? _rapidSwipeTimer;
  String? _rapidSwipeDirection;

  static const Duration _swipeTimeout = Duration(milliseconds: 1500);
  static const Duration _rapidSwipeWindow = Duration(milliseconds: 700);
  static const int _rapidSwipeThreshold = 3;

  int get swipeLength => patterns.isNotEmpty ? patterns.first.length : 2;

  CustomSwipeInputController({
    required this.patterns,
    this.hapticFeedback = true,
    this.disableRapidUndo = false,
    this.onSelectionCommitted,
    this.onUndoRequested,
    this.onResetRequested,
    this.onInvalidInput,
  });

  bool get isWaitingForMore => _currentSwipes.isNotEmpty && _currentSwipes.length < swipeLength;

  /// Handle a swipe gesture
  void handleSwipe(String direction) {
    // Rapid-swipe undo only if not disabled by the caller.
    if (!disableRapidUndo) {
      _checkRapidSwipe(direction);
      if (_rapidSwipeCount >= _rapidSwipeThreshold) {
        _triggerUndo();
        _resetRapidSwipeState();
        return;
      }
    }

    _timeoutTimer?.cancel();

    _currentSwipes.add(direction);

    if (_currentSwipes.length < swipeLength) {
      // Not complete yet — provide feedback and wait
      if (hapticFeedback) {
        HapticFeedback.lightImpact();
      }
      _timeoutTimer = Timer(_swipeTimeout, _onTimeout);
    } else {
      // Complete — try to match
      final index = _matchPattern(_currentSwipes);
      _currentSwipes = [];

      if (index != null) {
        _undoArmed = false;
        if (hapticFeedback) {
          HapticFeedback.lightImpact();
        }
        onSelectionCommitted?.call(index);
      } else {
        if (hapticFeedback) {
          HapticFeedback.vibrate();
        }
        onInvalidInput?.call();
      }
    }
  }

  int? _matchPattern(List<String> swipes) {
    for (int i = 0; i < patterns.length; i++) {
      if (_listsEqual(swipes, patterns[i])) return i;
    }
    return null;
  }

  bool _listsEqual(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  void _checkRapidSwipe(String direction) {
    if (_rapidSwipeDirection == direction) {
      _rapidSwipeCount++;
      _rapidSwipeTimer?.cancel();
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
    _currentSwipes = [];
    if (hapticFeedback) {
      HapticFeedback.vibrate();
    }
  }

  void _triggerUndo() {
    _timeoutTimer?.cancel();
    _currentSwipes = [];

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

  /// Parse stored pattern strings to lists
  static List<List<String>> parsePatterns(List<String> stored) {
    return stored.map((p) => p.split(',')).toList();
  }

  void dispose() {
    _timeoutTimer?.cancel();
    _rapidSwipeTimer?.cancel();
  }
}
