/// Générateur de Starter Pack CHOICES — Mode Buckets — Direct — FR
///
/// Génère une banque de textes pour CHOICES en mode bucket (hits/misses).
/// Pour R rounds, génère R+1 buckets: H0 à HR.
/// Chaque bucket contient UN SEUL texte avec placeholder {spectatorSequenceLabeled}.
///
/// Style: Direct (phrases courtes, futur, tapé vite)
/// Langue: FR uniquement

/// Génère la banque de textes bucket pour CHOICES (style Direct)
///
/// [rounds] : nombre de rounds (1-10)
///
/// Retourne une Map<String, String> où:
/// - key = bucket ID (ex: "H0", "H1", "H2", ...)
/// - value = texte généré avec placeholder {spectatorSequenceLabeled}
Map<String, String> generateChoicesBucketDirectFR({
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

/// Construit le texte pour un bucket donné
String _buildBucketText({
  required int hits,
  required int misses,
  required int rounds,
}) {
  final lines = <String>[];

  // L1: Séquence spectateur (placeholder remplacé au runtime)
  lines.add('Tu vas faire {spectatorSequenceLabeled}.');

  // L2: Ligne hits
  if (hits == rounds) {
    lines.add('Je vais tout deviner.');
  } else if (hits == 0) {
    lines.add('Je ne vais rien deviner.');
  } else if (hits == 1) {
    lines.add('Je vais deviner une seule fois.');
  } else {
    lines.add('Je vais deviner $hits fois.');
  }

  // L3: Ligne misses (uniquement si misses > 0)
  if (misses > 0) {
    if (misses == 1) {
      lines.add(
          'Je vais te laisser une fois, juste pour te laisser ce petit plaisir.');
    } else {
      lines.add(
          'Je vais te laisser $misses fois, juste pour te laisser ce petit plaisir.');
    }
  }

  // L4: Signature (toujours)
  lines.add(
      "Et c'était ça le vrai truc, te laisser croire que c'est toi qui décides.");

  return lines.join('\n');
}
