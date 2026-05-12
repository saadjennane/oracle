/// Starter Pack Generator CHOICES — Exact Sequences — Direct — EN
///
/// Generates a text bank for CHOICES (2 options, 1-5 rounds)
/// based on performer sequence and all possible spectator sequences.
///
/// Style: Direct (short sentences, future tense, quick)
/// Language: EN only

Map<String, String> generateChoicesExactDirectEN({
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

    final List<int> missPositions = [];
    final List<int> hitPositions = [];
    for (int r = 0; r < rounds; r++) {
      if (spectatorSeq[r] == performerSeq[r]) {
        hitPositions.add(r + 1);
      } else {
        missPositions.add(r + 1);
      }
    }

    final text = _buildTextDirect(
      spectatorSeq: spectatorSeq,
      label1: label1,
      label2: label2,
      missPositions: missPositions,
      hitPositions: hitPositions,
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

String _formatBlock(List<int> positions, int rounds) {
  if (positions.isEmpty) return '';
  final count = positions.length;
  final posSet = positions.toSet();

  if (count == rounds) return 'from start to finish';

  if (count == 1) {
    final pos = positions.first;
    if (pos == 1) return 'at the start';
    if (pos == rounds) return 'at the end';
    if (rounds == 3 && pos == 2) return 'in the middle';
    if (rounds == 4) {
      if (pos == 2) return 'after the start';
      if (pos == 3) return 'before the end';
    }
    if (rounds == 5) {
      if (pos == 2) return 'after the start';
      if (pos == 3) return 'in the middle';
      if (pos == 4) return 'before the end';
    }
    return 'in the middle';
  }

  if (count == 2) {
    final sorted = positions.toList()..sort();
    final first = sorted[0];
    final second = sorted[1];

    if (first == 1 && second == 2) return 'on the first two';
    if (first == rounds - 1 && second == rounds) return 'on the last two';
    if (rounds == 4 && first == 2 && second == 3) return 'in the middle';
    if (rounds == 5) {
      if (first == 2 && second == 3) return 'towards the start';
      if (first == 3 && second == 4) return 'towards the end';
    }
    if (first == 1 && second == rounds) return 'at the start and the end';
    if (first == 1) return 'at the start and in the middle';
    if (second == rounds) return 'in the middle and at the end';
    return 'in the middle';
  }

  if (count == 3) {
    final sorted = positions.toList()..sort();
    if (sorted[0] == 1 && sorted[1] == 2 && sorted[2] == 3) {
      return 'on the first three';
    }
    if (sorted[0] == rounds - 2 &&
        sorted[1] == rounds - 1 &&
        sorted[2] == rounds) {
      return 'on the last three';
    }
    if (sorted[0] == 1 && sorted[1] == 2 && sorted[2] == rounds) {
      return 'on the first two and at the end';
    }
    if (sorted[0] == 1 &&
        sorted[1] == rounds - 1 &&
        sorted[2] == rounds) {
      return 'at the start and on the last two';
    }
    if (sorted[0] == 1) return 'at the start and in the middle';
    if (sorted[2] == rounds) return 'in the middle and at the end';
    return 'in the middle';
  }

  if (count == 4 && rounds == 5) {
    if (!posSet.contains(5)) return 'on the first four';
    if (!posSet.contains(1)) return 'on the last four';
    final sorted = positions.toList()..sort();
    if (sorted[0] == 1 && sorted[1] == 2 && sorted[2] == 4 && sorted[3] == 5) {
      return 'on the first two and last two';
    }
    return 'almost everywhere';
  }

  return 'on several';
}

String _buildTextDirect({
  required List<int> spectatorSeq,
  required String label1,
  required String label2,
  required List<int> missPositions,
  required List<int> hitPositions,
  required int rounds,
}) {
  final lines = <String>[];
  final misses = missPositions.length;
  final hits = hitPositions.length;

  final spectatorLabels =
      spectatorSeq.map((v) => v == 1 ? label1 : label2).join(', ');
  lines.add('You will pick $spectatorLabels.');

  if (misses == 0) {
    lines.add("I will get everything right, because that's what I predicted.");
  } else if (hits == 0) {
    lines.add(
        'I will let you win from start to finish, I will get nothing right just to make you happy.');
  } else {
    final missBlock = _formatBlock(missPositions, rounds);
    final hitBlock = _formatBlock(hitPositions, rounds);
    lines.add('I will let you win $missBlock.');
    lines.add('I will get it right $hitBlock.');
  }

  lines.add(
      "And that was the real trick, letting you believe you are the one who decides.");

  return lines.join('\n');
}
