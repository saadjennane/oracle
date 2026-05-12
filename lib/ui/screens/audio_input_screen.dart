import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../inputs/audio_input_controller.dart';
import '../../inputs/volume_button_listener.dart';
import '../../models/models.dart';
import '../../utils/game_provider.dart';
import '../../utils/settings_provider.dart';
import '../../utils/reveal_provider.dart';
import '../../utils/haptic_helper.dart';
import '../../services/audio_ai_service.dart';
import '../../app.dart';
import '../theme/app_theme.dart';
import '../widgets/chain_progress_indicator.dart';

class AudioInputScreen extends StatefulWidget {
  const AudioInputScreen({super.key});

  @override
  State<AudioInputScreen> createState() => _AudioInputScreenState();
}

class _AudioInputScreenState extends State<AudioInputScreen> {
  AudioInputController? _controller;
  String _transcript = '';
  String _lastPhrase = '';
  AudioInputState _audioState = AudioInputState.idle;
  final List<String> _log = [];
  bool _isInitialized = false;
  String? _initError;
  bool _useAI = false;
  String _aiReasoning = '';
  List<String> _aiChoices = [];

  // Start/Stop sentence
  final _startSentenceController = TextEditingController(text: '');
  final _stopSentenceController = TextEditingController(text: '');
  bool _showConfig = true;

  // Stealth mode
  bool _isStealthMode = false;
  VolumeButtonListener? _volumeListener;
  StreamSubscription<VolumeDirection>? _volumeSubscription;

  // Stealth stages: preScreen → listening → reveal
  String _stealthStage = 'listening'; // 'preScreen', 'listening', 'reveal'

  // Stealth pixel feedback: 0=none, 1=listening, 2=analyzing, 3=done
  int _stealthPhase = 0;
  bool _narrativeGenerated = false;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    final provider = context.read<GameProvider>();
    final settings = context.read<SettingsProvider>();
    final session = provider.currentSession;
    if (session == null) return;

    // Get preset from route arguments for audio config
    final preset = ModalRoute.of(context)?.settings.arguments as Preset?;

    final isDuel = session.isDuel;
    final options = session.options;
    final totalRounds = session.totalRounds;

    // Set start/stop from preset
    _startSentenceController.text = preset?.audioStartSentence ?? '';
    _stopSentenceController.text = preset?.audioStopSentence ?? '';

    // Get performer sequence from the game provider
    final performerSeq = provider.inputMode == InputMode.preprogrammed
        ? provider.preprogrammedSequence
        : null;

    // Check if AI mode is available
    final apiKey = settings.openaiApiKey;
    _useAI = apiKey.isNotEmpty;
    AudioAIService? aiService;
    if (_useAI) {
      aiService = AudioAIService(apiKey: apiKey);
    }

    _createController(
      options: options,
      totalRounds: totalRounds,
      isDuel: isDuel,
      performerSeq: performerSeq,
      locale: preset?.audioLocale ?? (session.language == Language.french ? 'fr_FR' : 'en_US'),
      apiKey: apiKey,
    );

    // Stealth mode = not in test mode
    _isStealthMode = !settings.testModeEnabled;

    final available = await _controller!.initialize();
    setState(() {
      _isInitialized = available;
      _initError = available ? null : 'Speech recognition not available';
    });

    // Setup volume listener for stealth mode
    if (_isStealthMode) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

      // Determine starting stage
      _stealthStage = settings.preScreenEnabled ? 'preScreen' : 'listening';

