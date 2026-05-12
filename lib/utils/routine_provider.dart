import 'package:flutter/foundation.dart';
import '../models/routine.dart';
import '../data/routine_repository.dart';
import '../services/icloud_sync_service.dart';
import '../services/tombstone_store.dart';

class RoutineProvider extends ChangeNotifier {
  final RoutineRepository? _repository;
  List<Routine> _routines = [];
  bool _isLoading = false;
  String? _error;

  RoutineProvider(this._repository);

  List<Routine> get routines => _routines;
  bool get isLoading => _isLoading;
  bool get isEmpty => _routines.isEmpty;
  String? get error => _error;

  Future<void> loadRoutines() async {
    if (_repository == null) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _routines = await _repository!.listRoutines();
    } catch (e) {
      _error = 'Failed to load routines: $e';
      _routines = [];
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> addRoutine(Routine routine) async {
    if (_repository == null) {
      _error = 'Storage not available';
      notifyListeners();
      return false;
    }

    final errors = routine.validate();
    if (errors.isNotEmpty) {
      _error = errors.first;
      notifyListeners();
      return false;
    }

    try {
      await _repository!.upsertRoutine(routine);
      _routines.add(routine);
      _error = null;
      notifyListeners();
      _scheduleSync();
      return true;
    } catch (e) {
      _error = 'Failed to save routine: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateRoutine(Routine routine) async {
    if (_repository == null) {
      _error = 'Storage not available';
      notifyListeners();
      return false;
    }

    final errors = routine.validate();
    if (errors.isNotEmpty) {
      _error = errors.first;
      notifyListeners();
      return false;
    }

    try {
      await _repository!.upsertRoutine(routine);
      final index = _routines.indexWhere((r) => r.id == routine.id);
      if (index >= 0) {
        _routines[index] = routine;
      } else {
        _routines.add(routine);
      }
      _error = null;
      notifyListeners();
      _scheduleSync();
      return true;
    } catch (e) {
      _error = 'Failed to update routine: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteRoutine(String id) async {
    if (_repository == null) {
      _error = 'Storage not available';
      notifyListeners();
      return false;
    }

    try {
      await _repository!.deleteRoutine(id);
      _routines.removeWhere((r) => r.id == id);
      await TombstoneStore.addDeletedRoutine(id);
      _error = null;
      notifyListeners();
      _scheduleSync();
      return true;
    } catch (e) {
      _error = 'Failed to delete routine: $e';
      notifyListeners();
      return false;
    }
  }

  Routine? getRoutineById(String id) {
    try {
      return _routines.firstWhere((r) => r.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Find the routine that contains a given preset ID
  Routine? getRoutineForPreset(String presetId) {
    try {
      return _routines.firstWhere(
        (r) => r.inputOrder.contains(presetId),
      );
    } catch (_) {
      return null;
    }
  }

  /// Remove a preset ID from all routines (when preset is deleted)
  Future<void> removePresetFromRoutines(String presetId) async {
    final toUpdate = <Routine>[];
    final toDelete = <String>[];

    for (final routine in _routines) {
      if (routine.inputOrder.contains(presetId)) {
        final newInput = routine.inputOrder.where((id) => id != presetId).toList();
        final newOutput = routine.outputOrder.where((id) => id != presetId).toList();
        if (newInput.length < 2) {
          toDelete.add(routine.id);
        } else {
          toUpdate.add(routine.copyWith(inputOrder: newInput, outputOrder: newOutput));
        }
      }
    }

    for (final id in toDelete) {
      await deleteRoutine(id);
    }
    for (final routine in toUpdate) {
      await updateRoutine(routine);
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void _scheduleSync() => ICloudSyncService.scheduleAutoPush();
}
