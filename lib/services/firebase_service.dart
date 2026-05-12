import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/decoy_template.dart';

/// Firebase Realtime Database service using REST API.
/// No native SDK needed — simple HTTP calls.
class FirebaseService {
  static const String _databaseUrl =
      'https://oracle-5233b-default-rtdb.europe-west1.firebasedatabase.app';

  /// Push a full session to Firebase
  static Future<bool> pushSession(String assistantId, Map<String, dynamic> sessionData) async {
    try {
      final url = '$_databaseUrl/sessions/$assistantId.json';
      final response = await http.put(
        Uri.parse(url),
        body: jsonEncode(sessionData),
      ).timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Update a specific field in the session
  static Future<bool> updateSession(String assistantId, Map<String, dynamic> updates) async {
    try {
      final url = '$_databaseUrl/sessions/$assistantId.json';
      final response = await http.patch(
        Uri.parse(url),
        body: jsonEncode(updates),
      ).timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Read the current input from Firebase
  static Future<Map<String, dynamic>?> readInput(String assistantId) async {
    try {
      final url = '$_databaseUrl/sessions/$assistantId/input.json';
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 3));
      if (response.statusCode != 200 || response.body == 'null') return null;
      return jsonDecode(response.body) as Map<String, dynamic>?;
    } catch (_) {
      return null;
    }
  }

  /// Clear the input field (after processing)
  static Future<bool> clearInput(String assistantId) async {
    try {
      final url = '$_databaseUrl/sessions/$assistantId/input.json';
      final response = await http.delete(Uri.parse(url)).timeout(const Duration(seconds: 3));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Read free text from Firebase
  static Future<Map<String, dynamic>?> readFreeText(String assistantId) async {
    try {
      final url = '$_databaseUrl/sessions/$assistantId/freeText.json';
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 3));
      if (response.statusCode != 200 || response.body == 'null') return null;
      return jsonDecode(response.body) as Map<String, dynamic>?;
    } catch (_) {
      return null;
    }
  }

  /// Clear the session (set to idle)
  static Future<bool> clearSession(String assistantId) async {
    return pushSession(assistantId, {'state': 'idle'});
  }

  /// Push active session with preset data
  static Future<bool> pushActiveSession({
    required String assistantId,
    required String presetName,
    required String presetType,
    required List<String> options,
    required int currentRound,
    required int totalRounds,
    required String inputMode,
    List<String>? chain,
    int chainIndex = 0,
    String? redirectUrl,
  }) async {
    return pushSession(assistantId, {
      'state': 'active',
      'currentPreset': {
        'name': presetName,
        'type': presetType,
        'options': options,
        'currentRound': currentRound,
        'totalRounds': totalRounds,
        'inputMode': inputMode,
      },
      'chain': chain,
      'chainIndex': chainIndex,
      'redirectUrl': redirectUrl,
    });
  }

  /// Push free text mode
  static Future<bool> pushFreeTextMode(String assistantId) async {
    return pushSession(assistantId, {'state': 'free_text'});
  }

  /// Push a decoy session — the spectator's webapp (oass.app/{id}) renders
  /// the given [template] (Google Image Lightbox style) and captures inputs
  /// (taps or swipes) as configured by [inputType]. After [expectedInputs]
  /// gestures, the webapp redirects to [redirectUrl].
  ///
  /// Inputs are pushed into `sessions/{id}/input` as they happen, and the app
  /// reads them via the standard pollInput mechanism.
  ///
  /// `inputType`:
  ///   - 'tap'   — taps anywhere on the page (vertical zones for option pick)
  ///   - 'swipe' — directional swipes (clockMap two-step)
  ///
  /// `lockGesture` true → long-press sends a LOCK signal (used by Free Will
  /// tap mode where the volume button is unavailable on the spectator's phone).
  static const String defaultDecoyRedirectUrl = 'https://www.google.com';

  static Future<bool> pushDecoySession({
    required String assistantId,
    required DecoyTemplate template,
    required String inputType,
    required int expectedInputs,
    required String redirectUrl,
    int optionCount = 1,
    bool lockGesture = false,
    bool showIndicator = true,
  }) async {
    final effectiveRedirect = redirectUrl.trim().isEmpty
        ? defaultDecoyRedirectUrl
        : redirectUrl;
    return pushSession(assistantId, {
      'state': 'decoy',
      'decoy': {
        'template': template.toJson(),
        'inputType': inputType,
        'optionCount': optionCount,
        'expectedInputs': expectedInputs,
        'redirectUrl': effectiveRedirect,
        'lockGesture': lockGesture,
        'showIndicator': showIndicator,
      },
    });
  }

  /// Fetch all published preset templates from /templates/.
  /// Returns map: id -> {name, description, preset, createdAt, ...}
  static Future<Map<String, dynamic>> fetchTemplates() async {
    try {
      final url = '$_databaseUrl/templates.json';
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200 || response.body == 'null') return {};
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) return decoded;
      return {};
    } catch (_) {
      return {};
    }
  }

