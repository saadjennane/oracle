import 'dart:convert';

/// Text layout configuration for reveal screen overlay
class RevealTextLayout {
  final double offsetX;
  final double offsetY;
  final double maxWidth;
  final double fontSize;
  final double lineHeight;

  const RevealTextLayout({
    this.offsetX = 24,
    this.offsetY = 180,
    this.maxWidth = 0, // 0 means screenWidth - 48
    this.fontSize = 17,
    this.lineHeight = 1.25,
  });

  RevealTextLayout copyWith({
    double? offsetX,
    double? offsetY,
    double? maxWidth,
    double? fontSize,
    double? lineHeight,
  }) {
    return RevealTextLayout(
      offsetX: offsetX ?? this.offsetX,
      offsetY: offsetY ?? this.offsetY,
      maxWidth: maxWidth ?? this.maxWidth,
      fontSize: fontSize ?? this.fontSize,
      lineHeight: lineHeight ?? this.lineHeight,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'offsetX': offsetX,
      'offsetY': offsetY,
      'maxWidth': maxWidth,
      'fontSize': fontSize,
      'lineHeight': lineHeight,
    };
  }

  factory RevealTextLayout.fromJson(Map<String, dynamic> json) {
    return RevealTextLayout(
      offsetX: (json['offsetX'] as num?)?.toDouble() ?? 24,
      offsetY: (json['offsetY'] as num?)?.toDouble() ?? 180,
      maxWidth: (json['maxWidth'] as num?)?.toDouble() ?? 0,
      fontSize: (json['fontSize'] as num?)?.toDouble() ?? 17,
      lineHeight: (json['lineHeight'] as num?)?.toDouble() ?? 1.25,
    );
  }

  static const RevealTextLayout defaultLayout = RevealTextLayout();
}

/// Configuration for reveal screen skin (background + text layout)
class RevealSkinConfig {
  /// Path to light mode background image (local file path) - Note screen
  final String? lightBackgroundPath;

  /// Path to dark mode background image (local file path) - Note screen
  final String? darkBackgroundPath;

  /// Path to light mode list background image (local file path) - Notes list screen
  final String? lightListBackgroundPath;

  /// Path to dark mode list background image (local file path) - Notes list screen
  final String? darkListBackgroundPath;

  /// Path to calculator screenshot overlay
  final String? calculatorBackgroundPath;

  /// Text layout configuration for calculator overlay
  final RevealTextLayout calculatorLayout;

  /// Text layout configuration for light mode
  final RevealTextLayout lightLayout;

  /// Text layout configuration for dark mode
  final RevealTextLayout darkLayout;

  const RevealSkinConfig({
    this.lightBackgroundPath,
    this.darkBackgroundPath,
    this.lightListBackgroundPath,
    this.darkListBackgroundPath,
    this.calculatorBackgroundPath,
    this.calculatorLayout = const RevealTextLayout(offsetX: 24, offsetY: 120, fontSize: 48, lineHeight: 1.0),
    this.lightLayout = const RevealTextLayout(),
    this.darkLayout = const RevealTextLayout(),
  });

  // Note screen backgrounds
  bool get hasLightBackground => lightBackgroundPath != null && lightBackgroundPath!.isNotEmpty;
  bool get hasDarkBackground => darkBackgroundPath != null && darkBackgroundPath!.isNotEmpty;
  bool get hasAnyBackground => hasLightBackground || hasDarkBackground;

  // Calculator background
  bool get hasCalculatorBackground => calculatorBackgroundPath != null && calculatorBackgroundPath!.isNotEmpty;

  // List screen backgrounds
  bool get hasLightListBackground => lightListBackgroundPath != null && lightListBackgroundPath!.isNotEmpty;
  bool get hasDarkListBackground => darkListBackgroundPath != null && darkListBackgroundPath!.isNotEmpty;
  bool get hasAnyListBackground => hasLightListBackground || hasDarkListBackground;

  RevealSkinConfig copyWith({
    String? lightBackgroundPath,
    String? darkBackgroundPath,
    String? lightListBackgroundPath,
    String? darkListBackgroundPath,
    String? calculatorBackgroundPath,
    RevealTextLayout? calculatorLayout,
    RevealTextLayout? lightLayout,
    RevealTextLayout? darkLayout,
    bool clearLightBackground = false,
    bool clearDarkBackground = false,
    bool clearLightListBackground = false,
    bool clearDarkListBackground = false,
    bool clearCalculatorBackground = false,
  }) {
    return RevealSkinConfig(
      lightBackgroundPath: clearLightBackground ? null : (lightBackgroundPath ?? this.lightBackgroundPath),
      darkBackgroundPath: clearDarkBackground ? null : (darkBackgroundPath ?? this.darkBackgroundPath),
      lightListBackgroundPath: clearLightListBackground ? null : (lightListBackgroundPath ?? this.lightListBackgroundPath),
      darkListBackgroundPath: clearDarkListBackground ? null : (darkListBackgroundPath ?? this.darkListBackgroundPath),
      calculatorBackgroundPath: clearCalculatorBackground ? null : (calculatorBackgroundPath ?? this.calculatorBackgroundPath),
      calculatorLayout: calculatorLayout ?? this.calculatorLayout,
      lightLayout: lightLayout ?? this.lightLayout,
      darkLayout: darkLayout ?? this.darkLayout,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'lightBackgroundPath': lightBackgroundPath,
      'darkBackgroundPath': darkBackgroundPath,
      'lightListBackgroundPath': lightListBackgroundPath,
      'darkListBackgroundPath': darkListBackgroundPath,
      'calculatorBackgroundPath': calculatorBackgroundPath,
      'calculatorLayout': calculatorLayout.toJson(),
      'lightLayout': lightLayout.toJson(),
      'darkLayout': darkLayout.toJson(),
    };
  }

  factory RevealSkinConfig.fromJson(Map<String, dynamic> json) {
    return RevealSkinConfig(
      lightBackgroundPath: json['lightBackgroundPath'] as String?,
      darkBackgroundPath: json['darkBackgroundPath'] as String?,
      lightListBackgroundPath: json['lightListBackgroundPath'] as String?,
      darkListBackgroundPath: json['darkListBackgroundPath'] as String?,
      calculatorBackgroundPath: json['calculatorBackgroundPath'] as String?,
      calculatorLayout: json['calculatorLayout'] != null
          ? RevealTextLayout.fromJson(json['calculatorLayout'] as Map<String, dynamic>)
          : const RevealTextLayout(offsetX: 24, offsetY: 120, fontSize: 48, lineHeight: 1.0),
      lightLayout: json['lightLayout'] != null
          ? RevealTextLayout.fromJson(json['lightLayout'] as Map<String, dynamic>)
          : const RevealTextLayout(),
      darkLayout: json['darkLayout'] != null
          ? RevealTextLayout.fromJson(json['darkLayout'] as Map<String, dynamic>)
          : const RevealTextLayout(),
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory RevealSkinConfig.fromJsonString(String jsonString) {
    return RevealSkinConfig.fromJson(jsonDecode(jsonString) as Map<String, dynamic>);
  }

  static const RevealSkinConfig empty = RevealSkinConfig();
}
