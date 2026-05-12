import 'dart:async';
import 'package:flutter/services.dart';
import '../models/stealth_input_method.dart';
import 'free_will_input_state.dart';
import 'volume_button_listener.dart';

/// Callbacks for Free Will input events
typedef OnInputCaptured = void Function(FreeWillInput input, int captureIndex);
typedef OnDeductionComplete = void Function(FreeWillInput deduced, List<int> initialSlots);
typedef OnSwapPerformed = void Function(FreeWillSwapType swap, List<int> newSlots);
typedef OnLocked = void Function();
typedef OnRevealed = void Function(List<int> finalSlots, int swapCount);

/// Controller for Free Will input handling
///
/// Supports two input methods:
/// - Volume buttons: UP=1, DOWN=2, Double-press=3
/// - Tap zones: Zone1=1, Zone2=2, Zone3=3
///
/// State machine:
/// 1. Capturing: Wait for 2 distinct inputs, deduce the 3rd
/// 2. Swapping: Input 1=swap12, 2=swap13, 3=swap23 (unlimited)
/// 3. Locked: No more inputs
/// 4. Revealed: Final state
///
/// Lock mechanism:
/// - Volume mode: tap screen = LOCK
/// - Tap mode: any volume press = LOCK
///
/// Reveal mechanism:
/// - Volume mode: separate reveal action
/// - Tap mode: tap after lock = REVEAL
class FreeWillInputController {
  /// The state machine
  final FreeWillInputState state;

  /// Volume button listener (for volume mode or lock in tap mode)
  final VolumeButtonListener _volumeListener = VolumeButtonListener();

  /// Callbacks
  final OnInputCaptured? onInputCaptured;
  final OnDeductionComplete? onDeductionComplete;
  final OnSwapPerformed? onSwapPerformed;
  final OnLocked? onLocked;
  final OnRevealed? onRevealed;

  /// Whether haptic feedback is enabled
  final bool hapticFeedback;

  /// If true, the swap phase stays open after the last input so the spectator
  /// can change their mind; the performer must then tap to lock+reveal.
  /// If false, the reveal is triggered immediately on the last input.
  final bool suggestChangeOfMind;

  // ─────────────────────────────────────────────────────────────────
  // Double-press / long-press detection for Volume mode
  // ─────────────────────────────────────────────────────────────────
  Timer? _doublePressTimer;
  Timer? _input3PendingTimer;
  VolumeDirection? _lastVolumeDirection;
  DateTime? _lastVolumeTime;
  // Window to wait for a potential 2nd press of the same direction
  // (a "double press" = Input 3). Native iOS volume observer has ~110 ms
  // debounce between presses, so anything under 500 ms makes Input 3
  // unreliable for humans. 600 ms keeps the UI responsive while being
  // forgiving on timing.
  static const Duration _doublePressWindow = Duration(milliseconds: 600);
  // After the 2nd press, briefly wait for a 3rd same-direction press before
  // committing Input 3. A 3rd press in this window triggers a long-press
  // LOCK (lock + reveal) — mirrors the screen-tap behaviour so the spectator
  // can commit without touching the screen. Kept short so Input 3 still
  // feels snappy.
  static const Duration _longPressFollowUpWindow = Duration(milliseconds: 280);

  // Volume stream subscription
  StreamSubscription<VolumeDirection>? _volumeSubscription;

  // Track if we're actively listening
  bool _isListening = false;

  FreeWillInputController({
    required FreeWillInputMethod inputMethod,
    this.onInputCaptured,
    this.onDeductionComplete,
    this.onSwapPerformed,
    this.onLocked,
    this.onRevealed,
    this.hapticFeedback = true,
    this.suggestChangeOfMind = false,
  }) : state = FreeWillInputState(inputMethod: inputMethod);

  /// Get the input method
  FreeWillInputMethod get inputMethod => state.inputMethod;

  /// Get current phase
  FreeWillPhaseState get phase => state.phase;

  /// Check if locked
  bool get isLocked => state.phase == FreeWillPhaseState.locked;

  /// Check if revealed
  bool get isRevealed => state.phase == FreeWillPhaseState.revealed;

  // ─────────────────────────────────────────────────────────────────
  // START / STOP
  // ─────────────────────────────────────────────────────────────────

  /// Start listening for inputs
  Future<bool> startListening() async {
    if (_isListening) return true;

    // Always start volume listener (for inputs in volume mode, or lock in tap/swipe mode)
    final started = await _volumeListener.startListening();
    if (!started) {
      // Volume buttons not available, but we can still use tap/swipe mode
      if (inputMethod == FreeWillInputMethod.volume) {
        return false;
      }
    }

    _volumeSubscription = _volumeListener.onVolumeButtonPressed.listen(_handleVolumePress);
    _isListening = true;
    return true;
  }

