import 'package:flutter/foundation.dart';
import '../models/models.dart';
import '../data/data.dart';

class HistoryProvider extends ChangeNotifier {
  final SessionRepository? _repository;
  List<GameSession> _sessions = [];
  bool _isLoading = false;

  HistoryProvider(this._repository);

  List<GameSession> get sessions => _sessions;
  bool get isLoading => _isLoading;
  bool get isEmpty => _sessions.isEmpty;

  Future<void> loadHistory() async {
    if (_repository == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      _sessions = await _repository!.getRecentSessions(limit: 20);
    } catch (e) {
      _sessions = [];
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> deleteSession(String id) async {
    await _repository?.deleteSession(id);
    _sessions.removeWhere((s) => s.id == id);
    notifyListeners();
  }

  Future<void> clearHistory() async {
    await _repository?.clearAll();
    _sessions = [];
    notifyListeners();
  }

  GameSession? getSession(String id) {
    try {
      return _sessions.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }
}
