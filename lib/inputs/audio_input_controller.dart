import 'dart:async';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import '../services/audio_ai_service.dart';

/// Internal helper for keyword matching.
class _KeywordMatch {
  final int position;
  final int optionIndex;
  final String keyword;
  _KeywordMatch({required this.position, required this.optionIndex, required this.keyword});
}

/// Detected choice from audio input.
class AudioDetection {
  final int optionIndex;
  final String matchedWord;
  final String context; // surrounding transcript text
  final DateTime timestamp;

  AudioDetection({
    required this.optionIndex,
    required this.matchedWord,
    required this.context,
  }) : timestamp = DateTime.now();
}

/// Callback types
typedef OnAudioChoiceDetected = void Function(int optionIndex, String matchedWord);
typedef OnTranscriptUpdate = void Function(String fullTranscript, String lastPhrase);
typedef OnStateChange = void Function(AudioInputState state);
typedef OnError = void Function(String error);

enum AudioInputState {
  idle,        // Not listening
  listening,   // Listening, waiting for start sentence
  active,      // Start sentence detected, actively detecting choices
  completed,   // Stop sentence detected or all rounds filled
  error,
}

/// Controller for audio-based input using speech recognition.
/// Listens for keywords matching option labels and deduces spectator choices.
class AudioInputController {
  final List<String> options;
  final int expectedRounds;
  final String startSentence;
  final String stopSentence;
  final String locale; // e.g. 'fr_FR'

  /// Optional keyword overrides per option index.
  /// If null, uses option labels directly.
  final Map<int, List<String>>? keywordOverrides;

  /// For duel preprogrammed: outcome keywords to deduce spectator choice
  final bool isDuel;
  final List<int>? performerSequence;

  /// For First-To mode: game ends when target score is reached
  final bool isFirstTo;
  final int targetScore;

  /// AI mode: use OpenAI to interpret transcript instead of keyword matching
  final bool useAI;
  final AudioAIService? aiService;

  // Callbacks
  OnAudioChoiceDetected? onChoiceDetected;
  OnTranscriptUpdate? onTranscriptUpdate;
  OnStateChange? onStateChange;
  OnError? onError;
  void Function(String reasoning, List<String> choices)? onAIAnalysis;

  // State
  AudioInputState _state = AudioInputState.idle;
  AudioInputState get state => _state;

  final SpeechToText _speech = SpeechToText();
  bool _isAvailable = false;

  String _fullTranscript = '';
  String get fullTranscript => _fullTranscript;

  /// Segments from each speech session (for dedup)
  final List<String> _segments = [];

  final List<AudioDetection> _detections = [];
  List<AudioDetection> get detections => List.unmodifiable(_detections);

  int _currentRound = 0;
  int get currentRound => _currentRound;

  /// Track the last processed transcript length to only process NEW text
  int _lastProcessedLength = 0;

  Timer? _restartTimer;

  // Duel outcome keywords (French)
  static const _spectatorWinKeywords = ['gagné', 'gagne', 'bravo', 'bien joué', 'tu as gagné', 'point pour toi'];
  static const _performerWinKeywords = ['perdu', 'raté', 'pas cette fois', 'j\'ai gagné', 'point pour moi'];
  static const _tieKeywords = ['égalité', 'match nul', 'pareil', 'même chose'];

  AudioInputController({
    required this.options,
    required this.expectedRounds,
    this.startSentence = '',
    this.stopSentence = '',
    this.locale = 'fr_FR',
    this.keywordOverrides,
    this.isDuel = false,
    this.performerSequence,
    this.isFirstTo = false,
    this.targetScore = 0,
    this.useAI = false,
    this.aiService,
    this.onChoiceDetected,
    this.onTranscriptUpdate,
    this.onStateChange,
    this.onError,
    this.onAIAnalysis,
  });

