/// Starter Pack Generator DUEL — First-To Buckets — Taquin — EN
///
/// Generates a text bank for DUEL first-to mode.
/// For targetScore = T : 2*T buckets
/// Key: "{T}|{winner}|{loserScore}"
///
/// Style: Taquin (playful teasing, mentalist vibe)
/// Language: EN only

Map<String, String> generateDuelFirstToBucketTaquinEN({
  required int targetScore,
}) {
  assert(targetScore >= 2 && targetScore <= 5,
      'Target score must be between 2 and 5');

  final Map<String, String> bank = {};

  for (int loserScore = 0; loserScore < targetScore; loserScore++) {
    final keyS = '$targetScore|S|$loserScore';
    bank[keyS] = _buildFirstToBucketText(
      targetScore: targetScore,
      winner: 'S',
      loserScore: loserScore,
    );

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

  lines.add('You will play {spectatorSequence}.');

  if (winner == 'S') {
    lines.add('Final score $targetScore-$loserScore.');
  } else {
    lines.add('Final score $loserScore-$targetScore.');
  }

  if (winner == 'S') {
    if (loserScore == 0) {
      lines.add(
          'I will let you win without giving me a single point, just to give you that little thrill of having had a mentalist.');
    } else {
      final pointWord = loserScore == 1 ? 'point' : 'points';
      lines.add(
          'I will let you have $loserScore $pointWord, just so you believe it a little.');
    }
  } else {
    if (loserScore == 0) {
      lines.add(
          'I will not give you a single point, just so you wonder how that is even possible.');
    } else {
      final pointWord = loserScore == 1 ? 'point' : 'points';
      lines.add(
          'I will let you have $loserScore $pointWord, just to give you that little thrill of having had a mentalist.');
    }
  }

  lines.add('I hope you enjoyed it.');

  return lines.join('\n');
}
