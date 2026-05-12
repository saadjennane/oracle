import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:path_provider/path_provider.dart';
import '../models/models.dart';
import '../data/local_storage.dart';

class RevealProvider extends ChangeNotifier {
  final LocalStorage? _storage;

  RevealSkinConfig _config = RevealSkinConfig.empty;
  bool _isLoading = false;

  RevealProvider(this._storage) {
    _loadConfig();
  }

  RevealSkinConfig get config => _config;
  bool get isLoading => _isLoading;

  // Note screen backgrounds
  bool get hasLightBackground => _config.hasLightBackground;
  bool get hasDarkBackground => _config.hasDarkBackground;
  bool get hasAnyBackground => _config.hasAnyBackground;

  // Calculator background
  bool get hasCalculatorBackground => _config.hasCalculatorBackground;
  RevealTextLayout get calculatorLayout => _config.calculatorLayout;

  Future<void> setCalculatorLayout(RevealTextLayout layout) async {
    _config = _config.copyWith(calculatorLayout: layout);
    await _saveConfig();
    notifyListeners();
  }

  // List screen backgrounds
  bool get hasLightListBackground => _config.hasLightListBackground;
  bool get hasDarkListBackground => _config.hasDarkListBackground;
  bool get hasAnyListBackground => _config.hasAnyListBackground;

  RevealTextLayout get lightLayout => _config.lightLayout;
  RevealTextLayout get darkLayout => _config.darkLayout;

  Future<void> _loadConfig() async {
    if (_storage == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      final jsonString = _storage!.getString('reveal_skin_config');
      if (jsonString != null && jsonString.isNotEmpty) {
        _config = RevealSkinConfig.fromJsonString(jsonString);
      }
    } catch (e) {
      debugPrint('Error loading reveal config: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _saveConfig() async {
    if (_storage == null) return;
    await _storage!.setString('reveal_skin_config', _config.toJsonString());
  }

  /// Get the app's documents directory for storing images
  Future<Directory> _getImagesDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final imagesDir = Directory('${appDir.path}/reveal_backgrounds');
    if (!await imagesDir.exists()) {
      await imagesDir.create(recursive: true);
    }
    return imagesDir;
  }

  /// Save an image file and return the stored path
  Future<String> _saveImageFile(File sourceFile, String prefix) async {
    final imagesDir = await _getImagesDirectory();
    // Add timestamp to filename to bust cache
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final destPath = '${imagesDir.path}/${prefix}_$timestamp.png';

    // Copy file to app storage
    await sourceFile.copy(destPath);
    return destPath;
  }

  /// Delete an image file if it exists
  Future<void> _deleteImageFile(String? path) async {
    if (path == null || path.isEmpty) return;

    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('Error deleting image: $e');
    }
  }

  /// Set light mode background from a picked file
  Future<void> setLightBackground(File imageFile) async {
    // Delete old background if exists
    await _deleteImageFile(_config.lightBackgroundPath);

    // Clear image cache to ensure new image is loaded
    imageCache.clear();
    imageCache.clearLiveImages();

    // Save new image with unique name
    final savedPath = await _saveImageFile(imageFile, 'light_bg');

    _config = _config.copyWith(lightBackgroundPath: savedPath);
    await _saveConfig();
    notifyListeners();
  }

  /// Set dark mode background from a picked file
  Future<void> setDarkBackground(File imageFile) async {
    // Delete old background if exists
    await _deleteImageFile(_config.darkBackgroundPath);

    // Clear image cache to ensure new image is loaded
    imageCache.clear();
    imageCache.clearLiveImages();

    // Save new image with unique name
    final savedPath = await _saveImageFile(imageFile, 'dark_bg');

    _config = _config.copyWith(darkBackgroundPath: savedPath);
    await _saveConfig();
    notifyListeners();
  }

  /// Remove light mode background
  Future<void> removeLightBackground() async {
    await _deleteImageFile(_config.lightBackgroundPath);
    _config = _config.copyWith(clearLightBackground: true);
    await _saveConfig();
    notifyListeners();
  }

  /// Remove dark mode background
  Future<void> removeDarkBackground() async {
    await _deleteImageFile(_config.darkBackgroundPath);
    _config = _config.copyWith(clearDarkBackground: true);
    await _saveConfig();
    notifyListeners();
  }

