import 'dart:async';
import 'package:flutter/services.dart';

/// Controller for swipe-based digit input.
/// Each digit requires 2 swipes mapped to clock positions 0-9.
/// Supports two modes:
/// - Fixed: known digit count per operand (from formula XX pattern)
/// - Free: variable digits, confirmed with →← or ←→
class DigitSwipeController {
  /// Clock position mapping: (first, second) → digit
  static const Map<String, int> _digitMap = {
    'up,right': 1,
    'right,up': 2,
    'right,right': 3,
    'right,down': 4,
    'down,right': 5,
    'down,down': 6,
    'down,left': 7,
    'left,down': 8,
    'left,left': 9,
    'up,down': 0,
  };

  /// Confirm gestures (either direction)
  static const _confirmPatterns = {'right,left', 'left,right'};

  final void Function(int digit) onDigitEntered;
  final void Function(int number) onNumberConfirmed;
  final void Function() onInvalidInput;
  final bool hapticFeedback;

  // State
  String? _firstSwipe;
  Timer? _timeoutTimer;
  List<int> _currentDigits = [];
  int? _expectedDigitCount; // null = free mode

  static const Duration _swipeTimeout = Duration(milliseconds: 1500);

  DigitSwipeController({
    required this.onDigitEntered,
    required this.onNumberConfirmed,
    required this.onInvalidInput,
    this.hapticFeedback = true,
  });

  /// Set expected digit count for current number (null = free mode)
  void setExpectedDigits(int? count) {
    _expectedDigitCount = count;
    _currentDigits = [];
  }

  /// Reset for next number
  void reset() {
    _firstSwipe = null;
    _currentDigits = [];
    _timeoutTimer?.cancel();
  }

  /// Get current accumulated digits as string
  String get currentDigitsString => _currentDigits.join();

  void _haptic(void Function() pulse) {
    if (hapticFeedback) pulse();
  }

  /// Handle a swipe direction
  void handleSwipe(String direction) {
    _timeoutTimer?.cancel();

    if (_firstSwipe == null) {
      _firstSwipe = direction;
      _haptic(HapticFeedback.lightImpact);
      _timeoutTimer = Timer(_swipeTimeout, () {
        _firstSwipe = null;
        _haptic(HapticFeedback.vibrate);
      });
    } else {
      final key = '$_firstSwipe,$direction';
      _firstSwipe = null;

      // Check for confirm gesture
      if (_confirmPatterns.contains(key)) {
        if (_expectedDigitCount == null && _currentDigits.isNotEmpty) {
          final number = int.parse(_currentDigits.join());
          _currentDigits = [];
          _haptic(HapticFeedback.mediumImpact);
          onNumberConfirmed(number);
        } else {
          _haptic(HapticFeedback.vibrate);
          onInvalidInput();
        }
        return;
      }

      // Check for digit
      final digit = _digitMap[key];
      if (digit != null) {
        _currentDigits.add(digit);
        _haptic(HapticFeedback.lightImpact);
        onDigitEntered(digit);

        if (_expectedDigitCount != null && _currentDigits.length >= _expectedDigitCount!) {
          final number = int.parse(_currentDigits.join());
          _currentDigits = [];
          _haptic(HapticFeedback.mediumImpact);
          onNumberConfirmed(number);
        }
      } else {
        _haptic(HapticFeedback.vibrate);
        onInvalidInput();
      }
    }
  }

  /// Get gesture description for a digit
  static String gestureForDigit(int digit) {
    final entry = _digitMap.entries.firstWhere(
      (e) => e.value == digit,
      orElse: () => const MapEntry('?', -1),
    );
    final parts = entry.key.split(',');
    return '${_arrow(parts[0])} ${_arrow(parts[1])}';
  }

  static String _arrow(String dir) {
    switch (dir) {
      case 'up': return '↑';
      case 'down': return '↓';
      case 'left': return '←';
      case 'right': return '→';
      default: return '?';
    }
  }

  void dispose() {
    _timeoutTimer?.cancel();
  }
}
