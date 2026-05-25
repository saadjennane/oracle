import 'package:uuid/uuid.dart';
import 'appellation.dart';
import 'choices_narrative_mode.dart';
import 'duel_mode.dart';
import 'free_will_config.dart';
import 'input_mode.dart';
import 'language.dart';
import 'prediction_mode.dart';
import 'preprogrammed_tie_strategy.dart';
import '../engine/number_engine.dart';
import 'stealth_input_method.dart';

enum PresetType {
  choices,
  duel,
  freeWill,
  multipleOut,
  number;

  String displayName(Language locale) {
    switch (this) {
      case PresetType.choices:
        return locale == Language.french ? 'Choix Multiples' : 'Multiple Choices';
      case PresetType.duel:
        return locale == Language.french ? 'Duel (PFC)' : 'Duel (RPS)';
      case PresetType.freeWill:
        return locale == Language.french ? 'Libre Arbitre' : 'Free Will';
      case PresetType.multipleOut:
        return locale == Language.french ? 'Sorties Multiples' : 'Multiple Out';
      case PresetType.number:
        return locale == Language.french ? 'Nombres' : 'Numbers';
    }
  }

  String get description {
    switch (this) {
      case PresetType.choices:
        return '2-6 options per round';
      case PresetType.duel:
        return 'Rock/Paper/Scissors rules';
      case PresetType.freeWill:
        return '3 objects, 3 actions';
      case PresetType.multipleOut:
        return 'Pre-written texts, stealth select';
      case PresetType.number:
        return 'Rainman, Birthday, Today';
    }
  }

  int get minOptions => this == PresetType.choices ? 2 : 3;
  int get maxOptions => this == PresetType.choices ? 6 : 3;

  List<String> get defaultLabels {
    switch (this) {
      case PresetType.choices:
        return ['Option A', 'Option B'];
      case PresetType.duel:
        return ['Rock', 'Paper', 'Scissors'];
      case PresetType.freeWill:
        return ['Object 1', 'Object 2', 'Object 3'];
      case PresetType.multipleOut:
        return ['Text 1', 'Text 2'];
      case PresetType.number:
        return [];
    }
  }

  static PresetType fromString(String value) {
    switch (value) {
      case 'choices':
        return PresetType.choices;
      case 'duel':
        return PresetType.duel;
      case 'freeWill':
        return PresetType.freeWill;
      case 'multipleOut':
        return PresetType.multipleOut;
      case 'number':
        return PresetType.number;
      default:
        return PresetType.choices;
    }
  }
}

class Preset {
  final String id;
  final String name;
  final PresetType type;
  final Language language;
  final PredictionMode predictionMode;
  final int nbRounds;
  final int nbOptions;
  final List<String> labels;
  final InputMode inputMode;
  final List<int>? performerSequence;
  final StealthInputMethod stealthInputMethod;

  // TAP layout options
  final TapLayout2 tapLayout2;
  final TapLayout4 tapLayout4;

  // Appellation fields
  final NarratorVoice narratorVoice;
  final AddressMode addressMode;
  final String? spectatorName;
  final String? actorName;
  final String? participantName;

  // Audio AI settings
  final String? audioStartSentence;
  final String? audioStopSentence;
  final String audioLocale; // Speech recognition locale e.g. 'fr_FR', 'en_US'

  // Custom preprogrammed banks: performerKey -> spectatorKey -> text
  final Map<String, Map<String, String>>? customPreprogrammedBanks;

  // Custom duel bank templates: bucketKey -> text
  final Map<String, String>? customDuelBankTemplates;

  // Custom CHOICES bank templates: bucketKey -> text
  final Map<String, String>? customChoicesBankTemplates;

  // CHOICES narrative mode (buckets vs sequences)
  final ChoicesNarrativeMode choicesNarrativeMode;

  // Duel narrative mode (buckets vs sequences) - fixedRounds only, <= 5 rounds
  final ChoicesNarrativeMode duelNarrativeMode;

  // Duel mode settings (DUEL ONLY)
  final DuelMode duelMode;
  final int targetScore;
  final PreprogrammedTieStrategy preprogrammedTieStrategy;

  // FREE_WILL settings (FREE_WILL ONLY)
  final FreeWillConfig? freeWillConfig;

  // Custom FREE_WILL bank templates (per-permutation, "6 texts" mode)
  final Map<String, String>? customFreeWillBankTemplates;

  /// FREE_WILL bank mode: 'six' = 6 per-permutation texts (use ((Label1/2/3))),
  /// 'single' = a single template applied to every permutation (use {TAKE/GIVE/TABLE}).
  /// Default 'six' for backward compatibility.
  final String freeWillBankMode;

  /// Single template used when [freeWillBankMode] == 'single'. Substitutes
  /// {TAKE}/{GIVE}/{TABLE} at runtime against the spectator's outcome.
  final String? freeWillSingleTemplate;

