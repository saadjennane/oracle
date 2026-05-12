import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/models.dart';
import '../theme/app_theme.dart';
import '../../engine/bank_validator.dart';
import 'bank_import_modal.dart';

/// Widget pour éditer les banques preprogrammed
class PreprogrammedBankEditor extends StatefulWidget {
  final Map<String, Map<String, String>>? initialBanks;
  final List<String> labels;
  final List<int>? performerSequence;
  final int nbRounds;
  final Language language;
  final ValueChanged<Map<String, Map<String, String>>?> onChanged;

  const PreprogrammedBankEditor({
    super.key,
    this.initialBanks,
    required this.labels,
    this.performerSequence,
    required this.nbRounds,
    required this.language,
    required this.onChanged,
  });

  @override
  State<PreprogrammedBankEditor> createState() => _PreprogrammedBankEditorState();
}

class _PreprogrammedBankEditorState extends State<PreprogrammedBankEditor> {
  late Map<String, Map<String, String>> _banks;
  late Map<String, TextEditingController> _controllers;
  bool _isExpanded = true;

  String get _performerKey {
    if (widget.performerSequence == null || widget.performerSequence!.isEmpty) {
      return '';
    }
    // Clé position-based: option[0] → "1", option[1] → "2"
    return widget.performerSequence!.map((idx) => idx == 0 ? '1' : '2').join();
  }

  /// Clé performer avec initiales dynamiques pour affichage
  String get _performerKeyDisplay {
    if (widget.performerSequence == null || widget.performerSequence!.isEmpty) {
      return '';
    }
    final (char1, char2) = _labelChars;
    return widget.performerSequence!.map((idx) => idx == 0 ? char1 : char2).join();
  }

  /// Retourne (char1, char2) pour identifier les labels
  /// Si même première lettre → utilise suffixe (G1, G2)
  (String, String) get _labelChars {
    if (widget.labels.length < 2) return ('1', '2');

    final l1 = widget.labels[0];
    final l2 = widget.labels[1];

    if (l1.isEmpty || l2.isEmpty) return ('1', '2');

    final c1 = l1[0].toUpperCase();
    final c2 = l2[0].toUpperCase();

    // Si même première lettre → ajouter suffixe
    if (c1 == c2) {
      return ('${c1}1', '${c2}2');
    }
    return (c1, c2);
  }

  List<String> get _spectatorKeys {
    // Générer toutes les 2^n combinaisons position-based pour 1-5 rounds
    if (widget.nbRounds < 1 || widget.nbRounds > 5) return [];
    if (widget.labels.length < 2) return [];

    final total = 1 << widget.nbRounds; // 2^nbRounds
    final List<String> keys = [];

    for (int i = 0; i < total; i++) {
      final StringBuffer key = StringBuffer();
      for (int bit = widget.nbRounds - 1; bit >= 0; bit--) {
        key.write((i >> bit) & 1 == 0 ? '1' : '2');
      }
      keys.add(key.toString());
    }

    return keys;
  }

  @override
  void initState() {
    super.initState();
    _banks = Map.from(widget.initialBanks ?? {});
    _migrateLegacyKeys();
    _controllers = {};
    _initControllers();
    // Collapsed only if all texts are filled
    final bank = _banks[_performerKey] ?? {};
    final allFilled = _spectatorKeys.isNotEmpty &&
        _spectatorKeys.every((k) => bank[k]?.trim().isNotEmpty == true);
    _isExpanded = !allFilled;
  }

