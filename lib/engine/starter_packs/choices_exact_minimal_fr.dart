/// Générateur de Starter Pack CHOICES — Séquences Exactes — Minimal Sobre — FR
///
/// Génère une banque de textes pour CHOICES (2 options, 1-5 rounds)
/// basée sur la séquence performer et toutes les séquences spectateur possibles.
///
/// Style: Minimal sobre
/// Temps: Futur uniquement
/// Fin signature: "Et si c'était ça, le vrai truc, te laisser croire que tu décides."

/// Génère la banque de textes pour séquences exactes CHOICES
///
/// [label1] : label de l'option 1 (ex: "Droite", "A", "Téléphone")
/// [label2] : label de l'option 2 (ex: "Gauche", "B", "Clé")
/// [performerSeq] : séquence performer, longueur = rounds, valeurs 1 ou 2
///
/// Retourne une Map<String, String> où:
/// - key = séquence spectateur en string de '1'/'2' (ex: "1212")
/// - value = texte généré
Map<String, String> generateChoicesExactMinimalFR({
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
    List<int> missPositions = [];
    for (int r = 0; r < rounds; r++) {
      if (spectatorSeq[r] == performerSeq[r]) {
        hits++;
      } else {
        missPositions.add(r);
      }
    }
    final misses = rounds - hits;

    // Construire le texte
    final text = _buildText(
      spectatorSeq: spectatorSeq,
      label1: label1,
      label2: label2,
      hits: hits,
      misses: misses,
      missPositions: missPositions,
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

/// Construit le texte pour une séquence spectateur donnée
String _buildText({
  required List<int> spectatorSeq,
  required String label1,
  required String label2,
  required int hits,
  required int misses,
  required List<int> missPositions,
  required int rounds,
}) {
  final lines = <String>[];

  // L1: Séquence spectateur avec labels
  final spectatorLabels = spectatorSeq.map((v) => v == 1 ? label1 : label2).join(', ');
  lines.add('Tu vas faire $spectatorLabels.');

  // L2: Selon hits/misses
  if (hits == rounds) {
    lines.add('Je vais deviner à chaque fois.');
  } else if (hits == 0) {
    lines.add('Je vais me tromper à chaque fois, cadeau.');
  } else {
    lines.add('Je vais deviner $hits fois.');
  }

  // L3: Si misses > 0
  if (misses > 0 && hits > 0) {
    // Ne pas ajouter cette ligne si hits == 0 (déjà couvert par L2)
    if (misses == 1) {
      // Optionnel: préciser position du miss
      final missPos = missPositions.first;
      String positionHint = '';
      if (missPos == 0) {
        positionHint = ' au début';
      } else if (missPos == rounds - 1) {
        positionHint = ' à la fin';
      }
      lines.add('Je vais te laisser gagner une fois$positionHint, juste assez pour que tu te sentes libre.');
    } else {
      lines.add('Je vais te laisser gagner $misses fois, juste assez pour que tu te sentes libre.');
    }
  }

  // L4: Fin signature
  lines.add('Et si c\'était ça, le vrai truc, te laisser croire que tu décides.');

  return lines.join('\n');
}

/// Convertit une séquence de labels en clé de séquence
/// [choices] : liste des choix (labels)
/// [label1] : label correspondant à '1'
/// [label2] : label correspondant à '2'
/// Retourne la clé (ex: "1212")
String choicesToSequenceKey(List<String> choices, String label1, String label2) {
  return choices.map((c) => c == label1 ? '1' : '2').join();
}

/// Convertit une clé de séquence en liste de labels
/// [key] : clé de séquence (ex: "1212")
/// [label1] : label correspondant à '1'
/// [label2] : label correspondant à '2'
/// Retourne la liste des labels
List<String> sequenceKeyToLabels(String key, String label1, String label2) {
  return key.split('').map((c) => c == '1' ? label1 : label2).toList();
}
