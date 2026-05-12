import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../models/models.dart';
import '../../models/confabulation_preset.dart';
import '../../utils/presets_provider.dart';
import '../../utils/confabulation_provider.dart';
import '../../utils/routine_provider.dart';
import '../../utils/game_provider.dart';
import '../../utils/settings_provider.dart';
import '../../utils/acrostic_provider.dart';
import '../../engine/number_engine.dart';
import '../../services/firebase_service.dart';
import '../theme/app_theme.dart';
import 'acrostic_position_input_screen.dart';

/// Enum for preset categories in the unified list
enum PresetCategory {
  choices,
  duel,
  freeWill,
  confabulation,
  multipleOut,
  number;

  String get displayName {
    switch (this) {
      case PresetCategory.choices:
        return 'Choices';
      case PresetCategory.duel:
        return 'Duel';
      case PresetCategory.freeWill:
        return 'Free Will';
      case PresetCategory.confabulation:
        return 'Confabulation';
      case PresetCategory.multipleOut:
        return 'Multiple Out';
      case PresetCategory.number:
        return 'Number';
    }
  }

  Color get color {
    switch (this) {
      case PresetCategory.choices:
        return AppTheme.multiChoiceColor;
      case PresetCategory.duel:
        return AppTheme.duelColor;
      case PresetCategory.freeWill:
        return AppTheme.freeWillColor;
      case PresetCategory.confabulation:
        return AppTheme.confabulationColor;
      case PresetCategory.multipleOut:
        return AppTheme.multipleOutColor;
      case PresetCategory.number:
        return const Color(0xFFFF6B6B);
    }
  }

  IconData get icon {
    switch (this) {
      case PresetCategory.choices:
        return Icons.list_alt;
      case PresetCategory.duel:
        return Icons.sports_mma;
      case PresetCategory.freeWill:
        return Icons.psychology;
      case PresetCategory.confabulation:
        return Icons.text_fields;
      case PresetCategory.multipleOut:
        return Icons.text_snippet;
      case PresetCategory.number:
        return Icons.calculate;
    }
  }

  String get description {
    switch (this) {
      case PresetCategory.choices:
        return 'Predict spectator choices';
      case PresetCategory.duel:
        return 'Rock-Paper-Scissors style';
      case PresetCategory.freeWill:
        return '3 objects, 3 actions';
      case PresetCategory.confabulation:
        return 'Multi-slot word reveal';
      case PresetCategory.multipleOut:
        return 'Pre-written texts, stealth select';
      case PresetCategory.number:
        return 'Rainman, Birthday, Today';
    }
  }
}

/// Unified preset item that wraps both Preset and ConfabulationPreset
class UnifiedPresetItem {
  final PresetCategory category;
  final Preset? preset;
  final ConfabulationPreset? confabPreset;
  final int sortOrder; // Lower = older, higher = newer

  UnifiedPresetItem.fromPreset(this.preset, {required this.sortOrder})
      : category = preset!.type == PresetType.duel
            ? PresetCategory.duel
            : preset.type == PresetType.freeWill
                ? PresetCategory.freeWill
                : preset.type == PresetType.multipleOut
                    ? PresetCategory.multipleOut
                    : preset.type == PresetType.number
                        ? PresetCategory.number
                        : PresetCategory.choices,
        confabPreset = null;

  UnifiedPresetItem.fromConfabulation(this.confabPreset, {required this.sortOrder})
      : category = PresetCategory.confabulation,
        preset = null;

  String get id => preset?.id ?? confabPreset!.id;
  String get name => preset?.name ?? confabPreset!.name;
  Color get color => category.color;

  /// Primary sort key for the merged home list. Falls back to epoch 0 if
  /// the underlying entity has no createdAt yet (shouldn't happen post-
  /// migration, but defensive).
  DateTime get createdAt =>
      preset?.createdAt ?? confabPreset?.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static bool _autoStartHandled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await context.read<PresetsProvider>().loadPresets();
      if (!mounted) return;
      await context.read<ConfabulationProvider>().loadPresets();
      if (!mounted) return;
      await context.read<RoutineProvider>().loadRoutines();

