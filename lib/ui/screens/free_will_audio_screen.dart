import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:http/http.dart' as http;
import '../../models/models.dart';
import '../../inputs/volume_button_listener.dart';
import '../../utils/settings_provider.dart';
import '../../utils/game_provider.dart';
import '../../app.dart';
import '../theme/app_theme.dart';

/// Free Will audio input screen.
/// Listens to conversation, sends transcript to GPT to deduce assignments.
class FreeWillAudioScreen extends StatefulWidget {
  final Preset preset;

  const FreeWillAudioScreen({super.key, required this.preset});

  @override
  State<FreeWillAudioScreen> createState() => _FreeWillAudioScreenState();
}

class _FreeWillAudioScreenState extends State<FreeWillAudioScreen> {
  final SpeechToText _speech = SpeechToText();
  final VolumeButtonListener _volumeListener = VolumeButtonListener();
  StreamSubscription<VolumeDirection>? _volumeSubscription;

  String _transcript = '';
  bool _isListening = false;
  bool _isAnalyzing = false;
  bool _isInitialized = false;
  String? _error;
  String? _statusMessage;
  Timer? _restartTimer;

  FreeWillConfig get _config => widget.preset.freeWillConfig!;
  String get _locale => widget.preset.audioLocale;
  String? get _startSentence => widget.preset.audioStartSentence?.toLowerCase();
  String? get _stopSentence => widget.preset.audioStopSentence?.toLowerCase();

