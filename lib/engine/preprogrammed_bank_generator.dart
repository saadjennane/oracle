/// Preprogrammed Bank Generator
///
/// Génère des textes "starter" pour les banques preprogrammed.
/// Style: ultra direct, futur, taquin.
/// Pas de LLM, tout en local.

/// Génère une banque complète pour une séquence performer donnée
/// [performerKey] ex: "DDG" pour Droite, Droite, Gauche
/// [nbRounds] nombre de rounds (3 ou 5)
/// [labels] les labels des options (ex: ["Gauche", "Droite"])
Map<String, String> generateStarterBank({
  required String performerKey,
  required int nbRounds,
  required List<String> labels,
}) {
  if (nbRounds != 3) {
    // Pour l'instant on ne supporte que 3 rounds
    return {};
  }

  // Pour 3 rounds avec 2 options, on a 8 combinaisons possibles
  final spectatorKeys = _generateAllKeys(nbRounds);
  final bank = <String, String>{};

  for (final spectatorKey in spectatorKeys) {
    bank[spectatorKey] = _generateText(
      performerKey: performerKey,
      spectatorKey: spectatorKey,
      labels: labels,
    );
  }

  return bank;
}

/// Génère toutes les clés possibles pour n rounds (2 options)
List<String> _generateAllKeys(int nbRounds) {
  if (nbRounds == 3) {
    return ['DDD', 'DDG', 'DGD', 'DGG', 'GDD', 'GDG', 'GGD', 'GGG'];
  }
  // Pour 5 rounds, on aurait 32 combinaisons - pas supporté pour l'instant
  return [];
}

/// Génère un texte pour une combinaison performer/spectator
String _generateText({
  required String performerKey,
  required String spectatorKey,
  required List<String> labels,
}) {
  // Calculer les miss indices
  final missIndices = <int>[];
  for (int i = 0; i < performerKey.length; i++) {
    if (performerKey[i] != spectatorKey[i]) {
      missIndices.add(i);
    }
  }

  // Déterminer le label "gauche" et "droite"
  String leftLabel = labels.isNotEmpty ? labels[0].toLowerCase() : 'gauche';
  String rightLabel = labels.length > 1 ? labels[1].toLowerCase() : 'droite';

  // Convertir spectatorKey en description lisible
  final spectatorDesc = _describeSequence(spectatorKey, leftLabel, rightLabel);

  // Générer le texte selon le nombre de miss
  final lines = <String>[];

  // Ligne 1: Annonce de la séquence spectateur
  lines.add(_getOpenerLine(spectatorKey, spectatorDesc, leftLabel, rightLabel));

  // Ligne 2: Commentaire taquin sur la tactique
  lines.add(_getTacticLine(spectatorKey, missIndices.length));

  // Ligne 3: Mention des cadeaux si miss
  if (missIndices.isNotEmpty) {
    lines.add(_getGiftLine(missIndices, performerKey.length));
  }

  // Ligne 4: Punchline libre-arbitre
  lines.add("Au final, t'as choisi ou t'as cru choisir.");

  return lines.join('\n');
}

/// Décrit une séquence en français lisible
String _describeSequence(String key, String left, String right) {
  final parts = <String>[];
  for (final c in key.split('')) {
    parts.add(c == 'D' ? right : left);
  }

  // Compter les répétitions consécutives
  if (key == 'DDD') return 'la technique du tout à $right';
  if (key == 'GGG') return '$left du début à la fin';
  if (key == 'DGD' || key == 'GDG') return 'le zigzag classique : ${parts.join(', ')}';

  // Pattern avec répétition
  if (key.startsWith('DD')) return 'deux fois $right, puis $left';
  if (key.startsWith('GG')) return 'deux fois $left, puis $right';
  if (key.endsWith('DD')) return '$left, puis deux fois $right';
  if (key.endsWith('GG')) return '$right, puis deux fois $left';

  return parts.join(', puis ');
}

/// Ligne d'ouverture selon la séquence
String _getOpenerLine(String key, String desc, String left, String right) {
  if (key == 'DDD' || key == 'GGG') {
    final side = key == 'DDD' ? right : left;
    return "Tu vas utiliser la fameuse technique de rester sur la même main, la $side, pour m'avoir.";
  }
  if (key == 'DGD' || key == 'GDG') {
    return "Si mon conditionnement est bon, tu vas faire $desc.";
  }
  return "Tu vas faire $desc.";
}