  // Number mode settings
  final NumberMode? numberMode;
  final String? numberFormula;         // Rainman: "_ * _ + _ * _"
  final bool numberIncludeTime;        // Today: include time
  final int numberMinutesOffset;       // Today: minutes to add
  final String? numberOutputMode;      // "notes" or "calculator"
  /// Notes-mode template with variables — supports ((Result)) for
  /// Rainman/Today, and ((DayOfBirth)) + ((numDays)) for Birthday.
  /// Null or empty = fall back to the raw result (previous behavior).
  final String? numberNotesTemplate;

  // Assistant mode settings
  final String? assistantRedirectUrl;   // URL to redirect webapp after input
  final String? assistantInputMode;     // "buttons" (default), "blackscreen_tap", "blackscreen_swipe"

  // Acrostic position: 0 = auto, 1-6 = fixed, -1 = input at start
  final int acrosticPosition;

  // Output mode: 'notes' (default), 'image', 'both'
  final String outputMode;

  // After image save: 'black' (stay on black screen) or 'photos' (open Photos app)
  final String imageAfterSave;

  // Bank images: bankKey → local image path (optional per bank entry)
  // For Choices: "HMH" → "/path/to/image.png"
  // For Duel: "3|1-2" → "/path/to/image.png"
  // For Free Will: "TAKE:obj|GIVE:obj|TABLE:obj" → "/path/to/image.png"
  // For Multiple Out: "0", "1", "2" → "/path/to/image.png"
  final Map<String, String>? bankImages;

  // Timestamp offset for image gallery save (minutes in the past, 0 = now)
  final int imageTimestampOffset;

  // Custom swipe patterns for clockSwipe input on Choices
  final List<String>? swipePatterns;

  // MULTIPLE_OUT settings
  final List<String>? multipleOutTexts;
  final List<String>? multipleOutTitles;   // Optional display titles per text
  final List<String>? multipleOutKeywords; // Audio keywords per text

  // Per-preset override of global auto-copy / shortcut settings
  // null = inherit global setting
  final bool? autoCopyOverride;
  final String? shortcutNameOverride;

  /// Decoy template id selected for this preset (id of a `DecoyTemplate`
  /// stored in `SettingsProvider.decoyTemplates`). null = inherit the global
  /// default template id (`SettingsProvider.defaultDecoyTemplateId`); both
  /// null = no decoy, fall back to the standard assistant UI.
  final String? decoyTemplateId;

  /// How the spectator interacts with the decoy: 'tap' (vertical zones) or
  /// 'swipe' (clock-style directional swipes). Independent of the preset's
  /// stealthInputMethod since the spectator's phone has no access to the
  /// performer's volume buttons. null = default ('tap').
  final String? decoyInputType;

  // Last modification timestamp (for iCloud merge). null = unknown/legacy.
  final DateTime? updatedAt;

  // Creation timestamp — used as the primary sort key on the home screen
  // (chronological list across presets + confabs). null = legacy preset,
  // migrated at load time using the persisted list order.
  final DateTime? createdAt;

  // External API variable blocks
  final String? injectSuccessText;
  final String? injectFallbackText;
  final String? injectTransformPrompt;  // OpenAI prompt to transform inject value
  final String? elipsSuccessText;
  final String? elipsFallbackText;
  final String? elipsTransformPrompt;   // OpenAI prompt to transform elips values
  final String? highScoreSuccessText;
  final String? highScoreFallbackText;
  final String? highScoreLowText;   // score < 7
  final String? highScoreMedText;   // 7-20
  final String? highScoreHighText;  // > 20

  Preset({
    String? id,
    required this.name,
    required this.type,
    this.language = Language.english,
    PredictionMode? predictionMode,
    required this.nbRounds,
    required this.nbOptions,
    required this.labels,
    required this.inputMode,
    this.performerSequence,
    this.stealthInputMethod = StealthInputMethod.assistant,
    this.tapLayout2 = TapLayout2.topBottom,
    this.tapLayout4 = TapLayout4.corners,
    this.narratorVoice = NarratorVoice.firstPerson,
    this.addressMode = AddressMode.you,
    this.spectatorName,
    this.actorName,
    this.participantName,
    this.audioStartSentence,
    this.audioStopSentence,
    this.audioLocale = 'fr_FR',
    this.customPreprogrammedBanks,
    this.customDuelBankTemplates,
    this.customChoicesBankTemplates,
    this.choicesNarrativeMode = ChoicesNarrativeMode.buckets,
    this.duelNarrativeMode = ChoicesNarrativeMode.buckets,
    this.duelMode = DuelMode.fixedRounds,
    this.targetScore = 3,
    this.preprogrammedTieStrategy = PreprogrammedTieStrategy.repeat,
    this.freeWillConfig,
    this.customFreeWillBankTemplates,
    this.freeWillBankMode = 'six',
    this.freeWillSingleTemplate,
    this.numberMode,
    this.numberFormula,
    this.numberIncludeTime = false,
    this.numberMinutesOffset = 0,
    this.numberOutputMode,
    this.numberNotesTemplate,
    this.assistantRedirectUrl,
    this.assistantInputMode,
    this.acrosticPosition = 0,
    this.outputMode = 'notes',
    this.imageAfterSave = 'black',
    this.bankImages,
    this.imageTimestampOffset = 0,
    this.swipePatterns,
    this.multipleOutTexts,
    this.multipleOutTitles,
    this.multipleOutKeywords,
    this.autoCopyOverride,
    this.shortcutNameOverride,
    this.decoyTemplateId,
    this.decoyInputType,
    this.updatedAt,
    this.createdAt,
    this.injectSuccessText,
    this.injectFallbackText,
    this.injectTransformPrompt,
    this.elipsSuccessText,
    this.elipsFallbackText,
    this.elipsTransformPrompt,
    this.highScoreSuccessText,
    this.highScoreFallbackText,
    this.highScoreLowText,
    this.highScoreMedText,
    this.highScoreHighText,
  }) : id = id ?? const Uuid().v4(),
       predictionMode = (type == PresetType.duel || type == PresetType.freeWill)
           ? PredictionMode.game
           : (predictionMode ?? PredictionMode.game);

