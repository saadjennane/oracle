import 'package:uuid/uuid.dart';
import 'appellation.dart';
import 'choices_narrative_mode.dart';
import 'duel_mode.dart';
import 'preprogrammed_tie_strategy.dart';
import 'game_type.dart';
import 'input_mode.dart';
import 'language.dart';
import 'round_input.dart';
import 'computed_result.dart';
import 'prediction_mode.dart';

class GameSession {
  final String id;
  final DateTime createdAt;
  final GameType gameType;
  final InputMode inputMode;
  final List<String> options;
  final String player1Name;
  final String player2Name;
  final bool firstPerson;
  final List<String>? preprogrammedSequence;
  final List<RoundInput> rounds;
  final ComputedResult? computed;
  final int totalRounds;
  final Language language;
  final PredictionMode predictionMode;
  final int? narrativeSeed;

  // Appellation fields
  final NarratorVoice narratorVoice;
  final AddressMode addressMode;
  final String? spectatorName;
  final String? actorName;
  final String? participantName;

  // Custom preprogrammed banks copied from preset
  final Map<String, Map<String, String>>? customPreprogrammedBanks;

  // Custom duel bank templates copied from preset
  final Map<String, String>? customDuelBankTemplates;

  // Custom CHOICES bank templates copied from preset
  final Map<String, String>? customChoicesBankTemplates;

  // CHOICES narrative mode (buckets vs sequences)
  final ChoicesNarrativeMode choicesNarrativeMode;

  // Duel narrative mode (buckets vs sequences) - fixedRounds only
  final ChoicesNarrativeMode duelNarrativeMode;

  // Duel mode settings (DUEL ONLY)
  final DuelMode duelMode;
  final int targetScore;
  final PreprogrammedTieStrategy preprogrammedTieStrategy;

