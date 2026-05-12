import 'package:flutter/services.dart';
import 'tap_layout.dart';
import '../../utils/haptic_helper.dart';

/// Callback types for tap input events
typedef OnTapCommit = void Function(int optionIndex);
typedef OnTapUndo = void Function();
typedef OnTapReset = void Function();
typedef OnTapInvalid = void Function();

/// Controller for tap zone input handling
/// Manages commit, undo, reset logic similar to VolumeInputController
class TapInputController {
  final int optionsCount;
  final bool hapticFeedback;
  final HapticIntensity hapticIntensity;
  final OnTapCommit onSelectionCommitted;
  final OnTapUndo onUndoRequested;
  final OnTapReset onResetRequested;
  final OnTapInvalid onInvalidInput;

  /// Tracks if undo is "armed" (first undo done, second triggers reset)
  bool _undoArmed = false;

  TapInputController({
    required this.optionsCount,
    required this.hapticFeedback,
    this.hapticIntensity = HapticIntensity.medium,
    required this.onSelectionCommitted,
    required this.onUndoRequested,
    required this.onResetRequested,
    required this.onInvalidInput,
  });

  /// Handle a tap on a zone
  void handleTap(TapZone zone) {
    // Check if zone is disabled (5 options case)
    if (zone.isDisabled) {
      _triggerInvalid();
      return;
    }

    // Check if option index is valid
    if (zone.optionIndex < 0 || zone.optionIndex >= optionsCount) {
      _triggerInvalid();
      return;
    }

    // Valid tap - commit the selection
    _undoArmed = false; // Reset undo armed state on any valid commit

    if (hapticFeedback) {
      HapticHelper.confirmOption(zone.optionIndex, intensity: hapticIntensity);
    }

    onSelectionCommitted(zone.optionIndex);
  }

  /// Handle undo gesture (two-finger long-press)
  /// First call triggers undo, second consecutive call triggers reset
  void handleUndoGesture() {
    if (_undoArmed) {
      // Second consecutive undo -> reset
      _undoArmed = false;
      if (hapticFeedback) {
        HapticFeedback.heavyImpact();
      }
      onResetRequested();
    } else {
      // First undo
      _undoArmed = true;
      if (hapticFeedback) {
        HapticFeedback.mediumImpact();
      }
      onUndoRequested();
    }
  }

  void _triggerInvalid() {
    if (hapticFeedback) {
      HapticFeedback.vibrate();
    }
    onInvalidInput();
  }

  /// Reset undo armed state (call when a valid commit happens)
  void resetUndoState() {
    _undoArmed = false;
  }

  /// Check if undo is armed (for UI display)
  bool get isUndoArmed => _undoArmed;

  void dispose() {
    // Nothing to dispose for now
  }
}
