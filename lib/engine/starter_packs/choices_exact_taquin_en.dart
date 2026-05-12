/// Starter Pack Generator CHOICES — Exact Sequences — Taquin — EN
///
/// Generates a text bank for CHOICES (2 options, 1-5 rounds)
/// based on performer sequence and all possible spectator sequences.
///
/// Style: Taquin (playful teasing, mentalist vibe)
/// Language: EN only

Map<String, String> generateChoicesExactTaquinEN({
  required String label1,
  required String label2,
  required List<int> performerSeq,
}) {
  final rounds = performerSeq.length;
  assert(rounds >= 1 && rounds <= 5, 'Rounds must be between 1 and 5');
  assert(performerSeq.every((v) => v == 1 || v == 2),
      'Performer sequence must contain only 1 or 2');

  final Map<String, String> bank = {};
  final totalSequences = 1 << rounds;

  for (int i = 0; i < totalSequences; i++) {
    final spectatorSeq = _intToSequence(i, rounds);
    final key = spectatorSeq.join();

    int hits = 0;
    for (int r = 0; r < rounds; r++) {
      if (spectatorSeq[r] == performerSeq[r]) hits++;
    }
    final misses = rounds - hits;

    final text = _buildTextTaquin(
      spectatorSeq: spectatorSeq,
      label1: label1,
      label2: label2,
      hits: hits,
      misses: misses,
      rounds: rounds,
    );

    bank[key] = text;
  }

  return bank;
}

List<int> _intToSequence(int value, int length) {
  final List<int> seq = [];
  for (int i = length - 1; i >= 0; i--) {
    final bit = (value >> i) & 1;
    seq.add(bit == 0 ? 1 : 2);
  }
  return seq;
}

String _numberToEnglishText(int n) {
  switch (n) {
    case 1:
      return 'once';
    case 2:
      return 'twice';
    case 3:
      return 'three times';
    case 4:
      return 'four times';
    case 5:
      return 'five times';
    default:
      return '$n times';
  }
}

String _buildTextTaquin({
  required List<int> spectatorSeq,
  required String label1,
  required String label2,
  required int hits,
  required int misses,
  required int rounds,
}) {
  final lines = <String>[];

  final spectatorLabels =
      spectatorSeq.map((v) => v == 1 ? label1 : label2).join(', ');
  lines.add('You will pick $spectatorLabels.');

  if (hits == rounds) {
    lines.add('I will guess everything.');
  } else if (hits == 0) {
    lines.add('I will guess nothing.');
  } else {
    lines.add('I will guess ${_numberToEnglishText(hits)}.');
  }

  if (misses > 0) {
    if (misses == 1 && hits > 0) {
      lines.add(
          'And the last one, I will miss on purpose, just to give you that little thrill of having had a mentalist.');
    } else {
      lines.add(
          'And I will get it wrong ${_numberToEnglishText(misses)}, just to give you that little thrill of having had a mentalist.');
    }
  }

  lines.add('I hope you enjoyed it.');

  return lines.join('\n');
}
