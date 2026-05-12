import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../utils/reveal_provider.dart';
import '../theme/app_theme.dart';

class RevealCalibrationScreen extends StatefulWidget {
  final bool isDarkMode;

  const RevealCalibrationScreen({super.key, required this.isDarkMode});

  @override
  State<RevealCalibrationScreen> createState() => _RevealCalibrationScreenState();
}

class _RevealCalibrationScreenState extends State<RevealCalibrationScreen> {
  // Calibration text (hardcoded as per spec)
  static const String _calibrationText = '''ORACLE CALIBRATION
Line 2 with longer words
LEFT / RIGHT / UP / DOWN
1234567890''';

  // Local state for live editing
  late double _offsetX;
  late double _offsetY;
  late double _fontSize;
  late double _lineHeight;
  late double _maxWidth;
  double _opacity = 0.6;

  // Track if user is dragging
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    // Load initial values from provider based on theme
    final revealProvider = context.read<RevealProvider>();
    final layout = widget.isDarkMode ? revealProvider.darkLayout : revealProvider.lightLayout;
    _offsetX = layout.offsetX;
    _offsetY = layout.offsetY;
    _fontSize = layout.fontSize;
    _lineHeight = layout.lineHeight;
    _maxWidth = layout.maxWidth;
  }

  void _copyCalibrationText() {
    Clipboard.setData(const ClipboardData(text: _calibrationText));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Calibration text copied'),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _saveAndClose() {
    final revealProvider = context.read<RevealProvider>();
    final layout = RevealTextLayout(
      offsetX: _offsetX,
      offsetY: _offsetY,
      fontSize: _fontSize,
      lineHeight: _lineHeight,
      maxWidth: _maxWidth,
    );
    if (widget.isDarkMode) {
      revealProvider.updateDarkLayout(layout);
    } else {
      revealProvider.updateLightLayout(layout);
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<RevealProvider>(
      builder: (context, revealProvider, child) {
        final backgroundPath = revealProvider.getBackgroundPath(isDarkMode: widget.isDarkMode);
        final screenWidth = MediaQuery.of(context).size.width;
        final effectiveMaxWidth = _maxWidth > 0 ? _maxWidth : screenWidth - 48;

        return Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              // Background image
              if (backgroundPath != null)
                Positioned.fill(
                  child: Image.file(
                    File(backgroundPath),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(color: Colors.grey[900]),
                  ),
                ),

              // Draggable calibration text
              Positioned(
                left: _offsetX,
                top: _offsetY,
                child: GestureDetector(
                  onPanStart: (_) => setState(() => _isDragging = true),
                  onPanUpdate: (details) {
                    setState(() {
                      _offsetX += details.delta.dx;
                      _offsetY += details.delta.dy;
                      // Clamp to screen bounds
                      _offsetX = _offsetX.clamp(0, screenWidth - 100);
                      _offsetY = _offsetY.clamp(0, MediaQuery.of(context).size.height - 200);
                    });
                  },
                  onPanEnd: (_) => setState(() => _isDragging = false),
                  child: Container(
                    constraints: BoxConstraints(maxWidth: effectiveMaxWidth),
                    decoration: _isDragging
                        ? BoxDecoration(
                            border: Border.all(color: AppTheme.accent, width: 2),
                            borderRadius: BorderRadius.circular(4),
                          )
                        : null,
                    padding: _isDragging ? const EdgeInsets.all(4) : EdgeInsets.zero,
                    child: Opacity(
                      opacity: _opacity,
                      child: Text(
                        _calibrationText,
                        style: TextStyle(
                          fontSize: _fontSize,
                          height: _lineHeight,
                          color: widget.isDarkMode ? Colors.white : Colors.black,
                          fontFamily: '.SF Pro Text', // iOS system font
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Top bar with back and save
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.6),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: _saveAndClose,
                          child: const Text(
                            'Save',
                            style: TextStyle(
                              color: AppTheme.accent,
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Bottom controls panel
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.85),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Copy text button
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _copyCalibrationText,
                                icon: const Icon(Icons.copy, size: 18),
                                label: const Text('Copy Calibration Text'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white70,
                                  side: const BorderSide(color: Colors.white30),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Sliders
                        _SliderRow(
                          label: 'Font Size',
                          value: _fontSize,
                          min: 12,
                          max: 24,
                          onChanged: (v) => setState(() => _fontSize = v),
                          displayValue: '${_fontSize.round()}',
                        ),
                        _SliderRow(
                          label: 'Line Height',
                          value: _lineHeight,
                          min: 1.0,
                          max: 2.0,
                          onChanged: (v) => setState(() => _lineHeight = v),
                          displayValue: _lineHeight.toStringAsFixed(2),
                        ),
                        _SliderRow(
                          label: 'Preview Opacity',
                          value: _opacity,
                          min: 0.3,
                          max: 1.0,
                          onChanged: (v) => setState(() => _opacity = v),
                          displayValue: '${(_opacity * 100).round()}%',
                        ),
                        _SliderRow(
                          label: 'Max Width',
                          value: _maxWidth,
                          min: 0,
                          max: screenWidth,
                          onChanged: (v) => setState(() => _maxWidth = v),
                          displayValue: _maxWidth > 0 ? '${_maxWidth.round()}' : 'Auto',
                        ),

                        const SizedBox(height: 8),

                        // Position info
                        Text(
                          'Position: (${_offsetX.round()}, ${_offsetY.round()})',
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SliderRow extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  final String displayValue;

  const _SliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    required this.displayValue,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: AppTheme.accent,
                inactiveTrackColor: Colors.white24,
                thumbColor: Colors.white,
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              ),
              child: Slider(
                value: value,
                min: min,
                max: max,
                onChanged: onChanged,
              ),
            ),
          ),
          SizedBox(
            width: 50,
            child: Text(
              displayValue,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 12,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