  /// Publish a template to /templates/{id}. Requires admin token to satisfy
  /// the database security rule (the rule validates `newData/adminToken` server-side).
  /// Returns true on success.
  static Future<bool> publishTemplate({
    required String id,
    required String name,
    required String description,
    required Map<String, dynamic> presetJson,
    required String adminToken,
  }) async {
    try {
      final url = '$_databaseUrl/templates/$id.json';
      final response = await http.put(
        Uri.parse(url),
        body: jsonEncode({
          'name': name,
          'description': description,
          'preset': presetJson,
          'createdAt': DateTime.now().millisecondsSinceEpoch,
          'adminToken': adminToken,
        }),
      ).timeout(const Duration(seconds: 8));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Delete a template (requires admin token in query — rule validates it).
  static Future<bool> deleteTemplate({
    required String id,
    required String adminToken,
  }) async {
    try {
      final url = '$_databaseUrl/templates/$id.json?adminToken=$adminToken';
      final response = await http.delete(Uri.parse(url)).timeout(const Duration(seconds: 8));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Fetch all admin-published decoy templates from `/decoy_templates/`.
  /// Returns map: id → template JSON.
  static Future<Map<String, dynamic>> fetchSharedDecoyTemplates() async {
    try {
      final url = '$_databaseUrl/decoy_templates.json';
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200 || response.body == 'null') return {};
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) return decoded;
      return {};
    } catch (_) {
      return {};
    }
  }

  /// Publish a decoy template under `/decoy_templates/{id}` so other users
  /// can browse and import it. Requires admin token (mirrors the existing
  /// `templates` rule).
  static Future<bool> publishDecoyTemplate({
    required DecoyTemplate template,
    required String adminToken,
  }) async {
    try {
      final url = '$_databaseUrl/decoy_templates/${template.id}.json';
      final response = await http.put(
        Uri.parse(url),
        body: jsonEncode({
          ...template.toJson(),
          'adminToken': adminToken,
          'publishedAt': DateTime.now().millisecondsSinceEpoch,
        }),
      ).timeout(const Duration(seconds: 8));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Delete a published decoy template (admin only).
  static Future<bool> deleteSharedDecoyTemplate({
    required String id,
    required String adminToken,
  }) async {
    try {
      final url = '$_databaseUrl/decoy_templates/$id.json?adminToken=$adminToken';
      final response = await http.delete(Uri.parse(url)).timeout(const Duration(seconds: 8));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Poll for input changes (returns a stream-like polling mechanism)
  static Stream<Map<String, dynamic>?> pollInput(String assistantId, {Duration interval = const Duration(seconds: 1)}) {
    final controller = StreamController<Map<String, dynamic>?>();
    int? lastTimestamp;

    Timer.periodic(interval, (timer) async {
      if (controller.isClosed) {
        timer.cancel();
        return;
      }

      final input = await readInput(assistantId);
      if (input != null) {
        final timestamp = input['timestamp'] as int?;
        if (timestamp != null && timestamp != lastTimestamp) {
          lastTimestamp = timestamp;
          controller.add(input);
        }
      }
    });

    controller.onCancel = () {
      controller.close();
    };

    return controller.stream;
  }
}
