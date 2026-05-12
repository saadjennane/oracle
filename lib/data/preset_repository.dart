import 'dart:convert';
import '../models/models.dart';
import 'local_storage.dart';

class PresetRepository {
  static const _presetsKey = 'presets';

  final LocalStorage _storage;

  PresetRepository(this._storage);

  /// Get all presets
  Future<List<Preset>> listPresets() async {
    final jsonList = _storage.getStringList(_presetsKey) ?? [];

    return jsonList
        .map((json) {
          try {
            return Preset.fromJson(jsonDecode(json) as Map<String, dynamic>);
          } catch (e) {
            return null;
          }
        })
        .whereType<Preset>()
        .toList();
  }

  /// Create or update a preset
  Future<void> upsertPreset(Preset preset) async {
    final presets = await listPresets();

    // Remove existing preset with same ID if exists
    presets.removeWhere((p) => p.id == preset.id);

    // Add preset
    presets.add(preset);

    // Persist
    await _savePresets(presets);
  }

  /// Delete a preset by ID
  Future<void> deletePreset(String id) async {
    final presets = await listPresets();
    presets.removeWhere((p) => p.id == id);
    await _savePresets(presets);
  }

  /// Get a specific preset by ID
  Future<Preset?> getPreset(String id) async {
    final presets = await listPresets();
    try {
      return presets.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Clear all presets
  Future<void> clearAll() async {
    await _storage.remove(_presetsKey);
  }

  /// Get preset count
  Future<int> getPresetCount() async {
    final jsonList = _storage.getStringList(_presetsKey) ?? [];
    return jsonList.length;
  }

  /// Save all presets (for reordering)
  Future<void> saveAll(List<Preset> presets) async {
    await _savePresets(presets);
  }

  /// Private helper to save presets list
  Future<void> _savePresets(List<Preset> presets) async {
    final jsonList = presets.map((p) => jsonEncode(p.toJson())).toList();
    await _storage.setStringList(_presetsKey, jsonList);
  }
}
