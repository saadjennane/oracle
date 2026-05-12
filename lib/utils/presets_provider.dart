import 'package:flutter/foundation.dart';
import '../models/models.dart';
import '../data/data.dart';
import '../services/icloud_sync_service.dart';
import '../services/tombstone_store.dart';

class PresetsProvider extends ChangeNotifier {
  final PresetRepository? _repository;
  List<Preset> _presets = [];
  bool _isLoading = false;
  String? _error;

  PresetsProvider(this._repository);

  // Getters
  List<Preset> get presets => _presets;
  bool get isLoading => _isLoading;
  bool get isEmpty => _presets.isEmpty;
  String? get error => _error;

  /// Load all presets from storage
  Future<void> loadPresets() async {
    if (_repository == null) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _presets = await _repository!.listPresets();
      await _migrateCreatedAt();
    } catch (e) {
      _error = 'Failed to load presets: $e';
      _presets = [];
    }

    _isLoading = false;
    notifyListeners();
  }

  /// One-time backfill of `createdAt` for legacy presets that were saved
  /// before the field existed. Assigns sequential epoch-based timestamps
  /// matching the persisted list order, then writes the migrated values
  /// back to storage so the assignment is stable across launches.
  Future<void> _migrateCreatedAt() async {
    bool changed = false;
    for (int i = 0; i < _presets.length; i++) {
      if (_presets[i].createdAt == null) {
        // i * 1000ms keeps presets sortable and well below DateTime.now(),
        // so any new preset created later naturally lands at the bottom.
        _presets[i] = _presets[i].copyWith(
          createdAt: DateTime.fromMillisecondsSinceEpoch(i * 1000),
        );
        changed = true;
      }
    }
    if (changed && _repository != null) {
      await _repository!.saveAll(_presets);
    }
  }

  /// Add a new preset
  Future<bool> addPreset(Preset preset) async {
    if (_repository == null) {
      _error = 'Storage not available';
      notifyListeners();
      return false;
    }

    // Validate preset
    final errors = preset.validate();
    if (errors.isNotEmpty) {
      _error = errors.first;
      notifyListeners();
      return false;
    }

    try {
      // Stamp updatedAt + ensure createdAt is set so the new preset shows
      // up at the bottom of the home-screen chronological list. Existing
      // createdAt (from JSON import) is preserved.
      Preset stamped = preset.withTimestampNow();
      if (stamped.createdAt == null) {
        stamped = stamped.copyWith(createdAt: DateTime.now());
      }
      await _repository!.upsertPreset(stamped);
      _presets.add(stamped);
      _error = null;
      notifyListeners();
      _scheduleSync();
      return true;
    } catch (e) {
      _error = 'Failed to save preset: $e';
      notifyListeners();
      return false;
    }
  }

  /// Update a preset's createdAt (used to persist drag-reorder on the home
  /// screen — the new value places it between its new neighbours in the
  /// merged chronological list).
  Future<void> setPresetCreatedAt(String id, DateTime createdAt) async {
    final idx = _presets.indexWhere((p) => p.id == id);
    if (idx < 0) return;
    final updated = _presets[idx].copyWith(createdAt: createdAt);
    _presets[idx] = updated;
    notifyListeners();
    if (_repository != null) {
      await _repository!.upsertPreset(updated);
      _scheduleSync();
    }
  }

  /// Update an existing preset
  Future<bool> updatePreset(Preset preset) async {
    if (_repository == null) {
      _error = 'Storage not available';
      notifyListeners();
      return false;
    }

    // Validate preset
    final errors = preset.validate();
    if (errors.isNotEmpty) {
      _error = errors.first;
      notifyListeners();
      return false;
    }

    try {
      final stamped = preset.withTimestampNow();
      await _repository!.upsertPreset(stamped);

      // Update in local list
      final index = _presets.indexWhere((p) => p.id == stamped.id);
      if (index >= 0) {
        _presets[index] = stamped;
      } else {
        _presets.add(stamped);
      }

      _error = null;
      notifyListeners();
      _scheduleSync();
      return true;
    } catch (e) {
      _error = 'Failed to update preset: $e';
      notifyListeners();
      return false;
    }
  }

  /// Reorder presets
  Future<void> reorderPresets(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) newIndex -= 1;
    final item = _presets.removeAt(oldIndex);
    _presets.insert(newIndex, item);
    notifyListeners();
    // Persist new order
    if (_repository != null) {
      await _repository!.saveAll(_presets);
      _scheduleSync();
    }
  }

  /// Delete a preset by ID
  Future<bool> deletePreset(String id) async {
    if (_repository == null) {
      _error = 'Storage not available';
      notifyListeners();
      return false;
    }

    try {
      await _repository!.deletePreset(id);
      _presets.removeWhere((p) => p.id == id);
      await TombstoneStore.addDeletedPreset(id);
      _error = null;
      notifyListeners();
      _scheduleSync();
      return true;
    } catch (e) {
      _error = 'Failed to delete preset: $e';
      notifyListeners();
      return false;
    }
  }

  /// Get a preset by ID
  Preset? getPresetById(String id) {
    try {
      return _presets.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  void _scheduleSync() => ICloudSyncService.scheduleAutoPush();
}
