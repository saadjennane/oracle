import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../data/local_storage.dart';
import '../engine/acrostic_engine.dart';

/// Manages acrostic word banks per language.
/// Persists in SharedPreferences as JSON.
class AcrosticProvider extends ChangeNotifier {
  final LocalStorage? _storage;

  // language code → list of words
  Map<String, List<String>> _banks = {};
  List<String> _languages = ['fr'];
  String _currentLanguage = 'fr';

  // Favorites: language → "letter:position" → word
  // e.g. "p:2" → "empire" (letter P at position 3, 0-based position 2)
  Map<String, Map<String, String>> _favorites = {};

  AcrosticProvider(this._storage) {
    _loadBanks();
  }

  String get currentLanguage => _currentLanguage;
  List<String> get languages => _languages;
  List<String> get currentWords => _banks[_currentLanguage] ?? [];

  void setCurrentLanguage(String lang) {
    _currentLanguage = lang;
    notifyListeners();
  }

  /// Add a new language
  Future<void> addLanguage(String code) async {
    final lower = code.trim().toLowerCase();
    if (lower.isEmpty || _languages.contains(lower)) return;
    _languages.add(lower);
    _banks[lower] = [];
    await _save();
    _currentLanguage = lower;
    notifyListeners();
  }

  /// Remove a language (can't remove last one)
  Future<void> removeLanguage(String code) async {
    if (_languages.length <= 1) return;
    _languages.remove(code);
    _banks.remove(code);
    if (_currentLanguage == code) {
      _currentLanguage = _languages.first;
    }
    await _save();
    notifyListeners();
  }

  /// Add words (one or multiple) to current language. Preserves the casing
  /// the user typed/pasted (e.g. "Apple" stays "Apple"). Deduplication is
  /// case-insensitive — adding "apple" after "Apple" is a no-op.
  Future<void> addWords(List<String> words) async {
    final bank = _banks.putIfAbsent(_currentLanguage, () => []);
    final existingLower = bank.map((w) => w.toLowerCase()).toSet();
    for (final w in words) {
      final clean = w.trim();
      if (clean.isEmpty) continue;
      final key = clean.toLowerCase();
      if (existingLower.contains(key)) continue;
      bank.add(clean);
      existingLower.add(key);
    }
    bank.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    await _save();
    notifyListeners();
  }

  /// Remove a word from current language
  Future<void> removeWord(String word) async {
    _banks[_currentLanguage]?.remove(word);
    await _save();
    notifyListeners();
  }

  /// Get favorite word for a letter at a position (0-based)
  String? getFavorite(String letter, int position) {
    final key = '${letter.toLowerCase()}:$position';
    return _favorites[_currentLanguage]?[key];
  }

  /// Set favorite word for a letter at a position (0-based). Null to clear.
  Future<void> setFavorite(String letter, int position, String? word) async {
    final key = '${letter.toLowerCase()}:$position';
    _favorites.putIfAbsent(_currentLanguage, () => {});
    if (word == null || word.isEmpty) {
      _favorites[_currentLanguage]!.remove(key);
    } else {
      _favorites[_currentLanguage]![key] = word;
    }
    await _save();
    notifyListeners();
  }

  /// Check if a word is the favorite for its letter at a given position
  bool isFavorite(String word, String letter, int position) {
    return getFavorite(letter, position) == word;
  }

  /// Get all favorites for the current language
  Map<String, String> get currentFavorites => _favorites[_currentLanguage] ?? {};

  /// Get the index for a specific position (0-based) and letter.
  /// Case-insensitive on the bank side: words are matched regardless of
  /// stored casing, but the original casing is preserved in the returned list.
  List<String> getWordsForLetterAtPosition(String letter, int position) {
    final bank = _banks[_currentLanguage] ?? [];
    final target = letter.toLowerCase();
    return bank
        .where((w) => w.length > position && w[position].toLowerCase() == target)
        .toList();
  }

  /// Get coverage stats for a position: Map<letter, count>
  Map<String, int> getCoverageForPosition(int position) {
    final bank = _banks[_currentLanguage] ?? [];
    final coverage = <String, int>{};
    for (int c = 0; c < 26; c++) {
      final letter = String.fromCharCode(97 + c); // a-z
      coverage[letter] = bank
          .where((w) => w.length > position && w[position].toLowerCase() == letter)
          .length;
    }
    return coverage;
  }

