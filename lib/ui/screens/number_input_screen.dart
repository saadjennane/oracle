import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import '../../models/models.dart';
import '../../engine/number_engine.dart';
import '../../inputs/digit_swipe_controller.dart';
import '../../inputs/remote_key_listener.dart';
import '../../inputs/clock_swipe_input_controller.dart' show SwipeDirection;
import '../../utils/game_provider.dart';
import '../../utils/settings_provider.dart';
import '../theme/app_theme.dart';

class NumberInputScreen extends StatefulWidget {
  const NumberInputScreen({super.key});

  @override
  State<NumberInputScreen> createState() => _NumberInputScreenState();
}

class _NumberInputScreenState extends State<NumberInputScreen> {
  Preset? _preset;
  NumberMode _mode = NumberMode.rainman;
  bool _isInitialized = false;
  String _statusMessage = 'Initializing...';

  // Audio
  SpeechToText? _speech;
  bool _isListening = false;
  String _transcript = '';
  Timer? _speechRestartTimer;

  // Digit swipe
  DigitSwipeController? _digitSwipeController;

  // Rainman
  List<double> _collectedValues = [];
  int _expectedValues = 0;
  String _formula = '';
  List<int?> _operandDigitCounts = []; // null = free mode per operand

  // Birthday
  int? _birthDay;
  int? _birthMonth;
  int? _birthYear;
  int _birthdayStep = 0; // 0=day, 1=month, 2=century, 3=yearSuffix
  int _birthdayCentury = 19; // 19 or 20
  bool _waitingForCentury = false;

  // Today
  DateTime? _capturedTime;
  int? _spectatorNumber;

