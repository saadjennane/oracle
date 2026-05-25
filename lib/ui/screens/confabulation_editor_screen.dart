import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../models/confabulation_preset.dart';
import '../../engine/confabulation_engine.dart';
import '../../utils/confabulation_provider.dart';
import '../../utils/settings_provider.dart';
import '../../utils/acrostic_provider.dart';
import '../../services/external_api_service.dart';
import '../../services/cloudinary_service.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/models.dart' show Language;
import '../theme/app_theme.dart';
import '../widgets/output_override_section.dart';

class ConfabulationEditorScreen extends StatefulWidget {
  const ConfabulationEditorScreen({super.key});

  @override
  State<ConfabulationEditorScreen> createState() => _ConfabulationEditorScreenState();
}

class _ConfabulationEditorScreenState extends State<ConfabulationEditorScreen> {
  late TextEditingController _nameController;
  late TextEditingController _templateController;

  ConfabInputMethod _inputMethod = ConfabInputMethod.volume;
  List<ConfabSlot> _slots = [];
  late TextEditingController _audioStartController;
  late TextEditingController _audioStopController;

  bool _isEditing = false;
  String? _editingId;
  Map<String, String?> _errors = {};

  // Audio locale
  String _audioLocale = 'fr_FR';

  // Acrostic settings
  String? _acrosticLanguage;
  int _acrosticPosition = -1; // -1=input at runtime, 1-6=fixed (Auto removed)

  // AI Transform prompts
  late TextEditingController _injectTransformController;
  late TextEditingController _elipsArtistTransformController;
  late TextEditingController _elipsSongTransformController;
  late TextEditingController _elipsWordTransformController;
  final TextEditingController _assistantRedirectUrlController = TextEditingController();
  String? _decoyTemplateId;
  String _decoyInputType = 'tap';

