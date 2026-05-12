import 'language.dart';

/// Stealth input methods for secret input during performance
enum StealthInputMethod {
  /// Assistant mode - webapp for remote input
  assistant,

  /// Volume buttons: UP/DOWN multi-taps to select options
  volume,

  /// Black screen with invisible tap zones
  tap,

  /// Audio input via speech recognition
  audio,

  /// ClockSwipe: 2 consecutive swipes select a clock position (0-11)
  clockSwipe,
  ;

  String displayName(Language locale) {
    switch (this) {
      case StealthInputMethod.assistant:
        return locale == Language.french ? 'Assistant' : 'Assistant';
      case StealthInputMethod.volume:
        return locale == Language.french ? 'Boutons Volume' : 'Volume Buttons';
      case StealthInputMethod.tap:
        return locale == Language.french ? 'Zones Tap' : 'Tap Zones';
      case StealthInputMethod.audio:
        return locale == Language.french ? 'Audio IA' : 'AI Audio';
      case StealthInputMethod.clockSwipe:
        return 'Swipe';
    }
  }

  String description(Language locale) {
    switch (this) {
      case StealthInputMethod.assistant:
        return locale == Language.french
            ? 'Webapp pour assistant à distance'
            : 'Webapp for remote assistant';
      case StealthInputMethod.volume:
        return locale == Language.french
            ? 'Écran noir, entrée par boutons volume'
            : 'Black screen, input via volume buttons';
      case StealthInputMethod.tap:
        return locale == Language.french
            ? 'Écran noir, zones tactiles invisibles'
            : 'Black screen, invisible tap zones';
      case StealthInputMethod.audio:
        return locale == Language.french
            ? 'Reconnaissance vocale, détection par mots-clés'
            : 'Speech recognition, keyword detection';
      case StealthInputMethod.clockSwipe:
        return locale == Language.french
            ? 'Écran noir, patterns de swipes configurables'
            : 'Black screen, configurable swipe patterns';
    }
  }

  String toJson() => name;

  static StealthInputMethod fromJson(String? json) {
    if (json == null || json == 'none') return StealthInputMethod.assistant;
    return StealthInputMethod.values.firstWhere(
      (e) => e.name == json,
      orElse: () => StealthInputMethod.assistant,
    );
  }
}

/// Tap zone layout for 2 options
enum TapLayout2 {
  /// Top / Bottom halves
  topBottom,
  /// Left / Right halves
  leftRight;

  String displayName(Language locale) {
    switch (this) {
      case TapLayout2.leftRight:
        return locale == Language.french ? 'Gauche / Droite' : 'Left / Right';
      case TapLayout2.topBottom:
        return locale == Language.french ? 'Haut / Bas' : 'Top / Bottom';
    }
  }

  String toJson() => name;

  static TapLayout2 fromJson(String? json) {
    if (json == null) return TapLayout2.topBottom;
    return TapLayout2.values.firstWhere(
      (e) => e.name == json,
      orElse: () => TapLayout2.topBottom,
    );
  }
}

/// Tap zone layout for 4 options
enum TapLayout4 {
  /// 4 corners (quadrants)
  corners,
  /// 4 horizontal stripes
  stripes;

  String displayName(Language locale) {
    switch (this) {
      case TapLayout4.corners:
        return locale == Language.french ? '4 coins' : '4 corners';
      case TapLayout4.stripes:
        return locale == Language.french ? '4 bandes' : '4 stripes';
    }
  }

  String toJson() => name;

  static TapLayout4 fromJson(String? json) {
    if (json == null) return TapLayout4.corners;
    return TapLayout4.values.firstWhere(
      (e) => e.name == json,
      orElse: () => TapLayout4.corners,
    );
  }
}

/// Volume button direction
enum VolumeDirection {
  up,
  down,
}

/// Input method for Free Will mode
enum FreeWillInputMethod {
  /// Volume buttons: UP=1, DOWN=2, Double-press=3
  volume,

  /// Tap zones: 3 horizontal zones on screen
  tap,

  /// Swipe patterns on black screen
  swipe,

  /// Assistant webapp
  assistant,

  /// Audio AI: speech-to-text + GPT analysis
  audio;

  String displayName(Language locale) {
    switch (this) {
      case FreeWillInputMethod.volume:
        return locale == Language.french ? 'Boutons Volume' : 'Volume Buttons';
      case FreeWillInputMethod.tap:
        return locale == Language.french ? 'Zones Tap' : 'Tap Zones';
      case FreeWillInputMethod.swipe:
        return 'Swipe';
      case FreeWillInputMethod.assistant:
        return 'Assistant';
      case FreeWillInputMethod.audio:
        return 'Audio IA';
    }
  }