  /// Initialize speech recognition.
  Future<bool> initialize() async {
    _isAvailable = await _speech.initialize(
      onError: (error) {
        // Auto-restart only on timeout (silence), not on other errors
        if (error.errorMsg == 'error_speech_timeout' || error.errorMsg == 'error_no_match') {
          _scheduleRestart();
        } else {
          onError?.call(error.errorMsg);
        }
      },
      onStatus: (status) {
        if ((status == 'notListening' || status == 'done') && (_state == AudioInputState.active || _state == AudioInputState.listening)) {
          // Commit any pending partial text before restarting
          if (_lastProcessedText.isNotEmpty) {
            final newPart = _extractNewContent(_lastProcessedText);
            if (newPart.isNotEmpty) {
              _segments.add(newPart);
              _fullTranscript = _segments.join(' ');
            }
            _lastProcessedText = '';
          }
          _scheduleRestart();
        }
      },
    );
    return _isAvailable;
  }

  /// Start listening. If startSentence is empty, go directly to active mode.
  Future<void> startListening() async {
    if (!_isAvailable) {
      onError?.call('Speech recognition not available');
      return;
    }

    _fullTranscript = '';
    _segments.clear();
    _detections.clear();
    _currentRound = 0;
    _lastProcessedLength = 0;

    if (startSentence.trim().isEmpty) {
      _setState(AudioInputState.active);
    } else {
      _setState(AudioInputState.listening);
    }

    await _startRecognition();
  }

  /// Stop listening.
  void stopListening() {
    _restartTimer?.cancel();
    _speech.stop();
    _aiAnalyzing = false; // Reset in case a previous call is stuck
    _setState(AudioInputState.idle);
  }

  /// Force complete (manual stop).
  void forceComplete() {
    _restartTimer?.cancel();
    _speech.stop();
    _setState(AudioInputState.completed);
  }

  /// Manually trigger AI analysis. Pass the visible transcript from the UI
  /// in case _fullTranscript is incomplete (partials not committed).
  Future<void> manualAIAnalysis({String? visibleTranscript}) async {
    _aiAnalyzing = false; // Force reset any stuck state
    // Use visible transcript if our internal one is empty
    if (visibleTranscript != null && visibleTranscript.trim().isNotEmpty && _fullTranscript.trim().isEmpty) {
      _fullTranscript = visibleTranscript;
    }
    if (aiService != null && _fullTranscript.trim().isNotEmpty) {
      await _analyzeWithAI();
    } else {
      onError?.call('No transcript (${_fullTranscript.length} chars) or no AI service (${aiService != null})');
    }
  }

  Future<void> _startRecognition() async {
    await _speech.listen(
      onResult: _onSpeechResult,
      localeId: locale,
      listenMode: ListenMode.dictation,
      cancelOnError: false,
      partialResults: true,
    );
  }

  void _scheduleRestart() {
    _restartTimer?.cancel();
    _restartTimer = Timer(const Duration(milliseconds: 500), () async {
      if (_state == AudioInputState.active || _state == AudioInputState.listening) {
        await _startRecognition();
      }
    });
  }

  String _lastProcessedText = '';

