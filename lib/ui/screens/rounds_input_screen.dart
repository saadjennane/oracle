import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../app.dart';
import '../../models/models.dart';
import '../../utils/game_provider.dart';
import '../../utils/settings_provider.dart';
import '../../utils/haptic_helper.dart';
import '../theme/app_theme.dart';

class RoundsInputScreen extends StatefulWidget {
  const RoundsInputScreen({super.key});

  @override
  State<RoundsInputScreen> createState() => _RoundsInputScreenState();
}

class _RoundsInputScreenState extends State<RoundsInputScreen> {
  String? _spectatorChoice;
  String? _performerChoice;

  @override
  void initState() {
    super.initState();
    _spectatorChoice = null;
    _performerChoice = null;
  }

  void _resetChoices() {
    setState(() {
      _spectatorChoice = null;
      _performerChoice = null;
    });
  }

  void _playOptionHaptic(List<String> options, String choice) {
    final settings = context.read<SettingsProvider>();
    if (!settings.hapticFeedback) return;
    final index = options.indexOf(choice);
    if (index >= 0) {
      HapticHelper.confirmOption(index, intensity: settings.hapticIntensity);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<GameProvider>(
      builder: (context, provider, child) {
        final session = provider.currentSession;
        if (session == null) {
          return const Scaffold(
            body: Center(child: Text('No active session')),
          );
        }

        final currentRound = provider.currentRound;
        final totalRounds = provider.totalRounds;
        final isPreprogrammed = provider.inputMode == InputMode.preprogrammed;

        return Scaffold(
          backgroundColor: AppTheme.background,
          appBar: AppBar(
            backgroundColor: AppTheme.background,
            title: Text('Round $currentRound of $totalRounds'),
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => _confirmExit(context, provider),
            ),
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Progress indicator
                  _RoundProgressIndicator(
                    currentRound: currentRound,
                    totalRounds: totalRounds,
                  ),
                  const SizedBox(height: 32),

                  // PERFORMER FIRST (only in two-inputs mode)
                  if (!isPreprogrammed) ...[
                    const _SectionLabel(label: 'PERFORMER CHOICE'),
                    const SizedBox(height: 12),
                    _ChoiceGrid(
                      options: provider.options,
                      selectedOption: _performerChoice,
                      onSelected: (choice) {
                        setState(() => _performerChoice = choice);
                        _playOptionHaptic(provider.options, choice);
                      },
                      color: AppTheme.secondary,
                    ),
                    const SizedBox(height: 24),
                  ],

                  // SPECTATOR SECOND
                  const _SectionLabel(label: 'SPECTATOR CHOICE'),
                  const SizedBox(height: 12),
                  _ChoiceGrid(
                    options: provider.options,
                    selectedOption: _spectatorChoice,
                    onSelected: (choice) {
                      setState(() => _spectatorChoice = choice);
                      _playOptionHaptic(provider.options, choice);
                    },
                    color: AppTheme.primary,
                  ),

                  const Spacer(),

                  // Next/Finish button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _canProceed(isPreprogrammed)
                          ? () => _recordAndProceed(context, provider, isPreprogrammed)
                          : null,
                      child: Text(currentRound == totalRounds ? 'Finish' : 'Next Round'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  bool _canProceed(bool isPreprogrammed) {
    if (_spectatorChoice == null) return false;
    if (!isPreprogrammed && _performerChoice == null) return false;
    return true;
  }

  void _recordAndProceed(BuildContext context, GameProvider provider, bool isPreprogrammed) {
    String? performerChoice;
    if (isPreprogrammed) {
      final roundIdx = provider.currentRound - 1;
      performerChoice = provider.currentSession?.getPerformerChoice(roundIdx);
    } else {
      performerChoice = _performerChoice;
    }
    final success = provider.recordChoice(
      spectatorChoice: _spectatorChoice!,
      performerChoice: performerChoice,
    );

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.error ?? 'Failed to record choice')),
      );
      return;
    }

    if (provider.hasAllRounds) {
      navigateAfterPresetComplete(context);
    } else {
      _resetChoices();
      provider.proceedToNextRound();
    }
  }

  void _confirmExit(BuildContext context, GameProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text(
          'Exit Game?',
          style: TextStyle(color: AppTheme.textPrimary),
        ),
        content: const Text(
          'Your progress will be lost.',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              provider.reset();
              Navigator.pop(ctx);
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Exit'),
          ),
        ],
      ),
    );
  }
}

class _RoundProgressIndicator extends StatelessWidget {
  final int currentRound;
  final int totalRounds;

  const _RoundProgressIndicator({
    required this.currentRound,
    required this.totalRounds,
  });

  @override
  Widget build(BuildContext context) {
    // For many rounds, use a compact progress bar
    if (totalRounds > 5) {
      return Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Round $currentRound',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              Text(
                '$currentRound / $totalRounds',
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (currentRound - 1) / totalRounds,
              backgroundColor: AppTheme.surface,
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primary),
              minHeight: 8,
            ),
          ),
        ],
      );
    }

    // For fewer rounds, use circles
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(totalRounds, (index) {
          final roundNumber = index + 1;
          final isCompleted = roundNumber < currentRound;
          final isCurrent = roundNumber == currentRound;

          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 6),
            child: Column(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isCompleted
                        ? AppTheme.secondary
                        : isCurrent
                            ? AppTheme.primary
                            : AppTheme.surface,
                    border: Border.all(
                      color: isCurrent ? AppTheme.primary : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: isCompleted
                        ? const Icon(Icons.check, color: Colors.white, size: 18)
                        : Text(
                            '$roundNumber',
                            style: TextStyle(
                              fontSize: 14,
                              color: isCurrent ? Colors.white : AppTheme.textSecondary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;

  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppTheme.textSecondary,
        letterSpacing: 2,
      ),
    );
  }
}

class _ChoiceGrid extends StatelessWidget {
  final List<String> options;
  final String? selectedOption;
  final ValueChanged<String> onSelected;
  final Color color;

  const _ChoiceGrid({
    required this.options,
    required this.selectedOption,
    required this.onSelected,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: options.map((option) {
        final isSelected = option == selectedOption;
        return GestureDetector(
          onTap: () => onSelected(option),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            decoration: BoxDecoration(
              color: isSelected ? color : AppTheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? color : AppTheme.surfaceLight,
                width: 2,
              ),
            ),
            child: Text(
              option,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : AppTheme.textPrimary,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
