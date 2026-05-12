import 'dart:async';
import 'package:flutter/services.dart';
import '../models/stealth_input_method.dart';
import '../utils/haptic_helper.dart';

/// Callback types for volume input events
typedef OnSelectionCommitted = void Function(int optionIndex);
typedef OnUndoRequested = void Function();
typedef OnResetRequested = void Function();
typedef OnInvalidInput = void Function();

/// Controller for handling volume button input
///
/// Mapping:
/// UP x1   -> option 0
/// DOWN x1 -> option 1
/// UP x2   -> option 2
/// DOWN x2 -> option 3
/// UP x3   -> option 4
/// DOWN x3 -> option 5
///
/// Undo: 3 rapid presses in same direction within 700ms
/// Reset: Two consecutive undos with no selection in between
class VolumeInputController {
  /// Number of options available (max 6)
  final int optionsCount;

  /// Whether haptic feedback is enabled
  final bool hapticFeedback;

  /// Haptic intensity for confirmation pulses
  final HapticIntensity hapticIntensity;

  /// Callbacks
  final OnSelectionCommitted? onSelectionCommitted;
  final OnUndoRequested? onUndoRequested;
  final OnResetRequested? onResetRequested;
  final OnInvalidInput? onInvalidInput;

  // Internal state
  VolumeDirection? _currentDirection;
  int _tapCount = 0;
  Timer? _commitTimer;

  // Undo detection state
  int _rapidPressCount = 0;
  Timer? _rapidPressTimer;
  VolumeDirection? _rapidPressDirection;

  // Reset detection state
  bool _undoArmed = false;

  // Timing constants
  static const Duration _commitDelay = Duration(milliseconds: 550);
  static const Duration _rapidPressWindow = Duration(milliseconds: 700);

  /// Rapid-press threshold for undo. When the preset has ≥ 5 options, 3 taps
  /// is a valid selection (triple-tap = Option 5 or 6), so the undo gesture
  /// must use more presses to avoid conflicting with it. We use 4 in that
  /// case; 3 when options count allows it.
  int get _rapidPressThreshold => optionsCount >= 5 ? 4 : 3;

  VolumeInputController({
    required this.optionsCount,
    this.hapticFeedback = true,
    this.hapticIntensity = HapticIntensity.medium,
    this.onSelectionCommitted,
    this.onUndoRequested,
    this.onResetRequested,
    this.onInvalidInput,
  }) : assert(optionsCount >= 2 && optionsCount <= 6);

  /// Handle a volume button press event
  void handleVolumePress(VolumeDirection direction) {
    // Check for rapid press (potential undo)
    _handleRapidPressDetection(direction);

    // Handle normal selection input
    _handleSelectionInput(direction);
  }

  void _handleRapidPressDetection(VolumeDirection direction) {
    if (_rapidPressDirection == direction) {
      _rapidPressCount++;
      _rapidPressTimer?.cancel();

      if (_rapidPressCount >= _rapidPressThreshold) {
        // Rapid press detected - trigger undo
        _triggerUndo();
        _resetRapidPressState();
        return;
      }

      _rapidPressTimer = Timer(_rapidPressWindow, () {
        _resetRapidPressState();
      });
    } else {
      // Direction changed, reset rapid press detection
      _resetRapidPressState();
      _rapidPressDirection = direction;
      _rapidPressCount = 1;
      _rapidPressTimer = Timer(_rapidPressWindow, () {
        _resetRapidPressState();
      });
    }
  }

  void _resetRapidPressState() {
    _rapidPressCount = 0;
    _rapidPressTimer?.cancel();
    _rapidPressTimer = null;
    _rapidPressDirection = null;
  }

  void _handleSelectionInput(VolumeDirection direction) {
    if (_currentDirection == direction) {
      // Same direction, increment tap count
      _tapCount++;
    } else {
      // Different direction, start new gesture
      _currentDirection = direction;
      _tapCount = 1;
    }

    // Reset/restart commit timer
    _commitTimer?.cancel();
    _commitTimer = Timer(_commitDelay, () {
      _commitSelection();
    });
  }

  void _commitSelection() {
    if (_currentDirection == null || _tapCount == 0) return;

    final gesture = VolumeGesture(
      direction: _currentDirection!,
      tapCount: _tapCount,
    );

    final optionIndex = gesture.toOptionIndex(optionsCount);

    // Reset selection state
    _currentDirection = null;
    _tapCount = 0;

    if (optionIndex == null) {
      // Invalid selection
      _triggerInvalidInput();
      return;
    }

    // Valid selection - clear undo armed state
    _undoArmed = false;

    // Trigger confirmation haptic pattern
    if (hapticFeedback) {
      HapticHelper.confirmOption(optionIndex, intensity: hapticIntensity);
    }

    onSelectionCommitted?.call(optionIndex);
  }

  void _triggerUndo() {
    // Cancel any pending selection
    _commitTimer?.cancel();
    _currentDirection = null;
    _tapCount = 0;

    if (_undoArmed) {
      // Second consecutive undo -> Reset
      _undoArmed = false;
      if (hapticFeedback) {
        HapticFeedback.heavyImpact();
      }
      onResetRequested?.call();
    } else {
      // First undo
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

  /// Clear the undo armed state (called after a valid selection)
  void clearUndoArmed() {
    _undoArmed = false;
  }

  /// Get the current undo armed state
  bool get isUndoArmed => _undoArmed;

  /// Dispose of timers
  void dispose() {
    _commitTimer?.cancel();
    _rapidPressTimer?.cancel();
  }

  /// Get the gesture description for a given option index (for help/reference)
  static String getGestureDescription(int optionIndex, {bool french = false}) {
    final gesture = VolumeGesture.fromOptionIndex(optionIndex);
    if (gesture == null) return '';

    final directionStr = gesture.direction == VolumeDirection.up
        ? (french ? 'HAUT' : 'UP')
        : (french ? 'BAS' : 'DOWN');

    return '$directionStr x${gesture.tapCount}';
  }
}