  // Result
  String? _result;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    WidgetsBinding.instance.addPostFrameCallback((_) => _initialize());
  }

  Future<void> _initialize() async {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is! Preset || args.numberMode == null) {
      Navigator.pop(context);
      return;
    }

    _preset = args;
    _mode = args.numberMode!;
    _formula = args.numberFormula ?? '_ + _';

    if (_mode == NumberMode.rainman) {
      _parseFormulaOperands();
      _statusMessage = 'Value 1/$_expectedValues';
    } else if (_mode == NumberMode.birthday) {
      _birthdayStep = 0;
      _statusMessage = 'Day?';
    } else if (_mode == NumberMode.today) {
      _capturedTime = DateTime.now().add(Duration(minutes: args.numberMinutesOffset));
      _statusMessage = 'Enter number';
    }

    // Init audio
    if (_preset!.stealthInputMethod == StealthInputMethod.audio) {
      _speech = SpeechToText();
      final available = await _speech!.initialize();
      if (available) {
        _startListening();
      } else {
        // Surface the failure so the performer knows to fall back to another
        // input method instead of staring at a silent black screen.
        if (mounted) {
          setState(() => _statusMessage = 'Audio unavailable — long-press to exit');
        }
      }
    }

    // Init digit swipe
    if (_preset!.stealthInputMethod == StealthInputMethod.clockSwipe) {
      final settings = context.read<SettingsProvider>();
      _digitSwipeController = DigitSwipeController(
        onDigitEntered: _onSwipeDigitEntered,
        onNumberConfirmed: _onSwipeNumberConfirmed,
        onInvalidInput: () {},
        hapticFeedback: settings.hapticFeedback,
      );
      // Set expected digits for first operand
      _setupSwipeForCurrentInput();
    }

    setState(() => _isInitialized = true);
  }

  /// Parse formula to extract operand digit counts
  /// "XX * X + XXX" → [2, 1, 3] (fixed)
  /// "_ * _ + _" → [null, null, null] (free)
  void _parseFormulaOperands() {
    final matches = RegExp(r'X+|_').allMatches(_formula);
    _operandDigitCounts = [];
    for (final m in matches) {
      final token = m.group(0)!;
      if (token == '_') {
        _operandDigitCounts.add(null); // free mode
      } else {
        _operandDigitCounts.add(token.length); // fixed: XX=2, XXX=3
      }
    }
    _expectedValues = _operandDigitCounts.length;
  }

  void _setupSwipeForCurrentInput() {
    if (_digitSwipeController == null) return;

    if (_mode == NumberMode.rainman) {
      final idx = _collectedValues.length;
      if (idx < _operandDigitCounts.length) {
        _digitSwipeController!.setExpectedDigits(_operandDigitCounts[idx]);
      }
    } else if (_mode == NumberMode.birthday) {
      if (_birthdayStep <= 1) {
        // Day=2 digits, Month=2 digits
        _digitSwipeController!.setExpectedDigits(2);
      } else if (_birthdayStep == 2) {
        // Century: waiting for single swipe ↑ or ↓ (not digit)
        _waitingForCentury = true;
        _digitSwipeController!.setExpectedDigits(null); // pause digit controller
      } else {
        // Year suffix: 2 digits
        _waitingForCentury = false;
        _digitSwipeController!.setExpectedDigits(2);
      }
    } else if (_mode == NumberMode.today) {
      // Free mode — confirm with gesture
      _digitSwipeController!.setExpectedDigits(null);
    }
  }

  void _onSwipeDigitEntered(int digit) {
    setState(() {
      _statusMessage = '$_statusMessage$digit';
    });
  }

  void _onSwipeNumberConfirmed(int number) {
    if (_mode == NumberMode.rainman) {
      _addCollectedValue(number.toDouble());
    } else if (_mode == NumberMode.birthday) {
      _addBirthdayValue(number);
    } else if (_mode == NumberMode.today) {
      _spectatorNumber = number;
      _calculateAndFinish();
    }
  }

  void _addBirthdayValue(int value) {
    if (_birthdayStep == 0) {
      _birthDay = value;
      _birthdayStep = 1;
      setState(() => _statusMessage = 'Month?');
    } else if (_birthdayStep == 1) {
      _birthMonth = value;
      _birthdayStep = 2;
      setState(() => _statusMessage = 'Year? (↑=19xx ↓=20xx)');
    } else if (_birthdayStep == 3) {
      // Year suffix after century
      _birthYear = _birthdayCentury * 100 + value;
      _calculateAndFinish();
      return;
    } else {
      return; // step 2 = century, handled by swipe interceptor
    }
    _digitSwipeController?.reset();
    _setupSwipeForCurrentInput();
  }

  void _startListening() {
    final locale = _preset?.audioLocale ?? 'fr_FR';
    _speech?.listen(
      onResult: _onSpeechResult,
      localeId: locale,
      listenMode: ListenMode.dictation,
      partialResults: true,
    );
    setState(() => _isListening = true);
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    final text = result.recognizedWords;
    setState(() => _transcript = text);

    if (_mode == NumberMode.rainman) {
      final numbers = NumberEngine.extractNumbers(text);
      if (numbers.length >= _expectedValues) {
        _collectedValues = numbers.take(_expectedValues).map((n) => n.toDouble()).toList();
        _calculateAndFinish();
      }
    } else if (_mode == NumberMode.birthday) {
      final date = NumberEngine.parseDateFromText(text);
      if (date != null) {
        _birthDay = date.day;
        _birthMonth = date.month;
        _birthYear = date.year;
        _calculateAndFinish();
      }
    } else if (_mode == NumberMode.today) {
      final numbers = NumberEngine.extractNumbers(text);
      if (numbers.isNotEmpty) {
        _spectatorNumber = numbers.last;
        _calculateAndFinish();
      }
    }

    // Restart listening if speech stops
    if (result.finalResult) {
      _speechRestartTimer?.cancel();
      _speechRestartTimer = Timer(const Duration(milliseconds: 500), () {
        if (_isListening && mounted && _result == null) {
          _startListening();
        }
      });
    }
  }

  void _addCollectedValue(double value) {
    _collectedValues.add(value);
    if (_collectedValues.length >= _expectedValues) {
      _calculateAndFinish();
    } else {
      setState(() {
        _statusMessage = 'Value ${_collectedValues.length + 1}/$_expectedValues';
      });
      _digitSwipeController?.reset();
      _setupSwipeForCurrentInput();
    }
  }

  void _calculateAndFinish() {
    // Guard against being called before all required inputs were captured —
    // e.g. an audio/swipe session that ended early. Without this, Birthday's
    // `_birthDay! / _birthMonth! / _birthYear!` would throw on null.
    if (_mode == NumberMode.birthday &&
        (_birthDay == null || _birthMonth == null || _birthYear == null)) {
      setState(() => _statusMessage = 'Date incomplète — long-press to exit');
      return;
    }
    if (_mode == NumberMode.today && _spectatorNumber == null) {
      setState(() => _statusMessage = 'Nombre manquant — long-press to exit');
      return;
    }
    if (_mode == NumberMode.rainman && _collectedValues.length < _expectedValues) {
      setState(() => _statusMessage = 'Valeurs incomplètes — long-press to exit');
      return;
    }

    _speech?.stop();
    setState(() => _isListening = false);

    // Always compute raw numeric/calculator result first (no prose).
    String rawNumeric;
    // Extra variables only set for Birthday mode.
    String? dayOfBirthName;
    int? nbDays;

    if (_mode == NumberMode.rainman) {
      final result = NumberEngine.calculateRainman(_formula, _collectedValues);
      if (result.isInfinite || result.isNaN) {
        // Make the failure mode explicit. NaN = malformed formula, Infinity =
        // division by zero. Visible in test mode via the status banner.
        rawNumeric = 'Error';
        if (mounted) {
          setState(() => _statusMessage =
              result.isNaN ? 'Formule invalide' : 'Division par zéro');
        }
      } else {
        rawNumeric = result == result.toInt() ? result.toInt().toString() : result.toStringAsFixed(2);
      }
    } else if (_mode == NumberMode.birthday) {
      final result = NumberEngine.calculateBirthday(_birthDay!, _birthMonth!, _birthYear!);
      final isFR = _preset?.language == Language.french;
      dayOfBirthName = isFR ? result.dayOfWeekFR : result.dayOfWeekEN;
      nbDays = result.daysSince;
      // Calculator-mode default for Birthday = just the number of days.
      rawNumeric = result.daysSince.toString();
    } else {
      // Today
      final complement = NumberEngine.calculateTodayComplement(
        spectatorNumber: _spectatorNumber!,
        includeTime: _preset?.numberIncludeTime ?? false,
        minutesOffset: _preset?.numberMinutesOffset ?? 0,
      );
      rawNumeric = complement.toString();
    }

    final outputMode = _preset?.numberOutputMode ?? 'notes';

    // Notes output: substitute variables in the custom template. With no
    // template defined, fall back to the raw numeric for ALL modes (the old
    // Birthday-only "day name + days" legacy fallback was removed for
    // consistency — define the template explicitly to get prose output).
    String resultText;
    if (outputMode == 'notes') {
      final template = _preset?.numberNotesTemplate ?? '';
      if (template.trim().isNotEmpty) {
        resultText = template
            .replaceAll('((Result))', rawNumeric)
            .replaceAll('((DayOfBirth))', dayOfBirthName ?? '')
            .replaceAll('((numDays))', nbDays?.toString() ?? '');
      } else {
        resultText = rawNumeric;
      }
    } else {
      // Calculator: always pure numeric, no text.
      resultText = rawNumeric;
    }

    setState(() => _result = resultText);

    final gameProvider = context.read<GameProvider>();
    gameProvider.setFreeTextNarrative(resultText);

    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      if (outputMode == 'calculator') {
        Navigator.pushReplacementNamed(context, '/calculator', arguments: resultText);
      } else {
        // Skip the preview screen — go straight to the fake note reveal.
        Navigator.pushReplacementNamed(context, '/reveal');
      }
    });
  }

  void _cancelAndExit() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    _speech?.stop();
    _speechRestartTimer?.cancel();
    _digitSwipeController?.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  /// Compact one-line status for test mode — current digits or birthday parts,
  /// with the result substituted as soon as it's available.
  String _testModeStatusLine() {
    if (_result != null) return '= $_result';
    if (_mode == NumberMode.birthday) {
      final d = _birthDay?.toString() ?? '_';
      final m = _birthMonth?.toString() ?? '_';
      final y = _birthYear?.toString() ??
          (_birthdayStep >= 2 && _birthdayCentury != null ? '${_birthdayCentury}__' : '_');
      return 'D $d  M $m  Y $y';
    }
    final digits = _digitSwipeController?.currentDigitsString ?? '';
    return digits.isEmpty ? '[ _ ]' : '[ $digits ]';
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

    return RemoteKeyListener(
      onSwipeKey: _preset?.stealthInputMethod == StealthInputMethod.clockSwipe
          ? (d) => _processSwipeDirection(d.name)
          : null,
      child: GestureDetector(
      onLongPress: _cancelAndExit,
      onPanEnd: _preset?.stealthInputMethod == StealthInputMethod.clockSwipe ? (d) {
        final dx = d.velocity.pixelsPerSecond.dx;
        final dy = d.velocity.pixelsPerSecond.dy;
        if (dx.abs() < 100 && dy.abs() < 100) return;
        String dir;
        if (dx.abs() > dy.abs()) {
          dir = dx > 0 ? 'right' : 'left';
        } else {
          dir = dy > 0 ? 'down' : 'up';
        }
        _processSwipeDirection(dir);
      } : null,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            Container(color: Colors.black),

            if (testMode)
              IgnorePointer(
                ignoring: true,
                child: SafeArea(
                  child: Column(
                    children: [
                      // Compact top status: current step / digits / result.
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                        child: Center(
                          child: Text(
                            _testModeStatusLine(),
                            style: TextStyle(
                              color: (_result != null ? Colors.green : Colors.white).withValues(alpha: 0.85),
                              fontSize: 18,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w500,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ),
                      // Centred digit-gesture map (only for swipe input).
                      if (_preset?.stealthInputMethod == StealthInputMethod.clockSwipe)
                        Expanded(
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                for (int d = 0; d < 10; d++)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        SizedBox(
                                          width: 36,
                                          child: Text(
                                            '$d',
                                            textAlign: TextAlign.right,
                                            style: TextStyle(
                                              color: Colors.white.withValues(alpha: 0.55),
                                              fontSize: 22,
                                              fontFamily: 'monospace',
                                              fontWeight: FontWeight.w400,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        Text(
                                          DigitSwipeController.gestureForDigit(d),
                                          style: TextStyle(
                                            color: Colors.white.withValues(alpha: 0.85),
                                            fontSize: 22,
                                            fontFamily: 'monospace',
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                const SizedBox(height: 8),
                                Padding(
                                  padding: const EdgeInsets.only(left: 4),
                                  child: Text(
                                    'confirm:  →←  /  ←→',
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.4),
                                      fontSize: 14,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
    );
  }

  /// Shared swipe-direction processor used by both touchscreen swipes and
  /// Bluetooth remote presses. Handles the birthday-century single-direction
  /// shortcut before forwarding to the standard digit swipe controller.
  void _processSwipeDirection(String dir) {
    if (_preset?.stealthInputMethod != StealthInputMethod.clockSwipe) return;
    if (_waitingForCentury && _mode == NumberMode.birthday) {
      final hapticOn = context.read<SettingsProvider>().hapticFeedback;
      if (dir == 'up') {
        _birthdayCentury = 19;
        _waitingForCentury = false;
        _birthdayStep = 3;
        setState(() => _statusMessage = 'Year? 19__');
        _digitSwipeController?.reset();
        _setupSwipeForCurrentInput();
        if (hapticOn) HapticFeedback.mediumImpact();
      } else if (dir == 'down') {
        _birthdayCentury = 20;
        _waitingForCentury = false;
        _birthdayStep = 3;
        setState(() => _statusMessage = 'Year? 20__');
        _digitSwipeController?.reset();
        _setupSwipeForCurrentInput();
        if (hapticOn) HapticFeedback.mediumImpact();
      }
      return;
    }
    _digitSwipeController?.handleSwipe(dir);
  }
}
