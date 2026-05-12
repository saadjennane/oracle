import 'dart:convert';
import '../models/confabulation_preset.dart';
import 'local_storage.dart';

/// Repository for Confabulation presets persistence
class ConfabulationRepository {
  static const _presetsKey = 'confabulation_presets';

  final LocalStorage _storage;

  ConfabulationRepository(this._storage);

  /// Get all confabulation presets
  Future<List<ConfabulationPreset>> listPresets() async {
    final jsonList = _storage.getStringList(_presetsKey) ?? [];

    return jsonList
        .map((json) {
          try {
            return ConfabulationPreset.fromJson(
              jsonDecode(json) as Map<String, dynamic>,
            );
          } catch (e) {
            return null;
          }
        })
        .whereType<ConfabulationPreset>()
        .toList();
  }

  /// Create or update a confabulation preset
  Future<void> savePreset(ConfabulationPreset preset) async {
    final presets = await listPresets();

    // Remove existing preset with same ID if exists
    presets.removeWhere((p) => p.id == preset.id);

    // Add preset with updated timestamp
    presets.add(preset.copyWith(updatedAt: DateTime.now()));

    // Persist
    await _savePresets(presets);
  }

  /// Update an existing preset
  Future<void> updatePreset(ConfabulationPreset preset) async {
    await savePreset(preset);
  }

  /// Delete a preset by ID
  Future<void> deletePreset(String id) async {
    final presets = await listPresets();
    presets.removeWhere((p) => p.id == id);
    await _savePresets(presets);
  }

  /// Get a specific preset by ID
  Future<ConfabulationPreset?> getPreset(String id) async {
    final presets = await listPresets();
    try {
      return presets.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Clear all confabulation presets
  Future<void> clearAll() async {
    await _storage.remove(_presetsKey);
  }

  /// Get preset count
  Future<int> getPresetCount() async {
    final jsonList = _storage.getStringList(_presetsKey) ?? [];
    return jsonList.length;
  }

  /// Private helper to save presets list
  Future<void> _savePresets(List<ConfabulationPreset> presets) async {
    // Sort by updatedAt descending (most recent first)
    presets.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final jsonList = presets.map((p) => jsonEncode(p.toJson())).toList();
    await _storage.setStringList(_presetsKey, jsonList);
  }
}
