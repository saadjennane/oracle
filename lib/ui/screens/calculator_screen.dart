import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../utils/settings_provider.dart';
import '../../utils/reveal_provider.dart';
import '../theme/app_theme.dart';

/// Generic calculator screen with pre-filled result.
/// Supports screenshot overlay from settings.
class CalculatorScreen extends StatefulWidget {
  final String prefilledResult;

  const CalculatorScreen({super.key, required this.prefilledResult});

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  String _display = '0';
  String _currentInput = '';
  String _operator = '';
  double _firstOperand = 0;
  bool _showingResult = true;

  @override
  void initState() {
    super.initState();
    _display = widget.prefilledResult;
    _showingResult = true;
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  void _onDigit(String digit) {
    setState(() {
      if (_showingResult) {
        _display = digit;
        _currentInput = digit;
        _showingResult = false;
      } else {
        _currentInput += digit;
        _display = _currentInput;
      }
    });
  }

  void _onOperator(String op) {
    setState(() {
      _firstOperand = double.tryParse(_display) ?? 0;
      _operator = op;
      _currentInput = '';
      _showingResult = false;
    });
  }

  void _onEquals() {
    if (_operator.isEmpty || _currentInput.isEmpty) return;
    final second = double.tryParse(_currentInput) ?? 0;
    double result = 0;
    switch (_operator) {
      case '+': result = _firstOperand + second; break;
      case '-': result = _firstOperand - second; break;
      case '×': result = _firstOperand * second; break;
      case '÷': result = second != 0 ? _firstOperand / second : 0; break;
    }
    setState(() {
      _display = result == result.toInt() ? result.toInt().toString() : result.toStringAsFixed(2);
      _operator = '';
      _currentInput = '';
      _showingResult = true;
    });
  }

  void _onClear() {
    setState(() {
      _display = '0';
      _currentInput = '';
      _operator = '';
      _firstOperand = 0;
      _showingResult = false;
    });
  }

  void _onDot() {
    if (_currentInput.contains('.')) return;
    setState(() {
      if (_showingResult || _currentInput.isEmpty) {
        _currentInput = '0.';
        _showingResult = false;
      } else {
        _currentInput += '.';
      }
      _display = _currentInput;
    });
  }

  @override
  Widget build(BuildContext context) {
    final revealProvider = context.watch<RevealProvider>();
    final screenshotPath = revealProvider.config.calculatorBackgroundPath;
    final hasScreenshot = screenshotPath != null && screenshotPath.isNotEmpty && File(screenshotPath).existsSync();

    return GestureDetector(
      onLongPress: () => Navigator.of(context).popUntil((route) => route.isFirst),
      child: Scaffold(
        backgroundColor: const Color(0xFF1C1C1E),
        body: hasScreenshot
            ? _buildScreenshotMode(screenshotPath!)
            : _buildGenericMode(),
      ),
    );
  }

  Widget _buildScreenshotMode(String path) {
    final layout = context.read<RevealProvider>().calculatorLayout;
    return Stack(
      children: [
        // Screenshot background
        Positioned.fill(
          child: Image.file(File(path), fit: BoxFit.cover),
        ),
        // Result overlay (positioned from calibration)
        Positioned(
          top: layout.offsetY,
          right: layout.offsetX,
          child: Text(
            _display,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: layout.fontSize,
              fontWeight: FontWeight.w300,
              color: Colors.white,
              fontFamily: '.SF UI Display',
            ),
          ),
        ),
        // Invisible tap area for exit
        Positioned(
          top: 0, left: 0,
          child: GestureDetector(
            onLongPress: () => Navigator.of(context).popUntil((route) => route.isFirst),
            child: Container(width: 60, height: 60, color: Colors.transparent),
          ),
        ),
      ],
    );
  }

  Widget _buildGenericMode() {
    return SafeArea(
      child: Column(
        children: [
          // Display
          Expanded(
            flex: 2,
            child: Container(
              alignment: Alignment.bottomRight,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  _display,
                  style: const TextStyle(
                    fontSize: 72, fontWeight: FontWeight.w300,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
          // Buttons grid
          Expanded(
            flex: 5,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                children: [
                  _buildRow(['C', '±', '%', '÷']),
                  _buildRow(['7', '8', '9', '×']),
                  _buildRow(['4', '5', '6', '-']),
                  _buildRow(['1', '2', '3', '+']),
                  _buildRow(['0', '.', '=']),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(List<String> buttons) {
    return Expanded(
      child: Row(
        children: buttons.map((btn) {
          final isWide = btn == '0';
          final isOperator = btn == '÷' || btn == '×' || btn == '-' || btn == '+' || btn == '=';
          final isTopRow = btn == 'C' || btn == '±' || btn == '%';

          Color bgColor;
          Color textColor;
          if (isOperator) {
            bgColor = const Color(0xFFFF9F0A);
            textColor = Colors.white;
          } else if (isTopRow) {
            bgColor = const Color(0xFFA5A5A5);
            textColor = Colors.black;
          } else {
            bgColor = const Color(0xFF333333);
            textColor = Colors.white;
          }

          return Expanded(
            flex: isWide ? 2 : 1,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: MaterialButton(
                onPressed: () {
                  if (btn == 'C') _onClear();
                  else if (btn == '=') _onEquals();
                  else if (btn == '.') _onDot();
                  else if (btn == '±') setState(() {
                    if (_display.startsWith('-')) {
                      _display = _display.substring(1);
                    } else if (_display != '0') {
                      _display = '-$_display';
                    }
                    _currentInput = _display;
                  });
                  else if (btn == '%') setState(() {
                    final val = double.tryParse(_display) ?? 0;
                    _display = (val / 100).toString();
                    _currentInput = _display;
                    _showingResult = true;
                  });
                  else if (isOperator) _onOperator(btn);
                  else _onDigit(btn);
                },
                color: bgColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(40)),
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  btn,
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w400, color: textColor),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