  // Per-preset overrides for global auto-copy + shortcut.
  // null = inherit global setting.
  bool? _autoCopyOverride;
  String? _shortcutNameOverride;
  final TextEditingController _shortcutNameOverrideController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _templateController = TextEditingController();
    _audioStartController = TextEditingController();
    _audioStopController = TextEditingController();
    _injectTransformController = TextEditingController();
    _elipsArtistTransformController = TextEditingController();
    _elipsSongTransformController = TextEditingController();
    _elipsWordTransformController = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is ConfabulationPreset && !_isEditing) {
      _loadPreset(args);
    }
  }

  void _loadPreset(ConfabulationPreset preset) {
    setState(() {
      _isEditing = true;
      _editingId = preset.id;
      _nameController.text = preset.name;
      _templateController.text = _convertTokensToDisplay(preset.textTemplate, preset.slots);
      _inputMethod = preset.inputMethod;
      _slots = List.from(preset.slots);
      _audioStartController.text = preset.audioStartSentence ?? '';
      _audioStopController.text = preset.audioStopSentence ?? '';
      _audioLocale = preset.audioLocale ?? 'fr_FR';
      _acrosticLanguage = preset.acrosticLanguage;
      // Auto (0) is deprecated. Migrate legacy presets to Input (-1) so the
      // UI always shows a valid selection. The user can pick a fixed
      // position (1-6) afterwards if they prefer.
      _acrosticPosition = preset.acrosticPosition == 0 ? -1 : preset.acrosticPosition;
      _injectTransformController.text = preset.injectTransformPrompt ?? '';
      _assistantRedirectUrlController.text = preset.assistantRedirectUrl ?? '';
      _decoyTemplateId = preset.decoyTemplateId;
      _decoyInputType = preset.decoyInputType ?? 'tap';
      _elipsArtistTransformController.text = preset.elipsArtistTransformPrompt ?? '';
      _elipsSongTransformController.text = preset.elipsSongTransformPrompt ?? '';
      _elipsWordTransformController.text = preset.elipsWordTransformPrompt ?? '';
      _autoCopyOverride = preset.autoCopyOverride;
      _shortcutNameOverride = preset.shortcutNameOverride;
      _shortcutNameOverrideController.text = preset.shortcutNameOverride ?? '';
    });
  }

  /// Convert {{slot:id}} tokens to {{SlotName}} for display
  String _convertTokensToDisplay(String template, List<ConfabSlot> slots) {
    String result = template;
    for (final slot in slots) {
      result = result.replaceAll('{{slot:${slot.id}}}', '{{${slot.label}}}');
    }
    return result;
  }

  /// Convert {{SlotName}} display tokens back to {{slot:id}} for storage
  String _convertDisplayToTokens(String displayText) {
    String result = displayText;
    for (final slot in _slots) {
      result = result.replaceAll('{{${slot.label}}}', '{{slot:${slot.id}}}');
    }
    return result;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _templateController.dispose();
    _injectTransformController.dispose();
    _assistantRedirectUrlController.dispose();
    _elipsArtistTransformController.dispose();
    _elipsSongTransformController.dispose();
    _elipsWordTransformController.dispose();
    super.dispose();
  }

  Future<void> _testTransform(String prompt, String type) async {
    if (prompt.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a prompt first')),
      );
      return;
    }

    final settings = context.read<SettingsProvider>();
    final apiKey = settings.openaiApiKey;
    if (apiKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Set OpenAI API Key in Settings')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Testing...'), duration: Duration(seconds: 1)),
    );

    final Map<String, String> vars;
    switch (type) {
      case 'inject':
        vars = {'value': 'Paris'};
        break;
      case 'elips_artist':
        vars = {'value': 'Daft Punk'};
        break;
      case 'elips_song':
        vars = {'value': 'Get Lucky'};
        break;
      case 'elips_word':
        vars = {'value': 'music'};
        break;
      default:
        vars = {'value': 'test'};
    }

    final result = await ExternalApiService.transformWithPrompt(
      prompt: prompt,
      openaiApiKey: apiKey,
      variables: vars,
    );

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text('Transform Result', style: TextStyle(color: AppTheme.textPrimary, fontSize: 16)),
        content: Text(
          result ?? 'Error: no response',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
        ],
      ),
    );
  }

  void _showAddSlotModal() {
    _showSlotModal(null);
  }

  void _showEditSlotModal(ConfabSlot slot) {
    _showSlotModal(slot);
  }

  Future<void> _showSlotActions(ConfabSlot slot) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit, color: AppTheme.textPrimary),
              title: const Text('Edit', style: TextStyle(color: AppTheme.textPrimary)),
              onTap: () => Navigator.pop(ctx, 'edit'),
            ),
            ListTile(
              leading: const Icon(Icons.copy, color: AppTheme.textPrimary),
              title: const Text('Duplicate', style: TextStyle(color: AppTheme.textPrimary)),
              onTap: () => Navigator.pop(ctx, 'duplicate'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
              title: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
              onTap: () => Navigator.pop(ctx, 'delete'),
            ),
            ListTile(
              leading: const Icon(Icons.close, color: AppTheme.textSecondary),
              title: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
              onTap: () => Navigator.pop(ctx, 'cancel'),
            ),
          ],
        ),
      ),
    );

    if (!mounted || action == null || action == 'cancel') return;
    if (action == 'edit') {
      _showEditSlotModal(slot);
      return;
    }
    if (action == 'duplicate') {
      _duplicateSlot(slot);
      return;
    }
    if (action == 'delete') {
      _confirmDeleteSlot(slot);
    }
  }

  String _nextDuplicatedSlotLabel(String originalLabel) {
    final base = originalLabel.trim();
    int n = 2;
    final existing = _slots.map((s) => s.label.toLowerCase()).toSet();
    while (existing.contains('$base $n'.toLowerCase())) {
      n++;
    }
    return '$base $n';
  }

  void _duplicateSlot(ConfabSlot slot) {
    final duplicated = ConfabSlot(
      id: 'slot_${DateTime.now().millisecondsSinceEpoch}',
      label: _nextDuplicatedSlotLabel(slot.label),
      options: List<String>.from(slot.options),
    );
    setState(() {
      _slots.add(duplicated);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Slot duplicated')),
    );
  }

  Future<void> _confirmDeleteSlot(ConfabSlot slot) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Delete slot?', style: TextStyle(color: AppTheme.textPrimary)),
        content: Text(
          'This will remove "${slot.label}" from slots and from the template tags.',
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (ok == true) {
      _deleteSlot(slot);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Slot deleted')),
      );
    }
  }

  void _showSlotModal(ConfabSlot? existingSlot) {
    final isEditing = existingSlot != null;
    final nameController = TextEditingController(text: existingSlot?.label ?? '');
    final optionControllers = existingSlot != null
        ? existingSlot.options.map((o) => TextEditingController(text: o)).toList()
        : [TextEditingController(), TextEditingController()];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final canAddOption = optionControllers.length < ConfabulationEngine.maxOptionsPerSlot;
          final canRemoveOption = optionControllers.length > ConfabulationEngine.minOptionsPerSlot;

          // Compute whether the form is valid for enabling the button
          final nameValid = nameController.text.trim().isNotEmpty;
          final filledOptions = optionControllers
              .where((c) => c.text.trim().isNotEmpty)
              .length;
          final optionsValid = filledOptions >= ConfabulationEngine.minOptionsPerSlot;
          final canSubmit = nameValid && optionsValid;

          return Padding(
            padding: EdgeInsets.fromLTRB(
              24,
              24,
              24,
              24 + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle
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
                const SizedBox(height: 20),

                // Title
                Text(
                  isEditing ? 'Edit Slot' : 'New Slot',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 24),

                // Slot Name
                const Text(
                  'SLOT NAME',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    hintText: 'e.g., Color, Animal, City...',
                  ),
                  style: const TextStyle(color: AppTheme.textPrimary),
                  autofocus: !isEditing,
                  onChanged: (_) => setModalState(() {}),
                ),
                const SizedBox(height: 20),

                // Options
                Row(
                  children: [
                    Text(
                      'OPTIONS (${optionControllers.length}/${ConfabulationEngine.maxOptionsPerSlot})',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                        letterSpacing: 1,
                      ),
                    ),
                    const Spacer(),
                    if (canAddOption)
                      TextButton.icon(
                        onPressed: () {
                          setModalState(() {
                            optionControllers.add(TextEditingController());
                          });
                        },
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Add'),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),

                // Option fields
                ...List.generate(optionControllers.length, (index) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 24,
                          child: Text(
                            '${index + 1}.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ),
                        Expanded(
                          child: TextField(
                            controller: optionControllers[index],
                            decoration: InputDecoration(
                              hintText: 'Option ${index + 1}',
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                            ),
                            style: const TextStyle(color: AppTheme.textPrimary),
                            onChanged: (_) => setModalState(() {}),
                          ),
                        ),
                        if (canRemoveOption)
                          IconButton(
                            onPressed: () {
                              setModalState(() {
                                optionControllers[index].dispose();
                                optionControllers.removeAt(index);
                              });
                            },
                            icon: const Icon(Icons.remove_circle_outline, size: 18),
                            color: Colors.red,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          ),
                      ],
                    ),
                  );
                }),

                const SizedBox(height: 24),

                // Action buttons
                Row(
                  children: [
                    if (isEditing)
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _deleteSlot(existingSlot);
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text('Delete'),
                        ),
                      ),
                    if (isEditing) const SizedBox(width: 12),
                    Expanded(
                      flex: isEditing ? 2 : 1,
                      child: ElevatedButton(
                        onPressed: canSubmit
                            ? () {
                                final name = nameController.text.trim();
                                final options = optionControllers
                                    .map((c) => c.text.trim())
                                    .where((o) => o.isNotEmpty)
                                    .toList();

                                // Check for duplicate slot names
                                final isDuplicate = _slots.any((s) =>
                                    s.label.toLowerCase() == name.toLowerCase() &&
                                    (existingSlot == null || s.id != existingSlot.id));
                                if (isDuplicate) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('A slot with this name already exists'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                  return;
                                }

                                Navigator.pop(ctx);

                                if (isEditing) {
                                  _updateSlot(existingSlot, name, options);
                                } else {
                                  _addSlot(name, options);
                                }
                              }
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: AppTheme.primary.withOpacity(0.3),
                          disabledForegroundColor: Colors.white54,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text(isEditing ? 'Update' : 'Add Slot'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ),
          );
        },
      ),
    );
  }

  void _addSlot(String name, List<String> options) {
    final slot = ConfabSlot(
      id: 'slot_${DateTime.now().millisecondsSinceEpoch}',
      label: name,
      options: options,
    );
    setState(() {
      _slots.add(slot);
      _errors.clear();
    });
  }

  void _updateSlot(ConfabSlot oldSlot, String newName, List<String> newOptions) {
    final oldName = oldSlot.label;
    setState(() {
      final index = _slots.indexWhere((s) => s.id == oldSlot.id);
      if (index != -1) {
        _slots[index] = ConfabSlot(
          id: oldSlot.id,
          label: newName,
          options: newOptions,
        );
        // Update template if name changed
        if (oldName != newName) {
          _templateController.text = _templateController.text.replaceAll(
            '{{$oldName}}',
            '{{$newName}}',
          );
        }
      }
      _errors.clear();
    });
  }

  void _deleteSlot(ConfabSlot slot) {
    setState(() {
      _slots.removeWhere((s) => s.id == slot.id);
      // Remove from template
      _templateController.text = _templateController.text.replaceAll(
        '{{${slot.label}}}',
        '',
      );
      _errors.clear();
    });
  }

  void _insertSlotTag(ConfabSlot slot) {
    final tag = '{{${slot.label}}}';
    final selection = _templateController.selection;
    final text = _templateController.text;

    if (selection.isValid && selection.start >= 0) {
      final newText = text.replaceRange(selection.start, selection.end, tag);
      _templateController.text = newText;
      _templateController.selection = TextSelection.collapsed(
        offset: selection.start + tag.length,
      );
    } else {
      _templateController.text = text + tag;
      _templateController.selection = TextSelection.collapsed(
        offset: _templateController.text.length,
      );
    }
    setState(() {});
  }

  void _insertText(String marker) {
    final selection = _templateController.selection;
    final text = _templateController.text;
    if (selection.isValid && selection.start >= 0) {
      final newText = text.replaceRange(selection.start, selection.end, marker);
      _templateController.text = newText;
      _templateController.selection = TextSelection.collapsed(offset: selection.start + marker.length);
    } else {
      _templateController.text = text + marker;
      _templateController.selection = TextSelection.collapsed(offset: _templateController.text.length);
    }
    setState(() {});
  }

  ConfabulationPreset _buildPreset() {
    final now = DateTime.now();
    return ConfabulationPreset(
      id: _editingId ?? const Uuid().v4(),
      name: _nameController.text.trim(),
      audioLocale: _audioLocale,
      inputMethod: _inputMethod,
      textTemplate: _convertDisplayToTokens(_templateController.text),
      slots: _slots,
      audioStartSentence: _audioStartController.text.trim().isEmpty ? null : _audioStartController.text.trim(),
      audioStopSentence: _audioStopController.text.trim().isEmpty ? null : _audioStopController.text.trim(),
      acrosticPosition: _acrosticPosition,
      acrosticLanguage: _acrosticLanguage,
      injectTransformPrompt: _injectTransformController.text.trim().isEmpty ? null : _injectTransformController.text.trim(),
      assistantRedirectUrl: _assistantRedirectUrlController.text.trim().isEmpty ? null : _assistantRedirectUrlController.text.trim(),
      decoyTemplateId: _decoyTemplateId,
      decoyInputType: _decoyInputType,
      elipsArtistTransformPrompt: _elipsArtistTransformController.text.trim().isEmpty ? null : _elipsArtistTransformController.text.trim(),
      elipsSongTransformPrompt: _elipsSongTransformController.text.trim().isEmpty ? null : _elipsSongTransformController.text.trim(),
      elipsWordTransformPrompt: _elipsWordTransformController.text.trim().isEmpty ? null : _elipsWordTransformController.text.trim(),
      autoCopyOverride: _autoCopyOverride,
      shortcutNameOverride: _shortcutNameOverride,
      createdAt: now,
      updatedAt: now,
    );
  }

  bool _validate() {
    final preset = _buildPreset();
    final result = ConfabulationEngine.validatePreset(preset);

    final errors = <String, String?>{};

    for (final error in result.errors) {
      if (error.contains('name')) {
        errors['name'] = error;
      } else if (error.contains('template')) {
        errors['template'] = error;
      } else if (error.contains('slot')) {
        errors['slots'] = error;
      } else {
        errors['general'] = error;
      }
    }

    setState(() {
      _errors = errors;
    });

    return result.isValid;
  }

  Future<void> _save() async {
    if (!_validate()) {
      final firstError = _errors.values.whereType<String>().firstOrNull;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(firstError ?? 'Please fix the errors before saving'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final preset = _buildPreset();
    final provider = context.read<ConfabulationProvider>();

    final success = _isEditing
        ? await provider.updatePreset(preset)
        : await provider.addPreset(preset);

    if (success && mounted) {
      Navigator.pop(context);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.error ?? 'Failed to save preset'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showPreview() {
    final preset = _buildPreset();
    final preview = ConfabulationEngine.renderPreview(preset);

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Preview',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Using first option for each slot:',
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                preview,
                style: const TextStyle(
                  fontSize: 16,
                  color: AppTheme.textPrimary,
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isFR = context.watch<SettingsProvider>().appLanguage == Language.french;
    // Slots are optional when the template relies entirely on a standalone
    // variable (ACROSTIC_URL, INJECT, ELIPS_*, HIGHSCORE_*, etc.).
    // Mirror the engine's validation so the Save button is consistent.
    const standaloneVars = [
      '((ACROSTIC_URL))',
      '((INJECT))', '((ACROSTIC_INJECT))', '((AITransformInject))',
      '((ELIPS_ARTIST))', '((ELIPS_SONG))', '((ELIPS_WORD))',
      '((ACROSTIC_ELIPS_ARTIST))', '((ACROSTIC_ELIPS_SONG))', '((ACROSTIC_ELIPS_WORD))',
      '((AITransformElipsArtist))', '((AITransformElipsSong))', '((AITransformElipsWord))',
      '((HIGHSCORE_SCORE))', '((HIGHSCORE_SCORE+1))', '((HIGHSCORE_RANKING))',
    ];
    final template = _templateController.text;
    final hasStandalone = standaloneVars.any(template.contains);
    final canSave = _nameController.text.trim().isNotEmpty &&
        template.trim().isNotEmpty &&
        (_slots.isNotEmpty || hasStandalone);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        title: Text(_isEditing ? 'Edit Confabulation' : 'New Confabulation'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            onPressed: _showPreview,
            icon: const Icon(Icons.visibility_outlined),
            tooltip: 'Preview',
          ),
          TextButton(
            onPressed: canSave ? _save : null,
            child: Text(
              'Save',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: canSave ? AppTheme.primary : AppTheme.textTertiary,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Name
              _SectionTitle(title: 'NAME', required: true),
              const SizedBox(height: 8),
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  hintText: 'Enter preset name',
                  errorText: _errors['name'],
                ),
                style: const TextStyle(color: AppTheme.textPrimary),
                onChanged: (_) => setState(() => _errors.remove('name')),
              ),

              const SizedBox(height: 24),

              // Text Template with Add Slot button
              Row(
                children: [
                  _SectionTitle(title: 'TEXT', required: true),
                  const Spacer(),
                  if (_slots.length < ConfabulationEngine.maxSlots)
                    TextButton.icon(
                      onPressed: _showAddSlotModal,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add Slot'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.confabulationColor,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),

              // Slot tags
              if (_slots.isNotEmpty) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _slots.map((slot) {
                    return _SlotTag(
                      slot: slot,
                      onNameTap: () => _insertText('{{${slot.label}}}'),
                      onMenuTap: () => _showSlotActions(slot),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
              ],

              // API & Acrostic variable chips
              Builder(builder: (ctx) {
                final settings = ctx.watch<SettingsProvider>();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (settings.hasInjectConfig) ...[
                        _VariableChip(label: '((INJECT))', onTap: () => _insertText('((INJECT))')),
                        _VariableChip(label: '((ACROSTIC_INJECT))', onTap: () => _insertText('((ACROSTIC_INJECT))')),
                        _VariableChip(label: '((AITransformInject))', onTap: () { _insertText('((AITransformInject))'); setState(() {}); }),
                      ],
                      if (settings.hasElipsConfig) ...[
                        _VariableChip(label: '((ELIPS_ARTIST))', onTap: () => _insertText('((ELIPS_ARTIST))')),
                        _VariableChip(label: '((ELIPS_SONG))', onTap: () => _insertText('((ELIPS_SONG))')),
                        _VariableChip(label: '((ELIPS_WORD))', onTap: () => _insertText('((ELIPS_WORD))')),
                        _VariableChip(label: '((ACROSTIC_ELIPS_ARTIST))', onTap: () => _insertText('((ACROSTIC_ELIPS_ARTIST))')),
                        _VariableChip(label: '((ACROSTIC_ELIPS_SONG))', onTap: () => _insertText('((ACROSTIC_ELIPS_SONG))')),
                        _VariableChip(label: '((ACROSTIC_ELIPS_WORD))', onTap: () => _insertText('((ACROSTIC_ELIPS_WORD))')),
                        _VariableChip(label: '((AITransformElipsArtist))', onTap: () { _insertText('((AITransformElipsArtist))'); setState(() {}); }),
                        _VariableChip(label: '((AITransformElipsSong))', onTap: () { _insertText('((AITransformElipsSong))'); setState(() {}); }),
                        _VariableChip(label: '((AITransformElipsWord))', onTap: () { _insertText('((AITransformElipsWord))'); setState(() {}); }),
                      ],
                      if (settings.hasHighScoreConfig) ...[
                        _VariableChip(label: '((HIGHSCORE_SCORE))', onTap: () => _insertText('((HIGHSCORE_SCORE))')),
                        _VariableChip(label: '((HIGHSCORE_SCORE+1))', onTap: () => _insertText('((HIGHSCORE_SCORE+1))')),
                        _VariableChip(label: '((HIGHSCORE_RANKING))', onTap: () => _insertText('((HIGHSCORE_RANKING))')),
                      ],
                      // Acrostic via spectator URL (oass.app/{id}/{word}).
                      _VariableChip(label: '((ACROSTIC_URL))', onTap: () => _insertText('((ACROSTIC_URL))')),
                    ],
                  ),
                );
              }),

              // AI Transform Inject prompt (shown when template contains AITransformInject)
              if (_templateController.text.contains('((AITransformInject))'))
                _TransformPromptSection(
                  label: 'AI Transform Inject',
                  hint: 'Prompt with {value} for inject value...',
                  controller: _injectTransformController,
                  onTest: () => _testTransform(_injectTransformController.text, 'inject'),
                ),

              // AI Transform Elips Artist
              if (_templateController.text.contains('((AITransformElipsArtist))'))
                _TransformPromptSection(
                  label: 'AI Transform Elips Artist',
                  hint: 'Prompt with {value} for artist name...',
                  controller: _elipsArtistTransformController,
                  onTest: () => _testTransform(_elipsArtistTransformController.text, 'elips_artist'),
                ),

              // AI Transform Elips Song
              if (_templateController.text.contains('((AITransformElipsSong))'))
                _TransformPromptSection(
                  label: 'AI Transform Elips Song',
                  hint: 'Prompt with {value} for song name...',
                  controller: _elipsSongTransformController,
                  onTest: () => _testTransform(_elipsSongTransformController.text, 'elips_song'),
                ),

              // AI Transform Elips Word
              if (_templateController.text.contains('((AITransformElipsWord))'))
                _TransformPromptSection(
                  label: 'AI Transform Elips Word',
                  hint: 'Prompt with {value} for output word...',
                  controller: _elipsWordTransformController,
                  onTest: () => _testTransform(_elipsWordTransformController.text, 'elips_word'),
                ),

              // Acrostic bank & position settings (shown when template contains ACROSTIC)
              Builder(builder: (_) {
                final hasAcrostic = _templateController.text.contains('ACROSTIC');
                if (!hasAcrostic) return const SizedBox.shrink();

                final acrosticProvider = context.watch<AcrosticProvider>();
                final languages = acrosticProvider.languages;

                // Default to first language if not set
                if (_acrosticLanguage == null && languages.isNotEmpty) {
                  _acrosticLanguage = languages.first;
                }

                final availablePositions = _acrosticLanguage != null
                    ? acrosticProvider.fullyCoveredPositionsForLanguage(_acrosticLanguage!)
                    : <int>[];

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Acrostic', style: TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 10),

                      // Bank / language picker
                      Row(
                        children: [
                          Text('Bank', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Wrap(
                              spacing: 6,
                              children: languages.map((lang) {
                                final selected = lang == _acrosticLanguage;
                                return ChoiceChip(
                                  label: Text(lang.toUpperCase(), style: TextStyle(fontSize: 11)),
                                  selected: selected,
                                  selectedColor: AppTheme.primary,
                                  backgroundColor: AppTheme.surfaceLight,
                                  labelStyle: TextStyle(color: selected ? Colors.white : AppTheme.textSecondary),
                                  visualDensity: VisualDensity.compact,
                                  onSelected: (_) {
                                    setState(() {
                                      _acrosticLanguage = lang;
                                      // Reset position if not available in new bank
                                      final newPositions = acrosticProvider.fullyCoveredPositionsForLanguage(lang);
                                      if (_acrosticPosition > 0 && !newPositions.contains(_acrosticPosition)) {
                                        _acrosticPosition = 0;
                                      }
                                    });
                                  },
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Position picker
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text('Position', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                          ChoiceChip(
                            label: Text('Input', style: TextStyle(fontSize: 11)),
                            selected: _acrosticPosition == -1,
                            selectedColor: AppTheme.primary,
                            backgroundColor: AppTheme.surfaceLight,
                            labelStyle: TextStyle(color: _acrosticPosition == -1 ? Colors.white : AppTheme.textSecondary),
                            visualDensity: VisualDensity.compact,
                            onSelected: (_) => setState(() => _acrosticPosition = -1),
                          ),
                          ...List.generate(6, (i) {
                            final pos = i + 1;
                            final available = availablePositions.contains(pos);
                            final selected = _acrosticPosition == pos;
                            if (!available) return const SizedBox.shrink();
                            return ChoiceChip(
                              label: Text('$pos', style: TextStyle(fontSize: 11)),
                              selected: selected,
                              selectedColor: AppTheme.primary,
                              backgroundColor: AppTheme.surfaceLight,
                              labelStyle: TextStyle(color: selected ? Colors.white : AppTheme.textSecondary),
                              visualDensity: VisualDensity.compact,
                              onSelected: (_) => setState(() => _acrosticPosition = pos),
                            );
                          }),
                        ],
                      ),
                    ],
                  ),
                );
              }),

              // Template text field
              TextField(
                controller: _templateController,
                decoration: InputDecoration(
                  hintText: 'Write your text and tap slots to insert them...',
                  errorText: _errors['template'],
                  alignLabelWithHint: true,
                ),
                style: const TextStyle(color: AppTheme.textPrimary),
                maxLines: 10,
                minLines: 6,
                onChanged: (_) => setState(() => _errors.remove('template')),
              ),

              if (_errors['slots'] != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _errors['slots']!,
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ),

              const SizedBox(height: 24),

              // Input Method — only relevant when there are slots to fill.
              // With 0 slots (template uses only API variables / acrostics),
              // no input is needed and the picker is hidden.
              if (_slots.isNotEmpty) ...[
                _SectionTitle(title: 'INPUT METHOD', required: true),
                const SizedBox(height: 8),
                _InputMethodSelector(
                  selectedMethod: _inputMethod,
                  maxSlotOptions: _slots.map((s) => s.options.length).reduce((a, b) => a > b ? a : b),
                  onChanged: (method) => setState(() => _inputMethod = method),
                ),
              ] else
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, size: 18, color: AppTheme.textSecondary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          isFR
                              ? 'Aucun slot — pas d\'input nécessaire (texte rendu directement à partir des variables API).'
                              : 'No slot — no input required (text rendered directly from API variables).',
                          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                        ),
                      ),
                    ],
                  ),
                ),

              // Audio start/stop sentence fields
              if (_slots.isNotEmpty && _inputMethod == ConfabInputMethod.audio) ...[
                const SizedBox(height: 16),
                TextField(
                  controller: _audioStartController,
                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    labelText: isFR ? 'Start Sentence (optionnel)' : 'Start Sentence (optional)',
                    labelStyle: const TextStyle(color: AppTheme.textTertiary, fontSize: 12),
                    hintText: isFR ? 'Phrase pour démarrer l\'écoute...' : 'Sentence to start listening...',
                    hintStyle: const TextStyle(color: AppTheme.textTertiary, fontSize: 12, fontStyle: FontStyle.italic),
                    filled: true,
                    fillColor: AppTheme.surface,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.border)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.border)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.primary, width: 2)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _audioStopController,
                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    labelText: isFR ? 'Stop Sentence (optionnel)' : 'Stop Sentence (optional)',
                    labelStyle: const TextStyle(color: AppTheme.textTertiary, fontSize: 12),
                    hintText: isFR ? 'Phrase pour arrêter l\'écoute...' : 'Sentence to stop listening...',
                    hintStyle: const TextStyle(color: AppTheme.textTertiary, fontSize: 12, fontStyle: FontStyle.italic),
                    filled: true,
                    fillColor: AppTheme.surface,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.border)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.border)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.primary, width: 2)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
              ],

              const SizedBox(height: 16),
              _SectionTitle(title: 'DECOY TEMPLATE (optional)'),
              const SizedBox(height: 4),
              Text(
                isFR
                    ? 'Choisis un template (créés dans Paramètres → Display). Vide = défaut global.'
                    : 'Pick a template (managed in Settings → Display). Empty = global default.',
                style: const TextStyle(fontSize: 11, color: AppTheme.textTertiary, height: 1.3),
              ),
              const SizedBox(height: 8),
              Builder(builder: (ctx) {
                final settings = ctx.watch<SettingsProvider>();
                final templates = settings.decoyTemplates;
                final defaultId = settings.defaultDecoyTemplateId;
                return DropdownButtonFormField<String?>(
                  value: _decoyTemplateId,
                  isExpanded: true,
                  decoration: InputDecoration(
                    filled: true, fillColor: AppTheme.surface,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.border)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.border)),
                  ),
                  dropdownColor: AppTheme.surface,
                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                  items: [
                    DropdownMenuItem<String?>(
                      value: null,
                      child: Text(defaultId == null
                          ? (isFR ? '— Aucun —' : '— None —')
                          : (isFR
                              ? '— Défaut global (${settings.decoyTemplateById(defaultId)?.name ?? 'unknown'}) —'
                              : '— Global default (${settings.decoyTemplateById(defaultId)?.name ?? 'unknown'}) —')),
                    ),
                    for (final t in templates)
                      DropdownMenuItem<String?>(value: t.id, child: Text(t.name)),
                  ],
                  onChanged: (v) => setState(() => _decoyTemplateId = v),
                );
              }),

              const SizedBox(height: 10),
              Row(
                children: [
                  Text(isFR ? 'Geste :' : 'Gesture:', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  const SizedBox(width: 12),
                  Expanded(child: _ConfabDecoyPill(
                    label: 'Tap',
                    selected: _decoyInputType == 'tap',
                    onTap: () => setState(() => _decoyInputType = 'tap'),
                  )),
                  const SizedBox(width: 6),
                  Expanded(child: _ConfabDecoyPill(
                    label: 'Swipe',
                    selected: _decoyInputType == 'swipe',
                    onTap: () => setState(() => _decoyInputType = 'swipe'),
                  )),
                ],
              ),

              const SizedBox(height: 12),
              const Text(
                'Redirect URL after input (empty = global default)',
                style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _assistantRedirectUrlController,
                keyboardType: TextInputType.url,
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12),
                decoration: InputDecoration(
                  hintText: 'https://...',
                  hintStyle: const TextStyle(fontSize: 11, color: AppTheme.textTertiary),
                  filled: true,
                  fillColor: AppTheme.surface,
                  isDense: true,
                  prefixIcon: const Icon(Icons.link, size: 16, color: AppTheme.textSecondary),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.border)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.border)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),

              const SizedBox(height: 24),
              OutputOverrideSection(
                locale: context.read<SettingsProvider>().appLanguage,
                autoCopyOverride: _autoCopyOverride,
                shortcutNameOverride: _shortcutNameOverride,
                shortcutController: _shortcutNameOverrideController,
                onToggleCustom: (enabled) {
                  setState(() {
                    if (enabled) {
                      _autoCopyOverride = true;
                      _shortcutNameOverride = '';
                      _shortcutNameOverrideController.text = '';
                    } else {
                      _autoCopyOverride = null;
                      _shortcutNameOverride = null;
                      _shortcutNameOverrideController.text = '';
                    }
                  });
                },
                onAutoCopyChanged: (v) => setState(() => _autoCopyOverride = v),
                onShortcutChanged: (v) => setState(() => _shortcutNameOverride = v),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

// ============= WIDGETS =============

class _SectionTitle extends StatelessWidget {
  final String title;
  final bool required;

  const _SectionTitle({
    required this.title,
    this.required = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppTheme.textSecondary,
            letterSpacing: 1,
          ),
        ),
        if (required)
          const Text(
            ' *',
            style: TextStyle(color: Colors.red, fontSize: 12),
          ),
      ],
    );
  }
}