  /// Stop listening for inputs
  Future<void> stopListening() async {
    _isListening = false;
    _volumeSubscription?.cancel();
    _volumeSubscription = null;
    await _volumeListener.stopListening();
    _cancelDoublePressTimer();
  }

  // ─────────────────────────────────────────────────────────────────
  // VOLUME INPUT HANDLING
  // ─────────────────────────────────────────────────────────────────

  /// Public entry used by remote-key listeners to feed a volume press
  /// from a Bluetooth remote (in addition to the hardware volume
  /// subscription that's already active).
  void handleVolumePress(VolumeDirection direction) => _handleVolumePress(direction);

  void _handleVolumePress(VolumeDirection direction) {
    // In TAP or SWIPE mode, the volume button is the "commit" action: it
    // locks AND reveals in one press, which immediately fires the
    // onRevealed callback → completeFreeWill → auto-copy + shortcut.
    // No extra tap needed afterwards.
    if (inputMethod == FreeWillInputMethod.tap || inputMethod == FreeWillInputMethod.swipe) {
      if (state.phase == FreeWillPhaseState.swapping) {
        _performLock();
        _performReveal();
      } else if (state.phase == FreeWillPhaseState.locked) {
        // Defensive: if somehow lock fired without reveal (e.g. from an
        // earlier code path), volume still reveals.
        _performReveal();
      }
      return;
    }

    // In VOLUME mode, process the input
    _processVolumeInput(direction);
  }

  void _processVolumeInput(VolumeDirection direction) {
    final now = DateTime.now();

    // 3rd same-direction press while Input 3 was pending → LONG PRESS = lock.
    if (_input3PendingTimer != null && _lastVolumeDirection == direction) {
      _cancelDoublePressTimer();
      _lastVolumeDirection = null;
      _lastVolumeTime = null;
      _performVolumeLongPressLock();
      return;
    }

    // Different direction while Input 3 was pending → commit Input 3 first,
    // then process the new press fresh.
    if (_input3PendingTimer != null && _lastVolumeDirection != direction) {
      _input3PendingTimer?.cancel();
      _input3PendingTimer = null;
      _lastVolumeDirection = null;
      _lastVolumeTime = null;
      _handleFreeWillInput(FreeWillInput.input3);
      // Fall through to handle the new press as a fresh first press.
    }

    // 2nd same-direction press inside the double-press window. Don't fire
    // Input 3 immediately — arm a short follow-up window so a 3rd press in
    // the same direction can upgrade the gesture to a long-press lock.
    if (_lastVolumeDirection == direction &&
        _lastVolumeTime != null &&
        now.difference(_lastVolumeTime!) < _doublePressWindow) {
      _doublePressTimer?.cancel();
      _doublePressTimer = null;
      _lastVolumeTime = now;
      _input3PendingTimer?.cancel();
      _input3PendingTimer = Timer(_longPressFollowUpWindow, () {
        _input3PendingTimer = null;
        _lastVolumeDirection = null;
        _lastVolumeTime = null;
        _handleFreeWillInput(FreeWillInput.input3);
      });
      return;
    }

    // First press or different direction - start double-press detection
    _cancelDoublePressTimer();
    _lastVolumeDirection = direction;
    _lastVolumeTime = now;

    // Wait for potential second press
    _doublePressTimer = Timer(_doublePressWindow, () {
      // No double-press, commit single press
      final input = direction == VolumeDirection.up
          ? FreeWillInput.input1
          : FreeWillInput.input2;
      _lastVolumeDirection = null;
      _lastVolumeTime = null;
      _handleFreeWillInput(input);
    });
  }

  /// Long-press volume in Free Will VOLUME mode: same effect as a screen tap
  /// — lock + reveal in one go (or just reveal if already locked).
  void _performVolumeLongPressLock() {
    if (inputMethod != FreeWillInputMethod.volume) return;
    if (state.phase == FreeWillPhaseState.swapping) {
      _performLock();
      _performReveal();
    } else if (state.phase == FreeWillPhaseState.locked) {
      _performReveal();
    }
  }

  void _cancelDoublePressTimer() {
    _doublePressTimer?.cancel();
    _doublePressTimer = null;
    _input3PendingTimer?.cancel();
    _input3PendingTimer = null;
  }

  // ─────────────────────────────────────────────────────────────────
  // TAP INPUT HANDLING (called from UI)
  // ─────────────────────────────────────────────────────────────────

  /// Handle a tap on zone 1 (input 1)
  void handleTapZone1() {
    if (inputMethod != FreeWillInputMethod.tap) return;
    _handleTapInput(FreeWillInput.input1);
  }

  /// Handle a tap on zone 2 (input 2)
  void handleTapZone2() {
    if (inputMethod != FreeWillInputMethod.tap) return;
    _handleTapInput(FreeWillInput.input2);
  }

