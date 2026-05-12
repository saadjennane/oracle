/// Test script for Narrative Engine V2 - Generate 10 varied outputs
///
/// Run with: dart test/narrative_engine_v2_test.dart

import '../lib/models/models.dart';
import '../lib/engine/narrative_engine_v2/narrative_engine_v2.dart';
import '../lib/engine/narrative_engine_v2/casebook_fr.dart';

void main() {
  print('=' * 70);
  print('NARRATIVE ENGINE V2 - 10 VARIED OUTPUTS TEST');
  print('=' * 70);
  print('');

  final testCases = [
    // Test 1: DIRECT style, neutral tone, repeatHeavy pattern, allHit
    _TestCase(
      name: '1. DIRECT + neutral + repeatHeavy + allHit',
      spectator: ['Gauche', 'Gauche', 'Gauche'],
      performer: ['Gauche', 'Gauche', 'Gauche'],
      style: NarrativeStyleV2.direct,
      tone: NarrativeToneV2.neutral,
    ),
    // Test 2: DIRECT style, confident tone, alternating pattern, 1 miss
    _TestCase(
      name: '2. DIRECT + confident + alternating + 1miss',
      spectator: ['Gauche', 'Droite', 'Gauche'],
      performer: ['Gauche', 'Gauche', 'Gauche'],
      style: NarrativeStyleV2.direct,
      tone: NarrativeToneV2.confident,
    ),
    // Test 3: PSYCHOLOGIQUE style, humorous tone, oneSwitch pattern, 2 miss
    _TestCase(
      name: '3. PSYCHOLOGIQUE + humorous + oneSwitch + 2miss',
      spectator: ['Gauche', 'Droite', 'Droite'],
      performer: ['Gauche', 'Gauche', 'Gauche'],
      style: NarrativeStyleV2.psychologique,
      tone: NarrativeToneV2.humorous,
    ),
    // Test 4: PSYCHOLOGIQUE style, neutral tone, mixed pattern, allMiss
    _TestCase(
      name: '4. PSYCHOLOGIQUE + neutral + mixed + allMiss',
      spectator: ['Gauche', 'Droite', 'Gauche'],
      performer: ['Droite', 'Gauche', 'Droite'],
      style: NarrativeStyleV2.psychologique,
      tone: NarrativeToneV2.neutral,
    ),
    // Test 5: NARRATIF style, playfulMocking tone, repeatHeavy, allHit + dream flavor
    _TestCase(
      name: '5. NARRATIF + playfulMocking + repeatHeavy + dream flavor',
      spectator: ['Droite', 'Droite', 'Droite'],
      performer: ['Droite', 'Droite', 'Droite'],
      style: NarrativeStyleV2.narratif,
      tone: NarrativeToneV2.playfulMocking,
      flavor: NarrativeFlavorV2.dream,
    ),
    // Test 6: CARNET style, neutral tone, alternating pattern, 1 miss
    _TestCase(
      name: '6. CARNET + neutral + alternating + 1miss',
      spectator: ['Gauche', 'Droite', 'Gauche'],
      performer: ['Droite', 'Droite', 'Gauche'],
      style: NarrativeStyleV2.carnet,
      tone: NarrativeToneV2.neutral,
    ),
    // Test 7: DIRECT style, playfulMocking tone, oneSwitch, allMiss
    _TestCase(
      name: '7. DIRECT + playfulMocking + oneSwitch + allMiss',
      spectator: ['Gauche', 'Gauche', 'Droite'],
      performer: ['Droite', 'Droite', 'Gauche'],
      style: NarrativeStyleV2.direct,
      tone: NarrativeToneV2.playfulMocking,
    ),
    // Test 8: DIRECT style, confident tone, mixed pattern, 1 miss + future tense
    _TestCase(
      name: '8. DIRECT + confident + oneSwitch + future tense',
      spectator: ['Gauche', 'Droite', 'Droite'],
      performer: ['Gauche', 'Droite', 'Gauche'],
      style: NarrativeStyleV2.direct,
      tone: NarrativeToneV2.confident,
      tense: NarrativeTenseV2.future,
    ),
    // Test 9: NARRATIF style, humorous tone, oneSwitch, 2 miss + intuition flavor
    _TestCase(
      name: '9. NARRATIF + humorous + intuition flavor + 2miss',
      spectator: ['Droite', 'Droite', 'Gauche'],
      performer: ['Gauche', 'Droite', 'Droite'],
      style: NarrativeStyleV2.narratif,
      tone: NarrativeToneV2.humorous,
      flavor: NarrativeFlavorV2.intuition,
    ),
    // Test 10: CARNET style, playfulMocking tone, repeatHeavy, allHit
    _TestCase(
      name: '10. CARNET + playfulMocking + repeatHeavy + allHit',
      spectator: ['Gauche', 'Gauche', 'Gauche'],
      performer: ['Gauche', 'Gauche', 'Gauche'],
      style: NarrativeStyleV2.carnet,
      tone: NarrativeToneV2.playfulMocking,
    ),
  ];

  for (final testCase in testCases) {
    _runTestCase(testCase);
  }

  print('=' * 70);
  print('END OF TEST');
  print('=' * 70);
}