class _SlotTag extends StatelessWidget {
  final ConfabSlot slot;
  /// Tapping the name/label area inserts the slot's `{{Name}}` placeholder
  /// into the template at the current cursor position.
  final VoidCallback onNameTap;
  /// Tapping the trailing 3-dot icon opens the Edit/Duplicate/Delete menu.
  final VoidCallback onMenuTap;

  const _SlotTag({
    required this.slot,
    required this.onNameTap,
    required this.onMenuTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.confabulationColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.confabulationColor.withOpacity(0.5),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Tappable label — inserts the variable into the template.
          InkWell(
            onTap: onNameTap,
            customBorder: const RoundedRectangleBorder(
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                bottomLeft: Radius.circular(20),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    slot.label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.confabulationColor,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '(${slot.options.length})',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.confabulationColor.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Tappable 3-dot menu trigger — opens Edit/Duplicate/Delete actions.
          InkWell(
            onTap: onMenuTap,
            customBorder: const RoundedRectangleBorder(
              borderRadius: BorderRadius.only(
                topRight: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 10, 8),
              child: Icon(
                Icons.more_vert,
                size: 16,
                color: AppTheme.confabulationColor.withOpacity(0.75),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VariableChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _VariableChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.15),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.orange.withOpacity(0.3)),
        ),
        child: Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600, fontFamily: 'monospace', color: Colors.orange)),
      ),
    );
  }
}

