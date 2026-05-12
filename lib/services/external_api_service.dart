import 'dart:convert';
import 'package:http/http.dart' as http;

/// Result from Inject API
class InjectResult {
  final int count;
  final String value;

  InjectResult({required this.count, required this.value});

  factory InjectResult.fromJson(Map<String, dynamic> json) => InjectResult(
        count: json['count'] as int? ?? 0,
        value: json['value'] as String? ?? '',
      );
}

/// Result from Elips API
class ElipsResult {
  final int count;
  final String artist;
  final String song;
  final String outputWord;

  ElipsResult({
    required this.count,
    required this.artist,
    required this.song,
    required this.outputWord,
  });

  factory ElipsResult.fromJson(Map<String, dynamic> json) => ElipsResult(
        count: json['count'] as int? ?? 0,
        artist: json['artist'] as String? ?? '',
        song: json['song'] as String? ?? '',
        outputWord: json['outputWords'] as String? ?? '',
      );
}

/// Result from HighScore API
class HighScoreResult {
  final int lastUpdate;
  final int score;
  final int finalScore;
  final int leaderboardRank;

  HighScoreResult({
    required this.lastUpdate,
    required this.score,
    required this.finalScore,
    required this.leaderboardRank,
  });

  /// The relevant score (finalScore if > 0, otherwise score)
  int get effectiveScore => finalScore > 0 ? finalScore : score;

  factory HighScoreResult.fromJson(Map<String, dynamic> json) => HighScoreResult(
        lastUpdate: json['lastUpdate'] as int? ?? 0,
        score: json['score'] as int? ?? 0,
        finalScore: json['finalScore'] as int? ?? 0,
        leaderboardRank: json['leaderboardRank'] as int? ?? 0,
      );
}

/// Service for fetching data from external magic APIs
class ExternalApiService {
  static const Duration _timeout = Duration(seconds: 5);

  /// Fetch latest value from Inject API
  static Future<InjectResult?> fetchInject(String id) async {
    try {
      final url = 'https://11z.co/_w/$id/selection';
      final response = await http.get(Uri.parse(url)).timeout(_timeout);
      if (response.statusCode != 200) return null;
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return InjectResult.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  /// Fetch latest value from Elips API
  static Future<ElipsResult?> fetchElips(String id, String apiKey) async {
    try {
      final url = 'https://pag.gg/$id/api/$apiKey';
      final response = await http.get(Uri.parse(url)).timeout(_timeout);
      if (response.statusCode != 200) return null;
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return ElipsResult.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  /// Fetch latest value from HighScore API
  static Future<HighScoreResult?> fetchHighScore(String apiKey) async {
    try {
      final url = 'https://skyhopgame.com/api/session/state?apiKey=$apiKey';
      final response = await http.get(Uri.parse(url)).timeout(_timeout);
      if (response.statusCode != 200) return null;
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return HighScoreResult.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  /// Transform a value using OpenAI GPT-4o-mini with a custom prompt.
  /// The prompt can contain {value} which will be replaced with the input.
  /// For Elips, it can also contain {artist}, {song}, {outputWord}.
  /// Returns the transformed text, or null on failure.
  static Future<String?> transformWithPrompt({
    required String prompt,
    required String openaiApiKey,
    Map<String, String> variables = const {},
  }) async {
    if (openaiApiKey.isEmpty) return null;

    try {
      var resolvedPrompt = prompt;
      for (final entry in variables.entries) {
        resolvedPrompt = resolvedPrompt.replaceAll('{${entry.key}}', entry.value);
      }

      final response = await http.post(
        Uri.parse('https://api.openai.com/v1/chat/completions'),
        headers: {
          'Authorization': 'Bearer $openaiApiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'gpt-4o-mini',
          'messages': [
            {'role': 'system', 'content': 'You are a concise assistant. Reply with only the requested information, no explanations.'},
            {'role': 'user', 'content': resolvedPrompt},
          ],
          'max_tokens': 200,
          'temperature': 0.3,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return null;

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final choices = json['choices'] as List?;
      if (choices == null || choices.isEmpty) return null;

      final content = choices[0]['message']['content'] as String?;
      return content?.trim();
    } catch (_) {
      return null;
    }
  }
}