      if (!mounted) return;
      if (!_autoStartHandled) {
        _autoStartHandled = true;
        _checkAutoStart();
      }
    });
  }

  void _checkAutoStart() {
    final settings = context.read<SettingsProvider>();
    final presetId = settings.autoStartPresetId;
    if (presetId == null) return;

    final presetsProvider = context.read<PresetsProvider>();
    final preset = presetsProvider.presets.where((p) => p.id == presetId).firstOrNull;
    if (preset != null) {
      if (!preset.isPlayable) {
        settings.setAutoStartPresetId(null);
        return;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _playPreset(context, preset);
      });
      return;
    }

    final confabProvider = context.read<ConfabulationProvider>();
    final confab = confabProvider.presets.where((p) => p.id == presetId).firstOrNull;
    if (confab != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _playConfabulation(context, confab);
      });
      return;
    }

    // Stale ID — clear it.
    settings.setAutoStartPresetId(null);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'ORACLE',
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.history, color: AppTheme.textSecondary),
                        onPressed: () => Navigator.pushNamed(context, '/history'),
                      ),
                      IconButton(
                        icon: const Icon(Icons.settings, color: AppTheme.textSecondary),
                        onPressed: () => Navigator.pushNamed(context, '/settings'),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Add Preset + Import Buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _showAddPresetModal(context),
                      icon: const Icon(Icons.add),
                      label: const Text('Add Preset'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 44, height: 44,
                    child: ElevatedButton(
                      onPressed: () => _showImportPresetDialog(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.surface,
                        foregroundColor: AppTheme.textPrimary,
                        padding: EdgeInsets.zero,
                        side: BorderSide(color: AppTheme.primary.withOpacity(0.5)),
                      ),
                      child: const Text('I', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 6),
                  SizedBox(
                    width: 44, height: 44,
                    child: ElevatedButton(
                      onPressed: () => _exportAllPresets(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.surface,
                        foregroundColor: AppTheme.textPrimary,
                        padding: EdgeInsets.zero,
                        side: BorderSide(color: AppTheme.primary.withOpacity(0.5)),
                      ),
                      child: const Text('E', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 6),
                  SizedBox(
                    width: 44, height: 44,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pushNamed(context, '/templates'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.surface,
                        foregroundColor: AppTheme.textPrimary,
                        padding: EdgeInsets.zero,
                        side: BorderSide(color: AppTheme.primary.withOpacity(0.5)),
                      ),
                      child: const Text('T', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Decoy Mode toggle — persistent flag, vivid color when ON.
            // ON: every preset launch routes through the webapp at oass.app/{id}.
            //     If a decoy image is configured (per-preset or global), the page
            //     shows that image full-screen and captures taps/swipes silently.
            //     Without an image, falls back to the standard assistant UI.
            // OFF: no Firebase traffic, the webapp stays idle.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Consumer<SettingsProvider>(
                builder: (ctx, settings, _) {
                  final on = settings.assistantModeEnabled;
                  return SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _toggleAssistantMode(context),
                      icon: Icon(on ? Icons.wifi_tethering : Icons.wifi_tethering_off, size: 18),
                      label: Text(on ? 'Remote Input · ON' : 'Remote Input'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: on ? Colors.orangeAccent.shade700 : AppTheme.surface,
                        foregroundColor: on ? Colors.white : AppTheme.textSecondary,
                        elevation: on ? 4 : 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(color: on ? Colors.transparent : AppTheme.border),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 8),

            // Add Routine button (only if >=2 presets exist)
            Consumer2<PresetsProvider, ConfabulationProvider>(
              builder: (context, presetsProvider, confabProvider, _) {
                final totalPresets = presetsProvider.presets.length + confabProvider.presets.length;
                if (totalPresets < 2) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.pushNamed(context, '/routine-builder'),
                      icon: const Icon(Icons.playlist_play, size: 16),
                      label: const Text('Add Routine'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primary,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        side: BorderSide(color: AppTheme.primary.withOpacity(0.5)),
                      ),
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 12),

            // Unified Preset + Routine List
            Expanded(
              child: Consumer3<PresetsProvider, ConfabulationProvider, RoutineProvider>(
                builder: (context, presetsProvider, confabProvider, routineProvider, child) {
                  if (presetsProvider.isLoading || confabProvider.isLoading) {
                    return const Center(
                      child: CircularProgressIndicator(color: AppTheme.primary),
                    );
                  }

                  final presets = presetsProvider.presets;
                  final confabs = confabProvider.presets;
                  final routines = routineProvider.routines;

                  if (presets.isEmpty && confabs.isEmpty && routines.isEmpty) {
                    return const _EmptyState();
                  }

                  // Merge presets + confabs into a single chronological list
                  // sorted by createdAt ascending (oldest first). Routines
                  // stay anchored at the top — they're compound items and
                  // already user-orderable elsewhere.
                  final mergedItems = <UnifiedPresetItem>[
                    ...presets.map((p) => UnifiedPresetItem.fromPreset(p, sortOrder: 0)),
                    ...confabs.map((c) => UnifiedPresetItem.fromConfabulation(c, sortOrder: 0)),
                  ];
                  mergedItems.sort((a, b) => a.createdAt.compareTo(b.createdAt));

                  return ReorderableListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    proxyDecorator: (child, index, animation) {
                      return Material(
                        color: Colors.transparent,
                        elevation: 4,
                        shadowColor: Colors.black54,
                        borderRadius: BorderRadius.circular(16),
                        child: child,
                      );
                    },
                    onReorder: (oldIndex, newIndex) {
                      // Reorder only applies to the merged-items range
                      // (skip the routines that sit before them).
                      final oldM = oldIndex - routines.length;
                      var newM = newIndex - routines.length;
                      if (oldM < 0 || oldM >= mergedItems.length) return;
                      if (newM < 0) return;
                      // ReorderableListView convention: dropping AFTER the
                      // last slot gives newIndex == length + 1.
                      if (newM > mergedItems.length) newM = mergedItems.length;
                      if (oldM == newM || oldM == newM - 1) return;

                      final moved = mergedItems.removeAt(oldM);
                      if (oldM < newM) newM -= 1;
                      mergedItems.insert(newM, moved);

                      // Compute a new createdAt strictly between the new
                      // neighbours so the persisted sort matches the visual
                      // position. Endpoints get an offset so future moves
                      // still have room.
                      DateTime newCreatedAt;
                      DateTime? before = newM > 0 ? mergedItems[newM - 1].createdAt : null;
                      DateTime? after = newM < mergedItems.length - 1 ? mergedItems[newM + 1].createdAt : null;
                      if (before != null && after != null) {
                        final mid = (before.millisecondsSinceEpoch + after.millisecondsSinceEpoch) ~/ 2;
                        newCreatedAt = DateTime.fromMillisecondsSinceEpoch(mid);
                      } else if (after != null) {
                        newCreatedAt = after.subtract(const Duration(seconds: 1));
                      } else if (before != null) {
                        newCreatedAt = before.add(const Duration(seconds: 1));
                      } else {
                        newCreatedAt = DateTime.now();
                      }

                      if (moved.preset != null) {
                        presetsProvider.setPresetCreatedAt(moved.preset!.id, newCreatedAt);
                      } else if (moved.confabPreset != null) {
                        confabProvider.setPresetCreatedAt(moved.confabPreset!.id, newCreatedAt);
                      }
                    },
                    itemCount: routines.length + mergedItems.length,
                    itemBuilder: (context, index) {
                      // Routines first
                      if (index < routines.length) {
                        final routine = routines[index];
                        return Padding(
                          key: ValueKey('routine_${routine.id}'),
                          padding: const EdgeInsets.only(bottom: 16),
                          child: _RoutineCard(
                            routine: routine,
                            presetsProvider: presetsProvider,
                            confabProvider: confabProvider,
                            onPlay: () => _playRoutine(context, routine),
                            onEdit: () => Navigator.pushNamed(context, '/routine-builder', arguments: routine),
                            onDelete: () => _confirmDeleteRoutine(context, routine),
                          ),
                        );
                      }
                      final adjustedIndex = index - routines.length;
                      final settings = context.read<SettingsProvider>();
                      final item = mergedItems[adjustedIndex];
                      if (item.preset != null) {
                        final isAutoStart = settings.autoStartPresetId == item.preset!.id;
                        return Padding(
                          key: ValueKey(item.preset!.id),
                          padding: const EdgeInsets.only(bottom: 16),
                          child: _PresetCard(
                            preset: item.preset!,
                            category: item.category,
                            isAutoStart: isAutoStart,
                            onPlay: () => _playPreset(context, item.preset!),
                            onEdit: () => _editPreset(context, item.preset!),
                            onDelete: () => _confirmDelete(context, item.preset!),
                            onExport: () => _exportPreset(context, item.preset!),
                            onAutoStartTap: () => _showAutoStartDialog(context, item.preset!, isAutoStart),
                            onPublishTemplate: settings.isTemplatesAdmin
                                ? () => _publishAsTemplate(context, item.preset!)
                                : null,
                          ),
                        );
                      } else {
                        final isAutoStart = settings.autoStartPresetId == item.confabPreset!.id;
                        return Padding(
                          key: ValueKey('confab_${item.confabPreset!.id}'),
                          padding: const EdgeInsets.only(bottom: 16),
                          child: _ConfabulationCard(
                            preset: item.confabPreset!,
                            isAutoStart: isAutoStart,
                            onPlay: () => _playConfabulation(context, item.confabPreset!),
                            onEdit: () => _editConfabulation(context, item.confabPreset!),
                            onDelete: () => _confirmDeleteConfabulation(context, item.confabPreset!),
                            onExport: () => _exportConfabPreset(context, item.confabPreset!),
                            onAutoStartTap: () => _showAutoStartDialogForConfab(context, item.confabPreset!, isAutoStart),
                            onPublishTemplate: settings.isTemplatesAdmin
                                ? () => _publishConfabAsTemplate(context, item.confabPreset!)
                                : null,
                          ),
                        );
                      }
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddPresetModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.textTertiary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'New Preset',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Choose the type of preset to create',
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              _PresetTypeOption(
                category: PresetCategory.choices,
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.pushNamed(context, '/preset');
                },
              ),
              const SizedBox(height: 8),
              _PresetTypeOption(
                category: PresetCategory.duel,
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.pushNamed(context, '/preset', arguments: _createDuelPresetSkeleton());
                },
              ),
              const SizedBox(height: 8),
              _PresetTypeOption(
                category: PresetCategory.freeWill,
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.pushNamed(context, '/preset', arguments: _createFreeWillPresetSkeleton());
                },
              ),
              const SizedBox(height: 8),
              _PresetTypeOption(
                category: PresetCategory.multipleOut,
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.pushNamed(context, '/preset', arguments: _createMultipleOutPresetSkeleton());
                },
              ),
              const SizedBox(height: 8),
              _PresetTypeOption(
                category: PresetCategory.confabulation,
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.pushNamed(context, '/confabulation/editor');
                },
              ),
              const SizedBox(height: 8),
              _PresetTypeOption(
                category: PresetCategory.number,
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.pushNamed(context, '/preset', arguments: _createNumberPresetSkeleton());
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Preset _createDuelPresetSkeleton() {
    return Preset(
      id: '',
      name: '',
      type: PresetType.duel,
      labels: ['Rock', 'Paper', 'Scissors'],
      nbRounds: 3,
      nbOptions: 3,
      inputMode: InputMode.preprogrammed,
      language: Language.french,
      predictionMode: PredictionMode.game,
    );
  }

  Preset _createFreeWillPresetSkeleton() {
    return Preset(
      id: '',
      name: '',
      type: PresetType.freeWill,
      labels: ['Téléphone', 'Clé', 'Pièce'],
      nbRounds: 1,
      nbOptions: 3,
      inputMode: InputMode.twoInputs,
      language: Language.french,
      predictionMode: PredictionMode.game,
      freeWillConfig: FreeWillConfig.defaultConfig(),
    );
  }

  Preset _createMultipleOutPresetSkeleton() {
    return Preset(
      id: '',
      name: '',
      type: PresetType.multipleOut,
      labels: ['Text 1', 'Text 2'],
      nbRounds: 1,
      nbOptions: 2,
      inputMode: InputMode.preprogrammed,
      language: Language.french,
      stealthInputMethod: StealthInputMethod.volume,
      multipleOutTexts: ['', ''],
    );
  }

  void _launchFreeTextMode(BuildContext context) async {
    final settings = context.read<SettingsProvider>();
    // Push free text mode with optional redirect URL
    final sessionData = <String, dynamic>{'state': 'free_text'};
    if (settings.freeTextRedirectUrl.isNotEmpty) {
      sessionData['redirectUrl'] = settings.freeTextRedirectUrl;
    }
    await FirebaseService.pushSession(settings.assistantId, sessionData);
    if (context.mounted) {
      Navigator.pushNamed(context, '/assistant-free-text');
    }
  }

  /// When Assistant Mode is ON, publish a mirror session for this preset
  /// so the webapp shows the options being played. Uses the user's preferred
  /// stealth presentation (buttons / tap / swipe) from Settings.
  Future<void> _maybePushAssistantMirror(BuildContext context, Preset preset) async {
    final settings = context.read<SettingsProvider>();
    if (!settings.assistantModeEnabled) return;

    List<String> options;
    int totalRounds;
    if (preset.type == PresetType.multipleOut) {
      totalRounds = 1;
      final titles = preset.multipleOutTitles;
      final count = preset.multipleOutTexts?.length ?? 0;
      options = List.generate(count, (i) {
        if (titles != null && i < titles.length && titles[i].trim().isNotEmpty) {
          return titles[i];
        }
        return 'Text ${i + 1}';
      });
    } else if (preset.type == PresetType.freeWill && preset.freeWillConfig != null) {
      totalRounds = 2;
      final config = preset.freeWillConfig!;
      if (config.inputMode == FreeWillInputMode.byAction) {
        options = config.objects;
      } else {
        final isFR = preset.language == Language.french;
        options = config.actionOrder.map((a) => isFR ? a.shortNameFR : a.shortNameEN).toList();
      }
    } else if (preset.type == PresetType.number) {
      totalRounds = 1;
      options = const [];
    } else {
      totalRounds = preset.nbRounds;
      options = preset.labels;
    }

    // Per-preset redirect URL takes precedence over the global setting.
    final presetRedirect = preset.assistantRedirectUrl?.trim() ?? '';
    final effectiveRedirect = presetRedirect.isNotEmpty
        ? presetRedirect
        : settings.freeTextRedirectUrl;

    final sessionData = <String, dynamic>{
      'state': 'active',
      'currentPreset': {
        'name': preset.name,
        'type': preset.type.name,
        'options': options,
        'currentRound': 1,
        'totalRounds': totalRounds,
        'inputMode': settings.assistantStealthMode,
      },
      'redirectUrl': effectiveRedirect.isNotEmpty ? effectiveRedirect : null,
    };
    await FirebaseService.pushSession(settings.assistantId, sessionData);
  }

  Future<void> _maybePushConfabAssistantSession(BuildContext context, ConfabulationPreset preset) async {
    final settings = context.read<SettingsProvider>();
    if (!settings.assistantModeEnabled) return;
    final presetRedirect = preset.assistantRedirectUrl?.trim() ?? '';
    final effectiveRedirect = presetRedirect.isNotEmpty
        ? presetRedirect
        : settings.freeTextRedirectUrl;
    final sessionData = <String, dynamic>{'state': 'free_text'};
    if (effectiveRedirect.isNotEmpty) {
      sessionData['redirectUrl'] = effectiveRedirect;
    }
    await FirebaseService.pushSession(settings.assistantId, sessionData);
  }

  Future<void> _toggleAssistantMode(BuildContext context) async {
    final settings = context.read<SettingsProvider>();
    final willBeOn = !settings.assistantModeEnabled;
    await settings.setAssistantModeEnabled(willBeOn);
    // Decoy Mode: idle when no preset is active (no free-text session).
    // Each preset launch pushes its own session (decoy or standard).
    await FirebaseService.clearSession(settings.assistantId);
  }

  Preset _createNumberPresetSkeleton() {
    return Preset(
      id: '',
      name: '',
      type: PresetType.number,
      labels: [],
      nbRounds: 1,
      nbOptions: 0,
      inputMode: InputMode.preprogrammed,
      language: Language.french,
      stealthInputMethod: StealthInputMethod.audio,
      numberMode: NumberMode.rainman,
      numberFormula: '_ * _ + _',
      numberOutputMode: 'calculator',
    );
  }

  Future<void> _playPreset(BuildContext context, Preset preset) async {
    final gameProvider = context.read<GameProvider>();
    final settingsProvider = context.read<SettingsProvider>();

    // If acrostic position is "Input", ask before playing
    if (preset.acrosticPosition == -1) {
      final pos = await showDialog<int>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppTheme.surface,
          title: Text(
            preset.language == Language.french ? 'Position Acrostiche' : 'Acrostic Position',
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16),
          ),
          content: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(6, (i) => ElevatedButton(
              onPressed: () => Navigator.pop(ctx, i + 1),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(50, 50),
              ),
              child: Text('${i + 1}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            )),
          ),
        ),
      );
      if (pos == null) return;
      gameProvider.setAcrosticPosition(pos);
    }

    gameProvider.startGameFromPreset(preset);

    // Decoy Mode ON: route all spectator-input presets through the webapp
    // flow. Number presets have no spectator input, so they keep their
    // dedicated screen. AssistantInputScreen will decide whether to push
    // a decoy session (image configured) or fall back to standard
    // assistant UI (no image).
    if (settingsProvider.assistantModeEnabled && preset.type != PresetType.number) {
      Navigator.pushNamed(context, '/assistant-input', arguments: preset);
      return;
    }

    // When Assistant Mode is ON, publish the preset state so the webapp at
    // oass.app/{id} mirrors what's being played. Cleared after completion.
    await _maybePushAssistantMirror(context, preset);

    // Special handling for Number presets
    if (preset.type == PresetType.number) {
      Navigator.pushNamed(context, '/number-input', arguments: preset);
      return;
    }

    // Special handling for Multiple Out presets
    if (preset.type == PresetType.multipleOut) {
      Navigator.pushNamed(context, '/multiple-out-input', arguments: preset);
      return;
    }

    // Special handling for Free Will presets
    if (preset.type == PresetType.freeWill) {
      if (preset.stealthInputMethod == StealthInputMethod.assistant) {
        Navigator.pushNamed(context, '/assistant-input', arguments: preset);
      } else if (preset.stealthInputMethod == StealthInputMethod.audio) {
        Navigator.pushNamed(context, '/free-will-audio', arguments: preset);
      } else {
        Navigator.pushNamed(context, '/free-will-input', arguments: preset);
      }
      return;
    }

    switch (preset.stealthInputMethod) {
      case StealthInputMethod.volume:
      case StealthInputMethod.tap:
        if (settingsProvider.testModeEnabled) {
          if (preset.stealthInputMethod == StealthInputMethod.volume) {
            Navigator.pushNamed(context, '/stealth');
          } else {
            Navigator.pushNamed(context, '/stealth-tap', arguments: preset);
          }
        } else {
          Navigator.pushNamed(context, '/performance-flow', arguments: preset);
        }
        break;
      case StealthInputMethod.audio:
        Navigator.pushNamed(context, '/audio-input', arguments: preset);
        break;
      case StealthInputMethod.clockSwipe:
        if (preset.type == PresetType.choices || preset.type == PresetType.duel) {
          // Custom swipe patterns — use performance flow (black screen)
          Navigator.pushNamed(context, '/performance-flow', arguments: preset);
        } else {
          // Multiple Out uses standard rounds input
          Navigator.pushNamed(context, '/rounds');
        }
        break;
      case StealthInputMethod.assistant:
        Navigator.pushNamed(context, '/assistant-input', arguments: preset);
        break;
    }
  }

  void _editPreset(BuildContext context, Preset preset) {
    Navigator.pushNamed(context, '/preset', arguments: preset);
  }

  void _confirmDelete(BuildContext context, Preset preset) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Delete Preset?', style: TextStyle(color: AppTheme.textPrimary)),
        content: Text('Are you sure you want to delete "${preset.name}"?',
            style: const TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              context.read<PresetsProvider>().deletePreset(preset.id);
              context.read<RoutineProvider>().removePresetFromRoutines(preset.id);
              Navigator.pop(ctx);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _playRoutine(BuildContext context, Routine routine) async {
    final gameProvider = context.read<GameProvider>();
    final presetsProvider = context.read<PresetsProvider>();

    // Validate all presets still exist
    for (final presetId in routine.inputOrder) {
      if (presetsProvider.getPresetById(presetId) == null) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Some presets in this routine no longer exist')),
        );
        return;
      }
    }

    // Start chain with routine orders
    gameProvider.startChain(
      inputOrder: routine.inputOrder,
      outputOrder: routine.outputOrder,
    );

    // Play the first preset
    final firstPreset = presetsProvider.getPresetById(routine.inputOrder.first)!;
    await _playPreset(context, firstPreset);
  }

  void _confirmDeleteRoutine(BuildContext context, Routine routine) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Delete Routine?', style: TextStyle(color: AppTheme.textPrimary)),
        content: Text('Are you sure you want to delete "${routine.name}"?',
            style: const TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              context.read<RoutineProvider>().deleteRoutine(routine.id);
              Navigator.pop(ctx);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _exportPreset(BuildContext context, Preset preset) {
    final json = jsonEncode(_compactPresetJson(preset.toJson()));
    Clipboard.setData(ClipboardData(text: json));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Preset "${preset.name}" copied to clipboard'),
        backgroundColor: AppTheme.surface,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _publishAsTemplate(BuildContext context, Preset preset) async {
    final settings = context.read<SettingsProvider>();
    if (!settings.isTemplatesAdmin) return;

    final descController = TextEditingController();
    final nameController = TextEditingController(text: preset.name);

    final published = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Publier comme template',
            style: TextStyle(color: AppTheme.textPrimary, fontSize: 18)),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Sera visible par tous les utilisateurs immédiatement.',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              const SizedBox(height: 12),
              TextField(
                controller: nameController,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Nom',
                  labelStyle: const TextStyle(color: AppTheme.textSecondary),
                  filled: true,
                  fillColor: AppTheme.background,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: descController,
                style: const TextStyle(color: AppTheme.textPrimary),
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Description (courte)',
                  labelStyle: const TextStyle(color: AppTheme.textSecondary),
                  filled: true,
                  fillColor: AppTheme.background,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Publier'),
          ),
        ],
      ),
    );

    if (published != true) return;
    if (!context.mounted) return;

    final id = const Uuid().v4();
    final json = preset.toJson();
    json.remove('id');
    final ok = await FirebaseService.publishTemplate(
      id: id,
      name: nameController.text.trim().isEmpty ? preset.name : nameController.text.trim(),
      description: descController.text.trim(),
      presetJson: {'kind': 'preset', ...json},
      adminToken: settings.templatesAdminToken,
    );

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppTheme.surface,
        content: Text(
          ok ? 'Template publié !' : 'Échec de la publication (vérifie ton token admin)',
          style: TextStyle(color: ok ? AppTheme.textPrimary : Colors.red),
        ),
      ),
    );
  }

  /// Strip null entries (and empty maps/lists) from a JSON map. The receiving
  /// `fromJson` already supplies defaults for missing fields, so dropping
  /// them yields a much smaller export without losing fidelity.
  Map<String, dynamic> _compactPresetJson(Map<String, dynamic> json) {
    final out = <String, dynamic>{};
    json.forEach((k, v) {
      if (v == null) return;
      if (v is Map && v.isEmpty) return;
      if (v is List && v.isEmpty) return;
      out[k] = v;
    });
    return out;
  }

  void _exportAllPresets(BuildContext context) {
    final presetsProvider = context.read<PresetsProvider>();
    final confabProvider = context.read<ConfabulationProvider>();
    final presets = presetsProvider.presets;
    final confabs = confabProvider.presets;
    final total = presets.length + confabs.length;
    if (total == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No presets to export'), backgroundColor: AppTheme.surface),
      );
      return;
    }
    // Compact: drop null/empty fields, no indentation. Roughly 60-80%
    // smaller than the pretty version, and import works identically.
    final jsonList = [
      ...presets.map((p) => _compactPresetJson(p.toJson())),
      ...confabs.map((c) => _compactPresetJson(c.toJson())),
    ];
    final json = jsonEncode(jsonList);
    Clipboard.setData(ClipboardData(text: json));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$total presets copied to clipboard'),
        backgroundColor: AppTheme.surface,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showImportPresetDialog(BuildContext context) {
    final controller = TextEditingController();
    String? errorText;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.surface,
          title: const Text('Import Preset', style: TextStyle(color: AppTheme.textPrimary, fontSize: 18)),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Paste a preset JSON (single or array) to import.',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  maxLines: 8,
                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12, fontFamily: 'monospace'),
                  decoration: InputDecoration(
                    hintText: '{"name": "...", "type": "...", ...}',
                    hintStyle: TextStyle(color: AppTheme.textTertiary.withOpacity(0.5), fontSize: 12),
                    errorText: errorText,
                    errorMaxLines: 3,
                    filled: true,
                    fillColor: AppTheme.background,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppTheme.border),
                    ),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  final text = controller.text.trim();
                  if (text.isEmpty) {
                    setDialogState(() => errorText = 'Paste a JSON first');
                    return;
                  }
                  // Sanitize smart quotes
                  var sanitized = text
                      .replaceAll('\u201C', '"')
                      .replaceAll('\u201D', '"')
                      .replaceAll('\u2018', "'")
                      .replaceAll('\u2019', "'");
                  // Auto-wrap multiple JSON objects into an array
                  // Detects "} {" or "}\n{" patterns (two objects pasted without array)
                  if (sanitized.startsWith('{') && !sanitized.startsWith('[')) {
                    final wrapped = sanitized.replaceAllMapped(
                      RegExp(r'\}\s*\{'),
                      (m) => '}, {',
                    );
                    if (wrapped.contains('}, {')) {
                      sanitized = '[$wrapped]';
                    }
                  }
                  final decoded = jsonDecode(sanitized);
                  final presetsProvider = context.read<PresetsProvider>();
                  final confabProvider = context.read<ConfabulationProvider>();

                  // Confabulation presets have these signature fields and
                  // lack a `type` enum value — used to dispatch.
                  bool isConfab(Map<String, dynamic> m) =>
                      m.containsKey('slots') && m.containsKey('textTemplate');

                  Future<void> importOne(Map<String, dynamic> item) async {
                    if (isConfab(item)) {
                      final json = Map<String, dynamic>.from(item);
                      json['id'] = DateTime.now().microsecondsSinceEpoch.toString();
                      await confabProvider.addPreset(ConfabulationPreset.fromJson(json));
                    } else {
                      item.remove('id');
                      await presetsProvider.addPreset(Preset.fromJson(item));
                    }
                  }

                  if (decoded is List) {
                    int count = 0;
                    for (final item in decoded) {
                      if (item is Map<String, dynamic>) {
                        await importOne(item);
                        count++;
                      }
                    }
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('$count presets imported!'),
                        backgroundColor: AppTheme.surface,
                      ),
                    );
                  } else if (decoded is Map<String, dynamic>) {
                    final name = decoded['name'] ?? 'preset';
                    await importOne(decoded);
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Preset "$name" imported!'),
                        backgroundColor: AppTheme.surface,
                      ),
                    );
                  } else {
                    setDialogState(() => errorText = 'JSON must be an object or array');
                  }
                } catch (e) {
                  setDialogState(() => errorText = 'Invalid JSON: $e');
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Import'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _playConfabulation(BuildContext context, ConfabulationPreset preset) async {
    // If the acrostic position is set to "Input" (-1), ask the performer
    // to capture it first via the same stealth input method.
    if (preset.acrosticPosition == -1) {
      final acrostic = context.read<AcrosticProvider>();
      final lang = preset.acrosticLanguage;
      final available = lang != null
          ? acrostic.coveredPositionsForLanguage(lang)
          : acrostic.coveredPositionsForLanguage(acrostic.currentLanguage);
      if (available.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No acrostic positions available for the selected language')),
        );
        return;
      }
      final picked = await Navigator.push<int>(
        context,
        MaterialPageRoute(
          builder: (_) => AcrosticPositionInputScreen(
            inputMethod: preset.inputMethod,
            availablePositions: available,
            onPicked: (pos) => Navigator.pop(context, pos),
          ),
        ),
      );
      if (picked == null) return; // user cancelled
      // Attach the captured position to the run via provider.
      context.read<ConfabulationProvider>().setPendingAcrosticPosition(picked);
    }

    // Decoy Mode ON: route confab through the assistant flow regardless of
    // the preset's input method. The assistant screen will publish a decoy
    // session if a decoy image is configured (per-preset or global).
    final settings = context.read<SettingsProvider>();
    if (settings.assistantModeEnabled) {
      Navigator.pushNamed(context, '/confabulation/assistant', arguments: preset);
      return;
    }

    if (preset.inputMethod == ConfabInputMethod.assistant) {
      Navigator.pushNamed(context, '/confabulation/assistant', arguments: preset);
    } else {
      Navigator.pushNamed(context, '/confabulation/run', arguments: preset);
    }
  }

  void _editConfabulation(BuildContext context, ConfabulationPreset preset) {
    Navigator.pushNamed(context, '/confabulation/editor', arguments: preset);
  }

  void _confirmDeleteConfabulation(BuildContext context, ConfabulationPreset preset) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Delete Confabulation?', style: TextStyle(color: AppTheme.textPrimary)),
        content: Text('Are you sure you want to delete "${preset.name}"?',
            style: const TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              context.read<ConfabulationProvider>().deletePreset(preset.id);
              Navigator.pop(ctx);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showAutoStartDialog(BuildContext context, Preset preset, bool isAutoStart) {
    final settings = context.read<SettingsProvider>();

    if (isAutoStart) {
      // Modal to disable auto-start
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppTheme.surface,
          title: const Text('Disable Auto-Start', style: TextStyle(color: AppTheme.textPrimary)),
          content: Text('Stop launching "${preset.name}" on app start?',
              style: const TextStyle(color: AppTheme.textSecondary)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            TextButton(
              onPressed: () {
                settings.setAutoStartPresetId(null);
                Navigator.pop(ctx);
                setState(() {});
              },
              child: const Text('Disable'),
            ),
          ],
        ),
      );
    } else {
      // Modal to enable auto-start
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppTheme.surface,
          title: const Text('Launch on Start', style: TextStyle(color: AppTheme.textPrimary)),
          content: Text('Launch "${preset.name}" automatically when app opens?',
              style: const TextStyle(color: AppTheme.textSecondary)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            TextButton(
              onPressed: () {
                settings.setAutoStartPresetId(preset.id);
                Navigator.pop(ctx);
                setState(() {});
              },
              child: const Text('Confirm'),
            ),
          ],
        ),
      );
    }
  }

  void _showAutoStartDialogForConfab(BuildContext context, ConfabulationPreset preset, bool isAutoStart) {
    final settings = context.read<SettingsProvider>();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text(isAutoStart ? 'Disable Auto-Start' : 'Launch on Start',
            style: const TextStyle(color: AppTheme.textPrimary)),
        content: Text(
          isAutoStart
              ? 'Stop launching "${preset.name}" on app start?'
              : 'Launch "${preset.name}" automatically when app opens?',
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              settings.setAutoStartPresetId(isAutoStart ? null : preset.id);
              Navigator.pop(ctx);
              setState(() {});
            },
            child: Text(isAutoStart ? 'Disable' : 'Confirm'),
          ),
        ],
      ),
    );
  }

  void _exportConfabPreset(BuildContext context, ConfabulationPreset preset) {
    final json = jsonEncode(_compactPresetJson(preset.toJson()));
    Clipboard.setData(ClipboardData(text: json));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Confabulation "${preset.name}" copied to clipboard'),
        backgroundColor: AppTheme.surface,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _publishConfabAsTemplate(BuildContext context, ConfabulationPreset preset) async {
    final settings = context.read<SettingsProvider>();
    if (!settings.isTemplatesAdmin) return;

    final descController = TextEditingController();
    final nameController = TextEditingController(text: preset.name);

    final published = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Publier comme template',
            style: TextStyle(color: AppTheme.textPrimary, fontSize: 18)),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Sera visible par tous les utilisateurs immédiatement.',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              const SizedBox(height: 12),
              TextField(
                controller: nameController,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Nom',
                  labelStyle: const TextStyle(color: AppTheme.textSecondary),
                  filled: true,
                  fillColor: AppTheme.background,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: descController,
                style: const TextStyle(color: AppTheme.textPrimary),
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Description (courte)',
                  labelStyle: const TextStyle(color: AppTheme.textSecondary),
                  filled: true,
                  fillColor: AppTheme.background,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Publier'),
          ),
        ],
      ),
    );

    if (published != true || !context.mounted) return;

    final id = const Uuid().v4();
    final json = preset.toJson();
    json.remove('id');
    final ok = await FirebaseService.publishTemplate(
      id: id,
      name: nameController.text.trim().isEmpty ? preset.name : nameController.text.trim(),
      description: descController.text.trim(),
      presetJson: {'kind': 'confabulation', ...json},
      adminToken: settings.templatesAdminToken,
    );

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppTheme.surface,
        content: Text(
          ok ? 'Template publié !' : 'Échec de la publication (vérifie ton token admin)',
          style: TextStyle(color: ok ? AppTheme.textPrimary : Colors.red),
        ),
      ),
    );
  }
}