class _TestCase {
  final String name;
  final List<String> spectator;
  final List<String> performer;
  final NarrativeStyleV2 style;
  final NarrativeToneV2 tone;
  final NarrativeTenseV2 tense;
  final NarrativeFlavorV2? flavor;

  const _TestCase({
    required this.name,
    required this.spectator,
    required this.performer,
    required this.style,
    required this.tone,
    this.tense = NarrativeTenseV2.past,
    this.flavor,
  });
}

void _runTestCase(_TestCase testCase) {
  print('-' * 70);
  print('TEST: ${testCase.name}');
  print('-' * 70);

  // Create mock session
  final rounds = <RoundInput>[];
  for (int i = 0; i < testCase.spectator.length; i++) {
    rounds.add(RoundInput(
      roundNumber: i + 1,
      spectatorChoice: testCase.spectator[i],
      performerChoice: testCase.performer[i],
    ));
  }

  final session = GameSession(
    gameType: GameType.multiChoice,
    inputMode: InputMode.preprogrammed,
    options: ['Gauche', 'Droite'],
    player1Name: 'Performer',
    player2Name: 'Spectator',
    firstPerson: false,
    preprogrammedSequence: testCase.performer,
    rounds: rounds,
    totalRounds: rounds.length,
    language: Language.french,
    predictionMode: PredictionMode.game,
    narratorVoice: NarratorVoice.firstPerson,
    addressMode: AddressMode.you,
  );

  // Generate narrative
  final result = generateNarrativeV2(
    session: session,
    seed: testCase.name.hashCode.abs(),
  );

  // Calculate pattern for display
  int switches = 0;
  int maxStreak = 1, streak = 1;
  for (int i = 1; i < testCase.spectator.length; i++) {
    if (testCase.spectator[i] != testCase.spectator[i - 1]) {
      switches++;
      streak = 1;
    } else {
      streak++;
      if (streak > maxStreak) maxStreak = streak;
    }
  }
  String patternType;
  if (switches == 0) {
    patternType = 'repeatHeavy';
  } else if (switches == 1) {
    patternType = 'oneSwitch';
  } else if (switches == testCase.spectator.length - 1 && maxStreak == 1) {
    patternType = 'alternating';
  } else {
    patternType = 'mixed';
  }

  // Calculate hits/misses
  int hits = 0, misses = 0;
  final missIndices = <int>[];
  for (int i = 0; i < testCase.spectator.length; i++) {
    if (testCase.spectator[i] == testCase.performer[i]) {
      hits++;
    } else {
      misses++;
      missIndices.add(i + 1);
    }
  }

  print('');
  print('CONFIG:');
  print('  Style: ${testCase.style.name}');
  print('  Tone: ${testCase.tone.name}');
  print('  Tense: ${testCase.tense.name}');
  if (testCase.flavor != null) print('  Flavor: ${testCase.flavor!.name}');
  print('');
  print('DATA:');
  print('  Spectator: ${testCase.spectator.join(" → ")}');
  print('  Performer: ${testCase.performer.join(" → ")}');
  print('  Pattern: $patternType (switches=$switches)');
  print('  Hits: $hits, Misses: $misses ${missIndices.isNotEmpty ? "(rounds: ${missIndices.join(", ")})" : ""}');
  print('');
  print('TRACE:');
  print('  Hook: ${result.assemblyTrace.hookId}');
  if (result.assemblyTrace.performerLineId != null) {
    print('  PerformerLine: ${result.assemblyTrace.performerLineId}');
  }
  print('  PatternLine: ${result.assemblyTrace.patternLineId}');
  if (result.assemblyTrace.intentLineId != null) {
    print('  IntentLine: ${result.assemblyTrace.intentLineId}');
  }
  if (result.assemblyTrace.missLineId != null) {
    print('  MissLine: ${result.assemblyTrace.missLineId}');
  }
  print('  Closer: ${result.assemblyTrace.closerId}');
  print('');
  print('OUTPUT (${result.wordCount} words):');
  print('');
  print('  "${result.generatedText}"');
  print('');
}
