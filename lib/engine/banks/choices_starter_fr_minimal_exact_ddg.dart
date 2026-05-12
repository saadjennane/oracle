/// Choices Starter Pack FR - Minimal Sober - Exact Sequences - Performer DDG
///
/// Bank de textes pré-écrits pour CHOICES binaire (2 options: Droite/Gauche).
/// Utilisé UNIQUEMENT quand:
/// - language = FR
/// - rounds ∈ {1, 2, 3}
/// - inputMode = preprogrammed
/// - performerSequence = DDG (premiers N caractères selon rounds)
///
/// Les clés sont les séquences spectateur: "D", "G", "DD", "DG", etc.
/// Les textes sont prêts à afficher, pas de placeholders.
///
/// Style: Minimal sobre
/// Temps: Futur

/// Bank indexée par spectatorSequence
const Map<String, String> choicesStarterFrMinimalExactDDG = {
  // ============================================================
  // ROUND 1 (performer joue D)
  // ============================================================
  'D': '''Tu vas faire droite.
Je vais deviner.
Simple.
Et si c'était ça le vrai truc, te laisser croire que tu décides.''',

  'G': '''Tu vas faire gauche.
Je vais me tromper exprès.
Juste assez pour te donner l'impression que tu m'échappes.
Et si c'était ça le vrai truc, te laisser croire que tu décides.''',

  // ============================================================
  // ROUND 2 (performer joue DD)
  // ============================================================
  'DD': '''Tu vas faire droite, droite.
Je vais deviner deux fois.
Tu vas te dire que c'est trop propre.
Et si c'était ça le vrai truc, te laisser croire que tu décides.''',

  'DG': '''Tu vas faire droite, gauche.
Je vais deviner la première.
La deuxième, je vais la rater exprès, juste pour te laisser respirer.
Et si c'était ça le vrai truc, te laisser croire que tu décides.''',

  'GD': '''Tu vas faire gauche, droite.
Je vais rater la première exprès.
La deuxième, je vais la deviner, juste pour te recadrer.
Et si c'était ça le vrai truc, te laisser croire que tu décides.''',

  'GG': '''Tu vas faire gauche, gauche.
Je vais rater la première exprès.
La deuxième, je vais aussi la rater, juste pour te laisser y croire.
Et si c'était ça le vrai truc, te laisser croire que tu décides.''',

  // ============================================================
  // ROUND 3 (performer joue DDG)
  // ============================================================
  'DDD': '''Tu vas faire droite, droite, droite.
Je vais deviner les deux premières fois.
La dernière, je vais la rater exprès, juste pour te laisser ce petit plaisir.
Et si c'était ça le vrai truc, te laisser croire que tu décides.''',

  'DDG': '''Tu vas faire droite, droite, gauche.
Je vais deviner les trois fois.
Tu vas croire que c'était ton idée d'être logique.
Et si c'était ça le vrai truc, te laisser croire que tu décides.''',

  'DGD': '''Tu vas faire droite, gauche, droite.
Je vais deviner la première.
Les deux autres, je vais les rater exprès, juste pour te laisser un peu d'air.
Et si c'était ça le vrai truc, te laisser croire que tu décides.''',

  'DGG': '''Tu vas faire droite, gauche, gauche.
Je vais deviner la première.
La deuxième, je vais la rater exprès.
Et la troisième, je vais la deviner.
Et si c'était ça le vrai truc, te laisser croire que tu décides.''',

  'GDD': '''Tu vas faire gauche, droite, droite.
Je vais rater la première exprès, pour te mettre en confiance.
La deuxième, je vais la deviner.
La troisième, je vais la rater exprès.
Et si c'était ça le vrai truc, te laisser croire que tu décides.''',

  'GDG': '''Tu vas faire gauche, droite, gauche.
Je vais rater la première exprès.
La deuxième, je vais la deviner.
La troisième, je vais la deviner.
Et si c'était ça le vrai truc, te laisser croire que tu décides.''',

  'GGD': '''Tu vas faire gauche, gauche, droite.
Je vais rater les deux premières exprès.
La dernière, je vais la rater aussi, juste pour te laisser le contrôle.
Et si c'était ça le vrai truc, te laisser croire que tu décides.''',

  'GGG': '''Tu vas faire gauche, gauche, gauche.
Je vais rater les deux premières exprès.
La dernière, je vais la deviner.
Et si c'était ça le vrai truc, te laisser croire que tu décides.''',
};

/// Séquence performer attendue pour DDG
const String performerSequenceDDG = 'DDG';

/// Vérifie si les conditions sont remplies pour utiliser cette bank
bool canUseChoicesStarterDDG({
  required String languageCode,
  required int rounds,
  required bool isPreprogrammed,
  required List<String> performerSequence,
  required List<String> options,
}) {
  // Language FR only
  if (languageCode != 'french') return false;

  // Rounds 1, 2, or 3 only
  if (rounds < 1 || rounds > 3) return false;

  // Preprogrammed only
  if (!isPreprogrammed) return false;

  // Binary options (2 options) only
  if (options.length != 2) return false;

  // Check performer sequence matches DDG pattern
  if (performerSequence.length < rounds) return false;

  final expectedDDG = performerSequenceDDG.substring(0, rounds);
  final actualSequence = _toSequenceKey(performerSequence.take(rounds).toList(), options);

  return actualSequence == expectedDDG;
}

/// Récupère le texte pour une séquence spectateur donnée
String? getChoicesStarterDDGText(List<String> spectatorChoices, List<String> options) {
  final key = _toSequenceKey(spectatorChoices, options);
  return choicesStarterFrMinimalExactDDG[key];
}

/// Convertit une liste de choix en clé de séquence (D/G)
/// options[0] = Droite (D), options[1] = Gauche (G)
String _toSequenceKey(List<String> choices, List<String> options) {
  if (options.length != 2) return '';

  final buffer = StringBuffer();
  for (final choice in choices) {
    if (choice == options[0]) {
      buffer.write('D');
    } else if (choice == options[1]) {
      buffer.write('G');
    }
  }
  return buffer.toString();
}