class _PresetTypeOption extends StatelessWidget {
  final PresetCategory category;
  final VoidCallback onTap;

  const _PresetTypeOption({required this.category, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.background,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: category.color.withOpacity(0.3), width: 1),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: category.color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(category.icon, color: category.color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(category.displayName,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                  const SizedBox(height: 2),
                  Text(category.description, style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AppTheme.textTertiary),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.dashboard_customize_outlined, size: 64, color: AppTheme.textTertiary),
          const SizedBox(height: 16),
          Text('No presets yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
          const SizedBox(height: 8),
          Text('Tap "Add Preset" to create your first one',
              style: TextStyle(fontSize: 14, color: AppTheme.textTertiary)),
        ],
      ),
    );
  }
}

class _RoutineCard extends StatelessWidget {
  final Routine routine;
  final PresetsProvider presetsProvider;
  final ConfabulationProvider confabProvider;
  final VoidCallback onPlay;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _RoutineCard({
    required this.routine,
    required this.presetsProvider,
    required this.confabProvider,
    required this.onPlay,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    // Build preset name list
    final presetNames = routine.inputOrder.map((id) {
      final p = presetsProvider.getPresetById(id);
      return p?.name ?? '?';
    }).toList();

    return GestureDetector(
      onTap: onPlay,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.playlist_play, color: AppTheme.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    routine.name,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${routine.inputOrder.length} presets',
                  style: TextStyle(fontSize: 11, color: AppTheme.textTertiary),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: onEdit,
                  child: Icon(Icons.edit, size: 18, color: AppTheme.textTertiary),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: onDelete,
                  child: Icon(Icons.delete_outline, size: 18, color: AppTheme.textTertiary),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: List.generate(presetNames.length, (i) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (i > 0) Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Icon(Icons.chevron_right, size: 14, color: AppTheme.textTertiary),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        presetNames[i],
                        style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                      ),
                    ),
                  ],
                );
              }),
            ),
            if (routine.inputOrder.join(',') != routine.outputOrder.join(',')) ...[
              const SizedBox(height: 4),
              Text(
                'Output order differs from input order',
                style: TextStyle(fontSize: 10, color: AppTheme.textTertiary, fontStyle: FontStyle.italic),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PresetCard extends StatelessWidget {
  final Preset preset;
  final PresetCategory category;
  final bool isAutoStart;
  final VoidCallback onPlay;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onExport;
  final VoidCallback onAutoStartTap;
  final VoidCallback? onPublishTemplate;

  const _PresetCard({
    required this.preset,
    required this.category,
    required this.isAutoStart,
    required this.onPlay,
    required this.onEdit,
    required this.onDelete,
    required this.onExport,
    required this.onAutoStartTap,
    this.onPublishTemplate,
  });

  IconData _getStealthIcon(StealthInputMethod method) {
    switch (method) {
      case StealthInputMethod.assistant:
        return Icons.touch_app;
      case StealthInputMethod.volume:
        return Icons.volume_up;
      case StealthInputMethod.tap:
        return Icons.fingerprint;
      case StealthInputMethod.audio:
        return Icons.mic;
      case StealthInputMethod.clockSwipe:
        return Icons.swipe;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = category.color;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 4,
                  height: 60,
                  decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(preset.name,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: color.withOpacity(0.2), borderRadius: BorderRadius.circular(6)),
                            child: Text(category.displayName,
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: color)),
                          ),
                          // Free Will: show only the 3 object labels + input method.
                          if (preset.type == PresetType.freeWill) ...[
                            if (preset.freeWillConfig != null)
                              _DetailChip(
                                icon: Icons.inventory_2_outlined,
                                label: preset.freeWillConfig!.objects.join(' · '),
                              ),
                            if (preset.stealthInputMethod != StealthInputMethod.assistant)
                              _DetailChip(
                                icon: _getStealthIcon(preset.stealthInputMethod),
                                label: preset.stealthInputMethod == StealthInputMethod.volume ? 'Vol'
                                    : preset.stealthInputMethod == StealthInputMethod.audio ? 'IA'
                                    : preset.stealthInputMethod == StealthInputMethod.clockSwipe ? 'Swipe'
                                    : 'Tap',
                              ),
                          ] else if (preset.type == PresetType.multipleOut) ...[
                            // Multiple Out: number of texts + input method.
                            _DetailChip(
                              icon: Icons.format_list_numbered,
                              label: '${preset.multipleOutTexts?.length ?? 0} texts',
                            ),
                            if (preset.stealthInputMethod != StealthInputMethod.assistant)
                              _DetailChip(
                                icon: _getStealthIcon(preset.stealthInputMethod),
                                label: preset.stealthInputMethod == StealthInputMethod.volume ? 'Vol'
                                    : preset.stealthInputMethod == StealthInputMethod.audio ? 'IA'
                                    : preset.stealthInputMethod == StealthInputMethod.clockSwipe ? 'Swipe'
                                    : 'Tap',
                              ),
                          ] else if (preset.type == PresetType.number) ...[
                            // Number: sub-mode + output + input method.
                            if (preset.numberMode != null)
                              _DetailChip(
                                icon: preset.numberMode == NumberMode.rainman ? Icons.functions
                                    : preset.numberMode == NumberMode.birthday ? Icons.cake_outlined
                                    : Icons.today_outlined,
                                label: preset.numberMode == NumberMode.rainman ? 'Rainman'
                                    : preset.numberMode == NumberMode.birthday ? 'Birthday'
                                    : 'Today',
                              ),
                            _DetailChip(
                              icon: (preset.numberOutputMode ?? 'calculator') == 'calculator' ? Icons.calculate : Icons.note,
                              label: (preset.numberOutputMode ?? 'calculator') == 'calculator' ? 'Calculator' : 'Notes',
                            ),
                            if (preset.stealthInputMethod != StealthInputMethod.assistant)
                              _DetailChip(
                                icon: _getStealthIcon(preset.stealthInputMethod),
                                label: preset.stealthInputMethod == StealthInputMethod.audio ? 'IA' : 'Swipe',
                              ),
                          ] else ...[
                            _DetailChip(icon: Icons.repeat, label: '${preset.nbRounds}r'),
                            _DetailChip(icon: Icons.list, label: '${preset.nbOptions} opt'),
                            if (preset.stealthInputMethod != StealthInputMethod.assistant)
                              _DetailChip(
                                icon: _getStealthIcon(preset.stealthInputMethod),
                                label: preset.stealthInputMethod == StealthInputMethod.volume ? 'Vol'
                                    : preset.stealthInputMethod == StealthInputMethod.audio ? 'IA'
                                    : preset.stealthInputMethod == StealthInputMethod.clockSwipe ? 'Swipe'
                                    : 'Tap',
                              ),
                            // Performer sequence / twoInputs chips only for Choices / Duel.
                            if ((preset.type == PresetType.choices || preset.type == PresetType.duel)
                                && preset.inputMode == InputMode.preprogrammed
                                && preset.performerSequence != null
                                && preset.performerSequence!.isNotEmpty)
                              _DetailChip(
                                icon: Icons.playlist_play,
                                label: 'PS:${preset.performerSequence!.map((i) => i < preset.labels.length ? preset.labels[i][0].toUpperCase() : '?').join('')}',
                              ),
                            if ((preset.type == PresetType.choices || preset.type == PresetType.duel)
                                && preset.inputMode == InputMode.twoInputs)
                              _DetailChip(icon: Icons.swap_vert, label: '2 inputs'),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                if (preset.isPlayable)
                  Container(
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: color.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 4))],
                    ),
                    child: IconButton(
                      onPressed: onPlay,
                      icon: const Icon(Icons.play_arrow, color: Colors.white, size: 28),
                      padding: const EdgeInsets.all(10),
                    ),
                  )
                else
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade700,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_outlined, color: Colors.white70, size: 24),
                      padding: const EdgeInsets.all(10),
                      tooltip: 'Compléter la configuration',
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                    onPressed: preset.isPlayable ? onAutoStartTap : null,
                    icon: Icon(
                      isAutoStart ? Icons.rocket_launch : Icons.rocket_launch_outlined,
                      color: !preset.isPlayable
                          ? Colors.grey.shade800
                          : isAutoStart
                              ? Colors.orange.shade300
                              : Colors.grey.shade500,
                      size: 20,
                    ),
                    padding: const EdgeInsets.all(8),
                    tooltip: preset.isPlayable
                        ? (isAutoStart
                            ? 'Désactiver le démarrage auto'
                            : 'Lancer ce preset au démarrage de l\'app')
                        : 'Preset incomplet — terminez la configuration pour l\'activer',
                    constraints: const BoxConstraints()),
                IconButton(
                    onPressed: onExport,
                    icon: Icon(Icons.copy_outlined, color: AppTheme.textTertiary, size: 20),
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints()),
                if (onPublishTemplate != null)
                  IconButton(
                      onPressed: onPublishTemplate,
                      icon: Icon(Icons.cloud_upload_outlined, color: AppTheme.primary, size: 20),
                      tooltip: 'Publier comme template',
                      padding: const EdgeInsets.all(8),
                      constraints: const BoxConstraints()),
                IconButton(
                    onPressed: onEdit,
                    icon: Icon(Icons.edit_outlined, color: AppTheme.textSecondary, size: 20),
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints()),
                IconButton(
                    onPressed: onDelete,
                    icon: Icon(Icons.delete_outline, color: Colors.red.withOpacity(0.7), size: 20),
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints()),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Short chips listing the standalone API/acrostic variables used inside a
/// Confabulation template. Returns an empty list when the template has none.
List<Widget> _confabVariableChips(String template) {
  // (substring marker → short label, icon)
  const catalog = <(String, String, IconData)>[
    ('ACROSTIC_URL', 'Acrostic URL', Icons.link),
    ('ACROSTIC_INJECT', 'Acrostic Inject', Icons.bolt),
    ('ACROSTIC_ELIPS_ARTIST', 'Acrostic Artist', Icons.music_note),
    ('ACROSTIC_ELIPS_SONG', 'Acrostic Song', Icons.music_note),
    ('ACROSTIC_ELIPS_WORD', 'Acrostic Word', Icons.music_note),
    ('INJECT', 'Inject', Icons.bolt),
    ('ELIPS_ARTIST', 'Elips Artist', Icons.music_note),
    ('ELIPS_SONG', 'Elips Song', Icons.music_note),
    ('ELIPS_WORD', 'Elips Word', Icons.music_note),
    ('HIGHSCORE_SCORE', 'Score', Icons.emoji_events),
    ('HIGHSCORE_RANKING', 'Ranking', Icons.emoji_events),
    ('AITransformInject', 'AI Inject', Icons.auto_awesome),
    ('AITransformElipsArtist', 'AI Artist', Icons.auto_awesome),
    ('AITransformElipsSong', 'AI Song', Icons.auto_awesome),
    ('AITransformElipsWord', 'AI Word', Icons.auto_awesome),
  ];
  final added = <String>{};
  final chips = <Widget>[];
  for (final (marker, label, icon) in catalog) {
    if (added.contains(label)) continue;
    if (template.contains('(($marker))')) {
      chips.add(_DetailChip(icon: icon, label: label));
      added.add(label);
    }
  }
  return chips;
}

