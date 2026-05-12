import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../theme/app_theme.dart';

/// Per-preset Auto-copy toggle. When ON, the generated text is copied to the
/// clipboard and the optional iOS Shortcut launches.
class OutputOverrideSection extends StatelessWidget {
  final Language locale;
  final bool? autoCopyOverride;
  final String? shortcutNameOverride;
  final TextEditingController shortcutController;
  final ValueChanged<bool> onToggleCustom;
  final ValueChanged<bool> onAutoCopyChanged;
  final ValueChanged<String> onShortcutChanged;

  const OutputOverrideSection({
    super.key,
    required this.locale,
    required this.autoCopyOverride,
    required this.shortcutNameOverride,
    required this.shortcutController,
    required this.onToggleCustom,
    required this.onAutoCopyChanged,
    required this.onShortcutChanged,
  });

  bool get _enabled => autoCopyOverride == true;

  @override
  Widget build(BuildContext context) {
    final isFR = locale == Language.french;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: _enabled ? AppTheme.primary.withValues(alpha: 0.4) : AppTheme.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isFR ? 'Copie automatique' : 'Auto-copy',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isFR
                          ? 'Copie le texte généré et lance le raccourci iOS si défini'
                          : 'Copies the generated text and launches the iOS Shortcut if set',
                      style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _enabled,
                onChanged: (v) {
                  onAutoCopyChanged(v);
                  // Keep the legacy onToggleCustom hook working: any non-null
                  // override means "this preset has been touched".
                  onToggleCustom(v);
                },
                activeColor: AppTheme.primary,
              ),
            ],
          ),
          if (_enabled) ...[
            const SizedBox(height: 12),
            Text(
              isFR ? 'Nom du raccourci (vide = aucun)' : 'Shortcut name (empty = none)',
              style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 4),
            TextField(
              controller: shortcutController,
              style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary),
              decoration: InputDecoration(
                hintText: isFR ? 'Ex: Ma prédiction' : 'Ex: My prediction',
                hintStyle: const TextStyle(fontSize: 12, color: AppTheme.textTertiary),
                filled: true,
                fillColor: AppTheme.background,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppTheme.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppTheme.border),
                ),
              ),
              onChanged: onShortcutChanged,
            ),
          ],
        ],
      ),
    );
  }
}