  // ============= LIST BACKGROUNDS =============

  /// Set light mode list background from a picked file
  Future<void> setLightListBackground(File imageFile) async {
    await _deleteImageFile(_config.lightListBackgroundPath);
    imageCache.clear();
    imageCache.clearLiveImages();
    final savedPath = await _saveImageFile(imageFile, 'light_list_bg');
    _config = _config.copyWith(lightListBackgroundPath: savedPath);
    await _saveConfig();
    notifyListeners();
  }

  /// Set dark mode list background from a picked file
  Future<void> setDarkListBackground(File imageFile) async {
    await _deleteImageFile(_config.darkListBackgroundPath);
    imageCache.clear();
    imageCache.clearLiveImages();
    final savedPath = await _saveImageFile(imageFile, 'dark_list_bg');
    _config = _config.copyWith(darkListBackgroundPath: savedPath);
    await _saveConfig();
    notifyListeners();
  }

  /// Remove light mode list background
  Future<void> removeLightListBackground() async {
    await _deleteImageFile(_config.lightListBackgroundPath);
    _config = _config.copyWith(clearLightListBackground: true);
    await _saveConfig();
    notifyListeners();
  }

  /// Remove dark mode list background
  Future<void> removeDarkListBackground() async {
    await _deleteImageFile(_config.darkListBackgroundPath);
    _config = _config.copyWith(clearDarkListBackground: true);
    await _saveConfig();
    notifyListeners();
  }

  Future<void> setCalculatorBackground(File imageFile) async {
    final dir = await getApplicationDocumentsDirectory();
    final destPath = '${dir.path}/calculator_bg.png';
    await imageFile.copy(destPath);
    _config = _config.copyWith(calculatorBackgroundPath: destPath);
    await _saveConfig();
    notifyListeners();
  }

  Future<void> removeCalculatorBackground() async {
    await _deleteImageFile(_config.calculatorBackgroundPath);
    _config = _config.copyWith(clearCalculatorBackground: true);
    await _saveConfig();
    notifyListeners();
  }

  /// Get the appropriate list background path based on brightness
  String? getListBackgroundPath({required bool isDarkMode}) {
    if (isDarkMode && _config.hasDarkListBackground) {
      return _config.darkListBackgroundPath;
    } else if (!isDarkMode && _config.hasLightListBackground) {
      return _config.lightListBackgroundPath;
    }
    // Fallback: use whatever is available
    if (_config.hasLightListBackground) return _config.lightListBackgroundPath;
    if (_config.hasDarkListBackground) return _config.darkListBackgroundPath;
    return null;
  }

  /// Update light layout configuration
  Future<void> updateLightLayout(RevealTextLayout layout) async {
    _config = _config.copyWith(lightLayout: layout);
    await _saveConfig();
    notifyListeners();
  }

  /// Update dark layout configuration
  Future<void> updateDarkLayout(RevealTextLayout layout) async {
    _config = _config.copyWith(darkLayout: layout);
    await _saveConfig();
    notifyListeners();
  }

  /// Get the appropriate background path based on brightness
  String? getBackgroundPath({required bool isDarkMode}) {
    if (isDarkMode && _config.hasDarkBackground) {
      return _config.darkBackgroundPath;
    } else if (!isDarkMode && _config.hasLightBackground) {
      return _config.lightBackgroundPath;
    }
    // Fallback: use whatever is available
    if (_config.hasLightBackground) return _config.lightBackgroundPath;
    if (_config.hasDarkBackground) return _config.darkBackgroundPath;
    return null;
  }

  /// Get the appropriate text layout based on brightness
  RevealTextLayout getTextLayout({required bool isDarkMode}) {
    if (isDarkMode && _config.hasDarkBackground) {
      return _config.darkLayout;
    } else if (!isDarkMode && _config.hasLightBackground) {
      return _config.lightLayout;
    }
    // Fallback: use light layout if any background exists
    if (_config.hasLightBackground) return _config.lightLayout;
    if (_config.hasDarkBackground) return _config.darkLayout;
    return const RevealTextLayout();
  }
}
