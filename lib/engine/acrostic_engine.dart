import 'dart:math';

/// Engine for generating acrostic word columns.
/// Given a secret word, finds words from the bank where the Nth letter
/// of each word spells out the secret.
class AcrosticEngine {
  /// Word bank indexed by (letter, position) → list of words
  /// position is 0-based internally
  final Map<String, Map<int, List<String>>> _index = {};
  final List<String> _allWords;
  final Random _random = Random();

  /// Favorites: "letter:position" → word (optional, prioritized in selection)
  final Map<String, String>? favorites;

  AcrosticEngine(this._allWords, {this.favorites}) {
    _buildIndex();
  }

  void _buildIndex() {
    // Index is keyed by lowercase letters for matching, but stores the word
    // in its ORIGINAL casing so the acrostic output preserves what the user
    // typed (e.g. "Apple" stays "Apple", not "apple").
    for (final raw in _allWords) {
      final word = raw.trim();
      if (word.isEmpty) continue;
      for (int pos = 0; pos < word.length && pos < 6; pos++) {
        final letter = word[pos].toLowerCase();
        _index.putIfAbsent(letter, () => {});
        _index[letter]!.putIfAbsent(pos, () => []);
        _index[letter]![pos]!.add(word);
      }
    }
  }

  /// Generate an acrostic for the given secret word.
  /// Returns null if no valid position found.
  /// Tries positions 1-6 (1-based) and picks the first that works.
  /// Returns (words, position 1-based) or null.
  AcrosticResult? generate(String secret) {
    final letters = secret.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '').split('');
    if (letters.isEmpty) return null;

    // Try each position (0-based internally), shuffled for variety
    final positions = List.generate(6, (i) => i)..shuffle(_random);

    for (final pos in positions) {
      final words = _tryPosition(letters, pos);
      if (words != null) {
        return AcrosticResult(
          words: words,
          position: pos + 1, // 1-based for display
          secret: secret,
        );
      }
    }

