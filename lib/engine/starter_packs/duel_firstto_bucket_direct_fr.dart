/// Générateur de Starter Pack DUEL — Mode First-To (Score Cible) — Bucket — FR
///
/// Génère une banque de textes pour DUEL en mode First-To.
/// Premier joueur à atteindre targetScore gagne.
/// Les égalités ne donnent pas de points.
///
/// Pour targetScore = T : 2*T buckets
/// - Spectateur gagne: T-0, T-1, ..., T-(T-1)
/// - Performer gagne: T-0, T-1, ..., T-(T-1)
///
/// Clé: "{T}|{winner}|{loserScore}"
/// - T = targetScore
/// - winner = S (spectateur) ou P (performer)
/// - loserScore = score du perdant (0 à T-1)
///
/// Style: Direct (phrases courtes, futur, tapé vite)
/// Langue: FR uniquement

/// Génère la banque de textes bucket pour DUEL First-To (style Direct)
///
/// [targetScore] : score cible pour gagner (2-5)
///
/// Retourne une Map<String, String> où:
/// - key = bucket ID (ex: "3|S|0" pour T=3, spectateur gagne 3-0)
/// - value = texte généré avec placeholder {spectatorSequence}
Map<String, String> generateDuelFirstToBucketDirectFR({
  required int targetScore,
}) {
  assert(targetScore >= 2 && targetScore <= 5,
      'Target score must be between 2 and 5');

  final Map<String, String> bank = {};

  // Générer les buckets pour chaque loserScore (0 à T-1)
  for (int loserScore = 0; loserScore < targetScore; loserScore++) {
    // Spectateur gagne (S)
    final keyS = _buildFirstToBucketKey(
      targetScore: targetScore,
      winner: 'S',
      loserScore: loserScore,
    );
    final textS = _buildFirstToBucketText(
      targetScore: targetScore,
      winner: 'S',
      loserScore: loserScore,
    );
    bank[keyS] = textS;

    // Performer gagne (P)
    final keyP = _buildFirstToBucketKey(
      targetScore: targetScore,
      winner: 'P',
      loserScore: loserScore,
    );
    final textP = _buildFirstToBucketText(
      targetScore: targetScore,
      winner: 'P',
      loserScore: loserScore,
    );
    bank[keyP] = textP;
  }

  return bank;
}

/// Génère les banks pour tous les targetScores de 2 à maxTarget
Map<String, String> generateDuelFirstToBucketDirectFRAll({
  int maxTarget = 5,
}) {
  final Map<String, String> bank = {};

  for (int t = 2; t <= maxTarget; t++) {
    bank.addAll(generateDuelFirstToBucketDirectFR(targetScore: t));
  }

  return bank;
}

/// Construit la clé bucket: "{T}|{winner}|{loserScore}"
String _buildFirstToBucketKey({
  required int targetScore,
  required String winner,
  required int loserScore,
}) {
  return '$targetScore|$winner|$loserScore';
}

/// Parse une clé bucket First-To et retourne (targetScore, winner, loserScore)
/// Retourne null si la clé est invalide
({int targetScore, String winner, int loserScore})? parseFirstToBucketKey(
    String key) {
  // Format: "{T}|{winner}|{loserScore}"
  final regex = RegExp(r'^(\d+)\|(S|P)\|(\d+)$');
  final match = regex.firstMatch(key);

  if (match == null) return null;

  final targetScore = int.parse(match.group(1)!);
  final winner = match.group(2)!;
  final loserScore = int.parse(match.group(3)!);

  // Vérifier les contraintes
  if (targetScore < 1 || targetScore > 5) return null;
  if (loserScore < 0 || loserScore >= targetScore) return null;

  return (
    targetScore: targetScore,
    winner: winner,
    loserScore: loserScore,
  );
}

/// Calcule le nombre de buckets pour un targetScore T
/// Formule: 2*T
int firstToBucketCount(int targetScore) {
  return 2 * targetScore;
}

/// Construit le texte pour un bucket First-To donné
String _buildFirstToBucketText({
  required int targetScore,
  required String winner,
  required int loserScore,
}) {
  final lines = <String>[];

  // L1: Séquence spectateur (placeholder remplacé au runtime)
  lines.add('Tu vas faire {spectatorSequence}.');

  // L2: Score final
  // Note: {ties} sera injecté au runtime si ties > 0
  final scoreLine = _buildFirstToScoreLine(targetScore, winner, loserScore);
  lines.add(scoreLine);

  // L3: Ligne cadeau basée sur le résultat
  final giftLine = _buildFirstToGiftLine(winner, loserScore);
  lines.add(giftLine);

  // L4: Signature (toujours)
  lines.add(
      "Et c'était ça le vrai truc, te laisser croire que c'est toi qui décides.");

  return lines.join('\n');
}

/// Construit la ligne de score pour First-To
String _buildFirstToScoreLine(int targetScore, String winner, int loserScore) {
  // Winner score is always targetScore
  // Loser score is loserScore
  final int winnerScore = targetScore;

  if (winner == 'S') {
    // Spectateur gagne: X-Y où X=targetScore, Y=loserScore
    return 'Score final $winnerScore-$loserScore.';
  } else {
    // Performer gagne: X-Y où X=loserScore, Y=targetScore
    return 'Score final $loserScore-$winnerScore.';
  }
}

/// Construit la ligne cadeau basée sur le winner et la marge
String _buildFirstToGiftLine(String winner, int loserScore) {
  if (winner == 'S') {
    // Spectateur gagne
    if (loserScore == 0) {
      return 'Je te laisse gagner, juste assez.';
    } else {
      final pointWord = loserScore == 1 ? 'point' : 'points';
      return 'Je te laisse $loserScore $pointWord, juste pour que tu y croies.';
    }
  } else {
    // Performer gagne
    if (loserScore == 0) {
      return 'Je te laisse y croire un peu.';
    } else {
      final pointWord = loserScore == 1 ? 'point' : 'points';
      return 'Je te laisse $loserScore $pointWord, juste pour te mettre en confiance.';
    }
  }
}
