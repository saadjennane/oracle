import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'models/models.dart';
import 'services/bank_image_store.dart';
import 'services/firebase_service.dart';
import 'utils/game_provider.dart';
import 'utils/presets_provider.dart';
import 'utils/settings_provider.dart';
import 'ui/theme/app_theme.dart';
import 'ui/screens/home_screen.dart';
import 'ui/screens/license_gate_screen.dart';
import 'ui/screens/setup_screen.dart';
import 'ui/screens/preset_builder_screen.dart';
import 'ui/screens/rounds_input_screen.dart';
import 'ui/screens/stealth_input_screen.dart';
import 'ui/screens/tap_stealth_input_screen.dart';
import 'ui/screens/performance_flow_screen.dart';
import 'ui/screens/narration_preview_screen.dart';
import 'ui/screens/fake_note_screen.dart';
import 'ui/screens/history_screen.dart';
import 'ui/screens/settings_screen.dart';
import 'ui/screens/templates_screen.dart';
import 'ui/screens/reveal_calibration_screen.dart';
import 'ui/screens/confabulation_editor_screen.dart';
import 'ui/screens/confabulation_run_screen.dart';
import 'ui/screens/confabulation_result_screen.dart';
import 'ui/screens/narrative_lab_screen.dart';
import 'ui/screens/free_will_input_screen.dart';
import 'ui/screens/audio_input_screen.dart';
import 'ui/screens/multiple_out_input_screen.dart';
import 'ui/screens/assistant_input_screen.dart';
import 'ui/screens/acrostic_config_screen.dart';
import 'ui/screens/number_input_screen.dart';
import 'ui/screens/calculator_screen.dart';
import 'ui/screens/routine_builder_screen.dart';
import 'ui/screens/free_will_audio_screen.dart';
import 'ui/screens/confabulation_assistant_screen.dart';
import 'ui/screens/calculator_editor_screen.dart';
import 'ui/screens/calculator_calibration_screen.dart';
import 'ui/screens/tutorial_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'services/gallery_service.dart';
import 'ui/screens/image_reveal_screen.dart';

/// Navigate to preview or chain to next preset
void navigateAfterPresetComplete(BuildContext context) {
  final gameProvider = Provider.of<GameProvider>(context, listen: false);
  final settings = Provider.of<SettingsProvider>(context, listen: false);

  // Decoy Mode: when a preset finishes (and we're not chaining into the
  // next one), clear the session so the spectator's webapp redirects away
  // from the decoy image and returns to idle.
  if (settings.assistantModeEnabled && !gameProvider.isChaining) {
    FirebaseService.clearSession(settings.assistantId);
  }

  if (gameProvider.isChaining && gameProvider.hasNextPreset) {
    final nextId = gameProvider.completeChainStep();
    if (nextId != null && nextId.isNotEmpty) {
      final presetsProvider = Provider.of<PresetsProvider>(context, listen: false);
      final nextPreset = presetsProvider.presets.where((p) => p.id == nextId).firstOrNull;
      if (nextPreset != null) {
        // Play the next preset in chain
        _playChainedPreset(context, nextPreset);
        return;
      }
    }
  }

  // No more chaining — finalize
  if (gameProvider.isChaining) {
    gameProvider.finalizeChain();
  }

  // Route based on output mode
  final preset = gameProvider.currentPreset;
  final outputMode = preset?.outputMode ?? 'notes';
  final bankKey = gameProvider.lastBankKey;
  final imagePath = (bankKey != null && preset?.bankImages != null)
      ? preset!.bankImages![bankKey]
      : null;

  if (outputMode == 'both' && imagePath != null) {
    // Both mode: save image to gallery first, then copy text + launch shortcut
    Future<String> ensureLocal() async {
      final f = File(imagePath);
      if (f.existsSync()) return imagePath;
      final resolved = await BankImageStore.resolveForRead(imagePath);
      return resolved ?? imagePath;
    }
    ensureLocal().then((resolved) => GalleryService.saveToGallery(resolved)).then((_) {
      // Text was already auto-copied in finalizeChain/generate
      // Now launch shortcut which will open Notes/Telegram
      final settings = Provider.of<SettingsProvider>(context, listen: false);
      final autoCopy = preset?.autoCopyOverride ?? settings.autoCopyNarrative;
      final shortcut = preset?.shortcutNameOverride ?? settings.shortcutName;
      if (autoCopy && shortcut.isNotEmpty) {
        _launchShortcut(shortcut);
      }
    });
    // Go straight to the reveal (fake note screen) — skip the preview step
    gameProvider.confirmAndSave();
    Navigator.pushReplacementNamed(context, '/reveal');
  } else if (outputMode == 'image' && imagePath != null) {
    Navigator.pushReplacementNamed(context, '/image-reveal', arguments: {
      'imagePath': imagePath,
      'afterSave': preset?.imageAfterSave ?? 'black',
    });
  } else {
    // Default path: save session, skip the preview screen, go to reveal.
    gameProvider.confirmAndSave();
    Navigator.pushReplacementNamed(context, '/reveal');
  }
}

