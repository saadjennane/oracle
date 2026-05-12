/// Signature Prewritten Bank
///
/// Banque de textes pré-écrits pour les cas "signature" (performer sequence fixé).
/// Ces textes bypassent complètement le NarrativeAssembler pour un rendu optimal.
///
/// Note: Les textes sont embarqués en dur pour éviter les dépendances Flutter
/// dans les tests et garantir la disponibilité immédiate.

/// Cache statique pour les banques DDG
class SignaturePrewrittenBank {
  /// Map performerKey -> spectatorKey -> text
  static final Map<String, Map<String, String>> _banks = {
    'DDG': _ddgTexts,
  };

  /// Récupère le texte prewritten pour une combinaison performer/spectator
  static String? getText(String performerKey, String spectatorKey) {
    final bank = _banks[performerKey];
    if (bank == null) return null;
    return bank[spectatorKey];
  }

  /// Vérifie si une séquence performer a une banque prewritten
  static bool hasBank(String performerKey) {
    return _banks.containsKey(performerKey);
  }
}

/// Textes prewritten pour DDG (Droite, Droite, Gauche)
/// Ton: taquin, direct, futur
/// Chaque texte finit par: "Au final, t'as choisi ou t'as cru choisir."
const Map<String, String> _ddgTexts = {
  'DDD': '''Tu vas tenter la technique du tout à droite.
Je vais te laisser croire que ça marche.
Je vais te suivre sur deux tours, et sur le dernier je vais partir exprès à gauche pour te donner ce petit plaisir.
Au final, t'as choisi ou t'as cru choisir.''',

  'DDG': '''Tu vas faire deux fois droite, puis gauche au bon moment.
Audacieux. Et ça pourrait marcher… jamais contre un mentaliste.
Au final, t'as choisi ou t'as cru choisir.''',

  'DGD': '''Tu vas faire le zigzag classique : droite, gauche, droite.
Je vais deviner le premier, et je vais perdre exprès sur les deux derniers juste pour te donner la satisfaction de te dire que tu m'as eu.
Au final, t'as choisi ou t'as cru choisir.''',

  'DGG': '''Tu vas faire droite, puis deux fois gauche.
Je vais te laisser gagner au milieu, juste pour te laisser croire que ton switch m'a eu.
Au final, t'as choisi ou t'as cru choisir.''',

  'GDD': '''Tu vas faire gauche, puis deux fois droite.
Je vais perdre exprès au début et à la fin, juste pour te donner cette satisfaction de te dire que tu m'as eu.
Au final, t'as choisi ou t'as cru choisir.''',

  'GDG': '''Tu vas faire gauche, puis droite, puis gauche.
Je vais t'offrir un cadeau en perdant le premier tour, juste pour te mettre en confiance.
Au final, t'as choisi ou t'as cru choisir.''',

  'GGD': '''Tu vas faire gauche, gauche, puis droite.
Je vais perdre exprès tout le long, juste pour te laisser le plaisir de penser que t'as battu un mentaliste.
Sauf que battre un mentaliste est plus compliqué qu'on le pense.
Au final, t'as choisi ou t'as cru choisir.''',

  'GGG': '''Tu vas rester sur gauche du début à la fin.
Je vais te laisser les deux premiers tours, juste pour te donner l'impression que ta stratégie marche.
Et oui, cette stratégie peut marcher… jamais contre un mentaliste.
Au final, t'as choisi ou t'as cru choisir.''',
};

/// Convertit une séquence de choix en clé position-based (ex: ["Droite","Droite","Gauche"] → "112")
/// options[0] → "1", options[1] → "2". Label-agnostic.
String getSequenceKey(List<String> choices, {required List<String> options}) {
  return choices.map((c) {
    final idx = options.indexOf(c);
    return idx == 0 ? '1' : '2';
  }).join('');
}

/// Convertit une séquence Droite/Gauche en clé DDG (usage signature bank uniquement)
String toDDGKey(List<String> choices) {
  return choices.map((c) {
    final lower = c.toLowerCase();
    if (lower.startsWith('d') || lower.startsWith('r')) return 'D';
    return 'G';
  }).join('');
}
