/// First-To bucket key helpers.
///
/// Each First-To preset stores per-bucket templates keyed by score outcome
/// (e.g. `FT3_S_3-1` = first-to-3, spectator wins 3-1). The narrative
/// engine no longer ships default text — banks start empty and the user
/// authors the template for each bucket.
class DuelFirstToBuckets {
  /// All bucket keys produced for a given target score.
  /// Format: `FT{target}_{S|P}_{winnerScore}-{loserScore}`.
  static List<String> generateBucketKeysForTarget(int targetScore) {
    final keys = <String>[];
    for (int loser = 0; loser < targetScore; loser++) {
      keys.add('FT${targetScore}_S_$targetScore-$loser');
    }
    for (int loser = 0; loser < targetScore; loser++) {
      keys.add('FT${targetScore}_P_$targetScore-$loser');
    }
    return keys;
  }
}
