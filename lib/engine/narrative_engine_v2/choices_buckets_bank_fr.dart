/// Choices Buckets Bank FR
///
/// Banque de textes pré-écrits pour le mode CHOICES basé sur hits/misses.
/// Format bucket: "N|hitsCount" où N = nombre de rounds, hitsCount = nombre de hits.
///
/// Exemple: "3|2" = 3 rounds avec 2 hits (1 miss)
/// Pour N rounds, il y a N+1 buckets possibles (de 0 hits à N hits).
///
/// Placeholders disponibles:
/// - {spectatorSequence}: séquence des choix du spectateur (ex: "Rouge, Bleu, Rouge")
/// - {hitsCount}: nombre de bonnes prédictions
/// - {missCount}: nombre d'erreurs
///
/// Ton: taquin, direct, simple
/// Temps: futur uniquement
/// Fin obligatoire: "Au final, tu vas choisir ou tu vas juste croire choisir."

/// Banque de textes par bucket "N|hitsCount"
const Map<String, String> choicesBucketsFR = {
  // ============================================================
  // 1 ROUND (buckets: 0 hit, 1 hit)
  // ============================================================
  '1|0': '''Tu vas faire un seul choix.
Et ce choix, je ne vais pas le deviner.
Tu vas choisir {spectatorSequence}.
Je vais me tromper exprès, juste pour te montrer que même quand je perds, c'est moi qui décide.
{missCount} erreur, et pourtant tu n'as rien contrôlé.
Au final, tu vas choisir ou tu vas juste croire choisir.''',

  '1|1': '''Tu vas faire un seul choix.
Et ce choix, je vais le deviner.
Tu vas choisir {spectatorSequence}.
Pas de chance, pas de hasard. Juste de la lecture.
{hitsCount} sur {hitsCount}. Score parfait.
Au final, tu vas choisir ou tu vas juste croire choisir.''',

  // ============================================================
  // 2 ROUNDS (buckets: 0 hit, 1 hit, 2 hits)
  // ============================================================
  '2|0': '''Tu vas faire deux choix.
Et ces deux choix, je vais les rater.
Tu vas choisir {spectatorSequence}.
Je vais me tromper deux fois, mais c'est parce que je l'ai décidé.
{missCount} erreurs sur 2. Et pourtant, c'est exactement ce que je voulais.
Au final, tu vas choisir ou tu vas juste croire choisir.''',

  '2|1': '''Tu vas faire deux choix.
Et je vais en deviner un seul.
Tu vas choisir {spectatorSequence}.
{hitsCount} bonne réponse, {missCount} erreur. Un équilibre parfait.
Je te laisse croire que tu as eu de la chance sur l'erreur.
Au final, tu vas choisir ou tu vas juste croire choisir.''',

  '2|2': '''Tu vas faire deux choix.
Et ces deux choix, je vais les deviner.
Tu vas choisir {spectatorSequence}.
Deux sur deux. Pas d'erreur possible.
Tu pensais avoir une chance ? Pas contre un mentaliste.
Au final, tu vas choisir ou tu vas juste croire choisir.''',

  // ============================================================
  // 3 ROUNDS (buckets: 0 hit, 1 hit, 2 hits, 3 hits)
  // ============================================================
  '3|0': '''Tu vas faire trois choix.
Et ces trois choix, je vais tous les rater.
Tu vas choisir {spectatorSequence}.
{missCount} erreurs sur 3. Tu vas te dire que tu m'as battu.
Mais perdre volontairement, c'est aussi une forme de contrôle.
Au final, tu vas choisir ou tu vas juste croire choisir.''',

  '3|1': '''Tu vas faire trois choix.
Et je vais en deviner un seul.
Tu vas choisir {spectatorSequence}.
{hitsCount} bonne réponse sur 3. Les {missCount} autres, je te les laisse.
C'est ma façon de te donner l'illusion d'avoir gagné.
Au final, tu vas choisir ou tu vas juste croire choisir.''',

  '3|2': '''Tu vas faire trois choix.
Et je vais en deviner deux.
Tu vas choisir {spectatorSequence}.
{hitsCount} bonnes réponses, {missCount} erreur. La marge est serrée.
Mais même cette erreur, c'est moi qui l'ai choisie.
Au final, tu vas choisir ou tu vas juste croire choisir.''',

  '3|3': '''Tu vas faire trois choix.
Et ces trois choix, je vais tous les deviner.
Tu vas choisir {spectatorSequence}.
Trois sur trois. Sans hésitation.
Tu pensais pouvoir m'échapper ? Impossible.
Au final, tu vas choisir ou tu vas juste croire choisir.''',

  // ============================================================
  // 4 ROUNDS (buckets: 0 hit à 4 hits)
  // ============================================================
  '4|0': '''Tu vas faire quatre choix.
Et ces quatre choix, je vais tous les rater.
Tu vas choisir {spectatorSequence}.
{missCount} erreurs. Un score parfait... pour toi.
Mais je t'ai laissé gagner, et tu ne t'en es même pas rendu compte.
Au final, tu vas choisir ou tu vas juste croire choisir.''',

  '4|1': '''Tu vas faire quatre choix.
Et je vais en deviner un seul.
Tu vas choisir {spectatorSequence}.
{hitsCount} bonne réponse sur 4. Le minimum pour te prouver que je peux.
Les {missCount} autres ? Des cadeaux.
Au final, tu vas choisir ou tu vas juste croire choisir.''',

  '4|2': '''Tu vas faire quatre choix.
Et je vais en deviner la moitié.
Tu vas choisir {spectatorSequence}.
{hitsCount} bonnes réponses, {missCount} erreurs. Pile au milieu.
L'équilibre parfait entre te laisser espérer et te rappeler qui contrôle.
Au final, tu vas choisir ou tu vas juste croire choisir.''',

  '4|3': '''Tu vas faire quatre choix.
Et je vais en deviner trois.
Tu vas choisir {spectatorSequence}.
{hitsCount} bonnes réponses sur 4. Presque parfait.
Cette unique erreur ? Juste pour te donner un peu d'espoir.
Au final, tu vas choisir ou tu vas juste croire choisir.''',

  '4|4': '''Tu vas faire quatre choix.
Et ces quatre choix, je vais tous les deviner.
Tu vas choisir {spectatorSequence}.
Quatre sur quatre. Sans faille.
Tu as essayé d'être imprévisible. Ça n'a pas marché.
Au final, tu vas choisir ou tu vas juste croire choisir.''',

  // ============================================================
  // 5 ROUNDS (buckets: 0 hit à 5 hits)
  // ============================================================
  '5|0': '''Tu vas faire cinq choix.
Et ces cinq choix, je vais tous les rater.
Tu vas choisir {spectatorSequence}.
{missCount} erreurs sur 5. Un désastre... en apparence.
Perdre autant sans jamais perdre le contrôle, c'est mon talent.
Au final, tu vas choisir ou tu vas juste croire choisir.''',

  '5|1': '''Tu vas faire cinq choix.
Et je vais en deviner un seul.
Tu vas choisir {spectatorSequence}.
{hitsCount} sur 5. Tu vas penser que tu m'as dominé.
Mais cette unique réussite suffit à prouver que je peux lire en toi.
Au final, tu vas choisir ou tu vas juste croire choisir.''',

  '5|2': '''Tu vas faire cinq choix.
Et je vais en deviner deux.
Tu vas choisir {spectatorSequence}.
{hitsCount} bonnes réponses, {missCount} erreurs.
Assez pour te montrer ma capacité, pas assez pour t'écraser.
Au final, tu vas choisir ou tu vas juste croire choisir.''',

  '5|3': '''Tu vas faire cinq choix.
Et je vais en deviner trois.
Tu vas choisir {spectatorSequence}.
{hitsCount} sur 5. La majorité.
Tu as essayé de me surprendre, mais je garde l'avantage.
Au final, tu vas choisir ou tu vas juste croire choisir.''',

  '5|4': '''Tu vas faire cinq choix.
Et je vais en deviner quatre.
Tu vas choisir {spectatorSequence}.
{hitsCount} bonnes réponses sur 5. Presque la perfection.
Cette erreur unique ? Ma signature. Pour te rappeler que je suis humain.
Au final, tu vas choisir ou tu vas juste croire choisir.''',

  '5|5': '''Tu vas faire cinq choix.
Et ces cinq choix, je vais tous les deviner.
Tu vas choisir {spectatorSequence}.
Cinq sur cinq. Aucune échappatoire.
Tu as tout tenté pour me perdre. Tu as échoué.
Au final, tu vas choisir ou tu vas juste croire choisir.''',

  // ============================================================
  // 6 ROUNDS (buckets: 0 hit à 6 hits)
  // ============================================================
  '6|0': '''Tu vas faire six choix.
Et ces six choix, je vais tous les rater.
Tu vas choisir {spectatorSequence}.
{missCount} erreurs. Un échec total... si tu crois aux apparences.
Six fois perdre exprès demande plus de contrôle que six fois gagner.
Au final, tu vas choisir ou tu vas juste croire choisir.''',

  '6|1': '''Tu vas faire six choix.
Et je vais en deviner un seul.
Tu vas choisir {spectatorSequence}.
{hitsCount} sur 6. Une goutte dans l'océan.
Mais cette goutte suffit à prouver que rien n'est vraiment aléatoire.
Au final, tu vas choisir ou tu vas juste croire choisir.''',

  '6|2': '''Tu vas faire six choix.
Et je vais en deviner deux.
Tu vas choisir {spectatorSequence}.
{hitsCount} bonnes réponses, {missCount} erreurs.
Juste assez pour te faire douter de ton libre arbitre.
Au final, tu vas choisir ou tu vas juste croire choisir.''',

  '6|3': '''Tu vas faire six choix.
Et je vais en deviner la moitié.
Tu vas choisir {spectatorSequence}.
{hitsCount} sur 6. Pile au milieu.
L'équilibre entre hasard et certitude. Sauf qu'il n'y a pas de hasard.
Au final, tu vas choisir ou tu vas juste croire choisir.''',

  '6|4': '''Tu vas faire six choix.
Et je vais en deviner quatre.
Tu vas choisir {spectatorSequence}.
{hitsCount} bonnes réponses sur 6. Nette domination.
Les {missCount} erreurs ? Des os que je te jette pour te garder motivé.
Au final, tu vas choisir ou tu vas juste croire choisir.''',

  '6|5': '''Tu vas faire six choix.
Et je vais en deviner cinq.
Tu vas choisir {spectatorSequence}.
{hitsCount} sur 6. Presque parfait.
Cette unique erreur ? Juste pour que tu puisses te raccrocher à quelque chose.
Au final, tu vas choisir ou tu vas juste croire choisir.''',

  '6|6': '''Tu vas faire six choix.
Et ces six choix, je vais tous les deviner.
Tu vas choisir {spectatorSequence}.
Six sur six. Absolument aucune faille.
Tu as fait de ton mieux. Et ton mieux n'était pas suffisant.
Au final, tu vas choisir ou tu vas juste croire choisir.''',

  // ============================================================
  // 7 ROUNDS (buckets: 0 hit à 7 hits)
  // ============================================================
  '7|0': '''Tu vas faire sept choix.
Et ces sept choix, je vais tous les rater.
Tu vas choisir {spectatorSequence}.
{missCount} erreurs. Tu vas te croire invincible.
Mais c'est moi qui ai décidé de perdre. Sept fois.
Au final, tu vas choisir ou tu vas juste croire choisir.''',

  '7|1': '''Tu vas faire sept choix.
Et je vais en deviner un seul.
Tu vas choisir {spectatorSequence}.
{hitsCount} sur 7. Presque rien.
Presque. Mais ce presque change tout.
Au final, tu vas choisir ou tu vas juste croire choisir.''',

  '7|2': '''Tu vas faire sept choix.
Et je vais en deviner deux.
Tu vas choisir {spectatorSequence}.
{hitsCount} bonnes réponses, {missCount} erreurs.
Assez pour te faire réfléchir. Pas assez pour te convaincre. Parfait.
Au final, tu vas choisir ou tu vas juste croire choisir.''',

  '7|3': '''Tu vas faire sept choix.
Et je vais en deviner trois.
Tu vas choisir {spectatorSequence}.
{hitsCount} sur 7. Moins de la moitié.
Mais trois connexions mentales sur sept, c'est déjà troublant.
Au final, tu vas choisir ou tu vas juste croire choisir.''',

  '7|4': '''Tu vas faire sept choix.
Et je vais en deviner quatre.
Tu vas choisir {spectatorSequence}.
{hitsCount} bonnes réponses sur 7. La majorité.
Tu commences à comprendre que le hasard n'existe pas vraiment.
Au final, tu vas choisir ou tu vas juste croire choisir.''',

  '7|5': '''Tu vas faire sept choix.
Et je vais en deviner cinq.
Tu vas choisir {spectatorSequence}.
{hitsCount} sur 7. Une belle domination.
Les {missCount} erreurs restantes ? Des concessions calculées.
Au final, tu vas choisir ou tu vas juste croire choisir.''',

  '7|6': '''Tu vas faire sept choix.
Et je vais en deviner six.
Tu vas choisir {spectatorSequence}.
{hitsCount} bonnes réponses sur 7. Quasi parfait.
Cette unique erreur te donne l'espoir. Un espoir que j'ai créé.
Au final, tu vas choisir ou tu vas juste croire choisir.''',

  '7|7': '''Tu vas faire sept choix.
Et ces sept choix, je vais tous les deviner.
Tu vas choisir {spectatorSequence}.
Sept sur sept. La perfection absolue.
Tu pensais qu'avec plus de rounds tu aurais plus de chances. Tu avais tort.
Au final, tu vas choisir ou tu vas juste croire choisir.''',

  // ============================================================
  // 8 ROUNDS (buckets: 0 hit à 8 hits)
  // ============================================================
  '8|0': '''Tu vas faire huit choix.
Et ces huit choix, je vais tous les rater.
Tu vas choisir {spectatorSequence}.
{missCount} erreurs consécutives. Un record.
Mais perdre huit fois demande autant de précision que gagner huit fois.
Au final, tu vas choisir ou tu vas juste croire choisir.''',

  '8|1': '''Tu vas faire huit choix.
Et je vais en deviner un seul.
Tu vas choisir {spectatorSequence}.
{hitsCount} sur 8. Une étincelle dans l'obscurité.
Cette étincelle prouve que je peux voir à travers toi.
Au final, tu vas choisir ou tu vas juste croire choisir.''',

  '8|2': '''Tu vas faire huit choix.
Et je vais en deviner deux.
Tu vas choisir {spectatorSequence}.
{hitsCount} bonnes réponses, {missCount} erreurs.
Deux moments où nos esprits se sont connectés.
Au final, tu vas choisir ou tu vas juste croire choisir.''',

  '8|3': '''Tu vas faire huit choix.
Et je vais en deviner trois.
Tu vas choisir {spectatorSequence}.
{hitsCount} sur 8. Un peu moins de la moitié.
Mais ces trois réussites vont te hanter.
Au final, tu vas choisir ou tu vas juste croire choisir.''',

  '8|4': '''Tu vas faire huit choix.
Et je vais en deviner la moitié.
Tu vas choisir {spectatorSequence}.
{hitsCount} sur 8. L'équilibre parfait.
Quatre fois oui, quatre fois non. Mais rien de tout ça n'est le hasard.
Au final, tu vas choisir ou tu vas juste croire choisir.''',

  '8|5': '''Tu vas faire huit choix.
Et je vais en deviner cinq.
Tu vas choisir {spectatorSequence}.
{hitsCount} bonnes réponses sur 8. L'avantage est clair.
Les {missCount} erreurs ? Stratégiques.
Au final, tu vas choisir ou tu vas juste croire choisir.''',

  '8|6': '''Tu vas faire huit choix.
Et je vais en deviner six.
Tu vas choisir {spectatorSequence}.
{hitsCount} sur 8. Tu n'avais presque aucune chance.
Ces {missCount} erreurs ? Je te les ai offertes.
Au final, tu vas choisir ou tu vas juste croire choisir.''',

  '8|7': '''Tu vas faire huit choix.
Et je vais en deviner sept.
Tu vas choisir {spectatorSequence}.
{hitsCount} bonnes réponses sur 8. Écrasant.
Cette unique erreur ? Mon humanité qui transparaît.
Au final, tu vas choisir ou tu vas juste croire choisir.''',

  '8|8': '''Tu vas faire huit choix.
Et ces huit choix, je vais tous les deviner.
Tu vas choisir {spectatorSequence}.
Huit sur huit. Zéro erreur. Total.
Plus tu fais de choix, plus je te connais.
Au final, tu vas choisir ou tu vas juste croire choisir.''',

  // ============================================================
  // 9 ROUNDS (buckets: 0 hit à 9 hits)
  // ============================================================
  '9|0': '''Tu vas faire neuf choix.
Et ces neuf choix, je vais tous les rater.
Tu vas choisir {spectatorSequence}.
{missCount} erreurs. Tu vas penser m'avoir humilié.
Mais c'est l'inverse. Neuf défaites volontaires, c'est ma démonstration de pouvoir.
Au final, tu vas choisir ou tu vas juste croire choisir.''',

  '9|1': '''Tu vas faire neuf choix.
Et je vais en deviner un seul.
Tu vas choisir {spectatorSequence}.
{hitsCount} sur 9. Presque invisible.
Mais ce un suffit à tout remettre en question.
Au final, tu vas choisir ou tu vas juste croire choisir.''',

  '9|2': '''Tu vas faire neuf choix.
Et je vais en deviner deux.
Tu vas choisir {spectatorSequence}.
{hitsCount} bonnes réponses sur 9.
Deux éclairs de connexion dans une tempête d'incertitude.
Au final, tu vas choisir ou tu vas juste croire choisir.''',

  '9|3': '''Tu vas faire neuf choix.
Et je vais en deviner trois.
Tu vas choisir {spectatorSequence}.
{hitsCount} sur 9. Un tiers exactement.
Trois moments où j'ai vu clair dans ton esprit.
Au final, tu vas choisir ou tu vas juste croire choisir.''',

  '9|4': '''Tu vas faire neuf choix.
Et je vais en deviner quatre.
Tu vas choisir {spectatorSequence}.
{hitsCount} bonnes réponses, {missCount} erreurs.
Presque la moitié. Assez pour te troubler.
Au final, tu vas choisir ou tu vas juste croire choisir.''',

  '9|5': '''Tu vas faire neuf choix.
Et je vais en deviner la majorité.
Tu vas choisir {spectatorSequence}.
{hitsCount} sur 9. Plus de la moitié.
À partir de maintenant, c'est moi qui mène la danse.
Au final, tu vas choisir ou tu vas juste croire choisir.''',

  '9|6': '''Tu vas faire neuf choix.
Et je vais en deviner six.
Tu vas choisir {spectatorSequence}.
{hitsCount} bonnes réponses sur 9. Deux tiers.
Les {missCount} erreurs ? Des miettes que je te laisse.
Au final, tu vas choisir ou tu vas juste croire choisir.''',

  '9|7': '''Tu vas faire neuf choix.
Et je vais en deviner sept.
Tu vas choisir {spectatorSequence}.
{hitsCount} sur 9. Domination claire.
Tu n'avais que {missCount} moments de répit.
Au final, tu vas choisir ou tu vas juste croire choisir.''',

  '9|8': '''Tu vas faire neuf choix.
Et je vais en deviner huit.
Tu vas choisir {spectatorSequence}.
{hitsCount} bonnes réponses sur 9. Presque parfait.
Cette unique erreur ? Ma signature artistique.
Au final, tu vas choisir ou tu vas juste croire choisir.''',

  '9|9': '''Tu vas faire neuf choix.
Et ces neuf choix, je vais tous les deviner.
Tu vas choisir {spectatorSequence}.
Neuf sur neuf. La maîtrise absolue.
Neuf opportunités de m'échapper. Neuf échecs.
Au final, tu vas choisir ou tu vas juste croire choisir.''',

  // ============================================================
  // 10 ROUNDS (buckets: 0 hit à 10 hits)
  // ============================================================
  '10|0': '''Tu vas faire dix choix.
Et ces dix choix, je vais tous les rater.
Tu vas choisir {spectatorSequence}.
{missCount} erreurs. Dix sur dix à l'envers.
Un score parfait... dans le sens que j'ai choisi.
Au final, tu vas choisir ou tu vas juste croire choisir.''',

  '10|1': '''Tu vas faire dix choix.
Et je vais en deviner un seul.
Tu vas choisir {spectatorSequence}.
{hitsCount} sur 10. Dix pour cent.
Mais ce dix pour cent va te hanter longtemps.
Au final, tu vas choisir ou tu vas juste croire choisir.''',

  '10|2': '''Tu vas faire dix choix.
Et je vais en deviner deux.
Tu vas choisir {spectatorSequence}.
{hitsCount} bonnes réponses sur 10. Vingt pour cent.
Deux flashs de clairvoyance. Suffisant pour semer le doute.
Au final, tu vas choisir ou tu vas juste croire choisir.''',

  '10|3': '''Tu vas faire dix choix.
Et je vais en deviner trois.
Tu vas choisir {spectatorSequence}.
{hitsCount} sur 10. Presque un tiers.
Trois fois où ton esprit m'a parlé.
Au final, tu vas choisir ou tu vas juste croire choisir.''',

  '10|4': '''Tu vas faire dix choix.
Et je vais en deviner quatre.
Tu vas choisir {spectatorSequence}.
{hitsCount} bonnes réponses, {missCount} erreurs.
Quarante pour cent de lecture mentale réussie.
Au final, tu vas choisir ou tu vas juste croire choisir.''',

  '10|5': '''Tu vas faire dix choix.
Et je vais en deviner la moitié.
Tu vas choisir {spectatorSequence}.
{hitsCount} sur 10. Exactement 50%.
L'équilibre parfait entre mystère et certitude.
Au final, tu vas choisir ou tu vas juste croire choisir.''',

  '10|6': '''Tu vas faire dix choix.
Et je vais en deviner six.
Tu vas choisir {spectatorSequence}.
{hitsCount} bonnes réponses sur 10. La majorité.
Les {missCount} erreurs ? Du bruit de fond intentionnel.
Au final, tu vas choisir ou tu vas juste croire choisir.''',

  '10|7': '''Tu vas faire dix choix.
Et je vais en deviner sept.
Tu vas choisir {spectatorSequence}.
{hitsCount} sur 10. Soixante-dix pour cent.
Tu commences à réaliser l'ampleur de ma capacité.
Au final, tu vas choisir ou tu vas juste croire choisir.''',

  '10|8': '''Tu vas faire dix choix.
Et je vais en deviner huit.
Tu vas choisir {spectatorSequence}.
{hitsCount} bonnes réponses sur 10. Quatre-vingts pour cent.
Ces {missCount} erreurs ? Juste pour garder un peu de mystère.
Au final, tu vas choisir ou tu vas juste croire choisir.''',

  '10|9': '''Tu vas faire dix choix.
Et je vais en deviner neuf.
Tu vas choisir {spectatorSequence}.
{hitsCount} sur 10. Quasi perfection.
Une seule erreur sur dix. Et même celle-là était voulue.
Au final, tu vas choisir ou tu vas juste croire choisir.''',

  '10|10': '''Tu vas faire dix choix.
Et ces dix choix, je vais tous les deviner.
Tu vas choisir {spectatorSequence}.
Dix sur dix. La perfection absolue.
Dix chances de me surprendre. Dix échecs.
Au final, tu vas choisir ou tu vas juste croire choisir.''',
};

/// Récupère le texte bucket pour un nombre de rounds et de hits donné
String? getChoicesBucketText(int rounds, int hits) {
  final key = '$rounds|$hits';
  return choicesBucketsFR[key];
}

/// Applique les placeholders au texte
String applyChoicesPlaceholders(
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
