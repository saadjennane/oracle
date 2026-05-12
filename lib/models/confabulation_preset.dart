/// Confabulation Preset Model
///
/// A preset where the mentalist writes a text with variable slots,
/// each slot having 2-6 options that are filled during performance.

import 'package:uuid/uuid.dart';

/// Input method for confabulation
enum ConfabInputMethod {
  volume,
  tap,
  audio,
  clockSwipe,
  assistant;

  String get displayName {
    switch (this) {
      case ConfabInputMethod.volume:
        return 'Volume';
      case ConfabInputMethod.tap:
        return 'Tap';
      case ConfabInputMethod.audio:
        return 'Audio IA';
      case ConfabInputMethod.clockSwipe:
        return 'Swipe';
      case ConfabInputMethod.assistant:
        return 'Assistant';
    }
  }

  String toJson() => name;

  static ConfabInputMethod fromJson(String json) {
    return ConfabInputMethod.values.firstWhere(
      (e) => e.name == json,
      orElse: () => ConfabInputMethod.volume,
    );
  }
}

/// A single slot in the confabulation text
class ConfabSlot {
  final String id;
  final String label;
  final List<String> options;

  const ConfabSlot({
    required this.id,
    required this.label,
    required this.options,
  });

  /// Create a new slot with default options
  factory ConfabSlot.create({required String label}) {
    return ConfabSlot(
      id: const Uuid().v4().substring(0, 8),
      label: label,
      options: ['Option 1', 'Option 2'],
    );
  }

  ConfabSlot copyWith({
    String? id,
    String? label,
    List<String>? options,
  }) {
    return ConfabSlot(
      id: id ?? this.id,
      label: label ?? this.label,
      options: options ?? List.from(this.options),
    );
  }