  /// Extract only the NEW content from a segment that isn't already in transcript.
  String _extractNewContent(String text) {
    if (_fullTranscript.isEmpty) return text;

    // Find the longest overlap between end of existing transcript and start of new text
    final existing = _fullTranscript.toLowerCase();
    final newText = text.toLowerCase();

    // Try progressively shorter suffixes of existing text as prefixes of new text
    int bestOverlap = 0;
    final maxCheck = newText.length < existing.length ? newText.length : existing.length;
    for (int len = 10; len <= maxCheck; len++) {
      final suffix = existing.substring(existing.length - len);
      if (newText.startsWith(suffix)) {
        bestOverlap = len;
      }
    }

    if (bestOverlap > 10) {
      // New text overlaps with existing — only keep the new part
      return text.substring(bestOverlap).trim();
    }

    // Check if the entire new text is already contained in existing
    if (existing.contains(newText)) {
      return ''; // Complete duplicate
    }

    return text;
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    final text = result.recognizedWords.toLowerCase().trim();
    if (text.isEmpty) return;

    if (result.finalResult) {
      // Add as a new segment, extracting only the NEW part
      final newPart = _extractNewContent(text);
      if (newPart.isNotEmpty) {
        _segments.add(newPart);
        _fullTranscript = _segments.join(' ');
      }
      _lastProcessedText = '';
    } else {
      // Keep updating the last partial — always save the longest version
      if (text.length > _lastProcessedText.length || text != _lastProcessedText) {
        _lastProcessedText = text;
      }
    }

    // Show full transcript + current partial
    final display = result.finalResult ? _fullTranscript : '$_fullTranscript $text';
    onTranscriptUpdate?.call(display, text);

    final combined = _fullTranscript + text;

    // Check for stop sentence
    if (stopSentence.trim().isNotEmpty && _state == AudioInputState.active) {
      if (combined.contains(stopSentence.toLowerCase())) {
        forceComplete();
        return;
      }
    }

    // Check for start sentence
    if (_state == AudioInputState.listening && startSentence.trim().isNotEmpty) {
      if (combined.contains(startSentence.toLowerCase())) {
        _setState(AudioInputState.active);
        // Clear transcript after start to not re-detect
        _fullTranscript = '';
        return;
      }
    }

    // Detect choices (only in active state, on final results)
    if (_state == AudioInputState.active && result.finalResult) {
      if (!useAI) {
        // Keyword mode: process new text only
        final fullSoFar = _fullTranscript;
        if (fullSoFar.length > _lastProcessedLength) {
          final newText = fullSoFar.substring(_lastProcessedLength);
          _lastProcessedLength = fullSoFar.length;
          _processText(newText.trim());
        }
      }
      // AI mode: no auto-analysis, user triggers manually

      // Restart listening for next segment (after finalResult, no overlap)
      if (_currentRound < expectedRounds) {
        _scheduleRestart();
      }
    }
  }

  bool _aiAnalyzing = false;

  Future<void> _analyzeWithAI() async {
    if (_aiAnalyzing || aiService == null) return;
    _aiAnalyzing = true;

    onAIAnalysis?.call('Analyzing ${_fullTranscript.length} chars...', []);

    try {
      // Build performer labels for duel context
      List<String>? perfLabels;
      if (isDuel && performerSequence != null) {
        perfLabels = performerSequence!.map((i) => i < options.length ? options[i] : '?').toList();
      }

      final result = await aiService!.analyzeTranscript(
        transcript: _fullTranscript,
        options: options,
        expectedRounds: expectedRounds,
        alreadyDetected: 0,
        isDuel: isDuel,
        performerSequenceLabels: perfLabels,
        locale: locale.startsWith('fr') ? 'fr' : 'en',
      );

      if (result.choices.isEmpty && result.reasoning.isNotEmpty) {
        onError?.call('GPT: ${result.reasoning}');
      }

      onAIAnalysis?.call(result.reasoning, result.choices);

      // Replace all detections with AI result
      if (result.choices.isNotEmpty) {
        _detections.clear();
        _currentRound = 0;

        for (final choice in result.choices) {
          if (_currentRound >= expectedRounds) break;
          final idx = options.indexWhere((o) => o.toLowerCase() == choice.toLowerCase());
          if (idx >= 0) {
            _registerDetection(idx, 'AI:$choice', _fullTranscript);
          }
        }
      }
    } catch (e) {
      onError?.call('AI failed: $e');
    } finally {
      _aiAnalyzing = false;
    }
  }

  void _processText(String text) {
    // For First-To, don't use expectedRounds as hard limit (completion is score-based)
    if (!isFirstTo && _currentRound >= expectedRounds) return;
    if (_state == AudioInputState.completed) return;

    if (isDuel && performerSequence != null) {
      _processDuelText(text);
    } else {
      _processDirectText(text);
    }
  }

