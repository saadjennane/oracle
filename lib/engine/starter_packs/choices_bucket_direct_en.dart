/// Starter Pack Generator CHOICES — Buckets — Direct — EN
///
/// Generates a text bank for CHOICES bucket mode (hits/misses).
/// For R rounds, generates R+1 buckets: H0 to HR.
/// Each bucket has ONE text with placeholder {spectatorSequenceLabeled}.
///
/// Style: Direct (short, future tense, quick)
/// Language: EN only

Map<String, String> generateChoicesBucketDirectEN({
  required int rounds,
}) {
  assert(rounds >= 1 && rounds <= 10, 'Rounds must be between 1 and 10');

  final Map<String, String> bank = {};

  for (int hits = 0; hits <= rounds; hits++) {
    final key = 'H$hits';
    final misses = rounds - hits;

    final text = _buildBucketText(hits: hits, misses: misses, rounds: rounds);
    bank[key] = text;
  }

  return bank;
}

String _buildBucketText({
  required int hits,
  required int misses,
  required int rounds,
}) {
  final lines = <String>[];

  lines.add('You will pick {spectatorSequenceLabeled}.');

  if (hits == rounds) {
    lines.add('I will guess everything.');
  } else if (hits == 0) {
    lines.add('I will guess nothing.');
  } else if (hits == 1) {
    lines.add('I will guess only once.');
  } else {
    lines.add('I will guess $hits times.');
  }

  if (misses > 0) {
    if (misses == 1) {
      lines.add(
          'I will let you have one, just to give you that little pleasure.');
    } else {
      lines.add(
          'I will let you have $misses, just to give you that little pleasure.');
    }
  }

  lines.add(
      "And that was the real trick, letting you believe you are the one who decides.");

  return lines.join('\n');
}
