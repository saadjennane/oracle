/// Générateur de Starter Pack CHOICES — Séquences Exactes — Analytique — FR
///
/// Génère une banque de textes pour CHOICES (2 options, 1-5 rounds)
/// basée sur la séquence performer et toutes les séquences spectateur possibles.
///
/// Style: Analytique (analytical, observational)
/// Temps: Futur uniquement
/// Format: 4 lignes toujours

/// Génère la banque de textes pour séquences exactes CHOICES (style Analytique)
///
/// [label1] : label de l'option 1 (ex: "Droite", "A", "Téléphone")
/// [label2] : label de l'option 2 (ex: "Gauche", "B", "Clé")
/// [performerSeq] : séquence performer, longueur = rounds, valeurs 1 ou 2
///
/// Retourne une Map<String, String> où:
/// - key = séquence spectateur en string de '1'/'2' (ex: "1212")
/// - value = texte généré
Map<String, String> generateChoicesExactAnalytiqueFR({
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

    // Calculer hits/misses et leurs positions
    final List<int> hitIndices = [];
    final List<int> missIndices = [];
    for (int r = 0; r < rounds; r++) {
      if (spectatorSeq[r] == performerSeq[r]) {
        hitIndices.add(r);
      } else {
        missIndices.add(r);
      }
    }
    final hits = hitIndices.length;
    final misses = missIndices.length;

    // Calculer streakStartHits (hits consécutifs depuis le début)
    int streakStartHits = 0;
    for (int r = 0; r < rounds; r++) {
      if (spectatorSeq[r] == performerSeq[r]) {
        streakStartHits++;
      } else {
        break;
      }
    }

    // Construire le texte
    final text = _buildTextAnalytique(
      spectatorSeq: spectatorSeq,
      label1: label1,
      label2: label2,
      hits: hits,
      misses: misses,
      hitIndices: hitIndices,
      missIndices: missIndices,
      streakStartHits: streakStartHits,
      rounds: rounds,
      keyIndex: i,
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

/// Convertit un nombre en texte français (1-5)
String _numberToFrenchWord(int n) {
  switch (n) {
    case 1:
      return 'un';
    case 2:
      return 'deux';
    case 3:
      return 'trois';
    case 4:
      return 'quatre';
    case 5:
      return 'cinq';
    default:
      return '$n';
  }
}

/// Construit le texte pour une séquence spectateur donnée (style Analytique)
String _buildTextAnalytique({
  required List<int> spectatorSeq,
  required String label1,
  required String label2,
  required int hits,
  required int misses,
  required List<int> hitIndices,
  required List<int> missIndices,
  required int streakStartHits,
  required int rounds,
  required int keyIndex,
}) {
  final lines = <String>[];

  // L1: Séquence spectateur avec labels
  final spectatorLabels = spectatorSeq.map((v) => v == 1 ? label1 : label2).join(', ');
  lines.add('Tu vas faire $spectatorLabels.');

  // L2: line2Analytique - basé sur streakStartHits
  lines.add(_buildLine2Analytique(hits, rounds, streakStartHits));

  // L3: line3Analytique - basé sur les misses
  lines.add(_buildLine3Analytique(misses, missIndices, rounds));

  // L4: line4Analytique - fin déterministe
  lines.add(_buildLine4Analytique(keyIndex));

  return lines.join('\n');
}

/// Génère la ligne 2 (commentaire analytique sur les hits)
String _buildLine2Analytique(int hits, int rounds, int streakStartHits) {
  if (hits == 0) {
    return 'Tu vas être imprévisible sur toute la ligne, je ne vais rien deviner.';
  }

  if (hits == rounds) {
    return 'Tu vas laisser passer tous les signaux, je vais tout deviner sans effort.';
  }

  // Cas partiel - basé sur streakStartHits
  if (streakStartHits == 0) {
    return 'Au début, tu vas casser le rythme, je ne vais pas te lire tout de suite.';
  }

  if (streakStartHits == 1) {
    return 'Le premier choix, c\'est souvent là que tu te trahis, je vais le deviner sans effort.';
  }

  // streakStartHits >= 2
  final streakWord = _numberToFrenchWord(streakStartHits);
  return 'Les $streakWord premiers choix, c\'est souvent là que tu te trahis, je vais les deviner sans effort.';
}

/// Génère la ligne 3 (commentaire analytique sur les misses)
String _buildLine3Analytique(int misses, List<int> missIndices, int rounds) {
  if (misses == 0) {
    return 'Tu vas croire que tu as tout contrôlé, mais ça va être trop propre.';
  }

  if (misses == 1) {
    final missPos = missIndices.first;

    // Miss au dernier round
    if (missPos == rounds - 1) {
      return 'Le dernier, je vais le rater exprès, juste pour te laisser respirer et croire que ça venait de toi.';
    }

    // Miss au premier round
    if (missPos == 0) {
      return 'Le premier, je vais le rater exprès, juste pour te mettre en confiance et te laisser dérouler.';
    }

    // Miss ailleurs
    return 'Je vais laisser passer une seule fois, au bon moment, juste pour te donner l\'impression que tu pouvais m\'échapper.';
  }

  // misses >= 2
  final missesWord = _numberToFrenchWord(misses);
  return 'Je vais laisser passer $missesWord fois, juste assez pour que tu aies l\'impression de reprendre la main.';
}

/// Génère la ligne 4 (conclusion analytique déterministe)
String _buildLine4Analytique(int keyIndex) {
  // 3 fins possibles, sélection déterministe basée sur keyIndex
  final endings = [
    'Tu vas décider, ou tu vas juste croire décider.',
    'Tu vas choisir, mais le plus important, ça va être ce que tu crois contrôler.',
    'Tu vas penser que c\'est toi, et c\'est exactement ça qui va marcher.',
  ];

  return endings[keyIndex % 3];
}
