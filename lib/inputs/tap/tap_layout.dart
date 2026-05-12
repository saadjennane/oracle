import 'dart:ui';
import '../../models/models.dart';

/// Represents a single tap zone with its bounds and option index
class TapZone {
  final int optionIndex;
  final Rect rect;
  final bool isDisabled;

  const TapZone({
    required this.optionIndex,
    required this.rect,
    this.isDisabled = false,
  });

  bool containsPoint(Offset point) => rect.contains(point);
}

/// Computes tap zone layouts for different option counts
class TapLayoutCalculator {
  /// Compute tap zones for the given screen size and configuration
  static List<TapZone> computeZones({
    required Size screenSize,
    required int optionsCount,
    required TapLayout2 layout2,
    required TapLayout4 layout4,
  }) {
    switch (optionsCount) {
      case 2:
        return _compute2Zones(screenSize, layout2);
      case 3:
        return _compute3Zones(screenSize);
      case 4:
        return _compute4Zones(screenSize, layout4);
      case 5:
        return _compute5Zones(screenSize);
      case 6:
        return _compute6Zones(screenSize);
      default:
        return _compute2Zones(screenSize, layout2);
    }
  }

  /// 2 options: Left/Right or Top/Bottom halves
  static List<TapZone> _compute2Zones(Size size, TapLayout2 layout) {
    final w = size.width;
    final h = size.height;

    if (layout == TapLayout2.leftRight) {
      // Option 0 = left, option 1 = right
      return [
        TapZone(
          optionIndex: 0,
          rect: Rect.fromLTWH(0, 0, w / 2, h),
        ),
        TapZone(
          optionIndex: 1,
          rect: Rect.fromLTWH(w / 2, 0, w / 2, h),
        ),
      ];
    } else {
      // Top/Bottom: option 0 = top, option 1 = bottom
      return [
        TapZone(
          optionIndex: 0,
          rect: Rect.fromLTWH(0, 0, w, h / 2),
        ),
        TapZone(
          optionIndex: 1,
          rect: Rect.fromLTWH(0, h / 2, w, h / 2),
        ),
      ];
    }
  }

  /// 3 options: 3 horizontal bands (top/middle/bottom)
  static List<TapZone> _compute3Zones(Size size) {
    final w = size.width;
    final h = size.height;
    final bandHeight = h / 3;

    return [
      TapZone(
        optionIndex: 0,
        rect: Rect.fromLTWH(0, 0, w, bandHeight),
      ),
      TapZone(
        optionIndex: 1,
        rect: Rect.fromLTWH(0, bandHeight, w, bandHeight),
      ),
      TapZone(
        optionIndex: 2,
        rect: Rect.fromLTWH(0, bandHeight * 2, w, bandHeight),
      ),
    ];
  }

  /// 4 options: Quadrants (corners) or 4 horizontal stripes
  static List<TapZone> _compute4Zones(Size size, TapLayout4 layout) {
    final w = size.width;
    final h = size.height;

    if (layout == TapLayout4.corners) {
      final halfW = w / 2;
      final halfH = h / 2;
      return [
        // Top-left = option 1
        TapZone(
          optionIndex: 0,
          rect: Rect.fromLTWH(0, 0, halfW, halfH),
        ),
        // Top-right = option 2
        TapZone(
          optionIndex: 1,
          rect: Rect.fromLTWH(halfW, 0, halfW, halfH),
        ),
        // Bottom-left = option 3
        TapZone(
          optionIndex: 2,
          rect: Rect.fromLTWH(0, halfH, halfW, halfH),
        ),
        // Bottom-right = option 4
        TapZone(
          optionIndex: 3,
          rect: Rect.fromLTWH(halfW, halfH, halfW, halfH),
        ),
      ];
    } else {
      // 4 horizontal stripes
      final stripeHeight = h / 4;
      return [
        TapZone(
          optionIndex: 0,
          rect: Rect.fromLTWH(0, 0, w, stripeHeight),
        ),
        TapZone(
          optionIndex: 1,
          rect: Rect.fromLTWH(0, stripeHeight, w, stripeHeight),
        ),
        TapZone(
          optionIndex: 2,
          rect: Rect.fromLTWH(0, stripeHeight * 2, w, stripeHeight),
        ),
        TapZone(
          optionIndex: 3,
          rect: Rect.fromLTWH(0, stripeHeight * 3, w, stripeHeight),
        ),
      ];
    }
  }

  /// 5 options: 2x3 grid (6 cells, bottom-right disabled)
  static List<TapZone> _compute5Zones(Size size) {
    final w = size.width;
    final h = size.height;
    final cellW = w / 2;
    final cellH = h / 3;

    return [
      // Row 1: left=1, right=2
      TapZone(
        optionIndex: 0,
        rect: Rect.fromLTWH(0, 0, cellW, cellH),
      ),
      TapZone(
        optionIndex: 1,
        rect: Rect.fromLTWH(cellW, 0, cellW, cellH),
      ),
      // Row 2: left=3, right=4
      TapZone(
        optionIndex: 2,
        rect: Rect.fromLTWH(0, cellH, cellW, cellH),
      ),
      TapZone(
        optionIndex: 3,
        rect: Rect.fromLTWH(cellW, cellH, cellW, cellH),
      ),
      // Row 3: left=5, right=DISABLED
      TapZone(
        optionIndex: 4,
        rect: Rect.fromLTWH(0, cellH * 2, cellW, cellH),
      ),
      TapZone(
        optionIndex: 5,
        rect: Rect.fromLTWH(cellW, cellH * 2, cellW, cellH),
        isDisabled: true,
      ),
    ];
  }

  /// 6 options: 2x3 grid
  static List<TapZone> _compute6Zones(Size size) {
    final w = size.width;
    final h = size.height;
    final cellW = w / 2;
    final cellH = h / 3;

    return [
      // Row 1: left=1, right=2
      TapZone(
        optionIndex: 0,
        rect: Rect.fromLTWH(0, 0, cellW, cellH),
      ),
      TapZone(
        optionIndex: 1,
        rect: Rect.fromLTWH(cellW, 0, cellW, cellH),
      ),
      // Row 2: left=3, right=4
      TapZone(
        optionIndex: 2,
        rect: Rect.fromLTWH(0, cellH, cellW, cellH),
      ),
      TapZone(
        optionIndex: 3,
        rect: Rect.fromLTWH(cellW, cellH, cellW, cellH),
      ),
      // Row 3: left=5, right=6
      TapZone(
        optionIndex: 4,
        rect: Rect.fromLTWH(0, cellH * 2, cellW, cellH),
      ),
      TapZone(
        optionIndex: 5,
        rect: Rect.fromLTWH(cellW, cellH * 2, cellW, cellH),
      ),
    ];
  }

  /// Find which zone contains the given point
  static TapZone? findZoneAtPoint(List<TapZone> zones, Offset point) {
    for (final zone in zones) {
      if (zone.containsPoint(point)) {
        return zone;
      }
    }
    return null;
  }
}
