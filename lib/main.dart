import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'app.dart';
import 'data/data.dart';
import 'services/icloud_kv_service.dart';
import 'services/icloud_sync_service.dart';
import 'utils/game_provider.dart';
import 'utils/history_provider.dart';
import 'utils/settings_provider.dart';
import 'utils/presets_provider.dart';
import 'utils/reveal_provider.dart';
import 'utils/acrostic_provider.dart';
import 'utils/confabulation_provider.dart';
import 'utils/routine_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock orientation to portrait for consistent UX
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  // Set system UI style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF1C1C1E),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Initialize storage with error handling
  LocalStorage? storage;
  SessionRepository? sessionRepository;
  PresetRepository? presetRepository;
  ConfabulationRepository? confabulationRepository;
  RoutineRepository? routineRepository;

  try {
    storage = LocalStorage();
    await storage.init();
    sessionRepository = SessionRepository(storage);
    presetRepository = PresetRepository(storage);
    confabulationRepository = ConfabulationRepository(storage);
    routineRepository = RoutineRepository(storage);
  } catch (e) {
    // If storage fails, create with defaults
    debugPrint('Storage init error: $e');
  }

  // Create providers that others depend on
  final settingsProvider = SettingsProvider(storage);
  final acrosticProvider = AcrosticProvider(storage);

  // Pull + merge iCloud data at startup (best-effort; non-blocking on failure).
  if (storage != null) {
    try {
      await ICloudSyncService.pullAndMerge(storage);
    } catch (e) {
      debugPrint('iCloud pull error: $e');
    }
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(
          value: settingsProvider,
        ),
        ChangeNotifierProvider(
          create: (_) => GameProvider(
            sessionRepository,
            settingsProvider: settingsProvider,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => HistoryProvider(sessionRepository),
        ),
        ChangeNotifierProvider(
          create: (_) => PresetsProvider(presetRepository),
        ),
        ChangeNotifierProvider(
          create: (_) => RevealProvider(storage),
        ),
        ChangeNotifierProvider(
          create: (_) => ConfabulationProvider(
            confabulationRepository,
            settingsProvider: settingsProvider,
            acrosticProvider: acrosticProvider,
          ),
        ),
        ChangeNotifierProvider.value(
          value: acrosticProvider,
        ),
        ChangeNotifierProvider(
          create: (_) => RoutineProvider(routineRepository),
        ),
      ],
      child: const OracleApp(),
    ),
  );

  // Listen for external iCloud changes (another device pushed) and re-merge.
  if (storage != null) {
    ICloudKVService.onExternalChange.listen((_) async {
      try {
        await ICloudSyncService.pullAndMerge(storage!);
      } catch (_) {}
    });
  }
}
