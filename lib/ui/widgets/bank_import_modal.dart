import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../../engine/bank_validator.dart';
import '../../models/models.dart';
import '../../utils/settings_provider.dart';
import '../theme/app_theme.dart';

/// Callback when import is confirmed with valid entries.
typedef BankImportCallback = void Function(
    Map<String, String> entries, BankImportMeta meta);

/// Reusable modal for importing JSON bank data.
///
/// Three-step flow:
/// A) Prepare — Config recap + editable fields (language/tense/style/lines/examples)
/// B) Prompt — Variables block + live prompt + Copy + "J'ai le JSON"
/// C) Import — Paste JSON + Validate + Preview + Import
class BankImportModal extends StatefulWidget {
  final BankType bankType;
  final Language language;
  final int? rounds;
  final List<String>? options;
  final int? targetScore;
  final List<String>? freewheelObjects;
  final String? performerKey;
  final List<int>? performerSequenceIndices;
  final BankImportCallback onImport;

  const BankImportModal({
    super.key,
    required this.bankType,
    required this.language,
    this.rounds,
    this.options,
    this.targetScore,
    this.freewheelObjects,
    this.performerKey,
    this.performerSequenceIndices,
    required this.onImport,
  });

  /// Show the modal as a bottom sheet.
  static Future<void> show({
    required BuildContext context,
    required BankType bankType,
    required Language language,
    int? rounds,
    List<String>? options,
    int? targetScore,
    List<String>? freewheelObjects,
    String? performerKey,
    List<int>? performerSequenceIndices,
    required BankImportCallback onImport,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => BankImportModal(
        bankType: bankType,
        language: language,
        rounds: rounds,
        options: options,
        targetScore: targetScore,
        freewheelObjects: freewheelObjects,
        performerKey: performerKey,
        performerSequenceIndices: performerSequenceIndices,
        onImport: onImport,
      ),
    );
  }

  @override
  State<BankImportModal> createState() => _BankImportModalState();
}

class _BankImportModalState extends State<BankImportModal> {
  // Step navigation (1 = prepare, 2 = prompt, 3 = paste+validate)
  int _currentStep = 1;

  // Step 1: editable config fields
  late TextEditingController _langController;
  String _tense = 'future';
  late TextEditingController _styleController;

  // Scenario-based examples
  late List<ExampleScenario> _scenarios;
  late List<TextEditingController> _exampleControllers;
  bool _lastHasRequired = false;

  // Step 3: JSON paste + validation
  final _jsonController = TextEditingController();
  ValidationResult? _validationResult;

  // AI generation
  bool _isGenerating = false;
  String? _generateError;

  bool get _isFrench => widget.language == Language.french;

  String get _presetLabel {
    switch (widget.bankType) {
      case BankType.choicesExactSequence:
      case BankType.choicesBucket:
        return 'choices';
      case BankType.duelFixedRounds:
      case BankType.duelFirstTo:
      case BankType.duelSequences:
        return 'duel';
      case BankType.freewheel:
        return 'free will';
    }
  }

  String get _modeLabel {
    switch (widget.bankType) {
      case BankType.choicesExactSequence:
        return 'exact_sequence';
      case BankType.duelSequences:
        return 'duel_sequence';
      default:
        return 'bucket';
    }
  }

  int get _expectedCount {
    final meta = BankImportMeta(
      preset: _presetLabel,
      mode: _modeLabel,
      rounds: widget.rounds,
      options: widget.options,
      targetScore: widget.targetScore,
    );
    return BankValidator.computeExpectedKeys(
      bankType: widget.bankType,
      meta: meta,
      freewheelObjects: widget.freewheelObjects,
    ).length;
  }

  String get _langCode => _langController.text.trim().isEmpty
      ? (widget.language == Language.french ? 'fr' : 'en')
      : _langController.text.trim();

  String get _styleValue => _styleController.text.trim().isEmpty
      ? 'direct'
      : _styleController.text.trim();

