import '../models/stealth_input_method.dart';
import 'free_will_input_state.dart';

/// Describes how an input event maps to a value (1, 2, or 3)
class InputEventMapping {
  final String eventName;
  final String eventDescription;
  final int value;

  const InputEventMapping({
    required this.eventName,
    required this.eventDescription,
    required this.value,
  });
}

/// Describes how a value maps to a swap type
class SwapMapping {
  final int triggerValue;
  final FreeWillSwapType swapType;
  final String description;

  const SwapMapping({
    required this.triggerValue,
    required this.swapType,
    required this.description,
  });
}

/// Lock/Reveal action description
class LockRevealAction {
  final String action;
  final String description;

  const LockRevealAction({
    required this.action,
    required this.description,
  });
}

/// Complete input mapping for Free Will mode
/// Single source of truth for both input handling and UI display
class FreeWillInputMapping {
  final FreeWillInputMethod method;

  /// Phase 1: Input events to values (1, 2, 3)
  final List<InputEventMapping> choiceMapping;

  /// Phase 2: Values to swap types
  final List<SwapMapping> swapMapping;

  /// Lock action
  final LockRevealAction lockAction;

  /// Post-lock action (reveal)
  final LockRevealAction revealAction;

  /// Rule text for deduction
  final String deductionRule;

  const FreeWillInputMapping({
    required this.method,
    required this.choiceMapping,
    required this.swapMapping,
    required this.lockAction,
    required this.revealAction,
    required this.deductionRule,
  });

  /// Get mapping for Volume mode
  static FreeWillInputMapping volume() {
    return const FreeWillInputMapping(
      method: FreeWillInputMethod.volume,
      choiceMapping: [
        InputEventMapping(
          eventName: 'UP',
          eventDescription: 'Volume Up',
          value: 1,
        ),
        InputEventMapping(
          eventName: 'DOWN',
          eventDescription: 'Volume Down',
          value: 2,
        ),
        InputEventMapping(
          eventName: 'DOUBLE',
          eventDescription: 'Double-press (any)',
          value: 3,
        ),
      ],
      swapMapping: [
        SwapMapping(
          triggerValue: 1,
          swapType: FreeWillSwapType.keepObj1,
          description: 'UP → keep obj 1, swap 2↔3',
        ),
        SwapMapping(
          triggerValue: 2,
          swapType: FreeWillSwapType.keepObj2,
          description: 'DOWN → keep obj 2, swap 1↔3',
        ),
        SwapMapping(
          triggerValue: 3,
          swapType: FreeWillSwapType.keepObj3,
          description: 'DOUBLE → keep obj 3, swap 1↔2',
        ),
      ],
      lockAction: LockRevealAction(
        action: 'TAP SCREEN',
        description: 'Tap anywhere on screen to lock',
      ),
      revealAction: LockRevealAction(
        action: 'REVEAL BUTTON',
        description: 'Press Reveal button to show result',
      ),
      deductionRule: '2 inputs captured → 3rd deduced automatically',
    );
  }

  /// Get mapping for Tap mode
  static FreeWillInputMapping tap() {
    return const FreeWillInputMapping(
      method: FreeWillInputMethod.tap,
      choiceMapping: [
        InputEventMapping(
          eventName: 'ZONE 1',
          eventDescription: 'Top zone',
          value: 1,
        ),
        InputEventMapping(
          eventName: 'ZONE 2',
          eventDescription: 'Middle zone',
          value: 2,
        ),
        InputEventMapping(
          eventName: 'ZONE 3',
          eventDescription: 'Bottom zone',
          value: 3,
        ),
      ],
      swapMapping: [
        SwapMapping(
          triggerValue: 1,
          swapType: FreeWillSwapType.keepObj1,
          description: 'Zone 1 → keep obj 1, swap 2↔3',
        ),
        SwapMapping(
          triggerValue: 2,
          swapType: FreeWillSwapType.keepObj2,
          description: 'Zone 2 → keep obj 2, swap 1↔3',
        ),
        SwapMapping(
          triggerValue: 3,
          swapType: FreeWillSwapType.keepObj3,
          description: 'Zone 3 → keep obj 3, swap 1↔2',
        ),
      ],
      lockAction: LockRevealAction(
        action: 'VOLUME PRESS',
        description: 'Press any volume button to lock',
      ),
      revealAction: LockRevealAction(
        action: 'TAP SCREEN',
        description: 'Tap anywhere after lock to reveal',
      ),
      deductionRule: '2 inputs captured → 3rd deduced automatically',
    );
  }

  /// Get mapping for a specific input method
  static FreeWillInputMapping forMethod(FreeWillInputMethod method) {
    switch (method) {
      case FreeWillInputMethod.volume:
        return volume();
      case FreeWillInputMethod.tap:
      case FreeWillInputMethod.swipe:
      case FreeWillInputMethod.assistant:
      case FreeWillInputMethod.audio:
        return tap();
    }
  }

  /// Get the FreeWillInput for a given value
  static FreeWillInput inputFromValue(int value) {
    return FreeWillInput.fromValue(value);
  }

  /// Get the swap type for a given input
  static FreeWillSwapType swapFromInput(FreeWillInput input) {
    return FreeWillSwapType.fromInput(input);
  }
}