  List<String> validate() {
    final errors = <String>[];

    if (name.trim().isEmpty) {
      errors.add('Preset name is required');
    }

    if (nbRounds < 1 || nbRounds > 5) {
      errors.add('Number of rounds must be between 1 and 5');
    }

    if (type == PresetType.choices) {
      if (nbOptions < 2 || nbOptions > 6) {
        errors.add('Number of options must be between 2 and 6');
      }
    } else if (type == PresetType.duel) {
      if (nbOptions != 3) {
        errors.add('Duel must have exactly 3 options');
      }
    }

    if (labels.length != nbOptions) {
      errors.add('Labels count must match number of options');
    }

    final trimmedLabels = labels.map((l) => l.trim()).toList();
    if (trimmedLabels.any((l) => l.isEmpty)) {
      errors.add('All labels must be filled');
    }

    final lowerLabels = trimmedLabels.map((l) => l.toLowerCase()).toList();
    if (lowerLabels.toSet().length != lowerLabels.length) {
      errors.add('Labels must be unique');
    }

    // Performer sequence only applies to round-based types (choices, duel).
    // Free Will, Multiple Out and Number don't have a performer sequence.
    final needsPerformerSequence = type == PresetType.choices || type == PresetType.duel;
    if (needsPerformerSequence &&
        predictionMode == PredictionMode.game &&
        inputMode == InputMode.preprogrammed) {
      if (performerSequence == null || performerSequence!.length != nbRounds) {
        errors.add('Performer sequence must have $nbRounds selections');
      } else {
        for (int i = 0; i < performerSequence!.length; i++) {
          final idx = performerSequence![i];
          if (idx < 0 || idx >= nbOptions) {
            errors.add('Invalid sequence index at round ${i + 1}');
          }
        }
      }
    }

    if (stealthInputMethod == StealthInputMethod.volume) {
      if (nbOptions > 6) {
        errors.add('Volume input method supports maximum 6 options');
      }
    }

    if (type == PresetType.choices && addressMode == AddressMode.byName) {
      if (spectatorName == null || spectatorName!.trim().isEmpty) {
        errors.add('Spectator name is required when using name mode');
      }
    }

    if (type == PresetType.duel && narratorVoice == NarratorVoice.thirdPerson) {
      if (actorName == null || actorName!.trim().isEmpty) {
        errors.add('Performer name is required in third person mode');
      }
    }

    if (type == PresetType.duel && addressMode == AddressMode.byName) {
      if (participantName == null || participantName!.trim().isEmpty) {
        errors.add('Opponent name is required when using name mode');
      }
    }

    if (type == PresetType.multipleOut) {
      if (multipleOutTexts == null || multipleOutTexts!.length < 2) {
        errors.add('At least 2 texts are required');
      } else if (multipleOutTexts!.any((t) => t.trim().isEmpty)) {
        errors.add('All texts must be filled');
      }
    }

    if (type == PresetType.number) {
      if (numberMode == null) {
        errors.add('Number mode is required');
      }
      if (numberMode == NumberMode.rainman) {
        if (numberFormula == null || numberFormula!.trim().isEmpty) {
          errors.add('Formula is required for Rainman mode');
        } else {
          // Validate formula: must contain at least one _ or X and only valid chars
          final formula = numberFormula!.trim();
          final validChars = RegExp(r'^[_X\d\s\+\-\*\/\(\)\.=]+$', caseSensitive: false);
          if (!validChars.hasMatch(formula)) {
            errors.add('Formula contains invalid characters');
          }
          final operandCount = RegExp(r'_|X+').allMatches(formula).length;
          if (operandCount == 0) {
            errors.add('Formula must contain at least one operand (_ or XX)');
          }
        }
      }
    }

    return errors;
  }

  bool get isValid => validate().isEmpty;

