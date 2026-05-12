import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import '../models/models.dart';
import '../data/local_storage.dart';
import '../services/icloud_sync_service.dart';
import 'haptic_helper.dart';

/// Reveal background theme options
enum RevealThemeMode {
  light,
  dark,
  system;

  String get displayName {
    switch (this) {
      case RevealThemeMode.light:
        return 'Light';
      case RevealThemeMode.dark:
        return 'Dark';
      case RevealThemeMode.system:
        return 'System';
    }
  }

  /// Returns true if dark mode should be used for reveal
  bool get isDarkMode {
    switch (this) {
      case RevealThemeMode.light:
        return false;
      case RevealThemeMode.dark:
        return true;
      case RevealThemeMode.system:
        // Check system brightness
        final brightness = SchedulerBinding.instance.platformDispatcher.platformBrightness;
        return brightness == Brightness.dark;
    }
  }
}

class SettingsProvider extends ChangeNotifier {
  final LocalStorage? _storage;
  bool _suppressSync = false;

  @override
  void notifyListeners() {
    super.notifyListeners();
    if (!_suppressSync) {
      ICloudSyncService.scheduleAutoPush();
    }
  }

  /// Wrap a block of mutations to notify listeners without triggering iCloud push.
  /// Used when applying cloud pulls to avoid a feedback loop.
  void applyWithoutSync(void Function() fn) {
    _suppressSync = true;
    try {
      fn();
    } finally {
      _suppressSync = false;
    }
  }

  bool _hapticFeedback = true;
  HapticIntensity _hapticIntensity = HapticIntensity.medium;
  bool _testModeEnabled = false;
  bool _debugPanelEnabled = false;
  RevealThemeMode _revealThemeMode = RevealThemeMode.system;
  bool _doubleTapFallbackEnabled = false;
  bool _visualFeedbackEnabled = false;
  bool _preScreenEnabled = false;
  String _preScreenType = 'notes'; // 'notes' or 'homescreen'
  String? _homescreenPath;
  String? _autoStartPresetId;
  bool _autoCopyNarrative = false;
  String _shortcutName = '';
  String _openaiApiKey = '';
  String _templatesAdminToken = '';

  // Assistant mode
  String _assistantId = '';
  bool _assistantModeEnabled = false;
  /// Preferred presentation for the remote assistant UI when it mirrors a
  /// preset in stealth mode. One of 'buttons', 'blackscreen_tap',
  /// 'blackscreen_swipe'. Default 'buttons' is the most accessible.
  String _assistantStealthMode = 'buttons';

  // Bluetooth remote mapping (keyboard key labels)
  String _remoteKeyUp = '';
  String _remoteKeyDown = '';
  String _remoteKeyLeft = '';
  String _remoteKeyRight = '';
  bool _remoteEnabled = false;

  // Free Text Assistant settings
  String _freeTextRedirectUrl = '';
  String _freeTextTransformPrompt = '';
  bool _freeTextAcrosticEnabled = false;

  // Decoy templates library (max 3). Edited in Settings → Display.
  // Presets reference one by id via `Preset.decoyTemplateId`.
  List<DecoyTemplate> _decoyTemplates = [];
  // Optional default template id used when a preset has none set. null = no
  // default (preset without `decoyTemplateId` falls back to assistant UI).
  String? _defaultDecoyTemplateId;
  // Whether the spectator-facing decoy webapp shows a discreet pulse dot to
  // confirm each input was registered. Defaults to true (visible).
  bool _decoyShowIndicator = true;
  // Where the spectator's webapp redirects after a decoy session ends. The
  // per-preset `assistantRedirectUrl` overrides this when set. Default looks
  // like a natural place to land — Google home page.
  String _decoyRedirectUrl = 'https://www.google.com';

  // App language (global)
  Language _appLanguage = Language.english;

  // External API credentials
  String _injectId = '';
  String _elipsId = '';
  String _elipsApiKey = '';
  String _highScoreApiKey = '';

  SettingsProvider(this._storage) {
    _loadSettings();
  }

