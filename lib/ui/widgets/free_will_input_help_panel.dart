import 'package:flutter/material.dart';
import '../../inputs/free_will_input_mapping.dart';
import '../../inputs/free_will_input_state.dart';
import '../../models/stealth_input_method.dart';
import '../theme/app_theme.dart';

/// Dynamic help panel showing input mappings for Free Will mode
/// Uses FreeWillInputMapping as single source of truth
class FreeWillInputHelpPanel extends StatelessWidget {
  final FreeWillInputMethod inputMethod;
  final FreeWillPhaseState? currentPhase;
  final bool compact;

  const FreeWillInputHelpPanel({
    super.key,
    required this.inputMethod,
    this.currentPhase,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final mapping = FreeWillInputMapping.forMethod(inputMethod);

    return Container(
      padding: EdgeInsets.all(compact ? 12 : 16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.primary.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          _buildHeader(mapping),
          SizedBox(height: compact ? 12 : 16),

          // Phase 1: Choice
          _buildPhaseSection(
            title: 'Phase 1 — Choix',
            subtitle: '2 inputs distincts',
            isActive: currentPhase == FreeWillPhaseState.capturing,
            children: mapping.choiceMapping.map((m) => _buildMappingRow(
              left: m.eventName,
              right: '→ ${m.value}',
              description: m.eventDescription,
            )).toList(),
          ),
          SizedBox(height: compact ? 8 : 12),

          // Deduction rule
          _buildRuleBox(
            icon: Icons.auto_awesome,
            text: mapping.deductionRule,
          ),
          SizedBox(height: compact ? 8 : 12),

          // Phase 2: Swaps
          _buildPhaseSection(
            title: 'Phase 2 — Swaps',
            subtitle: 'illimités',
            isActive: currentPhase == FreeWillPhaseState.swapping,
            children: mapping.swapMapping.map((m) => _buildMappingRow(
              left: 'Input ${m.triggerValue}',
              right: '→ ${_formatSwapType(m.swapType)}',
              description: m.description,
            )).toList(),
          ),
          SizedBox(height: compact ? 8 : 12),

          // Lock & Reveal
          _buildLockRevealSection(mapping),
        ],
      ),
    );
  }