  /// Count letters with more than 3 words at a position (fully covered)
  int coveredLettersCount(int position) {
    final coverage = getCoverageForPosition(position);
    return coverage.values.where((c) => c > 3).length;
  }

  /// Get positions (1-6) that have meaningful coverage for a language
  /// A position is "available" if at least 10 letters have >0 words
  List<int> coveredPositionsForLanguage(String lang) {
    final bank = _banks[lang] ?? [];
    if (bank.isEmpty) return [];
    final positions = <int>[];
    for (int pos = 0; pos < 6; pos++) {
      int lettersWithWords = 0;
      for (int c = 0; c < 26; c++) {
        final letter = String.fromCharCode(97 + c);
        if (bank.any((w) => w.length > pos && w[pos].toLowerCase() == letter)) {
          lettersWithWords++;
        }
      }
      if (lettersWithWords >= 10) {
        positions.add(pos + 1); // 1-based
      }
    }
    return positions;
  }

  /// Stricter variant: only positions (1-6) where EVERY letter a-z has at
  /// least one word. Used in editors where the performer wants a guarantee
  /// that any spectator word will produce a valid acrostic column.
  List<int> fullyCoveredPositionsForLanguage(String lang) {
    final bank = _banks[lang] ?? [];
    if (bank.isEmpty) return [];
    final positions = <int>[];
    for (int pos = 0; pos < 6; pos++) {
      bool allCovered = true;
      for (int c = 0; c < 26; c++) {
        final letter = String.fromCharCode(97 + c);
        if (!bank.any((w) => w.length > pos && w[pos].toLowerCase() == letter)) {
          allCovered = false;
          break;
        }
      }
      if (allCovered) positions.add(pos + 1);
    }
    return positions;
  }

  /// Get an AcrosticEngine for the current language (with favorites)
  AcrosticEngine getEngine() {
    return AcrosticEngine(
      _banks[_currentLanguage] ?? AcrosticEngine.defaultWordBank,
      favorites: _favorites[_currentLanguage],
    );
  }

  /// Get an AcrosticEngine for a specific language (with favorites)
  AcrosticEngine getEngineForLanguage(String lang) {
    return AcrosticEngine(
      _banks[lang] ?? AcrosticEngine.defaultWordBank,
      favorites: _favorites[lang],
    );
  }

  Future<void> _loadBanks() async {
    if (_storage == null) return;
    try {
      final langsJson = _storage!.getString('acrostic_languages');
      if (langsJson != null) {
        _languages = (jsonDecode(langsJson) as List).cast<String>();
      }
      if (_languages.isEmpty) _languages = ['fr'];
      _currentLanguage = _languages.first;

      for (final lang in _languages) {
        final wordsJson = _storage!.getString('acrostic_bank_$lang');
        if (wordsJson != null) {
          _banks[lang] = (jsonDecode(wordsJson) as List).cast<String>();
        }
        final favsJson = _storage!.getString('acrostic_favs_$lang');
        if (favsJson != null) {
          _favorites[lang] = Map<String, String>.from(jsonDecode(favsJson) as Map);
        }
      }

      // Initialize French with default bank if empty
      if (!_banks.containsKey('fr') || _banks['fr']!.isEmpty) {
        _banks['fr'] = List.from(AcrosticEngine.defaultWordBank)..sort();
        await _save();
      }
    } catch (_) {
      _banks['fr'] = List.from(AcrosticEngine.defaultWordBank)..sort();
    }
    notifyListeners();
  }

  Future<void> _save() async {
    if (_storage == null) return;
    await _storage!.setString('acrostic_languages', jsonEncode(_languages));
    for (final lang in _languages) {
      final words = _banks[lang] ?? [];
      await _storage!.setString('acrostic_bank_$lang', jsonEncode(words));
      final favs = _favorites[lang];
      if (favs != null && favs.isNotEmpty) {
        await _storage!.setString('acrostic_favs_$lang', jsonEncode(favs));
      }
    }
  }
}