IconData _confabInputIcon(ConfabInputMethod method) {
  switch (method) {
    case ConfabInputMethod.volume:
      return Icons.volume_up;
    case ConfabInputMethod.tap:
      return Icons.fingerprint;
    case ConfabInputMethod.audio:
      return Icons.mic;
    case ConfabInputMethod.clockSwipe:
      return Icons.swipe;
    case ConfabInputMethod.assistant:
      return Icons.people;
  }
}

class _DetailChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _DetailChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey.shade400),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
      ],
    );
  }
}

class _ConfabulationCard extends StatelessWidget {
  final ConfabulationPreset preset;
  final bool isAutoStart;
  final VoidCallback onPlay;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onExport;
  final VoidCallback onAutoStartTap;
  final VoidCallback? onPublishTemplate;

  const _ConfabulationCard({
    required this.preset,
    required this.isAutoStart,
    required this.onPlay,
    required this.onEdit,
    required this.onDelete,
    required this.onExport,
    required this.onAutoStartTap,
    this.onPublishTemplate,
  });

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.confabulationColor;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 4,
                  height: 60,
                  decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(preset.name,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: color.withOpacity(0.2), borderRadius: BorderRadius.circular(6)),
                            child: Text('Confabulation',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: color)),
                          ),
                          if (preset.slots.isNotEmpty)
                            _DetailChip(icon: Icons.layers, label: '${preset.slots.length} slots'),
                          ..._confabVariableChips(preset.textTemplate),
                          if (preset.slots.isNotEmpty)
                            _DetailChip(
                              icon: _confabInputIcon(preset.inputMethod),
                              label: preset.inputMethod.displayName,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: color.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 4))],
                  ),
                  child: IconButton(
                    onPressed: onPlay,
                    icon: const Icon(Icons.play_arrow, color: Colors.white, size: 28),
                    padding: const EdgeInsets.all(10),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                    onPressed: onAutoStartTap,
                    icon: Icon(
                      isAutoStart ? Icons.rocket_launch : Icons.rocket_launch_outlined,
                      color: isAutoStart ? Colors.orange.shade300 : Colors.grey.shade500,
                      size: 20,
                    ),
                    padding: const EdgeInsets.all(8),
                    tooltip: isAutoStart
                        ? 'Désactiver le démarrage auto'
                        : 'Lancer ce preset au démarrage',
                    constraints: const BoxConstraints()),
                IconButton(
                    onPressed: onExport,
                    icon: Icon(Icons.copy_outlined, color: AppTheme.textTertiary, size: 20),
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints()),
                if (onPublishTemplate != null)
                  IconButton(
                      onPressed: onPublishTemplate,
                      icon: Icon(Icons.cloud_upload_outlined, color: AppTheme.primary, size: 20),
                      tooltip: 'Publier comme template',
                      padding: const EdgeInsets.all(8),
                      constraints: const BoxConstraints()),
                IconButton(
                    onPressed: onEdit,
                    icon: Icon(Icons.edit_outlined, color: AppTheme.textSecondary, size: 20),
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints()),
                IconButton(
                    onPressed: onDelete,
                    icon: Icon(Icons.delete_outline, color: Colors.red.withOpacity(0.7), size: 20),
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints()),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