  /// Direct keyword matching: scan text for ALL keyword occurrences in order.
  void _processDirectText(String text) {
    // Build a list of all keyword matches with their position in the text
    final matches = <_KeywordMatch>[];

    for (int i = 0; i < options.length; i++) {
      final keywords = _getKeywordsForOption(i);
      for (final keyword in keywords) {
        int startFrom = 0;
        while (true) {
          final pos = text.indexOf(keyword.toLowerCase(), startFrom);
          if (pos == -1) break;
          matches.add(_KeywordMatch(position: pos, optionIndex: i, keyword: keyword));
          startFrom = pos + keyword.length;
        }
      }
    }

    // Sort by position in text (left to right = chronological order)
    matches.sort((a, b) => a.position.compareTo(b.position));

    // Remove overlapping matches (keep the first one at each position)
    final filtered = <_KeywordMatch>[];
    int lastEnd = -1;
    for (final m in matches) {
      if (m.position >= lastEnd) {
        filtered.add(m);
        lastEnd = m.position + m.keyword.length;
      }
    }

    // Register each match as a round
    for (final m in filtered) {
      if (_currentRound >= expectedRounds) break;
      _registerDetection(m.optionIndex, m.keyword, text);
    }
  }

  /// Duel mode: detect outcome keywords and deduce spectator choice.
  /// Scans all occurrences in order.
  void _processDuelText(String text) {
    if (performerSequence == null) return;

    // Build all keyword matches with positions
    final matches = <_KeywordMatch>[];

    // Direct option mentions
    for (int i = 0; i < options.length; i++) {
      final keywords = _getKeywordsForOption(i);
      for (final keyword in keywords) {
        int startFrom = 0;
        while (true) {
          final pos = text.indexOf(keyword.toLowerCase(), startFrom);
          if (pos == -1) break;
          matches.add(_KeywordMatch(position: pos, optionIndex: i, keyword: keyword));
          startFrom = pos + keyword.length;
        }
      }
    }

    // Outcome keywords — use special indices: -1 = spectator win, -2 = performer win, -3 = tie
    for (final kw in _spectatorWinKeywords) {
      int startFrom = 0;
      while (true) {
        final pos = text.indexOf(kw, startFrom);
        if (pos == -1) break;
        matches.add(_KeywordMatch(position: pos, optionIndex: -1, keyword: kw));
        startFrom = pos + kw.length;
      }
    }
    for (final kw in _performerWinKeywords) {
      int startFrom = 0;
      while (true) {
        final pos = text.indexOf(kw, startFrom);
        if (pos == -1) break;
        matches.add(_KeywordMatch(position: pos, optionIndex: -2, keyword: kw));
        startFrom = pos + kw.length;
      }
    }
    for (final kw in _tieKeywords) {
      int startFrom = 0;
      while (true) {
        final pos = text.indexOf(kw, startFrom);
        if (pos == -1) break;
        matches.add(_KeywordMatch(position: pos, optionIndex: -3, keyword: kw));
        startFrom = pos + kw.length;
      }
    }

    // Sort by position
    matches.sort((a, b) => a.position.compareTo(b.position));

    // Remove overlapping
    final filtered = <_KeywordMatch>[];
    int lastEnd = -1;
    for (final m in matches) {
      if (m.position >= lastEnd) {
        filtered.add(m);
        lastEnd = m.position + m.keyword.length;
      }
    }

    // Register each match
    for (final m in filtered) {
      if (_currentRound >= expectedRounds || _currentRound >= performerSequence!.length) break;

      if (m.optionIndex >= 0) {
        // Direct option mention
        _registerDetection(m.optionIndex, m.keyword, text);
      } else if (m.optionIndex == -1) {
        // Spectator won
        final spectatorChoice = _findWinningChoice(performerSequence![_currentRound]);
        if (spectatorChoice != null) {
          _registerDetection(spectatorChoice, 'gagné→${options[spectatorChoice]}', text);
        }
      } else if (m.optionIndex == -2) {
        // Performer won
        final spectatorChoice = _findLosingChoice(performerSequence![_currentRound]);
        if (spectatorChoice != null) {
          _registerDetection(spectatorChoice, 'perdu→${options[spectatorChoice]}', text);
        }
      } else if (m.optionIndex == -3) {
        // Tie
        final performerChoice = performerSequence![_currentRound];
        _registerDetection(performerChoice, 'égalité→${options[performerChoice]}', text);
      }
    }
  }