  String? getPerformerLabel(int roundIndex) {
    if (performerSequence == null || roundIndex >= performerSequence!.length) {
      return null;
    }
    final idx = performerSequence![roundIndex];
    if (idx >= 0 && idx < labels.length) {
      return labels[idx];
    }
    return null;
  }

  List<String>? get performerLabels {
    if (performerSequence == null) return null;
    return performerSequence!.map((idx) {
      if (idx >= 0 && idx < labels.length) {
        return labels[idx];
      }
      return '';
    }).toList();
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type.name,
        'language': language.name,
        'predictionMode': predictionMode.name,
        'nbRounds': nbRounds,
        'nbOptions': nbOptions,
        'labels': labels,
        'inputMode': inputMode.name,
        'performerSequence': performerSequence,
        'stealthInputMethod': stealthInputMethod.toJson(),
        'tapLayout2': tapLayout2.toJson(),
        'tapLayout4': tapLayout4.toJson(),
        'narratorVoice': narratorVoice.name,
        'addressMode': addressMode.name,
        'spectatorName': spectatorName,
        'actorName': actorName,
        'participantName': participantName,
        'audioStartSentence': audioStartSentence,
        'audioStopSentence': audioStopSentence,
        'audioLocale': audioLocale,
        'customPreprogrammedBanks': customPreprogrammedBanks,
        'customDuelBankTemplates': customDuelBankTemplates,
        'customChoicesBankTemplates': customChoicesBankTemplates,
        'choicesNarrativeMode': choicesNarrativeMode.toJson(),
        'duelNarrativeMode': duelNarrativeMode.toJson(),
        'duelMode': duelMode.toJson(),
        'targetScore': targetScore,
        'preprogrammedTieStrategy': preprogrammedTieStrategy.toJson(),
        'freeWillConfig': freeWillConfig?.toJson(),
        'customFreeWillBankTemplates': customFreeWillBankTemplates,
        'freeWillBankMode': freeWillBankMode,
        'freeWillSingleTemplate': freeWillSingleTemplate,
        'numberMode': numberMode?.toJson(),
        'numberFormula': numberFormula,
        'numberIncludeTime': numberIncludeTime,
        'numberMinutesOffset': numberMinutesOffset,
        'numberOutputMode': numberOutputMode,
        'numberNotesTemplate': numberNotesTemplate,
        'assistantRedirectUrl': assistantRedirectUrl,
        'assistantInputMode': assistantInputMode,
        'acrosticPosition': acrosticPosition,
        'outputMode': outputMode,
        'imageAfterSave': imageAfterSave,
        'bankImages': bankImages,
        'imageTimestampOffset': imageTimestampOffset,
        'swipePatterns': swipePatterns,
        'multipleOutTexts': multipleOutTexts,
        'multipleOutTitles': multipleOutTitles,
        'multipleOutKeywords': multipleOutKeywords,
        'autoCopyOverride': autoCopyOverride,
        'shortcutNameOverride': shortcutNameOverride,
        'decoyTemplateId': decoyTemplateId,
        'decoyInputType': decoyInputType,
        'updatedAt': updatedAt?.toIso8601String(),
        'createdAt': createdAt?.toIso8601String(),
        'injectSuccessText': injectSuccessText,
        'injectFallbackText': injectFallbackText,
        'injectTransformPrompt': injectTransformPrompt,
        'elipsSuccessText': elipsSuccessText,
        'elipsFallbackText': elipsFallbackText,
        'elipsTransformPrompt': elipsTransformPrompt,
        'highScoreSuccessText': highScoreSuccessText,
        'highScoreFallbackText': highScoreFallbackText,
        'highScoreLowText': highScoreLowText,
        'highScoreMedText': highScoreMedText,
        'highScoreHighText': highScoreHighText,
      };