  Language get appLanguage => _appLanguage;
  bool get hapticFeedback => _hapticFeedback;
  HapticIntensity get hapticIntensity => _hapticIntensity;
  bool get testModeEnabled => _testModeEnabled;
  bool get debugPanelEnabled => _debugPanelEnabled;
  RevealThemeMode get revealThemeMode => _revealThemeMode;
  bool get revealIsDarkMode => _revealThemeMode.isDarkMode;
  bool get doubleTapFallbackEnabled => _doubleTapFallbackEnabled;
  bool get visualFeedbackEnabled => _visualFeedbackEnabled;
  bool get preScreenEnabled => _preScreenEnabled;
  String get preScreenType => _preScreenType;
  String? get homescreenPath => _homescreenPath;
  bool get hasHomescreenPath => _homescreenPath != null && _homescreenPath!.isNotEmpty;
  String? get autoStartPresetId => _autoStartPresetId;
  bool get autoCopyNarrative => _autoCopyNarrative;
  String get shortcutName => _shortcutName;
  String get openaiApiKey => _openaiApiKey;
  bool get hasOpenaiApiKey => _openaiApiKey.isNotEmpty;
  String get templatesAdminToken => _templatesAdminToken;
  bool get isTemplatesAdmin => _templatesAdminToken.isNotEmpty;

  // Assistant mode
  String get assistantId => _assistantId;
  String get assistantUrl => 'https://oass.app/$_assistantId';
  bool get assistantModeEnabled => _assistantModeEnabled;

  /// Runtime-only: Assistant Mode is intentionally not persisted — it defaults
  /// to OFF on every app launch so the performer has a clean starting state.
  Future<void> setAssistantModeEnabled(bool value) async {
    _assistantModeEnabled = value;
    notifyListeners();
  }

  String get assistantStealthMode => _assistantStealthMode;

  Future<void> setAssistantStealthMode(String value) async {
    _assistantStealthMode = value;
    await _storage?.setString('assistant_stealth_mode', value);
    notifyListeners();
  }

