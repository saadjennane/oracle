import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

/// Result from AI analysis of a transcript.
class AudioAIResult {
  final List<String> choices;
  final String reasoning;
  final bool isComplete;

  AudioAIResult({
    required this.choices,
    this.reasoning = '',
    this.isComplete = false,
  });
}

/// Service that calls OpenAI to interpret a game transcript.
class AudioAIService {
  final String apiKey;

  AudioAIService({required this.apiKey});

  /// Analyze a transcript and extract spectator choices.
  ///
  /// For Choices mode: extract the spectator's confirmed option for each round.
  /// For Duel preprogrammed: use performer sequence + outcomes to deduce spectator choices.
  Future<AudioAIResult> analyzeTranscript({
    required String transcript,
    required List<String> options,
    required int expectedRounds,
    required int alreadyDetected,
    required bool isDuel,
    List<String>? performerSequenceLabels,
    String locale = 'fr',
  }) async {
    final prompt = _buildPrompt(
      transcript: transcript,
      options: options,
      expectedRounds: expectedRounds,
      alreadyDetected: alreadyDetected,
      isDuel: isDuel,
      performerSequenceLabels: performerSequenceLabels,
      locale: locale,
    );

    try {
      final response = await http.post(
        Uri.parse('https://api.openai.com/v1/chat/completions'),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'gpt-4o',
          'messages': [
            {'role': 'system', 'content': _systemPrompt(locale)},
            {'role': 'user', 'content': prompt},
          ],
          'temperature': 0,
          'max_tokens': 500,
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        final body = response.body.length > 200 ? response.body.substring(0, 200) : response.body;
        return AudioAIResult(choices: [], reasoning: 'API ${response.statusCode}: $body');
      }

      final json = jsonDecode(response.body);
      final content = json['choices'][0]['message']['content'] as String;

      // Parse JSON from response (might be wrapped in markdown code block)
      String jsonStr = content.trim();
      if (jsonStr.startsWith('```')) {
        jsonStr = jsonStr.replaceAll(RegExp(r'^```\w*\n?'), '').replaceAll(RegExp(r'\n?```$'), '');
      }
      final parsed = jsonDecode(jsonStr);

      final choices = (parsed['choices'] as List?)?.map((e) => e.toString()).toList() ?? [];
      final reasoning = parsed['reasoning'] as String? ?? '';

      return AudioAIResult(
        choices: choices,
        reasoning: reasoning,
        isComplete: choices.length >= expectedRounds,
      );
    } catch (e) {
      return AudioAIResult(choices: [], reasoning: 'Error: $e');
    }
  }

  String _systemPrompt(String locale) {
    if (locale == 'fr') {
      return '''Tu es un assistant qui analyse des transcriptions audio d'un jeu de mentalisme.
Tu dois extraire les CHOIX CONFIRMÉS du spectateur à partir de la conversation du performer.

CONTEXTE IMPORTANT :
- C'est le PERFORMER qui parle (celui qui devine)
- Le performer annonce sa prédiction, puis révèle si c'était correct ou non
- Le RÉSULTAT RÉEL du spectateur est révélé APRÈS la prédiction du performer

Règles CRITIQUES pour identifier un choix CONFIRMÉ :
- Un choix est CONFIRMÉ quand le RÉSULTAT RÉEL est révélé (pas la prédiction du performer)
- "je pense qu'elle est dans la droite... ah non elle était dans la gauche" → le choix confirmé est GAUCHE (pas droite)
- "je dirais main gauche... parfait/excellent" → le choix confirmé est GAUCHE (le performer a eu raison)
- "elle était effectivement dans la droite" → choix confirmé DROITE
- "ah bon elle était dans la gauche" → choix confirmé GAUCHE
- "bravo tu m'as eu" après une prédiction = le performer s'est trompé

CE QUI N'EST PAS UN CHOIX :
- Les prédictions du performer ("je pense que", "je dirais que")
- Les questions ("gauche ou droite ?")
- Les explications du jeu
- Le texte d'introduction

POUR LE MODE DUEL :
- Le performer et le spectateur jouent en même temps chaque round
- La séquence du performer est connue et pré-programmée
- Déduis le choix du spectateur à partir du RÉSULTAT annoncé :
  - "égalité" / "pareil" → spectateur a joué le MÊME choix que le performer
  - "tu gagnes" / "1-0 pour toi" / "point pour toi" → spectateur a BATTU le performer
  - "je gagne" / "1-0 pour moi" / "point pour moi" → performer a BATTU le spectateur
  - Score ("2-1", "tu mènes") → calcule round par round depuis le score courant

TRANSCRIPT DUPLIQUÉ :
- La transcription peut contenir des RÉPÉTITIONS du même texte
- Si tu vois le même scénario se répéter, c'est un doublon, ne compte qu'UNE FOIS
- Cherche exactement le nombre de rounds demandé

Réponds UNIQUEMENT en JSON.''';
    }
    return '''You are an assistant analyzing audio transcripts from a mentalism game.
Extract CONFIRMED spectator choices from the conversation.

CRITICAL rules:
- A choice is CONFIRMED only when the performer validates the spectator's answer
- Ignore hesitations, questions, hypotheses
- "you chose right" = confirmed choice "right"
- "I was right" = performer guessed correctly, spectator played SAME as performer
- "you won" = spectator BEAT performer this round
- "I won" = performer BEAT spectator this round
- For duel with known performer sequence: deduce spectator choice from the outcome

Respond ONLY in JSON.''';
  }