  factory Preset.fromJson(Map<String, dynamic> json) => Preset(
        id: (json['id'] as String?)?.isNotEmpty == true ? json['id'] as String : null,
        name: json['name'] as String? ?? 'Imported Preset',
        type: PresetType.fromString(json['type'] as String? ?? 'choices'),
        language: Language.fromString(json['language'] as String? ?? 'english'),
        predictionMode: PredictionMode.fromJson(json['predictionMode'] as String? ?? 'game'),
        nbRounds: json['nbRounds'] as int? ?? 3,
        nbOptions: json['nbOptions'] as int? ?? 2,
        labels: (json['labels'] as List?)?.cast<String>() ?? ['A', 'B'],
        inputMode: InputMode.fromString(json['inputMode'] as String? ?? 'preprogrammed'),
        performerSequence: (json['performerSequence'] as List?)?.cast<int>(),
        stealthInputMethod: StealthInputMethod.fromJson(json['stealthInputMethod'] as String?),
        tapLayout2: TapLayout2.fromJson(json['tapLayout2'] as String?),
        tapLayout4: TapLayout4.fromJson(json['tapLayout4'] as String?),
        narratorVoice: NarratorVoice.fromJson(json['narratorVoice'] as String?),
        addressMode: AddressMode.fromJson(json['addressMode'] as String?),
        spectatorName: json['spectatorName'] as String?,
        actorName: json['actorName'] as String?,
        participantName: json['participantName'] as String?,
        audioStartSentence: json['audioStartSentence'] as String?,
        audioStopSentence: json['audioStopSentence'] as String?,
        audioLocale: json['audioLocale'] as String? ?? 'fr_FR',
        customPreprogrammedBanks: _parseCustomBanks(json['customPreprogrammedBanks']),
        customDuelBankTemplates: _parseCustomDuelBanks(json['customDuelBankTemplates']),
        customChoicesBankTemplates: _parseCustomChoicesBanks(json['customChoicesBankTemplates']),
        choicesNarrativeMode: ChoicesNarrativeMode.fromJson(json['choicesNarrativeMode'] as String?),
        duelNarrativeMode: ChoicesNarrativeMode.fromJson(json['duelNarrativeMode'] as String?),
        duelMode: DuelMode.fromJson(json['duelMode'] as String?),
        targetScore: json['targetScore'] as int? ?? 3,
        preprogrammedTieStrategy: PreprogrammedTieStrategy.fromJson(json['preprogrammedTieStrategy'] as String?),
        freeWillConfig: json['freeWillConfig'] != null
            ? FreeWillConfig.fromJson(json['freeWillConfig'] as Map<String, dynamic>)
            : null,
        customFreeWillBankTemplates: _parseCustomFreeWillBanks(json['customFreeWillBankTemplates']),
        freeWillBankMode: (json['freeWillBankMode'] as String?) ?? 'six',
        freeWillSingleTemplate: json['freeWillSingleTemplate'] as String?,
        numberMode: json['numberMode'] != null ? NumberMode.fromJson(json['numberMode'] as String) : null,
        numberFormula: json['numberFormula'] as String?,
        numberIncludeTime: json['numberIncludeTime'] as bool? ?? false,
        numberMinutesOffset: json['numberMinutesOffset'] as int? ?? 0,
        numberOutputMode: json['numberOutputMode'] as String?,
        numberNotesTemplate: json['numberNotesTemplate'] as String?,
        assistantRedirectUrl: json['assistantRedirectUrl'] as String?,
        assistantInputMode: json['assistantInputMode'] as String?,
        acrosticPosition: json['acrosticPosition'] as int? ?? 0,
        outputMode: json['outputMode'] as String? ?? 'notes',
        imageAfterSave: json['imageAfterSave'] as String? ?? 'black',
        bankImages: (json['bankImages'] as Map<String, dynamic>?)?.cast<String, String>(),
        imageTimestampOffset: json['imageTimestampOffset'] as int? ?? 0,
        swipePatterns: (json['swipePatterns'] as List?)?.cast<String>(),
        multipleOutTexts: (json['multipleOutTexts'] as List?)?.cast<String>(),
        multipleOutTitles: (json['multipleOutTitles'] as List?)?.cast<String>(),
        multipleOutKeywords: (json['multipleOutKeywords'] as List?)?.cast<String>(),
        autoCopyOverride: json['autoCopyOverride'] as bool?,
        shortcutNameOverride: json['shortcutNameOverride'] as String?,
        decoyTemplateId: json['decoyTemplateId'] as String?,
        decoyInputType: json['decoyInputType'] as String?,
        updatedAt: json['updatedAt'] is String ? DateTime.tryParse(json['updatedAt'] as String) : null,
        createdAt: json['createdAt'] is String ? DateTime.tryParse(json['createdAt'] as String) : null,
        injectSuccessText: json['injectSuccessText'] as String?,
        injectFallbackText: json['injectFallbackText'] as String?,
        injectTransformPrompt: json['injectTransformPrompt'] as String?,
        elipsSuccessText: json['elipsSuccessText'] as String?,
        elipsFallbackText: json['elipsFallbackText'] as String?,
        elipsTransformPrompt: json['elipsTransformPrompt'] as String?,
        highScoreSuccessText: json['highScoreSuccessText'] as String?,
        highScoreFallbackText: json['highScoreFallbackText'] as String?,
        highScoreLowText: json['highScoreLowText'] as String?,
        highScoreMedText: json['highScoreMedText'] as String?,
        highScoreHighText: json['highScoreHighText'] as String?,
      );

  static Map<String, Map<String, String>>? _parseCustomBanks(dynamic json) {
    if (json == null) return null;
    final outer = json as Map<String, dynamic>;
    final result = <String, Map<String, String>>{};
    for (final entry in outer.entries) {
      final inner = entry.value as Map<String, dynamic>;
      result[entry.key] = inner.map((k, v) => MapEntry(k, v as String));
    }
    return result.isEmpty ? null : result;
  }

  static Map<String, String>? _parseCustomDuelBanks(dynamic json) {
    if (json == null) return null;
    final map = json as Map<String, dynamic>;
    final result = map.map((k, v) => MapEntry(k, v as String));
    return result.isEmpty ? null : result;
  }