  bool _started = false; // true after start sentence detected (or if no start sentence)

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _initialize();
  }

  Future<void> _initialize() async {
    final available = await _speech.initialize();
    if (!available) {
      setState(() => _error = 'Speech recognition not available');
      return;
    }

    // Start volume listener for trigger
    await _volumeListener.startListening();
    _volumeSubscription = _volumeListener.onVolumeButtonPressed.listen(_handleVolumePress);

    setState(() {
      _isInitialized = true;
      _started = _startSentence == null || _startSentence!.isEmpty;
    });

    // Auto-start listening
    _startListening();
  }

  void _handleVolumePress(VolumeDirection direction) {
    if (_isAnalyzing) return;

    if (!_started) {
      // Volume UP = start
      if (direction == VolumeDirection.up) {
        setState(() => _started = true);
        _statusMessage = 'Listening...';
      }
    } else {
      // Volume DOWN = analyze now
      if (direction == VolumeDirection.down) {
        _analyzeTranscript();
      }
    }
  }

  Future<void> _startListening() async {
    if (_isListening) return;
    _isListening = true;

    await _speech.listen(
      onResult: _onSpeechResult,
      localeId: _locale,
      listenMode: ListenMode.dictation,
      cancelOnError: false,
      partialResults: true,
    );
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    final text = result.recognizedWords;
    setState(() => _transcript = text);

    // Check for start sentence
    if (!_started && _startSentence != null && _startSentence!.isNotEmpty) {
      if (text.toLowerCase().contains(_startSentence!)) {
        setState(() => _started = true);
      }
    }

    // Check for stop sentence → auto-analyze
    if (_started && _stopSentence != null && _stopSentence!.isNotEmpty) {
      if (text.toLowerCase().contains(_stopSentence!)) {
        _analyzeTranscript();
        return;
      }
    }

    // Speech recognition stops periodically — restart it
    if (result.finalResult) {
      _scheduleRestart();
    }
  }

  void _scheduleRestart() {
    _restartTimer?.cancel();
    _restartTimer = Timer(const Duration(milliseconds: 500), () async {
      if (_isListening && !_isAnalyzing && mounted) {
        await _startListening();
      }
    });
  }

  Future<void> _analyzeTranscript() async {
    if (_transcript.trim().isEmpty || _isAnalyzing) return;

    final settings = context.read<SettingsProvider>();
    final apiKey = settings.openaiApiKey;
    if (apiKey.isEmpty) {
      setState(() => _error = 'OpenAI API Key required (Settings)');
      return;
    }

    setState(() {
      _isAnalyzing = true;
      _statusMessage = 'Analyzing...';
    });

    // Stop listening
    await _speech.stop();
    _isListening = false;

    final objects = _config.objects;
    final isFR = _locale.startsWith('fr');

    final prompt = isFR
        ? '''Objets: ${objects.join(', ')}
Actions possibles: prendre (spectateur garde), donner (spectateur donne au performer), laisser sur la table

À partir de cette conversation, détermine quel objet a été assigné à quelle action:
"$_transcript"

Réponds UNIQUEMENT en JSON valide: {"take": "nom_objet", "give": "nom_objet", "table": "nom_objet"}'''
        : '''Objects: ${objects.join(', ')}
Possible actions: take (spectator keeps), give (spectator gives to performer), leave on table

From this conversation, determine which object was assigned to which action:
"$_transcript"

Reply ONLY with valid JSON: {"take": "object_name", "give": "object_name", "table": "object_name"}''';

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
            {'role': 'system', 'content': 'You are a JSON-only assistant. Reply with only valid JSON, no markdown, no explanation.'},
            {'role': 'user', 'content': prompt},
          ],
          'max_tokens': 100,
          'temperature': 0.1,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        setState(() {
          _isAnalyzing = false;
          _error = 'API error: ${response.statusCode}';
        });
        return;
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final content = json['choices'][0]['message']['content'] as String;

      // Parse JSON response — strip markdown if present
      var cleanContent = content.trim();
      if (cleanContent.startsWith('```')) {
        cleanContent = cleanContent.replaceAll(RegExp(r'```\w*\n?'), '').trim();
      }

      final result = jsonDecode(cleanContent) as Map<String, dynamic>;
      final takeObj = result['take'] as String?;
      final giveObj = result['give'] as String?;
      final tableObj = result['table'] as String?;

      if (takeObj == null || giveObj == null || tableObj == null) {
        setState(() {
          _isAnalyzing = false;
          _error = 'AI could not determine all assignments';
        });
        _retry();
        return;
      }

      // Validate objects match
      final resultObjects = {takeObj.toLowerCase(), giveObj.toLowerCase(), tableObj.toLowerCase()};
      final configObjects = objects.map((o) => o.toLowerCase()).toSet();
      if (!resultObjects.containsAll(configObjects)) {
        setState(() {
          _isAnalyzing = false;
          _error = 'AI returned unknown objects';
        });
        _retry();
        return;
      }

      // Find matching object names (case-insensitive)
      String matchObj(String aiName) => objects.firstWhere(
        (o) => o.toLowerCase() == aiName.toLowerCase(),
        orElse: () => aiName,
      );

      final freeWillResult = FreeWillResult(
        takeObject: matchObj(takeObj),
        giveObject: matchObj(giveObj),
        tableObject: matchObj(tableObj),
        swapCount: 0,
      );

      if (!mounted) return;
      final gameProvider = context.read<GameProvider>();
      gameProvider.completeFreeWill(freeWillResult, widget.preset);
      navigateAfterPresetComplete(context);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isAnalyzing = false;
        _error = 'Analysis failed: $e';
      });
      _retry();
    }
  }

  void _retry() {
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() {
        _error = null;
        _statusMessage = null;
      });
      _startListening();
    });
  }

  void _confirmExit() {
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _speech.stop();
    _restartTimer?.cancel();
    _volumeSubscription?.cancel();
    _volumeListener.dispose();
    WakelockPlus.disable();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final testMode = settings.testModeEnabled;

    if (!_isInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white24)),
      );
    }

    if (_error != null && !testMode) {
      // In stealth mode, just show black screen on error
      return Scaffold(
        backgroundColor: Colors.black,
        body: GestureDetector(
          onLongPress: _confirmExit,
          child: Container(color: Colors.black),
        ),
      );
    }

    // Stealth mode: black screen, no visual feedback
    if (!testMode) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: GestureDetector(
          onLongPress: _confirmExit,
          child: Stack(
            children: [
              Container(color: Colors.black),
              // Tiny indicator
              if (_isAnalyzing)
                Center(
                  child: Container(
                    width: 4, height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    // Test mode: show transcript and controls
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54),
                    onPressed: _confirmExit,
                  ),
                  const Spacer(),
                  Text(
                    'FREE WILL AUDIO',
                    style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  // Listening indicator
                  Container(
                    width: 10, height: 10,
                    decoration: BoxDecoration(
                      color: _isListening ? Colors.green : Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Objects
              Text('Objects: ${_config.objects.join(', ')}',
                  style: TextStyle(color: Colors.white38, fontSize: 12)),
              const SizedBox(height: 8),

              // Status
              if (!_started)
                Text(
                  _startSentence != null ? 'Waiting for: "$_startSentence"' : 'Waiting...',
                  style: TextStyle(color: Colors.orange, fontSize: 13),
                ),
              if (_started && !_isAnalyzing)
                Text('Listening... (Volume DOWN or stop sentence to analyze)',
                    style: TextStyle(color: Colors.green, fontSize: 13)),
              if (_isAnalyzing)
                Text('Analyzing with AI...',
                    style: TextStyle(color: AppTheme.primary, fontSize: 13)),

              const SizedBox(height: 16),

              // Transcript
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      _transcript.isEmpty ? '...' : _transcript,
                      style: TextStyle(
                        color: _started ? Colors.white70 : Colors.white24,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                  ),
                ),
              ),

              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: TextStyle(color: Colors.red, fontSize: 12)),
              ],

              const SizedBox(height: 16),

              // Manual analyze button (test mode)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isAnalyzing || _transcript.isEmpty ? null : _analyzeTranscript,
                  icon: Icon(Icons.psychology, size: 18),
                  label: Text('Analyze with AI'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