  GameSession({
    String? id,
    DateTime? createdAt,
    required this.gameType,
    required this.inputMode,
    required this.options,
    this.player1Name = 'Me',
    this.player2Name = 'You',
    this.firstPerson = true,
    this.preprogrammedSequence,
    this.rounds = const [],
    this.computed,
    this.totalRounds = 3,
    this.language = Language.english,
    this.predictionMode = PredictionMode.game,
    this.narrativeSeed,
    this.narratorVoice = NarratorVoice.firstPerson,
    this.addressMode = AddressMode.you,
    this.spectatorName,
    this.actorName,
    this.participantName,
    this.customPreprogrammedBanks,
    this.customDuelBankTemplates,
    this.customChoicesBankTemplates,
    this.choicesNarrativeMode = ChoicesNarrativeMode.buckets,
    this.duelNarrativeMode = ChoicesNarrativeMode.buckets,
    this.duelMode = DuelMode.fixedRounds,
    this.targetScore = 3,
    this.preprogrammedTieStrategy = PreprogrammedTieStrategy.repeat,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  bool get isComplete => rounds.length == totalRounds && computed != null;
  bool get hasAllRounds => rounds.length == totalRounds;
  int get currentRoundNumber => rounds.length + 1;
  bool get isDuel => gameType == GameType.duel;
  bool get isPreprogrammed => inputMode == InputMode.preprogrammed;

  String getPerformerChoice(int roundIndex) {
    // For First-To preprogrammed: ties don't consume the sequence
    if (isFirstTo && isPreprogrammed && preprogrammedSequence != null) {
      return _getFirstToPerformerChoice(roundIndex);
    }

    // Standard preprogrammed: direct index mapping
    if (isPreprogrammed && preprogrammedSequence != null && roundIndex < preprogrammedSequence!.length) {
      return preprogrammedSequence![roundIndex];
    }
    if (roundIndex < rounds.length) {
      return rounds[roundIndex].performerChoice ?? '';
    }
    return '';
  }

  String _getFirstToPerformerChoice(int roundIndex) {
    if (preprogrammedSequence == null || preprogrammedSequence!.isEmpty) return '';

    int sequenceIndex = 0;
    int cycleOffset = 0; // For cycle strategy: how many ties since last score

    for (int i = 0; i < roundIndex && i < rounds.length; i++) {
      final spectatorChoice = rounds[i].spectatorChoice;
      final baseChoice = preprogrammedSequence![sequenceIndex.clamp(0, preprogrammedSequence!.length - 1)];

      // Determine what the performer actually played this round
      String actualPerformerChoice;
      if (preprogrammedTieStrategy == PreprogrammedTieStrategy.cycle && cycleOffset > 0) {
        // Cycling: offset from the base choice in the options list
        final baseIdx = options.indexOf(baseChoice);
        actualPerformerChoice = options[(baseIdx + cycleOffset) % options.length];
      } else {
        actualPerformerChoice = baseChoice;
      }

      if (spectatorChoice == actualPerformerChoice) {
        // Tie: don't advance sequence
        if (preprogrammedTieStrategy == PreprogrammedTieStrategy.cycle) {
          cycleOffset++; // Next tie will try the next option
        }
      } else {
        // Point scored: advance sequence, reset cycle
        sequenceIndex++;
        cycleOffset = 0;
      }
    }

    // Return the choice for the current round
    final baseChoice = preprogrammedSequence![sequenceIndex.clamp(0, preprogrammedSequence!.length - 1)];
    if (preprogrammedTieStrategy == PreprogrammedTieStrategy.cycle && cycleOffset > 0) {
      final baseIdx = options.indexOf(baseChoice);
      return options[(baseIdx + cycleOffset) % options.length];
    }
    return baseChoice;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'createdAt': createdAt.toIso8601String(),
        'gameType': gameType.name,
        'inputMode': inputMode.name,
        'options': options,
        'player1Name': player1Name,
        'player2Name': player2Name,
        'firstPerson': firstPerson,
        'preprogrammedSequence': preprogrammedSequence,
        'rounds': rounds.map((r) => r.toJson()).toList(),
        'computed': computed?.toJson(),
        'totalRounds': totalRounds,
        'language': language.name,
        'predictionMode': predictionMode.name,
        'narrativeSeed': narrativeSeed,
        'narratorVoice': narratorVoice.name,
        'addressMode': addressMode.name,
        'spectatorName': spectatorName,
        'actorName': actorName,
        'participantName': participantName,
        'customPreprogrammedBanks': customPreprogrammedBanks,
        'customDuelBankTemplates': customDuelBankTemplates,
        'customChoicesBankTemplates': customChoicesBankTemplates,
        'choicesNarrativeMode': choicesNarrativeMode.toJson(),
        'duelNarrativeMode': duelNarrativeMode.toJson(),
        'duelMode': duelMode.toJson(),
        'targetScore': targetScore,
        'preprogrammedTieStrategy': preprogrammedTieStrategy.toJson(),
      };

  factory GameSession.fromJson(Map<String, dynamic> json) => GameSession(
        id: json['id'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        gameType: GameType.fromString(json['gameType'] as String),
        inputMode: InputMode.fromString(json['inputMode'] as String),
        options: (json['options'] as List).cast<String>(),
        player1Name: json['player1Name'] as String? ?? 'Me',
        player2Name: json['player2Name'] as String? ?? 'You',
        firstPerson: json['firstPerson'] as bool? ?? true,
        preprogrammedSequence:
            (json['preprogrammedSequence'] as List?)?.cast<String>(),
        rounds: (json['rounds'] as List)
            .map((r) => RoundInput.fromJson(r as Map<String, dynamic>))
            .toList(),
        computed: json['computed'] != null
            ? ComputedResult.fromJson(json['computed'] as Map<String, dynamic>)
            : null,
        totalRounds: json['totalRounds'] as int? ?? 3,
        language: Language.fromString(json['language'] as String? ?? 'english'),
        predictionMode: PredictionMode.fromJson(json['predictionMode'] as String? ?? 'game'),
        narrativeSeed: json['narrativeSeed'] as int?,
        narratorVoice: NarratorVoice.fromJson(json['narratorVoice'] as String?),
        addressMode: AddressMode.fromJson(json['addressMode'] as String?),
        spectatorName: json['spectatorName'] as String?,
        actorName: json['actorName'] as String?,
        participantName: json['participantName'] as String?,
        customPreprogrammedBanks: _parseCustomBanks(json['customPreprogrammedBanks']),
        customDuelBankTemplates: _parseCustomDuelBanks(json['customDuelBankTemplates']),
        customChoicesBankTemplates: _parseCustomChoicesBanks(json['customChoicesBankTemplates']),
        choicesNarrativeMode: ChoicesNarrativeMode.fromJson(json['choicesNarrativeMode'] as String?),
        duelNarrativeMode: ChoicesNarrativeMode.fromJson(json['duelNarrativeMode'] as String?),
        duelMode: DuelMode.fromJson(json['duelMode'] as String?),
        targetScore: json['targetScore'] as int? ?? 3,
        preprogrammedTieStrategy: PreprogrammedTieStrategy.fromJson(json['preprogrammedTieStrategy'] as String?),
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

  static Map<String, String>? _parseCustomChoicesBanks(dynamic json) {
    if (json == null) return null;
    final map = json as Map<String, dynamic>;
    final result = map.map((k, v) => MapEntry(k, v as String));
    return result.isEmpty ? null : result;
  }

  GameSession copyWith({
    String? id,
    DateTime? createdAt,
    GameType? gameType,
    InputMode? inputMode,
    List<String>? options,
    String? player1Name,
    String? player2Name,
    bool? firstPerson,
    List<String>? preprogrammedSequence,
    List<RoundInput>? rounds,
    ComputedResult? computed,
    int? totalRounds,
    Language? language,
    PredictionMode? predictionMode,
    int? narrativeSeed,
    NarratorVoice? narratorVoice,
    AddressMode? addressMode,
    String? spectatorName,
    String? actorName,
    String? participantName,
    Map<String, Map<String, String>>? customPreprogrammedBanks,
    Map<String, String>? customDuelBankTemplates,
    Map<String, String>? customChoicesBankTemplates,
    ChoicesNarrativeMode? choicesNarrativeMode,
    ChoicesNarrativeMode? duelNarrativeMode,
    DuelMode? duelMode,
    int? targetScore,
    PreprogrammedTieStrategy? preprogrammedTieStrategy,
  }) {
    return GameSession(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      gameType: gameType ?? this.gameType,
      inputMode: inputMode ?? this.inputMode,
      options: options ?? this.options,
      player1Name: player1Name ?? this.player1Name,
      player2Name: player2Name ?? this.player2Name,
      firstPerson: firstPerson ?? this.firstPerson,
      preprogrammedSequence:
          preprogrammedSequence ?? this.preprogrammedSequence,
      rounds: rounds ?? this.rounds,
      computed: computed ?? this.computed,
      totalRounds: totalRounds ?? this.totalRounds,
      language: language ?? this.language,
      predictionMode: predictionMode ?? this.predictionMode,
      narrativeSeed: narrativeSeed ?? this.narrativeSeed,
      narratorVoice: narratorVoice ?? this.narratorVoice,
      addressMode: addressMode ?? this.addressMode,
      spectatorName: spectatorName ?? this.spectatorName,
      actorName: actorName ?? this.actorName,
      participantName: participantName ?? this.participantName,
      customPreprogrammedBanks: customPreprogrammedBanks ?? this.customPreprogrammedBanks,
      customDuelBankTemplates: customDuelBankTemplates ?? this.customDuelBankTemplates,
      customChoicesBankTemplates: customChoicesBankTemplates ?? this.customChoicesBankTemplates,
      choicesNarrativeMode: choicesNarrativeMode ?? this.choicesNarrativeMode,
      duelNarrativeMode: duelNarrativeMode ?? this.duelNarrativeMode,
      duelMode: duelMode ?? this.duelMode,
      targetScore: targetScore ?? this.targetScore,
      preprogrammedTieStrategy: preprogrammedTieStrategy ?? this.preprogrammedTieStrategy,
    );
  }

  bool get isFirstTo => duelMode == DuelMode.firstTo && gameType == GameType.duel;

  String? getCustomBankText(String performerKey, String spectatorKey) {
    return customPreprogrammedBanks?[performerKey]?[spectatorKey];
  }

  String? getCustomDuelBankText(String bucketKey) {
    return customDuelBankTemplates?[bucketKey];
  }

  String? getCustomChoicesBankText(String bucketKey) {
    return customChoicesBankTemplates?[bucketKey];
  }

  GameSession addRound(RoundInput round) {
    return copyWith(rounds: [...rounds, round]);
  }

  GameSession removeLastRound() {
    if (rounds.isEmpty) return this;
    return copyWith(rounds: rounds.sublist(0, rounds.length - 1));
  }

  GameSession clearRounds() {
    return copyWith(rounds: []);
  }

  @override
  String toString() =>
      'GameSession(id: $id, type: $gameType, rounds: ${rounds.length}/$totalRounds)';
}
