import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../models/confabulation_preset.dart';
import '../../engine/confabulation_engine.dart';
import '../../services/firebase_service.dart';
import '../../utils/confabulation_provider.dart';
import '../../utils/settings_provider.dart';
import '../theme/app_theme.dart';

/// Confabulation assistant screen — slot-by-slot input via Firebase webapp.
class ConfabulationAssistantScreen extends StatefulWidget {
  const ConfabulationAssistantScreen({super.key});

  @override
  State<ConfabulationAssistantScreen> createState() => _ConfabulationAssistantScreenState();
}

class _ConfabulationAssistantScreenState extends State<ConfabulationAssistantScreen> {
  StreamSubscription<Map<String, dynamic>?>? _inputSubscription;
  ConfabulationPreset? _preset;
  bool _isInitialized = false;
  String? _statusMessage;
  List<String> _slotOrder = [];
  int _currentSlotIndex = 0;
  bool _decoyActive = false;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initialize());
  }

  Future<void> _initialize() async {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is! ConfabulationPreset) {
      Navigator.pop(context);
      return;
    }

    _preset = args;
    final settings = context.read<SettingsProvider>();
    final provider = context.read<ConfabulationProvider>();
    final assistantId = settings.assistantId;

    // Start the run in provider
    provider.startRun(_preset!);

    // Get slot order from template
    _slotOrder = ConfabulationEngine.getSlotOrderInTemplate(_preset!.textTemplate);

    // Resolve effective decoy template: per-preset > global default.
    final perPresetTplId = _preset!.decoyTemplateId?.trim() ?? '';
    final effectiveTplId = perPresetTplId.isNotEmpty ? perPresetTplId : settings.defaultDecoyTemplateId;
    final decoyTpl = settings.decoyTemplateById(effectiveTplId);

    if (decoyTpl != null && _slotOrder.isNotEmpty) {
      _decoyActive = true;
      // DECOY mode: single push covering all slots. optionCount = first
      // slot's option count (mismatches clamp on the app side).
      final firstSlot = _preset!.getSlotById(_slotOrder.first);
      final optionCount = firstSlot?.options.length ?? 2;
      final perPresetRedirect = _preset!.assistantRedirectUrl?.trim() ?? '';
      final redirect = perPresetRedirect.isNotEmpty
          ? perPresetRedirect
          : settings.decoyRedirectUrl;
      final inputType = _preset!.decoyInputType ?? 'tap';
      await FirebaseService.pushDecoySession(
        assistantId: assistantId,
        template: decoyTpl,
        inputType: inputType,
        optionCount: optionCount,
        expectedInputs: _slotOrder.length,
        redirectUrl: redirect,
        showIndicator: settings.decoyShowIndicator,
      );
    } else {
      // No decoy: fall back to per-slot button mirror.
      await _pushCurrentSlot(assistantId);
    }

    // Start polling for input
    _inputSubscription = FirebaseService.pollInput(assistantId).listen(_onInputReceived);

    setState(() {
      _isInitialized = true;
      _statusMessage = 'Waiting for assistant...';
    });
  }

  Future<void> _pushCurrentSlot(String assistantId) async {
    if (_currentSlotIndex >= _slotOrder.length) return;

    final slotId = _slotOrder[_currentSlotIndex];
    final slot = _preset!.getSlotById(slotId);
    if (slot == null) return;

    await FirebaseService.pushSession(assistantId, {
      'state': 'active',
      'currentPreset': {
        'name': _preset!.name,
        'type': 'confabulation',
        'options': slot.options,
        'currentRound': _currentSlotIndex + 1,
        'totalRounds': _slotOrder.length,
        'inputMode': 'buttons',
        'slotName': slot.label,
      },
    });
  }

  void _onInputReceived(Map<String, dynamic>? input) {
    if (input == null || _preset == null) return;

    final type = input['type'] as String?;
    final value = input['value'];

    if (type == 'selection' && value is int) {
      _handleSelection(value);
    }
  }

  Future<void> _handleSelection(int optionIndex) async {
    final provider = context.read<ConfabulationProvider>();
    final settings = context.read<SettingsProvider>();

    // Clear input
    await FirebaseService.clearInput(settings.assistantId);

    // Clamp to current slot's option range — needed in decoy mode where the
    // webapp lays out a fixed zone count that may exceed the current slot's
    // actual options.
    final currentSlot = _preset!.getSlotById(_slotOrder[_currentSlotIndex]);
    final maxIdx = (currentSlot?.options.length ?? 1) - 1;
    final clampedIdx = optionIndex.clamp(0, maxIdx);

    // Select option in provider
    provider.selectOption(clampedIdx);

    _currentSlotIndex++;

    if (_currentSlotIndex >= _slotOrder.length) {
      // All slots done — navigate to result
      await FirebaseService.clearSession(settings.assistantId);
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/confabulation/result');
      }
    } else if (!_decoyActive) {
      // Standard assistant flow: push next slot's options for the webapp.
      // In decoy mode we leave the session as-is — the webapp counts inputs
      // locally and we don't need to re-render anything.
      final slot = _preset!.getSlotById(_slotOrder[_currentSlotIndex]);
      setState(() {
        _statusMessage = 'Slot ${_currentSlotIndex + 1}/${_slotOrder.length}: ${slot?.label ?? "?"}';
      });
      await _pushCurrentSlot(settings.assistantId);
    } else {
      final slot = _preset!.getSlotById(_slotOrder[_currentSlotIndex]);
      setState(() {
        _statusMessage = 'Slot ${_currentSlotIndex + 1}/${_slotOrder.length}: ${slot?.label ?? "?"}';
      });
    }
  }

  @override
  void dispose() {
    _inputSubscription?.cancel();
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Scaffold(
        backgroundColor: AppTheme.background,
        body: Center(child: CircularProgressIndicator(color: AppTheme.primary)),
      );
    }

    final currentSlotId = _currentSlotIndex < _slotOrder.length ? _slotOrder[_currentSlotIndex] : null;
    final currentSlot = currentSlotId != null ? _preset!.getSlotById(currentSlotId) : null;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(_preset?.name ?? 'Confabulation'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            final settings = context.read<SettingsProvider>();
            FirebaseService.clearSession(settings.assistantId);
            Navigator.pop(context);
          },
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Progress
              Text(
                'Slot ${_currentSlotIndex + 1} / ${_slotOrder.length}',
                style: TextStyle(color: AppTheme.textTertiary, fontSize: 13),
              ),
              const SizedBox(height: 8),

              // Current slot name
              if (currentSlot != null)
                Text(
                  currentSlot.label,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              const SizedBox(height: 8),

              // Options count
              if (currentSlot != null)
                Text(
                  '${currentSlot.options.length} options',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                ),
              const SizedBox(height: 24),

              // Waiting indicator
              const CircularProgressIndicator(
                color: AppTheme.confabulationColor,
                strokeWidth: 2,
              ),
              const SizedBox(height: 16),

              Text(
                _statusMessage ?? 'Waiting...',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
              ),

              const SizedBox(height: 32),

              // Progress bar
              LinearProgressIndicator(
                value: _slotOrder.isEmpty ? 0 : _currentSlotIndex / _slotOrder.length,
                backgroundColor: AppTheme.surface,
                color: AppTheme.confabulationColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