  List<MapEntry<String, String>> get _filledExamples {
    final result = <MapEntry<String, String>>[];
    for (int i = 0; i < _scenarios.length; i++) {
      final text = _exampleControllers[i].text.trim();
      if (text.isNotEmpty) {
        result.add(MapEntry(_scenarios[i].key, text));
      }
    }
    return result;
  }

  BankPrompt get _livePrompt => BankValidator.generatePrompt(
        bankType: widget.bankType,
        languageCode: _langCode,
        rounds: widget.rounds,
        options: widget.options,
        targetScore: widget.targetScore,
        freewheelObjects: widget.freewheelObjects,
        tense: _tense,
        style: _styleValue,
        performerKey: widget.performerKey,
        examples: _filledExamples,
      );

  @override
  void initState() {
    super.initState();
    _langController = TextEditingController(
      text: widget.language == Language.french ? 'fr' : 'en',
    );
    _styleController = TextEditingController(text: 'direct');

    _scenarios = BankValidator.generateExampleScenarios(
      bankType: widget.bankType,
      languageCode: widget.language == Language.french ? 'fr' : 'en',
      rounds: widget.rounds,
      options: widget.options,
      targetScore: widget.targetScore,
      freewheelObjects: widget.freewheelObjects,
      performerKey: widget.performerKey,
      performerSequenceIndices: widget.performerSequenceIndices,
    );
    _exampleControllers = List.generate(
      _scenarios.length,
      (_) => TextEditingController(),
    );
  }

  @override
  void dispose() {
    _langController.dispose();
    _styleController.dispose();
    for (final c in _exampleControllers) {
      c.dispose();
    }
    _jsonController.dispose();
    super.dispose();
  }