  /// Migre les clés legacy (lettres-based: "DDG", "G1G2G1") vers position-based ("112")
  void _migrateLegacyKeys() {
    if (_banks.isEmpty) return;

    final newBanks = <String, Map<String, String>>{};
    bool didMigrate = false;

    for (final entry in _banks.entries) {
      final performerKey = entry.key;
      final spectatorMap = entry.value;

      // Détecter si la clé est déjà position-based (ne contient que 1 et 2)
      final isPositionBased = performerKey.split('').every((c) => c == '1' || c == '2');

      if (isPositionBased) {
        // Migrer les sous-clés spectateur si nécessaire
        final newSpectatorMap = <String, String>{};
        for (final se in spectatorMap.entries) {
          final isSpectatorPositionBased = se.key.split('').every((c) => c == '1' || c == '2');
          if (isSpectatorPositionBased) {
            newSpectatorMap[se.key] = se.value;
          } else {
            newSpectatorMap[_migrateKey(se.key)] = se.value;
            didMigrate = true;
          }
        }
        newBanks[performerKey] = newSpectatorMap;
      } else {
        // Migrer performer key et toutes les sous-clés
        final newPerformerKey = _migrateKey(performerKey);
        final newSpectatorMap = <String, String>{};
        for (final se in spectatorMap.entries) {
          newSpectatorMap[_migrateKey(se.key)] = se.value;
        }
        newBanks[newPerformerKey] = newSpectatorMap;
        didMigrate = true;
      }
    }

    if (didMigrate) {
      _banks = newBanks;
      // Propager la migration vers le preset (deferred to avoid setState during build)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onChanged(_banks.isEmpty ? null : _banks);
      });
    }
  }

  /// Convertit une clé legacy en position-based en utilisant les labels actuels
  String _migrateKey(String key) {
    if (widget.labels.length < 2) return key;

    final (char1, char2) = _labelChars;
    final buf = StringBuffer();

    // Parser la clé en tokens (char1 ou char2, potentiellement multi-caractères)
    int i = 0;
    while (i < key.length) {
      if (key.substring(i).startsWith(char1)) {
        buf.write('1');
        i += char1.length;
      } else if (key.substring(i).startsWith(char2)) {
        buf.write('2');
        i += char2.length;
      } else {
        // Fallback: essayer par première lettre du label
        final c = key[i].toUpperCase();
        if (c == widget.labels[0][0].toUpperCase()) {
          buf.write('1');
        } else {
          buf.write('2');
        }
        i++;
      }
    }

    return buf.toString();
  }

  void _initControllers() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _controllers.clear();

    final performerKey = _performerKey;
    if (performerKey.isEmpty) return;

    final bank = _banks[performerKey] ?? {};
    for (final spectatorKey in _spectatorKeys) {
      _controllers[spectatorKey] = TextEditingController(
        text: bank[spectatorKey] ?? '',
      );
    }
  }

  @override
  void didUpdateWidget(PreprogrammedBankEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.performerSequence != widget.performerSequence ||
        oldWidget.labels != widget.labels ||
        oldWidget.nbRounds != widget.nbRounds) {
      _initControllers();
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _onTextChanged(String spectatorKey, String text) {
    final performerKey = _performerKey;
    if (performerKey.isEmpty) return;

    if (!_banks.containsKey(performerKey)) {
      _banks[performerKey] = {};
    }

    if (text.trim().isEmpty) {
      _banks[performerKey]!.remove(spectatorKey);
      if (_banks[performerKey]!.isEmpty) {
        _banks.remove(performerKey);
      }
    } else {
      _banks[performerKey]![spectatorKey] = text;
    }

    widget.onChanged(_banks.isEmpty ? null : _banks);
  }

  void _applyExactBank(Map<String, String> generatedBank, String styleName) {
    final performerKey = _performerKey;
    // Les starter banks utilisent déjà des clés "1"/"2" — pas de conversion nécessaire

    setState(() {
      _banks[performerKey] = Map.from(generatedBank);
      for (final entry in generatedBank.entries) {
        _controllers[entry.key]?.text = entry.value;
      }
    });

    widget.onChanged(_banks);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(widget.language == Language.french
            ? 'Textes $styleName générés'
            : '$styleName texts generated'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _openImportModal() {
    BankImportModal.show(
      context: context,
      bankType: BankType.choicesExactSequence,
      language: widget.language,
      rounds: widget.nbRounds,
      options: widget.labels,
      performerKey: _performerKeyDisplay,
      performerSequenceIndices: widget.performerSequence,
      onImport: (entries, meta) {
        _applyExactBank(
          entries,
          'Import',
        );
      },
    );
  }

  void _copyAsJson() {
    final performerKey = _performerKey;
    if (performerKey.isEmpty) return;

    final bank = _banks[performerKey];
    if (bank == null || bank.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.language == Language.french
              ? 'Aucun texte à copier'
              : 'No text to copy'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final json = {
      'performerKey': performerKey,
      'entries': bank,
    };

    Clipboard.setData(ClipboardData(text: const JsonEncoder.withIndent('  ').convert(json)));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(widget.language == Language.french
            ? 'JSON copié dans le presse-papiers'
            : 'JSON copied to clipboard'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _clearAll() {
    final performerKey = _performerKey;
    if (performerKey.isEmpty) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text(
          widget.language == Language.french
              ? 'Effacer tous les textes ?'
              : 'Clear all texts?',
          style: const TextStyle(color: AppTheme.textPrimary),
        ),
        content: Text(
          widget.language == Language.french
              ? 'Cette action effacera tous les textes de cette banque.'
              : 'This will clear all texts in this bank.',
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(widget.language == Language.french ? 'Annuler' : 'Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _banks.remove(performerKey);
                for (final controller in _controllers.values) {
                  controller.clear();
                }
              });
              widget.onChanged(_banks.isEmpty ? null : _banks);
            },
            child: Text(
              widget.language == Language.french ? 'Effacer' : 'Clear',
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  /// Compute hits/misses between spectator key and performer key
  Widget _buildHitsMissesChip(String spectatorKey) {
    final perfKey = _performerKey;
    if (perfKey.isEmpty || spectatorKey.length != perfKey.length) {
      return const SizedBox.shrink();
    }

    int hits = 0;
    for (int i = 0; i < spectatorKey.length; i++) {
      if (spectatorKey[i] == perfKey[i]) hits++;
    }
    final misses = spectatorKey.length - hits;
    final isFR = widget.language == Language.french;
    final allHits = misses == 0;
    final allMisses = hits == 0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(5),
          ),
          child: Text(
            '$hits ✓',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.green,
            ),
          ),
        ),
        const SizedBox(width: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(5),
          ),
          child: Text(
            '$misses ✗',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.red,
            ),
          ),
        ),
      ],
    );
  }

  String _formatSpectatorKey(String key) {
    if (widget.labels.length < 2) return key;

    // Clés position-based: "1" → labels[0], "2" → labels[1]
    final parts = key.split('').map((c) {
      return c == '1' ? widget.labels[0] : widget.labels[1];
    }).toList();
    return parts.join(' → ');
  }

  @override
  Widget build(BuildContext context) {
    final performerKey = _performerKey;

    // Ne pas afficher si pas de séquence performer ou rounds hors limites (1-5)
    if (performerKey.isEmpty || widget.nbRounds < 1 || widget.nbRounds > 5) {
      return const SizedBox.shrink();
    }

    final hasContent = _banks[performerKey]?.values.any((t) => t.trim().isNotEmpty) ?? false;

    return Container(
      margin: const EdgeInsets.only(top: 16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header avec expand/collapse
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: AppTheme.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.language == Language.french
                              ? 'Banque Preprogrammed'
                              : 'Preprogrammed Bank',
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$_performerKeyDisplay (${widget.nbRounds} rounds)',
                          style: const TextStyle(
                            color: AppTheme.accent,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (hasContent) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${_banks[performerKey]?.values.where((t) => t.trim().isNotEmpty).length ?? 0} / ${_spectatorKeys.length}',
                        style: const TextStyle(
                          color: Colors.green,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          if (_isExpanded) ...[
            const Divider(height: 1, color: AppTheme.border),

            // Action buttons — Import / Export / Clear
            Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _ActionButton(
                    icon: Icons.auto_fix_high,
                    label: 'IA Import',
                    onTap: _openImportModal,
                    color: Colors.teal,
                  ),
                  _ActionButton(
                    icon: Icons.copy,
                    label: widget.language == Language.french ? 'Copier JSON' : 'Copy JSON',
                    onTap: _copyAsJson,
                  ),
                  if (hasContent)
                    _ActionButton(
                      icon: Icons.clear_all,
                      label: widget.language == Language.french ? 'Effacer' : 'Clear',
                      onTap: _clearAll,
                      color: Colors.red,
                    ),
                ],
              ),
            ),

            const Divider(height: 1, color: AppTheme.border),

            // Text fields for each spectator combination
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _spectatorKeys.length,
              separatorBuilder: (_, __) => const Divider(height: 1, color: AppTheme.border),
              itemBuilder: (context, index) {
                final spectatorKey = _spectatorKeys[index];
                final controller = _controllers[spectatorKey];
                if (controller == null) return const SizedBox.shrink();

                return Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.accent.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              spectatorKey,
                              style: const TextStyle(
                                color: AppTheme.accent,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _formatSpectatorKey(spectatorKey),
                              style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 12,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          _buildHitsMissesChip(spectatorKey),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: controller,
                        textCapitalization: TextCapitalization.sentences,
                        maxLines: 4,
                        minLines: 2,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 14,
                        ),
                        decoration: InputDecoration(
                          hintText: index == 0
                              ? (widget.language == Language.french
                                  ? 'Ex: Tu vas faire ${_formatSpectatorKey(spectatorKey)}.\nJe le savais avant même que tu commences...'
                                  : 'Ex: You will choose ${_formatSpectatorKey(spectatorKey)}.\nI knew it before you even started...')
                              : (widget.language == Language.french
                                  ? 'Texte pour ${_formatSpectatorKey(spectatorKey)}...'
                                  : 'Text for ${_formatSpectatorKey(spectatorKey)}...'),
                          hintMaxLines: 3,
                          hintStyle: TextStyle(
                            color: AppTheme.textSecondary.withValues(alpha: 0.5),
                          ),
                          filled: true,
                          fillColor: AppTheme.background,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: AppTheme.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: AppTheme.border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: AppTheme.accent),
                          ),
                          contentPadding: const EdgeInsets.all(12),
                        ),
                        onChanged: (value) => _onTextChanged(spectatorKey, value),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.person, size: 12, color: AppTheme.textSecondary),
                          const SizedBox(width: 4),
                          Text(
                            widget.language == Language.french
                                ? 'Performer : $_performerKeyDisplay'
                                : 'Performer: $_performerKeyDisplay',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.textSecondary,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? AppTheme.textSecondary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: effectiveColor.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: effectiveColor),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: effectiveColor,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
