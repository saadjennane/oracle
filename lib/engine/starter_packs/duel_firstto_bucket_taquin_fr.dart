/// Générateur de Starter Pack DUEL — Mode First-To (Score Cible) — Taquin — FR
///
/// Génère une banque de textes pour DUEL en mode First-To.
/// Premier joueur à atteindre targetScore gagne.
///
/// Pour targetScore = T : 2*T buckets
/// Clé: "{T}|{winner}|{loserScore}"
///
/// Style: Taquin (pique mentaliste, léger, futur)
/// Langue: FR uniquement

Map<String, String> generateDuelFirstToBucketTaquinFR({
  required int targetScore,
}) {
  assert(targetScore >= 2 && targetScore <= 5,
      'Target score must be between 2 and 5');

  final Map<String, String> bank = {};

  for (int loserScore = 0; loserScore < targetScore; loserScore++) {
    // Spectateur gagne (S)
    final keyS = '$targetScore|S|$loserScore';
    bank[keyS] = _buildFirstToBucketText(
      targetScore: targetScore,
      winner: 'S',
      loserScore: loserScore,
    );

    // Performer gagne (P)
    final keyP = '$targetScore|P|$loserScore';
    bank[keyP] = _buildFirstToBucketText(
      targetScore: targetScore,
      winner: 'P',
      loserScore: loserScore,
    );
  }

  return bank;
}

String _buildFirstToBucketText({
  required int targetScore,
  required String winner,
  required int loserScore,
}) {
  final lines = <String>[];

  // L1: Séquence spectateur (placeholder)
  lines.add('Tu vas faire {spectatorSequence}.');

  // L2: Score final
  if (winner == 'S') {
    lines.add('Score final $targetScore-$loserScore.');
  } else {
    lines.add('Score final $loserScore-$targetScore.');
  }

  // L3: Cadeau taquin
  if (winner == 'S') {
    if (loserScore == 0) {
      lines.add(
          'Je te laisse gagner sans me laisser un seul point, juste pour te donner ce petit plaisir d\'avoir eu un mentaliste.');
    } else {
      final pointWord = loserScore == 1 ? 'point' : 'points';
      lines.add(
          'Je te laisse $loserScore $pointWord, juste pour que tu y croies un peu.');
    }
  } else {
    if (loserScore == 0) {
      lines.add(
          'Je ne te laisse aucun point, juste pour que tu te demandes comment c\'est possible.');
    } else {
      final pointWord = loserScore == 1 ? 'point' : 'points';
      lines.add(
          'Je te laisse $loserScore $pointWord, juste pour te donner ce petit plaisir d\'avoir eu un mentaliste.');
    }
  }

  // L4: Signature taquin
  lines.add('J\'espère que ça t\'a fait plaisir.');

  return lines.join('\n');
}
