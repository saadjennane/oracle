/// Générateur de Starter Pack DUEL — Mode Buckets (Fixed Rounds) — Direct — FR
///
/// Génère une banque de textes pour DUEL en mode bucket (score final).
/// Pour R rounds, génère (R+1)(R+2)/2 buckets basés sur (S, P, ties).
/// Clé: "{R}|{S}-{P}|T{ties}"
///
/// Style: Direct (phrases courtes, futur, tapé vite)
/// Langue: FR uniquement

/// Génère la banque de textes bucket pour DUEL Fixed Rounds (style Direct)
///
/// [rounds] : nombre de rounds (1-10)
///
/// Retourne une Map<String, String> où:
/// - key = bucket ID (ex: "3|2-0|T1" pour R=3, S=2, P=0, ties=1)
/// - value = texte généré avec placeholder {spectatorSequence}
Map<String, String> generateDuelBucketDirectFR({
  required int rounds,
}) {
  assert(rounds >= 1 && rounds <= 10, 'Rounds must be between 1 and 10');

  final Map<String, String> bank = {};

  // Générer toutes les combinaisons (S, P, ties) où S + P + ties = R
  for (int spectatorWins = 0; spectatorWins <= rounds; spectatorWins++) {
    for (int performerWins = 0;
        performerWins <= rounds - spectatorWins;
        performerWins++) {
      final ties = rounds - spectatorWins - performerWins;

      final key = _buildBucketKey(
        rounds: rounds,
        spectatorWins: spectatorWins,
        performerWins: performerWins,
        ties: ties,
      );

      final text = _buildBucketText(
        rounds: rounds,
        spectatorWins: spectatorWins,
        performerWins: performerWins,
        ties: ties,
      );

      bank[key] = text;
    }
  }

  return bank;
}

/// Génère les banks pour tous les rounds de 1 à maxRounds
Map<String, String> generateDuelBucketDirectFRAll({
  int maxRounds = 10,
}) {
  final Map<String, String> bank = {};

  for (int r = 1; r <= maxRounds; r++) {
    bank.addAll(generateDuelBucketDirectFR(rounds: r));
  }

  return bank;
}

/// Construit la clé bucket: "{R}|{S}-{P}|T{ties}"
String _buildBucketKey({
  required int rounds,
  required int spectatorWins,
  required int performerWins,
  required int ties,
}) {
  return '$rounds|$spectatorWins-$performerWins|T$ties';
}

/// Parse une clé bucket et retourne (rounds, spectatorWins, performerWins, ties)
/// Retourne null si la clé est invalide
({int rounds, int spectatorWins, int performerWins, int ties})? parseBucketKey(
    String key) {
  // Format: "{R}|{S}-{P}|T{ties}"
  final regex = RegExp(r'^(\d+)\|(\d+)-(\d+)\|T(\d+)$');
  final match = regex.firstMatch(key);

  if (match == null) return null;

  final rounds = int.parse(match.group(1)!);
  final spectatorWins = int.parse(match.group(2)!);
  final performerWins = int.parse(match.group(3)!);
  final ties = int.parse(match.group(4)!);

  // Vérifier l'invariant
  if (spectatorWins + performerWins + ties != rounds) return null;

  return (
    rounds: rounds,
    spectatorWins: spectatorWins,
    performerWins: performerWins,
    ties: ties,
  );
}

/// Calcule le nombre de buckets pour R rounds
/// Formule: (R+1)(R+2)/2
int bucketCountForRounds(int rounds) {
  return (rounds + 1) * (rounds + 2) ~/ 2;
}

/// Construit le texte pour un bucket donné
String _buildBucketText({
  required int rounds,
  required int spectatorWins,
  required int performerWins,
  required int ties,
}) {
  final lines = <String>[];

  // L1: Séquence spectateur (placeholder remplacé au runtime)
  lines.add('Tu vas faire {spectatorSequence}.');

  // L2: Score final
  final scoreLine = _buildScoreLine(spectatorWins, performerWins, ties);
  lines.add(scoreLine);

  // L3: Ligne cadeau basée sur le résultat
  final giftLine =
      _buildGiftLine(spectatorWins, performerWins, ties);
  lines.add(giftLine);

  // L4: Signature (toujours)
  lines.add(
      "Et c'était ça le vrai truc, te laisser croire que c'est toi qui décides.");

  return lines.join('\n');
}

/// Construit la ligne de score
String _buildScoreLine(int spectatorWins, int performerWins, int ties) {
  if (ties > 0) {
    final tieWord = ties == 1 ? 'égalité' : 'égalités';
    return 'Score final $spectatorWins-$performerWins, avec $ties $tieWord.';
  }
  return 'Score final $spectatorWins-$performerWins.';
}

/// Construit la ligne cadeau basée sur le score
String _buildGiftLine(int spectatorWins, int performerWins, int ties) {
  if (spectatorWins > performerWins) {
    // Spectateur gagne
    if (ties > 0) {
      return 'Je te laisse gagner, avec quelques égalités pour le suspense.';
    }
    return 'Je te laisse gagner, juste assez.';
  } else if (spectatorWins < performerWins) {
    // Performer gagne
    if (ties > 0) {
      return 'Je te laisse quelques points et égalités, juste pour te mettre en confiance.';
    }
    return 'Je te laisse quelques points, juste pour te mettre en confiance.';
  } else {
    // Égalité parfaite (S == P)
    if (ties > 0) {
      return 'Je te laisse une égalité globale, juste assez pour que tu doutes.';
    }
    return 'Je te laisse une égalité parfaite, juste assez pour que tu doutes.';
  }
}