      _volumeListener = VolumeButtonListener();
      final volAvailable = await _volumeListener!.isAvailable();
      if (volAvailable) {
        await _volumeListener!.startListening();
        _volumeSubscription = _volumeListener!.onVolumeButtonPressed.listen((_) {
          _onVolumePress();
        });
      }
      // Auto-start listening only if no pre-screen
      if (available && _stealthStage == 'listening') {
        _controller?.startListening();
        setState(() => _stealthPhase = 1);
      }
    }

    if (available) {
      final lang = session.language == Language.french ? 'fr_FR' : 'en_US';
      _addLog('Ready. Locale: $lang. Mode: ${_useAI ? "AI" : "Keywords"}');
      _addLog('Options: ${options.join(", ")}');
    }
  }

  // Cached init params for recreating controller
  List<String> _options = [];
  int _totalRounds = 0;
  bool _isDuel = false;
  List<String>? _performerSeq;
  String _locale = 'fr_FR';
  String _apiKey = '';

  void _createController({
    required List<String> options,
    required int totalRounds,
    required bool isDuel,
    List<String>? performerSeq,
    required String locale,
    required String apiKey,
  }) {
    _options = options;
    _totalRounds = totalRounds;
    _isDuel = isDuel;
    _performerSeq = performerSeq;
    _locale = locale;
    _apiKey = apiKey;

    _useAI = apiKey.isNotEmpty;
    AudioAIService? aiService;
    if (_useAI) {
      aiService = AudioAIService(apiKey: apiKey);
    }

    // Get session for First-To context
    final gameProvider = context.read<GameProvider>();
    final currentSession = gameProvider.currentSession;
    final isFirstTo = currentSession?.duelMode == DuelMode.firstTo;
    final sessionTargetScore = currentSession?.targetScore ?? 3;

    _controller?.dispose();
    _controller = AudioInputController(
      options: options,
      expectedRounds: totalRounds,
      startSentence: _startSentenceController.text.trim(),
      stopSentence: _stopSentenceController.text.trim(),
      locale: locale,
      isDuel: isDuel,
      performerSequence: performerSeq != null
          ? performerSeq.map((label) => options.indexOf(label)).where((i) => i >= 0).toList()
          : null,
      isFirstTo: isFirstTo,
      targetScore: sessionTargetScore,
      useAI: _useAI,
      aiService: aiService,
      onChoiceDetected: _onChoiceDetected,
      onTranscriptUpdate: _onTranscriptUpdate,
      onStateChange: _onStateChange,
      onError: _onError,
      onAIAnalysis: _onAIAnalysis,
    );
  }

  /// Recreate controller with current start/stop sentences
  void _rebuildController() {
    _createController(
      options: _options,
      totalRounds: _totalRounds,
      isDuel: _isDuel,
      performerSeq: _performerSeq,
      locale: _locale,
      apiKey: _apiKey,
    );
  }

  void _onChoiceDetected(int optionIndex, String matchedWord) {
    final provider = context.read<GameProvider>();
    final settings = context.read<SettingsProvider>();
    final options = provider.options;
    final label = optionIndex < options.length ? options[optionIndex] : '?';

    setState(() {
      _addLog('✓ Round ${_controller!.currentRound}: $label (via "$matchedWord")');
    });

    // Haptic feedback
    if (settings.hapticFeedback) {
      HapticHelper.confirmOption(optionIndex, intensity: settings.hapticIntensity);
    }

    // Record the choice
    final isPreprogrammed = provider.inputMode == InputMode.preprogrammed;
    final isDirectMode = provider.predictionMode == PredictionMode.direct;

    if (isDirectMode || isPreprogrammed) {
      String? performerChoice;
      if (isPreprogrammed) {
        final roundIdx = provider.currentRound - 1;
        performerChoice = provider.currentSession?.getPerformerChoice(roundIdx);
      }
      provider.recordChoice(spectatorChoice: label, performerChoice: performerChoice);
    }
  }

  void _onTranscriptUpdate(String fullTranscript, String lastPhrase) {
    setState(() {
      _transcript = fullTranscript;
      _lastPhrase = lastPhrase;
    });
  }

  void _onStateChange(AudioInputState state) {
    setState(() {
      _audioState = state;
      switch (state) {
        case AudioInputState.idle:
          _addLog('— Stopped');
          break;
        case AudioInputState.listening:
          _addLog('— Listening for start sentence...');
          break;
        case AudioInputState.active:
          _addLog('— Active: detecting choices...');
          break;
        case AudioInputState.completed:
          _addLog('— Completed! All rounds detected.');
          break;
        case AudioInputState.error:
          break;
      }
    });

    if (state == AudioInputState.completed) {
      if (_isStealthMode) {
        // Stop sentence detected or all rounds done → auto-analyze
        _triggerStealthAnalysis();
      } else {
        _onComplete();
      }
    }
  }

  void _onAIAnalysis(String reasoning, List<String> choices) {
    setState(() {
      _aiReasoning = reasoning;
      _aiChoices = choices;
      _addLog('🤖 AI: ${choices.join(", ")} ($reasoning)');
    });

    // In stealth mode, auto-generate narrative after AI analysis
    if (_isStealthMode && !_narrativeGenerated) {
      _stealthGenerateNarrative();
    }
  }

  void _onError(String error) {
    setState(() {
      _addLog('⚠ Error: $error');
    });
  }

  void _onVolumePress() {
    if (!_isStealthMode) return;

    if (_stealthStage == 'preScreen') {
      // Transition from pre-screen to listening
      setState(() => _stealthStage = 'listening');
      _controller?.startListening();
      setState(() => _stealthPhase = 1);
    } else if (_stealthStage == 'listening') {
      if (_stealthPhase == 0 || _audioState == AudioInputState.listening) {
        _controller?.startListening();
        setState(() => _stealthPhase = 1);
      } else if (_stealthPhase == 1 && (_audioState == AudioInputState.active || _audioState == AudioInputState.completed)) {
        _triggerStealthAnalysis();
      }
    }
  }

  void _triggerStealthAnalysis() {
    _controller?.stopListening();
    setState(() => _stealthPhase = 2);

    if (_useAI && _transcript.isNotEmpty) {
      _controller?.manualAIAnalysis(visibleTranscript: _transcript);
    } else {
      // No AI — just generate with what we have
      _stealthGenerateNarrative();
    }
  }

  void _stealthGenerateNarrative() {
    final provider = context.read<GameProvider>();
    if (provider.generatedNarrative != null) {
      setState(() {
        _stealthPhase = 3;
        _narrativeGenerated = true;
        _stealthStage = 'reveal';
      });
    }
  }

  void _stopAndAnalyze() {
    _controller?.stopListening();
    setState(() {
      _addLog('— Stopped (tap)');
    });
    // Auto-trigger AI analysis if in AI mode
    if (_useAI && _transcript.isNotEmpty) {
      _addLog('🤖 Auto AI analysis...');
      setState(() {});
      _controller?.manualAIAnalysis(visibleTranscript: _transcript);
    }
  }

  void _onComplete() {
    // Don't auto-navigate — stay on screen and show results
    setState(() {
      _addLog('— Ready to generate narrative');
    });
  }

  void _addLog(String entry) {
    _log.insert(0, entry);
    if (_log.length > 50) _log.removeLast();
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    _controller?.dispose();
    _startSentenceController.dispose();
    _stopSentenceController.dispose();
    _volumeSubscription?.cancel();
    _volumeListener?.dispose();
    if (_isStealthMode) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<GameProvider>(
      builder: (context, provider, _) {
        final session = provider.currentSession;
        if (session == null) {
          return const Scaffold(body: Center(child: Text('No active session')));
        }

        // Stealth mode
        if (_isStealthMode) {
          if (_stealthStage == 'preScreen') {
            return _buildStealthPreScreen();
          } else if (_stealthStage == 'reveal') {
            return _buildStealthReveal(provider);
          }
          return _buildStealthScreen(provider);
        }

        return Scaffold(
          backgroundColor: AppTheme.background,
          appBar: AppBar(
            backgroundColor: AppTheme.surface,
            foregroundColor: AppTheme.textPrimary,
            title: const Text('Audio Input (Test)'),
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => _confirmExit(context, provider),
            ),
            actions: [
              // State indicator
              Container(
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _stateColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 8, height: 8, decoration: BoxDecoration(color: _stateColor, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Text(_stateLabel, style: TextStyle(fontSize: 12, color: _stateColor, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
          body: Column(
            children: [
              // Preset info bar
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                color: AppTheme.surface,
                child: Row(
                  children: [
                    Text('${session.gameType.name.toUpperCase()} • ${session.totalRounds} rounds',
                        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                    const Spacer(),
                    Text('Options: ${session.options.join(", ")}',
                        style: const TextStyle(fontSize: 12, color: AppTheme.accent)),
                  ],
                ),
              ),

              // Config panel (start/stop sentence)
              if (_showConfig) _buildConfigPanel(),

              // Progress indicator
              _buildProgressBar(provider),

              // Detections
              _buildDetections(),

              // AI Reasoning
              if (_aiReasoning.isNotEmpty) _buildAIReasoning(),

              // Live transcript — tap to stop when active
              Expanded(
                child: GestureDetector(
                  onTap: _audioState == AudioInputState.active ? _stopAndAnalyze : null,
                  child: _buildTranscript(),
                ),
              ),

              // Log
              _buildLog(),

              // Controls
              _buildControls(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStealthScreen(GameProvider provider) {
    final settings = context.watch<SettingsProvider>();
    final showPixel = settings.visualFeedbackEnabled;

    // Auto-detect when narrative is generated → transition to reveal
    if (!_narrativeGenerated && provider.generatedNarrative != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() { _stealthPhase = 3; _narrativeGenerated = true; _stealthStage = 'reveal'; });
      });
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onLongPress: () {
          // Exit stealth
          SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
          Navigator.pop(context);
        },
        child: Stack(
          children: [
            // Full black area
            Container(color: Colors.black),

            // Pixel feedback (top-right = listening, mid-right = analyzing, bottom-right = done)
            if (showPixel && _stealthPhase >= 1)
              Positioned(
                top: 60,
                right: 20,
                child: Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            if (showPixel && _stealthPhase >= 2)
              Positioned(
                top: MediaQuery.of(context).size.height / 2,
                right: 20,
                child: Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            if (showPixel && _stealthPhase >= 3)
              Positioned(
                bottom: 60,
                right: 20,
                child: Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            // Chain progress indicator
            Consumer<GameProvider>(
              builder: (_, gp, __) => gp.isChaining
                  ? ChainProgressIndicator(total: gp.chainTotal, currentIndex: gp.chainCurrentIndex)
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStealthPreScreen() {
    final settings = context.watch<SettingsProvider>();
    final revealProvider = context.watch<RevealProvider>();
    final brightness = MediaQuery.of(context).platformBrightness;
    final systemIsDark = brightness == Brightness.dark;

    // Determine which image to show
    String? imagePath;
    if (settings.preScreenType == 'homescreen') {
      imagePath = settings.homescreenPath;
    } else {
      // Notes list screenshot
      final config = revealProvider.config;
      imagePath = systemIsDark
          ? (config.hasDarkListBackground ? config.darkListBackgroundPath : config.lightListBackgroundPath)
          : (config.hasLightListBackground ? config.lightListBackgroundPath : config.darkListBackgroundPath);
      imagePath ??= systemIsDark
          ? (config.hasDarkBackground ? config.darkBackgroundPath : config.lightBackgroundPath)
          : (config.hasLightBackground ? config.lightBackgroundPath : config.darkBackgroundPath);
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onLongPress: () {
          SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
          Navigator.pop(context);
        },
        onTap: () {
          // Tap to transition to listening
          setState(() => _stealthStage = 'listening');
          _controller?.startListening();
          setState(() => _stealthPhase = 1);
        },
        child: Stack(
          children: [
            if (imagePath != null && File(imagePath).existsSync())
              Positioned.fill(
                child: Image.file(File(imagePath), fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(color: Colors.black)),
              )
            else
              Container(color: Colors.black),
          ],
        ),
      ),
    );
  }

  Widget _buildStealthReveal(GameProvider provider) {
    final settings = context.watch<SettingsProvider>();
    final revealProvider = context.watch<RevealProvider>();
    final brightness = MediaQuery.of(context).platformBrightness;
    final systemIsDark = brightness == Brightness.dark;
    final narrative = provider.generatedNarrative ?? '';

    final config = revealProvider.config;
    final isDark = settings.revealThemeMode == RevealThemeMode.dark ||
        (settings.revealThemeMode == RevealThemeMode.system && systemIsDark);

    final bgPath = isDark
        ? (config.hasDarkBackground ? config.darkBackgroundPath : config.lightBackgroundPath)
        : (config.hasLightBackground ? config.lightBackgroundPath : config.darkBackgroundPath);

    final layout = isDark ? config.darkLayout : config.lightLayout;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onLongPress: () {
          SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
          Navigator.pop(context);
        },
        child: Stack(
          children: [
            // Background
            if (bgPath != null && File(bgPath).existsSync())
              Positioned.fill(
                child: Image.file(File(bgPath), fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(color: Colors.black)),
              ),
            // Narrative text overlay
            Positioned(
              left: layout.offsetX,
              top: layout.offsetY,
              width: layout.maxWidth > 0 ? layout.maxWidth : MediaQuery.of(context).size.width - layout.offsetX * 2,
              child: Text(
                narrative,
                style: TextStyle(
                  fontSize: layout.fontSize,
                  height: layout.lineHeight,
                  color: isDark ? Colors.white : Colors.black,
                  fontFamily: '.SF UI Text',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfigPanel() {
    final isFR = context.watch<SettingsProvider>().appLanguage == Language.french;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.settings, size: 14, color: AppTheme.textSecondary),
              const SizedBox(width: 6),
              const Text('Configuration', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
              const Spacer(),
              GestureDetector(
                onTap: () => setState(() => _showConfig = false),
                child: const Icon(Icons.close, size: 16, color: AppTheme.textTertiary),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _startSentenceController,
            style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary),
            decoration: InputDecoration(
              labelText: 'Start sentence',
              labelStyle: const TextStyle(fontSize: 11, color: AppTheme.textTertiary),
              hintText: 'Ex: on va commencer',
              hintStyle: const TextStyle(fontSize: 11, color: AppTheme.textTertiary),
              isDense: true,
              filled: true,
              fillColor: AppTheme.background,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              prefixIcon: Icon(Icons.play_circle_outline, size: 16, color: _startSentenceController.text.isNotEmpty ? Colors.green : AppTheme.textTertiary),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _stopSentenceController,
            style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary),
            decoration: InputDecoration(
              labelText: 'Stop sentence',
              labelStyle: const TextStyle(fontSize: 11, color: AppTheme.textTertiary),
              hintText: 'Ex: merci',
              hintStyle: const TextStyle(fontSize: 11, color: AppTheme.textTertiary),
              isDense: true,
              filled: true,
              fillColor: AppTheme.background,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              prefixIcon: Icon(Icons.stop_circle_outlined, size: 16, color: _stopSentenceController.text.isNotEmpty ? Colors.red : AppTheme.textTertiary),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 6),
          Text(
            _startSentenceController.text.isEmpty
                ? (isFR ? 'Sans start sentence → écoute directe' : 'No start sentence → listens immediately')
                : (isFR
                    ? 'Écoute commence après "${_startSentenceController.text}"'
                    : 'Listens after "${_startSentenceController.text}"'),
            style: const TextStyle(fontSize: 10, color: AppTheme.textTertiary, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar(GameProvider provider) {
    final total = _controller?.expectedRounds ?? 0;
    final current = _controller?.currentRound ?? 0;

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Round $current / $total', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
              if (_audioState == AudioInputState.active)
                const Row(
                  children: [
                    SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.red)),
                    SizedBox(width: 6),
                    Text('Listening...', style: TextStyle(fontSize: 12, color: Colors.red)),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: total > 0 ? current / total : 0,
            backgroundColor: AppTheme.surface,
            valueColor: AlwaysStoppedAnimation<Color>(
                current == total ? Colors.green : AppTheme.accent),
            minHeight: 6,
            borderRadius: BorderRadius.circular(3),
          ),
        ],
      ),
    );
  }

  Widget _buildDetections() {
    final detections = _controller?.detections ?? [];
    if (detections.isEmpty) return const SizedBox.shrink();
    final provider = context.read<GameProvider>();
    final isFR = context.read<SettingsProvider>().appLanguage == Language.french;
    final options = provider.options;

    // Get performer sequence for hit/miss comparison
    final perfSeq = provider.preprogrammedSequence;
    final isPreprogrammed = provider.inputMode == InputMode.preprogrammed;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: detections.asMap().entries.map((entry) {
              final i = entry.key;
              final d = entry.value;
              final label = d.optionIndex < options.length ? options[d.optionIndex] : '?';

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.withOpacity(0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${i + 1}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green)),
                    const SizedBox(width: 4),
                    Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.green)),
                  ],
                ),
              );
            }).toList(),
          ),
          // Generate button when all rounds detected
          if (detections.length >= (_controller?.expectedRounds ?? 0)) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _showNarrativeModal(provider),
                icon: const Icon(Icons.auto_stories),
                label: Text(isFR ? 'Générer le texte' : 'Generate text'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAIReasoning() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.teal.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.teal.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.auto_fix_high, size: 14, color: Colors.teal),
          const SizedBox(width: 8),
          Expanded(
            child: Text(_aiReasoning,
                style: const TextStyle(fontSize: 11, color: Colors.teal, fontStyle: FontStyle.italic, height: 1.3)),
          ),
        ],
      ),
    );
  }

  void _showNarrativeModal(GameProvider provider) {
    final isFR = context.read<SettingsProvider>().appLanguage == Language.french;
    final narrative = provider.generatedNarrative ?? (isFR ? 'Aucun texte généré' : 'No text generated');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollController) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.grey.shade600, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.auto_stories, color: AppTheme.accent),
                  const SizedBox(width: 8),
                  Text(isFR ? 'Texte Généré' : 'Generated Text', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.copy, color: AppTheme.accent),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: narrative));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(isFR ? 'Texte copié' : 'Text copied'), duration: const Duration(seconds: 1)),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: Text(
                    narrative,
                    style: const TextStyle(fontSize: 16, color: AppTheme.textPrimary, height: 1.6),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    navigateAfterPresetComplete(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Continuer vers le reveal'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTranscript() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _audioState == AudioInputState.active ? Colors.red.withOpacity(0.5) : AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.mic, size: 16, color: _audioState == AudioInputState.active ? Colors.red : AppTheme.textTertiary),
              const SizedBox(width: 6),
              const Text('Transcript', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
              const Spacer(),
              if (_transcript.isNotEmpty)
                GestureDetector(
                  onTap: () {
                    final fullText = '$_transcript$_lastPhrase';
                    Clipboard.setData(ClipboardData(text: fullText));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Transcript copié'), duration: Duration(seconds: 1)),
                    );
                  },
                  child: const Icon(Icons.copy, size: 16, color: AppTheme.textTertiary),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: SingleChildScrollView(
              child: Text(
                _transcript.isEmpty ? 'Waiting for speech...' : '$_transcript$_lastPhrase',
                style: TextStyle(
                  fontSize: 14,
                  color: _transcript.isEmpty ? AppTheme.textTertiary : AppTheme.textPrimary,
                  height: 1.5,
                ),
              ),
            ),
          ),
          if (_audioState == AudioInputState.active && _stopSentenceController.text.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Center(
                child: Text(
                  'Tap ici pour arrêter et analyser',
                  style: TextStyle(fontSize: 11, color: Colors.red.withOpacity(0.6), fontStyle: FontStyle.italic),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLog() {
    return Container(
      height: 100,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Stack(
        children: [
          Positioned(
            top: 0, right: 0,
            child: GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: _log.reversed.join('\n')));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Log copié'), duration: Duration(seconds: 1)),
                );
              },
              child: const Icon(Icons.copy, size: 12, color: Colors.grey),
            ),
          ),
          ListView.builder(
        itemCount: _log.length,
        itemBuilder: (_, i) => Text(
          _log[i],
          style: TextStyle(
            fontSize: 10,
            fontFamily: 'monospace',
            color: _log[i].startsWith('✓') ? Colors.green
                : _log[i].startsWith('⚠') ? Colors.orange
                : _log[i].startsWith('🤖') ? Colors.teal
                : Colors.grey.shade400,
          ),
        ),
      ),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Start/Stop button
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _audioState == AudioInputState.idle || _audioState == AudioInputState.completed
                    ? () {
                        _rebuildController();
                        _controller?.initialize().then((_) {
                          _controller?.startListening();
                          setState(() {
                            _showConfig = false;
                            _transcript = '';
                            _aiReasoning = '';
                            _aiChoices = [];
                          });
                        });
                      }
                    : () => _controller?.stopListening(),
                icon: Icon(_audioState == AudioInputState.idle || _audioState == AudioInputState.completed
                    ? Icons.mic : Icons.stop),
                label: Text(_audioState == AudioInputState.idle || _audioState == AudioInputState.completed
                    ? 'Start' : 'Stop'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _audioState == AudioInputState.idle || _audioState == AudioInputState.completed
                      ? AppTheme.accent : Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // AI Analyze button
            if (_useAI)
              IconButton(
                onPressed: _controller != null && _transcript.isNotEmpty
                    ? () {
                        _addLog('🤖 Manual AI analysis...');
                        setState(() {});
                        _controller!.manualAIAnalysis(visibleTranscript: _transcript);
                      }
                    : null,
                icon: const Icon(Icons.auto_fix_high),
                color: Colors.teal,
                tooltip: 'Analyze with AI',
              ),
            // Undo
            IconButton(
              onPressed: _controller != null && (_controller!.detections.isNotEmpty)
                  ? () {
                      _controller!.undoLastDetection();
                      setState(() {
                        _addLog('↩ Undo last detection');
                      });
                    }
                  : null,
              icon: const Icon(Icons.undo),
              color: AppTheme.textSecondary,
            ),
            // Reset
            IconButton(
              onPressed: _controller != null && (_controller!.detections.isNotEmpty)
                  ? () {
                      _controller!.resetDetections();
                      setState(() {
                        _addLog('↺ Reset all detections');
                      });
                    }
                  : null,
              icon: const Icon(Icons.refresh),
              color: AppTheme.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  Color get _stateColor {
    switch (_audioState) {
      case AudioInputState.idle: return Colors.grey;
      case AudioInputState.listening: return Colors.orange;
      case AudioInputState.active: return Colors.red;
      case AudioInputState.completed: return Colors.green;
      case AudioInputState.error: return Colors.red;
    }
  }

  String get _stateLabel {
    switch (_audioState) {
      case AudioInputState.idle: return 'Idle';
      case AudioInputState.listening: return 'Waiting...';
      case AudioInputState.active: return 'Active';
      case AudioInputState.completed: return 'Done';
      case AudioInputState.error: return 'Error';
    }
  }

  void _confirmExit(BuildContext context, GameProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Exit?', style: TextStyle(color: AppTheme.textPrimary)),
        content: const Text('Progress will be lost.', style: TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              _controller?.stopListening();
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Exit'),
          ),
        ],
      ),
    );
  }
}