/// Ligne de commentaire taquin
String _getTacticLine(String key, int missCount) {
  if (missCount == 0) {
    return "C'est une tactique audacieuse qui aurait pu marcher, mais jamais contre un mentaliste.";
  }
  if (key == 'DDD' || key == 'GGG') {
    return "Elle peut marcher, mais jamais contre un mentaliste.";
  }
  return "Audacieux.";
}

/// Ligne mentionnant les cadeaux (miss intentionnels)
String _getGiftLine(List<int> missIndices, int totalRounds) {
  if (missIndices.length == totalRounds) {
    return "Je vais me tromper exprès tout le long, juste pour te laisser le plaisir de penser que t'as battu un mentaliste.\nSauf que battre un mentaliste est beaucoup plus compliqué qu'on le pense.";
  }

  if (missIndices.length == 1) {
    final roundNum = missIndices[0] + 1;
    if (roundNum == 1) {
      return "Je t'offre un cadeau en perdant le premier tour, juste pour te mettre en confiance.";
    } else if (roundNum == 2) {
      return "Je te laisse gagner le deuxième tour juste pour te donner le plaisir de penser que ton switch m'a eu.";
    } else {
      return "Je vais te laisser gagner le dernier tour, juste pour te donner ce plaisir.\nSauf que même cette erreur était prévue.";
    }
  }

  if (missIndices.length == 2) {
    if (missIndices.contains(0) && missIndices.contains(2)) {
      return "Je vais perdre exprès au début et à la fin, juste pour te donner cette satisfaction.";
    }
    if (missIndices.contains(1) && missIndices.contains(2)) {
      return "Je vais deviner le premier, puis perdre exprès sur les deux derniers pour te laisser ce plaisir.";
    }
    return "Je vais perdre exprès deux fois, juste pour te donner cette satisfaction.";
  }

  return "Je vais te laisser quelques tours, juste pour te donner l'impression que ta stratégie marche.";
}

/// Textes starter hardcodés pour DDG (utilisés comme fallback/référence)
const Map<String, String> ddgStarterTexts = {
  'DDD': '''Tu vas utiliser la fameuse technique de rester sur la même main, la droite, pour m'avoir.
Je vais te laisser gagner le dernier tour, juste pour te donner ce plaisir.
Sauf que même cette erreur était prévue.
Au final, t'as choisi ou t'as cru choisir.''',

  'DDG': '''Tu vas faire droite, droite, puis gauche à la fin.
C'est une tactique audacieuse qui aurait pu marcher, mais jamais contre un mentaliste.
Au final, t'as choisi ou t'as cru choisir.''',

  'DGD': '''Si mon conditionnement est bon, tu vas faire le zigzag droite, gauche, droite.
Je vais deviner le premier, puis perdre exprès sur les deux derniers pour te laisser ce plaisir.
Au final, t'as choisi ou t'as cru choisir.''',

  'DGG': '''Tu vas faire droite, puis deux fois gauche.
Je te laisse gagner le deuxième tour juste pour te donner le plaisir de penser que ton switch m'a eu.
Au final, t'as choisi ou t'as cru choisir.''',

  'GDD': '''Tu vas faire gauche, puis deux fois droite.
Je vais perdre exprès au début et à la fin, juste pour te donner cette satisfaction.
Au final, t'as choisi ou t'as cru choisir.''',

  'GDG': '''Tu vas faire gauche, puis droite, puis gauche.
Je t'offre un cadeau en perdant le premier tour, juste pour te mettre en confiance.
Au final, t'as choisi ou t'as cru choisir.''',

  'GGD': '''Tu vas faire gauche, gauche, puis droite.
Je vais me tromper exprès tout le long, juste pour te laisser le plaisir de penser que t'as battu un mentaliste.
Sauf que battre un mentaliste est beaucoup plus compliqué qu'on le pense.
Au final, t'as choisi ou t'as cru choisir.''',

  'GGG': '''Tu vas rester sur gauche du début à la fin.
Je vais te laisser les deux premiers tours, juste pour te donner l'impression que ta stratégie marche.
Elle peut marcher, mais jamais contre un mentaliste.
Au final, t'as choisi ou t'as cru choisir.''',
};
