import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../utils/game_provider.dart';
import '../theme/app_theme.dart';

class SetupScreen extends StatelessWidget {
  const SetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<GameProvider>(
      builder: (context, provider, child) {
        final gameType = provider.selectedGameType;
        if (gameType == null) {
          return const Scaffold(
            body: Center(child: Text('No game type selected')),
          );
        }

        return Scaffold(
          backgroundColor: AppTheme.background,
          appBar: AppBar(
            backgroundColor: AppTheme.background,
            title: Text(gameType.displayName),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios),
              onPressed: () {
                provider.reset();
                Navigator.pop(context);
              },
            ),
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Input Mode Selection
                  _SectionTitle(title: 'Input Mode'),
                  const SizedBox(height: 12),
                  _InputModeSelector(
                    selectedMode: provider.inputMode,
                    onChanged: provider.updateInputMode,
                  ),
                  const SizedBox(height: 24),

                  // Option Labels
                  _SectionTitle(title: 'Option Labels'),
                  const SizedBox(height: 12),
                  ...List.generate(
                    gameType.optionCount,
                    (index) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _OptionTextField(
                        label: 'Option ${index + 1}',
                        value: provider.options[index],
                        onChanged: (value) => provider.updateOption(index, value),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Duel-specific settings
                  if (gameType == GameType.duel) ...[
                    _SectionTitle(title: 'Player Names'),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _OptionTextField(
                            label: 'Performer',
                            value: provider.player1Name,
                            onChanged: (value) =>
                                provider.updatePlayerNames(value, provider.player2Name),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _OptionTextField(
                            label: 'Spectator',
                            value: provider.player2Name,
                            onChanged: (value) =>
                                provider.updatePlayerNames(provider.player1Name, value),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _ToggleRow(
                      title: 'First-person narration',
                      subtitle: 'Use "I" and "you" instead of names',
                      value: provider.firstPerson,
                      onChanged: provider.updateFirstPerson,
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Preprogrammed Sequence (Mode A)
                  if (provider.inputMode == InputMode.preprogrammed) ...[
                    const SizedBox(height: 12),
                    _SectionTitle(title: 'Your Sequence (3 rounds)'),
                    const SizedBox(height: 12),
                    ...List.generate(
                      3,
                      (index) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _PreprogrammedDropdown(
                          roundNumber: index + 1,
                          options: provider.options,
                          selectedValue: provider.preprogrammedSequence[index],
                          onChanged: (value) =>
                              provider.updatePreprogrammedChoice(index, value),
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 32),

                  // Start Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        if (provider.startGame()) {
                          Navigator.pushNamed(context, '/rounds');
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(provider.error ?? 'Failed to start game'),
                            ),
                          );
                        }
                      },
                      child: const Text('Start Game'),
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
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppTheme.textSecondary,
        letterSpacing: 1,
      ),
    );
  }
}

class _InputModeSelector extends StatelessWidget {
  final InputMode selectedMode;
  final ValueChanged<InputMode> onChanged;

  const _InputModeSelector({
    required this.selectedMode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: InputMode.values.map((mode) {
          final isSelected = mode == selectedMode;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(mode),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(
                      mode.displayName,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.white : AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      mode == InputMode.preprogrammed ? 'Pre-enter sequence' : 'Both inputs',
                      style: TextStyle(
                        fontSize: 11,
                        color: isSelected
                            ? Colors.white.withOpacity(0.8)
                            : AppTheme.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _OptionTextField extends StatefulWidget {
  final String label;
  final String value;
  final ValueChanged<String> onChanged;

  const _OptionTextField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  State<_OptionTextField> createState() => _OptionTextFieldState();
}

class _OptionTextFieldState extends State<_OptionTextField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(covariant _OptionTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && _controller.text != widget.value) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      onChanged: widget.onChanged,
      decoration: InputDecoration(
        labelText: widget.label,
        labelStyle: const TextStyle(color: AppTheme.textSecondary),
      ),
      style: const TextStyle(color: AppTheme.textPrimary),
    );
  }
}

class _PreprogrammedDropdown extends StatelessWidget {
  final int roundNumber;
  final List<String> options;
  final String selectedValue;
  final ValueChanged<String> onChanged;

  const _PreprogrammedDropdown({
    required this.roundNumber,
    required this.options,
    required this.selectedValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Text(
            'Round $roundNumber:',
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: selectedValue,
                isExpanded: true,
                dropdownColor: AppTheme.surface,
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16),
                items: options.map((option) {
                  return DropdownMenuItem(
                    value: option,
                    child: Text(option),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) onChanged(value);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppTheme.textTertiary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppTheme.primary,
          ),
        ],
      ),
    );
  }
}
