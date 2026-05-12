/// Choices Buckets Bank EN
///
/// Pre-written text bank for CHOICES mode based on hits/misses.
/// Bucket format: "N|hitsCount" where N = number of rounds, hitsCount = number of hits.
///
/// Example: "3|2" = 3 rounds with 2 hits (1 miss)
/// For N rounds, there are N+1 possible buckets (from 0 hits to N hits).
///
/// Available placeholders:
/// - {spectatorSequence}: sequence of spectator choices (e.g., "Red, Blue, Red")
/// - {hitsCount}: number of correct predictions
/// - {missCount}: number of errors
///
/// Tone: teasing, direct, simple
/// Tense: future only
/// Required ending: "In the end, will you choose or will you just believe you chose."

/// Text bank by bucket "N|hitsCount"
const Map<String, String> choicesBucketsEN = {
  // ============================================================
  // 1 ROUND (buckets: 0 hit, 1 hit)
  // ============================================================
  '1|0': '''You will make one choice.
And that choice, I won't predict.
You will choose {spectatorSequence}.
I will be wrong on purpose, just to show you that even when I lose, I'm the one in control.
{missCount} error, yet you controlled nothing.
In the end, will you choose or will you just believe you chose.''',

  '1|1': '''You will make one choice.
And that choice, I will predict.
You will choose {spectatorSequence}.
No luck, no chance. Just reading.
{hitsCount} out of {hitsCount}. Perfect score.
In the end, will you choose or will you just believe you chose.''',

  // ============================================================
  // 2 ROUNDS (buckets: 0 hit, 1 hit, 2 hits)
  // ============================================================
  '2|0': '''You will make two choices.
And both of them, I will miss.
You will choose {spectatorSequence}.
I will be wrong twice, but only because I decided to.
{missCount} errors out of 2. And yet, this is exactly what I wanted.
In the end, will you choose or will you just believe you chose.''',

  '2|1': '''You will make two choices.
And I will predict just one.
You will choose {spectatorSequence}.
{hitsCount} correct, {missCount} wrong. A perfect balance.
I let you think you got lucky on the miss.
In the end, will you choose or will you just believe you chose.''',

  '2|2': '''You will make two choices.
And both of them, I will predict.
You will choose {spectatorSequence}.
Two out of two. No room for error.
You thought you had a chance? Not against a mentalist.
In the end, will you choose or will you just believe you chose.''',

  // ============================================================
  // 3 ROUNDS (buckets: 0 hit, 1 hit, 2 hits, 3 hits)
  // ============================================================
  '3|0': '''You will make three choices.
And all three, I will miss.
You will choose {spectatorSequence}.
{missCount} errors out of 3. You'll think you beat me.
But losing on purpose is also a form of control.
In the end, will you choose or will you just believe you chose.''',

  '3|1': '''You will make three choices.
And I will predict just one.
You will choose {spectatorSequence}.
{hitsCount} correct out of 3. The other {missCount}, I give to you.
It's my way of letting you believe you won.
In the end, will you choose or will you just believe you chose.''',

  '3|2': '''You will make three choices.
And I will predict two.
You will choose {spectatorSequence}.
{hitsCount} correct, {missCount} wrong. The margin is tight.
But even that error, I chose it.
In the end, will you choose or will you just believe you chose.''',

  '3|3': '''You will make three choices.
And all three, I will predict.
You will choose {spectatorSequence}.
Three out of three. Without hesitation.
You thought you could escape me? Impossible.
In the end, will you choose or will you just believe you chose.''',

  // ============================================================
  // 4 ROUNDS (buckets: 0 hit to 4 hits)
  // ============================================================
  '4|0': '''You will make four choices.
And all four, I will miss.
You will choose {spectatorSequence}.
{missCount} errors. A perfect score... for you.
But I let you win, and you didn't even notice.
In the end, will you choose or will you just believe you chose.''',

  '4|1': '''You will make four choices.
And I will predict just one.
You will choose {spectatorSequence}.
{hitsCount} correct out of 4. The minimum to prove I can.
The other {missCount}? Gifts.
In the end, will you choose or will you just believe you chose.''',

  '4|2': '''You will make four choices.
And I will predict half.
You will choose {spectatorSequence}.
{hitsCount} correct, {missCount} wrong. Right in the middle.
The perfect balance between letting you hope and reminding you who's in control.
In the end, will you choose or will you just believe you chose.''',

  '4|3': '''You will make four choices.
And I will predict three.
You will choose {spectatorSequence}.
{hitsCount} correct out of 4. Almost perfect.
That single error? Just to give you a little hope.
In the end, will you choose or will you just believe you chose.''',

  '4|4': '''You will make four choices.
And all four, I will predict.
You will choose {spectatorSequence}.
Four out of four. Flawless.
You tried to be unpredictable. It didn't work.
In the end, will you choose or will you just believe you chose.''',

  // ============================================================
  // 5 ROUNDS (buckets: 0 hit to 5 hits)
  // ============================================================
  '5|0': '''You will make five choices.
And all five, I will miss.
You will choose {spectatorSequence}.
{missCount} errors out of 5. A disaster... in appearance.
Losing this much without ever losing control, that's my talent.
In the end, will you choose or will you just believe you chose.''',

  '5|1': '''You will make five choices.
And I will predict just one.
You will choose {spectatorSequence}.
{hitsCount} out of 5. You'll think you dominated me.
But that single success proves I can read you.
In the end, will you choose or will you just believe you chose.''',

  '5|2': '''You will make five choices.
And I will predict two.
You will choose {spectatorSequence}.
{hitsCount} correct, {missCount} wrong.
Enough to show my ability, not enough to crush you.
In the end, will you choose or will you just believe you chose.''',

  '5|3': '''You will make five choices.
And I will predict three.
You will choose {spectatorSequence}.
{hitsCount} out of 5. The majority.
You tried to surprise me, but I keep the advantage.
In the end, will you choose or will you just believe you chose.''',

  '5|4': '''You will make five choices.
And I will predict four.
You will choose {spectatorSequence}.
{hitsCount} correct out of 5. Near perfection.
That single error? My signature. To remind you I'm human.
In the end, will you choose or will you just believe you chose.''',

  '5|5': '''You will make five choices.
And all five, I will predict.
You will choose {spectatorSequence}.
Five out of five. No escape.
You tried everything to lose me. You failed.
In the end, will you choose or will you just believe you chose.''',

  // ============================================================
  // 6 ROUNDS (buckets: 0 hit to 6 hits)
  // ============================================================
  '6|0': '''You will make six choices.
And all six, I will miss.
You will choose {spectatorSequence}.
{missCount} errors. A total failure... if you believe appearances.
Losing six times on purpose requires more control than winning six times.
In the end, will you choose or will you just believe you chose.''',

  '6|1': '''You will make six choices.
And I will predict just one.
You will choose {spectatorSequence}.
{hitsCount} out of 6. A drop in the ocean.
But that drop proves nothing is truly random.
In the end, will you choose or will you just believe you chose.''',

  '6|2': '''You will make six choices.
And I will predict two.
You will choose {spectatorSequence}.
{hitsCount} correct, {missCount} wrong.
Just enough to make you doubt your free will.
In the end, will you choose or will you just believe you chose.''',

  '6|3': '''You will make six choices.
And I will predict half.
You will choose {spectatorSequence}.
{hitsCount} out of 6. Right in the middle.
The balance between chance and certainty. Except there is no chance.
In the end, will you choose or will you just believe you chose.''',

  '6|4': '''You will make six choices.
And I will predict four.
You will choose {spectatorSequence}.
{hitsCount} correct out of 6. Clear domination.
The {missCount} errors? Bones I throw you to keep you motivated.
In the end, will you choose or will you just believe you chose.''',

  '6|5': '''You will make six choices.
And I will predict five.
You will choose {spectatorSequence}.
{hitsCount} out of 6. Almost perfect.
That single error? Just so you have something to hold on to.
In the end, will you choose or will you just believe you chose.''',

  '6|6': '''You will make six choices.
And all six, I will predict.
You will choose {spectatorSequence}.
Six out of six. Absolutely flawless.
You did your best. And your best wasn't enough.
In the end, will you choose or will you just believe you chose.''',

  // ============================================================
  // 7 ROUNDS (buckets: 0 hit to 7 hits)
  // ============================================================
  '7|0': '''You will make seven choices.
And all seven, I will miss.
You will choose {spectatorSequence}.
{missCount} errors. You'll think you're invincible.
But I decided to lose. Seven times.
In the end, will you choose or will you just believe you chose.''',

  '7|1': '''You will make seven choices.
And I will predict just one.
You will choose {spectatorSequence}.
{hitsCount} out of 7. Almost nothing.
Almost. But that almost changes everything.
In the end, will you choose or will you just believe you chose.''',

  '7|2': '''You will make seven choices.
And I will predict two.
You will choose {spectatorSequence}.
{hitsCount} correct, {missCount} wrong.
Enough to make you think. Not enough to convince you. Perfect.
In the end, will you choose or will you just believe you chose.''',

  '7|3': '''You will make seven choices.
And I will predict three.
You will choose {spectatorSequence}.
{hitsCount} out of 7. Less than half.
But three mental connections out of seven is already disturbing.
In the end, will you choose or will you just believe you chose.''',

  '7|4': '''You will make seven choices.
And I will predict four.
You will choose {spectatorSequence}.
{hitsCount} correct out of 7. The majority.
You're starting to understand that chance doesn't really exist.
In the end, will you choose or will you just believe you chose.''',

  '7|5': '''You will make seven choices.
And I will predict five.
You will choose {spectatorSequence}.
{hitsCount} out of 7. Strong domination.
The remaining {missCount} errors? Calculated concessions.
In the end, will you choose or will you just believe you chose.''',

  '7|6': '''You will make seven choices.
And I will predict six.
You will choose {spectatorSequence}.
{hitsCount} correct out of 7. Near perfect.
That single error gives you hope. A hope I created.
In the end, will you choose or will you just believe you chose.''',

  '7|7': '''You will make seven choices.
And all seven, I will predict.
You will choose {spectatorSequence}.
Seven out of seven. Absolute perfection.
You thought more rounds meant more chances. You were wrong.
In the end, will you choose or will you just believe you chose.''',

  // ============================================================
  // 8 ROUNDS (buckets: 0 hit to 8 hits)
  // ============================================================
  '8|0': '''You will make eight choices.
And all eight, I will miss.
You will choose {spectatorSequence}.
{missCount} consecutive errors. A record.
But losing eight times requires as much precision as winning eight times.
In the end, will you choose or will you just believe you chose.''',

  '8|1': '''You will make eight choices.
And I will predict just one.
You will choose {spectatorSequence}.
{hitsCount} out of 8. A spark in the darkness.
That spark proves I can see through you.
In the end, will you choose or will you just believe you chose.''',

  '8|2': '''You will make eight choices.
And I will predict two.
You will choose {spectatorSequence}.
{hitsCount} correct, {missCount} wrong.
Two moments when our minds connected.
In the end, will you choose or will you just believe you chose.''',

  '8|3': '''You will make eight choices.
And I will predict three.
You will choose {spectatorSequence}.
{hitsCount} out of 8. A bit less than half.
But those three successes will haunt you.
In the end, will you choose or will you just believe you chose.''',

  '8|4': '''You will make eight choices.
And I will predict half.
You will choose {spectatorSequence}.
{hitsCount} out of 8. Perfect balance.
Four times yes, four times no. But none of this is chance.
In the end, will you choose or will you just believe you chose.''',

  '8|5': '''You will make eight choices.
And I will predict five.
You will choose {spectatorSequence}.
{hitsCount} correct out of 8. Clear advantage.
The {missCount} errors? Strategic.
In the end, will you choose or will you just believe you chose.''',

  '8|6': '''You will make eight choices.
And I will predict six.
You will choose {spectatorSequence}.
{hitsCount} out of 8. You barely had a chance.
Those {missCount} errors? I gave them to you.
In the end, will you choose or will you just believe you chose.''',

  '8|7': '''You will make eight choices.
And I will predict seven.
You will choose {spectatorSequence}.
{hitsCount} correct out of 8. Crushing.
That single error? My humanity showing through.
In the end, will you choose or will you just believe you chose.''',

  '8|8': '''You will make eight choices.
And all eight, I will predict.
You will choose {spectatorSequence}.
Eight out of eight. Zero errors. Total.
The more choices you make, the better I know you.
In the end, will you choose or will you just believe you chose.''',

  // ============================================================
  // 9 ROUNDS (buckets: 0 hit to 9 hits)
  // ============================================================
  '9|0': '''You will make nine choices.
And all nine, I will miss.
You will choose {spectatorSequence}.
{missCount} errors. You'll think you humiliated me.
But it's the opposite. Nine voluntary defeats is my demonstration of power.
In the end, will you choose or will you just believe you chose.''',

  '9|1': '''You will make nine choices.
And I will predict just one.
You will choose {spectatorSequence}.
{hitsCount} out of 9. Almost invisible.
But that one is enough to question everything.
In the end, will you choose or will you just believe you chose.''',

  '9|2': '''You will make nine choices.
And I will predict two.
You will choose {spectatorSequence}.
{hitsCount} correct out of 9.
Two flashes of connection in a storm of uncertainty.
In the end, will you choose or will you just believe you chose.''',

  '9|3': '''You will make nine choices.
And I will predict three.
You will choose {spectatorSequence}.
{hitsCount} out of 9. Exactly one third.
Three moments when I saw clearly into your mind.
In the end, will you choose or will you just believe you chose.''',

  '9|4': '''You will make nine choices.
And I will predict four.
You will choose {spectatorSequence}.
{hitsCount} correct, {missCount} wrong.
Almost half. Enough to trouble you.
In the end, will you choose or will you just believe you chose.''',

  '9|5': '''You will make nine choices.
And I will predict the majority.
You will choose {spectatorSequence}.
{hitsCount} out of 9. More than half.
From now on, I'm the one leading the dance.
In the end, will you choose or will you just believe you chose.''',

  '9|6': '''You will make nine choices.
And I will predict six.
You will choose {spectatorSequence}.
{hitsCount} correct out of 9. Two thirds.
The {missCount} errors? Crumbs I leave you.
In the end, will you choose or will you just believe you chose.''',

  '9|7': '''You will make nine choices.
And I will predict seven.
You will choose {spectatorSequence}.
{hitsCount} out of 9. Clear domination.
You only had {missCount} moments of respite.
In the end, will you choose or will you just believe you chose.''',

  '9|8': '''You will make nine choices.
And I will predict eight.
You will choose {spectatorSequence}.
{hitsCount} correct out of 9. Near perfect.
That single error? My artistic signature.
In the end, will you choose or will you just believe you chose.''',

  '9|9': '''You will make nine choices.
And all nine, I will predict.
You will choose {spectatorSequence}.
Nine out of nine. Absolute mastery.
Nine opportunities to escape me. Nine failures.
In the end, will you choose or will you just believe you chose.''',

  // ============================================================
  // 10 ROUNDS (buckets: 0 hit to 10 hits)
  // ============================================================
  '10|0': '''You will make ten choices.
And all ten, I will miss.
You will choose {spectatorSequence}.
{missCount} errors. Ten out of ten in reverse.
A perfect score... in the direction I chose.
In the end, will you choose or will you just believe you chose.''',

  '10|1': '''You will make ten choices.
And I will predict just one.
You will choose {spectatorSequence}.
{hitsCount} out of 10. Ten percent.
But that ten percent will haunt you for a long time.
In the end, will you choose or will you just believe you chose.''',

  '10|2': '''You will make ten choices.
And I will predict two.
You will choose {spectatorSequence}.
{hitsCount} correct out of 10. Twenty percent.
Two flashes of clairvoyance. Enough to sow doubt.
In the end, will you choose or will you just believe you chose.''',

  '10|3': '''You will make ten choices.
And I will predict three.
You will choose {spectatorSequence}.
{hitsCount} out of 10. Almost one third.
Three times your mind spoke to me.
In the end, will you choose or will you just believe you chose.''',

  '10|4': '''You will make ten choices.
And I will predict four.
You will choose {spectatorSequence}.
{hitsCount} correct, {missCount} wrong.
Forty percent successful mind reading.
In the end, will you choose or will you just believe you chose.''',

  '10|5': '''You will make ten choices.
And I will predict half.
You will choose {spectatorSequence}.
{hitsCount} out of 10. Exactly 50%.
The perfect balance between mystery and certainty.
In the end, will you choose or will you just believe you chose.''',

  '10|6': '''You will make ten choices.
And I will predict six.
You will choose {spectatorSequence}.
{hitsCount} correct out of 10. The majority.
The {missCount} errors? Intentional background noise.
In the end, will you choose or will you just believe you chose.''',

  '10|7': '''You will make ten choices.
And I will predict seven.
You will choose {spectatorSequence}.
{hitsCount} out of 10. Seventy percent.
You're starting to realize the extent of my ability.
In the end, will you choose or will you just believe you chose.''',

  '10|8': '''You will make ten choices.
And I will predict eight.
You will choose {spectatorSequence}.
{hitsCount} correct out of 10. Eighty percent.
Those {missCount} errors? Just to keep a bit of mystery.
In the end, will you choose or will you just believe you chose.''',

  '10|9': '''You will make ten choices.
And I will predict nine.
You will choose {spectatorSequence}.
{hitsCount} out of 10. Near perfection.
One single error out of ten. And even that one was intentional.
In the end, will you choose or will you just believe you chose.''',

  '10|10': '''You will make ten choices.
And all ten, I will predict.
You will choose {spectatorSequence}.
Ten out of ten. Absolute perfection.
Ten chances to surprise me. Ten failures.
In the end, will you choose or will you just believe you chose.''',
};

