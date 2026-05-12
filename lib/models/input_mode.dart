enum InputMode {
  preprogrammed, // Mode A: Performer pre-enters sequence
  twoInputs; // Mode B: Both inputs each round

  String get displayName {
    switch (this) {
      case InputMode.preprogrammed:
        return 'Preprogrammed';
      case InputMode.twoInputs:
        return 'Two Inputs';
    }
  }

  String get description {
    switch (this) {
      case InputMode.preprogrammed:
        return 'Pre-enter your sequence, app only collects spectator choices';
      case InputMode.twoInputs:
        return 'Input both spectator and performer choices each round';
    }
  }

  static InputMode fromString(String value) {
    switch (value) {
      case 'preprogrammed':
        return InputMode.preprogrammed;
      case 'twoInputs':
        return InputMode.twoInputs;
      default:
        return InputMode.preprogrammed;
    }
  }
}
