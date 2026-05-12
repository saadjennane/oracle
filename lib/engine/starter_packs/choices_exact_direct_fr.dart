/// Générateur de Starter Pack CHOICES — Séquences Exactes — Direct — FR
///
/// Génère une banque de textes pour CHOICES (2 options, 1-5 rounds)
/// basée sur la séquence performer et toutes les séquences spectateur possibles.
///
/// Style: Direct (phrases courtes, blocs naturels, tapé vite)
/// Temps: Futur uniquement
/// Format: 3-4 lignes (L1: séquence, L2: miss, L3: hit, L4: signature)

/// Génère la banque de textes pour séquences exactes CHOICES (style Direct)
///
/// [label1] : label de l'option 1 (ex: "Droite", "A", "Téléphone")
/// [label2] : label de l'option 2 (ex: "Gauche", "B", "Clé")
/// [performerSeq] : séquence performer, longueur = rounds, valeurs 1 ou 2
///
/// Retourne une Map<String, String> où:
/// - key = séquence spectateur en string de '1'/'2' (ex: "1212")
/// - value = texte généré
Map<String, String> generateChoicesExactDirectFR({
  required String label1,
  required String label2,
  required List<int> performerSeq,
}) {
  final rounds = performerSeq.length;
  assert(rounds >= 1 && rounds <= 5, 'Rounds must be between 1 and 5');
  assert(performerSeq.every((v) => v == 1 || v == 2),
      'Performer sequence must contain only 1 or 2');

  final Map<String, String> bank = {};

  // Générer toutes les 2^rounds séquences spectateur
  final totalSequences = 1 << rounds; // 2^rounds

  for (int i = 0; i < totalSequences; i++) {
    final spectatorSeq = _intToSequence(i, rounds);
    final key = spectatorSeq.join();

    // Calculer les positions des miss et hits (1-indexed pour la logique de blocs)
    final List<int> missPositions = [];
    final List<int> hitPositions = [];
    for (int r = 0; r < rounds; r++) {
      if (spectatorSeq[r] == performerSeq[r]) {
        hitPositions.add(r + 1); // 1-indexed
      } else {
        missPositions.add(r + 1); // 1-indexed
      }
    }

    // Construire le texte
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

/// Convertit un entier en séquence de choix (1 ou 2)
List<int> _intToSequence(int value, int length) {
  final List<int> seq = [];
  for (int i = length - 1; i >= 0; i--) {
    final bit = (value >> i) & 1;
    seq.add(bit == 0 ? 1 : 2);
  }
  return seq;
}

/// Formate un ensemble de positions en bloc naturel
/// Positions sont 1-indexed (1 = premier, N = dernier)
String _formatBlock(List<int> positions, int rounds) {
  if (positions.isEmpty) return '';

  final posSet = positions.toSet();
  final count = positions.length;

  // Cas: toutes les positions
  if (count == rounds) {
    return 'du début à la fin';
  }

  // Cas: une seule position
  if (count == 1) {
    final pos = positions.first;
    if (pos == 1) return 'au début';
    if (pos == rounds) return 'à la fin';
    if (rounds == 3 && pos == 2) return 'au milieu';
    if (rounds == 4) {
      if (pos == 2) return 'après le début';
      if (pos == 3) return 'avant la fin';
    }
    if (rounds == 5) {
      if (pos == 2) return 'après le début';
      if (pos == 3) return 'au milieu';
      if (pos == 4) return 'avant la fin';
    }
    return 'au milieu';
  }

  // Cas: deux positions
  if (count == 2) {
    final sorted = positions.toList()..sort();
    final first = sorted[0];
    final second = sorted[1];

    // Consécutifs depuis le début
    if (first == 1 && second == 2) {
      return 'sur les deux premiers';
    }

    // Consécutifs à la fin
    if (first == rounds - 1 && second == rounds) {
      return 'sur les deux derniers';
    }

    // Milieu (pour N=4: positions 2,3)
    if (rounds == 4 && first == 2 && second == 3) {
      return 'au milieu';
    }

    // Milieu (pour N=5: positions 2,3 ou 3,4)
    if (rounds == 5) {
      if (first == 2 && second == 3) return 'vers le début';
      if (first == 3 && second == 4) return 'vers la fin';
    }

    // Début et fin
    if (first == 1 && second == rounds) {
      return 'au début et à la fin';
    }

    // Début + position intermédiaire
    if (first == 1) {
      if (second == rounds - 1) return 'au début et avant la fin';
      return 'au début et au milieu';
    }

    // Position intermédiaire + fin
    if (second == rounds) {
      if (first == 2) return 'après le début et à la fin';
      return 'au milieu et à la fin';
    }

    // Deux positions intermédiaires
    return 'au milieu';
  }

  // Cas: trois positions
  if (count == 3) {
    final sorted = positions.toList()..sort();

    // Trois premiers consécutifs
    if (sorted[0] == 1 && sorted[1] == 2 && sorted[2] == 3) {
      return 'sur les trois premiers';
    }

    // Trois derniers consécutifs
    if (sorted[0] == rounds - 2 &&
        sorted[1] == rounds - 1 &&
        sorted[2] == rounds) {
      return 'sur les trois derniers';
    }

    // Deux premiers + fin
    if (sorted[0] == 1 && sorted[1] == 2 && sorted[2] == rounds) {
      return 'sur les deux premiers et à la fin';
    }

    // Début + deux derniers
    if (sorted[0] == 1 &&
        sorted[1] == rounds - 1 &&
        sorted[2] == rounds) {
      return 'au début et sur les deux derniers';
    }

    // Autres cas avec début
    if (sorted[0] == 1) {
      return 'au début et au milieu';
    }

    // Autres cas avec fin
    if (sorted[2] == rounds) {
      return 'au milieu et à la fin';
    }

    return 'au milieu';
  }

  // Cas: quatre positions (N=5)
  if (count == 4 && rounds == 5) {
    final sorted = positions.toList()..sort();

    // Quatre premiers
    if (!posSet.contains(5)) {
      return 'sur les quatre premiers';
    }

    // Quatre derniers
    if (!posSet.contains(1)) {
      return 'sur les quatre derniers';
    }

    // Trois premiers + fin
    if (sorted[0] == 1 && sorted[1] == 2 && sorted[2] == 3 && sorted[3] == 5) {
      return 'sur les trois premiers et à la fin';
    }

    // Début + trois derniers
    if (sorted[0] == 1 && sorted[1] == 3 && sorted[2] == 4 && sorted[3] == 5) {
      return 'au début et sur les trois derniers';
    }

    // Deux premiers + deux derniers
    if (sorted[0] == 1 && sorted[1] == 2 && sorted[2] == 4 && sorted[3] == 5) {
      return 'sur les deux premiers et les deux derniers';
    }

    return 'presque partout';
  }

  return 'sur plusieurs';
}

/// Construit le texte pour une séquence spectateur donnée (style Direct)
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

  // L1: Séquence spectateur avec labels
  final spectatorLabels =
      spectatorSeq.map((v) => v == 1 ? label1 : label2).join(', ');
  lines.add('Tu vas faire $spectatorLabels.');

  // L2 + L3: Selon le cas
  if (misses == 0) {
    // 0 miss = perfect match
    lines.add("Je vais tout deviner, parce que c'est ce que j'avais prédit.");
  } else if (hits == 0) {
    // All miss
    lines.add(
        'Je te laisse gagner du début à la fin, je ne vais rien deviner pour te faire plaisir.');
  } else {
    // Cas mixte: des miss ET des hits
    final missBlock = _formatBlock(missPositions, rounds);
    final hitBlock = _formatBlock(hitPositions, rounds);

    lines.add('Je te laisse gagner $missBlock.');
    lines.add('Je vais avoir juste $hitBlock.');
  }

  // L4: Signature (toujours)
  lines.add(
      "Et c'était ça le vrai truc, te laisser croire que c'est toi qui décides.");

  return lines.join('\n');
}