  static Map<String, String>? _parseCustomFreeWillBanks(dynamic json) {
    if (json == null) return null;
    final map = json as Map<String, dynamic>;
    final result = map.map((k, v) => MapEntry(k, v as String));
    return result.isEmpty ? null : result;
  }

  static Map<String, String>? _parseCustomChoicesBanks(dynamic json) {
    if (json == null) return null;
    final map = json as Map<String, dynamic>;
    final result = map.map((k, v) => MapEntry(k, v as String));
    return result.isEmpty ? null : result;
  }

  Preset copyWith({
    String? id,
    String? name,
    PresetType? type,
    Language? language,
    PredictionMode? predictionMode,
    int? nbRounds,
    int? nbOptions,
    List<String>? labels,
    InputMode? inputMode,
    List<int>? performerSequence,
    bool clearSequence = false,
    StealthInputMethod? stealthInputMethod,
    TapLayout2? tapLayout2,
    TapLayout4? tapLayout4,
    NarratorVoice? narratorVoice,
    AddressMode? addressMode,
    String? spectatorName,
    String? actorName,
    String? participantName,
    bool clearSpectatorName = false,
    bool clearActorName = false,
    bool clearParticipantName = false,
    Map<String, Map<String, String>>? customPreprogrammedBanks,
    bool clearCustomPreprogrammedBanks = false,
    Map<String, String>? customDuelBankTemplates,
    bool clearCustomDuelBankTemplates = false,
    Map<String, String>? customChoicesBankTemplates,
    bool clearCustomChoicesBankTemplates = false,
    ChoicesNarrativeMode? choicesNarrativeMode,
    ChoicesNarrativeMode? duelNarrativeMode,
    DuelMode? duelMode,
    int? targetScore,
    FreeWillConfig? freeWillConfig,
    bool clearFreeWillConfig = false,
    Map<String, String>? customFreeWillBankTemplates,
    bool clearCustomFreeWillBankTemplates = false,
    String? freeWillBankMode,
    String? freeWillSingleTemplate,
    bool clearFreeWillSingleTemplate = false,
    List<String>? multipleOutTexts,
    List<String>? multipleOutTitles,
    List<String>? multipleOutKeywords,
    String? outputMode,
    String? imageAfterSave,
    Map<String, String>? bankImages,
    int? imageTimestampOffset,
    List<String>? swipePatterns,
    String? audioLocale,
    NumberMode? numberMode,
    String? numberFormula,
    bool? numberIncludeTime,
    int? numberMinutesOffset,
    String? numberOutputMode,
    String? numberNotesTemplate,
    String? assistantRedirectUrl,
    String? assistantInputMode,
    int? acrosticPosition,
    bool? autoCopyOverride,
    String? shortcutNameOverride,
    String? decoyTemplateId,
    String? decoyInputType,
    String? injectSuccessText,
    String? injectFallbackText,
    String? injectTransformPrompt,
    String? elipsSuccessText,
    String? elipsFallbackText,
    String? elipsTransformPrompt,
    String? highScoreSuccessText,
    String? highScoreFallbackText,
    String? highScoreLowText,
    String? highScoreMedText,
    String? highScoreHighText,
    DateTime? createdAt,
  }) {
    return Preset(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      language: language ?? this.language,
      predictionMode: predictionMode ?? this.predictionMode,
      nbRounds: nbRounds ?? this.nbRounds,
      nbOptions: nbOptions ?? this.nbOptions,
      labels: labels ?? List.from(this.labels),
      inputMode: inputMode ?? this.inputMode,
      performerSequence: clearSequence ? null : (performerSequence ?? this.performerSequence),
      stealthInputMethod: stealthInputMethod ?? this.stealthInputMethod,
      tapLayout2: tapLayout2 ?? this.tapLayout2,
      tapLayout4: tapLayout4 ?? this.tapLayout4,
      narratorVoice: narratorVoice ?? this.narratorVoice,
      addressMode: addressMode ?? this.addressMode,
      spectatorName: clearSpectatorName ? null : (spectatorName ?? this.spectatorName),
      actorName: clearActorName ? null : (actorName ?? this.actorName),
      participantName: clearParticipantName ? null : (participantName ?? this.participantName),
      customPreprogrammedBanks: clearCustomPreprogrammedBanks
          ? null
          : (customPreprogrammedBanks ?? this.customPreprogrammedBanks),
      customDuelBankTemplates: clearCustomDuelBankTemplates
          ? null
          : (customDuelBankTemplates ?? this.customDuelBankTemplates),
      customChoicesBankTemplates: clearCustomChoicesBankTemplates
          ? null
          : (customChoicesBankTemplates ?? this.customChoicesBankTemplates),
      choicesNarrativeMode: choicesNarrativeMode ?? this.choicesNarrativeMode,
      duelNarrativeMode: duelNarrativeMode ?? this.duelNarrativeMode,
      duelMode: duelMode ?? this.duelMode,
      targetScore: targetScore ?? this.targetScore,
      freeWillConfig: clearFreeWillConfig ? null : (freeWillConfig ?? this.freeWillConfig),
      customFreeWillBankTemplates: clearCustomFreeWillBankTemplates
          ? null
          : (customFreeWillBankTemplates ?? this.customFreeWillBankTemplates),
      freeWillBankMode: freeWillBankMode ?? this.freeWillBankMode,
      freeWillSingleTemplate: clearFreeWillSingleTemplate
          ? null
          : (freeWillSingleTemplate ?? this.freeWillSingleTemplate),
      multipleOutTexts: multipleOutTexts ?? this.multipleOutTexts,
      multipleOutTitles: multipleOutTitles ?? this.multipleOutTitles,
      multipleOutKeywords: multipleOutKeywords ?? this.multipleOutKeywords,
      outputMode: outputMode ?? this.outputMode,
      imageAfterSave: imageAfterSave ?? this.imageAfterSave,
      bankImages: bankImages ?? this.bankImages,
      imageTimestampOffset: imageTimestampOffset ?? this.imageTimestampOffset,
      swipePatterns: swipePatterns ?? this.swipePatterns,
      audioLocale: audioLocale ?? this.audioLocale,
      numberMode: numberMode ?? this.numberMode,
      numberFormula: numberFormula ?? this.numberFormula,
      numberIncludeTime: numberIncludeTime ?? this.numberIncludeTime,
      numberMinutesOffset: numberMinutesOffset ?? this.numberMinutesOffset,
      numberOutputMode: numberOutputMode ?? this.numberOutputMode,
      numberNotesTemplate: numberNotesTemplate ?? this.numberNotesTemplate,
      assistantRedirectUrl: assistantRedirectUrl ?? this.assistantRedirectUrl,
      assistantInputMode: assistantInputMode ?? this.assistantInputMode,
      acrosticPosition: acrosticPosition ?? this.acrosticPosition,
      autoCopyOverride: autoCopyOverride ?? this.autoCopyOverride,
      shortcutNameOverride: shortcutNameOverride ?? this.shortcutNameOverride,
      decoyTemplateId: decoyTemplateId ?? this.decoyTemplateId,
      decoyInputType: decoyInputType ?? this.decoyInputType,
      injectSuccessText: injectSuccessText ?? this.injectSuccessText,
      injectFallbackText: injectFallbackText ?? this.injectFallbackText,
      injectTransformPrompt: injectTransformPrompt ?? this.injectTransformPrompt,
      elipsSuccessText: elipsSuccessText ?? this.elipsSuccessText,
      elipsFallbackText: elipsFallbackText ?? this.elipsFallbackText,
      elipsTransformPrompt: elipsTransformPrompt ?? this.elipsTransformPrompt,
      highScoreSuccessText: highScoreSuccessText ?? this.highScoreSuccessText,
      highScoreFallbackText: highScoreFallbackText ?? this.highScoreFallbackText,
      highScoreLowText: highScoreLowText ?? this.highScoreLowText,
      highScoreMedText: highScoreMedText ?? this.highScoreMedText,
      highScoreHighText: highScoreHighText ?? this.highScoreHighText,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: this.updatedAt,
    );
  }

