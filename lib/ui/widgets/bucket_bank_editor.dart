import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/models.dart';
import '../theme/app_theme.dart';
import '../../engine/bank_validator.dart';
import 'bank_import_modal.dart';

/// Widget pour éditer les banques bucket (hits/misses) pour CHOICES
/// Mode bucket: R+1 clés (H0..HR) avec placeholder {spectatorSequenceLabeled}
class BucketBankEditor extends StatefulWidget {
  final Map<String, String>? initialBank;
  final int nbRounds;
  final Language language;
  final ValueChanged<Map<String, String>?> onChanged;

  const BucketBankEditor({
    super.key,
    this.initialBank,
    required this.nbRounds,
    required this.language,
    required this.onChanged,
  });

  @override
  State<BucketBankEditor> createState() => _BucketBankEditorState();
}

class _BucketBankEditorState extends State<BucketBankEditor> {
  late Map<String, String> _bank;
  late Map<String, TextEditingController> _controllers;
  bool _isExpanded = false;

  /// Liste des clés bucket: H0, H1, ..., HR
  List<String> get _bucketKeys {
    if (widget.nbRounds < 1 || widget.nbRounds > 10) return [];
    return List.generate(widget.nbRounds + 1, (i) => 'H$i');
  }

  @override
  void initState() {
    super.initState();
    _bank = Map.from(widget.initialBank ?? {});
    _controllers = {};
    _initControllers();
  }

  void _initControllers() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _controllers.clear();

    for (final bucketKey in _bucketKeys) {
      _controllers[bucketKey] = TextEditingController(
        text: _bank[bucketKey] ?? '',
      );
    }
  }

  @override
  void didUpdateWidget(BucketBankEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.nbRounds != widget.nbRounds) {
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

  void _onTextChanged(String bucketKey, String text) {
    if (text.trim().isEmpty) {
      _bank.remove(bucketKey);
    } else {
      _bank[bucketKey] = text;
    }
    widget.onChanged(_bank.isEmpty ? null : _bank);
  }

  void _applyGeneratedBank(Map<String, String> generatedBank, String styleName) {
    setState(() {
      _bank = Map.from(generatedBank);
      for (final entry in generatedBank.entries) {
        _controllers[entry.key]?.text = entry.value;
      }
    });

    widget.onChanged(_bank);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(widget.language == Language.french
            ? 'Textes Bucket $styleName générés (${widget.nbRounds + 1} buckets)'
            : 'Bucket $styleName texts generated (${widget.nbRounds + 1} buckets)'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _openImportModal() {
    BankImportModal.show(
      context: context,
      bankType: BankType.choicesBucket,
      language: widget.language,
      rounds: widget.nbRounds,
      onImport: (entries, meta) {
        _applyGeneratedBank(entries, 'Import');
      },
    );
  }

  void _copyAsJson() {
    if (_bank.isEmpty) {
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
      'mode': 'bucket_hits_misses',
      'rounds': widget.nbRounds,
      'bucketCount': widget.nbRounds + 1,
      'entries': _bank,
    };

    Clipboard.setData(
        ClipboardData(text: const JsonEncoder.withIndent('  ').convert(json)));

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
              ? 'Cette action effacera tous les textes bucket.'
              : 'This will clear all bucket texts.',
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:
                Text(widget.language == Language.french ? 'Annuler' : 'Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _bank.clear();
                for (final controller in _controllers.values) {
                  controller.clear();
                }
              });
              widget.onChanged(null);
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

  String _formatBucketKey(String key) {
    // H0 -> "0 hit (all miss)", H1 -> "1 hit", etc.
    final hits = int.tryParse(key.substring(1)) ?? 0;
    final misses = widget.nbRounds - hits;

    if (hits == 0) {
      return widget.language == Language.french
          ? '0 hit ($misses miss)'
          : '0 hit ($misses miss)';
    }
    if (misses == 0) {
      return widget.language == Language.french
          ? '$hits hit (perfect)'
          : '$hits hit (perfect)';
    }
    return '$hits hit, $misses miss';
  }

  @override
  Widget build(BuildContext context) {
    // Ne pas afficher si rounds hors limites (1-10)
    if (widget.nbRounds < 1 || widget.nbRounds > 10) {
      return const SizedBox.shrink();
    }

    final hasContent = _bank.values.any((t) => t.trim().isNotEmpty);

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
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(12)),
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
                              ? 'Banque Bucket (Hits/Misses)'
                              : 'Bucket Bank (Hits/Misses)',
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${widget.nbRounds} rounds → ${widget.nbRounds + 1} buckets',
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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${_bank.values.where((t) => t.trim().isNotEmpty).length} / ${_bucketKeys.length}',
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
                      label: widget.language == Language.french
                          ? 'Effacer'
                          : 'Clear',
                      onTap: _clearAll,
                      color: Colors.red,
                    ),
                ],
              ),
            ),

            const Divider(height: 1, color: AppTheme.border),

            // Text fields for each bucket
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _bucketKeys.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, color: AppTheme.border),
              itemBuilder: (context, index) {
                final bucketKey = _bucketKeys[index];
                final controller = _controllers[bucketKey];
                if (controller == null) return const SizedBox.shrink();

                final hits = index;
                final misses = widget.nbRounds - hits;

                // Color coding based on hits
                Color keyColor;
                if (hits == widget.nbRounds) {
                  keyColor = Colors.green; // Perfect
                } else if (hits == 0) {
                  keyColor = Colors.red; // All miss
                } else {
                  keyColor = AppTheme.accent; // Partial
                }

                return Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: keyColor.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              bucketKey,
                              style: TextStyle(
                                color: keyColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _formatBucketKey(bucketKey),
                              style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          // Visual indicator
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              for (int i = 0; i < hits; i++)
                                Container(
                                  width: 8,
                                  height: 8,
                                  margin:
                                      const EdgeInsets.symmetric(horizontal: 1),
                                  decoration: const BoxDecoration(
                                    color: Colors.green,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              for (int i = 0; i < misses; i++)
                                Container(
                                  width: 8,
                                  height: 8,
                                  margin:
                                      const EdgeInsets.symmetric(horizontal: 1),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withValues(alpha: 0.5),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: controller,
                        textCapitalization: TextCapitalization.sentences,
                        maxLines: 5,
                        minLines: 3,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 14,
                        ),
                        decoration: InputDecoration(
                          hintText: index == 0
                              ? (widget.language == Language.french
                                  ? 'Ex: Tu as fait $misses erreur${misses > 1 ? 's' : ''}.\nMais même ces erreurs, je les avais prévues...'
                                  : 'Ex: You made $misses mistake${misses > 1 ? 's' : ''}.\nBut even those mistakes, I predicted them...')
                              : (widget.language == Language.french
                                  ? 'Texte pour $hits hit, $misses miss...'
                                  : 'Text for $hits hit, $misses miss...'),
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
                            borderSide: BorderSide(color: keyColor),
                          ),
                          contentPadding: const EdgeInsets.all(12),
                        ),
                        onChanged: (value) => _onTextChanged(bucketKey, value),
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
