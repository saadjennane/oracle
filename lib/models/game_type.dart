enum GameType {
  binary,
  multiChoice,
  duel;

  String get displayName {
    switch (this) {
      case GameType.binary:
        return 'Binary Choice';
      case GameType.multiChoice:
        return 'Multi Choice';
      case GameType.duel:
        return 'Duel';
    }
  }

  String get description {
    switch (this) {
      case GameType.binary:
        return 'Two options per round';
      case GameType.multiChoice:
        return 'Four options per round';
      case GameType.duel:
        return 'Rock/Paper/Scissors';
    }
  }

  String get icon {
    switch (this) {
      case GameType.binary:
        return 'balance';
      case GameType.multiChoice:
        return 'palette';
      case GameType.duel:
        return 'sports_mma';
    }
  }

  int get optionCount {
    switch (this) {
      case GameType.binary:
        return 2;
      case GameType.multiChoice:
        return 4;
      case GameType.duel:
        return 3;
    }
  }

  List<String> get defaultOptions {
    switch (this) {
      case GameType.binary:
        return ['Left', 'Right'];
      case GameType.multiChoice:
        return ['Red', 'Blue', 'Green', 'Yellow'];
      case GameType.duel:
        return ['Rock', 'Paper', 'Scissors'];
    }
  }

  static GameType fromString(String value) {
    switch (value) {
      case 'binary':
        return GameType.binary;
      case 'multiChoice':
        return GameType.multiChoice;
      case 'duel':
        return GameType.duel;
      default:
        return GameType.binary;
    }
  }
}
