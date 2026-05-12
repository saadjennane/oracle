/// Starter Pack Generator DUEL — Fixed Rounds Buckets — Taquin — EN
///
/// Generates a text bank for DUEL fixed rounds bucket mode.
/// For R rounds, generates (R+1)(R+2)/2 buckets based on (S, P, ties).
/// Key: "{R}|{S}-{P}|T{ties}"
///
/// Style: Taquin (playful teasing, mentalist vibe)
/// Language: EN only

Map<String, String> generateDuelBucketTaquinEN({
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

  lines.add('You will play {spectatorSequence}.');

  if (ties > 0) {
    final tieWord = ties == 1 ? 'tie' : 'ties';
    lines.add('Final score $spectatorWins-$performerWins, with $ties $tieWord.');
  } else {
    lines.add('Final score $spectatorWins-$performerWins.');
  }

  if (spectatorWins > performerWins) {
    if (ties > 0) {
      lines.add(
          'I will let you win with a few ties, just to give you that little thrill of having had a mentalist.');
    } else {
      lines.add(
          'I will let you win, just to give you that little thrill of having had a mentalist.');
    }
  } else if (spectatorWins < performerWins) {
    if (ties > 0) {
      lines.add(
          'I will let you have a few points and ties, just so you believe it a little.');
    } else {
      lines.add(
          'I will let you have a few points, just so you believe it a little.');
    }
  } else {
    if (ties > 0) {
      lines.add(
          'I will let it be a tie overall, just so you wonder if it was luck.');
    } else {
      lines.add(
          'I will let it be a perfect tie, just so you wonder if it was luck.');
    }
  }

  lines.add('I hope you enjoyed it.');

  return lines.join('\n');
}
