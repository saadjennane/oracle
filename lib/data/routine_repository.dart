import 'dart:convert';
import '../models/routine.dart';
import 'local_storage.dart';

class RoutineRepository {
  static const _routinesKey = 'routines';

  final LocalStorage _storage;

  RoutineRepository(this._storage);

  Future<List<Routine>> listRoutines() async {
    final jsonList = _storage.getStringList(_routinesKey) ?? [];
    return jsonList
        .map((json) {
          try {
            return Routine.fromJson(jsonDecode(json) as Map<String, dynamic>);
          } catch (e) {
            return null;
          }
        })
        .whereType<Routine>()
        .toList();
  }

  Future<void> upsertRoutine(Routine routine) async {
    final routines = await listRoutines();
    routines.removeWhere((r) => r.id == routine.id);
    routines.add(routine);
    await _saveRoutines(routines);
  }

  Future<void> deleteRoutine(String id) async {
    final routines = await listRoutines();
    routines.removeWhere((r) => r.id == id);
    await _saveRoutines(routines);
  }

  Future<Routine?> getRoutine(String id) async {
    final routines = await listRoutines();
    try {
      return routines.firstWhere((r) => r.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveAll(List<Routine> routines) async {
    await _saveRoutines(routines);
  }

  Future<void> _saveRoutines(List<Routine> routines) async {
    final jsonList = routines.map((r) => jsonEncode(r.toJson())).toList();
    await _storage.setStringList(_routinesKey, jsonList);
  }
}