  Widget _buildHeader(FreeWillInputMapping mapping) {
    final methodName = mapping.method == FreeWillInputMethod.volume
        ? 'Volume Buttons'
        : 'Tap Zones';
    final methodIcon = mapping.method == FreeWillInputMethod.volume
        ? Icons.volume_up
        : Icons.touch_app;

    return Row(
      children: [
        Icon(
          methodIcon,
          color: AppTheme.primary,
          size: compact ? 20 : 24,
        ),
        const SizedBox(width: 8),
        Text(
          methodName,
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: compact ? 16 : 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildPhaseSection({
    required String title,
    required String subtitle,
    required bool isActive,
    required List<Widget> children,
  }) {
    return Container(
      padding: EdgeInsets.all(compact ? 8 : 12),
      decoration: BoxDecoration(
        color: isActive
            ? AppTheme.primary.withOpacity(0.15)
            : Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: isActive
            ? Border.all(color: AppTheme.primary.withOpacity(0.5))
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: TextStyle(
                  color: isActive ? AppTheme.primary : AppTheme.textPrimary,
                  fontSize: compact ? 13 : 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '($subtitle)',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: compact ? 11 : 12,
                ),
              ),
              if (isActive) ...[
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'ACTIVE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: compact ? 9 : 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
          SizedBox(height: compact ? 6 : 8),
          ...children,
        ],
      ),
    );
  }

  Widget _buildMappingRow({
    required String left,
    required String right,
    String? description,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: compact ? 2 : 3),
      child: Row(
        children: [
          Container(
            width: compact ? 60 : 70,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              left,
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: compact ? 11 : 12,
                fontWeight: FontWeight.w500,
                fontFamily: 'monospace',
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            right,
            style: TextStyle(
              color: AppTheme.accent,
              fontSize: compact ? 11 : 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (description != null && !compact) ...[
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                description,
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 11,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRuleBox({
    required IconData icon,
    required String text,
  }) {
    return Container(
      padding: EdgeInsets.all(compact ? 8 : 10),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.amber.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: Colors.amber,
            size: compact ? 14 : 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.amber.shade200,
                fontSize: compact ? 11 : 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLockRevealSection(FreeWillInputMapping mapping) {
    final isLocked = currentPhase == FreeWillPhaseState.locked;
    final isRevealed = currentPhase == FreeWillPhaseState.revealed;

    return Container(
      padding: EdgeInsets.all(compact ? 8 : 12),
      decoration: BoxDecoration(
        color: isLocked || isRevealed
            ? Colors.green.withOpacity(0.15)
            : Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: isLocked || isRevealed
            ? Border.all(color: Colors.green.withOpacity(0.5))
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Lock & Reveal',
            style: TextStyle(
              color: isLocked || isRevealed ? Colors.green : AppTheme.textPrimary,
              fontSize: compact ? 13 : 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: compact ? 6 : 8),

          // Lock action
          _buildActionRow(
            icon: Icons.lock_outline,
            action: mapping.lockAction.action,
            description: mapping.lockAction.description,
            isActive: currentPhase == FreeWillPhaseState.swapping,
            isDone: isLocked || isRevealed,
          ),
          SizedBox(height: compact ? 4 : 6),

          // Reveal action
          _buildActionRow(
            icon: Icons.visibility,
            action: mapping.revealAction.action,
            description: mapping.revealAction.description,
            isActive: isLocked,
            isDone: isRevealed,
          ),
        ],
      ),
    );
  }

  Widget _buildActionRow({
    required IconData icon,
    required String action,
    required String description,
    required bool isActive,
    required bool isDone,
  }) {
    final color = isDone
        ? Colors.green
        : isActive
            ? AppTheme.accent
            : AppTheme.textSecondary;

    return Row(
      children: [
        Icon(
          isDone ? Icons.check_circle : icon,
          color: color,
          size: compact ? 14 : 16,
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            action,
            style: TextStyle(
              color: color,
              fontSize: compact ? 10 : 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            description,
            style: TextStyle(
              color: isDone ? Colors.green.shade300 : AppTheme.textSecondary,
              fontSize: compact ? 10 : 11,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  String _formatSwapType(FreeWillSwapType swap) {
    final (a, b) = swap.swappedObjects;
    return 'Keep ${swap.keptObject}, swap $a↔$b';
  }
}

/// Compact inline version for smaller spaces
class FreeWillInputHelpInline extends StatelessWidget {
  final FreeWillInputMethod inputMethod;

  const FreeWillInputHelpInline({
    super.key,
    required this.inputMethod,
  });

  @override
  Widget build(BuildContext context) {
    final mapping = FreeWillInputMapping.forMethod(inputMethod);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Choice phase summary
        _buildLine(
          'Choix:',
          mapping.choiceMapping.map((m) => '${m.eventName}=${m.value}').join(', '),
        ),
        const SizedBox(height: 4),

        // Swap phase summary
        _buildLine(
          'Swaps:',
          '1→keep1, 2→keep2, 3→keep3',
        ),
        const SizedBox(height: 4),

        // Lock/Reveal summary
        _buildLine(
          'Lock:',
          mapping.lockAction.action,
        ),
        _buildLine(
          'Reveal:',
          mapping.revealAction.action,
        ),
      ],
    );
  }

  Widget _buildLine(String label, String value) {
    return Row(
      children: [
        SizedBox(
          width: 50,
          child: Text(
            label,
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 11,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 11,
              fontFamily: 'monospace',
            ),
          ),
        ),
      ],
    );
  }
}