  /// Find the option index that beats the given performer choice (RPS rules).
  int? _findWinningChoice(int performerIdx) {
    // In RPS: index beats (index+2)%3, so spectator needs (performerIdx+1)%n to win
    final n = options.length;
    if (n == 2) return performerIdx == 0 ? 1 : 0; // simple: opposite wins
    // RPS: 0 beats 2, 1 beats 0, 2 beats 1 → to beat X, play (X+1)%3
    return (performerIdx + 1) % n;
  }

  /// Find the option index that loses to the given performer choice.
  int? _findLosingChoice(int performerIdx) {
    final n = options.length;
    if (n == 2) return performerIdx; // same as performer = performer wins in 2-option
    // RPS: 0 beats 2 → to lose to X, play (X+2)%3
    return (performerIdx + 2) % n;
  }

  List<String> _getKeywordsForOption(int index) {
    if (keywordOverrides != null && keywordOverrides!.containsKey(index)) {
      return keywordOverrides![index]!;
    }
    return [options[index].toLowerCase()];
  }

  void _registerDetection(int optionIndex, String matchedWord, String context) {
    final detection = AudioDetection(
      optionIndex: optionIndex,
      matchedWord: matchedWord,
      context: context,
    );
    _detections.add(detection);
    _currentRound++;

    onChoiceDetected?.call(optionIndex, matchedWord);

    // Check completion
    if (isFirstTo && isDuel && performerSequence != null) {
      // First-To: check if target score is reached
      int sWins = 0, pWins = 0;
      for (final d in _detections) {
        final round = _detections.indexOf(d);
        if (round < performerSequence!.length) {
          if (d.optionIndex == performerSequence![round]) {
            // Tie — neither scores
          } else {
            // Check who wins this round (RPS logic)
            final n = options.length;
            final spectatorIdx = d.optionIndex;
            final performerIdx = performerSequence![round];
            if (n == 2) {
              sWins++; // In 2-option, non-tie always means spectator chose differently = spectator wins
            } else {
              // RPS: (X+1)%3 beats X
              if (spectatorIdx == (performerIdx + 1) % n) {
                sWins++;
              } else {
                pWins++;
              }
            }
          }
        }
      }
      if (sWins >= targetScore || pWins >= targetScore) {
        forceComplete();
      }
    } else if (_currentRound >= expectedRounds) {
      forceComplete();
    }
  }

  bool _containsWord(String text, String word) {
    // Match whole word
    return RegExp('\\b$word\\b', caseSensitive: false).hasMatch(text);
  }

  void _setState(AudioInputState newState) {
    _state = newState;
    onStateChange?.call(newState);
  }

  void dispose() {
    _restartTimer?.cancel();
    _speech.stop();
    _speech.cancel();
  }

  /// Undo last detection.
  void undoLastDetection() {
    if (_detections.isNotEmpty) {
      _detections.removeLast();
      _currentRound = _detections.length;
      if (_state == AudioInputState.completed) {
        _setState(AudioInputState.active);
        _startRecognition();
      }
    }
  }

  /// Reset all detections.
  void resetDetections() {
    _detections.clear();
    _currentRound = 0;
    _fullTranscript = '';
    if (_state == AudioInputState.completed) {
      _setState(AudioInputState.active);
      _startRecognition();
    }
  }
}