  /// Get the token to insert in the text template
  String get token => '{{slot:$id}}';

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'label': label,
      'options': options,
    };
  }

  factory ConfabSlot.fromJson(Map<String, dynamic> json) {
    return ConfabSlot(
      id: json['id'] as String,
      label: json['label'] as String,
      options: (json['options'] as List<dynamic>).cast<String>(),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ConfabSlot && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// A confabulation preset
class ConfabulationPreset {
  final String id;
  final String name;
  final ConfabInputMethod inputMethod;
  final String textTemplate;
  final List<ConfabSlot> slots;
  final String? audioStartSentence;
  final String? audioStopSentence;
  final String? audioLocale; // Speech recognition locale e.g. 'fr_FR'
  final int acrosticPosition; // 0=auto, 1-6=fixed
  final String? acrosticLanguage; // language code for word bank (null = default)
  final String? injectTransformPrompt;       // OpenAI prompt for ((AITransformInject))
  final String? elipsArtistTransformPrompt;  // OpenAI prompt for ((AITransformElipsArtist))
  final String? elipsSongTransformPrompt;    // OpenAI prompt for ((AITransformElipsSong))
  final String? elipsWordTransformPrompt;    // OpenAI prompt for ((AITransformElipsWord))
  final bool? autoCopyOverride;       // null = inherit global
  final String? shortcutNameOverride; // null = inherit global
  /// Decoy template id for the spectator's webapp (oass.app/{id}). null =
  /// inherit `SettingsProvider.defaultDecoyTemplateId`; both null = no decoy.
  final String? decoyTemplateId;
  /// Decoy input gesture: 'tap' or 'swipe'. null = default ('tap').
  final String? decoyInputType;
  /// Redirect URL for the assistant webapp after input is sent.
  /// null / empty = fall back to global SettingsProvider.freeTextRedirectUrl.
  final String? assistantRedirectUrl;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ConfabulationPreset({
    required this.id,
    required this.name,
    required this.inputMethod,
    required this.textTemplate,
    required this.slots,
    this.audioStartSentence,
    this.audioStopSentence,
    this.audioLocale = 'fr_FR',
    this.acrosticPosition = 0,
    this.acrosticLanguage,
    this.injectTransformPrompt,
    this.elipsArtistTransformPrompt,
    this.elipsSongTransformPrompt,
    this.elipsWordTransformPrompt,
    this.autoCopyOverride,
    this.shortcutNameOverride,
    this.decoyTemplateId,
    this.decoyInputType,
    this.assistantRedirectUrl,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Create a new empty preset
  factory ConfabulationPreset.create({String? name}) {
    final now = DateTime.now();
    return ConfabulationPreset(
      id: const Uuid().v4(),
      name: name ?? 'New Preset',
      inputMethod: ConfabInputMethod.volume,
      textTemplate: '',
      slots: [],
      createdAt: now,
      updatedAt: now,
    );
  }

  ConfabulationPreset copyWith({
    String? id,
    String? name,
    ConfabInputMethod? inputMethod,
    String? textTemplate,
    List<ConfabSlot>? slots,
    String? audioStartSentence,
    String? audioStopSentence,
    String? audioLocale,
    int? acrosticPosition,
    String? acrosticLanguage,
    String? injectTransformPrompt,
    String? elipsArtistTransformPrompt,
    String? elipsSongTransformPrompt,
    String? elipsWordTransformPrompt,
    bool? autoCopyOverride,
    String? shortcutNameOverride,
    String? decoyTemplateId,
    String? decoyInputType,
    String? assistantRedirectUrl,
    bool clearAutoCopyOverride = false,
    bool clearShortcutNameOverride = false,
    bool clearDecoyTemplateId = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ConfabulationPreset(
      id: id ?? this.id,
      name: name ?? this.name,
      inputMethod: inputMethod ?? this.inputMethod,
      textTemplate: textTemplate ?? this.textTemplate,
      slots: slots ?? List.from(this.slots),
      audioStartSentence: audioStartSentence ?? this.audioStartSentence,
      audioStopSentence: audioStopSentence ?? this.audioStopSentence,
      audioLocale: audioLocale ?? this.audioLocale,
      acrosticPosition: acrosticPosition ?? this.acrosticPosition,
      acrosticLanguage: acrosticLanguage ?? this.acrosticLanguage,
      injectTransformPrompt: injectTransformPrompt ?? this.injectTransformPrompt,
      elipsArtistTransformPrompt: elipsArtistTransformPrompt ?? this.elipsArtistTransformPrompt,
      elipsSongTransformPrompt: elipsSongTransformPrompt ?? this.elipsSongTransformPrompt,
      elipsWordTransformPrompt: elipsWordTransformPrompt ?? this.elipsWordTransformPrompt,
      autoCopyOverride: clearAutoCopyOverride ? null : (autoCopyOverride ?? this.autoCopyOverride),
      shortcutNameOverride: clearShortcutNameOverride ? null : (shortcutNameOverride ?? this.shortcutNameOverride),
      decoyTemplateId: clearDecoyTemplateId ? null : (decoyTemplateId ?? this.decoyTemplateId),
      decoyInputType: decoyInputType ?? this.decoyInputType,
      assistantRedirectUrl: assistantRedirectUrl ?? this.assistantRedirectUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  /// Get a slot by its ID
  ConfabSlot? getSlotById(String slotId) {
    try {
      return slots.firstWhere((s) => s.id == slotId);
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'inputMethod': inputMethod.toJson(),
      'textTemplate': textTemplate,
      'slots': slots.map((s) => s.toJson()).toList(),
      'audioStartSentence': audioStartSentence,
      'audioStopSentence': audioStopSentence,
      'audioLocale': audioLocale,
      'acrosticPosition': acrosticPosition,
      'acrosticLanguage': acrosticLanguage,
      'injectTransformPrompt': injectTransformPrompt,
      'elipsArtistTransformPrompt': elipsArtistTransformPrompt,
      'elipsSongTransformPrompt': elipsSongTransformPrompt,
      'elipsWordTransformPrompt': elipsWordTransformPrompt,
      'autoCopyOverride': autoCopyOverride,
      'shortcutNameOverride': shortcutNameOverride,
      'decoyTemplateId': decoyTemplateId,
      'decoyInputType': decoyInputType,
      'assistantRedirectUrl': assistantRedirectUrl,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory ConfabulationPreset.fromJson(Map<String, dynamic> json) {
    return ConfabulationPreset(
      id: json['id'] as String,
      name: json['name'] as String,
      inputMethod: ConfabInputMethod.fromJson(json['inputMethod'] as String),
      textTemplate: json['textTemplate'] as String,
      slots: (json['slots'] as List<dynamic>)
          .map((s) => ConfabSlot.fromJson(s as Map<String, dynamic>))
          .toList(),
      audioStartSentence: json['audioStartSentence'] as String?,
      audioStopSentence: json['audioStopSentence'] as String?,
      audioLocale: json['audioLocale'] as String? ?? 'fr_FR',
      acrosticPosition: json['acrosticPosition'] as int? ?? 0,
      acrosticLanguage: json['acrosticLanguage'] as String?,
      injectTransformPrompt: json['injectTransformPrompt'] as String?,
      elipsArtistTransformPrompt: json['elipsArtistTransformPrompt'] as String?,
      elipsSongTransformPrompt: json['elipsSongTransformPrompt'] as String?,
      elipsWordTransformPrompt: json['elipsWordTransformPrompt'] as String?,
      autoCopyOverride: json['autoCopyOverride'] as bool?,
      shortcutNameOverride: json['shortcutNameOverride'] as String?,
      decoyTemplateId: json['decoyTemplateId'] as String?,
      decoyInputType: json['decoyInputType'] as String?,
      assistantRedirectUrl: json['assistantRedirectUrl'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ConfabulationPreset && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
