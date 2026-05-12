import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/stealth_input_method.dart';
import '../utils/settings_provider.dart';
import 'clock_swipe_input_controller.dart';

/// Translates Bluetooth remote keyboard events into volume or swipe callbacks.
/// Wrap any stealth input screen with this widget.
class RemoteKeyListener extends StatelessWidget {
  final Widget child;
  final void Function(VolumeDirection direction)? onVolumeKey;
  final void Function(SwipeDirection direction)? onSwipeKey;

  const RemoteKeyListener({
    super.key,
    required this.child,
    this.onVolumeKey,
    this.onSwipeKey,
  });

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    if (!settings.remoteEnabled) return child;

    return KeyboardListener(
      focusNode: FocusNode()..requestFocus(),
      autofocus: true,
      onKeyEvent: (event) {
        if (event is! KeyDownEvent) return;
        final keyLabel = event.logicalKey.keyLabel;

        if (keyLabel == settings.remoteKeyUp) {
          onVolumeKey?.call(VolumeDirection.up);
          onSwipeKey?.call(SwipeDirection.up);
        } else if (keyLabel == settings.remoteKeyDown) {
          onVolumeKey?.call(VolumeDirection.down);
          onSwipeKey?.call(SwipeDirection.down);
        } else if (keyLabel == settings.remoteKeyLeft) {
          onSwipeKey?.call(SwipeDirection.left);
        } else if (keyLabel == settings.remoteKeyRight) {
          onSwipeKey?.call(SwipeDirection.right);
        }
      },
      child: child,
    );
  }
}