/// Gets the bucket text for a given number of rounds and hits
String? getChoicesBucketTextEN(int rounds, int hits) {
  final key = '$rounds|$hits';
  return choicesBucketsEN[key];
}

/// Applies placeholders to the text
String applyChoicesPlaceholdersEN(
  String text, {
  required String spectatorSequence,
  required int hitsCount,
  required int missCount,
  required List<String> spectatorChoices,
  List<String> performerChoices = const [],
  List<String> options = const [],
  int? seed,
}) {
  var result = text
      .replaceAll('{spectatorSequence}', spectatorSequence)
      .replaceAll('{hitsCount}', hitsCount.toString())
      .replaceAll('{missCount}', missCount.toString());
  // Per-round spectator choices: {choiceS1}, {choice1}, {choiceSpectator1}, ...
  for (int i = 0; i < spectatorChoices.length; i++) {
    result = result.replaceAll('{choiceS${i + 1}}', spectatorChoices[i]);
    result = result.replaceAll('{choix${i + 1}}', spectatorChoices[i]);
    result = result.replaceAll('{choiceSpectator${i + 1}}', spectatorChoices[i]);
  }
  // Per-round performer choices: {choiceP1}, {choicePerformer1}, ...
  for (int i = 0; i < performerChoices.length; i++) {
    result = result.replaceAll('{choiceP${i + 1}}', performerChoices[i]);
    result = result.replaceAll('{choicePerformer${i + 1}}', performerChoices[i]);
  }
  // Per-round alternative choices: {altS1}, {altS2}, ... (3+ options only)
  if (options.length >= 3) {
    final rng = seed ?? DateTime.now().millisecondsSinceEpoch;
    for (int i = 0; i < spectatorChoices.length; i++) {
      final placeholder = '{altS${i + 1}}';
      if (!result.contains(placeholder)) continue;
      final others = options.where((o) => o != spectatorChoices[i]).toList();
      if (others.isNotEmpty) {
        final alt = others[(rng + i) % others.length];
        result = result.replaceAll(placeholder, alt);
      }
    }
  }
  return result;
}