void _launchShortcut(String shortcutName) {
  final url = Uri.parse('shortcuts://run-shortcut?name=${Uri.encodeComponent(shortcutName)}');
  launchUrl(url, mode: LaunchMode.externalApplication);
}

void _playChainedPreset(BuildContext context, Preset preset) {
  final gameProvider = Provider.of<GameProvider>(context, listen: false);
  final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);

  gameProvider.startGameFromPreset(preset);

  if (preset.type == PresetType.number) {
    Navigator.pushReplacementNamed(context, '/number-input', arguments: preset);
  } else if (preset.type == PresetType.multipleOut) {
    Navigator.pushReplacementNamed(context, '/multiple-out-input', arguments: preset);
  } else if (preset.type == PresetType.freeWill) {
    if (preset.stealthInputMethod == StealthInputMethod.assistant) {
      Navigator.pushReplacementNamed(context, '/assistant-input', arguments: preset);
    } else if (preset.stealthInputMethod == StealthInputMethod.audio) {
      Navigator.pushReplacementNamed(context, '/free-will-audio', arguments: preset);
    } else {
      Navigator.pushReplacementNamed(context, '/free-will-input', arguments: preset);
    }
  } else {
    switch (preset.stealthInputMethod) {
      case StealthInputMethod.volume:
      case StealthInputMethod.tap:
        if (settingsProvider.testModeEnabled) {
          if (preset.stealthInputMethod == StealthInputMethod.volume) {
            Navigator.pushReplacementNamed(context, '/stealth');
          } else {
            Navigator.pushReplacementNamed(context, '/stealth-tap', arguments: preset);
          }
        } else {
          Navigator.pushReplacementNamed(context, '/performance-flow', arguments: preset);
        }
        break;
      case StealthInputMethod.audio:
        Navigator.pushReplacementNamed(context, '/audio-input', arguments: preset);
        break;
      case StealthInputMethod.clockSwipe:
        if (preset.swipePatterns != null) {
          Navigator.pushReplacementNamed(context, '/performance-flow', arguments: preset);
        } else {
          Navigator.pushReplacementNamed(context, '/rounds');
        }
        break;
      case StealthInputMethod.assistant:
        Navigator.pushReplacementNamed(context, '/assistant-input', arguments: preset);
        break;
    }
  }
}