  /// Returns a new Preset with `updatedAt` set to now (for iCloud merge tracking).
  /// Preserves all fields identically.
  Preset withTimestampNow() {
    final now = DateTime.now().toUtc();
    return Preset.fromJson({...toJson(), 'updatedAt': now.toIso8601String()});
  }

  String? getCustomBankText(String performerKey, String spectatorKey) {
    return customPreprogrammedBanks?[performerKey]?[spectatorKey];
  }

  bool hasCustomBank(String performerKey) {
    final bank = customPreprogrammedBanks?[performerKey];
    if (bank == null) return false;
    return bank.values.any((text) => text.trim().isNotEmpty);
  }

  String? getCustomDuelBankText(String bucketKey) {
    return customDuelBankTemplates?[bucketKey];
  }

  bool get hasCustomDuelBank {
    if (customDuelBankTemplates == null) return false;
    return customDuelBankTemplates!.values.any((text) => text.trim().isNotEmpty);
  }

  int get customDuelBankCount {
    if (customDuelBankTemplates == null) return 0;
    return customDuelBankTemplates!.values.where((text) => text.trim().isNotEmpty).length;
  }

  String? getCustomChoicesBankText(String bucketKey) {
    return customChoicesBankTemplates?[bucketKey];
  }

  bool get hasCustomChoicesBank {
    if (customChoicesBankTemplates == null) return false;
    return customChoicesBankTemplates!.values.any((text) => text.trim().isNotEmpty);
  }

  int get customChoicesBankCount {
    if (customChoicesBankTemplates == null) return 0;
    return customChoicesBankTemplates!.values.where((text) => text.trim().isNotEmpty).length;
  }

  String? getCustomFreeWillBankText(String bucketKey) {
    return customFreeWillBankTemplates?[bucketKey];
  }

