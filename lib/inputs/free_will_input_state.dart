/// Free Will Input State Machine
///
/// States:
/// - capturing: waiting for 2 distinct inputs (1, 2, or 3)
/// - swapping: unlimited swaps allowed (input 1=swap12, 2=swap13, 3=swap23)
/// - locked: no more inputs accepted, ready to reveal
/// - revealed: final state, narrative displayed

import '../models/stealth_input_method.dart';

/// Input values for Free Will (abstract 1/2/3)
enum FreeWillInput {
  input1,
  input2,
  input3;

  int get value {
    switch (this) {
      case FreeWillInput.input1:
        return 1;
      case FreeWillInput.input2:
        return 2;
      case FreeWillInput.input3:
        return 3;
    }
  }

  static FreeWillInput fromValue(int value) {
    switch (value) {
      case 1:
        return FreeWillInput.input1;
      case 2:
        return FreeWillInput.input2;
      case 3:
        return FreeWillInput.input3;
      default:
        throw ArgumentError('Invalid input value: $value');
    }
  }
}

/// Swap types for Free Will.
///
/// Semantic: each value identifies the canonical object that STAYS in place
/// during the swap. The other two objects swap their assigned actions.
///
/// - `keepObj1`: input 1 → object 1 stays, swap objects 2 and 3
/// - `keepObj2`: input 2 → object 2 stays, swap objects 1 and 3
/// - `keepObj3`: input 3 → object 3 stays, swap objects 1 and 2
enum FreeWillSwapType {
  keepObj1,
  keepObj2,
  keepObj3;

  static FreeWillSwapType fromInput(FreeWillInput input) {
    switch (input) {
      case FreeWillInput.input1:
        return FreeWillSwapType.keepObj1;
      case FreeWillInput.input2:
        return FreeWillSwapType.keepObj2;
      case FreeWillInput.input3:
        return FreeWillSwapType.keepObj3;
    }
  }

  /// Canonical 1-based object indices being swapped (the one NOT in the pair stays).
  (int, int) get swappedObjects {
    switch (this) {
      case FreeWillSwapType.keepObj1:
        return (2, 3);
      case FreeWillSwapType.keepObj2:
        return (1, 3);
      case FreeWillSwapType.keepObj3:
        return (1, 2);
    }
  }

  /// Canonical 1-based object index that stays in place.
  int get keptObject {
    switch (this) {
      case FreeWillSwapType.keepObj1:
        return 1;
      case FreeWillSwapType.keepObj2:
        return 2;
      case FreeWillSwapType.keepObj3:
        return 3;
    }
  }
}

/// State of the Free Will input machine
enum FreeWillPhaseState {
  /// Waiting for 2 distinct inputs
  capturing,
  /// Accepting unlimited swaps
  swapping,
  /// Locked, ready to reveal
  locked,
  /// Final state, revealed
  revealed,
}

/// The Free Will input state machine
class FreeWillInputState {
  /// Current phase
  FreeWillPhaseState _phase = FreeWillPhaseState.capturing;

  /// Captured inputs (max 2)
  final List<FreeWillInput> _capturedInputs = [];

  /// Deduced input (the remaining one after 2 captures)
  FreeWillInput? _deducedInput;

  /// Current slot assignments (index 0,1,2 -> input value 1,2,3)
  /// After capture: slot[0]=inputA, slot[1]=inputB, slot[2]=deduced
  List<int> _slots = [1, 2, 3];

  /// Number of swaps performed
  int _swapCount = 0;

  /// Input method being used
  final FreeWillInputMethod inputMethod;

  FreeWillInputState({
    required this.inputMethod,
  });

  // ─────────────────────────────────────────────────────────────────
  // GETTERS
  // ─────────────────────────────────────────────────────────────────

  FreeWillPhaseState get phase => _phase;
  List<FreeWillInput> get capturedInputs => List.unmodifiable(_capturedInputs);
  FreeWillInput? get deducedInput => _deducedInput;
  List<int> get slots => List.unmodifiable(_slots);
  int get swapCount => _swapCount;
  bool get hasSwapped => _swapCount > 0;

