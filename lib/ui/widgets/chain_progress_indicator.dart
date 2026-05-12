import 'package:flutter/material.dart';

/// Subtle chain progress indicator for stealth screens.
/// Shows small white pixels: bright = current, dim = done, hidden = not done.
class ChainProgressIndicator extends StatelessWidget {
  final int total;
  final int currentIndex;

  const ChainProgressIndicator({
    super.key,
    required this.total,
    required this.currentIndex,
  });

  @override
  Widget build(BuildContext context) {
    if (total <= 1) return const SizedBox.shrink();

    return Positioned(
      bottom: 20,
      right: 20,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(total, (i) {
          if (i > currentIndex) {
            // Not yet done — invisible
            return const SizedBox(width: 10);
          }

          final isCurrent = i == currentIndex;
          return Padding(
            padding: const EdgeInsets.only(left: 6),
            child: Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(isCurrent ? 0.20 : 0.08),
                shape: BoxShape.circle,
              ),
            ),
          );
        }),
      ),
    );
  }
}
