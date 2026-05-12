/// Starter Pack Generator CHOICES — Buckets — Taquin — EN
///
/// Generates a text bank for CHOICES bucket mode (hits/misses).
/// For R rounds, generates R+1 buckets: H0 to HR.
/// Each bucket has ONE text with placeholder {spectatorSequenceLabeled}.
///
/// Style: Taquin (playful teasing, mentalist vibe)
/// Language: EN only

Map<String, String> generateChoicesBucketTaquinEN({
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
          'And the last one, I will miss on purpose, just to give you that little thrill of having had a mentalist.');
    } else {
      lines.add(
          'And I will get it wrong $misses times, just to give you that little thrill of having had a mentalist.');
    }
  }

  lines.add('I hope you enjoyed it.');

  return lines.join('\n');
}