  bool get hasCustomFreeWillBank {
    // Validate against the SELECTED mode only — the user must fill the
    // option they chose. The other mode's data (if any) is ignored for
    // playability so the rocket icon reflects their actual setup.
    if (freeWillBankMode == 'single') {
      return freeWillSingleTemplate != null &&
          freeWillSingleTemplate!.trim().isNotEmpty;
    }
    // 'six' mode: at least one of the 6 per-permutation texts is filled.
    if (customFreeWillBankTemplates == null) return false;
    return customFreeWillBankTemplates!.values.any((text) => text.trim().isNotEmpty);
  }

  int get customFreeWillBankCount {
    if (customFreeWillBankTemplates == null) return 0;
    return customFreeWillBankTemplates!.values.where((text) => text.trim().isNotEmpty).length;
  }

  /// Check if any template text uses unresolved variables.
  bool _hasUnresolvedVariables(Map<String, String> templates) {
    for (final text in templates.values) {
      if (text.trim().isEmpty) continue;
      // Check whenTie variables - need round names
      final whenTiePattern = RegExp(r'\{whenTie(\d+)\}');
      for (final match in whenTiePattern.allMatches(text)) {
        final idx = int.parse(match.group(1)!);
        final roundNameKey = '__roundName_${idx}__';
        // We can't check exact round mapping here, but check if round names exist
        if (!templates.keys.any((k) => k.startsWith('__roundName_'))) return true;
      }
      // Check tieTextOrNoTieText - need at least one of the 3 tie tiers
      if (text.contains('{tieTextOrNoTieText}')) {
        if (!templates.containsKey('__tieText__') &&
            !templates.containsKey('__noTieText__') &&
            !templates.containsKey('__tieTextHigh__')) return true;
      }
    }
    return false;
  }

  /// Check if the preset is ready to play (all required texts are filled).
  bool get isPlayable {
    if (name.trim().isEmpty) return false;
    if (labels.any((l) => l.trim().isEmpty)) return false;

    // Clock-swipe input requires every option's pattern to share the same
    // number of swipes (otherwise runtime recognition is ambiguous).
    if (stealthInputMethod == StealthInputMethod.clockSwipe &&
        swipePatterns != null &&
        swipePatterns!.isNotEmpty) {
      final lengths = swipePatterns!
          .map((p) => p.split(',').where((s) => s.trim().isNotEmpty).length)
          .toSet();
      if (lengths.length != 1 || lengths.first == 0) return false;
    }

    if (type == PresetType.duel) {
      if (duelMode == DuelMode.fixedRounds) {
        // Score-based buckets: (R+1)(R+2)/2 entries
        final templates = customDuelBankTemplates ?? {};
        for (int s = 0; s <= nbRounds; s++) {
          for (int p = 0; p <= nbRounds - s; p++) {
            final key = '$nbRounds|$s-$p';
            if (templates[key]?.trim().isNotEmpty != true) return false;
          }
        }
        return true;
      } else {
        // First-To: 2*targetScore entries
        final templates = customDuelBankTemplates ?? {};
        for (int loser = 0; loser < targetScore; loser++) {
          if (templates['FT${targetScore}_S_$targetScore-$loser']?.trim().isNotEmpty != true) return false;
          if (templates['FT${targetScore}_P_$targetScore-$loser']?.trim().isNotEmpty != true) return false;
        }
        return true;
      }
    } else if (type == PresetType.choices) {
      // H/M pattern bank: 2^R entries
      final templates = customChoicesBankTemplates ?? {};
      final total = 1 << nbRounds; // 2^nbRounds
      for (int i = 0; i < total; i++) {
        final buf = StringBuffer();
        for (int bit = nbRounds - 1; bit >= 0; bit--) {
          buf.write((i >> bit) & 1 == 0 ? 'H' : 'M');
        }
        if (templates[buf.toString()]?.trim().isNotEmpty != true) return false;
      }
      return true;
    } else if (type == PresetType.freeWill) {
      return hasCustomFreeWillBank;
    } else if (type == PresetType.multipleOut) {
      if (multipleOutTexts == null || multipleOutTexts!.length < 2) return false;
      if (multipleOutTexts!.any((t) => t.trim().isEmpty)) return false;
      return true;
    }

    return true;
  }

  static int _pow(int base, int exp) {
    int result = 1;
    for (int i = 0; i < exp; i++) result *= base;
    return result;
  }

  factory Preset.empty({PresetType type = PresetType.choices}) {
    final defaultLabels = type.defaultLabels;
    return Preset(
      name: '',
      type: type,
      language: Language.english,
      predictionMode: PredictionMode.game,
      nbRounds: type == PresetType.freeWill ? 1 : 3,
      nbOptions: defaultLabels.length,
      labels: defaultLabels,
      inputMode: InputMode.preprogrammed,
      performerSequence: null,
      freeWillConfig: type == PresetType.freeWill
          ? FreeWillConfig.defaultConfig()
          : null,
    );
  }

  @override
  String toString() => 'Preset(id: $id, name: $name, type: $type, rounds: $nbRounds, options: $nbOptions)';
}