  Future<void> setAssistantId(String value) async {
    final trimmed = value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9\-_]'), '');
    if (trimmed.isEmpty) return;
    _assistantId = trimmed;
    await _storage?.setString('assistant_id', _assistantId);
    notifyListeners();
  }

  // Bluetooth remote
  bool get remoteEnabled => _remoteEnabled;
  String get remoteKeyUp => _remoteKeyUp;
  String get remoteKeyDown => _remoteKeyDown;
  String get remoteKeyLeft => _remoteKeyLeft;
  String get remoteKeyRight => _remoteKeyRight;
  bool get hasRemote4Buttons => _remoteKeyLeft.isNotEmpty && _remoteKeyRight.isNotEmpty;

  Future<void> setRemoteEnabled(bool value) async {
    _remoteEnabled = value;
    await _storage?.setBool('remote_enabled', value);
    notifyListeners();
  }

  Future<void> setRemoteKey(String direction, String keyLabel) async {
    switch (direction) {
      case 'up': _remoteKeyUp = keyLabel; break;
      case 'down': _remoteKeyDown = keyLabel; break;
      case 'left': _remoteKeyLeft = keyLabel; break;
      case 'right': _remoteKeyRight = keyLabel; break;
    }
    await _storage?.setString('remote_key_$direction', keyLabel);
    notifyListeners();
  }

  // Free Text Assistant getters
  String get freeTextRedirectUrl => _freeTextRedirectUrl;
  String get freeTextTransformPrompt => _freeTextTransformPrompt;
  bool get hasFreeTextTransformPrompt => _freeTextTransformPrompt.isNotEmpty;
  bool get freeTextAcrosticEnabled => _freeTextAcrosticEnabled;

  /// User-defined decoy templates (max 3, unlimited for admins). Edited in
  /// Settings → Display.
  List<DecoyTemplate> get decoyTemplates => List.unmodifiable(_decoyTemplates);
  bool get canCreateDecoyTemplate =>
      isTemplatesAdmin || _decoyTemplates.length < maxDecoyTemplates;
  static const int maxDecoyTemplates = 3;

  DecoyTemplate? decoyTemplateById(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final t in _decoyTemplates) {
      if (t.id == id) return t;
    }
    return null;
  }

  /// Default decoy template id used when a preset doesn't specify one.
  /// null = no fallback (preset without decoy → standard assistant UI).
  String? get defaultDecoyTemplateId => _defaultDecoyTemplateId;

  Future<void> setDefaultDecoyTemplateId(String? id) async {
    _defaultDecoyTemplateId = (id?.isEmpty ?? true) ? null : id;
    if (_defaultDecoyTemplateId == null) {
      await _storage?.remove('default_decoy_template_id');
    } else {
      await _storage?.setString('default_decoy_template_id', _defaultDecoyTemplateId!);
    }
    notifyListeners();
  }

  Future<bool> addDecoyTemplate(DecoyTemplate template) async {
    if (!canCreateDecoyTemplate) return false;
    _decoyTemplates.add(template);
    await _persistDecoyTemplates();
    notifyListeners();
    return true;
  }

  Future<void> updateDecoyTemplate(DecoyTemplate template) async {
    final idx = _decoyTemplates.indexWhere((t) => t.id == template.id);
    if (idx < 0) return;
    _decoyTemplates[idx] = template;
    await _persistDecoyTemplates();
    notifyListeners();
  }

  Future<void> deleteDecoyTemplate(String id) async {
    _decoyTemplates.removeWhere((t) => t.id == id);
    if (_defaultDecoyTemplateId == id) {
      _defaultDecoyTemplateId = null;
      await _storage?.remove('default_decoy_template_id');
    }
    await _persistDecoyTemplates();
    notifyListeners();
  }

  Future<void> _persistDecoyTemplates() async {
    final encoded = _decoyTemplates.map((t) => t.toJson()).toList();
    await _storage?.setString('decoy_templates', jsonEncode(encoded));
  }

  /// When true, the decoy webapp shows a small white pulse in the bottom
  /// corner each time an input registers. Off = fully silent (only haptic).
  bool get decoyShowIndicator => _decoyShowIndicator;
  Future<void> setDecoyShowIndicator(bool value) async {
    _decoyShowIndicator = value;
    await _storage?.setBool('decoy_show_indicator', value);
    notifyListeners();
  }

  /// Default redirect URL for the decoy webapp after a session ends. The
  /// per-preset `assistantRedirectUrl` takes precedence when set.
  String get decoyRedirectUrl => _decoyRedirectUrl;
  Future<void> setDecoyRedirectUrl(String value) async {
    final trimmed = value.trim();
    _decoyRedirectUrl = trimmed.isEmpty ? 'https://www.google.com' : trimmed;
    await _storage?.setString('decoy_redirect_url', _decoyRedirectUrl);
    notifyListeners();
  }

  Future<void> setFreeTextRedirectUrl(String value) async {
    _freeTextRedirectUrl = value.trim();
    await _storage?.setString('free_text_redirect_url', _freeTextRedirectUrl);
    notifyListeners();
  }

  Future<void> setFreeTextTransformPrompt(String value) async {
    _freeTextTransformPrompt = value.trim();
    await _storage?.setString('free_text_transform_prompt', _freeTextTransformPrompt);
    notifyListeners();
  }

  Future<void> setFreeTextAcrosticEnabled(bool value) async {
    _freeTextAcrosticEnabled = value;
    await _storage?.setBool('free_text_acrostic_enabled', value);
    notifyListeners();
  }

  /// Generic getter for any stored string
  String? getString(String key) => _storage?.getString(key);

  // External API getters
  String get injectId => _injectId;
  bool get hasInjectConfig => _injectId.isNotEmpty;
  String get elipsId => _elipsId;
  String get elipsApiKey => _elipsApiKey;
  bool get hasElipsConfig => _elipsId.isNotEmpty && _elipsApiKey.isNotEmpty;
  String get highScoreApiKey => _highScoreApiKey;
  bool get hasHighScoreConfig => _highScoreApiKey.isNotEmpty;
  bool get hasAnyApiConfig => hasInjectConfig || hasElipsConfig || hasHighScoreConfig;

  Future<void> _loadSettings() async {
    if (_storage == null) return;

    try {
      _hapticFeedback = _storage!.getBool('haptic_feedback') ?? true;
      final intensityIndex = _storage!.getInt('haptic_intensity') ?? 1; // Default to medium
      _hapticIntensity = HapticIntensity.values[intensityIndex.clamp(0, HapticIntensity.values.length - 1)];
      _testModeEnabled = _storage!.getBool('test_mode_enabled') ?? false;
      _debugPanelEnabled = _storage!.getBool('debug_panel_enabled') ?? false;
      final themeIndex = _storage!.getInt('reveal_theme_mode') ?? 2; // Default to system
      _revealThemeMode = RevealThemeMode.values[themeIndex.clamp(0, RevealThemeMode.values.length - 1)];
      _doubleTapFallbackEnabled = _storage!.getBool('double_tap_fallback_enabled') ?? false;
      _visualFeedbackEnabled = _storage!.getBool('visual_feedback_enabled') ?? false;
      _preScreenEnabled = _storage!.getBool('pre_screen_enabled') ?? false;
      _preScreenType = _storage!.getString('pre_screen_type') ?? 'notes';
      _homescreenPath = _storage!.getString('homescreen_path');
      _autoStartPresetId = _storage!.getString('auto_start_preset_id');
      _autoCopyNarrative = _storage!.getBool('auto_copy_narrative') ?? false;
      _shortcutName = _storage!.getString('shortcut_name') ?? '';
      _openaiApiKey = _storage!.getString('openai_api_key') ?? '';
      _templatesAdminToken = _storage!.getString('templates_admin_token') ?? '';
      // Assistant Mode is runtime-only: always OFF at boot.
      _assistantModeEnabled = false;
      _assistantStealthMode = _storage!.getString('assistant_stealth_mode') ?? 'buttons';
      _assistantId = _storage!.getString('assistant_id') ?? '';
      if (_assistantId.isEmpty) {
        // Generate a short 4-char ID
        final chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
        final rand = DateTime.now().millisecondsSinceEpoch;
        _assistantId = String.fromCharCodes(
          List.generate(4, (i) => chars.codeUnitAt((rand >> (i * 5)) % chars.length)),
        );
        await _storage!.setString('assistant_id', _assistantId);
      }
      _remoteEnabled = _storage!.getBool('remote_enabled') ?? false;
      _remoteKeyUp = _storage!.getString('remote_key_up') ?? '';
      _remoteKeyDown = _storage!.getString('remote_key_down') ?? '';
      _remoteKeyLeft = _storage!.getString('remote_key_left') ?? '';
      _remoteKeyRight = _storage!.getString('remote_key_right') ?? '';
      _freeTextRedirectUrl = _storage!.getString('free_text_redirect_url') ?? '';
      _decoyShowIndicator = _storage!.getBool('decoy_show_indicator') ?? true;
      _decoyRedirectUrl = _storage!.getString('decoy_redirect_url') ?? 'https://www.google.com';
      _defaultDecoyTemplateId = _storage!.getString('default_decoy_template_id');
      // Decoy templates list (decoded from a JSON array of template maps).
      final templatesRaw = _storage!.getString('decoy_templates');
      if (templatesRaw != null && templatesRaw.isNotEmpty) {
        try {
          final decoded = jsonDecode(templatesRaw);
          if (decoded is List) {
            _decoyTemplates = decoded
                .whereType<Map>()
                .map((m) => DecoyTemplate.fromJson(m.cast<String, dynamic>()))
                .toList();
          }
        } catch (_) {
          _decoyTemplates = [];
        }
      }
      _freeTextTransformPrompt = _storage!.getString('free_text_transform_prompt') ?? '';
      _freeTextAcrosticEnabled = _storage!.getBool('free_text_acrostic_enabled') ?? false;
      _injectId = _storage!.getString('inject_id') ?? '';
      _elipsId = _storage!.getString('elips_id') ?? '';
      _elipsApiKey = _storage!.getString('elips_api_key') ?? '';
      _highScoreApiKey = _storage!.getString('high_score_api_key') ?? '';
      _appLanguage = Language.fromString(_storage!.getString('app_language'));
      notifyListeners();
    } catch (e) {
      // Use defaults on error
    }
  }

  Future<void> setAppLanguage(Language value) async {
    _appLanguage = value;
    await _storage?.setString('app_language', value.name);
    notifyListeners();
  }

  Future<void> setHapticFeedback(bool value) async {
    _hapticFeedback = value;
    await _storage?.setBool('haptic_feedback', value);
    notifyListeners();
  }

  Future<void> setHapticIntensity(HapticIntensity value) async {
    _hapticIntensity = value;
    await _storage?.setInt('haptic_intensity', value.index);
    notifyListeners();
  }

  Future<void> setTestModeEnabled(bool value) async {
    _testModeEnabled = value;
    await _storage?.setBool('test_mode_enabled', value);
    notifyListeners();
  }

  Future<void> setDebugPanelEnabled(bool value) async {
    _debugPanelEnabled = value;
    await _storage?.setBool('debug_panel_enabled', value);
    notifyListeners();
  }

  Future<void> setRevealThemeMode(RevealThemeMode mode) async {
    _revealThemeMode = mode;
    await _storage?.setInt('reveal_theme_mode', mode.index);
    notifyListeners();
  }

  Future<void> setDoubleTapFallbackEnabled(bool value) async {
    _doubleTapFallbackEnabled = value;
    await _storage?.setBool('double_tap_fallback_enabled', value);
    notifyListeners();
  }

  Future<void> setVisualFeedbackEnabled(bool value) async {
    _visualFeedbackEnabled = value;
    await _storage?.setBool('visual_feedback_enabled', value);
    notifyListeners();
  }

  Future<void> setPreScreenEnabled(bool value) async {
    _preScreenEnabled = value;
    await _storage?.setBool('pre_screen_enabled', value);
    notifyListeners();
  }

  Future<void> setPreScreenType(String value) async {
    _preScreenType = value;
    await _storage?.setString('pre_screen_type', value);
    notifyListeners();
  }

  Future<void> setHomescreenPath(String? path) async {
    _homescreenPath = path;
    if (path == null) {
      await _storage?.remove('homescreen_path');
    } else {
      await _storage?.setString('homescreen_path', path);
    }
    notifyListeners();
  }

  Future<void> setAutoStartPresetId(String? presetId) async {
    _autoStartPresetId = presetId;
    if (presetId == null) {
      await _storage?.remove('auto_start_preset_id');
    } else {
      await _storage?.setString('auto_start_preset_id', presetId);
    }
    notifyListeners();
  }

  Future<void> setAutoCopyNarrative(bool value) async {
    _autoCopyNarrative = value;
    await _storage?.setBool('auto_copy_narrative', value);
    notifyListeners();
  }

  Future<void> setShortcutName(String value) async {
    _shortcutName = value;
    await _storage?.setString('shortcut_name', value);
    notifyListeners();
  }

  Future<void> setOpenaiApiKey(String value) async {
    _openaiApiKey = value;
    await _storage?.setString('openai_api_key', value);
    notifyListeners();
  }

  Future<void> setTemplatesAdminToken(String value) async {
    _templatesAdminToken = value.trim();
    await _storage?.setString('templates_admin_token', _templatesAdminToken);
    notifyListeners();
  }

  Future<void> setInjectId(String value) async {
    _injectId = value;
    await _storage?.setString('inject_id', value);
    notifyListeners();
  }

  Future<void> setElipsId(String value) async {
    _elipsId = value;
    await _storage?.setString('elips_id', value);
    notifyListeners();
  }

  Future<void> setElipsApiKey(String value) async {
    _elipsApiKey = value;
    await _storage?.setString('elips_api_key', value);
    notifyListeners();
  }

  Future<void> setHighScoreApiKey(String value) async {
    _highScoreApiKey = value;
    await _storage?.setString('high_score_api_key', value);
    notifyListeners();
  }
}