  /// Get the final assignment: which input is in which slot
  /// Returns map: slotIndex (0,1,2) -> inputValue (1,2,3)
  Map<int, int> get finalAssignment {
    return {
      0: _slots[0],
      1: _slots[1],
      2: _slots[2],
    };
  }

  // ─────────────────────────────────────────────────────────────────
  // ACTIONS
  // ─────────────────────────────────────────────────────────────────

  /// Handle an input (1, 2, or 3)
  /// Returns true if the input was accepted
  FreeWillInputResult handleInput(FreeWillInput input) {
    switch (_phase) {
      case FreeWillPhaseState.capturing:
        return _handleCapture(input);
      case FreeWillPhaseState.swapping:
        return _handleSwap(input);
      case FreeWillPhaseState.locked:
      case FreeWillPhaseState.revealed:
        return FreeWillInputResult.ignored;
    }
  }

  FreeWillInputResult _handleCapture(FreeWillInput input) {
    // Don't accept duplicates
    if (_capturedInputs.contains(input)) {
      return FreeWillInputResult.duplicateIgnored;
    }

    _capturedInputs.add(input);

    // If we have 2 inputs, deduce the 3rd and transition to swapping
    if (_capturedInputs.length == 2) {
      _deduceThirdInput();
      _initializeSlots();
      _phase = FreeWillPhaseState.swapping;
      return FreeWillInputResult.capturedAndTransitioned;
    }

    return FreeWillInputResult.captured;
  }

  void _deduceThirdInput() {
    final captured = _capturedInputs.map((i) => i.value).toSet();
    final all = {1, 2, 3};
    final remaining = all.difference(captured);
    _deducedInput = FreeWillInput.fromValue(remaining.first);
  }

  void _initializeSlots() {
    // Initial slot assignment:
    // slot 0 = first captured input
    // slot 1 = second captured input
    // slot 2 = deduced input
    _slots = [
      _capturedInputs[0].value,
      _capturedInputs[1].value,
      _deducedInput!.value,
    ];
  }

  FreeWillInputResult _handleSwap(FreeWillInput input) {
    _applySwap(input);
    _swapCount++;
    return FreeWillInputResult.swapped;
  }

  /// Swap semantics: "input N" keeps the canonical object N (object value N)
  /// in place — i.e. the action assigned to object N stays — and the action
  /// assignments of the other two objects swap.
  ///
  /// In byAction mode (the only supported mode), each slot holds an object
  /// value at a fixed action position. So we find which slot currently holds
  /// value N and swap the other two slot positions.
  void _applySwap(FreeWillInput input) {
    final keepValue = input.value;
    final keepPos = _slots.indexOf(keepValue);
    if (keepPos < 0) return;
    final swapPositions = [0, 1, 2]..removeAt(keepPos);
    final a = swapPositions[0];
    final b = swapPositions[1];
    final temp = _slots[a];
    _slots[a] = _slots[b];
    _slots[b] = temp;
  }

  /// Lock the state (no more inputs accepted)
  bool lock() {
    if (_phase != FreeWillPhaseState.swapping) {
      return false;
    }
    _phase = FreeWillPhaseState.locked;
    return true;
  }

  /// Reveal the final state
  bool reveal() {
    if (_phase != FreeWillPhaseState.locked) {
      return false;
    }
    _phase = FreeWillPhaseState.revealed;
    return true;
  }

  /// Reset the state machine
  void reset() {
    _phase = FreeWillPhaseState.capturing;
    _capturedInputs.clear();
    _deducedInput = null;
    _slots = [1, 2, 3];
    _swapCount = 0;
  }

  @override
  String toString() {
    return 'FreeWillInputState(phase: $_phase, captured: $_capturedInputs, '
        'deduced: $_deducedInput, slots: $_slots, swaps: $_swapCount)';
  }
}

/// Result of handling an input
enum FreeWillInputResult {
  /// Input was captured successfully
  captured,
  /// Input was captured and triggered transition to swapping
  capturedAndTransitioned,
  /// Input was a duplicate and ignored
  duplicateIgnored,
  /// Swap was performed
  swapped,
  /// Input was ignored (wrong phase)
  ignored,
}

