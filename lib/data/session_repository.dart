import 'dart:convert';
import '../models/models.dart';
import 'local_storage.dart';

class SessionRepository {
  static const _sessionsKey = 'game_sessions';
  static const _maxSessions = 20;

  final LocalStorage _storage;

  SessionRepository(this._storage);

  /// Get recent sessions (up to limit)
  Future<List<GameSession>> getRecentSessions({int limit = 5}) async {
    final jsonList = _storage.getStringList(_sessionsKey) ?? [];

    return jsonList
        .map((json) => GameSession.fromJson(jsonDecode(json) as Map<String, dynamic>))
        .take(limit)
        .toList();
  }

  /// Save a session (maintains max 5 sessions)
  Future<void> saveSession(GameSession session) async {
    final sessions = await getRecentSessions(limit: _maxSessions);

    // Remove existing session with same ID if exists
    sessions.removeWhere((s) => s.id == session.id);

    // Remove oldest if at capacity
    while (sessions.length >= _maxSessions) {
      sessions.removeLast();
    }

    // Add new session at front
    sessions.insert(0, session);

    // Persist
    final jsonList = sessions.map((s) => jsonEncode(s.toJson())).toList();
    await _storage.setStringList(_sessionsKey, jsonList);
  }

  /// Get a specific session by ID
  Future<GameSession?> getSession(String id) async {
    final sessions = await getRecentSessions();
    try {
      return sessions.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Delete a session
  Future<void> deleteSession(String id) async {
    final sessions = await getRecentSessions();
    sessions.removeWhere((s) => s.id == id);

    final jsonList = sessions.map((s) => jsonEncode(s.toJson())).toList();
    await _storage.setStringList(_sessionsKey, jsonList);
  }

  /// Clear all sessions
  Future<void> clearAll() async {
    await _storage.remove(_sessionsKey);
  }

  /// Get session count
  Future<int> getSessionCount() async {
    final jsonList = _storage.getStringList(_sessionsKey) ?? [];
    return jsonList.length;
  }
}
