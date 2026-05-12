/// Générateur de Starter Pack CHOICES — Mode Buckets — Taquin — FR
///
/// Génère une banque de textes pour CHOICES en mode bucket (hits/misses).
/// Pour R rounds, génère R+1 buckets: H0 à HR.
/// Chaque bucket contient UN SEUL texte avec placeholder {spectatorSequenceLabeled}.
///
/// Style: Taquin (pique mentaliste, léger, futur)
/// Langue: FR uniquement

Map<String, String> generateChoicesBucketTaquinFR({
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

  // L1: Séquence spectateur (placeholder)
  lines.add('Tu vas faire {spectatorSequenceLabeled}.');

  // L2: Hits
  if (hits == rounds) {
    lines.add('Je vais tout deviner.');
  } else if (hits == 0) {
    lines.add('Je ne vais rien deviner.');
  } else if (hits == 1) {
    lines.add('Je vais deviner une seule fois.');
  } else {
    lines.add('Je vais deviner $hits fois.');
  }

  // L3: Cadeau taquin (si misses > 0)
  if (misses > 0) {
    if (misses == 1) {
      lines.add(
          'Et la dernière, je vais la rater exprès, juste pour te donner ce petit plaisir d\'avoir eu un mentaliste.');
    } else {
      lines.add(
          'Et je vais me tromper $misses fois, juste pour te donner ce petit plaisir d\'avoir eu un mentaliste.');
    }
  }

  // L4: Signature taquin
  lines.add('J\'espère que ça t\'a fait plaisir.');

  return lines.join('\n');
}
