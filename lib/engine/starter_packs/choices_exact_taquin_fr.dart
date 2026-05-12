/// Générateur de Starter Pack CHOICES — Séquences Exactes — Taquin — FR
///
/// Génère une banque de textes pour CHOICES (2 options, 1-5 rounds)
/// basée sur la séquence performer et toutes les séquences spectateur possibles.
///
/// Style: Taquin (playful/teasing)
/// Temps: Futur uniquement
/// Fin signature: "J'espère que ça t'a fait plaisir."

/// Génère la banque de textes pour séquences exactes CHOICES (style Taquin)
///
/// [label1] : label de l'option 1 (ex: "Droite", "A", "Téléphone")
/// [label2] : label de l'option 2 (ex: "Gauche", "B", "Clé")
/// [performerSeq] : séquence performer, longueur = rounds, valeurs 1 ou 2
///
/// Retourne une Map<String, String> où:
/// - key = séquence spectateur en string de '1'/'2' (ex: "1212")
/// - value = texte généré
Map<String, String> generateChoicesExactTaquinFR({
  required String label1,
  required String label2,
  required List<int> performerSeq,
}) {
  final rounds = performerSeq.length;
  assert(rounds >= 1 && rounds <= 5, 'Rounds must be between 1 and 5');
  assert(performerSeq.every((v) => v == 1 || v == 2), 'Performer sequence must contain only 1 or 2');

  final Map<String, String> bank = {};

  // Générer toutes les 2^rounds séquences spectateur
  final totalSequences = 1 << rounds; // 2^rounds

  for (int i = 0; i < totalSequences; i++) {
    final spectatorSeq = _intToSequence(i, rounds);
    final key = spectatorSeq.join();

    // Calculer hits/misses
    int hits = 0;
    for (int r = 0; r < rounds; r++) {
      if (spectatorSeq[r] == performerSeq[r]) {
        hits++;
      }
    }
    final misses = rounds - hits;

    // Construire le texte
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

/// Convertit un entier en séquence de choix (1 ou 2)
/// Ex: 5 en binaire = 101, pour rounds=3 => [2, 1, 2] (1-indexed: 1=premier bit 0, 2=bit 1)
List<int> _intToSequence(int value, int length) {
  final List<int> seq = [];
  for (int i = length - 1; i >= 0; i--) {
    // Bit à la position i (de gauche à droite)
    final bit = (value >> i) & 1;
    seq.add(bit == 0 ? 1 : 2);
  }
  return seq;
}

/// Convertit un nombre en texte français (1-5)
String _numberToFrenchText(int n) {
  switch (n) {
    case 1:
      return 'une fois';
    case 2:
      return 'deux fois';
    case 3:
      return 'trois fois';
    case 4:
      return 'quatre fois';
    case 5:
      return 'cinq fois';
    default:
      return '$n fois';
  }
}

/// Construit le texte pour une séquence spectateur donnée (style Taquin)
String _buildTextTaquin({
  required List<int> spectatorSeq,
  required String label1,
  required String label2,
  required int hits,
  required int misses,
  required int rounds,
}) {
  final lines = <String>[];

  // L1: Séquence spectateur avec labels
  final spectatorLabels = spectatorSeq.map((v) => v == 1 ? label1 : label2).join(', ');
  lines.add('Tu vas faire $spectatorLabels.');

  // L2: hitsText
  if (hits == rounds) {
    // All correct
    lines.add('Je vais deviner tout.');
  } else if (hits == 0) {
    // None correct
    lines.add('Je ne vais rien deviner.');
  } else {
    // Partial hits
    lines.add('Je vais deviner ${_numberToFrenchText(hits)}.');
  }

  // L3: missLineTaquin (uniquement si misses > 0)
  if (misses > 0) {
    if (misses == 1 && hits > 0) {
      // Exactly one miss (and at least one hit) - use "la dernière" phrasing
      lines.add('Et la dernière, je vais la rater exprès, juste pour te donner ce petit plaisir d\'avoir eu un mentaliste.');
    } else {
      // Multiple misses OR all misses (hits == 0) - use "me tromper" phrasing
      lines.add('Et je vais me tromper ${_numberToFrenchText(misses)}, juste pour te donner ce petit plaisir d\'avoir eu un mentaliste.');
    }
  }

  // L4: Fin signature Taquin
  lines.add('J\'espère que ça t\'a fait plaisir.');

  return lines.join('\n');
}