  /// Handle a tap on zone 3 (input 3)
  void handleTapZone3() {
    if (inputMethod != FreeWillInputMethod.tap) return;
    _handleTapInput(FreeWillInput.input3);
  }

  /// Handle a swipe selection (index 0, 1, 2 → input 1, 2, 3)
  void handleSwipeSelection(int index) {
    if (inputMethod != FreeWillInputMethod.swipe) return;
    final input = [FreeWillInput.input1, FreeWillInput.input2, FreeWillInput.input3][index.clamp(0, 2)];
    _handleTapInput(input); // Same logic as tap
  }

  /// Lock + reveal from swipe mode. The dedicated "lock direction" swipe is
  /// the spectator's commit gesture: it locks the state AND fires reveal in
  /// one go, so the auto-copy + shortcut chain runs immediately (matches the
  /// volume-button behaviour in tap/swipe modes — see `_handleVolumePress`).
  void handleSwipeLock() {
    if (inputMethod != FreeWillInputMethod.swipe) return;
    if (state.phase == FreeWillPhaseState.swapping) {
      _performLock();
      _performReveal();
    } else if (state.phase == FreeWillPhaseState.locked) {
      // Defensive: if somehow lock was set without reveal, this finishes it.
      _performReveal();
    }
  }

  /// Handle any tap (for reveal after lock in tap/swipe mode)
  void handleAnyTap() {
    if (inputMethod != FreeWillInputMethod.tap && inputMethod != FreeWillInputMethod.swipe) return;

    // Tap after lock = REVEAL
    if (state.phase == FreeWillPhaseState.locked) {
      _performReveal();
    }
  }

  void _handleTapInput(FreeWillInput input) {
    // Only process if in capturing or swapping phase
    if (state.phase == FreeWillPhaseState.capturing ||
        state.phase == FreeWillPhaseState.swapping) {
      _handleFreeWillInput(input);
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // SCREEN TAP FOR VOLUME MODE (LOCK)
  // ─────────────────────────────────────────────────────────────────

  /// Handle screen tap (lock + reveal in one action, volume mode)
  void handleScreenTap() {
    if (inputMethod != FreeWillInputMethod.volume) return;

    // Volume mode: tap screen = LOCK immediately followed by REVEAL.
    if (state.phase == FreeWillPhaseState.swapping) {
      _performLock();
      _performReveal();
    } else if (state.phase == FreeWillPhaseState.locked) {
      _performReveal();
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // CORE INPUT HANDLING
  // ─────────────────────────────────────────────────────────────────

  void _handleFreeWillInput(FreeWillInput input) {
    final previousPhase = state.phase;
    final result = state.handleInput(input);

    switch (result) {
      case FreeWillInputResult.captured:
        onInputCaptured?.call(input, state.capturedInputs.length);
        break;

      case FreeWillInputResult.capturedAndTransitioned:
        onInputCaptured?.call(input, state.capturedInputs.length);
        onDeductionComplete?.call(state.deducedInput!, state.slots);
        // Auto-lock + auto-reveal on the last input ONLY when the preset
        // does not offer a change-of-mind phase. When it does, the swap
        // phase stays open and the performer taps the screen to lock+reveal
        // (see `handleScreenTap`).
        if (!suggestChangeOfMind) {
          _performLock();
          _performReveal();
        }
        break;

      case FreeWillInputResult.swapped:
        final swapType = FreeWillSwapType.fromInput(input);
        if (hapticFeedback) {
          HapticFeedback.lightImpact();
        }
        onSwapPerformed?.call(swapType, state.slots);
        break;

      case FreeWillInputResult.duplicateIgnored:
        if (hapticFeedback) {
          HapticFeedback.vibrate();
        }
        break;

      case FreeWillInputResult.ignored:
        break;
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // LOCK / REVEAL
  // ─────────────────────────────────────────────────────────────────

  void _performLock() {
    if (state.lock()) {
      if (hapticFeedback) {
        HapticFeedback.mediumImpact();
      }
      onLocked?.call();
    }
  }

  void _performReveal() {
    if (state.reveal()) {
      if (hapticFeedback) {
        HapticFeedback.heavyImpact();
      }
      onRevealed?.call(state.slots, state.swapCount);
    }
  }

  /// Manually trigger reveal (for volume mode or UI button)
  void triggerReveal() {
    _performReveal();
  }

  /// Manually trigger lock (for UI button if needed)
  void triggerLock() {
    _performLock();
  }

  // ─────────────────────────────────────────────────────────────────
  // RESET / DISPOSE
  // ─────────────────────────────────────────────────────────────────

  /// Reset the state machine
  void reset() {
    state.reset();
    _cancelDoublePressTimer();
    _lastVolumeDirection = null;
    _lastVolumeTime = null;
  }

  /// Dispose of resources
  void dispose() {
    stopListening();
    _volumeListener.dispose();
  }
}