  void _copyPrompt() {
    Clipboard.setData(ClipboardData(text: _livePrompt.combined));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isFrench ? 'Prompt copié' : 'Prompt copied'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _doValidate() {
    final result = BankValidator.validate(
      jsonString: _jsonController.text,
      expectedBankType: widget.bankType,
      freewheelObjects: widget.freewheelObjects,
    );
    setState(() {
      _validationResult = result;
    });
  }

  void _doImport() {
    final result = _validationResult;
    if (result == null || !result.isValid || result.entries == null) return;

    widget.onImport(result.entries!, result.meta!);
    Navigator.of(context).pop();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isFrench
            ? '${result.foundCount} textes importés'
            : '${result.foundCount} texts imported'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _generateWithAI() async {
    final settings = context.read<SettingsProvider>();
    if (!settings.hasOpenaiApiKey) {
      setState(() => _generateError = _isFrench
          ? 'Clé OpenAI non configurée. Allez dans Réglages.'
          : 'OpenAI key not configured. Go to Settings.');
      return;
    }

    setState(() {
      _isGenerating = true;
      _generateError = null;
    });

    try {
      final prompt = _livePrompt;
      // Lower temperature when examples are present: we want stylistic
      // fidelity, not creativity. Without examples, allow more variety.
      final temperature = prompt.hasExamples ? 0.4 : 0.7;
      final response = await http.post(
        Uri.parse('https://api.openai.com/v1/chat/completions'),
        headers: {
          'Authorization': 'Bearer ${settings.openaiApiKey}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'gpt-4o',
          'messages': [
            {'role': 'system', 'content': prompt.system},
            {'role': 'user', 'content': prompt.user},
          ],
          'temperature': temperature,
          'max_tokens': 16000,
        }),
      ).timeout(const Duration(seconds: 120));

      if (!mounted) return;

      if (response.statusCode != 200) {
        setState(() {
          _isGenerating = false;
          _generateError = 'API error ${response.statusCode}: ${response.body.length > 200 ? response.body.substring(0, 200) : response.body}';
        });
        return;
      }

      final json = jsonDecode(response.body);
      final content = json['choices']?[0]?['message']?['content'] as String? ?? '';

      // Extract JSON from response (strip markdown fences if present)
      var jsonStr = content.trim();
      if (jsonStr.startsWith('```')) {
        jsonStr = jsonStr.replaceFirst(RegExp(r'^```\w*\n?'), '').replaceFirst(RegExp(r'\n?```$'), '');
      }

      setState(() {
        _isGenerating = false;
        _jsonController.text = jsonStr;
        _currentStep = 3;
      });

      // Auto-validate
      _doValidate();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isGenerating = false;
        _generateError = e.toString();
      });
    }
  }

  String get _stepTitle {
    switch (_currentStep) {
      case 1:
        return _isFrench ? 'IA Import — Préparer' : 'AI Import — Prepare';
      case 2:
        return _isFrench ? 'IA Import — Prompt' : 'AI Import — Prompt';
      case 3:
        return _isFrench ? 'IA Import — Coller & Valider' : 'AI Import — Paste & Validate';
      default:
        return 'IA Import';
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final maxHeight = mediaQuery.size.height * 0.9;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      padding: EdgeInsets.only(bottom: mediaQuery.viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.textTertiary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Title bar with step indicator
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                if (_currentStep > 1)
                  IconButton(
                    icon: const Icon(Icons.arrow_back,
                        color: AppTheme.textSecondary, size: 20),
                    onPressed: () =>
                        setState(() => _currentStep = _currentStep - 1),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                if (_currentStep > 1) const SizedBox(width: 8),
                const Icon(Icons.auto_fix_high,
                    color: AppTheme.primary, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _stepTitle,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                // Step indicator
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$_currentStep/3',
                    style: const TextStyle(
                      color: AppTheme.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: AppTheme.border),

          // Content
          Expanded(
            child: _currentStep == 1
                ? _buildStepPrepare()
                : _currentStep == 2
                    ? _buildStepPrompt()
                    : _buildStepPaste(),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // STEP A — PREPARE (config recap + editable fields)
  // ═══════════════════════════════════════════════════════════════

  Widget _buildStepPrepare() {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Workflow explanation ──
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.primary.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.auto_fix_high, size: 18, color: AppTheme.primary.withValues(alpha: 0.8)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _isFrench
                              ? 'Nous allons préparer un prompt à copier-coller dans l\'IA de votre choix (Claude, ChatGPT…). '
                                'Elle générera un JSON que vous collerez ici pour l\'importer.'
                              : 'We\'ll prepare a prompt to copy-paste into the AI of your choice (Claude, ChatGPT…). '
                                'It will generate a JSON that you\'ll paste here to import.',
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── Recap (read-only) ──
                _buildSectionLabel(
                    _isFrench ? 'Récapitulatif' : 'Summary'),
                const SizedBox(height: 8),
                _buildRecapCard(),
                const SizedBox(height: 16),

                // ── Editable fields ──
                _buildSectionLabel(
                    _isFrench ? 'Personnalisation' : 'Customization'),
                const SizedBox(height: 8),
                _buildEditableFields(),
                const SizedBox(height: 16),

                // ── Examples ──
                _buildSectionLabel(
                    _isFrench ? 'Exemples de style' : 'Style examples'),
                const SizedBox(height: 8),
                _buildExamplesSection(),
              ],
            ),
          ),
        ),
        // Bottom buttons
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _hasRequiredExample
                      ? () => setState(() => _currentStep = 2)
                      : null,
                  icon: const Icon(Icons.arrow_forward, size: 16),
                  label: Text(_isFrench ? 'Voir le prompt' : 'View prompt'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppTheme.surfaceLight,
                    disabledForegroundColor: AppTheme.textTertiary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => setState(() => _currentStep = 3),
                  icon: const Icon(Icons.content_paste, size: 16),
                  label: Text(_isFrench ? 'J\'ai le JSON' : 'I have the JSON'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.surface,
                    foregroundColor: AppTheme.textPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: AppTheme.primary.withOpacity(0.5)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // STEP B — PROMPT PREVIEW
  // ═══════════════════════════════════════════════════════════════

  Widget _buildStepPrompt() {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Variables block ──
                _buildSectionLabel(_isFrench ? 'Variables' : 'Variables'),
                const SizedBox(height: 8),
                _buildVariablesBlock(),
                const SizedBox(height: 16),

                // ── Live prompt ──
                _buildSectionLabel('Prompt'),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.background,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: SelectableText(
                    _livePrompt.combined,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 10,
                      color: AppTheme.textPrimary,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Error message
        if (_generateError != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              _generateError!,
              style: TextStyle(fontSize: 12, color: Colors.red.shade300),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),

        // Bottom buttons
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            children: [
              // Main action: Generate with AI
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isGenerating ? null : _generateWithAI,
                  icon: _isGenerating
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.auto_fix_high, size: 16),
                  label: Text(_isGenerating
                      ? (_isFrench ? 'Génération en cours...' : 'Generating...')
                      : (_isFrench ? 'Générer avec IA' : 'Generate with AI')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.teal.withValues(alpha: 0.5),
                    disabledForegroundColor: Colors.white70,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Secondary actions
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isGenerating ? null : _copyPrompt,
                      icon: const Icon(Icons.copy, size: 16),
                      label: Text(_isFrench ? 'Copier prompt' : 'Copy prompt'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primary,
                        side: const BorderSide(color: AppTheme.primary),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isGenerating ? null : () => setState(() => _currentStep = 3),
                      icon: const Icon(Icons.paste, size: 16),
                      label: Text(_isFrench ? "J'ai le JSON" : 'I have JSON'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.textSecondary,
                        side: const BorderSide(color: AppTheme.border),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // SHARED UI COMPONENTS
  // ═══════════════════════════════════════════════════════════════

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppTheme.textSecondary,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildRecapCard() {
    final rows = <_RecapRow>[];

    rows.add(_RecapRow('Preset', _presetLabel));
    rows.add(_RecapRow('Mode', _modeLabel));

    if (widget.rounds != null) {
      rows.add(_RecapRow('Rounds', '${widget.rounds}'));
    }
    if (widget.targetScore != null) {
      rows.add(_RecapRow('Target score', '${widget.targetScore}'));
    }
    if (widget.options != null && widget.options!.isNotEmpty) {
      rows.add(_RecapRow(
          'Options (${widget.options!.length})', widget.options!.join(', ')));
    }
    if (widget.performerKey != null) {
      rows.add(_RecapRow('Performer key', widget.performerKey!));
    }
    if (widget.freewheelObjects != null) {
      rows.add(
          _RecapRow('Objects', widget.freewheelObjects!.join(', ')));
    }

    rows.add(_RecapRow(
        _isFrench ? 'Entrées attendues' : 'Expected entries',
        '$_expectedCount'));

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          for (int i = 0; i < rows.length; i++) ...[
            if (i > 0)
              const Divider(height: 1, color: AppTheme.border),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 120,
                    child: Text(
                      rows[i].label,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      rows[i].value,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEditableFields() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Language
          _buildFieldLabel(_isFrench ? 'Langue' : 'Language'),
          const SizedBox(height: 4),
          TextField(
            controller: _langController,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(
                color: AppTheme.textPrimary, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'fr, en, es, ar...',
              hintStyle: TextStyle(
                  color: AppTheme.textTertiary.withValues(alpha: 0.6),
                  fontSize: 13),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 10),
              filled: true,
              fillColor: AppTheme.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: AppTheme.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: AppTheme.border),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Tense
          _buildFieldLabel(_isFrench ? 'Temps' : 'Tense'),
          const SizedBox(height: 4),
          _buildSegmentedSelector(
            value: _tense,
            items: const ['future', 'present', 'past'],
            labels: _isFrench
                ? const ['Futur', 'Présent', 'Passé']
                : const ['Future', 'Present', 'Past'],
            onChanged: (v) => setState(() => _tense = v),
          ),
          const SizedBox(height: 12),

          // Style (free text + tooltip)
          Row(
            children: [
              _buildFieldLabel('Style'),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: AppTheme.surface,
                      title: Text(
                        'Style',
                        style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16),
                      ),
                      content: Text(
                        _isFrench
                            ? 'Décrivez librement le ton et le style d\'écriture souhaité pour les textes générés.\n\n'
                              'Exemples : drôle, moqueur, coquin, élégant, vulgaire, minimaliste, poétique, direct, psychologique, blunt...\n\n'
                              'Vous pouvez aussi écrire des phrases complètes : "comme si tu parlais à un ami", "ton sarcastique mais bienveillant", etc.'
                            : 'Freely describe the tone and writing style you want for the generated texts.\n\n'
                              'Examples: funny, mocking, playful, elegant, vulgar, minimalist, poetic, direct, psychological, blunt...\n\n'
                              'You can also write full sentences: "as if talking to a friend", "sarcastic but kind tone", etc.',
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.5),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: const Text('OK'),
                        ),
                      ],
                    ),
                  );
                },
                child: const Icon(
                  Icons.info_outline,
                  size: 14,
                  color: AppTheme.textTertiary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          TextField(
            controller: _styleController,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(
                color: AppTheme.textPrimary, fontSize: 13),
            decoration: InputDecoration(
              hintText: _isFrench
                  ? 'Ex: drôle, moqueur, coquin, élégant...'
                  : 'E.g. funny, mocking, playful, elegant...',
              hintStyle: TextStyle(
                  color: AppTheme.textTertiary.withValues(alpha: 0.6),
                  fontSize: 12),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 10),
              filled: true,
              fillColor: AppTheme.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: AppTheme.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: AppTheme.border),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExamplesSection() {
    if (_scenarios.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _isFrench
              ? 'Écrivez un exemple de texte pour chaque scénario afin que le LLM imite votre style.'
              : 'Write an example text for each scenario so the LLM can imitate your style.',
          style: const TextStyle(
            fontSize: 11,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 10),
        for (int i = 0; i < _scenarios.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          _buildScenarioCard(i),
        ],
      ],
    );
  }

  bool get _hasRequiredExample =>
      _exampleControllers.isNotEmpty &&
      _exampleControllers[0].text.trim().isNotEmpty;

  Widget _buildScenarioCard(int index) {
    final scenario = _scenarios[index];
    final isFirst = index == 0;

    return Container(
      key: ValueKey('scenario_${scenario.key}'),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isFirst
              ? AppTheme.primary.withValues(alpha: 0.4)
              : AppTheme.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: colored H/M pattern + summary + info icon
          Row(
            children: [
              // Colored H/M pattern badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: _isHMPattern(scenario.displayKey)
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (int c = 0; c < scenario.displayKey.length; c++)
                            Text(
                              scenario.displayKey[c],
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: scenario.displayKey[c] == 'H'
                                    ? Colors.green
                                    : Colors.red.shade300,
                              ),
                            ),
                        ],
                      )
                    : Text(
                        scenario.displayKey,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primary,
                        ),
                      ),
              ),
              const SizedBox(width: 8),
              // Summary
              Expanded(
                child: Text(
                  scenario.summary,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              // Info button (tap to expand)
              GestureDetector(
                onTap: () => _showScenarioInfo(scenario),
                child: const Icon(
                  Icons.info_outline,
                  size: 16,
                  color: AppTheme.textTertiary,
                ),
              ),
            ],
          ),
          // In preprogrammed mode: show S/P sequences
          if (_isHMPattern(scenario.displayKey) &&
              widget.performerSequenceIndices != null &&
              widget.options != null) ...[
            const SizedBox(height: 4),
            _buildScenarioSequences(scenario.displayKey),
          ],
          const SizedBox(height: 8),
          // Text field
          TextField(
            controller: _exampleControllers[index],
            textCapitalization: TextCapitalization.sentences,
            onChanged: isFirst
                ? (_) {
                    final has = _hasRequiredExample;
                    if (has != _lastHasRequired) {
                      _lastHasRequired = has;
                      setState(() {});
                    }
                  }
                : null,
            maxLines: 3,
            minLines: 2,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 12,
            ),
            decoration: InputDecoration(
              labelText: isFirst
                  ? (_isFrench ? 'Votre texte (requis)' : 'Your text (required)')
                  : (_isFrench ? 'Votre texte' : 'Your text'),
              labelStyle: const TextStyle(
                color: AppTheme.textTertiary,
                fontSize: 12,
              ),
              hintText: _isFrench
                  ? 'Écrivez un texte de prédiction pour ce scénario...'
                  : 'Write a prediction text for this scenario...',
              hintStyle: TextStyle(
                color: AppTheme.textTertiary.withValues(alpha: 0.5),
                fontSize: 11,
              ),
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              filled: true,
              fillColor: AppTheme.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: AppTheme.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: AppTheme.border),
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _isHMPattern(String key) {
    return key.isNotEmpty && key.split('').every((c) => c == 'H' || c == 'M');
  }

  Widget _buildScenarioSequences(String pattern) {
    final perfSeq = widget.performerSequenceIndices!;
    final labels = widget.options!;
    final nbOptions = labels.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Spectator sequence
        Row(
          children: [
            const Text('S: ', style: TextStyle(fontSize: 10, color: AppTheme.textTertiary, fontWeight: FontWeight.w600)),
            for (int i = 0; i < pattern.length; i++) ...[
              if (i > 0) const Text(', ', style: TextStyle(fontSize: 10, color: AppTheme.textTertiary)),
              Text(
                pattern[i] == 'H'
                    ? (i < perfSeq.length && perfSeq[i] < labels.length ? labels[perfSeq[i]] : '?')
                    : (nbOptions == 2 && i < perfSeq.length && perfSeq[i] < labels.length
                        ? labels[1 - perfSeq[i]]
                        : '≠${i < perfSeq.length && perfSeq[i] < labels.length ? labels[perfSeq[i]] : '?'}'),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: pattern[i] == 'H' ? Colors.green : Colors.red.shade300,
                ),
              ),
            ],
          ],
        ),
        // Performer sequence
        Row(
          children: [
            const Text('P: ', style: TextStyle(fontSize: 10, color: AppTheme.textTertiary, fontWeight: FontWeight.w600)),
            for (int i = 0; i < pattern.length; i++) ...[
              if (i > 0) const Text(', ', style: TextStyle(fontSize: 10, color: AppTheme.textTertiary)),
              Text(
                i < perfSeq.length && perfSeq[i] < labels.length ? labels[perfSeq[i]] : '?',
                style: const TextStyle(fontSize: 10, color: AppTheme.textTertiary),
              ),
            ],
          ],
        ),
      ],
    );
  }

  void _showScenarioInfo(ExampleScenario scenario) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                scenario.displayKey,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primary,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                scenario.summary,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          scenario.tooltip,
          style: const TextStyle(
            fontSize: 13,
            color: AppTheme.textSecondary,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _buildVariablesBlock() {
    final exCount = _exampleControllers
        .where((c) => c.text.trim().isNotEmpty)
        .length;

    final vars = <_RecapRow>[
      _RecapRow(_isFrench ? 'Langue' : 'Language', _langCode),
      _RecapRow(_isFrench ? 'Temps' : 'Tense', _tense),
      _RecapRow('Style', _styleValue),
      _RecapRow(_isFrench ? 'Exemples' : 'Examples', '$exCount'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          for (int i = 0; i < vars.length; i++) ...[
            if (i > 0)
              Divider(
                  height: 1,
                  color: AppTheme.primary.withValues(alpha: 0.1)),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                children: [
                  SizedBox(
                    width: 100,
                    child: Text(
                      vars[i].label,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      vars[i].value,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: AppTheme.textSecondary,
      ),
    );
  }

  Widget _buildSegmentedSelector({
    required String value,
    required List<String> items,
    required List<String> labels,
    required ValueChanged<String> onChanged,
  }) {
    return Row(
      children: [
        for (int i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: GestureDetector(
              onTap: () => onChanged(items[i]),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: value == items[i]
                      ? AppTheme.primary.withValues(alpha: 0.15)
                      : AppTheme.surface,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: value == items[i]
                        ? AppTheme.primary
                        : AppTheme.border,
                  ),
                ),
                child: Center(
                  child: Text(
                    labels[i],
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: value == items[i]
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color: value == items[i]
                          ? AppTheme.primary
                          : AppTheme.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // STEP C — PASTE + VALIDATE + IMPORT
  // ═══════════════════════════════════════════════════════════════

  Widget _buildStepPaste() {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isFrench
                      ? 'Collez le JSON renvoyé par votre LLM ci-dessous.'
                      : 'Paste the JSON returned by your LLM below.',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 12),

                // JSON text field
                TextField(
                  controller: _jsonController,
                  onChanged: (_) => setState(() {}),
                  maxLines: 10,
                  minLines: 6,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: AppTheme.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: '{ "meta": { ... }, "entries": { ... } }',
                    hintStyle: TextStyle(
                      color: AppTheme.textTertiary.withValues(alpha: 0.5),
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                    filled: true,
                    fillColor: AppTheme.background,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          const BorderSide(color: AppTheme.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          const BorderSide(color: AppTheme.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(
                          color: AppTheme.primary, width: 2),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Validate button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _jsonController.text.trim().isEmpty
                        ? null
                        : _doValidate,
                    icon: const Icon(Icons.check_circle_outline, size: 18),
                    label: Text(_isFrench ? 'Valider' : 'Validate'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primary,
                      side: const BorderSide(color: AppTheme.primary),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),

                // Validation result
                if (_validationResult != null) ...[
                  const SizedBox(height: 16),
                  _buildValidationResult(),
                ],
              ],
            ),
          ),
        ),

        // Bottom buttons
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => setState(() {
                    _currentStep = 2;
                    _validationResult = null;
                  }),
                  icon: const Icon(Icons.arrow_back, size: 16),
                  label: Text(_isFrench ? 'Retour' : 'Back'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.textSecondary,
                    side: const BorderSide(color: AppTheme.border),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: (_validationResult?.isValid == true)
                      ? _doImport
                      : null,
                  icon: const Icon(Icons.upload_file, size: 18),
                  label: Text(_isFrench ? 'Importer' : 'Import'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppTheme.surfaceLight,
                    disabledForegroundColor: AppTheme.textTertiary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── Validation result display ──────────────────────────────────

  Widget _buildValidationResult() {
    final result = _validationResult!;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: result.isValid
            ? Colors.green.withValues(alpha: 0.1)
            : Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: result.isValid
              ? Colors.green.withValues(alpha: 0.3)
              : Colors.red.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status header
          Row(
            children: [
              Icon(
                result.isValid ? Icons.check_circle : Icons.error,
                color: result.isValid ? Colors.green : Colors.red,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  result.isValid
                      ? 'Validation OK'
                      : (_isFrench
                          ? 'Erreurs de validation'
                          : 'Validation errors'),
                  style: TextStyle(
                    color: result.isValid ? Colors.green : Colors.red,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
              Text(
                '${result.foundCount}/${result.expectedCount}',
                style: TextStyle(
                  color: result.isValid ? Colors.green : Colors.red,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),

          // Errors
          if (result.errors.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (final error in result.errors)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('  • ',
                        style:
                            TextStyle(color: Colors.red, fontSize: 12)),
                    Expanded(
                      child: Text(
                        error,
                        style: const TextStyle(
                            color: Colors.red, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
          ],

          // Preview samples
          if (result.previewSamples.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              _isFrench ? 'Aperçu (3 premiers)' : 'Preview (first 3)',
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            for (final sample in result.previewSamples)
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.background,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sample.key,
                      style: const TextStyle(
                        color: AppTheme.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      sample.value.length > 120
                          ? '${sample.value.substring(0, 120)}...'
                          : sample.value,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 11,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// Helper for recap rows.
class _RecapRow {
  final String label;
  final String value;
  const _RecapRow(this.label, this.value);
}
