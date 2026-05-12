import '../data/local_storage.dart';

/// Tracks IDs of objects deleted locally so that iCloud merge does not
/// resurrect them when pulling from another device.
class TombstoneStore {
  static const _presetsKey = '_tombstones_presets';
  static const _confabKey = '_tombstones_confab';
  static const _routinesKey = '_tombstones_routines';

  static Future<LocalStorage> _storage() async {
    final s = LocalStorage();
    await s.init();
    return s;
  }

  static Future<void> _addTo(String storageKey, String id) async {
    final s = await _storage();
    final existing = s.getStringList(storageKey) ?? <String>[];
    if (existing.contains(id)) return;
    existing.add(id);
    await s.setStringList(storageKey, existing);
  }

  static Future<Set<String>> _getFrom(String storageKey) async {
    final s = await _storage();
    final list = s.getStringList(storageKey) ?? <String>[];
    return list.toSet();
  }

  static Future<void> addDeletedPreset(String id) => _addTo(_presetsKey, id);
  static Future<void> addDeletedConfab(String id) => _addTo(_confabKey, id);
  static Future<void> addDeletedRoutine(String id) => _addTo(_routinesKey, id);

  static Future<Set<String>> getDeletedPresets() => _getFrom(_presetsKey);
  static Future<Set<String>> getDeletedConfabs() => _getFrom(_confabKey);
  static Future<Set<String>> getDeletedRoutines() => _getFrom(_routinesKey);

  /// Merge tombstones received from cloud (union).
  static Future<void> mergeCloudTombstones({
    required Set<String> cloudPresets,
    required Set<String> cloudConfabs,
    required Set<String> cloudRoutines,
  }) async {
    final s = await _storage();
    final curPresets = (s.getStringList(_presetsKey) ?? <String>[]).toSet();
    final curConfabs = (s.getStringList(_confabKey) ?? <String>[]).toSet();
    final curRoutines = (s.getStringList(_routinesKey) ?? <String>[]).toSet();
    await s.setStringList(_presetsKey, {...curPresets, ...cloudPresets}.toList());
    await s.setStringList(_confabKey, {...curConfabs, ...cloudConfabs}.toList());
    await s.setStringList(_routinesKey, {...curRoutines, ...cloudRoutines}.toList());
  }
}