class _InputMethodSelector extends StatelessWidget {
  final ConfabInputMethod selectedMethod;
  final ValueChanged<ConfabInputMethod> onChanged;
  final int maxSlotOptions;

  const _InputMethodSelector({
    required this.selectedMethod,
    required this.onChanged,
    this.maxSlotOptions = 6,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        // Assistant became a global mode (Home screen toggle), so it's no
        // longer proposed as a per-preset input method.
        children: const [
          ConfabInputMethod.volume,
          ConfabInputMethod.tap,
          ConfabInputMethod.audio,
          ConfabInputMethod.clockSwipe,
        ].map((method) {
          final isSelected = method == selectedMethod;
          // Tap and Volume are limited to 6 options
          final isDisabled = (method == ConfabInputMethod.tap || method == ConfabInputMethod.volume)
              && maxSlotOptions > 6;

          IconData icon;
          switch (method) {
            case ConfabInputMethod.volume:
              icon = Icons.volume_up;
              break;
            case ConfabInputMethod.audio:
              icon = Icons.mic;
              break;
            case ConfabInputMethod.tap:
              icon = Icons.fingerprint;
              break;
            case ConfabInputMethod.clockSwipe:
              icon = Icons.swipe;
              break;
            case ConfabInputMethod.assistant:
              icon = Icons.people;
              break;
          }

          return Expanded(
            child: GestureDetector(
              onTap: isDisabled ? null : () => onChanged(method),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: isSelected && !isDisabled ? AppTheme.confabulationColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Opacity(
                  opacity: isDisabled ? 0.3 : 1.0,
                  child: Column(
                    children: [
                      Icon(
                        icon,
                        color: isSelected && !isDisabled ? Colors.white : AppTheme.textSecondary,
                        size: 24,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        method.displayName,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isSelected && !isDisabled ? Colors.white : AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _TransformPromptSection extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final VoidCallback onTest;

  const _TransformPromptSection({
    required this.label,
    required this.hint,
    required this.controller,
    required this.onTest,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            maxLines: 3,
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: AppTheme.textTertiary, fontSize: 12),
              filled: true,
              fillColor: AppTheme.background,
              contentPadding: const EdgeInsets.all(10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppTheme.border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppTheme.border)),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: SizedBox(
              height: 30,
              child: ElevatedButton.icon(
                onPressed: onTest,
                icon: Icon(Icons.play_arrow, size: 14),
                label: Text('Test', style: TextStyle(fontSize: 11)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfabDecoyPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ConfabDecoyPill({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primary.withValues(alpha: 0.15) : AppTheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? AppTheme.primary : AppTheme.border,
            width: selected ? 1.2 : 1,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? AppTheme.primary : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}
