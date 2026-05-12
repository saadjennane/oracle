import 'dart:io';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import '../../utils/reveal_provider.dart';
import '../theme/app_theme.dart';

/// Mini editor for calculator screenshot.
/// Pick background color, then paint over the "0" to erase it.
class CalculatorEditorScreen extends StatefulWidget {
  final String imagePath;

  const CalculatorEditorScreen({super.key, required this.imagePath});

  @override
  State<CalculatorEditorScreen> createState() => _CalculatorEditorScreenState();
}

class _CalculatorEditorScreenState extends State<CalculatorEditorScreen> {
  ui.Image? _image;
  ByteData? _imageBytes;
  int _imageWidth = 0;
  int _imageHeight = 0;

  Color _pickedColor = Colors.black;
  bool _isColorPicked = false;
  double _brushSize = 30;
  List<_BrushStroke> _strokes = [];
  List<Offset> _currentStroke = [];

  final GlobalKey _repaintKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    final file = File(widget.imagePath);
    final bytes = await file.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;

    // Get pixel data for color picking
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);

    setState(() {
      _image = image;
      _imageBytes = byteData;
      _imageWidth = image.width;
      _imageHeight = image.height;
    });
  }

  Color _getPixelColor(Offset localPosition, Size widgetSize) {
    if (_imageBytes == null) return Colors.black;

    // Map widget position to image position
    final scaleX = _imageWidth / widgetSize.width;
    final scaleY = _imageHeight / widgetSize.height;
    final imgX = (localPosition.dx * scaleX).clamp(0, _imageWidth - 1).toInt();
    final imgY = (localPosition.dy * scaleY).clamp(0, _imageHeight - 1).toInt();

    final offset = (imgY * _imageWidth + imgX) * 4;
    if (offset + 3 >= _imageBytes!.lengthInBytes) return Colors.black;

    final r = _imageBytes!.getUint8(offset);
    final g = _imageBytes!.getUint8(offset + 1);
    final b = _imageBytes!.getUint8(offset + 2);
    return Color.fromARGB(255, r, g, b);
  }

  Future<void> _saveAndExit() async {
    // Render the painted image
    final boundary = _repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return;

    final image = await boundary.toImage(pixelRatio: 2.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) return;

    // Save to same path (overwrite)
    final dir = await getApplicationDocumentsDirectory();
    final destPath = '${dir.path}/calculator_bg_edited.png';
    final file = File(destPath);
    await file.writeAsBytes(byteData.buffer.asUint8List());

    if (!mounted) return;

    // Update provider with edited path
    final revealProvider = context.read<RevealProvider>();
    await revealProvider.setCalculatorBackground(file);

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    if (_image == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: const Center(child: CircularProgressIndicator(color: AppTheme.primary)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        title: const Text('Edit Screenshot', style: TextStyle(fontSize: 16)),
        actions: [
          TextButton(
            onPressed: _saveAndExit,
            child: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: Column(
        children: [
          // Instructions
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: AppTheme.surface,
            child: Row(
              children: [
                // Color preview
                Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    color: _pickedColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white24, width: 2),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    !_isColorPicked
                        ? 'Step 1: Tap the background color near the "0"'
                        : 'Step 2: Paint over the "0" to erase it',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                  ),
                ),
                if (_isColorPicked) ...[
                  // Brush size slider
                  SizedBox(
                    width: 100,
                    child: Slider(
                      value: _brushSize,
                      min: 10,
                      max: 60,
                      activeColor: AppTheme.primary,
                      onChanged: (v) => setState(() => _brushSize = v),
                    ),
                  ),
                ],
                // Undo button
                if (_strokes.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.undo, size: 20, color: AppTheme.textSecondary),
                    onPressed: () => setState(() => _strokes.removeLast()),
                  ),
              ],
            ),
          ),

          // Image area
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return GestureDetector(
                  onTapDown: !_isColorPicked ? (d) {
                    // Step 1: Pick color
                    final color = _getPixelColor(d.localPosition, constraints.biggest);
                    setState(() {
                      _pickedColor = color;
                      _isColorPicked = true;
                    });
                  } : null,
                  onPanStart: _isColorPicked ? (d) {
                    _currentStroke = [d.localPosition];
                  } : null,
                  onPanUpdate: _isColorPicked ? (d) {
                    setState(() {
                      _currentStroke.add(d.localPosition);
                    });
                  } : null,
                  onPanEnd: _isColorPicked ? (d) {
                    setState(() {
                      _strokes.add(_BrushStroke(
                        points: List.from(_currentStroke),
                        color: _pickedColor,
                        size: _brushSize,
                      ));
                      _currentStroke = [];
                    });
                  } : null,
                  child: RepaintBoundary(
                    key: _repaintKey,
                    child: CustomPaint(
                      size: constraints.biggest,
                      painter: _EditorPainter(
                        image: _image!,
                        strokes: _strokes,
                        currentStroke: _currentStroke,
                        currentColor: _pickedColor,
                        currentBrushSize: _brushSize,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _BrushStroke {
  final List<Offset> points;
  final Color color;
  final double size;

  const _BrushStroke({
    required this.points,
    required this.color,
    required this.size,
  });
}

class _EditorPainter extends CustomPainter {
  final ui.Image image;
  final List<_BrushStroke> strokes;
  final List<Offset> currentStroke;
  final Color currentColor;
  final double currentBrushSize;

  _EditorPainter({
    required this.image,
    required this.strokes,
    required this.currentStroke,
    required this.currentColor,
    required this.currentBrushSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw image
    final src = Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
    final dst = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawImageRect(image, src, dst, Paint());

    // Draw committed strokes
    for (final stroke in strokes) {
      _drawStroke(canvas, stroke.points, stroke.color, stroke.size);
    }

    // Draw current stroke
    if (currentStroke.isNotEmpty) {
      _drawStroke(canvas, currentStroke, currentColor, currentBrushSize);
    }
  }

  void _drawStroke(Canvas canvas, List<Offset> points, Color color, double size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = size
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    if (points.length == 1) {
      canvas.drawCircle(points.first, size / 2, Paint()..color = color);
    } else {
      final path = Path();
      path.moveTo(points.first.dx, points.first.dy);
      for (int i = 1; i < points.length; i++) {
        path.lineTo(points[i].dx, points[i].dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _EditorPainter oldDelegate) => true;
}
