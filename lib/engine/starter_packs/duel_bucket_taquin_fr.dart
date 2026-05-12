/// Générateur de Starter Pack DUEL — Mode Buckets (Fixed Rounds) — Taquin — FR
///
/// Génère une banque de textes pour DUEL en mode bucket (score final).
/// Pour R rounds, génère (R+1)(R+2)/2 buckets basés sur (S, P, ties).
/// Clé: "{R}|{S}-{P}|T{ties}"
///
/// Style: Taquin (pique mentaliste, léger, futur)
/// Langue: FR uniquement

Map<String, String> generateDuelBucketTaquinFR({
  required int rounds,
}) {
  assert(rounds >= 1 && rounds <= 10, 'Rounds must be between 1 and 10');

  final Map<String, String> bank = {};

  for (int spectatorWins = 0; spectatorWins <= rounds; spectatorWins++) {
    for (int performerWins = 0;
        performerWins <= rounds - spectatorWins;
        performerWins++) {
      final ties = rounds - spectatorWins - performerWins;

      final key = '$rounds|$spectatorWins-$performerWins|T$ties';

      final text = _buildBucketText(
        spectatorWins: spectatorWins,
        performerWins: performerWins,
        ties: ties,
      );

      bank[key] = text;
    }
  }

  return bank;
}

String _buildBucketText({
  required int spectatorWins,
  required int performerWins,
  required int ties,
}) {
  final lines = <String>[];

  // L1: Séquence spectateur (placeholder)
  lines.add('Tu vas faire {spectatorSequence}.');

  // L2: Score final
  if (ties > 0) {
    final tieWord = ties == 1 ? 'égalité' : 'égalités';
    lines.add('Score final $spectatorWins-$performerWins, avec $ties $tieWord.');
  } else {
    lines.add('Score final $spectatorWins-$performerWins.');
  }

  // L3: Cadeau taquin
  if (spectatorWins > performerWins) {
    if (ties > 0) {
      lines.add(
          'Je te laisse gagner avec quelques égalités, juste pour te donner ce petit plaisir d\'avoir eu un mentaliste.');
    } else {
      lines.add(
          'Je te laisse gagner, juste pour te donner ce petit plaisir d\'avoir eu un mentaliste.');
    }
  } else if (spectatorWins < performerWins) {
    if (ties > 0) {
      lines.add(
          'Je te laisse quelques points et quelques égalités, juste pour que tu y croies un peu.');
    } else {
      lines.add(
          'Je te laisse quelques points, juste pour que tu y croies un peu.');
    }
  } else {
    // Égalité S == P
    if (ties > 0) {
      lines.add(
          'Je te laisse une égalité globale, juste pour que tu te demandes si c\'est du hasard.');
    } else {
      lines.add(
          'Je te laisse une égalité parfaite, juste pour que tu te demandes si c\'est du hasard.');
    }
  }

  // L4: Signature taquin
  lines.add('J\'espère que ça t\'a fait plaisir.');

  return lines.join('\n');
}