  String _buildPrompt({
    required String transcript,
    required List<String> options,
    required int expectedRounds,
    required int alreadyDetected,
    required bool isDuel,
    List<String>? performerSequenceLabels,
    required String locale,
  }) {
    final buf = StringBuffer();

    buf.writeln('GAME CONTEXT:');
    buf.writeln('- Type: ${isDuel ? "DUEL (rock-paper-scissors style)" : "CHOICES (pick one option)"}');
    buf.writeln('- Options: ${options.join(", ")}');
    buf.writeln('- Total rounds: $expectedRounds');
    buf.writeln('- Already detected: $alreadyDetected');
    buf.writeln('- Remaining: ${expectedRounds - alreadyDetected}');

    if (isDuel && performerSequenceLabels != null) {
      buf.writeln('');
      buf.writeln('=== DUEL MODE (CRITICAL) ===');
      buf.writeln('The performer\'s choices are PRE-PROGRAMMED and KNOWN:');
      for (int i = 0; i < performerSequenceLabels.length; i++) {
        buf.writeln('  Round ${i + 1}: Performer plays ${performerSequenceLabels[i]}');
      }
      buf.writeln('');
      buf.writeln('YOUR TASK: Deduce the SPECTATOR\'s choice for each round from the outcome mentioned.');
      buf.writeln('');
      buf.writeln('RPS RULES:');
      if (options.length >= 3) {
        buf.writeln('  ${options[0]} beats ${options[2]}');
        buf.writeln('  ${options[2]} beats ${options[1]}');
        buf.writeln('  ${options[1]} beats ${options[0]}');
      }
      buf.writeln('');
      buf.writeln('OUTCOME KEYWORDS TO DETECT:');
      buf.writeln('  Spectator wins: "pour toi", "tu gagnes", "1-0", "bravo", "point pour toi"');
      buf.writeln('  Performer wins: "pour moi", "je gagne", "perdu", "point pour moi"');
      buf.writeln('  Tie: "égalité", "pareil", "match nul"');
      buf.writeln('');
      buf.writeln('HOW TO DEDUCE:');
      buf.writeln('  If spectator WINS round N → spectator played the option that BEATS performer\'s round N option');
      buf.writeln('  If performer WINS round N → spectator played the option that LOSES TO performer\'s round N option');
      buf.writeln('  If TIE round N → spectator played SAME as performer\'s round N option');
      buf.writeln('');
      buf.writeln('EXAMPLE: If performer sequence is [${options.length >= 3 ? "${options[2]}, ${options[0]}, ${options[2]}" : "A, B, A"}]');
      if (options.length >= 3) {
        buf.writeln('  "1-0 pour toi" at round 1 → spectator WON → needs to beat ${options[2]} → spectator played ${options[0]}');
        buf.writeln('  "je gagne" at round 2 → performer WON → spectator LOST to ${options[0]} → spectator played ${options[2]}');
        buf.writeln('  "je gagne" at round 3 → performer WON → spectator LOST to ${options[2]} → spectator played ${options[1]}');
        buf.writeln('  → choices: ["${options[0]}", "${options[2]}", "${options[1]}"]');
      }
      buf.writeln('');
      buf.writeln('Process rounds IN ORDER. Return the spectator\'s deduced choice for each round.');
    }

    buf.writeln('');
    buf.writeln('TRANSCRIPT:');
    buf.writeln('"""');
    buf.writeln(transcript);
    buf.writeln('"""');
    buf.writeln('');
    buf.writeln('Extract ALL confirmed spectator choices in chronological order.');
    buf.writeln('Return JSON: {"choices": ["option1", "option2", ...], "reasoning": "brief explanation"}');
    buf.writeln('Each choice MUST be one of: ${options.join(", ")}');
    buf.writeln('Return ONLY confirmed choices, not guesses. If unsure, return fewer choices.');

    return buf.toString();
  }
}
