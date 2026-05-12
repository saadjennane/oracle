/// Preprogrammed Bank Generator EN
///
/// Generates "starter" texts for preprogrammed banks.
/// Style: ultra direct, future tense, teasing.
/// No LLM, all local.

/// Generates a complete bank for a given performer sequence
/// [performerKey] e.g.: "RRL" for Right, Right, Left
/// [nbRounds] number of rounds (3 or 5)
/// [labels] the option labels (e.g.: ["Left", "Right"])
Map<String, String> generateStarterBankEN({
  required String performerKey,
  required int nbRounds,
  required List<String> labels,
}) {
  if (nbRounds != 3) {
    // For now we only support 3 rounds
    return {};
  }

  // For 3 rounds with 2 options, we have 8 possible combinations
  final spectatorKeys = _generateAllKeys(nbRounds);
  final bank = <String, String>{};

  for (final spectatorKey in spectatorKeys) {
    bank[spectatorKey] = _generateTextEN(
      performerKey: performerKey,
      spectatorKey: spectatorKey,
      labels: labels,
    );
  }

  return bank;
}

/// Generates all possible keys for n rounds (2 options)
List<String> _generateAllKeys(int nbRounds) {
  if (nbRounds == 3) {
    return ['RRR', 'RRL', 'RLR', 'RLL', 'LRR', 'LRL', 'LLR', 'LLL'];
  }
  // For 5 rounds, we'd have 32 combinations - not supported yet
  return [];
}

/// Generates a text for a performer/spectator combination
String _generateTextEN({
  required String performerKey,
  required String spectatorKey,
  required List<String> labels,
}) {
  // Calculate miss indices
  final missIndices = <int>[];
  for (int i = 0; i < performerKey.length; i++) {
    if (performerKey[i] != spectatorKey[i]) {
      missIndices.add(i);
    }
  }

  // Determine the "left" and "right" labels
  String leftLabel = labels.isNotEmpty ? labels[0].toLowerCase() : 'left';
  String rightLabel = labels.length > 1 ? labels[1].toLowerCase() : 'right';

  // Convert spectatorKey to readable description
  final spectatorDesc = _describeSequenceEN(spectatorKey, leftLabel, rightLabel);

  // Generate text based on number of misses
  final lines = <String>[];

  // Line 1: Announce spectator sequence
  lines.add(_getOpenerLineEN(spectatorKey, spectatorDesc, leftLabel, rightLabel));

  // Line 2: Teasing comment on tactics
  lines.add(_getTacticLineEN(spectatorKey, missIndices.length));

  // Line 3: Mention gifts if miss
  if (missIndices.isNotEmpty) {
    lines.add(_getGiftLineEN(missIndices, performerKey.length));
  }

  // Line 4: Free will punchline
  lines.add("In the end, you chose or you just thought you were choosing.");

  return lines.join('\n');
}

/// Describes a sequence in readable English
String _describeSequenceEN(String key, String left, String right) {
  final parts = <String>[];
  for (final c in key.split('')) {
    parts.add(c == 'R' ? right : left);
  }

  // Count consecutive repetitions
  if (key == 'RRR') return 'the all-$right technique';
  if (key == 'LLL') return '$left from start to finish';
  if (key == 'RLR' || key == 'LRL') return 'the classic zigzag: ${parts.join(', ')}';

  // Pattern with repetition
  if (key.startsWith('RR')) return 'twice $right, then $left';
  if (key.startsWith('LL')) return 'twice $left, then $right';
  if (key.endsWith('RR')) return '$left, then twice $right';
  if (key.endsWith('LL')) return '$right, then twice $left';

  return parts.join(', then ');
}

/// Opening line based on sequence
String _getOpenerLineEN(String key, String desc, String left, String right) {
  if (key == 'RRR' || key == 'LLL') {
    final side = key == 'RRR' ? right : left;
    return "You'll use the famous stay-on-the-same-hand technique, $side, to try to get me.";
  }
  if (key == 'RLR' || key == 'LRL') {
    return "If my conditioning worked, you'll do $desc.";
  }
  return "You'll do $desc.";
}

/// Teasing comment line
String _getTacticLineEN(String key, int missCount) {
  if (missCount == 0) {
    return "It's a bold tactic that could have worked, but never against a mentalist.";
  }
  if (key == 'RRR' || key == 'LLL') {
    return "It can work, but never against a mentalist.";
  }
  return "Bold move.";
}

/// Line mentioning gifts (intentional misses)
String _getGiftLineEN(List<int> missIndices, int totalRounds) {
  if (missIndices.length == totalRounds) {
    return "I'll miss on purpose the whole way, just to let you enjoy thinking you beat a mentalist.\nExcept beating a mentalist is much harder than you think.";
  }

  if (missIndices.length == 1) {
    final roundNum = missIndices[0] + 1;
    if (roundNum == 1) {
      return "I'll give you a gift by losing the first round, just to build your confidence.";
    } else if (roundNum == 2) {
      return "I'll let you win the second round just to give you the pleasure of thinking your switch got me.";
    } else {
      return "I'll let you win the last round, just to give you that pleasure.\nExcept even that mistake was planned.";
    }
  }

  if (missIndices.length == 2) {
    if (missIndices.contains(0) && missIndices.contains(2)) {
      return "I'll lose on purpose at the start and the end, just to give you that satisfaction.";
    }
    if (missIndices.contains(1) && missIndices.contains(2)) {
      return "I'll guess the first one, then lose on purpose on the last two to give you that pleasure.";
    }
    return "I'll lose on purpose twice, just to give you that satisfaction.";
  }

  return "I'll let you have a few rounds, just to give you the impression your strategy is working.";
}

/// Hardcoded starter texts for RRL (used as fallback/reference)
const Map<String, String> rrlStarterTextsEN = {
  'RRR': '''You'll use the famous stay-on-the-same-hand technique, right, to try to get me.
I'll let you win the last round, just to give you that pleasure.
Except even that mistake was planned.
In the end, you chose or you just thought you were choosing.''',

  'RRL': '''You'll do right, right, then left at the end.
It's a bold tactic that could have worked, but never against a mentalist.
In the end, you chose or you just thought you were choosing.''',

  'RLR': '''If my conditioning worked, you'll do the zigzag right, left, right.
I'll guess the first one, then lose on purpose on the last two to give you that pleasure.
In the end, you chose or you just thought you were choosing.''',

  'RLL': '''You'll do right, then twice left.
I'll let you win the second round just to give you the pleasure of thinking your switch got me.
In the end, you chose or you just thought you were choosing.''',

  'LRR': '''You'll do left, then twice right.
I'll lose on purpose at the start and the end, just to give you that satisfaction.
In the end, you chose or you just thought you were choosing.''',

  'LRL': '''You'll do left, then right, then left.
I'll give you a gift by losing the first round, just to build your confidence.
In the end, you chose or you just thought you were choosing.''',

  'LLR': '''You'll do left, left, then right.
I'll miss on purpose the whole way, just to let you enjoy thinking you beat a mentalist.
Except beating a mentalist is much harder than you think.
In the end, you chose or you just thought you were choosing.''',

  'LLL': '''You'll stay on left from start to finish.
I'll let you have the first two rounds, just to give you the impression your strategy is working.
It can work, but never against a mentalist.
In the end, you chose or you just thought you were choosing.''',
};
