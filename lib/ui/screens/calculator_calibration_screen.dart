import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../utils/reveal_provider.dart';
import '../theme/app_theme.dart';

/// Calibration screen for calculator text overlay positioning.
/// Drag the sample number, adjust font size and weight.
class CalculatorCalibrationScreen extends StatefulWidget {
  const CalculatorCalibrationScreen({super.key});

  @override
  State<CalculatorCalibrationScreen> createState() => _CalculatorCalibrationScreenState();
}

class _CalculatorCalibrationScreenState extends State<CalculatorCalibrationScreen> {
  late double _offsetX;
  late double _offsetY;
  late double _fontSize;
  int _fontWeightIndex = 2; // 0=w100, 1=w200, 2=w300, 3=w400, 4=w500, 5=w600
  bool _alignRight = true;

  static const _fontWeights = [
    FontWeight.w100, FontWeight.w200, FontWeight.w300,
    FontWeight.w400, FontWeight.w500, FontWeight.w600,
  ];
  static const _fontWeightLabels = ['Thin', 'ExtraLight', 'Light', 'Regular', 'Medium', 'SemiBold'];

  static const _sampleText = '12345';

  @override
  void initState() {
    super.initState();
    final layout = context.read<RevealProvider>().calculatorLayout;
    _offsetX = layout.offsetX;
    _offsetY = layout.offsetY;
    _fontSize = layout.fontSize;
  }

  void _save() {
    final provider = context.read<RevealProvider>();
    provider.setCalculatorLayout(RevealTextLayout(
      offsetX: _offsetX,
      offsetY: _offsetY,
      fontSize: _fontSize,
      lineHeight: 1.0,
    ));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final revealProvider = context.watch<RevealProvider>();
    final bgPath = revealProvider.config.calculatorBackgroundPath;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        title: const Text('Calibrate Calculator', style: TextStyle(fontSize: 16)),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: Column(
        children: [
          // Preview area
          Expanded(
            child: Stack(
              children: [
                // Background image
                if (bgPath != null)
                  Positioned.fill(
                    child: Image.file(File(bgPath), fit: BoxFit.cover),
                  ),

                // Draggable text overlay
                Positioned(
                  top: _offsetY,
                  left: _alignRight ? null : _offsetX,
                  right: _alignRight ? _offsetX : null,
                  child: GestureDetector(
                    onPanUpdate: (d) {
                      setState(() {
                        if (_alignRight) {
                          _offsetX = (_offsetX - d.delta.dx).clamp(0, 200);
                        } else {
                          _offsetX = (_offsetX + d.delta.dx).clamp(0, 200);
                        }
                        _offsetY = (_offsetY + d.delta.dy).clamp(0, MediaQuery.of(context).size.height - 100);
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.5), width: 1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _sampleText,
                        style: TextStyle(
                          fontSize: _fontSize,
                          fontWeight: _fontWeights[_fontWeightIndex],
                          color: Colors.white,
                          fontFamily: '.SF UI Display',
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Controls
          Container(
            padding: const EdgeInsets.all(16),
            color: AppTheme.surface,
            child: Column(
              children: [
                // Font size
                Row(
                  children: [
                    Text('Size', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                    const SizedBox(width: 8),
                    Text('${_fontSize.round()}', style: TextStyle(color: AppTheme.textPrimary, fontSize: 12)),
                    Expanded(
                      child: Slider(
                        value: _fontSize,
                        min: 20,
                        max: 80,
                        activeColor: AppTheme.primary,
                        onChanged: (v) => setState(() => _fontSize = v),
                      ),
                    ),
                  ],
                ),

                // Font weight
                Row(
                  children: [
                    Text('Weight', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: List.generate(_fontWeightLabels.length, (i) {
                            final selected = _fontWeightIndex == i;
                            return Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: ChoiceChip(
                                label: Text(_fontWeightLabels[i], style: TextStyle(fontSize: 10)),
                                selected: selected,
                                selectedColor: AppTheme.primary,
                                backgroundColor: AppTheme.background,
                                labelStyle: TextStyle(color: selected ? Colors.white : AppTheme.textSecondary),
                                visualDensity: VisualDensity.compact,
                                onSelected: (_) => setState(() => _fontWeightIndex = i),
                              ),
                            );
                          }),
                        ),
                      ),
                    ),
                  ],
                ),

                // Alignment
                Row(
                  children: [
                    Text('Align', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                    const SizedBox(width: 12),
                    ChoiceChip(
                      label: const Text('Right', style: TextStyle(fontSize: 10)),
                      selected: _alignRight,
                      selectedColor: AppTheme.primary,
                      backgroundColor: AppTheme.background,
                      labelStyle: TextStyle(color: _alignRight ? Colors.white : AppTheme.textSecondary),
                      visualDensity: VisualDensity.compact,
                      onSelected: (_) => setState(() => _alignRight = true),
                    ),
                    const SizedBox(width: 6),
                    ChoiceChip(
                      label: const Text('Left', style: TextStyle(fontSize: 10)),
                      selected: !_alignRight,
                      selectedColor: AppTheme.primary,
                      backgroundColor: AppTheme.background,
                      labelStyle: TextStyle(color: !_alignRight ? Colors.white : AppTheme.textSecondary),
                      visualDensity: VisualDensity.compact,
                      onSelected: (_) => setState(() => _alignRight = false),
                    ),
                  ],
                ),

                const SizedBox(height: 8),
                Text(
                  'Drag the number to position it',
                  style: TextStyle(fontSize: 10, color: AppTheme.textTertiary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