  String description(Language locale) {
    switch (this) {
      case FreeWillInputMethod.volume:
        return locale == Language.french
            ? 'UP=1, DOWN=2, Double=3, Tap écran=LOCK'
            : 'UP=1, DOWN=2, Double=3, Tap screen=LOCK';
      case FreeWillInputMethod.tap:
        return locale == Language.french
            ? '3 zones, Volume=LOCK, Tap après lock=REVEAL'
            : '3 zones, Volume=LOCK, Tap after lock=REVEAL';
      case FreeWillInputMethod.swipe:
        return locale == Language.french
            ? 'Patterns de swipes configurables'
            : 'Configurable swipe patterns';
      case FreeWillInputMethod.assistant:
        return locale == Language.french
            ? 'Webapp pour assistant à distance'
            : 'Webapp for remote assistant';
      case FreeWillInputMethod.audio:
        return locale == Language.french
            ? 'IA écoute et déduit les choix'
            : 'AI listens and deduces choices';
    }
  }

  String toJson() => name;

  static FreeWillInputMethod fromJson(String? json) {
    if (json == null) return FreeWillInputMethod.volume;
    return FreeWillInputMethod.values.firstWhere(
      (e) => e.name == json,
      orElse: () => FreeWillInputMethod.volume,
    );
  }
}

/// Orientation des zones de tap pour Free Will (3 zones)
enum TapOrientation {
  /// 3 bandes horizontales (haut, milieu, bas)
  horizontal,

  /// 3 bandes verticales (gauche, centre, droite)
  vertical;

  String displayName(Language locale) {
    switch (this) {
      case TapOrientation.horizontal:
        return locale == Language.french ? 'Horizontal (3 bandes)' : 'Horizontal (3 stripes)';
      case TapOrientation.vertical:
        return locale == Language.french ? 'Vertical (3 bandes)' : 'Vertical (3 stripes)';
    }
  }

  String description(Language locale) {
    switch (this) {
      case TapOrientation.horizontal:
        return locale == Language.french
            ? 'Haut = 1, Milieu = 2, Bas = 3'
            : 'Top = 1, Middle = 2, Bottom = 3';
      case TapOrientation.vertical:
        return locale == Language.french
            ? 'Gauche = 1, Centre = 2, Droite = 3'
            : 'Left = 1, Center = 2, Right = 3';
    }
  }

  /// Noms des zones selon l'orientation (FR)
  List<String> get zoneNamesFR {
    switch (this) {
      case TapOrientation.horizontal:
        return ['Haut', 'Milieu', 'Bas'];
      case TapOrientation.vertical:
        return ['Gauche', 'Centre', 'Droite'];
    }
  }

  /// Noms des zones selon l'orientation (EN)
  List<String> get zoneNamesEN {
    switch (this) {
      case TapOrientation.horizontal:
        return ['Top', 'Middle', 'Bottom'];
      case TapOrientation.vertical:
        return ['Left', 'Center', 'Right'];
    }
  }

  List<String> zoneNames(Language locale) {
    return locale == Language.french ? zoneNamesFR : zoneNamesEN;
  }

  String toJson() => name;

  static TapOrientation fromJson(String? json) {
    if (json == null) return TapOrientation.horizontal;
    return TapOrientation.values.firstWhere(
      (e) => e.name == json,
      orElse: () => TapOrientation.horizontal,
    );
  }
}

/// Represents a volume input gesture (direction + tap count)
class VolumeGesture {
  final VolumeDirection direction;
  final int tapCount;

  const VolumeGesture({
    required this.direction,
    required this.tapCount,
  });

  /// Convert gesture to option index (0-based)
  /// Mapping:
  /// UP x1   -> 0
  /// DOWN x1 -> 1
  /// UP x2   -> 2
  /// DOWN x2 -> 3
  /// UP x3   -> 4
  /// DOWN x3 -> 5
  ///
  /// Special case for 3-option presets: both UPx2 and DOWNx2 commit option 2
  /// (the 3rd option). This gives the spectator a symmetric "any double" cue
  /// for the third choice — easier to remember than "specifically UPx2".
  int? toOptionIndex(int maxOptions) {
    if (tapCount < 1 || tapCount > 3) return null;

    if (maxOptions == 3 && tapCount == 2) return 2;

    final index = (tapCount - 1) * 2 + (direction == VolumeDirection.up ? 0 : 1);

    if (index >= maxOptions) return null;
    return index;
  }

  /// Create gesture from option index
  static VolumeGesture? fromOptionIndex(int index) {
    if (index < 0 || index > 5) return null;

    final tapCount = (index ~/ 2) + 1;
    final direction = index.isEven ? VolumeDirection.up : VolumeDirection.down;

    return VolumeGesture(direction: direction, tapCount: tapCount);
  }

  @override
  String toString() => 'VolumeGesture(${direction.name} x$tapCount)';
}