class OracleApp extends StatelessWidget {
  const OracleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ORACLE',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      initialRoute: '/',
      routes: {
        '/': (context) => const LicenseGateScreen(),
        '/setup': (context) => const SetupScreen(), // Legacy, kept for compatibility
        '/preset': (context) => const PresetBuilderScreen(), // New Preset Builder
        '/rounds': (context) => const RoundsInputScreen(),
        '/stealth': (context) => const StealthInputScreen(), // Volume stealth input
        '/audio-input': (context) => const AudioInputScreen(),
        '/preview': (context) => const NarrationPreviewScreen(),
        '/reveal': (context) => const FakeNoteScreen(),
        '/history': (context) => const HistoryScreen(),
        '/settings': (context) => const SettingsScreen(),
        '/acrostic-config': (context) => const AcrosticConfigScreen(),
        '/tutorial': (context) => const TutorialScreen(),
        '/templates': (context) => const TemplatesScreen(),
      },
      onGenerateRoute: (settings) {
        // Handle routes with arguments
        if (settings.name == '/stealth-tap') {
          final preset = settings.arguments as Preset?;
          return MaterialPageRoute(
            builder: (context) => TapStealthInputScreen(
              tapLayout2: preset?.tapLayout2 ?? TapLayout2.leftRight,
              tapLayout4: preset?.tapLayout4 ?? TapLayout4.corners,
            ),
          );
        }
        if (settings.name == '/performance-flow') {
          final preset = settings.arguments as Preset?;
          return MaterialPageRoute(
            builder: (context) => PerformanceFlowScreen(
              stealthMethod: preset?.stealthInputMethod ?? StealthInputMethod.volume,
              tapLayout2: preset?.tapLayout2 ?? TapLayout2.leftRight,
              tapLayout4: preset?.tapLayout4 ?? TapLayout4.corners,
              swipePatterns: preset?.swipePatterns,
            ),
          );
        }
        if (settings.name == '/reveal-calibration') {
          final isDarkMode = settings.arguments as bool? ?? false;
          return MaterialPageRoute(
            builder: (context) => RevealCalibrationScreen(isDarkMode: isDarkMode),
          );
        }
        // Confabulation routes
        if (settings.name == '/confabulation/editor') {
          return MaterialPageRoute(
            builder: (context) => const ConfabulationEditorScreen(),
            settings: settings,
          );
        }
        if (settings.name == '/confabulation/assistant') {
          return MaterialPageRoute(
            builder: (context) => const ConfabulationAssistantScreen(),
            settings: settings,
          );
        }
        if (settings.name == '/confabulation/run') {
          return MaterialPageRoute(
            builder: (context) => const ConfabulationRunScreen(),
            settings: settings,
          );
        }
        if (settings.name == '/confabulation/result') {
          return MaterialPageRoute(
            builder: (context) => const ConfabulationResultScreen(),
          );
        }
        if (settings.name == '/narrative-lab') {
          return MaterialPageRoute(
            builder: (context) => const NarrativeLabScreen(),
          );
        }
        // Number input route
        if (settings.name == '/number-input') {
          return MaterialPageRoute(
            builder: (context) => const NumberInputScreen(),
            settings: settings,
          );
        }
        // Calculator route
        if (settings.name == '/calculator') {
          final result = settings.arguments as String? ?? '0';
          return MaterialPageRoute(
            builder: (context) => CalculatorScreen(prefilledResult: result),
          );
        }
        // Assistant input route
        if (settings.name == '/assistant-input') {
          return MaterialPageRoute(
            builder: (context) => const AssistantInputScreen(),
            settings: settings,
          );
        }
        // Assistant free text route
        if (settings.name == '/assistant-free-text') {
          return MaterialPageRoute(
            builder: (context) => const AssistantFreeTextScreen(),
          );
        }
        // Multiple Out input route
        if (settings.name == '/multiple-out-input') {
          final preset = settings.arguments as Preset?;
          if (preset != null) {
            return MaterialPageRoute(
              builder: (context) => MultipleOutInputScreen(
                preset: preset,
                onComplete: (selectedIndex) {
                  final gameProvider = Provider.of<GameProvider>(context, listen: false);
                  gameProvider.completeMultipleOut(selectedIndex, preset);
                  navigateAfterPresetComplete(context);
                },
              ),
            );
          }
        }
        // Free Will audio route
        if (settings.name == '/free-will-audio') {
          final preset = settings.arguments as Preset?;
          if (preset != null) {
            return MaterialPageRoute(
              builder: (context) => FreeWillAudioScreen(preset: preset),
            );
          }
        }
        // Free Will input route
        if (settings.name == '/free-will-input') {
          final preset = settings.arguments as Preset?;
          if (preset != null && preset.freeWillConfig != null) {
            // Assistant mode → route to assistant input screen
            if (preset.stealthInputMethod == StealthInputMethod.assistant) {
              return MaterialPageRoute(
                builder: (context) => const AssistantInputScreen(),
                settings: settings,
              );
            }
            // Determine input method from stealth setting
            final FreeWillInputMethod inputMethod;
            switch (preset.stealthInputMethod) {
              case StealthInputMethod.tap:
                inputMethod = FreeWillInputMethod.tap;
                break;
              case StealthInputMethod.clockSwipe:
                inputMethod = FreeWillInputMethod.swipe;
                break;
              default:
                inputMethod = FreeWillInputMethod.volume;
            }
            return MaterialPageRoute(
              builder: (context) => FreeWillInputScreen(
                config: preset.freeWillConfig!,
                inputMethod: inputMethod,
                swipePatterns: preset.swipePatterns,
                onComplete: (result, runtimeLabels) {
                  final gameProvider = Provider.of<GameProvider>(context, listen: false);
                  gameProvider.completeFreeWill(result, preset, runtimeLabels: runtimeLabels);
                  navigateAfterPresetComplete(context);
                },
              ),
            );
          }
        }
        // Calculator calibration route
        if (settings.name == '/image-reveal') {
          final args = settings.arguments as Map<String, dynamic>?;
          return MaterialPageRoute(
            builder: (context) => ImageRevealScreen(
              imagePath: args?['imagePath'] as String? ?? '',
              narrativeText: args?['narrativeText'] as String?,
              afterSave: args?['afterSave'] as String? ?? 'black',
            ),
          );
        }
        if (settings.name == '/calculator-calibration') {
          return MaterialPageRoute(
            builder: (context) => const CalculatorCalibrationScreen(),
          );
        }
        // Calculator editor route
        if (settings.name == '/calculator-editor') {
          final path = settings.arguments as String;
          return MaterialPageRoute(
            builder: (context) => CalculatorEditorScreen(imagePath: path),
          );
        }
        // Routine builder route
        if (settings.name == '/routine-builder') {
          return MaterialPageRoute(
            builder: (context) => const RoutineBuilderScreen(),
            settings: settings,
          );
        }
        return null;
      },
    );
  }
}
