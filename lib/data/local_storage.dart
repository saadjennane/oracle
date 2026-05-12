import 'package:shared_preferences/shared_preferences.dart';

class LocalStorage {
  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  SharedPreferences get prefs {
    if (_prefs == null) {
      throw StateError('LocalStorage not initialized. Call init() first.');
    }
    return _prefs!;
  }

  // String operations
  Future<bool> setString(String key, String value) async {
    return prefs.setString(key, value);
  }

  String? getString(String key) {
    return prefs.getString(key);
  }

  // Int operations
  Future<bool> setInt(String key, int value) async {
    return prefs.setInt(key, value);
  }

  int? getInt(String key) {
    return prefs.getInt(key);
  }

  // Bool operations
  Future<bool> setBool(String key, bool value) async {
    return prefs.setBool(key, value);
  }

  bool? getBool(String key) {
    return prefs.getBool(key);
  }

  // List operations
  Future<bool> setStringList(String key, List<String> value) async {
    return prefs.setStringList(key, value);
  }

  List<String>? getStringList(String key) {
    return prefs.getStringList(key);
  }

  // Delete
  Future<bool> remove(String key) async {
    return prefs.remove(key);
  }

  Future<bool> clear() async {
    return prefs.clear();
  }

  // Check if key exists
  bool containsKey(String key) {
    return prefs.containsKey(key);
  }

  Set<String> getKeys() {
    return prefs.getKeys();
  }
}
