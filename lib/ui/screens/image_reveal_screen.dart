import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/gallery_service.dart';
import '../../services/bank_image_store.dart';
import '../theme/app_theme.dart';

/// Full-screen image reveal. Saves to gallery automatically.
class ImageRevealScreen extends StatefulWidget {
  final String imagePath;
  final String? narrativeText;
  final String afterSave; // 'black' or 'photos'

  const ImageRevealScreen({
    super.key,
    required this.imagePath,
    this.narrativeText,
    this.afterSave = 'black',
  });

  @override
  State<ImageRevealScreen> createState() => _ImageRevealScreenState();
}

class _ImageRevealScreenState extends State<ImageRevealScreen> {
  bool _saved = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _saveAndHandle();
  }

  Future<void> _saveAndHandle() async {
    setState(() => _saving = true);
    // If the local file is missing, try resolving from iCloud container first.
    var path = widget.imagePath;
    if (!File(path).existsSync()) {
      final resolved = await BankImageStore.resolveForRead(path);
      if (resolved != null) path = resolved;
    }
    final success = await GalleryService.saveToGallery(path);
    if (!mounted) return;

    setState(() {
      _saved = success;
      _saving = false;
    });

    // After save action
    if (success && widget.afterSave == 'photos') {
      // Small delay so the image is indexed
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      // Open Photos app
      await launchUrl(Uri.parse('photos-redirect://'), mode: LaunchMode.externalApplication);
    }
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: () {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
        Navigator.of(context).popUntil((route) => route.isFirst);
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            Container(color: Colors.black),

            // Save status indicator (bottom right, subtle)
            if (_saved)
              Positioned(
                bottom: 20,
                right: 20,
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.3),
                    shape: BoxShape.circle,
                  ),
                ),
              ),

            if (_saving)
              Positioned(
                bottom: 20,
                right: 20,
                child: SizedBox(
                  width: 6,
                  height: 6,
                  child: CircularProgressIndicator(
                    strokeWidth: 1,
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
