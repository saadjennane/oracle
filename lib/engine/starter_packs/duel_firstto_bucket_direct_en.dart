/// Starter Pack Generator DUEL — First-To Buckets — Direct — EN
///
/// Generates a text bank for DUEL first-to mode.
/// For targetScore = T : 2*T buckets
/// Key: "{T}|{winner}|{loserScore}"
///
/// Style: Direct (short, future tense, quick)
/// Language: EN only

Map<String, String> generateDuelFirstToBucketDirectEN({
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
      lines.add('I will let you win, just enough.');
    } else {
      final pointWord = loserScore == 1 ? 'point' : 'points';
      lines.add(
          'I will let you have $loserScore $pointWord, just so you believe it.');
    }
  } else {
    if (loserScore == 0) {
      lines.add('I will let you believe in it a little.');
    } else {
      final pointWord = loserScore == 1 ? 'point' : 'points';
      lines.add(
          'I will let you have $loserScore $pointWord, just to build your confidence.');
    }
  }

  lines.add(
      "And that was the real trick, letting you believe you are the one who decides.");

  return lines.join('\n');
}