    return null;
  }

  /// Generate with a preferred position (1-based). Falls back to others if not possible.
  AcrosticResult? generateAtPosition(String secret, int preferredPosition) {
    final letters = secret.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '').split('');
    if (letters.isEmpty) return null;

    final pos = preferredPosition - 1; // Convert to 0-based

    // Try preferred position first
    final words = _tryPosition(letters, pos);
    if (words != null) {
      return AcrosticResult(
        words: words,
        position: preferredPosition,
        secret: secret,
      );
    }

    // Fallback to any position
    return generate(secret);
  }

  List<String>? _tryPosition(List<String> letters, int pos) {
    final result = <String>[];
    final usedWords = <String>{};

    for (final letter in letters) {
      final candidates = _index[letter]?[pos];
      if (candidates == null || candidates.isEmpty) return null;

      // Filter out already used words
      final available = candidates.where((w) => !usedWords.contains(w)).toList();
      if (available.isEmpty) return null;

      // Check for favorite first
      final favKey = '$letter:$pos';
      final favWord = favorites?[favKey];
      String chosen;
      if (favWord != null && available.contains(favWord)) {
        chosen = favWord;
      } else {
        chosen = available[_random.nextInt(available.length)];
      }
      result.add(chosen);
      usedWords.add(chosen);
    }

    return result;
  }

  /// Check which positions are possible for a given secret
  List<int> availablePositions(String secret) {
    final letters = secret.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '').split('');
    if (letters.isEmpty) return [];

    final positions = <int>[];
    for (int pos = 0; pos < 6; pos++) {
      if (_tryPosition(letters, pos) != null) {
        positions.add(pos + 1); // 1-based
      }
    }
    return positions;
  }

  /// Default word bank
  static const List<String> defaultWordBank = [
    'abdomen', 'abdos', 'abeille', 'abstention', 'acier', 'acteur', 'adaptation',
    'adoption', 'adrenaline', 'adulte', 'affection', 'affiche', 'afrique',
    'agglomeration', 'agnostique', 'agriculture', 'agrume', 'aiguille', 'ajustement',
    'altitude', 'aluminum', 'amateur', 'ambassadeur', 'ami', 'amour', 'animal',
    'antenne', 'anxiete', 'appareil', 'appartement', 'aquarelle', 'aqueduc',
    'arbre', 'archipel', 'architecte', 'archive', 'armoire', 'artiste', 'athlete',
    'athletisme', 'atome', 'automobile', 'avalanche', 'avenir', 'aventure', 'avion',
    'avril', 'azote', 'azteque', 'bacterie', 'balade', 'balancoire', 'banjo',
    'banque', 'banquise', 'bateau', 'besoin', 'bijou', 'biochimie', 'biodiversite',
    'biogaz', 'biologie', 'biophysique', 'boheme', 'bois', 'bonheur', 'bouddhisme',
    'boussole', 'bouteille', 'bowling', 'boxe', 'bracelet', 'bronze', 'bureau',
    'cabane', 'camera', 'camion', 'canape', 'carbone', 'carburant', 'carnaval',
    'casserole', 'catalyse', 'cathedrale', 'cerise', 'champignon', 'charbon',
    'chasse', 'chateau', 'chauffage', 'chemin', 'cheval', 'chiffre', 'cinema',
    'citron', 'clavier', 'clip', 'cloche', 'cocktail', 'codex', 'collier',
    'comedie', 'confiance', 'confidence', 'conjugaison', 'couleur', 'couteau',
    'coworking', 'croix', 'croyance', 'cuivre', 'danse', 'darwin', 'decembre',
    'democratie', 'depart', 'derive', 'desert', 'design', 'desinformation',
    'dessin', 'diamant', 'dimanche', 'diplomatie', 'disque', 'divertissement',
    'djembe', 'djinn', 'docteur', 'doctorat', 'domaine', 'domino', 'dossier',
    'douceur', 'dragon', 'drapeau', 'ecole', 'ecologie', 'economie', 'ecosysteme',
    'ecotaxe', 'ecran', 'ecrivain', 'education', 'effet', 'egalite', 'electricite',
    'elegant', 'embryon', 'empire', 'encyclopedie', 'energie', 'enfant',
    'entrepreneur', 'entreprise', 'enveloppe', 'enzyme', 'epidemie', 'epingle',
    'equation', 'equipage', 'equipe', 'equitation', 'ersatz', 'escargot',
    'escroquerie', 'espoir', 'esthetique', 'ete', 'ethique', 'etoile', 'europe',
    'evasion', 'exil', 'explorateur', 'explosif', 'export', 'expression',
    'famille', 'fantastique', 'farine', 'fauteuil', 'femme', 'fenetre', 'festival',
    'feuille', 'fevrier', 'fiction', 'fief', 'fjord', 'flamme', 'flashback',
    'fleuve', 'flore', 'foret', 'fourchette', 'framework', 'france', 'frequence',
    'fresque', 'fromage', 'fusil', 'galerie', 'garage', 'gazon', 'gene',
    'genetique', 'geometrie', 'gilet', 'glacier', 'gobelet', 'gourde', 'gourmet',
    'gouvernement', 'graine', 'gravite', 'grece', 'greffier', 'grizzli', 'guitare',
    'habitude', 'hache', 'haiku', 'harmonie', 'hautparleur', 'hawai', 'helicoptere',
    'helium', 'herbivore', 'herisson', 'heritage', 'histoire', 'hiver', 'horizon',
    'horloge', 'humour', 'hybride', 'hydrogene', 'hydrojet', 'idee', 'iguane',
    'ile', 'illusion', 'image', 'impression', 'imprimante', 'indice', 'industrie',
    'infini', 'information', 'infrarouge', 'innovation', 'insecte', 'instant',
    'instrument', 'interphone', 'interview', 'invention', 'investissement',
    'istanbul', 'italie', 'ivoire', 'janvier', 'jardin', 'jeune', 'jeunesse',
    'joueur', 'journal', 'joyau', 'joystick', 'judo', 'juge', 'juillet', 'juin',
    'jumelles', 'jungle', 'justice', 'karate', 'karting', 'kayak', 'kazakhstan',
    'kilo', 'kilogramme', 'kilowatt', 'kimono', 'kiosque', 'kiwi', 'koala',
    'lac', 'lampe', 'langue', 'larynx', 'lecture', 'legende', 'levier', 'lexique',
    'lezard', 'liberte', 'liquide', 'lobby', 'logique', 'logo', 'loupe', 'lumiere',
    'lunettes', 'lutte', 'lynx', 'magazine', 'magie', 'maison', 'maki', 'maman',
    'mammifere', 'manifestation', 'manuscrit', 'marbre', 'marche', 'marine',
    'marketing', 'marquis', 'marteau', 'masque', 'mathematiques', 'medecin',
    'memoire', 'meteo', 'microphone', 'miracle', 'miroir', 'montre', 'mosaique',
    'moteur', 'motivation', 'multijoueur', 'musique', 'mystere', 'mystique',
    'mythologie', 'nature', 'navette', 'navire', 'nectar', 'neige', 'nickel',
    'nid', 'noblesse', 'noir', 'noix', 'nord', 'novembre', 'nuage', 'numero',
    'objectif', 'objet', 'ocean', 'octobre', 'ode', 'odeur', 'officier', 'ogre',
    'oiseau', 'ombre', 'opera', 'optique', 'or', 'orage', 'orange', 'orchidee',
    'ordinateur', 'orgue', 'outil', 'ouzbekistan', 'ovni', 'oxygene', 'ozone',
    'pacifique', 'paix', 'pancake', 'paprika', 'paquebot', 'paques', 'parapluie',
    'parfum', 'parking', 'patchwork', 'paysage', 'pendjabi', 'philosophie',
    'photo', 'photographe', 'photojournal', 'physique', 'piano', 'pince', 'pixel',
    'pizza', 'plage', 'plaisir', 'planification', 'plante', 'plomb', 'plume',
    'poele', 'poesie', 'poker', 'politique', 'polymere', 'poubelle', 'pouvoir',
    'prefecture', 'principe', 'projectile', 'proteine', 'psychiatre', 'psychiatrie',
    'psychologie', 'puzzle', 'qualite', 'quartier', 'quartz', 'question', 'quille',
    'radar', 'radio', 'raffraichissement', 'raison', 'raquette', 'recyclage',
    'refuge', 'regard', 'religion', 'remorque', 'requin', 'reve', 'revolution',
    'risque', 'rivage', 'riviere', 'robinet', 'rookie', 'route', 'royaume',
    'rubiks', 'russie', 'sac', 'saison', 'sandwich', 'sapajou', 'sarcophage',
    'science', 'sculpture', 'secret', 'serrure', 'sexe', 'shareware', 'sheriff',
    'showroom', 'silex', 'skateboard', 'sketch', 'ski', 'skipper', 'snowboard',
    'soja', 'soleil', 'sourire', 'sphere', 'sport', 'statue', 'style', 'stylo',
    'swahili', 'symbole', 'symphonie', 'syndicat', 'syntaxe', 'table', 'tableau',
    'taxi', 'telephone', 'telescope', 'teleski', 'television', 'temperature',
    'tempete', 'textile', 'theatre', 'thermos', 'thorax', 'tique', 'tourisme',
    'tournevis', 'tradition', 'trajectoire', 'tramway', 'trapeze', 'tresor',
    'triangle', 'trompette', 'tropique', 'tube', 'tunnel', 'twitter', 'ultraviolet',
    'univers', 'universite', 'urbanisme', 'urne', 'usage', 'ustensile', 'utile',
    'utopie', 'valise', 'velo', 'venezuela', 'ventilateur', 'verre', 'vert',
    'viande', 'victoire', 'village', 'violon', 'virus', 'vision', 'vitesse',
    'vizir', 'voiture', 'voyage', 'wagon', 'walkman', 'webcam', 'western',
    'whisky', 'wikipedia', 'xenon', 'xylophone', 'yacht', 'yak', 'yaourt', 'yen',
    'yeti', 'yoga', 'yoyo', 'zebre', 'zen', 'zenith', 'zeppelin', 'zinc',
    'zipper', 'zodiac', 'zombie', 'zone', 'zoo',
  ];
}

class AcrosticResult {
  final List<String> words;
  final int position; // 1-based
  final String secret;

  AcrosticResult({
    required this.words,
    required this.position,
    required this.secret,
  });

  /// Format as display text (one word per line)
  String toDisplayText() => words.join('\n');

  @override
  String toString() => 'Acrostic(secret: $secret, position: $position, words: $words)';
}
