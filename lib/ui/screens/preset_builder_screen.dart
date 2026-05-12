import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../../models/models.dart';
import '../../utils/presets_provider.dart';
import '../../utils/settings_provider.dart';
import '../../engine/duel_firstto_buckets.dart';
import '../../engine/free_will_bank_fr.dart';
import '../../engine/number_engine.dart';
import '../../inputs/volume_input_controller.dart';
import '../../services/external_api_service.dart';
import '../../services/cloudinary_service.dart';
import '../../inputs/clock_swipe_input_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/preprogrammed_bank_editor.dart';
import '../../engine/bank_validator.dart';
import '../widgets/bank_import_modal.dart';
import '../widgets/output_override_section.dart';
import '../../utils/template_preview.dart';
import '../../services/bank_image_store.dart';

class PresetBuilderScreen extends StatefulWidget {
  const PresetBuilderScreen({super.key});

  @override
  State<PresetBuilderScreen> createState() => _PresetBuilderScreenState();
}

class _PresetBuilderScreenState extends State<PresetBuilderScreen> {
  late TextEditingController _nameController;
  late List<TextEditingController> _labelControllers;

  // Language from global settings
  Language get _language => context.read<SettingsProvider>().appLanguage;

  // Required fields
  PresetType _type = PresetType.choices;
  int _nbRounds = 3;
  DuelMode _duelMode = DuelMode.fixedRounds;
  PreprogrammedTieStrategy _preprogrammedTieStrategy = PreprogrammedTieStrategy.repeat;
  int _targetScore = 3;
  InputMode _inputMode = InputMode.preprogrammed;
  StealthInputMethod _stealthInputMethod = StealthInputMethod.volume;
  TextEditingController? _audioStartSentenceController;
  TextEditingController? _audioStopSentenceController;
  TapLayout2 _tapLayout2 = TapLayout2.topBottom;
  TapLayout4 _tapLayout4 = TapLayout4.corners;
  List<int> _performerSequence = [];
  String _audioLocale = 'fr_FR';

  // Multiple Out
  List<TextEditingController> _multipleOutControllers = [];
  List<TextEditingController> _multipleOutTitleControllers = [];
  bool _multipleOutShowTitles = false; // Per-text titles (mostly for Assistant mode)
  List<TextEditingController> _multipleOutKeywordControllers = [];

  // Number mode
  NumberMode? _numberMode;
  TextEditingController _numberFormulaController = TextEditingController(text: '_ * _ + _');
  TextEditingController _numberNotesTemplateController = TextEditingController();
  bool _numberIncludeTime = false;
  TextEditingController _numberOffsetController = TextEditingController(text: '0');
  String? _numberOutputMode = 'calculator';

  // Output mode
  String _outputMode = 'notes';
  String _imageAfterSave = 'black';
  Map<String, String> _bankImages = {};
  int _imageTimestampOffset = 0;

  // Per-preset overrides for auto-copy / shortcut (null = inherit globals)
  bool? _autoCopyOverride;
  final TextEditingController _assistantRedirectUrlController = TextEditingController();
  String? _shortcutNameOverride;
  final TextEditingController _shortcutNameOverrideController = TextEditingController();
  // Per-preset decoy template id (null = inherit global default)
  String? _decoyTemplateId;
  // Decoy input gesture: 'tap' or 'swipe'
  String _decoyInputType = 'tap';

  // Acrostic position
  int _acrosticPosition = 0; // 0=auto, 1-6=fixed, -1=input

  // Custom swipe patterns (for clockSwipe on Choices)
  List<List<String>>? _swipePatterns; // Each entry = list of directions e.g. ['up', 'right']

  TextEditingController? _focusedMultipleOutController;

  // Custom preprogrammed banks
  Map<String, Map<String, String>>? _customPreprogrammedBanks;

  // Custom duel bank templates (bucket key -> text)
  Map<String, String>? _customDuelBankTemplates;

  // Custom CHOICES bank templates (bucket key -> text)
  // bucketKey format: "rounds|hits" (ex: "3|2" = 3 rounds, 2 hits)
  Map<String, String>? _customChoicesBankTemplates;

  // CHOICES narrative mode (buckets vs sequences) - only for 2 options + 1-5 rounds
  ChoicesNarrativeMode _choicesNarrativeMode = ChoicesNarrativeMode.buckets;

  // DUEL narrative mode (buckets vs sequences) - fixedRounds only, <= 5 rounds
  ChoicesNarrativeMode _duelNarrativeMode = ChoicesNarrativeMode.buckets;

  // FREE_WILL fields
  FreeWillInputMode _freeWillInputMode = FreeWillInputMode.byAction;
  List<FreeWillAction> _freeWillActionOrder = [FreeWillAction.take, FreeWillAction.give, FreeWillAction.table];
  List<int> _freeWillObjectOrder = [0, 1, 2];
  bool _suggestChangeOfMind = true;
  TextEditingController? _changeMindTextController;
  TextEditingController? _noChangeMindTextController;
  Map<String, String>? _customFreeWillBankTemplates;
  String _freeWillBankMode = 'six'; // 'six' | 'single'
  final TextEditingController _freeWillSingleTemplateController = TextEditingController();
  TapOrientation _tapOrientation = TapOrientation.horizontal;

  bool _isEditing = false;
  String? _editingId;
  Map<String, String?> _errors = {};

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _audioStartSentenceController = TextEditingController();
    _audioStopSentenceController = TextEditingController();
    _labelControllers = [
      TextEditingController(text: 'Option A'),
      TextEditingController(text: 'Option B'),
    ];
    _performerSequence = List.filled(_nbRounds, 0);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Preset && !_isEditing) {
      // Check if this is a new preset (empty id/name) or editing existing
      if (args.id.isNotEmpty && args.name.isNotEmpty) {
        _loadPreset(args);
      } else {
        // New preset with type pre-selected from home screen modal
        _loadPresetType(args);
      }
    }
  }

  /// Load only the type and initial values for a new preset
  void _loadPresetType(Preset skeleton) {
    setState(() {
      _isEditing = true; // Prevent re-loading on didChangeDependencies
      _type = skeleton.type;
      if (skeleton.type == PresetType.duel) {
        // Set up duel-specific defaults
        for (final c in _labelControllers) {
          c.dispose();
        }
        _labelControllers = skeleton.labels
            .map((l) => TextEditingController(text: l))
            .toList();
        _inputMode = skeleton.inputMode;
      } else if (skeleton.type == PresetType.number) {
        _numberMode = skeleton.numberMode ?? NumberMode.rainman;
        _stealthInputMethod = skeleton.stealthInputMethod;
        _numberOutputMode = skeleton.numberOutputMode ?? 'calculator';
      } else if (skeleton.type == PresetType.multipleOut) {
        _stealthInputMethod = skeleton.stealthInputMethod;
        for (final c in _multipleOutControllers) { c.dispose(); }
        for (final c in _multipleOutTitleControllers) { c.dispose(); }
        for (final c in _multipleOutKeywordControllers) { c.dispose(); }
        _multipleOutControllers = [TextEditingController(), TextEditingController()];
        _multipleOutTitleControllers = [TextEditingController(), TextEditingController()];
        _multipleOutKeywordControllers = [TextEditingController(), TextEditingController()];
      } else if (skeleton.type == PresetType.freeWill) {
        // Set up free will-specific defaults
        for (final c in _labelControllers) {
          c.dispose();
        }
        final config = skeleton.freeWillConfig ?? FreeWillConfig.defaultConfig();
        _labelControllers = config.objects
            .map((l) => TextEditingController(text: l))
            .toList();
        _freeWillInputMode = config.inputMode;
        _freeWillActionOrder = List.from(config.actionOrder);
        _freeWillObjectOrder = List.from(config.objectOrder);
        _suggestChangeOfMind = config.suggestChangeOfMind;
      }
    });
  }

  void _loadPreset(Preset preset) {
    setState(() {
      _isEditing = true;
      _editingId = preset.id;
      _nameController.text = preset.name;
      _type = preset.type;
      // predictionMode always game (no UI selector)
      _nbRounds = preset.nbRounds.clamp(1, 5);
      _duelMode = preset.duelMode;
      _targetScore = preset.targetScore.clamp(1, 5);
      _preprogrammedTieStrategy = preset.preprogrammedTieStrategy;
      _inputMode = preset.inputMode;
      // Migrate legacy presets that used Assistant as input method — it's now
      // a global mode, not a per-preset option. Default to Volume.
      _stealthInputMethod = preset.stealthInputMethod == StealthInputMethod.assistant
          ? StealthInputMethod.volume
          : preset.stealthInputMethod;
      _audioStartSentenceController?.text = preset.audioStartSentence ?? '';
      _audioStopSentenceController?.text = preset.audioStopSentence ?? '';
      _audioLocale = preset.audioLocale;
      _tapLayout2 = preset.tapLayout2;
      _tapLayout4 = preset.tapLayout4;
      _performerSequence = preset.performerSequence != null
          ? List.from(preset.performerSequence!)
          : List.filled(_nbRounds, 0);

      // Appellation: always defaults (no UI)

      // Load custom preprogrammed banks
      _customPreprogrammedBanks = preset.customPreprogrammedBanks != null
          ? Map.from(preset.customPreprogrammedBanks!.map(
              (k, v) => MapEntry(k, Map<String, String>.from(v))))
          : null;

      // Load custom duel bank templates
      _customDuelBankTemplates = preset.customDuelBankTemplates != null
          ? Map<String, String>.from(preset.customDuelBankTemplates!)
          : null;

      // Load custom CHOICES bank templates
      _customChoicesBankTemplates = preset.customChoicesBankTemplates != null
          ? Map<String, String>.from(preset.customChoicesBankTemplates!)
          : null;

      // Load CHOICES narrative mode
      _choicesNarrativeMode = preset.choicesNarrativeMode;
      _duelNarrativeMode = preset.duelNarrativeMode;

      // Load FREE_WILL config
      if (preset.type == PresetType.freeWill && preset.freeWillConfig != null) {
        final config = preset.freeWillConfig!;
        _freeWillInputMode = config.inputMode;
        _freeWillActionOrder = List.from(config.actionOrder);
        _freeWillObjectOrder = List.from(config.objectOrder);
        _suggestChangeOfMind = config.suggestChangeOfMind;
        _tapOrientation = config.tapOrientation;
        _changeMindTextController?.dispose();
        _noChangeMindTextController?.dispose();
        _changeMindTextController = TextEditingController(text: config.changeMindText ?? '');
        _noChangeMindTextController = TextEditingController(text: config.noChangeMindText ?? '');
        _customFreeWillBankTemplates = preset.customFreeWillBankTemplates != null
            ? Map<String, String>.from(preset.customFreeWillBankTemplates!)
            : null;
        _freeWillBankMode = preset.freeWillBankMode;
        _freeWillSingleTemplateController.text = preset.freeWillSingleTemplate ?? '';
      }

      for (final c in _labelControllers) {
        c.dispose();
      }
      if (preset.type == PresetType.freeWill && preset.freeWillConfig != null) {
        _labelControllers = preset.freeWillConfig!.objects
            .map((l) => TextEditingController(text: l))
            .toList();
      } else {
        _labelControllers = preset.labels
            .map((l) => TextEditingController(text: l))
            .toList();
      }

      // Load Number config
      _numberMode = preset.numberMode;
      _numberFormulaController.text = preset.numberFormula ?? '_ * _ + _';
      _numberIncludeTime = preset.numberIncludeTime;
      _numberOffsetController.text = preset.numberMinutesOffset.toString();
      _numberOutputMode = preset.numberOutputMode ?? 'calculator';
      _numberNotesTemplateController.text = preset.numberNotesTemplate ?? '';

      // Load swipe patterns
      if (preset.swipePatterns != null) {
        _swipePatterns = preset.swipePatterns!
            .map((p) => p.split(','))
            .toList();
      }

      // Load acrostic position
      _acrosticPosition = preset.acrosticPosition;
      _outputMode = preset.outputMode;
      _imageAfterSave = preset.imageAfterSave;
      _bankImages = Map.from(preset.bankImages ?? {});
      _imageTimestampOffset = preset.imageTimestampOffset;
      _autoCopyOverride = preset.autoCopyOverride;
      _assistantRedirectUrlController.text = preset.assistantRedirectUrl ?? '';
      _shortcutNameOverride = preset.shortcutNameOverride;
      _shortcutNameOverrideController.text = preset.shortcutNameOverride ?? '';
      _decoyTemplateId = preset.decoyTemplateId;
      _decoyInputType = preset.decoyInputType ?? 'tap';

      // Load Multiple Out texts
      if (preset.type == PresetType.multipleOut && preset.multipleOutTexts != null) {
        for (final c in _multipleOutControllers) { c.dispose(); }
        for (final c in _multipleOutTitleControllers) { c.dispose(); }
        for (final c in _multipleOutKeywordControllers) { c.dispose(); }
        _multipleOutControllers = preset.multipleOutTexts!
            .map((t) => TextEditingController(text: t))
            .toList();
        final titles = preset.multipleOutTitles ?? List.filled(preset.multipleOutTexts!.length, '');
        _multipleOutTitleControllers = titles
            .map((t) => TextEditingController(text: t))
            .toList();
        // If any saved title is non-empty, assume the user wants titles visible.
        _multipleOutShowTitles = titles.any((t) => t.trim().isNotEmpty);
        final keywords = preset.multipleOutKeywords ?? List.filled(preset.multipleOutTexts!.length, '');
        _multipleOutKeywordControllers = keywords
            .map((k) => TextEditingController(text: k))
            .toList();
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    for (final c in _labelControllers) {
      c.dispose();
    }
    _changeMindTextController?.dispose();
    _noChangeMindTextController?.dispose();
    for (final c in _multipleOutControllers) { c.dispose(); }
    for (final c in _multipleOutTitleControllers) { c.dispose(); }
    for (final c in _multipleOutKeywordControllers) { c.dispose(); }
    _numberFormulaController.dispose();
    _numberOffsetController.dispose();
    _assistantRedirectUrlController.dispose();
    _shortcutNameOverrideController.dispose();
    super.dispose();
  }

  int get _nbOptions => _labelControllers.length;

  List<String> _getLabels() {
    return _labelControllers.map((c) => c.text.trim()).toList();
  }

  void _addOption() {
    if (_type == PresetType.duel || _nbOptions >= 6) return;
    setState(() {
      _labelControllers.add(TextEditingController(text: 'Option ${String.fromCharCode(65 + _nbOptions)}'));
      _errors.clear();
    });
  }

  void _removeOption(int index) {
    if (_type == PresetType.duel || _nbOptions <= 2) return;
    setState(() {
      _labelControllers[index].dispose();
      _labelControllers.removeAt(index);
      // Update performer sequence
      _performerSequence = _performerSequence.map((idx) {
        if (idx >= _nbOptions) return _nbOptions - 1;
        return idx;
      }).toList();
      _errors.clear();
    });
  }

  void _onNbRoundsChanged(int value) {
    setState(() {
      _nbRounds = value;
      // Adjust performer sequence
      if (_performerSequence.length < _nbRounds) {
        _performerSequence = [
          ..._performerSequence,
          ...List.filled(_nbRounds - _performerSequence.length, 0),
        ];
      } else if (_performerSequence.length > _nbRounds) {
        _performerSequence = _performerSequence.take(_nbRounds).toList();
      }
      _errors.clear();
    });
  }

  bool _validate() {
    final errors = <String, String?>{};

    // Name validation
    if (_nameController.text.trim().isEmpty) {
      errors['name'] = _language == Language.french
          ? 'Le nom est requis'
          : 'Preset name is required';
    }

    // Multiple Out validation
    if (_type == PresetType.multipleOut) {
      if (_multipleOutControllers.length < 2) {
        errors['multipleOut'] = 'At least 2 texts required';
      } else {
        for (int i = 0; i < _multipleOutControllers.length; i++) {
          if (_multipleOutControllers[i].text.trim().isEmpty) {
            errors['multipleOut_$i'] = _language == Language.french
                ? 'Le texte ${i + 1} ne peut pas être vide'
                : 'Text ${i + 1} cannot be empty';
          }
        }
      }
      setState(() => _errors = errors);
      return errors.isEmpty;
    }

    // Labels validation
    final labels = _getLabels();
    for (int i = 0; i < labels.length; i++) {
      if (labels[i].isEmpty) {
        errors['label_$i'] = _language == Language.french
            ? 'Le label ne peut pas être vide'
            : 'Label cannot be empty';
      }
    }

    // Check uniqueness (case-insensitive)
    final lowerLabels = labels.map((l) => l.toLowerCase()).toList();
    final seen = <String>{};
    for (int i = 0; i < lowerLabels.length; i++) {
      if (lowerLabels[i].isNotEmpty && seen.contains(lowerLabels[i])) {
        errors['label_$i'] = _language == Language.french
            ? 'Les labels doivent être uniques'
            : 'Labels must be unique';
      }
      seen.add(lowerLabels[i]);
    }

    // Preprogrammed sequence validation — only applies to choices/duel.
    // Free Will, Multiple Out and Number do not use a performer sequence.
    final bool _needsPerformerSequence = _type == PresetType.choices || _type == PresetType.duel;
    if (_needsPerformerSequence && _inputMode == InputMode.preprogrammed) {
      // For First-To mode, minimum sequence = (targetScore * 2) - 1
      // For Fixed Rounds mode, sequence must match nbRounds
      final bool isFirstTo = _type == PresetType.duel && _duelMode == DuelMode.firstTo;
      final int requiredLength = isFirstTo ? (_targetScore * 2) - 1 : _nbRounds;

      if (isFirstTo) {
        if (_performerSequence.length < requiredLength) {
          errors['sequence'] = _language == Language.french
              ? 'La séquence doit avoir au moins $requiredLength sélections pour Premier à $_targetScore'
              : 'Performer sequence must have at least $requiredLength selections for First-To $_targetScore';
        }
      } else {
        if (_performerSequence.length != requiredLength) {
          errors['sequence'] = _language == Language.french
              ? 'La séquence doit avoir $requiredLength sélections'
              : 'Performer sequence must have $requiredLength selections';
        }
      }
      for (int i = 0; i < _performerSequence.length; i++) {
        final idx = _performerSequence[i];
        if (idx < 0 || idx >= _nbOptions) {
          errors['sequence_$i'] = _language == Language.french
              ? 'Sélection invalide au round ${i + 1}'
              : 'Invalid selection at round ${i + 1}';
        }
      }
    }

    // Number template placeholder validation — surfaces typos like ((Resut))
    // before save instead of letting them silently appear in the final text.
    if (_type == PresetType.number &&
        (_numberOutputMode ?? 'calculator') == 'notes') {
      final tpl = _numberNotesTemplateController.text;
      if (tpl.trim().isNotEmpty) {
        const allowed = {'Result', 'DayOfBirth', 'nbDays'};
        final tokens = RegExp(r'\(\(([^)]+)\)\)').allMatches(tpl);
        final unknown = <String>{};
        for (final m in tokens) {
          final name = m.group(1)?.trim() ?? '';
          if (name.isNotEmpty && !allowed.contains(name)) {
            unknown.add(name);
          }
        }
        if (unknown.isNotEmpty) {
          errors['number_template'] = _language == Language.french
              ? 'Variable(s) inconnue(s) dans le template : ${unknown.join(", ")}. Utilise ((Result)), ((DayOfBirth)), ((numDays)).'
              : 'Unknown placeholder(s) in template: ${unknown.join(", ")}. Use ((Result)), ((DayOfBirth)), ((numDays)).';
        }
      }
    }

    // Bank completeness: warnings only (don't block save)
    // These are stored in errors for display but _validate() still returns true for save
    final bankWarnings = <String, String?>{};
    if (_type == PresetType.duel) {
      if (_duelMode == DuelMode.fixedRounds) {
        // Duel Fixed Rounds: check all bucket keys filled
        final expectedKeys = <String>[];
        for (int s = 0; s <= _nbRounds; s++) {
          for (int p = 0; p <= _nbRounds - s; p++) {
            expectedKeys.add('$_nbRounds|$s-$p');
          }
        }
        final missing = expectedKeys.where((k) =>
            _customDuelBankTemplates == null ||
            (_customDuelBankTemplates![k]?.trim().isEmpty ?? true)).length;
        if (missing > 0) {
          bankWarnings['bank'] = _language == Language.french
              ? '$missing texte(s) manquant(s) dans la banque de narration'
              : '$missing missing text(s) in the narrative bank';
        }
        // Also check preprogrammed bank if applicable
        if (_inputMode == InputMode.preprogrammed && _nbRounds <= 5) {
          final performerKey = _performerSequence.map((idx) => idx == 0 ? '1' : '2').join();
          final spectatorCount = 1 << _nbRounds; // 2^nbRounds
          final bank = _customPreprogrammedBanks?[performerKey] ?? {};
          final filledCount = bank.values.where((t) => t.trim().isNotEmpty).length;
          if (filledCount < spectatorCount) {
            bankWarnings['preprogrammed_bank'] = _language == Language.french
                ? '${spectatorCount - filledCount} texte(s) manquant(s) dans la banque séquentielle'
                : '${spectatorCount - filledCount} missing text(s) in the sequence bank';
          }
        }
      } else {
        // Duel First-To: check all bucket keys filled
        final expectedKeys = DuelFirstToBuckets.generateBucketKeysForTarget(_targetScore);
        final missing = expectedKeys.where((k) =>
            _customDuelBankTemplates == null ||
            (_customDuelBankTemplates![k]?.trim().isEmpty ?? true)).length;
        if (missing > 0) {
          bankWarnings['bank'] = _language == Language.french
              ? '$missing texte(s) manquant(s) dans la banque de narration'
              : '$missing missing text(s) in the narrative bank';
        }
      }
    } else if (_type == PresetType.choices) {
      // Choices H/M pattern bank validation
      {
        final total = 1 << _nbRounds; // 2^nbRounds
        int missing = 0;
        for (int i = 0; i < total; i++) {
          final buf = StringBuffer();
          for (int bit = _nbRounds - 1; bit >= 0; bit--) {
            buf.write((i >> bit) & 1 == 0 ? 'H' : 'M');
          }
          final key = buf.toString();
          if (_customChoicesBankTemplates == null ||
              (_customChoicesBankTemplates![key]?.trim().isEmpty ?? true)) {
            missing++;
          }
        }
        if (missing > 0) {
          bankWarnings['bank'] = _language == Language.french
              ? '$missing texte(s) manquant(s) dans la banque de narration'
              : '$missing missing text(s) in the narrative bank';
        }
      }
    } else if (_type == PresetType.freeWill) {
      // Free Will: check all 6 permutation keys filled
      final expectedKeys = FreeWillBankGeneratorFR.generateAllBucketKeys(_getLabels());
      final missing = expectedKeys.where((k) =>
          _customFreeWillBankTemplates == null ||
          (_customFreeWillBankTemplates![k]?.trim().isEmpty ?? true)).length;
      if (missing > 0) {
        bankWarnings['bank'] = _language == Language.french
            ? '$missing texte(s) manquant(s) dans la banque de narration'
            : '$missing missing text(s) in the narrative bank';
      }
    }

    setState(() {
      _errors = {...errors, ...bankWarnings};
    });

    // Only structural errors block save, not bank completeness warnings
    return errors.isEmpty;
  }

  Future<void> _save() async {
    if (!_validate()) {
      // Show the most relevant error (bank errors are most useful)
      final bankError = _errors['bank'] ?? _errors['preprogrammed_bank'];
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(bankError ?? (_language == Language.french
              ? 'Veuillez corriger les erreurs avant de sauvegarder'
              : 'Please fix the errors before saving')),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final effectiveInputMode = _inputMode;

    // Build FREE_WILL config if applicable
    FreeWillConfig? freeWillConfig;
    if (_type == PresetType.freeWill) {
      freeWillConfig = FreeWillConfig(
        objects: _getLabels(), // Labels are the object names for freeWill
        actionOrder: _freeWillActionOrder,
        objectOrder: _freeWillObjectOrder,
        inputMode: _freeWillInputMode,
        suggestChangeOfMind: _suggestChangeOfMind,
        changeMindText: _changeMindTextController?.text.trim().isNotEmpty == true
            ? _changeMindTextController!.text.trim()
            : null,
        noChangeMindText: _noChangeMindTextController?.text.trim().isNotEmpty == true
            ? _noChangeMindTextController!.text.trim()
            : null,
        tapOrientation: _tapOrientation,
      );
    }

    final preset = Preset(
      id: _editingId,
      name: _nameController.text.trim(),
      type: _type,
      numberMode: _type == PresetType.number ? _numberMode : null,
      numberFormula: _type == PresetType.number ? _numberFormulaController.text.trim() : null,
      numberIncludeTime: _numberIncludeTime,
      numberMinutesOffset: int.tryParse(_numberOffsetController.text) ?? 0,
      numberOutputMode: _type == PresetType.number ? _numberOutputMode : null,
      numberNotesTemplate: _type == PresetType.number && _numberOutputMode == 'notes'
          ? (_numberNotesTemplateController.text.trim().isEmpty ? null : _numberNotesTemplateController.text)
          : null,
      acrosticPosition: _acrosticPosition,
      outputMode: _outputMode,
      imageAfterSave: _imageAfterSave,
      bankImages: _bankImages.isEmpty ? null : _bankImages,
      imageTimestampOffset: _imageTimestampOffset,
      autoCopyOverride: _autoCopyOverride,
      shortcutNameOverride: _shortcutNameOverride,
      assistantRedirectUrl: _assistantRedirectUrlController.text.trim().isEmpty
          ? null
          : _assistantRedirectUrlController.text.trim(),
      decoyTemplateId: _decoyTemplateId,
      decoyInputType: _decoyInputType,
      language: _language,
      predictionMode: PredictionMode.game,
      nbRounds: (_type == PresetType.freeWill || _type == PresetType.multipleOut || _type == PresetType.number) ? 1 : _nbRounds,
      duelMode: _duelMode,
      targetScore: _targetScore,
      preprogrammedTieStrategy: _preprogrammedTieStrategy,
      nbOptions: _nbOptions,
      labels: _getLabels(),
      inputMode: effectiveInputMode,
      performerSequence: (_inputMode == InputMode.preprogrammed)
          ? _performerSequence
          : null,
      stealthInputMethod: _stealthInputMethod,
      audioStartSentence: _audioStartSentenceController?.text.trim().isNotEmpty == true ? _audioStartSentenceController!.text.trim() : null,
      audioStopSentence: _audioStopSentenceController?.text.trim().isNotEmpty == true ? _audioStopSentenceController!.text.trim() : null,
      audioLocale: _audioLocale,
      tapLayout2: _tapLayout2,
      tapLayout4: _tapLayout4,
      // Fall back to default patterns when the user picked Swipe but never
      // opened the pattern editor — otherwise we'd silently save a clockSwipe
      // preset with no patterns and the runtime swipe controller would be
      // skipped (= swipes ignored).
      swipePatterns: _stealthInputMethod == StealthInputMethod.clockSwipe
          ? (_swipePatterns ?? _getDefaultSwipePatterns(_nbOptions))
              .map((dirs) => dirs.join(','))
              .toList()
          : null,
      customPreprogrammedBanks: _customPreprogrammedBanks,
      customDuelBankTemplates: _customDuelBankTemplates,
      customChoicesBankTemplates: _type == PresetType.choices ? _customChoicesBankTemplates : null,
      choicesNarrativeMode: _choicesNarrativeMode,
      duelNarrativeMode: _duelNarrativeMode,
      freeWillConfig: freeWillConfig,
      customFreeWillBankTemplates: _type == PresetType.freeWill ? _customFreeWillBankTemplates : null,
      freeWillBankMode: _type == PresetType.freeWill ? _freeWillBankMode : 'six',
      freeWillSingleTemplate: _type == PresetType.freeWill && _freeWillSingleTemplateController.text.trim().isNotEmpty
          ? _freeWillSingleTemplateController.text
          : null,
      multipleOutTexts: _type == PresetType.multipleOut
          ? _multipleOutControllers.map((c) => c.text).toList()
          : null,
      multipleOutTitles: _type == PresetType.multipleOut
          ? _multipleOutTitleControllers.map((c) => c.text).toList()
          : null,
      multipleOutKeywords: _type == PresetType.multipleOut && _stealthInputMethod == StealthInputMethod.audio
          ? _multipleOutKeywordControllers.map((c) => c.text).toList()
          : null,
    );

    final provider = context.read<PresetsProvider>();
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

  Widget _buildAcrosticPosChip(String label, int value) {
    final isSelected = _acrosticPosition == value;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        onTap: () => setState(() => _acrosticPosition = value),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primary : AppTheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isSelected ? AppTheme.primary : AppTheme.border),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w600,
              color: isSelected ? Colors.white : AppTheme.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  /// Default swipe patterns sized to the option count.
  /// - ≤ 4 options: single-swipe directions (up / right / down / left).
  /// - 5–12 options: 2-swipe clock positions (1h … 12h).
  /// - 13+ options: 4-swipe combos (two 2-swipe clock positions).
  ///
  /// All patterns in a returned list always share the same number of swipes,
  /// which is required for the preset to be playable.
  static List<List<String>> _getDefaultSwipePatterns(int count) {
    const singles = <String>['up', 'right', 'down', 'left'];
    const clock = <List<String>>[
      ['up', 'right'],    // 1h
      ['right', 'up'],    // 2h
      ['right', 'right'], // 3h
      ['right', 'down'],  // 4h
      ['down', 'right'],  // 5h
      ['down', 'down'],   // 6h
      ['down', 'left'],   // 7h
      ['left', 'down'],   // 8h
      ['left', 'left'],   // 9h
      ['left', 'up'],     // 10h
      ['up', 'left'],     // 11h
      ['up', 'up'],       // 12h
    ];

    if (count <= 4) {
      return List.generate(count, (i) => [singles[i]]);
    }
    if (count <= 12) {
      return List.generate(count, (i) => List<String>.from(clock[i]));
    }
    // 13+: 4-swipe combos (up to 144 unique).
    return List.generate(count, (i) {
      final tens = (i ~/ 12).clamp(0, 11);
      final units = i % 12;
      return [...clock[tens], ...clock[units]];
    });
  }

  static String _dirToArrow(String dir) {
    switch (dir) {
      case 'up': return '↑';
      case 'down': return '↓';
      case 'left': return '←';
      case 'right': return '→';
      default: return '?';
    }
  }

  void _editSwipePattern(int index) {
    final current = List<String>.from(_swipePatterns![index]);
    final editing = List<String>.from(current);
    // No fixed length cap — performer can build patterns of any length. The
    // preset is only `isPlayable` once every pattern shares the same length
    // (validated separately in Preset.isPlayable).

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setDialogState) {
          final arrows = editing.map(_dirToArrow).join(' ');
          return AlertDialog(
            backgroundColor: AppTheme.surface,
            title: Text(
              '${_getLabels()[index]}',
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(arrows, style: const TextStyle(fontSize: 32, letterSpacing: 8)),
                const SizedBox(height: 20),
                // Arrow buttons (no length cap — pass null)
                SizedBox(
                  width: 180,
                  height: 180,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned(top: 0, child: _arrowButton('up', editing, null, setDialogState)),
                      Positioned(bottom: 0, child: _arrowButton('down', editing, null, setDialogState)),
                      Positioned(left: 0, child: _arrowButton('left', editing, null, setDialogState)),
                      Positioned(right: 0, child: _arrowButton('right', editing, null, setDialogState)),
                      GestureDetector(
                        onTap: () => setDialogState(() => editing.clear()),
                        child: Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceLight,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Icon(Icons.refresh, size: 18, color: AppTheme.textTertiary),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _language == Language.french
                      ? '${editing.length} swipe${editing.length > 1 ? "s" : ""}'
                      : '${editing.length} swipe${editing.length > 1 ? "s" : ""}',
                  style: TextStyle(
                    fontSize: 12,
                    color: editing.isEmpty ? AppTheme.textTertiary : Colors.green,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              TextButton(
                onPressed: editing.isEmpty ? null : () {
                  final newPattern = editing.join(',');
                  for (int i = 0; i < _swipePatterns!.length; i++) {
                    if (i != index && _swipePatterns![i].join(',') == newPattern) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Pattern already used by ${_getLabels()[i]}')),
                      );
                      return;
                    }
                  }
                  setState(() {
                    _swipePatterns![index] = List.from(editing);
                  });
                  Navigator.pop(ctx);
                },
                child: const Text('OK'),
              ),
            ],
          );
        });
      },
    );
  }

  Widget _arrowButton(String dir, List<String> editing, int? maxLength, StateSetter setDialogState) {
    return GestureDetector(
      onTap: () {
        if (maxLength == null || editing.length < maxLength) {
          setDialogState(() => editing.add(dir));
        }
      },
      child: Container(
        width: 56, height: 56,
        decoration: BoxDecoration(
          color: AppTheme.primary.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: AppTheme.primary.withValues(alpha: 0.5)),
        ),
        child: Center(
          child: Text(_dirToArrow(dir), style: const TextStyle(fontSize: 28)),
        ),
      ),
    );
  }

  Widget _buildFreeWillInputPreview({
    required String title,
    required String subtitle,
    required List<_FreeWillPreviewItem> items,
    required void Function(int, int) onReorder,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
        const SizedBox(height: 4),
        Text(subtitle, style: TextStyle(fontSize: 10, color: AppTheme.textTertiary)),
        const SizedBox(height: 8),
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          proxyDecorator: (child, index, animation) => Material(
            color: Colors.transparent,
            elevation: 4,
            shadowColor: Colors.black54,
            borderRadius: BorderRadius.circular(8),
            child: child,
          ),
          onReorder: onReorder,
          itemCount: items.length,
          itemBuilder: (context, i) {
            final item = items[i];
            final isFR = _language == Language.french;
            return Container(
              key: ValueKey('fw_preview_$i'),
              margin: const EdgeInsets.only(bottom: 4),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: item.isAuto ? AppTheme.surface.withValues(alpha: 0.5) : AppTheme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: item.isAuto ? AppTheme.border.withValues(alpha: 0.5) : AppTheme.border),
              ),
              child: Row(
                children: [
                  if (!item.isAuto) Icon(Icons.drag_handle, size: 16, color: AppTheme.textTertiary),
                  if (!item.isAuto) const SizedBox(width: 8),
                  Text(
                    item.isAuto ? (isFR ? 'Auto' : 'Auto') : 'Input ${i + 1}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: item.isAuto ? AppTheme.textTertiary : AppTheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      item.fixed,
                      style: TextStyle(
                        fontSize: 13,
                        color: item.isAuto ? AppTheme.textTertiary : AppTheme.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Icon(Icons.arrow_forward, size: 14, color: AppTheme.textTertiary),
                  const SizedBox(width: 8),
                  Text(
                    item.isAuto ? (isFR ? 'déduit' : 'deduced') : item.variable,
                    style: TextStyle(
                      fontSize: 12,
                      fontStyle: item.isAuto ? FontStyle.italic : FontStyle.normal,
                      color: item.isAuto ? AppTheme.textTertiary : AppTheme.accent,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  /// Check if all narrative texts are ready
  bool _areAllTextsReady() {
    if (_type == PresetType.choices) {
      final templates = _customChoicesBankTemplates ?? {};
      final total = 1 << _nbRounds;
      for (int i = 0; i < total; i++) {
        final buf = StringBuffer();
        for (int bit = _nbRounds - 1; bit >= 0; bit--) {
          buf.write((i >> bit) & 1 == 0 ? 'H' : 'M');
        }
        if (templates[buf.toString()]?.trim().isNotEmpty != true) return false;
      }
      return true;
    } else if (_type == PresetType.duel) {
      final templates = _customDuelBankTemplates ?? {};
      return templates.values.any((t) => t.trim().isNotEmpty);
    } else if (_type == PresetType.freeWill) {
      // Match the runtime selection logic: validate the ACTIVE bank mode only.
      // 'single' → just the single template; 'six' → at least one of the 6.
      if (_freeWillBankMode == 'single') {
        return _freeWillSingleTemplateController.text.trim().isNotEmpty;
      }
      return _customFreeWillBankTemplates != null &&
          _customFreeWillBankTemplates!.values.any((t) => t.trim().isNotEmpty);
    } else if (_type == PresetType.multipleOut) {
      return _multipleOutControllers.length >= 2 && _multipleOutControllers.every((c) => c.text.trim().isNotEmpty);
    }
    return false;
  }

  /// Get all bank keys for current preset type
  List<String> _getBankKeys() {
    if (_type == PresetType.choices) {
      final total = 1 << _nbRounds; // 2^nbRounds
      return List.generate(total, (i) {
        final buf = StringBuffer();
        for (int bit = _nbRounds - 1; bit >= 0; bit--) {
          buf.write((i >> bit) & 1 == 0 ? 'H' : 'M');
        }
        return buf.toString();
      });
    } else if (_type == PresetType.duel) {
      if (_duelMode == DuelMode.fixedRounds) {
        final keys = <String>[];
        for (int s = 0; s <= _nbRounds; s++) {
          for (int p = 0; p <= _nbRounds - s; p++) {
            keys.add('$_nbRounds|$s-$p');
          }
        }
        return keys;
      } else {
        final keys = <String>[];
        for (int loser = 0; loser < _targetScore; loser++) {
          keys.add('FT${_targetScore}_S_$_targetScore-$loser');
          keys.add('FT${_targetScore}_P_$_targetScore-$loser');
        }
        return keys;
      }
    } else if (_type == PresetType.freeWill) {
      final objects = _getLabels();
      if (objects.length < 3) return [];
      final perms = [
        [0, 1, 2], [0, 2, 1], [1, 0, 2], [1, 2, 0], [2, 0, 1], [2, 1, 0],
      ];
      return perms.map((p) => 'TAKE:${objects[p[0]]}|GIVE:${objects[p[1]]}|TABLE:${objects[p[2]]}').toList();
    } else if (_type == PresetType.multipleOut) {
      return List.generate(_multipleOutControllers.length, (i) => '$i');
    }
    return [];
  }

  /// Format bank key for display
  String _formatBankKeyDisplay(String key) {
    if (_type == PresetType.choices) return key; // "HMH"
    if (_type == PresetType.duel) return key; // "3|1-2"
    if (_type == PresetType.freeWill) {
      // "TAKE:Clé|GIVE:Boîte|TABLE:Pièce" → "Clé → Boîte → Pièce"
      final parts = key.split('|');
      return parts.map((p) => p.split(':').last).join(' → ');
    }
    if (_type == PresetType.multipleOut) {
      final idx = int.tryParse(key) ?? 0;
      if (idx < _multipleOutTitleControllers.length && _multipleOutTitleControllers[idx].text.isNotEmpty) {
        return _multipleOutTitleControllers[idx].text;
      }
      return 'Text ${idx + 1}';
    }
    return key;
  }

  Future<void> _pickBankImage(String bankKey) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    // Content-addressed store that also copies to iCloud container for sync.
    final destPath = await BankImageStore.importFromSource(image.path);

    setState(() {
      _bankImages[bankKey] = destPath;
    });
  }

  void _showStealthInputHelp() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _StealthInputHelpSheet(locale: _language, labels: _getLabels()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool canSave = _validate();

    // Build dynamic title based on preset type
    final typeNameFR = _type == PresetType.freeWill
        ? 'Free Will'
        : _type == PresetType.duel
            ? 'Duel'
            : _type == PresetType.multipleOut
                ? 'Multiple Out'
                : _type == PresetType.number
                    ? 'Number'
                    : 'Choix';
    final typeNameEN = _type == PresetType.freeWill
        ? 'Free Will'
        : _type == PresetType.duel
            ? 'Duel'
            : _type == PresetType.multipleOut
                ? 'Multiple Out'
                : _type == PresetType.number
                    ? 'Number'
                    : 'Choices';

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        title: Text(_isEditing
            ? (_language == Language.french ? 'Modifier $typeNameFR' : 'Edit $typeNameEN')
            : (_language == Language.french ? 'Nouveau $typeNameFR' : 'New $typeNameEN')),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: canSave ? _save : null,
            child: Text(
              _language == Language.french ? 'Sauvegarder' : 'Save',
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
              // 1) Preset Name
              _SectionTitle(
                title: _language == Language.french ? 'Nom du Preset' : 'Preset Name',
                required: true,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _nameController,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: _language == Language.french
                      ? 'Entrez le nom du preset'
                      : 'Enter preset name',
                  errorText: _errors['name'],
                ),
                style: const TextStyle(color: AppTheme.textPrimary),
                onChanged: (_) => setState(() => _errors.remove('name')),
              ),

              const SizedBox(height: 16),

              // ==========================================
              // NUMBER SPECIFIC SECTIONS
              // ==========================================
              if (_type == PresetType.number) ...[
                const SizedBox(height: 24),
                // Number mode selector
                _SectionTitle(title: _language == Language.french ? 'Mode' : 'Mode', required: true),
                const SizedBox(height: 8),
                Row(
                  children: NumberMode.values.map((mode) {
                    final isSelected = (_numberMode ?? NumberMode.rainman) == mode;
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(right: mode != NumberMode.values.last ? 8 : 0),
                        child: GestureDetector(
                          onTap: () => setState(() => _numberMode = mode),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: isSelected ? AppTheme.primary : AppTheme.surface,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: isSelected ? AppTheme.primary : AppTheme.border),
                            ),
                            child: Center(
                              child: Text(
                                mode.displayName(french: _language == Language.french),
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                                    color: isSelected ? Colors.white : AppTheme.textSecondary),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),

                // Rainman: formula editor
                if ((_numberMode ?? NumberMode.rainman) == NumberMode.rainman) ...[
                  const SizedBox(height: 16),
                  _SectionTitle(title: _language == Language.french ? 'Formule' : 'Formula', required: true),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _numberFormulaController,
                    style: const TextStyle(fontSize: 16, color: AppTheme.textPrimary, fontFamily: 'monospace'),
                    decoration: InputDecoration(
                      hintText: '_ * _ + _ * _',
                      hintStyle: TextStyle(color: AppTheme.textTertiary),
                      filled: true, fillColor: AppTheme.surface,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.border)),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _language == Language.french
                        ? 'Utilisez _ pour chaque nombre et +, -, *, / comme opérateurs'
                        : 'Use _ for each number and +, -, *, / as operators',
                    style: TextStyle(fontSize: 10, color: AppTheme.textTertiary),
                  ),
                ],

                // Today: include time + offset
                if ((_numberMode ?? NumberMode.rainman) == NumberMode.today) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: SwitchListTile.adaptive(
                          title: Text(_language == Language.french ? 'Inclure l\'heure' : 'Include time',
                              style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary)),
                          value: _numberIncludeTime,
                          onChanged: (v) => setState(() => _numberIncludeTime = v),
                          activeColor: AppTheme.primary,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
                  if (_numberIncludeTime) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(_language == Language.french ? 'Décalage (minutes) :' : 'Offset (minutes):',
                            style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary)),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 60,
                          child: TextField(
                            controller: _numberOffsetController,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary),
                            decoration: InputDecoration(
                              filled: true, fillColor: AppTheme.surface,
                              isDense: true,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],

                // Output mode: Notes or Calculator
                const SizedBox(height: 16),
                _SectionTitle(title: 'Output'),
                const SizedBox(height: 8),
                Row(
                  children: ['notes', 'calculator'].map((mode) {
                    final isSelected = (_numberOutputMode ?? 'calculator') == mode;
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(right: mode == 'notes' ? 8 : 0),
                        child: GestureDetector(
                          onTap: () => setState(() => _numberOutputMode = mode),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: isSelected ? AppTheme.primary : AppTheme.surface,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: isSelected ? AppTheme.primary : AppTheme.border),
                            ),
                            child: Column(
                              children: [
                                Icon(mode == 'notes' ? Icons.note : Icons.calculate,
                                    color: isSelected ? Colors.white : AppTheme.textSecondary, size: 20),
                                const SizedBox(height: 4),
                                Text(mode == 'notes' ? 'Notes' : _language == Language.french ? 'Calculatrice' : 'Calculator',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                                        color: isSelected ? Colors.white : AppTheme.textSecondary)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),

                // Notes template with variable chips (Notes output only)
                if ((_numberOutputMode ?? 'calculator') == 'notes') ...[
                  const SizedBox(height: 16),
                  Text(
                    _language == Language.french ? 'Texte Notes (optionnel)' : 'Notes Text (optional)',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _language == Language.french
                        ? 'Laisse vide = seul le résultat s\'affiche. Insère des variables via les chips ci-dessous.'
                        : 'Leave empty = only the raw result is shown. Tap a chip below to insert a variable.',
                    style: const TextStyle(fontSize: 10, color: AppTheme.textTertiary, height: 1.3),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _numberNotesTemplateController,
                    maxLines: 4,
                    minLines: 2,
                    style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary),
                    decoration: InputDecoration(
                      hintText: (_numberMode ?? NumberMode.rainman) == NumberMode.birthday
                          ? (_language == Language.french
                              ? 'Ex: Tu es né un ((DayOfBirth)), il y a ((numDays)) jours.'
                              : 'Ex: You were born on a ((DayOfBirth)), ((numDays)) days ago.')
                          : (_language == Language.french
                              ? 'Ex: Le résultat est ((Result)).'
                              : 'Ex: The result is ((Result)).'),
                      hintStyle: const TextStyle(fontSize: 11, color: AppTheme.textTertiary),
                      filled: true,
                      fillColor: AppTheme.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppTheme.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppTheme.border),
                      ),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  if (_errors['number_template'] != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      _errors['number_template']!,
                      style: const TextStyle(color: Colors.red, fontSize: 11),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: () {
                      final chips = <String>[];
                      final mode = _numberMode ?? NumberMode.rainman;
                      if (mode == NumberMode.birthday) {
                        chips.addAll(['((DayOfBirth))', '((numDays))']);
                      } else {
                        chips.add('((Result))');
                      }
                      return chips.map((c) => _MiniInsertChip(
                        label: c,
                        onTap: () {
                          final ctrl = _numberNotesTemplateController;
                          final sel = ctrl.selection;
                          final pos = sel.isValid ? sel.baseOffset : ctrl.text.length;
                          final newText = ctrl.text.substring(0, pos) + c + ctrl.text.substring(pos);
                          ctrl.text = newText;
                          ctrl.selection = TextSelection.collapsed(offset: pos + c.length);
                          setState(() {});
                        },
                      )).toList();
                    }(),
                  ),
                ],

                // Input method (audio or swipe only)
                const SizedBox(height: 16),
                _SectionTitle(title: _language == Language.french ? 'Méthode d\'Entrée' : 'Input Method'),
                const SizedBox(height: 8),
                Row(
                  children: [StealthInputMethod.audio, StealthInputMethod.clockSwipe].map((method) {
                    final isSelected = _stealthInputMethod == method;
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(right: method == StealthInputMethod.audio ? 8 : 0),
                        child: GestureDetector(
                          onTap: () => setState(() => _stealthInputMethod = method),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: isSelected ? AppTheme.primary : AppTheme.surface,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: isSelected ? AppTheme.primary : AppTheme.border),
                            ),
                            child: Column(
                              children: [
                                Icon(method == StealthInputMethod.audio ? Icons.mic : Icons.swipe,
                                    color: isSelected ? Colors.white : AppTheme.textSecondary, size: 20),
                                const SizedBox(height: 4),
                                Text(method.displayName(_language),
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                                        color: isSelected ? Colors.white : AppTheme.textSecondary)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],

              // ==========================================
              // MULTIPLE OUT SPECIFIC SECTIONS
              // ==========================================
              if (_type == PresetType.multipleOut) ...[
                // ---- TEXTS SECTION (first) ----
                const SizedBox(height: 24),
                _SectionTitle(
                  title: _language == Language.french
                      ? 'Textes (${_multipleOutControllers.length})'
                      : 'Texts (${_multipleOutControllers.length})',
                  required: true,
                ),
                const SizedBox(height: 8),

                // Show-titles toggle — useful mostly in Assistant mode where the
                // titles appear as button labels on the remote webapp. Hidden
                // by default to keep the builder clean.
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _language == Language.french ? 'Afficher un titre par texte' : 'Show a title per text',
                            style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _language == Language.french
                                ? 'Utile surtout en Remote Input : le titre devient le libellé du bouton sur la webapp distante.'
                                : 'Mostly useful with Remote Input: the title becomes the button label on the remote webapp.',
                            style: const TextStyle(fontSize: 10, color: AppTheme.textTertiary, height: 1.3),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _multipleOutShowTitles,
                      activeThumbColor: AppTheme.primary,
                      onChanged: (v) {
                        setState(() {
                          _multipleOutShowTitles = v;
                          // When disabling titles, clear them so the preset
                          // is saved without stale values.
                          if (!v) {
                            for (final c in _multipleOutTitleControllers) {
                              c.clear();
                            }
                          }
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Text editors
                ...List.generate(_multipleOutControllers.length, (index) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                      // Title field (optional, shown only when the toggle is ON)
                      if (_multipleOutShowTitles)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: TextField(
                          controller: index < _multipleOutTitleControllers.length
                              ? _multipleOutTitleControllers[index]
                              : TextEditingController(),
                          style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary),
                          decoration: InputDecoration(
                            labelText: '${_language == Language.french ? "Titre" : "Title"} ${index + 1}',
                            labelStyle: const TextStyle(fontSize: 11, color: AppTheme.textTertiary),
                            hintText: _language == Language.french ? 'Ex: Prédiction carte' : 'Ex: Card prediction',
                            hintStyle: const TextStyle(fontSize: 11, color: AppTheme.textTertiary),
                            filled: true,
                            fillColor: AppTheme.surface,
                            isDense: true,
                            prefixIcon: const Icon(Icons.title, size: 16, color: AppTheme.textSecondary),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: AppTheme.border),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: AppTheme.border),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          ),
                        ),
                      ),
                      // Keyword field (audio only)
                      if (_stealthInputMethod == StealthInputMethod.audio)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: TextField(
                            controller: index < _multipleOutKeywordControllers.length
                                ? _multipleOutKeywordControllers[index]
                                : TextEditingController(),
                            style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary),
                            decoration: InputDecoration(
                              labelText: '${_language == Language.french ? "Mot-clé" : "Keyword"} ${index + 1}',
                              labelStyle: const TextStyle(fontSize: 11, color: AppTheme.textTertiary),
                              hintText: _language == Language.french ? 'Ex: espagne, paris...' : 'Ex: spain, paris...',
                              hintStyle: const TextStyle(fontSize: 11, color: AppTheme.textTertiary),
                              filled: true,
                              fillColor: AppTheme.primary.withOpacity(0.08),
                              isDense: true,
                              prefixIcon: const Icon(Icons.mic, size: 16, color: AppTheme.primary),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: AppTheme.primary.withOpacity(0.3)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: AppTheme.primary.withOpacity(0.3)),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            ),
                          ),
                        ),
                      Focus(
                      onFocusChange: (hasFocus) {
                        if (hasFocus) _focusedMultipleOutController = _multipleOutControllers[index];
                      },
                      child: TextField(
                      controller: _multipleOutControllers[index],
                      maxLines: 4,
                      minLines: 2,
                      style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary),
                      decoration: InputDecoration(
                        labelText: '${_language == Language.french ? "Texte" : "Text"} ${index + 1}',
                        labelStyle: const TextStyle(fontSize: 12, color: AppTheme.textTertiary),
                        hintText: _language == Language.french
                            ? 'Entrez le texte pour la sortie ${index + 1}...'
                            : 'Enter text for output ${index + 1}...',
                        hintStyle: const TextStyle(fontSize: 12, color: AppTheme.textTertiary),
                        filled: true,
                        fillColor: AppTheme.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppTheme.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppTheme.border),
                        ),
                        contentPadding: const EdgeInsets.all(12),
                      ),
                    )),
                    const SizedBox(height: 8),
                    _BankImageControl(
                      imagePath: _bankImages['$index'],
                      onPick: () => _pickBankImage('$index'),
                      onRemove: () => setState(() => _bankImages.remove('$index')),
                      locale: _language,
                    ),
                    ],),
                  );
                }),

                // ---- ADD / REMOVE BUTTONS (below the last text) ----
                const SizedBox(height: 4),
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _multipleOutControllers.add(TextEditingController());
                          _multipleOutTitleControllers.add(TextEditingController());
                          _multipleOutKeywordControllers.add(TextEditingController());
                        });
                      },
                      icon: const Icon(Icons.add, size: 16),
                      label: Text(_language == Language.french ? 'Ajouter' : 'Add'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        textStyle: const TextStyle(fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (_multipleOutControllers.length > 2)
                      ElevatedButton.icon(
                        onPressed: () {
                          setState(() {
                            _multipleOutControllers.removeLast().dispose();
                            if (_multipleOutTitleControllers.isNotEmpty) _multipleOutTitleControllers.removeLast().dispose();
                            if (_multipleOutKeywordControllers.isNotEmpty) _multipleOutKeywordControllers.removeLast().dispose();
                          });
                        },
                        icon: const Icon(Icons.remove, size: 16),
                        label: Text(_language == Language.french ? 'Retirer' : 'Remove'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.surface,
                          foregroundColor: AppTheme.textSecondary,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          textStyle: const TextStyle(fontSize: 12),
                        ),
                      ),
                  ],
                ),

                // ---- INPUT METHOD SECTION (after texts) ----
                const SizedBox(height: 24),
                _SectionTitle(
                  title: _language == Language.french ? 'Méthode d\'Entrée' : 'Input Method',
                  required: true,
                ),
                const SizedBox(height: 8),
                Builder(builder: (_) {
                  final textCount = _multipleOutControllers.length;
                  // Keep the same canonical order as other presets:
                  // volume → tap → audio → clockSwipe. Assistant is a global
                  // toggle now (Home screen), not a per-preset input method.
                  // Volume and tap require ≤ 6 texts.
                  final methods = <StealthInputMethod>[
                    if (textCount <= 6) StealthInputMethod.volume,
                    if (textCount <= 6) StealthInputMethod.tap,
                    StealthInputMethod.audio,
                    StealthInputMethod.clockSwipe,
                  ];
                  // If current method no longer available, reset
                  if (!methods.contains(_stealthInputMethod)) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      setState(() => _stealthInputMethod = methods.first);
                    });
                  }
                  return _StealthInputMethodSelector(
                    selectedMethod: _stealthInputMethod,
                    locale: _language,
                    allowedMethods: methods,
                    onChanged: (method) => setState(() => _stealthInputMethod = method),
                  );
                }),

                // ---- HELP PANELS ----
                // Volume mapping
                if (_stealthInputMethod == StealthInputMethod.volume) ...[
                  const SizedBox(height: 12),
                  ...List.generate(_multipleOutControllers.length, (i) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(
                        '${VolumeInputController.getGestureDescription(i, french: _language == Language.french)}  →  ${_multipleOutTitleControllers[i].text.isNotEmpty ? _multipleOutTitleControllers[i].text : "Text ${i + 1}"}',
                        style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                      ),
                    );
                  }),
                ],

                // Tap mapping — phone mockup with zone labels
                if (_stealthInputMethod == StealthInputMethod.tap) ...[
                  const SizedBox(height: 12),
                  _MultipleOutTapHelpPanel(
                    locale: _language,
                    zoneLabels: List.generate(_multipleOutControllers.length, (i) {
                      final title = i < _multipleOutTitleControllers.length
                          ? _multipleOutTitleControllers[i].text.trim()
                          : '';
                      return title.isNotEmpty
                          ? title
                          : (_language == Language.french ? 'Texte ${i + 1}' : 'Text ${i + 1}');
                    }),
                  ),
                ],

                // Swipe pattern editor
                if (_stealthInputMethod == StealthInputMethod.clockSwipe) ...[
                  const SizedBox(height: 12),
                  Builder(builder: (_) {
                    final count = _multipleOutControllers.length;
                    // Initialize default patterns if needed
                    if (_swipePatterns == null || _swipePatterns!.length != count) {
                      _swipePatterns = _getDefaultSwipePatterns(count);
                    }
                    final swipeLength = _swipePatterns!.first.length;

                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _language == Language.french
                                ? 'Patterns Swipe ($swipeLength geste${swipeLength > 1 ? "s" : ""})'
                                : 'Swipe Patterns ($swipeLength swipe${swipeLength > 1 ? "s" : ""})',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _language == Language.french
                                ? 'Tu peux choisir n\'importe quel nombre de swipes — mais tous les patterns doivent en avoir le même nombre pour que le preset soit jouable.'
                                : 'You can pick any number of swipes — but every pattern must use the same count for the preset to be playable.',
                            style: TextStyle(fontSize: 10, color: AppTheme.textTertiary, height: 1.3),
                          ),
                          const SizedBox(height: 8),
                          ...List.generate(count, (i) {
                            final title = _multipleOutTitleControllers[i].text.isNotEmpty
                                ? _multipleOutTitleControllers[i].text
                                : 'Text ${i + 1}';
                            final dirs = _swipePatterns![i];
                            final arrows = dirs.map(_dirToArrow).join(' ');
                            return GestureDetector(
                              onTap: () => _editSwipePattern(i),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 4),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  color: AppTheme.background,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppTheme.border),
                                ),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 70,
                                      child: Text(title, style: const TextStyle(fontSize: 11, color: AppTheme.textPrimary), overflow: TextOverflow.ellipsis),
                                    ),
                                    const Spacer(),
                                    Text(arrows, style: const TextStyle(fontSize: 18, letterSpacing: 3)),
                                    const SizedBox(width: 6),
                                    Icon(Icons.edit, size: 12, color: AppTheme.textTertiary),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    );
                  }),
                ],

                // Audio: start/stop sentences + language
                if (_stealthInputMethod == StealthInputMethod.audio) ...[
                  const SizedBox(height: 12),
                  // Audio language
                  Row(
                    children: [
                      Icon(Icons.language, size: 16, color: AppTheme.textSecondary),
                      const SizedBox(width: 8),
                      Text(_language == Language.french ? 'Langue audio' : 'Audio language',
                          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                      const Spacer(),
                      DropdownButton<String>(
                        value: _audioLocale,
                        dropdownColor: AppTheme.surface,
                        style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                        underline: const SizedBox(),
                        items: const [
                          DropdownMenuItem(value: 'fr_FR', child: Text('Français')),
                          DropdownMenuItem(value: 'en_US', child: Text('English (US)')),
                          DropdownMenuItem(value: 'en_GB', child: Text('English (UK)')),
                          DropdownMenuItem(value: 'es_ES', child: Text('Español')),
                          DropdownMenuItem(value: 'de_DE', child: Text('Deutsch')),
                          DropdownMenuItem(value: 'it_IT', child: Text('Italiano')),
                          DropdownMenuItem(value: 'pt_PT', child: Text('Português')),
                        ],
                        onChanged: (v) => setState(() => _audioLocale = v!),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _audioStartSentenceController,
                    style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary),
                    decoration: InputDecoration(
                      labelText: _language == Language.french ? 'Start sentence (optionnel)' : 'Start sentence (optional)',
                      labelStyle: const TextStyle(fontSize: 12),
                      prefixIcon: const Icon(Icons.play_circle_outline, size: 18),
                      isDense: true, filled: true, fillColor: AppTheme.surface,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.border)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _audioStopSentenceController,
                    style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary),
                    decoration: InputDecoration(
                      labelText: _language == Language.french ? 'Stop sentence (optionnel)' : 'Stop sentence (optional)',
                      labelStyle: const TextStyle(fontSize: 12),
                      prefixIcon: const Icon(Icons.stop_circle_outlined, size: 18),
                      isDense: true, filled: true, fillColor: AppTheme.surface,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.border)),
                    ),
                  ),
                ],

                // Assistant info
                if (_stealthInputMethod == StealthInputMethod.assistant) ...[
                  const SizedBox(height: 12),
                  Text(
                    _language == Language.french
                        ? 'L\'assistant verra les titres comme boutons sur la webapp'
                        : 'Assistant will see titles as buttons on the webapp',
                    style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                  ),
                ],
              ],

              // ==========================================
              // NON-MULTIPLE-OUT SECTIONS BELOW
              // ==========================================
              if (_type != PresetType.multipleOut && _type != PresetType.number) ...[
              const SizedBox(height: 24),

              // 8) Options / Labels
              _SectionTitle(
                title: _language == Language.french ? 'Options / Labels' : 'Options / Labels',
                required: true,
              ),
              const SizedBox(height: 8),
              ...List.generate(_nbOptions, (index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _labelControllers[index],
                          textCapitalization: TextCapitalization.sentences,
                          decoration: InputDecoration(
                            labelText: 'Option ${index + 1}',
                            errorText: _errors['label_$index'],
                          ),
                          style: const TextStyle(color: AppTheme.textPrimary),
                          onChanged: (_) => setState(() => _errors.remove('label_$index')),
                        ),
                      ),
                      if (_type == PresetType.choices && _nbOptions > 2)
                        IconButton(
                          onPressed: () => _removeOption(index),
                          icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                        ),
                    ],
                  ),
                );
              }),
              if (_type == PresetType.choices && _nbOptions < 6)
                TextButton.icon(
                  onPressed: _addOption,
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(_language == Language.french ? '+ Ajouter une option' : '+ Add option'),
                ),

              const SizedBox(height: 24),

              // 7) Round Mode (DUEL ONLY)
              if (_type == PresetType.duel) ...[
                _SectionTitle(
                  title: _language == Language.french ? 'Mode de Jeu' : 'Game Mode',
                  required: true,
                ),
                const SizedBox(height: 8),
                _DuelRoundModeSelector(
                  locale: _language,
                  selectedMode: _duelMode,
                  targetScore: _targetScore,
                  onModeChanged: (mode) {
                    setState(() {
                      _duelMode = mode;
                      _errors.clear();
                    });
                  },
                  onTargetScoreChanged: (score) {
                    setState(() {
                      _targetScore = score;
                      // Adjust performer sequence if needed for First-To preprogrammed
                      if (_inputMode == InputMode.preprogrammed) {
                        final minMoves = (_targetScore * 2) - 1;
                        if (_performerSequence.length < minMoves) {
                          _performerSequence = [
                            ..._performerSequence,
                            ...List.filled(minMoves - _performerSequence.length, 0),
                          ];
                        }
                      }
                      _errors.clear();
                    });
                  },
                ),

                // 7b) Number of Rounds (for DUEL Fixed Rounds - BEFORE narrative bank)
                if (_duelMode == DuelMode.fixedRounds) ...[
                  const SizedBox(height: 24),
                  _SectionTitle(
                    title: _language == Language.french ? 'Nombre de Rounds' : 'Number of Rounds',
                    required: true,
                  ),
                  const SizedBox(height: 8),
                  _NumberSelector(
                    value: _nbRounds,
                    min: 1,
                    max: 5,
                    onChanged: _onNbRoundsChanged,
                  ),
                ],

                // 7b2) Input Method for DUEL (right after rounds)
                const SizedBox(height: 24),
                _SectionTitle(
                  title: _language == Language.french ? 'Méthode d\'Entrée' : 'Input Method',
                  required: true,
                ),
                const SizedBox(height: 8),
                _InputModeSelector(
                  selectedMode: _inputMode,
                  locale: _language,
                  onChanged: (mode) {
                    setState(() {
                      _inputMode = mode;
                      _errors.clear();
                    });
                  },
                ),

                // 7b3) Performer Sequence for DUEL preprogrammed (before narrative bank)
                if (_inputMode == InputMode.preprogrammed) ...[
                  const SizedBox(height: 16),
                  Builder(
                    builder: (context) {
                      final bool isFirstTo = _duelMode == DuelMode.firstTo;
                      final int displayRounds = isFirstTo ? (_targetScore * 2) - 1 : _nbRounds;
                      return _PerformerSequenceInline(
                        nbRounds: displayRounds,
                        labels: _getLabels(),
                        sequence: _performerSequence,
                        locale: _language,
                        errors: _errors,
                        isFirstTo: isFirstTo,
                        onChanged: (newSequence) {
                          setState(() {
                            _performerSequence = newSequence;
                            _errors.remove('sequence');
                            for (int i = 0; i < newSequence.length; i++) {
                              _errors.remove('sequence_$i');
                            }
                          });
                        },
                      );
                    },
                  ),
                  // Tie strategy selector (First-To only)
                  if (_duelMode == DuelMode.firstTo) ...[
                    const SizedBox(height: 16),
                    _SectionTitle(
                      title: _language == Language.french ? 'Gestion des Égalités' : 'Tie Handling',
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: PreprogrammedTieStrategy.values.map((strategy) {
                        final isSelected = _preprogrammedTieStrategy == strategy;
                        return Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(right: strategy != PreprogrammedTieStrategy.values.last ? 8 : 0),
                            child: GestureDetector(
                              onTap: () => setState(() => _preprogrammedTieStrategy = strategy),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                                decoration: BoxDecoration(
                                  color: isSelected ? AppTheme.primary : AppTheme.surface,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: isSelected ? AppTheme.primary : AppTheme.border),
                                ),
                                child: Column(
                                  children: [
                                    Icon(
                                      strategy == PreprogrammedTieStrategy.repeat
                                          ? Icons.replay
                                          : Icons.rotate_right,
                                      color: isSelected ? Colors.white : AppTheme.textSecondary,
                                      size: 20,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      strategy.displayName(_language),
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: isSelected ? Colors.white : AppTheme.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      strategy.description(_language),
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: isSelected ? Colors.white70 : AppTheme.textTertiary,
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
                  ],
                ],

                const SizedBox(height: 24),
                // 7c) Duel Score Bank (DUEL ONLY)
                _SectionTitle(
                  title: _language == Language.french ? 'Banque de Narration' : 'Narrative Bank',
                  required: false,
                ),
                const SizedBox(height: 8),

                if (_duelMode == DuelMode.fixedRounds)
                  _DuelScoreBankSection(
                    locale: _language,
                    nbRounds: _nbRounds,
                    inputMode: _inputMode,
                    labels: _getLabels(),
                    performerSequence: _inputMode == InputMode.preprogrammed ? _performerSequence : null,
                    customTemplates: _customDuelBankTemplates,
                    onChanged: (templates) {
                      setState(() {
                        _customDuelBankTemplates = templates;
                      });
                    },
                    bankImages: _bankImages,
                    onPickImage: _pickBankImage,
                    onRemoveImage: (key) => setState(() => _bankImages.remove(key)),
                  )
                else
                  _DuelFirstToScoreBankSection(
                    locale: _language,
                    targetScore: _targetScore,
                    inputMode: _inputMode,
                    labels: _getLabels(),
                    customTemplates: _customDuelBankTemplates,
                    onChanged: (templates) {
                      setState(() {
                        _customDuelBankTemplates = templates;
                      });
                    },
                    bankImages: _bankImages,
                    onPickImage: _pickBankImage,
                    onRemoveImage: (key) => setState(() => _bankImages.remove(key)),
                  ),
                const SizedBox(height: 16),
              ],

              // FREE_WILL SPECIFIC SECTION
              if (_type == PresetType.freeWill) ...[
                const SizedBox(height: 24),

                // FREE_WILL: only one input mode supported (input the object
                // for each action). The selector was removed.
                _SectionTitle(
                  title: _language == Language.french ? 'Je dois entrer l\'objet' : 'I need to enter the object',
                  required: true,
                ),
                const SizedBox(height: 8),

                // Live preview: each action prompts for an object
                Builder(builder: (_) {
                  final labels = _getLabels();
                  final isFR = _language == Language.french;
                  return _buildFreeWillInputPreview(
                    title: isFR ? 'Mapping' : 'Mapping',
                    subtitle: isFR
                        ? 'Options = les objets (${labels.join(", ")})'
                        : 'Options = the objects (${labels.join(", ")})',
                    items: List.generate(_freeWillActionOrder.length, (i) {
                      final action = _freeWillActionOrder[i];
                      final actionName = isFR ? action.shortNameFR : action.shortNameEN;
                      return _FreeWillPreviewItem(
                        fixed: actionName.toUpperCase(),
                        variable: isFR ? 'quel objet ?' : 'which object?',
                        isAuto: i == 2,
                      );
                    }),
                    onReorder: (oldIndex, newIndex) {
                      setState(() {
                        if (oldIndex < newIndex) newIndex -= 1;
                        final item = _freeWillActionOrder.removeAt(oldIndex);
                        _freeWillActionOrder.insert(newIndex, item);
                      });
                    },
                  );
                }),

                const SizedBox(height: 24),

                // FREE_WILL Bank Section (moved up, before Change of Mind)
                _SectionTitle(
                  title: _language == Language.french ? 'Banque de Narration' : 'Narrative Bank',
                  required: false,
                ),
                const SizedBox(height: 8),
                _FreeWillBankSection(
                  locale: _language,
                  objects: _getLabels(),
                  customTemplates: _customFreeWillBankTemplates,
                  mode: _freeWillBankMode,
                  singleTemplateController: _freeWillSingleTemplateController,
                  onModeChanged: (m) => setState(() => _freeWillBankMode = m),
                  onSingleTemplateChanged: (_) => setState(() {}),
                  onChanged: (templates) {
                    setState(() {
                      _customFreeWillBankTemplates = templates;
                    });
                  },
                  bankImages: _bankImages,
                  onPickImage: _pickBankImage,
                  onRemoveImage: (key) => setState(() => _bankImages.remove(key)),
                ),

                const SizedBox(height: 24),

                // Change of Mind (moved AFTER Narrative Bank)
                _SectionTitle(
                  title: _language == Language.french ? 'Changement d\'Avis' : 'Change of Mind',
                  required: false,
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  title: Text(
                    _language == Language.french
                        ? 'Proposer de changer d\'avis'
                        : 'Suggest changing mind',
                    style: const TextStyle(color: AppTheme.textPrimary),
                  ),
                  subtitle: Text(
                    _language == Language.french
                        ? 'Ajoute une phrase si le spectateur ne change pas d\'avis'
                        : 'Adds a phrase if spectator doesn\'t change their mind',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  value: _suggestChangeOfMind,
                  activeThumbColor: AppTheme.primary,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (value) {
                    setState(() {
                      _suggestChangeOfMind = value;
                    });
                  },
                ),

                if (_suggestChangeOfMind) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _noChangeMindTextController ??= TextEditingController(),
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      labelText: _language == Language.french
                          ? 'Texte "Pas de changement"'
                          : '"No change" text',
                      hintText: _language == Language.french
                          ? 'Ex: Je vais te proposer de changer d\'avis. Tu ne vas pas le faire.'
                          : 'E.g., I\'ll offer you to change your mind. You won\'t.',
                    ),
                    style: const TextStyle(color: AppTheme.textPrimary),
                    maxLines: 2,
                  ),
                ],

                const SizedBox(height: 12),
                TextField(
                  controller: _changeMindTextController ??= TextEditingController(),
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: _language == Language.french
                        ? 'Texte "Changement d\'avis"'
                        : '"Changed mind" text',
                    hintText: _language == Language.french
                        ? 'Ex: Tu vas changer d\'avis, comme prévu.'
                        : 'E.g., You\'ll change your mind, as expected.',
                  ),
                  style: const TextStyle(color: AppTheme.textPrimary),
                  maxLines: 2,
                ),

                const SizedBox(height: 16),
              ],

              // 8) Number of Rounds (only for CHOICES type, not DUEL or FREE_WILL)
              if (_type == PresetType.choices) ...[
                _SectionTitle(
                  title: _language == Language.french ? 'Nombre de Rounds' : 'Number of Rounds',
                  required: true,
                ),
                const SizedBox(height: 8),
                _NumberSelector(
                  value: _nbRounds,
                  min: 1,
                  max: 5,
                  onChanged: _onNbRoundsChanged,
                ),
              ],

              // 9) Input Method (only for CHOICES in game mode — Duel has its own above)
              if (_type == PresetType.choices) ...[
                const SizedBox(height: 24),
                _SectionTitle(
                  title: _language == Language.french ? 'Méthode d\'Entrée' : 'Input Method',
                  required: true,
                ),
                const SizedBox(height: 8),
                _InputModeSelector(
                  selectedMode: _inputMode,
                  locale: _language,
                  onChanged: (mode) {
                    setState(() {
                      _inputMode = mode;
                      _errors.clear();
                    });
                  },
                ),

                // 10) Performer Sequence for CHOICES (Duel has its own above)
                if (_inputMode == InputMode.preprogrammed) ...[
                  const SizedBox(height: 16),
                  _PerformerSequenceInline(
                    nbRounds: _nbRounds,
                    labels: _getLabels(),
                    sequence: _performerSequence,
                    locale: _language,
                    errors: _errors,
                    isFirstTo: false,
                    onChanged: (newSequence) {
                      setState(() {
                        _performerSequence = newSequence;
                        _errors.remove('sequence');
                        for (int i = 0; i < newSequence.length; i++) {
                          _errors.remove('sequence_$i');
                        }
                      });
                    },
                  ),

                  // 10b) CHOICES preprogrammed: Mode Toggle + Sequence Bank
                  if (_type == PresetType.choices) ...[
                    const SizedBox(height: 16),

                  ],

                  // 10c) Duel Preprogrammed Bank Editor moved to section 7b3
                ],
              ],

              // 10d) CHOICES H/M Pattern Bank (unified single model)
              if (_type == PresetType.choices &&
                  (_inputMode == InputMode.preprogrammed || _inputMode == InputMode.twoInputs)) ...[
                const SizedBox(height: 16),
                _ChoicesScoreBankSection(
                  locale: _language,
                  nbRounds: _nbRounds,
                  inputMode: _inputMode,
                  labels: _getLabels(),
                  performerSequence: _inputMode == InputMode.preprogrammed ? _performerSequence : null,
                  customTemplates: _customChoicesBankTemplates,
                  onChanged: (templates) {
                    setState(() {
                      _customChoicesBankTemplates = templates;
                    });
                  },
                  bankImages: _bankImages,
                  onPickImage: _pickBankImage,
                  onRemoveImage: (key) => setState(() => _bankImages.remove(key)),
                ),
              ],

              // 11) Stealth Input Method
              const SizedBox(height: 24),
              _SectionTitle(
                title: _language == Language.french ? 'Méthode d\'Entrée Secrète' : 'Stealth Input Method',
                required: false,
                // Hide info icon for Free Will, Duel, and Choices (help panels are shown inline)
                onInfoTap: (_type == PresetType.freeWill || _type == PresetType.duel || _type == PresetType.choices) ? null : _showStealthInputHelp,
              ),
              const SizedBox(height: 8),
              _StealthInputMethodSelector(
                selectedMethod: _stealthInputMethod,
                locale: _language,
                onChanged: (method) {
                  setState(() {
                    _stealthInputMethod = method;
                  });
                },
              ),

              // Audio start/stop sentence fields (only when AUDIO is selected)
              if (_stealthInputMethod == StealthInputMethod.audio) ...[
                const SizedBox(height: 12),
                // Audio language selector
                Row(
                  children: [
                    Icon(Icons.language, size: 18, color: AppTheme.textSecondary),
                    const SizedBox(width: 8),
                    Text(
                      _language == Language.french ? 'Langue audio' : 'Audio language',
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                    const Spacer(),
                    DropdownButton<String>(
                      value: _audioLocale,
                      dropdownColor: AppTheme.surface,
                      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                      underline: const SizedBox(),
                      items: const [
                        DropdownMenuItem(value: 'fr_FR', child: Text('Français')),
                        DropdownMenuItem(value: 'en_US', child: Text('English (US)')),
                        DropdownMenuItem(value: 'en_GB', child: Text('English (UK)')),
                        DropdownMenuItem(value: 'es_ES', child: Text('Español')),
                        DropdownMenuItem(value: 'de_DE', child: Text('Deutsch')),
                        DropdownMenuItem(value: 'it_IT', child: Text('Italiano')),
                        DropdownMenuItem(value: 'pt_PT', child: Text('Português')),
                        DropdownMenuItem(value: 'nl_NL', child: Text('Nederlands')),
                        DropdownMenuItem(value: 'ja_JP', child: Text('日本語')),
                        DropdownMenuItem(value: 'zh_CN', child: Text('中文')),
                        DropdownMenuItem(value: 'ko_KR', child: Text('한국어')),
                        DropdownMenuItem(value: 'ar_SA', child: Text('العربية')),
                        DropdownMenuItem(value: 'ru_RU', child: Text('Русский')),
                        DropdownMenuItem(value: 'hi_IN', child: Text('हिन्दी')),
                        DropdownMenuItem(value: 'tr_TR', child: Text('Türkçe')),
                        DropdownMenuItem(value: 'pl_PL', child: Text('Polski')),
                        DropdownMenuItem(value: 'sv_SE', child: Text('Svenska')),
                        DropdownMenuItem(value: 'da_DK', child: Text('Dansk')),
                        DropdownMenuItem(value: 'he_IL', child: Text('עברית')),
                      ],
                      onChanged: (v) => setState(() => _audioLocale = v!),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _audioStartSentenceController,
                  style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary),
                  decoration: InputDecoration(
                    labelText: _language == Language.french ? 'Start sentence (optionnel)' : 'Start sentence (optional)',
                    labelStyle: const TextStyle(fontSize: 12),
                    hintText: _language == Language.french ? 'Ex: on va commencer' : 'Ex: let\'s begin',
                    hintStyle: const TextStyle(fontSize: 12, color: AppTheme.textTertiary),
                    prefixIcon: const Icon(Icons.play_circle_outline, size: 18),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _audioStopSentenceController,
                  style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary),
                  decoration: InputDecoration(
                    labelText: _language == Language.french ? 'Stop sentence (optionnel)' : 'Stop sentence (optional)',
                    labelStyle: const TextStyle(fontSize: 12),
                    hintText: _language == Language.french ? 'Ex: merci' : 'Ex: thank you',
                    hintStyle: const TextStyle(fontSize: 12, color: AppTheme.textTertiary),
                    prefixIcon: const Icon(Icons.stop_circle_outlined, size: 18),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _language == Language.french
                      ? 'Sans start sentence → écoute directe. Sans stop sentence → arrêt manuel.'
                      : 'No start sentence → immediate. No stop sentence → manual stop.',
                  style: const TextStyle(fontSize: 10, color: AppTheme.textTertiary),
                ),
              ],

              // Volume help panel for Free Will (only when VOLUME is selected)
              if (_type == PresetType.freeWill && _stealthInputMethod == StealthInputMethod.volume) ...[
                const SizedBox(height: 16),
                _FreeWillVolumeHelpPanel(
                  inputMode: _freeWillInputMode,
                  actionOrder: _freeWillActionOrder,
                  objectOrder: _freeWillObjectOrder,
                  objectNames: _getLabels(),
                  locale: _language,
                ),
              ],

              // Tap options for Free Will (only when TAP is selected)
              if (_type == PresetType.freeWill && _stealthInputMethod == StealthInputMethod.tap) ...[
                const SizedBox(height: 16),

                // Orientation selector
                const Text(
                  'Orientation des zones',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                _TapOrientationSelector(
                  selectedOrientation: _tapOrientation,
                  locale: _language,
                  onChanged: (orientation) {
                    setState(() {
                      _tapOrientation = orientation;
                    });
                  },
                ),
                const SizedBox(height: 16),

                // Help panel
                _FreeWillTapHelpPanel(
                  inputMode: _freeWillInputMode,
                  actionOrder: _freeWillActionOrder,
                  objectOrder: _freeWillObjectOrder,
                  objectNames: _getLabels(),
                  tapOrientation: _tapOrientation,
                  locale: _language,
                ),
              ],

              // Swipe help panel for Free Will
              if (_type == PresetType.freeWill && _stealthInputMethod == StealthInputMethod.clockSwipe) ...[
                const SizedBox(height: 16),
                Builder(builder: (_) {
                  final isFR = _language == Language.french;
                  final slotLabels = _getLabels(); // objects (only mode supported)
                  final patterns = _swipePatterns ?? _getDefaultSwipePatterns(3);
                  final allDirs = {'up', 'right', 'down', 'left'};
                  final usedDirs = <String>{};
                  for (final p in patterns) { for (final d in p) { usedDirs.add(d); } }
                  final lockDir = allDirs.difference(usedDirs).isNotEmpty
                      ? allDirs.difference(usedDirs).first : null;

                  String arrow(String d) => {'up': '↑', 'down': '↓', 'left': '←', 'right': '→'}[d] ?? '?';

                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.swipe, color: AppTheme.primary, size: 20),
                            const SizedBox(width: 8),
                            Text(isFR ? 'Mode Swipe' : 'Swipe Mode',
                                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Phase 1: Choice
                        Text(isFR ? 'Phase 1 : Choix (2 inputs)' : 'Phase 1: Choice (2 inputs)',
                            style: TextStyle(color: AppTheme.accent, fontSize: 12, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        ...List.generate(slotLabels.length, (i) {
                          final arrows = patterns[i].map(arrow).join(' ');
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(children: [
                              Text(arrows, style: const TextStyle(fontSize: 16)),
                              const SizedBox(width: 10),
                              Text('→', style: TextStyle(color: AppTheme.textTertiary, fontSize: 12)),
                              const SizedBox(width: 10),
                              Text(slotLabels[i], style: TextStyle(color: AppTheme.textPrimary, fontSize: 13)),
                            ]),
                          );
                        }),
                        Text(isFR ? '2 inputs, le 3e est déduit.' : '2 inputs, 3rd deduced.',
                            style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                        const SizedBox(height: 12),
                        // Phase 2: Swap
                        Text(isFR ? 'Phase 2 : Changement d\'avis' : 'Phase 2: Change of mind',
                            style: TextStyle(color: AppTheme.accent, fontSize: 12, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        ...List.generate(patterns.length, (i) {
                          final arrows = patterns[i].map(arrow).join(' ');
                          // Swap mapping: input N keeps object N, swaps the other two.
                          final swapPairs = [(1, 2), (0, 2), (0, 1)];
                          final (a, b) = swapPairs[i % swapPairs.length];
                          final keep = i < slotLabels.length ? slotLabels[i] : '?';
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(children: [
                              Text(arrows, style: const TextStyle(fontSize: 16)),
                              const SizedBox(width: 10),
                              Text('→', style: TextStyle(color: AppTheme.textTertiary, fontSize: 12)),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  isFR
                                      ? 'garde $keep, swap ${slotLabels[a]} ↔ ${slotLabels[b]}'
                                      : 'keep $keep, swap ${slotLabels[a]} ↔ ${slotLabels[b]}',
                                  style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                                ),
                              ),
                            ]),
                          );
                        }),
                        const SizedBox(height: 12),
                        // End
                        Text(isFR ? 'Fin' : 'End',
                            style: TextStyle(color: AppTheme.accent, fontSize: 12, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        if (lockDir != null)
                          Row(children: [
                            Text(arrow(lockDir), style: const TextStyle(fontSize: 16)),
                            const SizedBox(width: 10),
                            Text('→', style: TextStyle(color: AppTheme.textTertiary, fontSize: 12)),
                            const SizedBox(width: 10),
                            Text('LOCK', style: TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                          ]),
                        Row(children: [
                          Icon(Icons.volume_down, size: 16, color: AppTheme.accent),
                          const SizedBox(width: 10),
                          Text('→', style: TextStyle(color: AppTheme.textTertiary, fontSize: 12)),
                          const SizedBox(width: 10),
                          Text('LOCK', style: TextStyle(color: AppTheme.textPrimary, fontSize: 13)),
                        ]),
                      ],
                    ),
                  );
                }),
              ],

              // Volume help panel for Duel (only when VOLUME is selected)
              if (_type == PresetType.duel && _stealthInputMethod == StealthInputMethod.volume) ...[
                const SizedBox(height: 16),
                _DuelVolumeHelpPanel(locale: _language, labels: _getLabels()),
              ],

              // Volume help panel for Choices (only when VOLUME is selected)
              if (_type == PresetType.choices && _stealthInputMethod == StealthInputMethod.volume) ...[
                const SizedBox(height: 16),
                _ChoicesVolumeHelpPanel(
                  locale: _language,
                  nbOptions: _nbOptions,
                  labels: _getLabels(),
                ),
              ],

              // TAP Layout options (only when TAP is selected) - for non-FreeWill presets
              if (_stealthInputMethod == StealthInputMethod.tap && _type != PresetType.freeWill) ...[
                const SizedBox(height: 16),

                // Layout for 2 options
                if (_nbOptions == 2) ...[
                  Text(
                    _language == Language.french ? 'Disposition des zones' : 'Zone layout',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _TapLayout2Selector(
                    selectedLayout: _tapLayout2,
                    locale: _language,
                    onChanged: (layout) {
                      setState(() {
                        _tapLayout2 = layout;
                      });
                    },
                  ),
                ],

                // Layout for 4 options
                if (_nbOptions == 4) ...[
                  Text(
                    _language == Language.french ? 'Disposition des zones' : 'Zone layout',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _TapLayout4Selector(
                    selectedLayout: _tapLayout4,
                    locale: _language,
                    onChanged: (layout) {
                      setState(() {
                        _tapLayout4 = layout;
                      });
                    },
                  ),
                ],

                // Layout selector for 3 options (Duel): horizontal or vertical bands
                if (_nbOptions == 3 && _type == PresetType.duel) ...[
                  Text(
                    _language == Language.french ? 'Disposition des zones' : 'Zone layout',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _TapLayout2Selector(
                    selectedLayout: _tapLayout2,
                    locale: _language,
                    onChanged: (layout) {
                      setState(() {
                        _tapLayout2 = layout;
                      });
                    },
                  ),
                ],

                // Info for fixed layouts (3 options non-duel, 5, 6 options)
                if ((_nbOptions == 3 && _type != PresetType.duel) || _nbOptions == 5 || _nbOptions == 6) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, size: 18, color: AppTheme.textSecondary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _nbOptions == 3
                                ? (_language == Language.french
                                    ? '3 bandes horizontales (haut → bas)'
                                    : '3 horizontal bands (top → bottom)')
                                : (_language == Language.french
                                    ? 'Grille 2×3 (gauche→droite, haut→bas)'
                                    : '2×3 grid (left→right, top→bottom)'),
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Tap help panel for Duel
                if (_type == PresetType.duel) ...[
                  const SizedBox(height: 16),
                  _DuelTapHelpPanel(
                    locale: _language,
                    tapLayout2: _tapLayout2,
                    inputMode: _inputMode,
                    labels: _getLabels(),
                  ),
                ],

                // Tap help panel for Choices
                if (_type == PresetType.choices) ...[
                  const SizedBox(height: 16),
                  _ChoicesTapHelpPanel(
                    locale: _language,
                    nbOptions: _nbOptions,
                    tapLayout2: _tapLayout2,
                    tapLayout4: _tapLayout4,
                    labels: _getLabels(),
                  ),
                ],
              ],

              // Swipe pattern editor (when clockSwipe selected for Choices)
              if (_stealthInputMethod == StealthInputMethod.clockSwipe && (_type == PresetType.choices || _type == PresetType.duel || _type == PresetType.freeWill)) ...[
                const SizedBox(height: 16),
                Builder(builder: (_) {
                  // Initialize default patterns from clock map if needed
                  if (_swipePatterns == null || _swipePatterns!.length != _nbOptions) {
                    _swipePatterns = _getDefaultSwipePatterns(_nbOptions);
                  }
                  final swipeLength = _swipePatterns!.first.length;

                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _language == Language.french
                              ? 'Patterns Swipe ($swipeLength geste${swipeLength > 1 ? 's' : ''})'
                              : 'Swipe Patterns ($swipeLength swipe${swipeLength > 1 ? 's' : ''})',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _language == Language.french
                              ? 'Tap un pattern pour le modifier. Tu peux choisir n\'importe quel nombre de swipes, mais tous les patterns doivent en avoir le même nombre pour que le preset soit jouable.'
                              : 'Tap a pattern to edit it. You can pick any number of swipes, but every pattern must share the same count for the preset to be playable.',
                          style: TextStyle(fontSize: 10, color: AppTheme.textTertiary, height: 1.3),
                        ),
                        const SizedBox(height: 12),
                        ...List.generate(_nbOptions, (i) {
                          final String label;
                          if (_type == PresetType.freeWill && _freeWillInputMode == FreeWillInputMode.byObject) {
                            // byObject: options are actions
                            label = i < _freeWillActionOrder.length
                                ? (_language == Language.french ? _freeWillActionOrder[i].shortNameFR : _freeWillActionOrder[i].shortNameEN)
                                : 'Option ${i + 1}';
                          } else {
                            label = i < _getLabels().length ? _getLabels()[i] : 'Option ${i + 1}';
                          }
                          final dirs = _swipePatterns![i];
                          final arrows = dirs.map(_dirToArrow).join(' ');

                          return GestureDetector(
                            onTap: () => _editSwipePattern(i),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: AppTheme.background,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppTheme.border),
                              ),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 90,
                                    child: Text(label, style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary), overflow: TextOverflow.ellipsis),
                                  ),
                                  const Spacer(),
                                  Text(arrows, style: const TextStyle(fontSize: 20, letterSpacing: 4)),
                                  const SizedBox(width: 8),
                                  Icon(Icons.edit, size: 14, color: AppTheme.textTertiary),
                                ],
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  );
                }),
              ],

              ], // end if (_type != PresetType.multipleOut && _type != PresetType.number)

              // Per-preset override for auto-copy + shortcut (all types)
              const SizedBox(height: 24),
              OutputOverrideSection(
                locale: _language,
                autoCopyOverride: _autoCopyOverride,
                shortcutNameOverride: _shortcutNameOverride,
                shortcutController: _shortcutNameOverrideController,
                onToggleCustom: (enabled) {
                  setState(() {
                    if (enabled) {
                      // Defaults when activating per-preset copy/shortcut.
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

              const SizedBox(height: 16),
              _DecoyTemplatePickerField(
                locale: _language,
                selectedId: _decoyTemplateId,
                onChanged: (v) => setState(() => _decoyTemplateId = v),
                inputType: _decoyInputType,
                onInputTypeChanged: (v) => setState(() => _decoyInputType = v),
                redirectController: _assistantRedirectUrlController,
                onRedirectChanged: (_) => setState(() {}),
              ),

              // Output Mode (all types except Number)
              if (_type != PresetType.number) ...[
                const SizedBox(height: 24),
                _SectionTitle(
                  title: _language == Language.french ? 'Mode de Sortie' : 'Output Mode',
                ),
                const SizedBox(height: 8),
                Builder(builder: (_) {
                  final bankKeys = _getBankKeys();
                  final allTextsReady = _areAllTextsReady();
                  final allImagesReady = bankKeys.isNotEmpty && bankKeys.every((k) => _bankImages[k] != null && _bankImages[k]!.isNotEmpty);

                  // Auto-reset outputMode if conditions no longer met
                  if (_outputMode == 'notes' && !allTextsReady) {
                    WidgetsBinding.instance.addPostFrameCallback((_) => setState(() => _outputMode = 'image'));
                  }
                  if (_outputMode == 'image' && !allImagesReady) {
                    WidgetsBinding.instance.addPostFrameCallback((_) => setState(() => _outputMode = 'notes'));
                  }

                  return Row(
                  children: ['notes', 'image', 'both'].map((mode) {
                    final isSelected = _outputMode == mode;
                    final isEnabled = mode == 'notes' ? allTextsReady
                        : mode == 'image' ? allImagesReady
                        : allTextsReady && allImagesReady;
                    final label = mode == 'notes' ? 'Notes' : mode == 'image' ? 'Image' : 'Both';
                    final icon = mode == 'notes' ? Icons.note : mode == 'image' ? Icons.photo : Icons.splitscreen;
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(right: mode != 'both' ? 8 : 0),
                        child: GestureDetector(
                          onTap: isEnabled ? () => setState(() => _outputMode = mode) : null,
                          child: Opacity(
                            opacity: isEnabled ? 1.0 : 0.3,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: isSelected && isEnabled ? AppTheme.primary : AppTheme.surface,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: isSelected && isEnabled ? AppTheme.primary : AppTheme.border),
                              ),
                              child: Column(
                                children: [
                                  Icon(icon, size: 18, color: isSelected && isEnabled ? Colors.white : AppTheme.textSecondary),
                                  const SizedBox(height: 4),
                                  Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isSelected && isEnabled ? Colors.white : AppTheme.textSecondary)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                );
                }),
                // Bank images section (hidden for all types now — managed per-bank inline)
                if (false && (_outputMode == 'image' || _outputMode == 'both')) ...[
                  const SizedBox(height: 16),
                  Text(
                    _language == Language.french ? 'Images par résultat' : 'Images per outcome',
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  ..._getBankKeys().map((key) {
                    final hasImage = _bankImages.containsKey(key) && _bankImages[key]!.isNotEmpty;
                    final displayKey = _formatBankKeyDisplay(key);
                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: hasImage ? Colors.green.withValues(alpha: 0.5) : AppTheme.border),
                      ),
                      child: Row(
                        children: [
                          // Thumbnail or placeholder
                          if (hasImage)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: Image.file(
                                File(_bankImages[key]!),
                                width: 36, height: 36, fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  width: 36, height: 36,
                                  color: AppTheme.background,
                                  child: Icon(Icons.broken_image, size: 16, color: AppTheme.textTertiary),
                                ),
                              ),
                            )
                          else
                            Container(
                              width: 36, height: 36,
                              decoration: BoxDecoration(
                                color: AppTheme.background,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Icon(Icons.image_outlined, size: 16, color: AppTheme.textTertiary),
                            ),
                          const SizedBox(width: 10),
                          // Key label
                          Expanded(
                            child: Text(displayKey, style: TextStyle(fontSize: 12, color: AppTheme.textPrimary), overflow: TextOverflow.ellipsis),
                          ),
                          // Upload / Remove buttons
                          if (hasImage)
                            GestureDetector(
                              onTap: () => setState(() => _bankImages.remove(key)),
                              child: Icon(Icons.close, size: 16, color: AppTheme.textTertiary),
                            ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () => _pickBankImage(key),
                            child: Icon(hasImage ? Icons.refresh : Icons.add_photo_alternate, size: 18, color: AppTheme.primary),
                          ),
                        ],
                      ),
                    );
                  }),
                ],

                // Image timestamp offset
                if (_outputMode == 'image' || _outputMode == 'both') ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text(_language == Language.french ? 'Antidater de' : 'Backdate by',
                          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 60,
                        child: TextField(
                          controller: TextEditingController(text: '$_imageTimestampOffset'),
                          keyboardType: TextInputType.number,
                          style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary),
                          textAlign: TextAlign.center,
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                            filled: true, fillColor: AppTheme.surface,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppTheme.border)),
                          ),
                          onChanged: (v) => _imageTimestampOffset = int.tryParse(v) ?? 0,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('min', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _language == Language.french
                        ? '0 = maintenant, 60 = il y a 1h, 1440 = hier'
                        : '0 = now, 60 = 1h ago, 1440 = yesterday',
                    style: TextStyle(fontSize: 10, color: AppTheme.textTertiary),
                  ),
                  // After save action
                  const SizedBox(height: 16),
                  Text(
                    _language == Language.french ? 'Après sauvegarde' : 'After save',
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _imageAfterSave = 'black'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: _imageAfterSave == 'black' ? AppTheme.primary : AppTheme.surface,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: _imageAfterSave == 'black' ? AppTheme.primary : AppTheme.border),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.dark_mode, size: 16, color: _imageAfterSave == 'black' ? Colors.white : AppTheme.textSecondary),
                                const SizedBox(width: 6),
                                Text('Black Screen', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _imageAfterSave == 'black' ? Colors.white : AppTheme.textSecondary)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _imageAfterSave = 'photos'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: _imageAfterSave == 'photos' ? AppTheme.primary : AppTheme.surface,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: _imageAfterSave == 'photos' ? AppTheme.primary : AppTheme.border),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.photo_library, size: 16, color: _imageAfterSave == 'photos' ? Colors.white : AppTheme.textSecondary),
                                const SizedBox(width: 6),
                                Text('Open Photos', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _imageAfterSave == 'photos' ? Colors.white : AppTheme.textSecondary)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

// ============= HELPER WIDGETS =============

class _SectionTitle extends StatelessWidget {
  final String title;
  final bool required;
  final VoidCallback? onInfoTap;

  const _SectionTitle({
    required this.title,
    this.required = false,
    this.onInfoTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title.toUpperCase(),
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
        if (onInfoTap != null) ...[
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onInfoTap,
            child: const Icon(
              Icons.info_outline,
              size: 18,
              color: AppTheme.primary,
            ),
          ),
        ],
      ],
    );
  }
}

/// Round mode selector for DUEL presets only
/// Allows selecting between Fixed Rounds and First-To modes
class _DuelRoundModeSelector extends StatelessWidget {
  final Language locale;
  final DuelMode selectedMode;
  final int targetScore;
  final ValueChanged<DuelMode> onModeChanged;
  final ValueChanged<int> onTargetScoreChanged;

  const _DuelRoundModeSelector({
    required this.locale,
    required this.selectedMode,
    required this.targetScore,
    required this.onModeChanged,
    required this.onTargetScoreChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Mode toggle
        Container(
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              // Fixed Rounds
              Expanded(
                child: GestureDetector(
                  onTap: () => onModeChanged(DuelMode.fixedRounds),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: selectedMode == DuelMode.fixedRounds
                          ? AppTheme.primary
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.repeat,
                          color: selectedMode == DuelMode.fixedRounds
                              ? Colors.white
                              : AppTheme.textTertiary,
                          size: 20,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          locale == Language.french ? 'Rounds Fixes' : 'Fixed Rounds',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: selectedMode == DuelMode.fixedRounds
                                ? Colors.white
                                : AppTheme.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // First To
              Expanded(
                child: GestureDetector(
                  onTap: () => onModeChanged(DuelMode.firstTo),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: selectedMode == DuelMode.firstTo
                          ? AppTheme.primary
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.emoji_events_outlined,
                          color: selectedMode == DuelMode.firstTo
                              ? Colors.white
                              : AppTheme.textTertiary,
                          size: 20,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          locale == Language.french ? 'Premier à' : 'First To',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: selectedMode == DuelMode.firstTo
                                ? Colors.white
                                : AppTheme.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Target score selector (only shown for First-To mode)
        if (selectedMode == DuelMode.firstTo) ...[
          const SizedBox(height: 16),
          Text(
            locale == Language.french
                ? 'Score cible (premier à atteindre)'
                : 'Target score (first to reach)',
            style: const TextStyle(
              fontSize: 13,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [1, 2, 3, 4, 5].map((score) {
              final isSelected = targetScore == score;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: GestureDetector(
                    onTap: () => onTargetScoreChanged(score),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected ? AppTheme.primary : AppTheme.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected ? AppTheme.primary : AppTheme.border,
                          width: 1,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          score.toString(),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: isSelected ? Colors.white : AppTheme.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}

/// Duel Score Bank section - editable narrative bank for duel mode
/// Templates are keyed by bucket: "rounds|spectatorWins-performerWins"
class _DuelScoreBankSection extends StatefulWidget {
  final Language locale;
  final int nbRounds;
  final InputMode inputMode;
  final List<String> labels;
  final List<int>? performerSequence;
  final Map<String, String>? customTemplates;
  final ValueChanged<Map<String, String>?> onChanged;
  final Map<String, String> bankImages;
  final Future<void> Function(String bankKey) onPickImage;
  final void Function(String bankKey) onRemoveImage;


  const _DuelScoreBankSection({
    required this.locale,
    required this.nbRounds,
    required this.inputMode,
    this.labels = const [],
    this.performerSequence,
    required this.customTemplates,
    required this.onChanged,
    required this.bankImages,
    required this.onPickImage,
    required this.onRemoveImage,
  });

  bool get isPreprogrammed => inputMode == InputMode.preprogrammed && performerSequence != null;

  @override
  State<_DuelScoreBankSection> createState() => _DuelScoreBankSectionState();
}

class _DuelScoreBankSectionState extends State<_DuelScoreBankSection> {
  bool _isExpanded = true;
  late Map<String, TextEditingController> _controllers;
  late Map<String, FocusNode> _focusNodes;
  String? _focusedBucketKey;
  late Map<String, String> _templates;

  // Narrative variable toggles
  bool _roundOutcomesEnabled = false;
  bool _samePatternEnabled = false;

  @override
  void initState() {
    super.initState();
    _templates = Map.from(widget.customTemplates ?? {});
    _roundOutcomesEnabled = _templates.keys.any((k) => RegExp(r'^__round\d+_(spectatorWin|performerWin|tie)__$').hasMatch(k));
    _samePatternEnabled = _templates.containsKey('__samePatternText__') || _templates.containsKey('__mixedPatternText__');

    _controllers = {};
    _focusNodes = {};
    _initControllers();
    // Collapse if all bucket texts are filled
    final bucketKeys = _getBucketsForRounds(widget.nbRounds).map((b) => b['key'] as String).toList();
    final allBucketsFilled = bucketKeys.isNotEmpty &&
        bucketKeys.every((k) => _templates[k]?.trim().isNotEmpty == true);
    _isExpanded = !allBucketsFilled;
  }

  void _initControllers() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    for (final focusNode in _focusNodes.values) {
      focusNode.dispose();
    }
    _controllers.clear();
    _focusNodes.clear();
    _focusedBucketKey = null;

    final buckets = _getBucketsForRounds(widget.nbRounds);
    for (final bucket in buckets) {
      final key = bucket['key'] as String;
      _controllers[key] = TextEditingController(
        text: _templates[key] ?? '',
      );
      final focusNode = FocusNode();
      focusNode.addListener(() {
        if (focusNode.hasFocus) {
          setState(() => _focusedBucketKey = key);
        }
      });
      _focusNodes[key] = focusNode;
    }
  }

  @override
  void didUpdateWidget(_DuelScoreBankSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.nbRounds != widget.nbRounds) {
      _templates = Map.from(widget.customTemplates ?? {});
      _initControllers();
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    for (final focusNode in _focusNodes.values) {
      focusNode.dispose();
    }
    super.dispose();
  }

  void _saveNarrVar(String key, String value) {
    if (value.trim().isEmpty) { _templates.remove(key); } else { _templates[key] = value; }
    widget.onChanged(_templates.isEmpty ? null : Map.from(_templates));
  }

  void _openFixedRoundsNarrativeModal() {
    final isFR = widget.locale == Language.french;
    final nbR = widget.nbRounds;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModalState) {
          // Keyboard-aware bottom padding so all fields stay reachable when
          // the soft keyboard is up.
          final keyboardInset = MediaQuery.of(ctx).viewInsets.bottom;
          return Container(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.92),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(margin: const EdgeInsets.only(top: 8), width: 40, height: 4,
                decoration: BoxDecoration(color: AppTheme.textTertiary, borderRadius: BorderRadius.circular(2))),
              Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 8), child: Row(children: [
                const Icon(Icons.tune, color: AppTheme.primary, size: 20), const SizedBox(width: 8),
                Expanded(child: Text(isFR ? 'Variables narratives' : 'Narrative variables',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimary))),
                GestureDetector(
                  onTap: () => Navigator.pop(ctx),
                  child: Text(isFR ? 'OK' : 'OK', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.primary)),
                ),
              ])),
              const Divider(height: 1, color: AppTheme.border),
              Expanded(child: SingleChildScrollView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + keyboardInset),
                child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Section 1: Auto variables
                  _buildFixedNarrSection(title: isFR ? 'Variables automatiques' : 'Automatic variables',
                    icon: Icons.info_outline, color: AppTheme.textTertiary,
                    child: Wrap(spacing: 6, runSpacing: 6, children: [
                      for (int i = 1; i <= nbR; i++) _NarrativeVarChip(name: '{choiceS$i}', desc: 'S r$i'),
                      for (int i = 1; i <= nbR; i++) _NarrativeVarChip(name: '{choiceP$i}', desc: 'P r$i'),
                    ])),
                  const SizedBox(height: 16),

                  // Section: Same Pattern Text — text injected via {samePatternText}
                  // depending on whether the spectator always picks the same gesture.
                  _buildFixedNarrToggle(title: isFR ? 'Same Pattern Text' : 'Same Pattern Text',
                    icon: Icons.repeat, color: Colors.teal, enabled: _samePatternEnabled,
                    onToggle: (v) { setModalState(() => _samePatternEnabled = v); setState(() => _samePatternEnabled = v);
                      if (!v) { _templates.remove('__samePatternText__'); _templates.remove('__mixedPatternText__');
                        widget.onChanged(_templates.isEmpty ? null : Map.from(_templates)); }},
                    children: [
                      Text(isFR
                          ? 'Variable {samePatternText} : injecte un texte différent selon que le spectateur joue toujours le même geste ou non.'
                          : '{samePatternText}: injects a different text depending on whether the spectator always plays the same gesture.',
                        style: const TextStyle(fontSize: 10, color: AppTheme.textTertiary)),
                      const SizedBox(height: 8),
                      _buildFixedNarrField(
                        key: '__samePatternText__',
                        label: isFR ? 'Toujours le même geste' : 'Always same gesture',
                        value: _templates['__samePatternText__'] ?? '',
                        onChanged: (v) { _saveNarrVar('__samePatternText__', v); }),
                      _buildFixedNarrField(
                        key: '__mixedPatternText__',
                        label: isFR ? 'Gestes variés' : 'Mixed gestures',
                        value: _templates['__mixedPatternText__'] ?? '',
                        onChanged: (v) { _saveNarrVar('__mixedPatternText__', v); }),
                    ]),
                  const SizedBox(height: 16),

                  // Section: Round-by-round outcomes
                  _buildFixedNarrToggle(title: isFR ? 'Résultat par round' : 'Per-round outcomes',
                    icon: Icons.format_list_numbered, color: Colors.purple, enabled: _roundOutcomesEnabled,
                    onToggle: (v) { setModalState(() => _roundOutcomesEnabled = v); setState(() => _roundOutcomesEnabled = v);
                      if (!v) { _templates.removeWhere((k, _) => RegExp(r'^__round\d+_').hasMatch(k));
                        widget.onChanged(_templates.isEmpty ? null : Map.from(_templates)); }},
                    children: [
                      _buildNarrVarsHint(nbR, isFR),
                      for (int r = 1; r <= nbR; r++) ...[
                        Padding(padding: const EdgeInsets.only(top: 8, bottom: 4),
                          child: Text('Round $r', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.purple.shade200))),
                        _buildFixedNarrField(key: '__round${r}_spectatorWin__', label: isFR ? 'Spectateur gagne' : 'Spectator wins',
                          value: _templates['__round${r}_spectatorWin__'] ?? '',
                          onChanged: (v) { _saveNarrVar('__round${r}_spectatorWin__', v); }),
                        _buildFixedNarrField(key: '__round${r}_performerWin__', label: isFR ? 'Performer gagne' : 'Performer wins',
                          value: _templates['__round${r}_performerWin__'] ?? '',
                          onChanged: (v) { _saveNarrVar('__round${r}_performerWin__', v); }),
                        _buildFixedNarrField(key: '__round${r}_tie__', label: isFR ? 'Égalité' : 'Tie',
                          value: _templates['__round${r}_tie__'] ?? '',
                          onChanged: (v) { _saveNarrVar('__round${r}_tie__', v); }),
                      ],
                    ]),
                  const SizedBox(height: 24),
                ],
              ))),
            ]),
          );
        },
      ),
    );
  }

  Widget _buildFixedNarrSection({required String title, required IconData icon, required Color color, required Widget child}) {
    return Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(
      color: AppTheme.background, borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withValues(alpha: 0.2))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Icon(icon, size: 16, color: color), const SizedBox(width: 8),
          Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color))]),
        const SizedBox(height: 8), child,
      ]));
  }

  Widget _buildFixedNarrToggle({required String title, required IconData icon, required Color color,
    required bool enabled, required ValueChanged<bool> onToggle, required List<Widget> children}) {
    return Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(
      color: AppTheme.background, borderRadius: BorderRadius.circular(10),
      border: Border.all(color: enabled ? color.withValues(alpha: 0.4) : AppTheme.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 16, color: enabled ? color : AppTheme.textTertiary), const SizedBox(width: 8),
          Expanded(child: Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: enabled ? color : AppTheme.textSecondary))),
          Switch.adaptive(value: enabled, onChanged: onToggle, activeColor: color),
        ]),
        if (enabled) ...[const SizedBox(height: 8), ...children],
      ]));
  }

  // Track the currently focused narrative field controller for chip insertion
  TextEditingController? _activeNarrFieldController;
  ValueChanged<String>? _activeNarrFieldOnChanged;

  // Stable controllers for narrative variable fields (keyed by template key)
  final Map<String, TextEditingController> _narrFieldControllers = {};
  final Map<String, FocusNode> _narrFieldFocusNodes = {};

  TextEditingController _getNarrController(String key, String initialValue) {
    if (!_narrFieldControllers.containsKey(key)) {
      _narrFieldControllers[key] = TextEditingController(text: initialValue);
    }
    return _narrFieldControllers[key]!;
  }

  FocusNode _getNarrFocusNode(String key, ValueChanged<String> onChanged) {
    if (!_narrFieldFocusNodes.containsKey(key)) {
      final node = FocusNode();
      node.addListener(() {
        if (node.hasFocus) {
          _activeNarrFieldController = _narrFieldControllers[key];
          _activeNarrFieldOnChanged = onChanged;
        }
      });
      _narrFieldFocusNodes[key] = node;
    }
    return _narrFieldFocusNodes[key]!;
  }

  Widget _buildNarrVarsHint(int nbRounds, bool isFR) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Wrap(
        spacing: 4, runSpacing: 4,
        children: [
          for (int i = 1; i <= nbRounds; i++)
            _buildNarrInsertChip('{choiceS$i}'),
          for (int i = 1; i <= nbRounds; i++)
            _buildNarrInsertChip('{choiceP$i}'),
        ],
      ),
    );
  }

  Widget _buildNarrInsertChip(String placeholder) {
    return GestureDetector(
      onTap: () {
        if (_activeNarrFieldController == null) return;
        final ctrl = _activeNarrFieldController!;
        final text = ctrl.text;
        final sel = ctrl.selection;
        final pos = sel.isValid ? sel.baseOffset : text.length;
        final newText = text.substring(0, pos) + placeholder + text.substring(pos);
        ctrl.text = newText;
        ctrl.selection = TextSelection.collapsed(offset: pos + placeholder.length);
        _activeNarrFieldOnChanged?.call(newText);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: AppTheme.accent.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: AppTheme.accent.withValues(alpha: 0.3)),
        ),
        child: Text(placeholder, style: const TextStyle(fontSize: 10, fontFamily: 'monospace', fontWeight: FontWeight.w600, color: AppTheme.accent)),
      ),
    );
  }

  Widget _buildFixedNarrField({required String key, required String label, required String value, required ValueChanged<String> onChanged}) {
    final controller = _getNarrController(key, value);
    final focusNode = _getNarrFocusNode(key, onChanged);
    final hasValue = controller.text.trim().isNotEmpty;
    return Padding(padding: const EdgeInsets.only(bottom: 8), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppTheme.textSecondary)),
      const SizedBox(height: 4),
      TextField(controller: controller, focusNode: focusNode, maxLines: 3, minLines: 1,
        style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary),
        decoration: InputDecoration(isDense: true, contentPadding: const EdgeInsets.all(10), filled: true, fillColor: AppTheme.surface,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.border)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: hasValue ? Colors.green.withValues(alpha: 0.5) : AppTheme.border)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.primary, width: 2))),
        onChanged: onChanged),
    ]));
  }

  void _onTextChanged(String bucketKey, String text) {
    if (text.trim().isEmpty) {
      _templates.remove(bucketKey);
    } else {
      _templates[bucketKey] = text;
    }
    widget.onChanged(_templates.isEmpty ? null : Map.from(_templates));
  }

  String _getBucketKey(int rounds, int spectatorWins, int performerWins) {
    return '$rounds|$spectatorWins-$performerWins';
  }

  List<Map<String, dynamic>> _getBucketsForRounds(int rounds) {
    final List<Map<String, dynamic>> buckets = [];
    for (int spectator = 0; spectator <= rounds; spectator++) {
      for (int performer = 0; performer <= rounds - spectator; performer++) {
        final ties = rounds - spectator - performer;
        buckets.add({
          'key': _getBucketKey(rounds, spectator, performer),
          'spectator': spectator,
          'performer': performer,
          'ties': ties,
        });
      }
    }
    return buckets;
  }

  int get _configuredCount {
    return _templates.entries
        .where((e) => e.value.trim().isNotEmpty)
        .length;
  }

  void _insertPlaceholder(String placeholder) {
    if (_focusedBucketKey == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sélectionnez d\'abord un champ de texte'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 1),
        ),
      );
      return;
    }

    final controller = _controllers[_focusedBucketKey];
    if (controller == null) return;

    final text = controller.text;
    final selection = controller.selection;
    final cursorPos = selection.isValid ? selection.baseOffset : text.length;

    final newText = text.substring(0, cursorPos) + placeholder + text.substring(cursorPos);
    controller.text = newText;
    controller.selection = TextSelection.collapsed(offset: cursorPos + placeholder.length);

    _onTextChanged(_focusedBucketKey!, newText);

    // Re-focus the field
    _focusNodes[_focusedBucketKey]?.requestFocus();
  }

  void _copyAsJson() {
    if (_templates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.locale == Language.french ? 'Aucun texte à copier' : 'No text to copy'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final json = {
      'rounds': widget.nbRounds,
      'buckets': _templates,
    };

    Clipboard.setData(ClipboardData(text: const JsonEncoder.withIndent('  ').convert(json)));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('JSON copié dans le presse-papiers'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _clearAll() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text(
          widget.locale == Language.french
              ? 'Effacer tous les textes ?'
              : 'Clear all texts?',
          style: const TextStyle(color: AppTheme.textPrimary),
        ),
        content: Text(
          widget.locale == Language.french
              ? 'Cette action effacera tous les textes de cette banque.'
              : 'This will clear all texts in this bank.',
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(widget.locale == Language.french ? 'Annuler' : 'Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _templates.clear();
                for (final controller in _controllers.values) {
                  controller.clear();
                }
                _samePatternEnabled = false;
                _roundOutcomesEnabled = false;
              });
              widget.onChanged(null);
            },
            child: Text(
              widget.locale == Language.french ? 'Effacer' : 'Clear',
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  void _openDuelImportModal() {
    BankImportModal.show(
      context: context,
      bankType: BankType.duelFixedRounds,
      language: widget.locale,
      rounds: widget.nbRounds,
      onImport: (entries, meta) {
        _applyGeneratedDuelBank(entries, 'Import');
      },
    );
  }

  void _applyGeneratedDuelBank(Map<String, String> generatedBank, String styleName) {
    setState(() {
      for (final entry in generatedBank.entries) {
        _templates[entry.key] = entry.value;
        _controllers[entry.key]?.text = entry.value;
      }
    });

    widget.onChanged(Map.from(_templates));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(widget.locale == Language.french
            ? 'Textes Duel $styleName générés'
            : 'Duel $styleName texts generated'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final buckets = _getBucketsForRounds(widget.nbRounds);
    final hasCustom = _configuredCount > 0;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasCustom ? Colors.green.withValues(alpha: 0.5) : AppTheme.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with expand/collapse
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
                          widget.locale == Language.french ? 'Banque de Narration' : 'Narrative Bank',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.locale == Language.french
                              ? '${widget.nbRounds} rounds • ${buckets.length} buckets'
                              : '${widget.nbRounds} rounds • ${buckets.length} buckets',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppTheme.accent,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (hasCustom)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        widget.locale == Language.french ? 'Configuré' : 'Configured',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.green,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          // Expanded content
          if (_isExpanded) ...[
            const Divider(height: 1, color: AppTheme.border),

            // Action buttons
            Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _ActionButton(
                    icon: Icons.auto_fix_high,
                    label: 'IA Import',
                    onTap: _openDuelImportModal,
                    color: Colors.teal,
                  ),
                  _ActionButton(
                    icon: Icons.copy,
                    label: widget.locale == Language.french ? 'Copier JSON' : 'Copy JSON',
                    onTap: _copyAsJson,
                  ),
                  if (hasCustom)
                    _ActionButton(
                      icon: Icons.clear_all,
                      label: widget.locale == Language.french ? 'Effacer' : 'Clear',
                      onTap: _clearAll,
                      color: Colors.red,
                    ),
                ],
              ),
            ),

            // Configure narrative variables button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _openFixedRoundsNarrativeModal,
                  icon: const Icon(Icons.tune, size: 16),
                  label: Text(widget.locale == Language.french ? 'Configurer les variables' : 'Configure variables'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primary,
                    side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.4)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Collapsible variables legend
            _CollapsibleFixedRoundsVariablesLegend(
              nbRounds: widget.nbRounds,
              locale: widget.locale,
            ),

            const Divider(height: 16, color: AppTheme.border),

            // Bucket editors
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: buckets.length,
              separatorBuilder: (_, __) => const Divider(height: 1, color: AppTheme.border),
              itemBuilder: (context, index) {
                final bucket = buckets[index];
                return _buildBucketEditor(bucket);
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBucketEditor(Map<String, dynamic> bucket) {
    final key = bucket['key'] as String;
    final spectator = bucket['spectator'] as int;
    final performer = bucket['performer'] as int;
    final ties = bucket['ties'] as int;
    final controller = _controllers[key];
    final focusNode = _focusNodes[key];
    final hasCustomText = _templates[key]?.trim().isNotEmpty ?? false;
    final isFocused = _focusedBucketKey == key;
    final isFR = widget.locale == Language.french;

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
                  color: hasCustomText
                      ? Colors.green.withValues(alpha: 0.2)
                      : AppTheme.accent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$spectator-$performer',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                    color: hasCustomText ? Colors.green : AppTheme.accent,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                isFR
                    ? 'Score $spectator - $performer${ties > 0 ? ' ($ties égalité${ties > 1 ? 's' : ''})' : ''}'
                    : 'Score $spectator - $performer${ties > 0 ? ' ($ties tie${ties > 1 ? 's' : ''})' : ''}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
              ),
              const Spacer(),
              if (hasCustomText)
                const Icon(Icons.check_circle, size: 16, color: Colors.green),
            ],
          ),
          // Performer sequence display (when preprogrammed and focused)
          if (isFocused && widget.isPreprogrammed) ...[
            const SizedBox(height: 4),
            Row(children: [
              Text('P: ', style: TextStyle(fontSize: 10, color: AppTheme.textTertiary, fontWeight: FontWeight.w600)),
              for (int i = 0; i < widget.nbRounds; i++) ...[
                if (i > 0) Text(', ', style: TextStyle(fontSize: 10, color: AppTheme.textTertiary)),
                Text(
                  i < widget.performerSequence!.length && widget.performerSequence![i] < widget.labels.length
                      ? widget.labels[widget.performerSequence![i]]
                      : '?',
                  style: TextStyle(fontSize: 10, color: AppTheme.textTertiary),
                ),
              ],
            ]),
          ],
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            focusNode: focusNode,
            textCapitalization: TextCapitalization.sentences,
            maxLines: 6,
            minLines: 2,
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.textPrimary,
            ),
            decoration: InputDecoration(
              hintText: widget.locale == Language.french ? 'Template vide = utilise le défaut' : 'Empty = use default',
              hintStyle: const TextStyle(
                fontSize: 11,
                color: AppTheme.textTertiary,
                fontStyle: FontStyle.italic,
              ),
              filled: true,
              fillColor: isFocused ? AppTheme.primary.withValues(alpha: 0.05) : AppTheme.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppTheme.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: hasCustomText ? Colors.green.withValues(alpha: 0.5) : AppTheme.border,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppTheme.primary, width: 2),
              ),
              contentPadding: const EdgeInsets.all(10),
            ),
            onChanged: (text) => _onTextChanged(key, text),
          ),
          // Clickable placeholder chips (shown only when focused)
          if (isFocused) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                // Per-round choices (always available)
                for (int i = 1; i <= widget.nbRounds; i++)
                  _PlaceholderChip(placeholder: '{choiceS$i}', description: 'S r$i', onTap: () => _insertPlaceholder('{choiceS$i}')),
                for (int i = 1; i <= widget.nbRounds; i++)
                  _PlaceholderChip(placeholder: '{choiceP$i}', description: 'P r$i', onTap: () => _insertPlaceholder('{choiceP$i}')),
                // Per-round outcome texts (only show chips for rounds with content)
                if (_roundOutcomesEnabled)
                  for (int i = 1; i <= widget.nbRounds; i++)
                    if ((_templates['__round${i}_spectatorWin__'] ?? '').trim().isNotEmpty ||
                        (_templates['__round${i}_performerWin__'] ?? '').trim().isNotEmpty ||
                        (_templates['__round${i}_tie__'] ?? '').trim().isNotEmpty)
                      _PlaceholderChip(placeholder: '{round${i}OutcomeText}', description: 'r$i', onTap: () => _insertPlaceholder('{round${i}OutcomeText}')),
                // Tie info (always shown when ties > 0)
                if (_samePatternEnabled)
                  _PlaceholderChip(placeholder: '{samePattern}', description: 'same gesture', onTap: () => _insertPlaceholder('{samePattern}')),
              ],
            ),
          ],
          // Preview
          if (hasCustomText && TemplatePreview.hasVariables(controller?.text ?? '')) ...[
            const SizedBox(height: 8),
            Builder(builder: (_) {
              final vars = TemplatePreview.buildDuelBucketSampleVars(
                spectatorWins: spectator,
                performerWins: performer,
                ties: ties,
                nbRounds: widget.nbRounds,
                labels: widget.labels,
                templates: _templates,
                performerSequence: widget.isPreprogrammed ? widget.performerSequence : null,
              );
              final rendered = TemplatePreview.render(controller!.text, vars);
              final unresolved = TemplatePreview.findUnresolved(rendered, {});
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: unresolved.isEmpty ? AppTheme.primary.withValues(alpha: 0.2) : Colors.orange.withValues(alpha: 0.4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.visibility, size: 12, color: AppTheme.primary.withValues(alpha: 0.6)),
                        const SizedBox(width: 4),
                        Text('Aperçu', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.primary.withValues(alpha: 0.6))),
                        if (unresolved.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Icon(Icons.warning_amber, size: 12, color: Colors.orange),
                          const SizedBox(width: 2),
                          Text('Variables manquantes', style: TextStyle(fontSize: 9, color: Colors.orange)),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(rendered, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary, fontStyle: FontStyle.italic, height: 1.4)),
                  ],
                ),
              );
            }),
          ],
          const SizedBox(height: 8),
          _BankImageControl(
            imagePath: widget.bankImages[key],
            onPick: () => widget.onPickImage(key),
            onRemove: () => widget.onRemoveImage(key),
            locale: widget.locale,
          ),
        ],
      ),
    );
  }
}

/// Action button widget for bank editors
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

/// Clickable placeholder chip for inserting placeholders into text fields
class _PlaceholderChip extends StatelessWidget {
  final String placeholder;
  final String description;
  final VoidCallback onTap;
  final bool isObject;

  const _PlaceholderChip({
    required this.placeholder,
    required this.description,
    required this.onTap,
    this.isObject = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isObject ? AppTheme.primary : AppTheme.accent;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              placeholder,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                fontFamily: isObject ? null : 'monospace',
                color: color,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              description,
              style: const TextStyle(
                fontSize: 9,
                color: AppTheme.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Read-only chip for displaying variable placeholders (no interaction)
class _ReadOnlyChip extends StatelessWidget {
  final String placeholder;
  final String description;

  const _ReadOnlyChip({
    required this.placeholder,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.textTertiary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.textTertiary.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            placeholder,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              fontFamily: 'monospace',
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            description,
            style: const TextStyle(
              fontSize: 9,
              color: AppTheme.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Mini insert chip for tie text fields
class _MiniInsertChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _MiniInsertChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: AppTheme.accent.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: AppTheme.accent.withValues(alpha: 0.3)),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, fontFamily: 'monospace', color: AppTheme.accent),
        ),
      ),
    );
  }
}

/// Variables legend for Fixed Rounds mode
class _CollapsibleFixedRoundsVariablesLegend extends StatefulWidget {
  final int nbRounds;
  final Language locale;

  const _CollapsibleFixedRoundsVariablesLegend({required this.nbRounds, required this.locale});

  @override
  State<_CollapsibleFixedRoundsVariablesLegend> createState() => _CollapsibleFixedRoundsVariablesLegendState();
}

class _CollapsibleFixedRoundsVariablesLegendState extends State<_CollapsibleFixedRoundsVariablesLegend> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final isFR = widget.locale == Language.french;
    final nbR = widget.nbRounds;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Row(
              children: [
                Icon(_expanded ? Icons.expand_less : Icons.expand_more, size: 18, color: AppTheme.textTertiary),
                const SizedBox(width: 4),
                Text(isFR ? 'Variables disponibles' : 'Available variables',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppTheme.textTertiary)),
              ],
            ),
          ),
          if (_expanded) ...[
            const SizedBox(height: 8),
            _sectionLabel(isFR ? 'Choix par round' : 'Choices per round'),
            for (int i = 1; i <= nbR; i++)
              _varRow('{choiceS$i}', isFR ? 'Choix spectateur round $i' : 'Spectator choice round $i'),
            for (int i = 1; i <= nbR; i++)
              _varRow('{choiceP$i}', isFR ? 'Choix performer round $i' : 'Performer choice round $i'),
            const SizedBox(height: 6),
            _sectionLabel(isFR ? 'Variables conditionnelles (via Configurer)' : 'Conditional (via Configure)'),
            for (int i = 1; i <= nbR; i++)
              _varRow('{round${i}OutcomeText}', isFR ? 'Texte round $i selon issue' : 'Round $i text by outcome'),
            _varRow('{samePattern}', isFR ? 'Texte selon geste répété ou varié' : 'Text by repeated/mixed gesture'),
          ],
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(padding: const EdgeInsets.only(top: 4, bottom: 2),
      child: Text(text, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.accent.withValues(alpha: 0.7))));
  }

  Widget _varRow(String name, String desc) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 1), child: Row(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(name, style: const TextStyle(fontSize: 10, fontFamily: 'monospace', fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
        const SizedBox(width: 6),
        Expanded(child: Text(desc, style: const TextStyle(fontSize: 10, color: AppTheme.textTertiary))),
      ]));
  }
}

class _FixedRoundsVariablesLegend extends StatelessWidget {
  final int nbRounds;
  final Language locale;
  final InputMode inputMode;

  const _FixedRoundsVariablesLegend({
    required this.nbRounds,
    required this.locale,
    required this.inputMode,
  });

  @override
  Widget build(BuildContext context) {
    final isFR = locale == Language.french;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isFR ? 'Variables disponibles :' : 'Available variables:',
            style: const TextStyle(
              fontSize: 11,
              color: AppTheme.textTertiary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _ReadOnlyChip(
                placeholder: '{spectatorSequence}',
                description: isFR ? 'séquence complète' : 'full sequence',
              ),
              for (int i = 1; i < nbRounds; i++)
                _ReadOnlyChip(
                  placeholder: '{whenTie$i}',
                  description: isFR ? 'nom manche tie $i' : 'tie $i round name',
                ),
              for (int i = 1; i <= nbRounds; i++)
                _ReadOnlyChip(
                  placeholder: '{choix$i}',
                  description: isFR ? 'choix round $i' : 'round $i choice',
                ),
              if (inputMode == InputMode.twoInputs)
                for (int i = 1; i <= nbRounds; i++)
                  _ReadOnlyChip(
                    placeholder: '{choicePerformer$i}',
                    description: isFR ? 'choix performer round $i' : 'performer round $i choice',
                  ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Toggle to choose between Buckets and Sequences modes for CHOICES
class _ChoicesNarrativeModeToggle extends StatelessWidget {
  final Language locale;
  final ChoicesNarrativeMode selectedMode;
  final ValueChanged<ChoicesNarrativeMode> onChanged;

  const _ChoicesNarrativeModeToggle({
    required this.locale,
    required this.selectedMode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isFrench = locale == Language.french;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isFrench ? 'Mode de Narration' : 'Narrative Mode',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isFrench
                ? 'Choisissez comment les textes sont organisés'
                : 'Choose how texts are organized',
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _ModeOption(
                  label: isFrench ? 'Buckets' : 'Buckets',
                  description: isFrench ? 'Par score (hits/miss)' : 'By score (hits/miss)',
                  isSelected: selectedMode == ChoicesNarrativeMode.buckets,
                  onTap: () => onChanged(ChoicesNarrativeMode.buckets),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ModeOption(
                  label: isFrench ? 'Séquences' : 'Sequences',
                  description: isFrench ? 'Par ordre exact' : 'By exact order',
                  isSelected: selectedMode == ChoicesNarrativeMode.sequences,
                  onTap: () => onChanged(ChoicesNarrativeMode.sequences),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ModeOption extends StatelessWidget {
  final String label;
  final String description;
  final bool isSelected;
  final VoidCallback onTap;

  const _ModeOption({
    required this.label,
    required this.description,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary.withValues(alpha: 0.1) : AppTheme.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppTheme.primary : AppTheme.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                  size: 18,
                  color: isSelected ? AppTheme.primary : AppTheme.textTertiary,
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? AppTheme.primary : AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 26),
              child: Text(
                description,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Variables legend for CHOICES bucket mode
class _ChoicesVariablesLegend extends StatelessWidget {
  final int nbRounds;
  final int nbOptions;
  final Language locale;

  const _ChoicesVariablesLegend({required this.nbRounds, this.nbOptions = 2, required this.locale});

  void _showVariablesInfo(BuildContext context) {
    final isFR = locale == Language.french;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isFR ? 'Variables disponibles' : 'Available variables',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 16),
            _VariableInfoRow(name: '{choiceS1}..{choiceS$nbRounds}', description: isFR ? 'Choix du spectateur au round N' : 'Spectator choice at round N'),
            const SizedBox(height: 8),
            _VariableInfoRow(name: '{choiceP1}..{choiceP$nbRounds}', description: isFR ? 'Choix du performer au round N' : 'Performer choice at round N'),
            if (nbOptions >= 3) ...[
              const SizedBox(height: 8),
              _VariableInfoRow(name: '{altS1}..{altS$nbRounds}', description: isFR ? 'Un choix alternatif (≠ choix réel) au round N' : 'An alternative choice (≠ actual) at round N'),
            ],
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isFR = locale == Language.french;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                isFR ? 'Variables disponibles :' : 'Available variables:',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.textTertiary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () => _showVariablesInfo(context),
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.textTertiary, width: 1),
                  ),
                  child: const Center(
                    child: Text('i', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.textTertiary)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (int i = 1; i <= nbRounds; i++)
                _ReadOnlyChip(placeholder: '{choiceS$i}', description: ''),
              for (int i = 1; i <= nbRounds; i++)
                _ReadOnlyChip(placeholder: '{choiceP$i}', description: ''),
              if (nbOptions >= 3)
                for (int i = 1; i <= nbRounds; i++)
                  _ReadOnlyChip(placeholder: '{altS$i}', description: ''),
            ],
          ),
        ],
      ),
    );
  }
}

class _VariableInfoRow extends StatelessWidget {
  final String name;
  final String description;

  const _VariableInfoRow({required this.name, required this.description});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: AppTheme.accent.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            name,
            style: const TextStyle(fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.w600, color: AppTheme.accent),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            description,
            style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
          ),
        ),
      ],
    );
  }
}

/// Choices Score Bank section - editable narrative bank for choices mode
/// Templates are keyed by H/M pattern (e.g. "HMH", "HHM")
class _ChoicesScoreBankSection extends StatefulWidget {
  final Language locale;
  final int nbRounds;
  final InputMode inputMode;
  final List<String> labels;
  final List<int>? performerSequence;
  final Map<String, String>? customTemplates;
  final ValueChanged<Map<String, String>?> onChanged;
  final Map<String, String> bankImages;
  final Future<void> Function(String bankKey) onPickImage;
  final void Function(String bankKey) onRemoveImage;

  const _ChoicesScoreBankSection({
    required this.locale,
    required this.nbRounds,
    required this.inputMode,
    required this.labels,
    this.performerSequence,
    required this.customTemplates,
    required this.onChanged,
    required this.bankImages,
    required this.onPickImage,
    required this.onRemoveImage,
  });

  bool get isPreprogrammed => inputMode == InputMode.preprogrammed && performerSequence != null;

  @override
  State<_ChoicesScoreBankSection> createState() => _ChoicesScoreBankSectionState();
}

class _ChoicesScoreBankSectionState extends State<_ChoicesScoreBankSection> {
  late bool _isExpanded;
  late Map<String, TextEditingController> _controllers;
  late Map<String, FocusNode> _focusNodes;
  String? _focusedBucketKey;
  late Map<String, String> _templates;

  @override
  void initState() {
    super.initState();
    _templates = Map.from(widget.customTemplates ?? {});
    // Collapse if all templates are already configured
    final hasConfigured = _templates.values.any((t) => t.trim().isNotEmpty);
    _isExpanded = !hasConfigured;
    _controllers = {};
    _focusNodes = {};
    _initControllers();
  }

  void _initControllers() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    for (final focusNode in _focusNodes.values) {
      focusNode.dispose();
    }
    _controllers.clear();
    _focusNodes.clear();
    _focusedBucketKey = null;

    final buckets = _getBucketsForRounds(widget.nbRounds);
    for (final bucket in buckets) {
      final key = bucket['key'] as String;
      _controllers[key] = TextEditingController(
        text: _templates[key] ?? '',
      );
      final focusNode = FocusNode();
      focusNode.addListener(() {
        if (focusNode.hasFocus) {
          setState(() => _focusedBucketKey = key);
        }
      });
      _focusNodes[key] = focusNode;
    }
  }

  @override
  void didUpdateWidget(_ChoicesScoreBankSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.nbRounds != widget.nbRounds ||
        oldWidget.inputMode != widget.inputMode) {
      _templates = Map.from(widget.customTemplates ?? {});
      _initControllers();
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    for (final focusNode in _focusNodes.values) {
      focusNode.dispose();
    }
    super.dispose();
  }

  void _onTextChanged(String bucketKey, String text) {
    if (text.trim().isEmpty) {
      _templates.remove(bucketKey);
    } else {
      _templates[bucketKey] = text;
    }
    widget.onChanged(_templates.isEmpty ? null : Map.from(_templates));
  }

  /// Generate all H/M pattern buckets for N rounds (2^N entries)
  /// Each pattern is a string like "HMH" representing hit/miss per round
  List<Map<String, dynamic>> _getBucketsForRounds(int rounds) {
    final List<Map<String, dynamic>> buckets = [];
    final total = 1 << rounds; // 2^rounds
    for (int i = 0; i < total; i++) {
      final buf = StringBuffer();
      int hits = 0;
      for (int bit = rounds - 1; bit >= 0; bit--) {
        final isHit = (i >> bit) & 1 == 0;
        buf.write(isHit ? 'H' : 'M');
        if (isHit) hits++;
      }
      final pattern = buf.toString();
      buckets.add({
        'key': pattern,
        'hits': hits,
        'misses': rounds - hits,
        'pattern': pattern,
      });
    }
    return buckets;
  }

  int get _configuredCount {
    return _templates.values.where((t) => t.trim().isNotEmpty).length;
  }

  void _insertPlaceholder(String placeholder) {
    if (_focusedBucketKey == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sélectionnez d\'abord un champ de texte'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 1),
        ),
      );
      return;
    }

    final controller = _controllers[_focusedBucketKey];
    if (controller == null) return;

    final text = controller.text;
    final selection = controller.selection;
    final cursorPos = selection.isValid ? selection.baseOffset : text.length;

    final newText = text.substring(0, cursorPos) + placeholder + text.substring(cursorPos);
    controller.text = newText;
    controller.selection = TextSelection.collapsed(offset: cursorPos + placeholder.length);

    _onTextChanged(_focusedBucketKey!, newText);

    _focusNodes[_focusedBucketKey]?.requestFocus();
  }

  void _copyAsJson() {
    if (_templates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.locale == Language.french ? 'Aucun texte à copier' : 'No text to copy'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final json = {
      'rounds': widget.nbRounds,
      'buckets': _templates,
    };

    Clipboard.setData(ClipboardData(text: const JsonEncoder.withIndent('  ').convert(json)));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('JSON copié dans le presse-papiers'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _clearAll() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text(
          widget.locale == Language.french
              ? 'Effacer tous les textes ?'
              : 'Clear all texts?',
          style: const TextStyle(color: AppTheme.textPrimary),
        ),
        content: Text(
          widget.locale == Language.french
              ? 'Cette action effacera tous les textes de cette banque.'
              : 'This will clear all texts in this bank.',
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(widget.locale == Language.french ? 'Annuler' : 'Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _templates.clear();
                for (final controller in _controllers.values) {
                  controller.clear();
                }
              });
              widget.onChanged(null);
            },
            child: Text(
              widget.locale == Language.french ? 'Effacer' : 'Clear',
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  void _openChoicesImportModal() {
    BankImportModal.show(
      context: context,
      bankType: BankType.choicesBucket,
      language: widget.locale,
      rounds: widget.nbRounds,
      options: widget.labels,
      performerSequenceIndices: widget.isPreprogrammed ? widget.performerSequence : null,
      onImport: (entries, meta) {
        _applyGeneratedChoicesBank(entries);
      },
    );
  }

  void _applyGeneratedChoicesBank(Map<String, String> generatedBank) {
    setState(() {
      for (final entry in generatedBank.entries) {
        _templates[entry.key] = entry.value;
        _controllers[entry.key]?.text = entry.value;
      }
    });

    widget.onChanged(Map.from(_templates));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(widget.locale == Language.french
            ? 'Textes Choices importés'
            : 'Choices texts imported'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showPreview(String templateText, String pattern, int hits, int misses) {
    final labels = widget.labels;
    final perfSeq = widget.performerSequence;
    final nbOptions = labels.length;

    // Build spectator + performer choices from pattern + performer sequence
    final spectatorChoices = <String>[];
    final performerChoices = <String>[];
    for (int i = 0; i < pattern.length; i++) {
      final perfIdx = (perfSeq != null && i < perfSeq.length) ? perfSeq[i] : 0;
      final perfLabel = perfIdx < labels.length ? labels[perfIdx] : '?';
      performerChoices.add(perfLabel);
      if (pattern[i] == 'H') {
        spectatorChoices.add(perfLabel);
      } else {
        // Pick a different label for miss
        if (nbOptions == 2) {
          spectatorChoices.add(labels[1 - perfIdx]);
        } else {
          final otherIdx = (perfIdx + 1) % nbOptions;
          spectatorChoices.add(labels[otherIdx]);
        }
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _ChoicesPreviewModal(
        templateText: templateText,
        nbRounds: widget.nbRounds,
        pattern: pattern,
        hits: hits,
        misses: misses,
        spectatorChoices: spectatorChoices,
        performerChoices: performerChoices,
        locale: widget.locale,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // FR and EN banks now available
    final buckets = _getBucketsForRounds(widget.nbRounds);
    final hasCustom = _configuredCount > 0;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasCustom ? Colors.green.withValues(alpha: 0.5) : AppTheme.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with expand/collapse
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
                          widget.locale == Language.french ? 'Banque de Narration' : 'Narrative Bank',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.locale == Language.french
                              ? '${widget.nbRounds} rounds • ${buckets.length} patterns H/M'
                              : '${widget.nbRounds} rounds • ${buckets.length} H/M patterns',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppTheme.accent,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (hasCustom)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        widget.locale == Language.french ? 'Configuré' : 'Configured',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.green,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          // Expanded content
          if (_isExpanded) ...[
            const Divider(height: 1, color: AppTheme.border),

            // Action buttons
            Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _ActionButton(
                    icon: Icons.auto_fix_high,
                    label: 'IA Import',
                    onTap: _openChoicesImportModal,
                    color: Colors.teal,
                  ),
                  _ActionButton(
                    icon: Icons.copy,
                    label: widget.locale == Language.french ? 'Copier JSON' : 'Copy JSON',
                    onTap: _copyAsJson,
                  ),
                  if (hasCustom)
                    _ActionButton(
                      icon: Icons.clear_all,
                      label: widget.locale == Language.french ? 'Effacer' : 'Clear',
                      onTap: _clearAll,
                      color: Colors.red,
                    ),
                ],
              ),
            ),

            // Variables legend (read-only)
            _ChoicesVariablesLegend(nbRounds: widget.nbRounds, nbOptions: widget.labels.length, locale: widget.locale),

            const Divider(height: 16, color: AppTheme.border),

            // Bucket editors
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: buckets.length,
              separatorBuilder: (_, __) => const Divider(height: 1, color: AppTheme.border),
              itemBuilder: (context, index) {
                final bucket = buckets[index];
                return _buildBucketEditor(bucket);
              },
            ),
          ],
        ],
      ),
    );
  }

  /// Build colored H/M pattern row (twoInputs mode)
  Widget _buildHMPatternRow(String pattern, bool hasCustomText) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < pattern.length; i++) ...[
          if (i > 0) const SizedBox(width: 2),
          Text(
            pattern[i],
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
              color: pattern[i] == 'H' ? Colors.green : Colors.red.shade300,
            ),
          ),
        ],
      ],
    );
  }

  /// Build spectator sequence display for preprogrammed mode
  Widget _buildSequenceDisplay(String pattern) {
    final perfSeq = widget.performerSequence!;
    final labels = widget.labels;
    final nbOptions = labels.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Spectator sequence
        Row(
          children: [
            Text(
              'S: ',
              style: TextStyle(fontSize: 11, color: AppTheme.textTertiary, fontWeight: FontWeight.w600),
            ),
            for (int i = 0; i < pattern.length; i++) ...[
              if (i > 0) Text(', ', style: TextStyle(fontSize: 11, color: AppTheme.textTertiary)),
              Text(
                pattern[i] == 'H'
                    ? (i < perfSeq.length && perfSeq[i] < labels.length ? labels[perfSeq[i]] : '?')
                    : (nbOptions == 2 && i < perfSeq.length && perfSeq[i] < labels.length
                        ? labels[1 - perfSeq[i]]
                        : '≠${i < perfSeq.length && perfSeq[i] < labels.length ? labels[perfSeq[i]] : '?'}'),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: pattern[i] == 'H' ? Colors.green : Colors.red.shade300,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 2),
        // Performer sequence (rappel)
        Row(
          children: [
            Text(
              'P: ',
              style: TextStyle(fontSize: 11, color: AppTheme.textTertiary, fontWeight: FontWeight.w600),
            ),
            for (int i = 0; i < pattern.length; i++) ...[
              if (i > 0) Text(', ', style: TextStyle(fontSize: 11, color: AppTheme.textTertiary)),
              Text(
                i < perfSeq.length && perfSeq[i] < labels.length ? labels[perfSeq[i]] : '?',
                style: TextStyle(fontSize: 11, color: AppTheme.textTertiary),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildBucketEditor(Map<String, dynamic> bucket) {
    final key = bucket['key'] as String;
    final hits = bucket['hits'] as int;
    final misses = bucket['misses'] as int;
    final controller = _controllers[key];
    final focusNode = _focusNodes[key];
    final hasCustomText = _templates[key]?.trim().isNotEmpty ?? false;
    final isFocused = _focusedBucketKey == key;
    final isPreprogrammed = widget.isPreprogrammed;

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row: pattern badge + stats + check icon
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: hasCustomText
                      ? Colors.green.withValues(alpha: 0.2)
                      : AppTheme.accent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: isPreprogrammed
                    ? _buildHMPatternRow(key, hasCustomText)
                    : _buildHMPatternRow(key, hasCustomText),
              ),
              const SizedBox(width: 8),
              Text(
                '$hits H / $misses M',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
              ),
              const Spacer(),
              if (hasCustomText) ...[
                GestureDetector(
                  onTap: () => _showPreview(_templates[key]!, key, hits, misses),
                  child: const Icon(Icons.visibility, size: 16, color: AppTheme.accent),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.check_circle, size: 16, color: Colors.green),
              ],
            ],
          ),
          // In preprogrammed mode: show spectator + performer sequences
          if (isPreprogrammed) ...[
            const SizedBox(height: 6),
            _buildSequenceDisplay(key),
          ],
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            focusNode: focusNode,
            textCapitalization: TextCapitalization.sentences,
            maxLines: 6,
            minLines: 2,
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.textPrimary,
            ),
            decoration: InputDecoration(
              hintText: widget.locale == Language.french ? 'Template vide = utilise le défaut' : 'Empty = use default',
              hintStyle: const TextStyle(
                fontSize: 11,
                color: AppTheme.textTertiary,
                fontStyle: FontStyle.italic,
              ),
              filled: true,
              fillColor: isFocused ? AppTheme.primary.withValues(alpha: 0.05) : AppTheme.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppTheme.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: hasCustomText ? Colors.green.withValues(alpha: 0.5) : AppTheme.border,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppTheme.primary, width: 2),
              ),
              contentPadding: const EdgeInsets.all(10),
            ),
            onChanged: (text) => _onTextChanged(key, text),
          ),
          // Clickable placeholder chips (shown only when focused)
          if (isFocused) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (int i = 1; i <= widget.nbRounds; i++)
                  _PlaceholderChip(
                    placeholder: '{choiceS$i}',
                    description: '',
                    onTap: () => _insertPlaceholder('{choiceS$i}'),
                  ),
                for (int i = 1; i <= widget.nbRounds; i++)
                  _PlaceholderChip(
                    placeholder: '{choiceP$i}',
                    description: '',
                    onTap: () => _insertPlaceholder('{choiceP$i}'),
                  ),
                if (widget.labels.length >= 3)
                  for (int i = 1; i <= widget.nbRounds; i++)
                    _PlaceholderChip(
                      placeholder: '{altS$i}',
                      description: '',
                      onTap: () => _insertPlaceholder('{altS$i}'),
                    ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          _BankImageControl(
            imagePath: widget.bankImages[key],
            onPick: () => widget.onPickImage(key),
            onRemove: () => widget.onRemoveImage(key),
            locale: widget.locale,
          ),
        ],
      ),
    );
  }
}

/// Image import / preview / delete control shown below a bank text field.
class _BankImageControl extends StatelessWidget {
  final String? imagePath;
  final VoidCallback onPick;
  final VoidCallback onRemove;
  final Language locale;

  const _BankImageControl({
    required this.imagePath,
    required this.onPick,
    required this.onRemove,
    required this.locale,
  });

  bool get _hasImage => imagePath != null && imagePath!.isNotEmpty;

  void _showPreview(BuildContext context) {
    if (!_hasImage) return;
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(ctx),
              child: InteractiveViewer(
                child: Center(
                  child: Image.file(
                    File(imagePath!),
                    errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.white54, size: 48),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: Material(
                color: Colors.black54,
                shape: const CircleBorder(),
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isFR = locale == Language.french;
    if (!_hasImage) {
      return GestureDetector(
        onTap: onPick,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.background,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.border, style: BorderStyle.solid),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_photo_alternate, size: 16, color: AppTheme.primary),
              const SizedBox(width: 6),
              Text(
                isFR ? 'Importer une image' : 'Import an image',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppTheme.primary),
              ),
            ],
          ),
        ),
      );
    }
    return Row(
      children: [
        GestureDetector(
          onTap: () => _showPreview(context),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.file(
              File(imagePath!),
              width: 48, height: 48, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 48, height: 48,
                color: AppTheme.background,
                child: const Icon(Icons.broken_image, size: 18, color: AppTheme.textTertiary),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: GestureDetector(
            onTap: () => _showPreview(context),
            child: Text(
              isFR ? 'Image importée · toucher pour voir' : 'Image imported · tap to preview',
              style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
            ),
          ),
        ),
        GestureDetector(
          onTap: onPick,
          child: const Padding(
            padding: EdgeInsets.all(6),
            child: Icon(Icons.refresh, size: 18, color: AppTheme.textSecondary),
          ),
        ),
        GestureDetector(
          onTap: onRemove,
          child: const Padding(
            padding: EdgeInsets.all(6),
            child: Icon(Icons.close, size: 18, color: Colors.redAccent),
          ),
        ),
      ],
    );
  }
}

/// Interactive preview modal for Choices bucket texts
class _ChoicesPreviewModal extends StatefulWidget {
  final String templateText;
  final int nbRounds;
  final String pattern;
  final int hits;
  final int misses;
  final List<String> spectatorChoices;
  final List<String> performerChoices;
  final Language locale;

  const _ChoicesPreviewModal({
    required this.templateText,
    required this.nbRounds,
    required this.pattern,
    required this.hits,
    required this.misses,
    required this.spectatorChoices,
    required this.performerChoices,
    required this.locale,
  });

  @override
  State<_ChoicesPreviewModal> createState() => _ChoicesPreviewModalState();
}

class _ChoicesPreviewModalState extends State<_ChoicesPreviewModal> {
  late List<String> _spectatorChoices;
  late List<String> _performerChoices;

  @override
  void initState() {
    super.initState();
    _spectatorChoices = List.from(widget.spectatorChoices);
    _performerChoices = List.from(widget.performerChoices);
  }

  String get _renderedText {
    var text = widget.templateText;
    text = text.replaceAll('{spectatorSequence}', _spectatorChoices.join(', '));
    text = text.replaceAll('{hitsCount}', widget.hits.toString());
    text = text.replaceAll('{missCount}', widget.misses.toString());
    for (int i = 0; i < _spectatorChoices.length; i++) {
      text = text.replaceAll('{choiceS${i + 1}}', _spectatorChoices[i]);
      text = text.replaceAll('{choix${i + 1}}', _spectatorChoices[i]);
      text = text.replaceAll('{choiceSpectator${i + 1}}', _spectatorChoices[i]);
    }
    for (int i = 0; i < _performerChoices.length; i++) {
      text = text.replaceAll('{choiceP${i + 1}}', _performerChoices[i]);
      text = text.replaceAll('{choicePerformer${i + 1}}', _performerChoices[i]);
    }
    return text;
  }

  @override
  Widget build(BuildContext context) {
    final isFR = widget.locale == Language.french;
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 40, height: 4,
            decoration: BoxDecoration(color: AppTheme.textTertiary, borderRadius: BorderRadius.circular(2)),
          ),
          // Title
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                const Icon(Icons.visibility, color: AppTheme.accent, size: 20),
                const SizedBox(width: 8),
                Text(
                  '${widget.pattern} — ${widget.hits} H / ${widget.misses} M',
                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppTheme.border),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Sequences display
                  Text(
                    isFR ? 'Valeurs de test :' : 'Test values:',
                    style: const TextStyle(fontSize: 12, color: AppTheme.textTertiary),
                  ),
                  const SizedBox(height: 8),
                  // Per-round display: S vs P with H/M indicator
                  for (int i = 0; i < widget.nbRounds; i++) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          Container(
                            width: 20,
                            alignment: Alignment.center,
                            child: Text(
                              widget.pattern[i],
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'monospace',
                                color: widget.pattern[i] == 'H' ? Colors.green : Colors.red.shade300,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'R${i + 1}:  S=',
                            style: const TextStyle(fontSize: 12, color: AppTheme.textTertiary),
                          ),
                          Text(
                            _spectatorChoices[i],
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: widget.pattern[i] == 'H' ? Colors.green : Colors.red.shade300,
                            ),
                          ),
                          Text(
                            '  P=',
                            style: const TextStyle(fontSize: 12, color: AppTheme.textTertiary),
                          ),
                          Text(
                            _performerChoices[i],
                            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  // Rendered text
                  Text(
                    isFR ? 'Résultat :' : 'Result:',
                    style: const TextStyle(fontSize: 12, color: AppTheme.textTertiary),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Text(
                      _renderedText,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 15,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Variables legend for First-To mode
class _NarrativeVarChip extends StatelessWidget {
  final String name;
  final String desc;

  const _NarrativeVarChip({required this.name, required this.desc});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.textTertiary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppTheme.textTertiary.withValues(alpha: 0.2)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(name, style: const TextStyle(fontSize: 10, fontFamily: 'monospace', fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
        const SizedBox(width: 4),
        Text(desc, style: const TextStyle(fontSize: 9, color: AppTheme.textTertiary)),
      ]),
    );
  }
}

class _CollapsibleFirstToVariablesLegend extends StatefulWidget {
  final int targetScore;
  final Language locale;
  final InputMode inputMode;

  const _CollapsibleFirstToVariablesLegend({
    required this.targetScore,
    required this.locale,
    required this.inputMode,
  });

  @override
  State<_CollapsibleFirstToVariablesLegend> createState() => _CollapsibleFirstToVariablesLegendState();
}

class _CollapsibleFirstToVariablesLegendState extends State<_CollapsibleFirstToVariablesLegend> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final isFR = widget.locale == Language.french;
    final maxRounds = (widget.targetScore * 2) - 1;
    final ordinals = ['1st', '2nd', '3rd', '4th', '5th'];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Row(
              children: [
                Icon(_expanded ? Icons.expand_less : Icons.expand_more, size: 18, color: AppTheme.textTertiary),
                const SizedBox(width: 4),
                Text(
                  isFR ? 'Variables disponibles' : 'Available variables',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppTheme.textTertiary),
                ),
                const Spacer(),
                if (!_expanded)
                  Text(
                    '${_countVariables(maxRounds, ordinals)}',
                    style: const TextStyle(fontSize: 10, color: AppTheme.textTertiary),
                  ),
              ],
            ),
          ),
          if (_expanded) ...[
            const SizedBox(height: 8),
            // Totals
            _varRow('{numRounds}', isFR ? 'Nombre total de rounds joués' : 'Total rounds played'),
            _varRow('{numRounds+1}', isFR ? 'Total rounds + 1' : 'Total rounds + 1'),
            _varRow('{numTies}', isFR ? 'Nombre d\'égalités' : 'Number of ties'),
            _varRow('{numTies+1}', isFR ? 'Égalités + 1' : 'Ties + 1'),
            const SizedBox(height: 6),
            // Choices per round (cap 5)
            _sectionLabel(isFR ? 'Choix par round (max 5)' : 'Choices per round (max 5)'),
            for (int i = 1; i <= maxRounds && i <= 5; i++)
              _varRow('{choiceS$i}', isFR ? 'Choix spectateur round $i' : 'Spectator choice round $i'),
            for (int i = 1; i <= maxRounds && i <= 5; i++)
              _varRow('{choiceP$i}', isFR ? 'Choix performer round $i' : 'Performer choice round $i'),
            const SizedBox(height: 6),
            // Highlight hooks
            _sectionLabel(isFR ? 'Rounds clés' : 'Key rounds'),
            _varRow('{1stNoTieSpectator}', isFR ? 'Choix spectateur du 1er round décisif' : '1st decisive round spectator choice'),
            _varRow('{1stNoTiePerformer}', isFR ? 'Choix performer du 1er round décisif' : '1st decisive round performer choice'),
            _varRow('{lastWinSpectator}', isFR ? 'Choix spectateur du dernier round' : 'Last round spectator choice'),
            _varRow('{lastWinPerformer}', isFR ? 'Choix performer du dernier round' : 'Last round performer choice'),
            _varRow('{1stTieChoice}', isFR ? 'Choix spectateur lors de la 1ère égalité' : 'Spectator choice at 1st tie'),
            _varRow('{When1stTie}', isFR ? 'Numéro du round de la 1ère égalité' : 'Round number of 1st tie'),
            const SizedBox(height: 6),
            // Conditional (via Configure)
            _sectionLabel(isFR ? 'Variables conditionnelles (via Configurer)' : 'Conditional (via Configure)'),
            for (int i = 1; i <= 5; i++)
              _varRow('{round${i}OutcomeText}', isFR ? 'Texte du round $i selon issue' : 'Round $i text by outcome'),
            _varRow('{samePattern}', isFR ? 'Texte selon geste répété ou varié' : 'Text by repeated/mixed gesture'),
            _varRow('{tieTextOrNoTieText}', isFR ? 'Texte égalité ou non' : 'Tie or no-tie text'),
            _varRow('{comebackText}', isFR ? 'Narration de comeback' : 'Comeback narrative'),
          ],
        ],
      ),
    );
  }

  int _countVariables(int maxRounds, List<String> ordinals) {
    // 4 totals + (cap-5 choices per side) + 6 highlight hooks + 5 round outcomes
    // + 3 conditional aggregates (samePattern, tieText, comebackText)
    final cappedRounds = maxRounds < 5 ? maxRounds : 5;
    return 4 + cappedRounds * 2 + 6 + 5 + 3;
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 2),
      child: Text(text, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.accent.withValues(alpha: 0.7))),
    );
  }

  Widget _varRow(String name, String desc) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name, style: const TextStyle(fontSize: 10, fontFamily: 'monospace', fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
          const SizedBox(width: 6),
          Expanded(child: Text(desc, style: const TextStyle(fontSize: 10, color: AppTheme.textTertiary))),
        ],
      ),
    );
  }
}

class _FirstToVariablesLegend extends StatelessWidget {
  final int targetScore;
  final Language locale;
  final InputMode inputMode;

  const _FirstToVariablesLegend({
    required this.targetScore,
    required this.locale,
    required this.inputMode,
  });

  @override
  Widget build(BuildContext context) {
    final isFR = locale == Language.french;
    final maxRounds = (targetScore * 2) - 1;
    final ordinals = ['1st', '2nd', '3rd', '4th', '5th'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                isFR ? 'Variables disponibles :' : 'Available variables:',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.textTertiary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () => _showVariablesInfo(context, isFR, maxRounds, ordinals),
                child: Icon(Icons.info_outline, size: 14, color: AppTheme.textTertiary),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              // Totals
              _ReadOnlyChip(placeholder: '{numRounds}', description: isFR ? 'nb rounds' : 'rounds'),
              _ReadOnlyChip(placeholder: '{numRounds+1}', description: 'rounds+1'),
              _ReadOnlyChip(placeholder: '{numTies}', description: isFR ? 'égalités' : 'ties'),
              _ReadOnlyChip(placeholder: '{numTies+1}', description: 'ties+1'),
              // Choices per round (cap 5)
              for (int i = 1; i <= maxRounds && i <= 5; i++)
                _ReadOnlyChip(placeholder: '{choiceS$i}', description: isFR ? 'choix S round $i' : 'S choice r$i'),
              for (int i = 1; i <= maxRounds && i <= 5; i++)
                _ReadOnlyChip(placeholder: '{choiceP$i}', description: isFR ? 'choix P round $i' : 'P choice r$i'),
              // Highlight hooks
              _ReadOnlyChip(placeholder: '{1stNoTieSpectator}', description: isFR ? '1er décisif S' : '1st decisive S'),
              _ReadOnlyChip(placeholder: '{1stNoTiePerformer}', description: isFR ? '1er décisif P' : '1st decisive P'),
              _ReadOnlyChip(placeholder: '{lastWinSpectator}', description: isFR ? 'dernier round S' : 'last round S'),
              _ReadOnlyChip(placeholder: '{lastWinPerformer}', description: isFR ? 'dernier round P' : 'last round P'),
              _ReadOnlyChip(placeholder: '{1stTieChoice}', description: isFR ? 'choix 1ère égalité' : '1st tie choice'),
              _ReadOnlyChip(placeholder: '{When1stTie}', description: isFR ? 'round 1ère égalité' : '1st tie pos'),
              // Conditional (always shown in legend so user knows they exist)
              for (int i = 1; i <= 5; i++)
                _ReadOnlyChip(placeholder: '{round${i}OutcomeText}', description: isFR ? 'texte round $i' : 'round $i text'),
              _ReadOnlyChip(placeholder: '{samePattern}', description: isFR ? 'pattern' : 'pattern'),
              _ReadOnlyChip(placeholder: '{tieTextOrNoTieText}', description: isFR ? 'égalité/non' : 'tie/no-tie'),
              _ReadOnlyChip(placeholder: '{comebackText}', description: 'comeback'),
            ],
          ),
        ],
      ),
    );
  }

  void _showVariablesInfo(BuildContext context, bool isFR, int maxRounds, List<String> ordinals) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text(
          isFR ? 'Variables First-To' : 'First-To Variables',
          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _infoRow('{numRounds}', isFR ? 'Nombre total de rounds joués' : 'Total rounds played'),
              _infoRow('{numRounds+1}', isFR ? 'Total rounds + 1' : 'Total rounds + 1'),
              _infoRow('{numTies}', isFR ? 'Nombre d\'égalités' : 'Number of ties'),
              _infoRow('{numTies+1}', isFR ? 'Égalités + 1' : 'Ties + 1'),
              const Divider(height: 16),
              _infoRow('{choiceS1}…{choiceS5}', isFR ? 'Choix spectateur par round (max 5)' : 'Spectator choice per round (max 5)'),
              _infoRow('{choiceP1}…{choiceP5}', isFR ? 'Choix performer par round (max 5)' : 'Performer choice per round (max 5)'),
              const Divider(height: 16),
              _infoRow('{1stNoTieSpectator}', isFR ? 'Choix spectateur du 1er round décisif' : 'Spectator choice of 1st decisive round'),
              _infoRow('{1stNoTiePerformer}', isFR ? 'Choix performer du 1er round décisif' : 'Performer choice of 1st decisive round'),
              _infoRow('{lastWinSpectator}', isFR ? 'Choix spectateur du dernier round' : 'Spectator choice of final round'),
              _infoRow('{lastWinPerformer}', isFR ? 'Choix performer du dernier round' : 'Performer choice of final round'),
              _infoRow('{1stTieChoice}', isFR ? 'Choix spectateur lors de la 1ère égalité' : 'Spectator choice at 1st tie'),
              _infoRow('{When1stTie}', isFR ? 'Numéro du round de la 1ère égalité' : 'Round number of 1st tie'),
              const Divider(height: 16),
              _infoRow('{round1OutcomeText}…{round5OutcomeText}', isFR ? 'Texte par round selon issue (via Configurer)' : 'Round text by outcome (via Configure)'),
              _infoRow('{samePattern}', isFR ? 'Texte selon geste répété/varié (via Configurer)' : 'Text by repeated/mixed gesture (via Configure)'),
              _infoRow('{tieTextOrNoTieText}', isFR ? 'Texte si égalité ou non (via Configurer)' : 'Tie / no-tie text (via Configure)'),
              _infoRow('{comebackText}', isFR ? 'Narration de comeback (via Configurer)' : 'Comeback narrative (via Configure)'),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
        ],
      ),
    );
  }

  static Widget _infoRow(String variable, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(variable, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.primary, fontFamily: 'monospace')),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(description, style: TextStyle(fontSize: 11, color: AppTheme.textSecondary))),
        ],
      ),
    );
  }
}

/// Editable First-To score bank section
class _DuelFirstToScoreBankSection extends StatefulWidget {
  final Language locale;
  final int targetScore;
  final InputMode inputMode;
  final List<String> labels;
  final Map<String, String>? customTemplates;
  final ValueChanged<Map<String, String>?> onChanged;
  final Map<String, String> bankImages;
  final Future<void> Function(String bankKey) onPickImage;
  final void Function(String bankKey) onRemoveImage;


  const _DuelFirstToScoreBankSection({
    required this.locale,
    required this.targetScore,
    required this.inputMode,
    this.labels = const [],
    required this.customTemplates,
    required this.onChanged,
    required this.bankImages,
    required this.onPickImage,
    required this.onRemoveImage,
  });

  @override
  State<_DuelFirstToScoreBankSection> createState() => _DuelFirstToScoreBankSectionState();
}

class _DuelFirstToScoreBankSectionState extends State<_DuelFirstToScoreBankSection> {
  // Storage keys for narrative variables
  // 3-tier ties narration: __noTieText__ (0), __tieText__ (1-3), __tieTextHigh__ (>3)
  static const _tieTextKey = '__tieText__';
  static const _noTieTextKey = '__noTieText__';
  static const _tieTextHighKey = '__tieTextHigh__';
  static const _remontadaSpectatorKey = '__remontadaSpectator__';
  static const _remontadaPerformerKey = '__remontadaPerformer__';
  // Early rounds keys: __r{N}_{tie|spectatorWin|performerWin}__
  // + __r3_finalWinSpectator__, __r3_finalWinPerformer__

  bool _isExpanded = true;
  late Map<String, TextEditingController> _controllers;
  late Map<String, FocusNode> _focusNodes;
  String? _focusedBucketKey;
  late Map<String, String> _templates;

  // Toggle states
  bool _tieTextEnabled = false;
  bool _remontadaEnabled = false;
  bool _samePatternEnabled = false;
  bool _earlyRoundsEnabled = false;

  // Tie text fields
  late TextEditingController _tieTextController;
  late TextEditingController _noTieTextController;
  late TextEditingController _tieTextHighController;
  late FocusNode _tieTextFocusNode;
  late FocusNode _noTieTextFocusNode;
  late FocusNode _tieTextHighFocusNode;

  @override
  void initState() {
    super.initState();
    _templates = Map.from(widget.customTemplates ?? {});

    // Initialize toggle states from stored templates
    _tieTextEnabled = _templates.containsKey(_tieTextKey) || _templates.containsKey(_noTieTextKey) || _templates.containsKey(_tieTextHighKey);
    _remontadaEnabled = _templates.containsKey(_remontadaSpectatorKey) || _templates.containsKey(_remontadaPerformerKey);
    _samePatternEnabled = _templates.containsKey('__samePatternText__') || _templates.containsKey('__mixedPatternText__');
    _earlyRoundsEnabled = _templates.keys.any((k) => k.startsWith('__r') && k.endsWith('__'));

    _tieTextController = TextEditingController(text: _templates[_tieTextKey] ?? '');
    _noTieTextController = TextEditingController(text: _templates[_noTieTextKey] ?? '');
    _tieTextHighController = TextEditingController(text: _templates[_tieTextHighKey] ?? '');
    _tieTextFocusNode = FocusNode();
    _noTieTextFocusNode = FocusNode();
    _tieTextHighFocusNode = FocusNode();

    _controllers = {};
    _focusNodes = {};
    _initControllers();
    // Collapse if all bucket texts are filled
    final ftKeys = DuelFirstToBuckets.generateBucketKeysForTarget(widget.targetScore);
    final allFtFilled = ftKeys.isNotEmpty &&
        ftKeys.every((k) => _templates[k]?.trim().isNotEmpty == true);
    _isExpanded = !allFtFilled;
  }

  void _initControllers() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    for (final focusNode in _focusNodes.values) {
      focusNode.dispose();
    }
    _controllers.clear();
    _focusNodes.clear();
    _focusedBucketKey = null;

    final bucketKeys = DuelFirstToBuckets.generateBucketKeysForTarget(widget.targetScore);
    for (final key in bucketKeys) {
      _controllers[key] = TextEditingController(
        text: _templates[key] ?? '',
      );
      final focusNode = FocusNode();
      focusNode.addListener(() {
        if (focusNode.hasFocus) {
          setState(() => _focusedBucketKey = key);
        }
      });
      _focusNodes[key] = focusNode;
    }
  }

  @override
  void didUpdateWidget(_DuelFirstToScoreBankSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.targetScore != widget.targetScore) {
      _templates = Map.from(widget.customTemplates ?? {});
      _initControllers();
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    for (final focusNode in _focusNodes.values) {
      focusNode.dispose();
    }
    _tieTextController.dispose();
    _noTieTextController.dispose();
    _tieTextHighController.dispose();
    _tieTextFocusNode.dispose();
    _noTieTextFocusNode.dispose();
    _tieTextHighFocusNode.dispose();
    super.dispose();
  }

  void _onTieTextChanged() {
    final tieText = _tieTextController.text;
    final noTieText = _noTieTextController.text;
    if (tieText.trim().isEmpty) {
      _templates.remove(_tieTextKey);
    } else {
      _templates[_tieTextKey] = tieText;
    }
    if (noTieText.trim().isEmpty) {
      _templates.remove(_noTieTextKey);
    } else {
      _templates[_noTieTextKey] = noTieText;
    }
    widget.onChanged(_templates.isEmpty ? null : Map.from(_templates));
  }

  void _saveNarrativeVar(String key, String value) {
    if (value.trim().isEmpty) {
      _templates.remove(key);
    } else {
      _templates[key] = value;
    }
    widget.onChanged(_templates.isEmpty ? null : Map.from(_templates));
  }

  void _removeNarrativeVarsWithPrefix(String prefix) {
    _templates.removeWhere((k, _) => k.startsWith(prefix));
    widget.onChanged(_templates.isEmpty ? null : Map.from(_templates));
  }

  void _openNarrativeVariablesModal() {
    final isFR = widget.locale == Language.french;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModalState) {
          // viewInsets.bottom = soft-keyboard height. We add it to the scroll
          // padding so the bottom fields stay reachable when the keyboard is
          // up (without it the keyboard covers the last fields with no way
          // to scroll past them).
          final keyboardInset = MediaQuery.of(ctx).viewInsets.bottom;
          final maxH = MediaQuery.of(ctx).size.height * 0.92;
          return Container(
            constraints: BoxConstraints(maxHeight: maxH),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(margin: const EdgeInsets.only(top: 8), width: 40, height: 4,
                  decoration: BoxDecoration(color: AppTheme.textTertiary, borderRadius: BorderRadius.circular(2))),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Row(
                    children: [
                      const Icon(Icons.tune, color: AppTheme.primary, size: 20),
                      const SizedBox(width: 8),
                      Expanded(child: Text(isFR ? 'Variables narratives' : 'Narrative variables',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimary))),
                      GestureDetector(
                        onTap: () => Navigator.pop(ctx),
                        child: Text(isFR ? 'OK' : 'OK', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.primary)),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: AppTheme.border),
                Expanded(
                  child: SingleChildScrollView(
                    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + keyboardInset),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Section 1: Auto variables
                        _buildNarrativeSection(title: isFR ? 'Variables automatiques' : 'Automatic variables',
                          subtitle: isFR ? 'Injectées automatiquement' : 'Injected automatically',
                          icon: Icons.info_outline, color: AppTheme.textTertiary,
                          child: Wrap(spacing: 6, runSpacing: 6, children: [
                            _NarrativeVarChip(name: '{numRounds}', desc: isFR ? 'nb rounds' : 'rounds'),
                            _NarrativeVarChip(name: '{numTies}', desc: isFR ? 'nb égalités' : 'ties'),
                          ])),
                        const SizedBox(height: 16),

                        // Section 2: Ties
                        _buildNarrativeToggleSection(title: isFR ? 'Narration des égalités' : 'Ties narration',
                          icon: Icons.handshake_outlined, color: Colors.orange, enabled: _tieTextEnabled,
                          description: isFR ? 'Texte injecté selon le nombre d\'égalités (0, 1-3, >3). Permet de personnaliser la narration autour des rounds nuls.' : 'Text injected based on number of ties (0, 1-3, >3). Customize narration around tied rounds.',
                          variableName: '{tieTextOrNoTieText}',
                          onToggle: (v) {
                            setModalState(() => _tieTextEnabled = v); setState(() => _tieTextEnabled = v);
                            if (!v) { _tieTextController.clear(); _noTieTextController.clear(); _tieTextHighController.clear();
                              _templates.remove(_tieTextKey); _templates.remove(_noTieTextKey); _templates.remove(_tieTextHighKey);
                              widget.onChanged(_templates.isEmpty ? null : Map.from(_templates)); }
                          },
                          children: [
                            _buildNarrativeTextField(label: isFR ? 'Si égalités ≤ 3' : 'If ties ≤ 3', hint: isFR ? 'Ex: avec {numTies} égalité(s)...' : '',
                              value: _templates[_tieTextKey] ?? '', onChanged: (v) { setModalState(() {}); _saveNarrativeVar(_tieTextKey, v); _tieTextController.text = v; }),
                            _buildNarrativeTextField(label: isFR ? 'Si égalités > 3' : 'If ties > 3', hint: '',
                              value: _templates[_tieTextHighKey] ?? '', onChanged: (v) { setModalState(() {}); _saveNarrativeVar(_tieTextHighKey, v); _tieTextHighController.text = v; }),
                            _buildNarrativeTextField(label: isFR ? 'Si aucune égalité' : 'If no ties', hint: '',
                              value: _templates[_noTieTextKey] ?? '', onChanged: (v) { setModalState(() {}); _saveNarrativeVar(_noTieTextKey, v); _noTieTextController.text = v; }),
                          ]),
                        const SizedBox(height: 16),

                        // Section: Same Pattern Text
                        _buildNarrativeToggleSection(title: 'Same Pattern Text',
                          icon: Icons.repeat, color: Colors.teal, enabled: _samePatternEnabled,
                          description: isFR
                              ? 'Variable {samePattern} : injecte un texte différent selon que le spectateur joue toujours le même geste ou non.'
                              : '{samePattern}: injects a different text depending on whether the spectator always plays the same gesture.',
                          variableName: '{samePattern}',
                          onToggle: (v) {
                            setModalState(() => _samePatternEnabled = v); setState(() => _samePatternEnabled = v);
                            if (!v) { _templates.remove('__samePatternText__'); _templates.remove('__mixedPatternText__');
                              widget.onChanged(_templates.isEmpty ? null : Map.from(_templates)); }
                          },
                          children: [
                            _buildNarrativeTextField(label: isFR ? 'Toujours le même geste' : 'Always same gesture', hint: '',
                              value: _templates['__samePatternText__'] ?? '',
                              onChanged: (v) { setModalState(() {}); _saveNarrativeVar('__samePatternText__', v); }),
                            _buildNarrativeTextField(label: isFR ? 'Gestes variés' : 'Mixed gestures', hint: '',
                              value: _templates['__mixedPatternText__'] ?? '',
                              onChanged: (v) { setModalState(() {}); _saveNarrativeVar('__mixedPatternText__', v); }),
                          ]),
                        const SizedBox(height: 16),

                        // Section: Remontada
                        _buildNarrativeToggleSection(title: isFR ? 'Narration de comeback' : 'Comeback narrative',
                          icon: Icons.trending_up, color: Colors.green, enabled: _remontadaEnabled,
                          description: isFR ? 'Texte injecté quand le gagnant était mené à un moment donné. Ajoute du suspense à la narration.' : 'Text injected when the winner was trailing at some point. Adds suspense to the narrative.',
                          variableName: '{comebackText}',
                          onToggle: (v) {
                            setModalState(() => _remontadaEnabled = v); setState(() => _remontadaEnabled = v);
                            if (!v) { _templates.remove(_remontadaSpectatorKey); _templates.remove(_remontadaPerformerKey);
                              widget.onChanged(_templates.isEmpty ? null : Map.from(_templates)); }
                          },
                          children: [
                            _buildNarrativeTextField(label: isFR ? 'Le spectateur remonte' : 'Spectator comes back', hint: '',
                              value: _templates[_remontadaSpectatorKey] ?? '', onChanged: (v) { setModalState(() {}); _saveNarrativeVar(_remontadaSpectatorKey, v); }),
                            _buildNarrativeTextField(label: isFR ? 'Le performer remonte' : 'Performer comes back', hint: '',
                              value: _templates[_remontadaPerformerKey] ?? '', onChanged: (v) { setModalState(() {}); _saveNarrativeVar(_remontadaPerformerKey, v); }),
                          ]),
                        const SizedBox(height: 16),

                        // Section: Per-round outcomes (rounds 1-5)
                        _buildNarrativeToggleSection(title: isFR ? 'Résultat par round (1-5)' : 'Per-round outcomes (1-5)',
                          icon: Icons.format_list_numbered, color: Colors.purple, enabled: _earlyRoundsEnabled,
                          description: isFR ? 'Un texte par round (selon Spectateur gagne / Performer gagne / Égalité). Inséré dans le bucket via {round1OutcomeText}…{round5OutcomeText}.' : 'One text per round (Spectator wins / Performer wins / Tie). Insert in the bucket template via {round1OutcomeText}…{round5OutcomeText}.',
                          variableName: '{round1OutcomeText}',
                          onToggle: (v) {
                            setModalState(() => _earlyRoundsEnabled = v); setState(() => _earlyRoundsEnabled = v);
                            if (!v) _removeNarrativeVarsWithPrefix('__round');
                          },
                          children: [
                            for (int r = 1; r <= 5; r++) ...[
                              Padding(padding: const EdgeInsets.only(top: 8, bottom: 4),
                                child: Text('Round $r', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.purple.shade200))),
                              _buildNarrativeTextField(label: isFR ? 'Spectateur gagne' : 'Spectator wins', hint: '', value: _templates['__round${r}_spectatorWin__'] ?? '',
                                onChanged: (v) { setModalState(() {}); _saveNarrativeVar('__round${r}_spectatorWin__', v); }),
                              _buildNarrativeTextField(label: isFR ? 'Performer gagne' : 'Performer wins', hint: '', value: _templates['__round${r}_performerWin__'] ?? '',
                                onChanged: (v) { setModalState(() {}); _saveNarrativeVar('__round${r}_performerWin__', v); }),
                              _buildNarrativeTextField(label: isFR ? 'Égalité' : 'Tie', hint: '', value: _templates['__round${r}_tie__'] ?? '',
                                onChanged: (v) { setModalState(() {}); _saveNarrativeVar('__round${r}_tie__', v); }),
                            ],
                          ]),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildNarrativeSection({required String title, String? subtitle, required IconData icon, required Color color, required Widget child}) {
    return Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(
      color: AppTheme.background, borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withValues(alpha: 0.2))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Icon(icon, size: 16, color: color), const SizedBox(width: 8),
          Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color))]),
        if (subtitle != null) ...[const SizedBox(height: 2), Text(subtitle, style: const TextStyle(fontSize: 10, color: AppTheme.textTertiary))],
        const SizedBox(height: 8), child,
      ]));
  }

  Widget _buildNarrativeToggleSection({required String title, required IconData icon, required Color color,
    required bool enabled, required ValueChanged<bool> onToggle, required List<Widget> children,
    String? description, String? variableName}) {
    return Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(
      color: AppTheme.background, borderRadius: BorderRadius.circular(10),
      border: Border.all(color: enabled ? color.withValues(alpha: 0.4) : AppTheme.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 16, color: enabled ? color : AppTheme.textTertiary), const SizedBox(width: 8),
          Expanded(child: Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: enabled ? color : AppTheme.textSecondary))),
          if (description != null)
            GestureDetector(
              onTap: () => _showNarrativeVarInfo(title, description, variableName),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Icon(Icons.info_outline, size: 14, color: enabled ? color.withValues(alpha: 0.6) : AppTheme.textTertiary),
              ),
            ),
          Switch.adaptive(value: enabled, onChanged: onToggle, activeColor: color),
        ]),
        if (enabled) ...[const SizedBox(height: 8), ...children],
      ]));
  }

  void _showNarrativeVarInfo(String title, String description, String? variableName) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: AppTheme.surface,
      title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(description, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.4)),
        if (variableName != null) ...[
          const SizedBox(height: 12),
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(
            color: AppTheme.accent.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
            child: Text(variableName, style: const TextStyle(fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.w600, color: AppTheme.accent))),
        ],
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
    ));
  }

  Widget _buildNarrativeTextField({required String label, required String hint, required String value, required ValueChanged<String> onChanged}) {
    return Padding(padding: const EdgeInsets.only(bottom: 8), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppTheme.textSecondary)),
      const SizedBox(height: 4),
      TextFormField(initialValue: value, maxLines: 3, minLines: 1,
        style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary),
        decoration: InputDecoration(hintText: hint.isEmpty ? null : hint,
          hintStyle: const TextStyle(fontSize: 11, color: AppTheme.textTertiary, fontStyle: FontStyle.italic),
          isDense: true, contentPadding: const EdgeInsets.all(10), filled: true, fillColor: AppTheme.surface,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.border)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: value.trim().isNotEmpty ? Colors.green.withValues(alpha: 0.5) : AppTheme.border)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.primary, width: 2))),
        onChanged: onChanged),
    ]));
  }

  void _onTextChanged(String bucketKey, String text) {
    if (text.trim().isEmpty) {
      _templates.remove(bucketKey);
    } else {
      _templates[bucketKey] = text;
    }
    widget.onChanged(_templates.isEmpty ? null : Map.from(_templates));
  }

  int get _configuredCount {
    // Don't count special narrative variable keys
    return _templates.entries
        .where((e) => !e.key.startsWith('__') && e.value.trim().isNotEmpty)
        .length;
  }

  void _insertIntoController(TextEditingController controller, FocusNode focusNode, String placeholder) {
    final text = controller.text;
    final selection = controller.selection;
    final cursorPos = selection.isValid ? selection.baseOffset : text.length;
    final newText = text.substring(0, cursorPos) + placeholder + text.substring(cursorPos);
    controller.text = newText;
    controller.selection = TextSelection.collapsed(offset: cursorPos + placeholder.length);
    _onTieTextChanged();
    focusNode.requestFocus();
  }

  void _insertPlaceholder(String placeholder) {
    if (_focusedBucketKey == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sélectionnez d\'abord un champ de texte'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 1),
        ),
      );
      return;
    }

    final controller = _controllers[_focusedBucketKey];
    if (controller == null) return;

    final text = controller.text;
    final selection = controller.selection;
    final cursorPos = selection.isValid ? selection.baseOffset : text.length;

    final newText = text.substring(0, cursorPos) + placeholder + text.substring(cursorPos);
    controller.text = newText;
    controller.selection = TextSelection.collapsed(offset: cursorPos + placeholder.length);

    _onTextChanged(_focusedBucketKey!, newText);

    _focusNodes[_focusedBucketKey]?.requestFocus();
  }

  void _copyAsJson() {
    if (_templates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.locale == Language.french ? 'Aucun texte à copier' : 'No text to copy'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final json = {
      'targetScore': widget.targetScore,
      'buckets': _templates,
    };

    Clipboard.setData(ClipboardData(text: const JsonEncoder.withIndent('  ').convert(json)));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('JSON copié dans le presse-papiers'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _clearAll() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text(
          widget.locale == Language.french
              ? 'Effacer tous les textes ?'
              : 'Clear all texts?',
          style: const TextStyle(color: AppTheme.textPrimary),
        ),
        content: Text(
          widget.locale == Language.french
              ? 'Cette action effacera tous les textes de cette banque.'
              : 'This will clear all texts in this bank.',
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(widget.locale == Language.french ? 'Annuler' : 'Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _templates.clear();
                for (final controller in _controllers.values) {
                  controller.clear();
                }
                _tieTextController.clear();
                _noTieTextController.clear();
                _tieTextHighController.clear();
                _tieTextEnabled = false;
              });
              widget.onChanged(null);
            },
            child: Text(
              widget.locale == Language.french ? 'Effacer' : 'Clear',
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }


  void _openFirstToImportModal() {
    BankImportModal.show(
      context: context,
      bankType: BankType.duelFirstTo,
      language: widget.locale,
      targetScore: widget.targetScore,
      onImport: (entries, meta) {
        _applyGeneratedFirstToBank(entries, 'Import');
      },
    );
  }

  void _applyGeneratedFirstToBank(Map<String, String> generatedBank, String styleName) {
    setState(() {
      for (final entry in generatedBank.entries) {
        _templates[entry.key] = entry.value;
        _controllers[entry.key]?.text = entry.value;
      }
    });

    widget.onChanged(Map.from(_templates));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(widget.locale == Language.french
            ? 'Textes First-To $styleName générés'
            : 'First-To $styleName texts generated'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bucketKeys = DuelFirstToBuckets.generateBucketKeysForTarget(widget.targetScore);
    final hasCustom = _configuredCount > 0;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasCustom ? Colors.green.withValues(alpha: 0.5) : AppTheme.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with expand/collapse
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
                          'Banque Premier à ${widget.targetScore}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${bucketKeys.length} buckets',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppTheme.accent,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (hasCustom)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        widget.locale == Language.french ? 'Configuré' : 'Configured',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.green,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          // Expanded content
          if (_isExpanded) ...[
            const Divider(height: 1, color: AppTheme.border),

            // Action buttons
            Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _ActionButton(
                    icon: Icons.auto_fix_high,
                    label: 'IA Import',
                    onTap: _openFirstToImportModal,
                    color: Colors.teal,
                  ),
                  _ActionButton(
                    icon: Icons.copy,
                    label: widget.locale == Language.french ? 'Copier JSON' : 'Copy JSON',
                    onTap: _copyAsJson,
                  ),
                  if (hasCustom)
                    _ActionButton(
                      icon: Icons.clear_all,
                      label: widget.locale == Language.french ? 'Effacer' : 'Clear',
                      onTap: _clearAll,
                      color: Colors.red,
                    ),
                ],
              ),
            ),

            // Configure narrative variables button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _openNarrativeVariablesModal,
                  icon: const Icon(Icons.tune, size: 16),
                  label: Text(widget.locale == Language.french ? 'Configurer les variables' : 'Configure variables'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primary,
                    side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.4)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Collapsible variables legend
            _CollapsibleFirstToVariablesLegend(
              targetScore: widget.targetScore,
              locale: widget.locale,
              inputMode: widget.inputMode,
            ),

            const Divider(height: 16, color: AppTheme.border),

            // Bucket editors
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: bucketKeys.length,
              separatorBuilder: (_, __) => const Divider(height: 1, color: AppTheme.border),
              itemBuilder: (context, index) {
                final key = bucketKeys[index];
                return _buildBucketEditor(key);
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBucketEditor(String bucketKey) {
    // Parse bucket key: FT{targetScore}_{S|P}_{winnerScore}-{loserScore}
    final parts = bucketKey.split('_');
    final spectatorWins = parts[1] == 'S';
    final scoreParts = parts[2].split('-');
    final winnerScore = int.parse(scoreParts[0]);
    final loserScore = int.parse(scoreParts[1]);

    final controller = _controllers[bucketKey];
    final focusNode = _focusNodes[bucketKey];
    final hasCustomText = _templates[bucketKey]?.trim().isNotEmpty ?? false;
    final isFocused = _focusedBucketKey == bucketKey;

    final winnerLabel = spectatorWins ? 'Spectateur' : 'Performeur';

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
                  color: hasCustomText
                      ? Colors.green.withValues(alpha: 0.2)
                      : (spectatorWins ? Colors.blue.withValues(alpha: 0.2) : Colors.orange.withValues(alpha: 0.2)),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$winnerScore-$loserScore',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                    color: hasCustomText ? Colors.green : (spectatorWins ? Colors.blue : Colors.orange),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$winnerLabel gagne $winnerScore-$loserScore',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
              if (hasCustomText)
                const Icon(Icons.check_circle, size: 16, color: Colors.green),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            focusNode: focusNode,
            textCapitalization: TextCapitalization.sentences,
            maxLines: 6,
            minLines: 2,
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.textPrimary,
            ),
            decoration: InputDecoration(
              hintText: widget.locale == Language.french ? 'Template vide = utilise le défaut' : 'Empty = use default',
              hintStyle: const TextStyle(
                fontSize: 11,
                color: AppTheme.textTertiary,
                fontStyle: FontStyle.italic,
              ),
              filled: true,
              fillColor: isFocused ? AppTheme.primary.withValues(alpha: 0.05) : AppTheme.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppTheme.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: hasCustomText ? Colors.green.withValues(alpha: 0.5) : AppTheme.border,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppTheme.primary, width: 2),
              ),
              contentPadding: const EdgeInsets.all(10),
            ),
            onChanged: (text) => _onTextChanged(bucketKey, text),
          ),
          // Clickable placeholder chips (shown only when focused)
          if (isFocused) ...[
            const SizedBox(height: 8),
            Builder(
              builder: (context) {
                final totalRounds = winnerScore + loserScore;
                final isFR = widget.locale == Language.french;
                // A chip for a section-gated variable only shows up if the
                // user actually filled at least one of the underlying fields
                // — keeps the palette honest about what will substitute.
                bool _hasAny(List<String> keys) =>
                    keys.any((k) => (_templates[k] ?? '').trim().isNotEmpty);
                return Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    // Totals
                    _PlaceholderChip(placeholder: '{numRounds}', description: isFR ? 'nb rounds' : 'rounds', onTap: () => _insertPlaceholder('{numRounds}')),
                    _PlaceholderChip(placeholder: '{numRounds+1}', description: isFR ? 'rounds+1' : 'rounds+1', onTap: () => _insertPlaceholder('{numRounds+1}')),
                    _PlaceholderChip(placeholder: '{numTies}', description: isFR ? 'nb egal' : 'ties', onTap: () => _insertPlaceholder('{numTies}')),
                    _PlaceholderChip(placeholder: '{numTies+1}', description: isFR ? 'egal+1' : 'ties+1', onTap: () => _insertPlaceholder('{numTies+1}')),
                    // Per-round choices (cap at 5)
                    for (int i = 1; i <= totalRounds && i <= 5; i++)
                      _PlaceholderChip(placeholder: '{choiceS$i}', description: 'S r$i', onTap: () => _insertPlaceholder('{choiceS$i}')),
                    for (int i = 1; i <= totalRounds && i <= 5; i++)
                      _PlaceholderChip(placeholder: '{choiceP$i}', description: 'P r$i', onTap: () => _insertPlaceholder('{choiceP$i}')),
                    // Highlight hooks
                    _PlaceholderChip(placeholder: '{1stNoTieSpectator}', description: '1st S', onTap: () => _insertPlaceholder('{1stNoTieSpectator}')),
                    _PlaceholderChip(placeholder: '{1stNoTiePerformer}', description: '1st P', onTap: () => _insertPlaceholder('{1stNoTiePerformer}')),
                    _PlaceholderChip(placeholder: '{lastWinSpectator}', description: 'last S', onTap: () => _insertPlaceholder('{lastWinSpectator}')),
                    _PlaceholderChip(placeholder: '{lastWinPerformer}', description: 'last P', onTap: () => _insertPlaceholder('{lastWinPerformer}')),
                    _PlaceholderChip(placeholder: '{1stTieChoice}', description: '1st tie', onTap: () => _insertPlaceholder('{1stTieChoice}')),
                    _PlaceholderChip(placeholder: '{When1stTie}', description: '1st tie pos', onTap: () => _insertPlaceholder('{When1stTie}')),
                    // Conditional (only if the underlying section has content)
                    if (_samePatternEnabled && _hasAny(['__samePatternText__', '__mixedPatternText__']))
                      _PlaceholderChip(placeholder: '{samePattern}', description: isFR ? 'pattern' : 'pattern', onTap: () => _insertPlaceholder('{samePattern}')),
                    if (_tieTextEnabled && _hasAny([_tieTextKey, _noTieTextKey]))
                      _PlaceholderChip(placeholder: '{tieTextOrNoTieText}', description: isFR ? 'égalité' : 'tie', onTap: () => _insertPlaceholder('{tieTextOrNoTieText}')),
                    if (_remontadaEnabled && _hasAny([_remontadaSpectatorKey, _remontadaPerformerKey]))
                      _PlaceholderChip(placeholder: '{comebackText}', description: 'comeback', onTap: () => _insertPlaceholder('{comebackText}')),
                    if (_earlyRoundsEnabled) ...[
                      for (int r = 1; r <= 5; r++)
                        if (_hasAny(['__round${r}_spectatorWin__', '__round${r}_performerWin__', '__round${r}_tie__']))
                          _PlaceholderChip(placeholder: '{round${r}OutcomeText}', description: 'r$r', onTap: () => _insertPlaceholder('{round${r}OutcomeText}')),
                    ],
                  ],
                );
              },
            ),
          ],
          // Preview for First-To
          if (hasCustomText && TemplatePreview.hasVariables(controller?.text ?? '')) ...[
            const SizedBox(height: 8),
            Builder(builder: (_) {
              final totalRounds = winnerScore + loserScore;
              final tiesCount = totalRounds - winnerScore - loserScore; // always 0 for min rounds
              final sWins = spectatorWins ? winnerScore : loserScore;
              final pWins = spectatorWins ? loserScore : winnerScore;
              final vars = TemplatePreview.buildDuelBucketSampleVars(
                spectatorWins: sWins,
                performerWins: pWins,
                ties: tiesCount,
                nbRounds: totalRounds,
                labels: widget.labels,
                templates: _templates,
              );
              final rendered = TemplatePreview.render(controller!.text, vars);
              final unresolved = TemplatePreview.findUnresolved(rendered, {});
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: unresolved.isEmpty ? AppTheme.primary.withValues(alpha: 0.2) : Colors.orange.withValues(alpha: 0.4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.visibility, size: 12, color: AppTheme.primary.withValues(alpha: 0.6)),
                        const SizedBox(width: 4),
                        Text('Aperçu', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.primary.withValues(alpha: 0.6))),
                        if (unresolved.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Icon(Icons.warning_amber, size: 12, color: Colors.orange),
                          const SizedBox(width: 2),
                          Text('Variables manquantes', style: TextStyle(fontSize: 9, color: Colors.orange)),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(rendered, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary, fontStyle: FontStyle.italic, height: 1.4)),
                  ],
                ),
              );
            }),
          ],
          const SizedBox(height: 8),
          _BankImageControl(
            imagePath: widget.bankImages[bucketKey],
            onPick: () => widget.onPickImage(bucketKey),
            onRemove: () => widget.onRemoveImage(bucketKey),
            locale: widget.locale,
          ),
        ],
      ),
    );
  }
}

class _NumberSelector extends StatelessWidget {
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  const _NumberSelector({
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: value > min ? () => onChanged(value - 1) : null,
            icon: Icon(
              Icons.remove_circle_outline,
              color: value > min ? AppTheme.primary : AppTheme.textTertiary,
            ),
          ),
          Text(
            '$value',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          IconButton(
            onPressed: value < max ? () => onChanged(value + 1) : null,
            icon: Icon(
              Icons.add_circle_outline,
              color: value < max ? AppTheme.primary : AppTheme.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

class _InputModeSelector extends StatelessWidget {
  final InputMode selectedMode;
  final Language locale;
  final ValueChanged<InputMode> onChanged;

  const _InputModeSelector({
    required this.selectedMode,
    required this.locale,
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
          final label = mode == InputMode.preprogrammed
              ? (locale == Language.french ? 'Pré-programmé' : 'Pre-programmed')
              : (locale == Language.french ? 'Double Entrée' : 'Double Input');
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
                    Icon(
                      mode == InputMode.preprogrammed ? Icons.lock_outline : Icons.swap_horiz,
                      color: isSelected ? Colors.white : AppTheme.textSecondary,
                      size: 20,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.white : AppTheme.textSecondary,
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

class _PerformerSequenceInline extends StatelessWidget {
  final int nbRounds;
  final List<String> labels;
  final List<int> sequence;
  final Language locale;
  final Map<String, String?> errors;
  final ValueChanged<List<int>> onChanged;
  final bool isFirstTo;

  const _PerformerSequenceInline({
    required this.nbRounds,
    required this.labels,
    required this.sequence,
    required this.locale,
    required this.errors,
    required this.onChanged,
    this.isFirstTo = false,
  });

  @override
  Widget build(BuildContext context) {
    final title = locale == Language.french ? 'SÉQUENCE PERFORMER' : 'PERFORMER SEQUENCE';
    final firstToNote = locale == Language.french
        ? 'Les égalités ne consomment pas la séquence'
        : 'Ties do not consume the sequence';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: errors.keys.any((k) => k.startsWith('sequence'))
            ? Border.all(color: Colors.red, width: 1)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
              letterSpacing: 1,
            ),
          ),
          if (isFirstTo) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.info_outline,
                    size: 12,
                    color: AppTheme.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    firstToNote,
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          ...List.generate(nbRounds, (index) {
            final currentValue = index < sequence.length ? sequence[index] : 0;
            final hasError = errors['sequence_$index'] != null;

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: hasError ? Colors.red : AppTheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: AppTheme.background,
                        borderRadius: BorderRadius.circular(8),
                        border: hasError ? Border.all(color: Colors.red) : null,
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: currentValue.clamp(0, labels.length - 1),
                          isExpanded: true,
                          dropdownColor: AppTheme.surface,
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 14,
                          ),
                          items: List.generate(labels.length, (optionIndex) {
                            final label = labels[optionIndex].isNotEmpty
                                ? labels[optionIndex]
                                : 'Option ${optionIndex + 1}';
                            return DropdownMenuItem(
                              value: optionIndex,
                              child: Text(label),
                            );
                          }),
                          onChanged: (value) {
                            if (value != null) {
                              final newSequence = List<int>.from(sequence);
                              while (newSequence.length <= index) {
                                newSequence.add(0);
                              }
                              newSequence[index] = value;
                              onChanged(newSequence);
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          if (errors['sequence'] != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                errors['sequence']!,
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }
}

// ============= STEALTH INPUT WIDGETS =============

class _ApiVariableBlock extends StatefulWidget {
  final String label;
  final IconData icon;
  final bool enabled;
  final ValueChanged<bool> onToggle;
  final TextEditingController successController;
  final TextEditingController fallbackController;
  final String successHint;
  final List<String> variables;
  final Language locale;
  final List<Widget>? extraFields;
  final TextEditingController? transformPromptController;
  final List<String>? transformVariableNames; // e.g. ['inject_text'] or ['artist', 'song']

  const _ApiVariableBlock({
    required this.label,
    required this.icon,
    required this.enabled,
    required this.onToggle,
    required this.successController,
    required this.fallbackController,
    required this.successHint,
    required this.variables,
    required this.locale,
    this.extraFields,
    this.transformPromptController,
    this.transformVariableNames,
  });

  @override
  State<_ApiVariableBlock> createState() => _ApiVariableBlockState();
}

class _ApiVariableBlockState extends State<_ApiVariableBlock> {
  TextEditingController? _focusedController;
  final TextEditingController _testInputController = TextEditingController();
  String? _testResult;
  bool _isTesting = false;

  void _insertVariable(String variable) {
    final controller = _focusedController ?? widget.successController;
    final text = controller.text;
    final selection = controller.selection;
    final cursorPos = selection.isValid ? selection.baseOffset : text.length;
    final newText = text.substring(0, cursorPos) + variable + text.substring(cursorPos);
    controller.text = newText;
    controller.selection = TextSelection.collapsed(offset: cursorPos + variable.length);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: widget.enabled ? AppTheme.primary.withOpacity(0.5) : AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(widget.icon, size: 18, color: widget.enabled ? AppTheme.primary : AppTheme.textSecondary),
              const SizedBox(width: 8),
              Text(widget.label, style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w600,
                color: widget.enabled ? AppTheme.textPrimary : AppTheme.textSecondary,
              )),
              const Spacer(),
              Switch.adaptive(
                value: widget.enabled,
                onChanged: widget.onToggle,
                activeColor: AppTheme.primary,
              ),
            ],
          ),
          if (widget.enabled) ...[
            const SizedBox(height: 8),
            // Variable chips
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: widget.variables.map((v) => InkWell(
                onTap: () => _insertVariable(v),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppTheme.accent.withOpacity(0.3)),
                  ),
                  child: Text(v, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, fontFamily: 'monospace', color: AppTheme.accent)),
                ),
              )).toList(),
            ),
            const SizedBox(height: 8),
            Focus(
              onFocusChange: (hasFocus) {
                if (hasFocus) setState(() => _focusedController = widget.successController);
              },
              child: TextField(
                controller: widget.successController,
                maxLines: 3,
                minLines: 1,
                style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  labelText: widget.locale == Language.french ? 'Texte si succès' : 'Success text',
                  labelStyle: const TextStyle(fontSize: 12, color: AppTheme.textTertiary),
                  hintText: widget.successHint,
                  hintStyle: const TextStyle(fontSize: 11, color: AppTheme.textTertiary),
                  filled: true, fillColor: AppTheme.background,
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.border)),
                  contentPadding: const EdgeInsets.all(10),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Focus(
              onFocusChange: (hasFocus) {
                if (hasFocus) setState(() => _focusedController = widget.fallbackController);
              },
              child: TextField(
                controller: widget.fallbackController,
                maxLines: 2,
                minLines: 1,
                style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  labelText: widget.locale == Language.french ? 'Texte fallback (optionnel)' : 'Fallback text (optional)',
                  labelStyle: const TextStyle(fontSize: 12, color: AppTheme.textTertiary),
                  hintText: widget.locale == Language.french ? 'Si API indisponible (vide = supprimé)' : 'If API unavailable (empty = removed)',
                  hintStyle: const TextStyle(fontSize: 11, color: AppTheme.textTertiary),
                  filled: true, fillColor: AppTheme.background,
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.border)),
                  contentPadding: const EdgeInsets.all(10),
                ),
              ),
            ),
            // Transform prompt (Inject/Elips only)
            if (widget.transformPromptController != null) ...[
              const SizedBox(height: 10),
              Text(
                widget.locale == Language.french ? 'Prompt de transformation (IA)' : 'Transform prompt (AI)',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 4),
              TextField(
                controller: widget.transformPromptController!,
                maxLines: 2,
                minLines: 1,
                style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  hintText: widget.locale == Language.french
                      ? 'Ex: Donne-moi la capitale de ce pays : {value}'
                      : 'Ex: Give me the capital of this country: {value}',
                  hintStyle: const TextStyle(fontSize: 10, color: AppTheme.textTertiary),
                  filled: true, fillColor: AppTheme.background,
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.border)),
                  contentPadding: const EdgeInsets.all(8),
                ),
              ),
              const SizedBox(height: 6),
              // Test row
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _testInputController,
                      style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary),
                      decoration: InputDecoration(
                        hintText: widget.locale == Language.french ? 'Input test...' : 'Test input...',
                        hintStyle: const TextStyle(fontSize: 11, color: AppTheme.textTertiary),
                        filled: true, fillColor: AppTheme.background,
                        isDense: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.border)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  SizedBox(
                    height: 32,
                    child: ElevatedButton(
                      onPressed: _isTesting ? null : () async {
                        final prompt = widget.transformPromptController!.text.trim();
                        final input = _testInputController.text.trim();
                        if (prompt.isEmpty || input.isEmpty) return;

                        final settings = context.read<SettingsProvider>();
                        if (!settings.hasOpenaiApiKey) {
                          setState(() => _testResult = 'OpenAI key required');
                          return;
                        }

                        setState(() { _isTesting = true; _testResult = null; });

                        // Build test variables
                        final vars = <String, String>{'value': input};
                        if (widget.transformVariableNames != null) {
                          for (final name in widget.transformVariableNames!) {
                            vars[name] = input;
                          }
                        }

                        final result = await ExternalApiService.transformWithPrompt(
                          prompt: prompt,
                          openaiApiKey: settings.openaiApiKey,
                          variables: vars,
                        );

                        if (mounted) {
                          setState(() {
                            _isTesting = false;
                            _testResult = result ?? 'Error';
                          });
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        textStyle: const TextStyle(fontSize: 11),
                      ),
                      child: _isTesting
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Test'),
                    ),
                  ),
                ],
              ),
              if (_testResult != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _testResult!,
                      style: TextStyle(fontSize: 12, color: AppTheme.textPrimary, fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
            ],
            if (widget.extraFields != null) ...[
              const SizedBox(height: 8),
              ...widget.extraFields!,
            ],
          ],
        ],
      ),
    );
  }
}

class _ApiConditionalField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final Language locale;

  const _ApiConditionalField({
    required this.label,
    required this.controller,
    required this.locale,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: TextField(
        controller: controller,
        style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(fontSize: 11, color: AppTheme.textTertiary),
          filled: true, fillColor: AppTheme.background,
          isDense: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.border)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        ),
      ),
    );
  }
}

class _StealthInputMethodSelector extends StatelessWidget {
  final StealthInputMethod selectedMethod;
  final Language locale;
  final ValueChanged<StealthInputMethod> onChanged;
  /// When provided, only these methods are rendered (others hidden).
  final List<StealthInputMethod>? allowedMethods;

  const _StealthInputMethodSelector({
    required this.selectedMethod,
    required this.locale,
    required this.onChanged,
    this.allowedMethods,
  });

  IconData _getIcon(StealthInputMethod method) {
    switch (method) {
      case StealthInputMethod.assistant:
        return Icons.people;
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
    // Assistant is a global mode now (see Home screen toggle), not a per-preset
    // input method. Exclude it from the default list.
    final methods = allowedMethods ??
        StealthInputMethod.values
            .where((m) => m != StealthInputMethod.assistant)
            .toList();
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: methods.map((method) {
          final isSelected = method == selectedMethod;
          final icon = _getIcon(method);

          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(method),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Icon(
                      icon,
                      color: isSelected ? Colors.white : AppTheme.textSecondary,
                      size: 20,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      method.displayName(locale),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.white : AppTheme.textSecondary,
                      ),
                      textAlign: TextAlign.center,
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

class _TapLayout2Selector extends StatelessWidget {
  final TapLayout2 selectedLayout;
  final Language locale;
  final ValueChanged<TapLayout2> onChanged;

  const _TapLayout2Selector({
    required this.selectedLayout,
    required this.locale,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: TapLayout2.values.map((layout) {
          final isSelected = layout == selectedLayout;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(layout),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      layout == TapLayout2.leftRight
                          ? Icons.swap_horiz
                          : Icons.swap_vert,
                      color: isSelected ? Colors.white : AppTheme.textSecondary,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      layout.displayName(locale),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.white : AppTheme.textSecondary,
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

class _TapLayout4Selector extends StatelessWidget {
  final TapLayout4 selectedLayout;
  final Language locale;
  final ValueChanged<TapLayout4> onChanged;

  const _TapLayout4Selector({
    required this.selectedLayout,
    required this.locale,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: TapLayout4.values.map((layout) {
          final isSelected = layout == selectedLayout;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(layout),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      layout == TapLayout4.corners
                          ? Icons.grid_view
                          : Icons.view_agenda,
                      color: isSelected ? Colors.white : AppTheme.textSecondary,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      layout.displayName(locale),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.white : AppTheme.textSecondary,
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

class _StealthInputHelpSheet extends StatelessWidget {
  final Language locale;
  final List<String> labels;

  const _StealthInputHelpSheet({required this.locale, required this.labels});

  @override
  Widget build(BuildContext context) {
    final title = locale == Language.french
        ? 'Méthode d\'Entrée Secrète'
        : 'Stealth Input Method';

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.textTertiary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
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
            ),
            const Divider(height: 1, color: AppTheme.divider),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    locale == Language.french
                        ? 'Permet d\'entrer les choix de façon invisible pendant la performance.'
                        : 'Allows entering choices invisibly during performance.',
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Standard (touch) option
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.background,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.touch_app, color: AppTheme.primary, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              locale == Language.french ? 'Standard (Tactile)' : 'Standard (Touch)',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          locale == Language.french
                              ? 'Utilise l\'interface tactile normale. L\'écran affiche les boutons de sélection.'
                              : 'Uses the normal touch interface. The screen displays selection buttons.',
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Volume buttons option
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.background,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.volume_up, color: AppTheme.primary, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              locale == Language.french ? 'Boutons Volume' : 'Volume Buttons',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          locale == Language.french
                              ? 'Écran entièrement noir. Entrez les choix avec les boutons de volume physiques.'
                              : 'Completely black screen. Enter choices using physical volume buttons.',
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Encoding table
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.background,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          locale == Language.french ? 'Encodage Volume' : 'Volume Encoding',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          [
                            '▲ x1 → ${labels.isNotEmpty ? labels[0] : 'Option 1'}',
                            '▼ x1 → ${labels.length > 1 ? labels[1] : 'Option 2'}',
                            '▲ x2 → ${labels.length > 2 ? labels[2] : 'Option 3'}',
                            '▼ x2 → ${labels.length > 3 ? labels[3] : 'Option 4'}',
                            '▲ x3 → ${labels.length > 4 ? labels[4] : 'Option 5'}',
                            '▼ x3 → ${labels.length > 5 ? labels[5] : 'Option 6'}',
                          ].join('\n'),
                          style: const TextStyle(
                            fontSize: 14,
                            fontFamily: 'monospace',
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          locale == Language.french
                              ? 'Attendez 550ms après le dernier appui pour confirmer.'
                              : 'Wait 550ms after last press to confirm.',
                          style: const TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color: AppTheme.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Undo/Reset
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.undo, color: AppTheme.primary, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              locale == Language.french ? 'Undo & Reset' : 'Undo & Reset',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          locale == Language.french
                              ? '• Undo : 3 appuis rapides (même direction)\n• Reset : 2 undos consécutifs'
                              : '• Undo : 3 rapid presses (same direction)\n• Reset : 2 consecutive undos',
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Hidden gestures
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.background,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          locale == Language.french ? 'Gestes Cachés' : 'Hidden Gestures',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          locale == Language.french
                              ? '• Long-press (2s) : Quitter\n• Double-tap : Voir le statut'
                              : '• Long-press (2s) : Exit\n• Double-tap : View status',
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FREE_WILL WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

/// Selector for FREE_WILL input mode (byAction / byObject)
class _FreeWillPreviewItem {
  final String fixed;
  final String variable;
  final bool isAuto;
  const _FreeWillPreviewItem({required this.fixed, required this.variable, this.isAuto = false});
}

class _FreeWillInputModeSelector extends StatelessWidget {
  final FreeWillInputMode selectedMode;
  final Language locale;
  final ValueChanged<FreeWillInputMode> onChanged;

  const _FreeWillInputModeSelector({
    required this.selectedMode,
    required this.locale,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _buildOption(
            mode: FreeWillInputMode.byAction,
            label: locale == Language.french ? 'L\'objet' : 'The object',
            subtitle: locale == Language.french
                ? 'Quel objet pour chaque action'
                : 'Which object for each action',
            icon: Icons.category,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildOption(
            mode: FreeWillInputMode.byObject,
            label: locale == Language.french ? 'L\'action' : 'The action',
            subtitle: locale == Language.french
                ? 'Quelle action pour chaque objet'
                : 'Which action for each object',
            icon: Icons.touch_app,
          ),
        ),
      ],
    );
  }

  Widget _buildOption({
    required FreeWillInputMode mode,
    required String label,
    required String subtitle,
    required IconData icon,
  }) {
    final isSelected = selectedMode == mode;
    return GestureDetector(
      onTap: () => onChanged(mode),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary.withValues(alpha: 0.2) : AppTheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppTheme.primary : AppTheme.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? AppTheme.primary : AppTheme.textPrimary,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 10,
                color: isSelected ? AppTheme.primary.withValues(alpha: 0.7) : AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Reorderable list of actions for FREE_WILL byAction mode
class _ReorderableActionList extends StatelessWidget {
  final List<FreeWillAction> actionOrder;
  final Language locale;
  final ValueChanged<List<FreeWillAction>> onReorder;

  const _ReorderableActionList({
    required this.actionOrder,
    required this.locale,
    required this.onReorder,
  });

  @override
  Widget build(BuildContext context) {
    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: actionOrder.length,
      onReorder: (oldIndex, newIndex) {
        final newList = List<FreeWillAction>.from(actionOrder);
        if (newIndex > oldIndex) newIndex--;
        final item = newList.removeAt(oldIndex);
        newList.insert(newIndex, item);
        onReorder(newList);
      },
      itemBuilder: (context, index) {
        final action = actionOrder[index];
        return Container(
          key: ValueKey(action),
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.border),
          ),
          child: ListTile(
            leading: const Icon(Icons.drag_handle, color: AppTheme.textSecondary),
            title: Text(
              action.shortNameEN,
              style: const TextStyle(color: AppTheme.textPrimary),
            ),
            subtitle: Text(
              '${index + 1}${locale == Language.french ? 'er' : 'st'} ${locale == Language.french ? 'input' : 'input'}',
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
            trailing: _getActionIcon(action),
          ),
        );
      },
    );
  }

  Widget _getActionIcon(FreeWillAction action) {
    IconData icon;
    Color color;
    switch (action) {
      case FreeWillAction.take:
        icon = Icons.person;
        color = Colors.green;
        break;
      case FreeWillAction.give:
        icon = Icons.card_giftcard;
        color = Colors.blue;
        break;
      case FreeWillAction.table:
        icon = Icons.table_restaurant;
        color = Colors.orange;
        break;
    }
    return Icon(icon, color: color, size: 24);
  }
}

/// Reorderable list of objects for FREE_WILL byObject mode
class _ReorderableObjectList extends StatelessWidget {
  final List<int> objectOrder;
  final List<String> objectNames;
  final ValueChanged<List<int>> onReorder;

  const _ReorderableObjectList({
    required this.objectOrder,
    required this.objectNames,
    required this.onReorder,
  });

  @override
  Widget build(BuildContext context) {
    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: objectOrder.length,
      onReorder: (oldIndex, newIndex) {
        final newList = List<int>.from(objectOrder);
        if (newIndex > oldIndex) newIndex--;
        final item = newList.removeAt(oldIndex);
        newList.insert(newIndex, item);
        onReorder(newList);
      },
      itemBuilder: (context, index) {
        final objIndex = objectOrder[index];
        final objName = objIndex < objectNames.length ? objectNames[objIndex] : 'Object ${objIndex + 1}';
        return Container(
          key: ValueKey('obj_$objIndex'),
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.border),
          ),
          child: ListTile(
            leading: const Icon(Icons.drag_handle, color: AppTheme.textSecondary),
            title: Text(
              objName,
              style: const TextStyle(color: AppTheme.textPrimary),
            ),
            trailing: CircleAvatar(
              radius: 14,
              backgroundColor: AppTheme.primary.withValues(alpha: 0.2),
              child: Text(
                '${index + 1}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// FREE_WILL Bank Section - 6 text fields for each permutation
class _FreeWillBankSection extends StatefulWidget {
  final Language locale;
  final List<String> objects;
  final Map<String, String>? customTemplates;
  final ValueChanged<Map<String, String>?> onChanged;
  final Map<String, String> bankImages;
  final Future<void> Function(String bankKey) onPickImage;
  final void Function(String bankKey) onRemoveImage;
  final String mode; // 'six' | 'single'
  final TextEditingController singleTemplateController;
  final ValueChanged<String> onModeChanged;
  final ValueChanged<String> onSingleTemplateChanged;

  const _FreeWillBankSection({
    required this.locale,
    required this.objects,
    required this.customTemplates,
    required this.onChanged,
    required this.bankImages,
    required this.onPickImage,
    required this.onRemoveImage,
    required this.mode,
    required this.singleTemplateController,
    required this.onModeChanged,
    required this.onSingleTemplateChanged,
  });

  @override
  State<_FreeWillBankSection> createState() => _FreeWillBankSectionState();
}

class _FreeWillBankSectionState extends State<_FreeWillBankSection> {
  late bool _isExpanded;
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, FocusNode> _focusNodes = {};
  String? _focusedKey;

  List<String> get _bucketKeys {
    return FreeWillBankGeneratorFR.generateAllBucketKeys(widget.objects);
  }

  bool get _hasAnyContent {
    final hasSingle = widget.singleTemplateController.text.trim().isNotEmpty;
    final hasSix = widget.customTemplates != null &&
        widget.customTemplates!.values.any((t) => t.trim().isNotEmpty);
    return hasSingle || hasSix;
  }

  @override
  void initState() {
    super.initState();
    // New / empty preset → start expanded so the toggle and editor are visible.
    // Already-configured preset → start collapsed to keep the form compact.
    _isExpanded = !_hasAnyContent;
    _initControllers();
  }

  void _initControllers() {
    for (final key in _bucketKeys) {
      _controllers[key] = TextEditingController(
        text: widget.customTemplates?[key] ?? '',
      );
      _focusNodes[key] = FocusNode()
        ..addListener(() {
          setState(() {
            _focusedKey = _focusNodes[key]!.hasFocus ? key : _focusedKey;
          });
        });
    }
  }

  @override
  void didUpdateWidget(covariant _FreeWillBankSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reinitialize if objects changed
    if (oldWidget.objects.join(',') != widget.objects.join(',')) {
      _disposeControllers();
      _initControllers();
    }
  }

  void _disposeControllers() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    for (final focusNode in _focusNodes.values) {
      focusNode.dispose();
    }
    _controllers.clear();
    _focusNodes.clear();
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  void _onTextChanged(String bucketKey, String text) {
    final newTemplates = Map<String, String>.from(widget.customTemplates ?? {});
    if (text.trim().isEmpty) {
      newTemplates.remove(bucketKey);
    } else {
      newTemplates[bucketKey] = text;
    }
    widget.onChanged(newTemplates.isEmpty ? null : newTemplates);
  }

  int get _configuredCount {
    if (widget.customTemplates == null) return 0;
    return widget.customTemplates!.values.where((t) => t.trim().isNotEmpty).length;
  }

  void _generateAllTexts() {
    final newTemplates = <String, String>{};

    for (final bucketKey in _bucketKeys) {
      // Parse bucket key to get object names for each action
      final parts = bucketKey.split('|');
      final takeObj = parts[0].replaceFirst('TAKE:', '');
      final giveObj = parts[1].replaceFirst('GIVE:', '');
      final tableObj = parts[2].replaceFirst('TABLE:', '');

      // Generate text with actual object names
      final text = widget.locale == Language.french
          ? 'Tu vas prendre $takeObj, me donner $giveObj et laisser $tableObj sur la table.'
          : 'You will take the $takeObj, give me the $giveObj and leave the $tableObj on the table.';

      _controllers[bucketKey]?.text = text;
      newTemplates[bucketKey] = text;
    }

    setState(() {});
    widget.onChanged(newTemplates);
  }

  void _openImportModal() {
    BankImportModal.show(
      context: context,
      bankType: BankType.freewheel,
      language: widget.locale,
      freewheelObjects: widget.objects,
      onImport: (entries, meta) {
        setState(() {
          for (final entry in entries.entries) {
            _controllers[entry.key]?.text = entry.value;
          }
        });
        widget.onChanged(entries);
      },
    );
  }

  void _copyAsJson() {
    if (widget.customTemplates == null || widget.customTemplates!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.locale == Language.french
              ? 'Aucun texte à copier'
              : 'No text to copy'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final json = {
      'mode': 'freewheel',
      'objects': widget.objects,
      'entries': widget.customTemplates,
    };

    Clipboard.setData(
        ClipboardData(text: const JsonEncoder.withIndent('  ').convert(json)));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(widget.locale == Language.french
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
          widget.locale == Language.french
              ? 'Effacer tous les textes ?'
              : 'Clear all texts?',
          style: const TextStyle(color: AppTheme.textPrimary),
        ),
        content: Text(
          widget.locale == Language.french
              ? 'Cette action effacera tous les textes de cette banque.'
              : 'This will clear all texts in this bank.',
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(widget.locale == Language.french ? 'Annuler' : 'Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                for (final controller in _controllers.values) {
                  controller.clear();
                }
              });
              widget.onChanged(null);
            },
            child: Text(
              widget.locale == Language.french ? 'Effacer' : 'Clear',
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isFR = widget.locale == Language.french;
    final isSingle = widget.mode == 'single';
    final headerLabel = isSingle
        ? (isFR ? '1 texte unique' : '1 single text')
        : (isFR ? '6 textes personnalisés' : '6 custom texts');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with expand/collapse
        GestureDetector(
          onTap: () => setState(() => _isExpanded = !_isExpanded),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.border),
            ),
            child: Row(
              children: [
                Icon(
                  _isExpanded ? Icons.expand_less : Icons.expand_more,
                  color: AppTheme.textSecondary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    headerLabel,
                    style: const TextStyle(color: AppTheme.textPrimary),
                  ),
                ),
                if (!isSingle && _configuredCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$_configuredCount/6',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),

        if (_isExpanded) ...[
          const SizedBox(height: 8),

          // Mode toggle: 6 texts vs 1 single text.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                Expanded(
                  child: _ModePill(
                    label: isFR ? '6 textes' : '6 texts',
                    sub: isFR ? '((Label1)) ((Label2)) ((Label3))' : '((Label1)) ((Label2)) ((Label3))',
                    selected: !isSingle,
                    onTap: () => widget.onModeChanged('six'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ModePill(
                    label: isFR ? '1 texte' : '1 text',
                    sub: '{TAKE} {GIVE} {TABLE}',
                    selected: isSingle,
                    onTap: () => widget.onModeChanged('single'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── SINGLE-TEMPLATE MODE ──
          if (isSingle) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                isFR
                    ? 'Un seul texte couvre toutes les permutations. Utilise {TAKE}, {GIVE}, {TABLE} pour référencer ce que le spectateur a fait.'
                    : 'One text covers every permutation. Use {TAKE}, {GIVE}, {TABLE} to reference the spectator\'s outcome.',
                style: const TextStyle(fontSize: 11, color: AppTheme.textTertiary, height: 1.3),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: widget.singleTemplateController,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: isFR
                    ? 'Tu vas garder {TAKE}, me donner {GIVE}, et laisser {TABLE} sur la table.'
                    : 'You will keep {TAKE}, give me {GIVE}, and leave {TABLE} on the table.',
                isDense: true,
              ),
              style: const TextStyle(color: AppTheme.textPrimary),
              maxLines: 6,
              minLines: 3,
              onChanged: widget.onSingleTemplateChanged,
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                for (final v in const ['{TAKE}', '{GIVE}', '{TABLE}'])
                  _MiniInsertChip(
                    label: v,
                    onTap: () {
                      final ctrl = widget.singleTemplateController;
                      final sel = ctrl.selection;
                      final pos = sel.isValid ? sel.baseOffset : ctrl.text.length;
                      final newText = ctrl.text.substring(0, pos) + v + ctrl.text.substring(pos);
                      ctrl.text = newText;
                      ctrl.selection = TextSelection.collapsed(offset: pos + v.length);
                      widget.onSingleTemplateChanged(newText);
                    },
                  ),
              ],
            ),
          ] else ...[
          // ── 6 TEXTS MODE ──
          // Action buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
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
                  label: widget.locale == Language.french ? 'Copier JSON' : 'Copy JSON',
                  onTap: _copyAsJson,
                ),
                _ActionButton(
                  icon: Icons.auto_fix_high,
                  label: widget.locale == Language.french ? 'Générer' : 'Generate',
                  onTap: _generateAllTexts,
                  color: AppTheme.accent,
                ),
                if (_configuredCount > 0)
                  _ActionButton(
                    icon: Icons.clear_all,
                    label: widget.locale == Language.french ? 'Effacer' : 'Clear',
                    onTap: _clearAll,
                    color: Colors.red,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // List of 6 text fields
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _bucketKeys.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final bucketKey = _bucketKeys[index];
              final parts = bucketKey.split('|');
              final takeObj = parts[0].replaceFirst('TAKE:', '');
              final giveObj = parts[1].replaceFirst('GIVE:', '');
              final tableObj = parts[2].replaceFirst('TABLE:', '');

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SPECTATOR: $takeObj | PERFORMER: $giveObj | TABLE: $tableObj',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _controllers[bucketKey],
                    focusNode: _focusNodes[bucketKey],
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: widget.locale == Language.french
                          ? 'Texte personnalisé...'
                          : 'Custom text...',
                      isDense: true,
                    ),
                    style: const TextStyle(color: AppTheme.textPrimary),
                    maxLines: 3,
                    minLines: 2,
                    onChanged: (text) => _onTextChanged(bucketKey, text),
                  ),
                  const SizedBox(height: 6),
                  // Variable chips — tap to insert at cursor.
                  // {TAKE}/{GIVE}/{TABLE} resolve to the action's object FOR THIS row.
                  // ((Label1))/((Label2))/((Label3)) resolve to the canonical object
                  // by position (same for every row), so the runtime label-override
                  // overlay can swap them per-show.
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      // 6-texts mode: only ((Label1/2/3)). The runtime override
                      // overlay swaps these per-show. {TAKE/GIVE/TABLE} are
                      // exclusive to single-text mode for clarity.
                      for (final v in const ['((Label1))', '((Label2))', '((Label3))'])
                        _MiniInsertChip(
                          label: v,
                          onTap: () {
                            final ctrl = _controllers[bucketKey]!;
                            final sel = ctrl.selection;
                            final pos = sel.isValid ? sel.baseOffset : ctrl.text.length;
                            final newText = ctrl.text.substring(0, pos) + v + ctrl.text.substring(pos);
                            ctrl.text = newText;
                            ctrl.selection = TextSelection.collapsed(offset: pos + v.length);
                            _onTextChanged(bucketKey, newText);
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _BankImageControl(
                    imagePath: widget.bankImages[bucketKey],
                    onPick: () => widget.onPickImage(bucketKey),
                    onRemove: () => widget.onRemoveImage(bucketKey),
                    locale: widget.locale,
                  ),
                ],
              );
            },
          ),
          ], // close `else ...[ ` for 6-texts mode
        ],
      ],
    );
  }
}

/// Pill-style toggle for the bank mode (6 texts vs single text).
class _ModePill extends StatelessWidget {
  final String label;
  final String sub;
  final bool selected;
  final VoidCallback onTap;
  const _ModePill({
    required this.label,
    required this.sub,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.primary.withValues(alpha: 0.18)
              : AppTheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? AppTheme.primary : AppTheme.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? AppTheme.primary : AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              sub,
              style: TextStyle(
                fontSize: 9,
                color: AppTheme.textTertiary,
                fontFamily: 'monospace',
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Help panel for Duel Volume input mode
class _DuelVolumeHelpPanel extends StatelessWidget {
  final Language locale;
  final List<String> labels;

  const _DuelVolumeHelpPanel({required this.locale, required this.labels});

  @override
  Widget build(BuildContext context) {
    final isFrench = locale == Language.french;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.volume_up, color: AppTheme.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                isFrench ? 'Mode Volume' : 'Volume Mode',
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildRow(isFrench ? 'Volume HAUT' : 'Volume UP', labels.isNotEmpty ? labels[0] : (isFrench ? '1ère option' : '1st option')),
          const SizedBox(height: 6),
          _buildRow(isFrench ? 'Volume BAS' : 'Volume DOWN', labels.length > 1 ? labels[1] : (isFrench ? '2ème option' : '2nd option')),
          const SizedBox(height: 6),
          _buildRow(isFrench ? 'HAUT ou BAS ×2' : 'UP or DOWN ×2', labels.length > 2 ? labels[2] : (isFrench ? '3ème option' : '3rd option')),
        ],
      ),
    );
  }

  Widget _buildRow(String gesture, String option) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            gesture,
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 8),
        const Icon(Icons.arrow_forward, size: 14, color: AppTheme.textSecondary),
        const SizedBox(width: 8),
        Text(
          option,
          style: const TextStyle(
            fontSize: 12,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }
}

/// Help panel for Duel Tap input mode
class _DuelTapHelpPanel extends StatelessWidget {
  final Language locale;
  final TapLayout2 tapLayout2;
  final InputMode inputMode;
  final List<String> labels;

  const _DuelTapHelpPanel({
    required this.locale,
    required this.tapLayout2,
    required this.inputMode,
    required this.labels,
  });

  @override
  Widget build(BuildContext context) {
    final isFrench = locale == Language.french;
    final isPreprogrammed = inputMode == InputMode.preprogrammed;
    // Both modes: 3 zones = the 3 options (labels)
    final zoneLabels = labels.length >= 3
        ? [labels[0], labels[1], labels[2]]
        : ['1', '2', '3'];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.fingerprint, color: AppTheme.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                isFrench ? 'Mode Tap' : 'Tap Mode',
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            isPreprogrammed
                ? (isFrench ? '1 input/round — choix du spectateur' : '1 input/round — spectator choice')
                : (isFrench ? '2 inputs/round — performer puis spectateur' : '2 inputs/round — performer then spectator'),
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 11,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 12),
          Center(child: _buildPhoneMockup(zoneLabels)),
        ],
      ),
    );
  }

  Widget _buildPhoneMockup(List<String> zoneLabels) {
    final colors = [AppTheme.primary, AppTheme.accent, Colors.teal];
    final isVertical = tapLayout2 == TapLayout2.topBottom;

    return Container(
      width: 140,
      height: 240,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.textSecondary.withValues(alpha: 0.3), width: 2),
      ),
      padding: const EdgeInsets.all(8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: isVertical
            ? Column(
                children: [
                  for (int i = 0; i < zoneLabels.length; i++) ...[
                    if (i > 0) Container(height: 2, color: AppTheme.textSecondary.withValues(alpha: 0.5)),
                    _buildZone(zoneLabels[i], colors[i % colors.length]),
                  ],
                ],
              )
            : Row(
                children: [
                  for (int i = 0; i < zoneLabels.length; i++) ...[
                    if (i > 0) Container(width: 2, color: AppTheme.textSecondary.withValues(alpha: 0.5)),
                    _buildZone(zoneLabels[i], colors[i % colors.length]),
                  ],
                ],
              ),
      ),
    );
  }

  Widget _buildZone(String label, Color color) {
    return Expanded(
      child: Container(
        color: color.withValues(alpha: 0.3),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Help panel for Choices Volume input mode
class _ChoicesVolumeHelpPanel extends StatelessWidget {
  final Language locale;
  final int nbOptions;
  final List<String> labels;

  const _ChoicesVolumeHelpPanel({
    required this.locale,
    required this.nbOptions,
    required this.labels,
  });

  @override
  Widget build(BuildContext context) {
    final isFrench = locale == Language.french;

    // Build rows based on nbOptions
    final rows = <Widget>[];

    String optLabel(int idx) => idx < labels.length && labels[idx].isNotEmpty ? labels[idx] : '${idx + 1}';

    // 1st option: UP
    rows.add(_buildRow(isFrench ? 'Volume HAUT' : 'Volume UP', optLabel(0)));

    // 2nd option: DOWN
    if (nbOptions >= 2) {
      rows.add(const SizedBox(height: 6));
      rows.add(_buildRow(isFrench ? 'Volume BAS' : 'Volume DOWN', optLabel(1)));
    }

    // 3rd option: UP×2 or DOWN×2 (for 3 options) or just UP×2 (for 4+)
    if (nbOptions >= 3) {
      rows.add(const SizedBox(height: 6));
      if (nbOptions == 3) {
        rows.add(_buildRow(isFrench ? 'HAUT ou BAS ×2' : 'UP or DOWN ×2', optLabel(2)));
      } else {
        rows.add(_buildRow(isFrench ? 'HAUT ×2' : 'UP ×2', optLabel(2)));
      }
    }

    // 4th option: DOWN×2
    if (nbOptions >= 4) {
      rows.add(const SizedBox(height: 6));
      rows.add(_buildRow(isFrench ? 'BAS ×2' : 'DOWN ×2', optLabel(3)));
    }

    // 5th option: UP×3 or DOWN×3 (for 5 options) or just UP×3 (for 6)
    if (nbOptions >= 5) {
      rows.add(const SizedBox(height: 6));
      if (nbOptions == 5) {
        rows.add(_buildRow(isFrench ? 'HAUT ou BAS ×3' : 'UP or DOWN ×3', optLabel(4)));
      } else {
        rows.add(_buildRow(isFrench ? 'HAUT ×3' : 'UP ×3', optLabel(4)));
      }
    }

    // 6th option: DOWN×3
    if (nbOptions >= 6) {
      rows.add(const SizedBox(height: 6));
      rows.add(_buildRow(isFrench ? 'BAS ×3' : 'DOWN ×3', optLabel(5)));
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.volume_up, color: AppTheme.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                isFrench ? 'Mode Volume' : 'Volume Mode',
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...rows,
        ],
      ),
    );
  }

  Widget _buildRow(String gesture, String label) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            gesture,
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 8),
        const Icon(Icons.arrow_forward, size: 14, color: AppTheme.textSecondary),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// Help panel for Choices Tap input mode
class _ChoicesTapHelpPanel extends StatelessWidget {
  final Language locale;
  final int nbOptions;
  final TapLayout2 tapLayout2;
  final TapLayout4 tapLayout4;
  final List<String> labels;

  const _ChoicesTapHelpPanel({
    required this.locale,
    required this.nbOptions,
    required this.tapLayout2,
    required this.tapLayout4,
    required this.labels,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.fingerprint, color: AppTheme.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                locale == Language.french ? 'Mode Tap' : 'Tap Mode',
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Center(child: _buildPhoneMockup()),
        ],
      ),
    );
  }

  /// Visual phone screen mockup showing zone layout
  Widget _buildPhoneMockup() {
    return Container(
      width: 140,
      height: 240,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.textSecondary.withValues(alpha: 0.3), width: 2),
      ),
      padding: const EdgeInsets.all(8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: _buildZoneLayout(),
      ),
    );
  }

  Widget _buildZoneLayout() {
    if (nbOptions == 2) {
      if (tapLayout2 == TapLayout2.topBottom) {
        return Column(
          children: [
            _buildZone('1', flex: 1),
            _zoneDivider(horizontal: true),
            _buildZone('2', flex: 1),
          ],
        );
      } else {
        return Row(
          children: [
            _buildZone('1', flex: 1),
            _zoneDivider(horizontal: false),
            _buildZone('2', flex: 1),
          ],
        );
      }
    } else if (nbOptions == 3) {
      return Column(
        children: [
          _buildZone('1', flex: 1),
          _zoneDivider(horizontal: true),
          _buildZone('2', flex: 1),
          _zoneDivider(horizontal: true),
          _buildZone('3', flex: 1),
        ],
      );
    } else if (nbOptions == 4) {
      if (tapLayout4 == TapLayout4.corners) {
        return Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  _buildZone('1', flex: 1),
                  _zoneDivider(horizontal: false),
                  _buildZone('2', flex: 1),
                ],
              ),
            ),
            _zoneDivider(horizontal: true),
            Expanded(
              child: Row(
                children: [
                  _buildZone('3', flex: 1),
                  _zoneDivider(horizontal: false),
                  _buildZone('4', flex: 1),
                ],
              ),
            ),
          ],
        );
      } else {
        return Column(
          children: [
            _buildZone('1', flex: 1),
            _zoneDivider(horizontal: true),
            _buildZone('2', flex: 1),
            _zoneDivider(horizontal: true),
            _buildZone('3', flex: 1),
            _zoneDivider(horizontal: true),
            _buildZone('4', flex: 1),
          ],
        );
      }
    } else {
      // 5-6: 2x3 grid
      final rows = <Widget>[];
      int idx = 1;
      for (int r = 0; r < 3; r++) {
        if (r > 0) rows.add(_zoneDivider(horizontal: true));
        final cols = <Widget>[];
        for (int c = 0; c < 2; c++) {
          if (c > 0) cols.add(_zoneDivider(horizontal: false));
          if (idx <= nbOptions) {
            cols.add(_buildZone('$idx', flex: 1));
            idx++;
          } else {
            cols.add(Expanded(child: Container(color: Colors.black)));
          }
        }
        rows.add(Expanded(child: Row(children: cols)));
      }
      return Column(children: rows);
    }
  }

  String _zoneLabel(int index) {
    return index < labels.length && labels[index].isNotEmpty ? labels[index] : '${index + 1}';
  }

  Widget _buildZone(String label, {required int flex}) {
    final colors = [
      AppTheme.primary,
      AppTheme.accent,
      Colors.teal,
      Colors.deepOrange,
      Colors.pink,
      Colors.indigo,
    ];
    final index = int.parse(label) - 1;
    final color = colors[index % colors.length];
    final displayLabel = _zoneLabel(index);

    return Expanded(
      flex: flex,
      child: Container(
        color: color.withValues(alpha: 0.3),
        child: Center(
          child: Text(
            displayLabel,
            style: TextStyle(
              color: color,
              fontSize: displayLabel.length > 4 ? 11 : 18,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
        ),
      ),
    );
  }

  Widget _zoneDivider({required bool horizontal}) {
    return horizontal
        ? Container(height: 2, color: AppTheme.textSecondary.withValues(alpha: 0.5))
        : Container(width: 2, color: AppTheme.textSecondary.withValues(alpha: 0.5));
  }
}

/// Help panel for Free Will Volume input mode
class _FreeWillVolumeHelpPanel extends StatelessWidget {
  final FreeWillInputMode inputMode;
  final List<FreeWillAction> actionOrder;
  final List<int> objectOrder;
  final List<String> objectNames;
  final Language locale;

  const _FreeWillVolumeHelpPanel({
    required this.inputMode,
    required this.actionOrder,
    required this.objectOrder,
    required this.objectNames,
    required this.locale,
  });

  bool get _fr => locale == Language.french;

  @override
  Widget build(BuildContext context) {
    final List<String> slotLabels = _buildSlotLabels();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Row(
            children: [
              const Icon(Icons.volume_up, color: AppTheme.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                _fr ? 'Comment utiliser le mode Volume' : 'How to use Volume mode',
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Block 0: Current mapping (dynamic)
          _buildSection(
            title: _fr ? 'Correspondance actuelle' : 'Current mapping',
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildMappingRow('1', slotLabels[0]),
                _buildMappingRow('2', slotLabels[1]),
                _buildMappingRow('3', slotLabels[2]),
              ],
            ),
            highlight: true,
          ),
          const SizedBox(height: 12),

          // Block 1: Phase 1 - Choice
          _buildSection(
            title: _fr ? 'Phase 1 : Choix (2 inputs)' : 'Phase 1: Choice (2 inputs)',
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInputRow(_fr ? 'Volume Haut' : 'Volume Up', slotLabels[0]),
                _buildInputRow(_fr ? 'Volume Bas' : 'Volume Down', slotLabels[1]),
                _buildInputRow(_fr ? 'Double Volume' : 'Double Volume', slotLabels[2]),
                const SizedBox(height: 6),
                Text(
                  _fr
                      ? 'Tu fais 2 inputs. Le 3e est déduit automatiquement.'
                      : '2 inputs. The 3rd is deduced automatically.',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Block 2: Phase 2 - Swaps (semantic labels)
          _buildSection(
            title: _fr ? 'Phase 2 : Swaps (après déduction)' : 'Phase 2: Swaps (after deduction)',
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInputRow(
                  _fr ? '1 (Haut)' : '1 (Up)',
                  _fr
                      ? 'garde ${slotLabels[0]}, swap ${slotLabels[1]} ↔ ${slotLabels[2]}'
                      : 'keep ${slotLabels[0]}, swap ${slotLabels[1]} ↔ ${slotLabels[2]}',
                ),
                _buildInputRow(
                  _fr ? '2 (Bas)' : '2 (Down)',
                  _fr
                      ? 'garde ${slotLabels[1]}, swap ${slotLabels[0]} ↔ ${slotLabels[2]}'
                      : 'keep ${slotLabels[1]}, swap ${slotLabels[0]} ↔ ${slotLabels[2]}',
                ),
                _buildInputRow(
                  _fr ? '3 (Double)' : '3 (Double)',
                  _fr
                      ? 'garde ${slotLabels[2]}, swap ${slotLabels[0]} ↔ ${slotLabels[1]}'
                      : 'keep ${slotLabels[2]}, swap ${slotLabels[0]} ↔ ${slotLabels[1]}',
                ),
                const SizedBox(height: 6),
                Text(
                  _fr
                      ? 'Tu peux swap autant de fois que tu veux. Haptique à chaque swap.'
                      : 'Unlimited swaps. Haptic feedback on each swap.',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Block 3: End
          _buildSection(
            title: _fr ? 'Fin' : 'End',
            content: Row(
              children: [
                const Icon(Icons.touch_app, size: 16, color: AppTheme.accent),
                const SizedBox(width: 8),
                Text(
                  _fr
                      ? 'Tap sur l\'écran = lock (arrête les swaps)'
                      : 'Tap screen = lock (stops swaps)',
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<String> _buildSlotLabels() {
    if (inputMode == FreeWillInputMode.byAction) {
      // byAction: performer inputs OBJECTS
      return objectNames;
    } else {
      // byObject: performer inputs ACTIONS
      return actionOrder.map((action) =>
          _fr ? action.shortNameFR : action.shortNameEN).toList();
    }
  }

  Widget _buildSection({
    required String title,
    required Widget content,
    bool highlight = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: highlight
            ? AppTheme.primary.withValues(alpha: 0.1)
            : Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: highlight
            ? Border.all(color: AppTheme.primary.withValues(alpha: 0.3))
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: highlight ? AppTheme.primary : AppTheme.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          content,
        ],
      ),
    );
  }

  Widget _buildMappingRow(String slot, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              slot,
              style: const TextStyle(
                color: AppTheme.primary,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            '=',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputRow(String input, String result) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              input,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 11,
              ),
            ),
          ),
          const Text(
            '=',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              result,
              softWrap: true,
              style: const TextStyle(
                color: AppTheme.accent,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Selector for Tap orientation (horizontal/vertical) for Free Will
class _TapOrientationSelector extends StatelessWidget {
  final TapOrientation selectedOrientation;
  final Language locale;
  final Function(TapOrientation) onChanged;

  const _TapOrientationSelector({
    required this.selectedOrientation,
    required this.locale,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: TapOrientation.values.map((orientation) {
        final isSelected = orientation == selectedOrientation;
        return Expanded(
          child: GestureDetector(
            onTap: () => onChanged(orientation),
            child: Container(
              margin: EdgeInsets.only(
                right: orientation != TapOrientation.values.last ? 8 : 0,
              ),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.primary.withValues(alpha: 0.2)
                    : AppTheme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected
                      ? AppTheme.primary
                      : AppTheme.surface,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    orientation == TapOrientation.horizontal
                        ? Icons.dehaze
                        : Icons.view_column,
                    size: 24,
                    color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    orientation.displayName(locale),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// Help panel for Free Will Tap input mode
class _FreeWillTapHelpPanel extends StatelessWidget {
  final FreeWillInputMode inputMode;
  final List<FreeWillAction> actionOrder;
  final List<int> objectOrder;
  final List<String> objectNames;
  final TapOrientation tapOrientation;
  final Language locale;

  const _FreeWillTapHelpPanel({
    required this.inputMode,
    required this.actionOrder,
    required this.objectOrder,
    required this.objectNames,
    required this.tapOrientation,
    required this.locale,
  });

  bool get _fr => locale == Language.french;

  @override
  Widget build(BuildContext context) {
    final List<String> slotLabels = _buildSlotLabels();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Row(
            children: [
              const Icon(Icons.touch_app, color: AppTheme.accent, size: 20),
              const SizedBox(width: 8),
              Text(
                _fr ? 'Comment utiliser le mode Tap' : 'How to use Tap mode',
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Block 0: Current mapping (dynamic)
          _buildSection(
            title: _fr ? 'Correspondance actuelle' : 'Current mapping',
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildMappingRow('1', slotLabels[0]),
                _buildMappingRow('2', slotLabels[1]),
                _buildMappingRow('3', slotLabels[2]),
              ],
            ),
            highlight: true,
          ),
          const SizedBox(height: 12),

          // Block 1: Zone layout (visual)
          _buildSection(
            title: _fr ? 'Zones de tap' : 'Tap zones',
            content: Center(child: _buildPhoneMockup(slotLabels)),
          ),
          const SizedBox(height: 12),

          // Block 2: Phase 1 - Choice
          _buildSection(
            title: _fr ? 'Phase 1 : Choix (2 taps)' : 'Phase 1: Choice (2 taps)',
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _fr
                      ? 'Tu fais 2 taps sur les zones. Le 3e est déduit automatiquement.'
                      : '2 taps on zones. The 3rd is deduced automatically.',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Block 3: Phase 2 - Swaps (semantic labels)
          _buildSection(
            title: _fr ? 'Phase 2 : Swaps (après déduction)' : 'Phase 2: Swaps (after deduction)',
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInputRow(
                  'Tap zone 1',
                  _fr
                      ? 'garde ${slotLabels[0]}, swap ${slotLabels[1]} ↔ ${slotLabels[2]}'
                      : 'keep ${slotLabels[0]}, swap ${slotLabels[1]} ↔ ${slotLabels[2]}',
                ),
                _buildInputRow(
                  'Tap zone 2',
                  _fr
                      ? 'garde ${slotLabels[1]}, swap ${slotLabels[0]} ↔ ${slotLabels[2]}'
                      : 'keep ${slotLabels[1]}, swap ${slotLabels[0]} ↔ ${slotLabels[2]}',
                ),
                _buildInputRow(
                  'Tap zone 3',
                  _fr
                      ? 'garde ${slotLabels[2]}, swap ${slotLabels[0]} ↔ ${slotLabels[1]}'
                      : 'keep ${slotLabels[2]}, swap ${slotLabels[0]} ↔ ${slotLabels[1]}',
                ),
                const SizedBox(height: 6),
                Text(
                  _fr
                      ? 'Tu peux swap autant de fois que tu veux. Haptique à chaque swap.'
                      : 'Unlimited swaps. Haptic feedback on each swap.',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Block 4: End
          _buildSection(
            title: _fr ? 'Fin' : 'End',
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.volume_up, size: 16, color: AppTheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _fr
                            ? 'Bouton Volume (haut ou bas) = lock (arrête les swaps)'
                            : 'Volume button (up or down) = lock (stops swaps)',
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.touch_app, size: 16, color: AppTheme.accent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _fr
                            ? 'Tap suivant = révèle (affiche le résultat)'
                            : 'Next tap = reveal (shows result)',
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhoneMockup(List<String> slotLabels) {
    final colors = [AppTheme.primary, AppTheme.accent, Colors.teal];
    return Container(
      width: 140,
      height: 240,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.textSecondary.withValues(alpha: 0.3), width: 2),
      ),
      padding: const EdgeInsets.all(8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: tapOrientation == TapOrientation.horizontal
            ? Column(
                children: [
                  for (int i = 0; i < 3; i++) ...[
                    if (i > 0) Container(height: 2, color: AppTheme.textSecondary.withValues(alpha: 0.5)),
                    Expanded(
                      child: Container(
                        color: colors[i].withValues(alpha: 0.25),
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Text(
                              slotLabels[i],
                              textAlign: TextAlign.center,
                              style: TextStyle(color: colors[i], fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              )
            : Row(
                children: [
                  for (int i = 0; i < 3; i++) ...[
                    if (i > 0) Container(width: 2, color: AppTheme.textSecondary.withValues(alpha: 0.5)),
                    Expanded(
                      child: Container(
                        color: colors[i].withValues(alpha: 0.25),
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(2),
                            child: Text(
                              slotLabels[i],
                              textAlign: TextAlign.center,
                              style: TextStyle(color: colors[i], fontSize: 9, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }

  List<String> _buildSlotLabels() {
    if (inputMode == FreeWillInputMode.byAction) {
      // byAction: performer inputs OBJECTS
      return objectNames;
    } else {
      // byObject: performer inputs ACTIONS
      return actionOrder.map((action) =>
          _fr ? action.shortNameFR : action.shortNameEN).toList();
    }
  }

  Widget _buildSection({
    required String title,
    required Widget content,
    bool highlight = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: highlight
            ? AppTheme.accent.withValues(alpha: 0.1)
            : Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: highlight
            ? Border.all(color: AppTheme.accent.withValues(alpha: 0.3))
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: highlight ? AppTheme.accent : AppTheme.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          content,
        ],
      ),
    );
  }

  Widget _buildMappingRow(String slot, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppTheme.accent.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              slot,
              style: const TextStyle(
                color: AppTheme.accent,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            '=',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputRow(String input, String result) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              input,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 11,
              ),
            ),
          ),
          const Text(
            '=',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              result,
              softWrap: true,
              style: const TextStyle(
                color: AppTheme.accent,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}


/// Sequence-based bank editor for Duel Fixed Rounds (preprogrammed, up to 5 rounds).
/// Same style as PreprogrammedBankEditor / DuelScoreBankSection.
class _DuelSequenceBankSection extends StatefulWidget {
  final Language locale;
  final int nbRounds;
  final List<String> labels;
  final List<int> performerSequence;
  final Map<String, String>? customTemplates;
  final ValueChanged<Map<String, String>?> onChanged;

  const _DuelSequenceBankSection({
    required this.locale,
    required this.nbRounds,
    required this.labels,
    required this.performerSequence,
    required this.customTemplates,
    required this.onChanged,
  });

  @override
  State<_DuelSequenceBankSection> createState() => _DuelSequenceBankSectionState();
}

class _DuelSequenceBankSectionState extends State<_DuelSequenceBankSection> {
  bool _isExpanded = true;
  late Map<String, TextEditingController> _controllers;
  late Map<String, String> _templates;

  @override
  void initState() {
    super.initState();
    _templates = Map.from(widget.customTemplates ?? {});
    _controllers = {};
    _initControllers();
    // Collapse if all sequence texts are filled
    final allSeqs = _generateAllSequences(widget.nbRounds, widget.labels.length);
    final allSeqFilled = allSeqs.isNotEmpty &&
        allSeqs.every((s) => _templates[_seqKey(s)]?.trim().isNotEmpty == true);
    _isExpanded = !allSeqFilled;
  }

  List<List<int>> _generateAllSequences(int rounds, int optionCount) {
    if (rounds == 0) return [[]];
    final sub = _generateAllSequences(rounds - 1, optionCount);
    final result = <List<int>>[];
    for (int opt = 0; opt < optionCount; opt++) {
      for (final s in sub) {
        result.add([opt, ...s]);
      }
    }
    return result;
  }

  String _seqKey(List<int> spectatorSeq) => 'SEQ_${spectatorSeq.join('_')}';

  int _roundResult(int performerIdx, int spectatorIdx, int optionCount) {
    if (performerIdx == spectatorIdx) return 0;
    if (optionCount == 2) return performerIdx == 0 ? 1 : -1;
    final winsAgainst = <int, int>{};
    for (int i = 0; i < optionCount; i++) {
      winsAgainst[i] = (i + 2) % optionCount;
    }
    return winsAgainst[performerIdx] == spectatorIdx ? 1 : -1;
  }

  Map<String, int> _computeScore(List<int> spectatorSeq) {
    int s = 0, p = 0, t = 0;
    final perfSeq = widget.performerSequence;
    final optCount = widget.labels.length;
    for (int i = 0; i < spectatorSeq.length && i < perfSeq.length; i++) {
      final result = _roundResult(perfSeq[i], spectatorSeq[i], optCount);
      if (result > 0) p++;
      else if (result < 0) s++;
      else t++;
    }
    return {'s': s, 'p': p, 't': t};
  }

  void _initControllers() {
    for (final c in _controllers.values) c.dispose();
    _controllers.clear();
    for (final seq in _generateAllSequences(widget.nbRounds, widget.labels.length)) {
      final key = _seqKey(seq);
      _controllers[key] = TextEditingController(text: _templates[key] ?? '');
    }
  }

  @override
  void didUpdateWidget(_DuelSequenceBankSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.nbRounds != widget.nbRounds ||
        oldWidget.labels.length != widget.labels.length ||
        oldWidget.performerSequence != widget.performerSequence) {
      _templates = Map.from(widget.customTemplates ?? {});
      _initControllers();
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) c.dispose();
    super.dispose();
  }

  void _onTextChanged(String key, String text) {
    if (text.trim().isEmpty) {
      _templates.remove(key);
    } else {
      _templates[key] = text;
    }
    widget.onChanged(_templates.isEmpty ? null : Map.from(_templates));
  }

  int get _configuredCount =>
      _templates.entries.where((e) => e.key.startsWith('SEQ_') && e.value.trim().isNotEmpty).length;

  void _copyAsJson() {
    final seqEntries = Map.fromEntries(
        _templates.entries.where((e) => e.key.startsWith('SEQ_') && e.value.trim().isNotEmpty));
    final isFR = widget.locale == Language.french;
    if (seqEntries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isFR ? 'Aucun texte à copier' : 'No text to copy'), backgroundColor: Colors.orange),
      );
      return;
    }
    final json = {'rounds': widget.nbRounds, 'sequences': seqEntries};
    Clipboard.setData(ClipboardData(text: const JsonEncoder.withIndent('  ').convert(json)));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(isFR ? 'JSON copié' : 'JSON copied'), backgroundColor: Colors.green, duration: const Duration(seconds: 2)),
    );
  }

  void _openDuelSequenceImportModal() {
    // Build performer key display
    final perfDisplay = widget.performerSequence
        .map((i) => i < widget.labels.length ? widget.labels[i] : '?')
        .join('');
    BankImportModal.show(
      context: context,
      bankType: BankType.duelSequences,
      language: widget.locale,
      rounds: widget.nbRounds,
      options: widget.labels,
      performerKey: perfDisplay,
      performerSequenceIndices: widget.performerSequence,
      onImport: (entries, meta) {
        setState(() {
          for (final entry in entries.entries) {
            _templates[entry.key] = entry.value;
            _controllers[entry.key]?.text = entry.value;
          }
        });
        widget.onChanged(Map.from(_templates));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isFR ? 'Textes séquences importés' : 'Sequence texts imported'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      },
    );
  }

  void _clearAll() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text(widget.locale == Language.french ? 'Effacer tous les textes ?' : 'Clear all texts?',
            style: const TextStyle(color: AppTheme.textPrimary)),
        content: Text(widget.locale == Language.french
            ? 'Cette action effacera tous les textes de cette banque.'
            : 'This will clear all texts in this bank.',
            style: const TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx),
              child: Text(widget.locale == Language.french ? 'Annuler' : 'Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _templates.removeWhere((k, _) => k.startsWith('SEQ_'));
                for (final c in _controllers.values) c.clear();
              });
              widget.onChanged(_templates.isEmpty ? null : Map.from(_templates));
            },
            child: Text(widget.locale == Language.french ? 'Effacer' : 'Clear',
                style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Color _roundColor(int result) {
    if (result < 0) return Colors.blue;
    if (result > 0) return Colors.orange;
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    final allSequences = _generateAllSequences(widget.nbRounds, widget.labels.length);
    final hasCustom = _configuredCount > 0;
    final isFR = widget.locale == Language.french;

    // Group by score
    final grouped = <String, List<List<int>>>{};
    for (final seq in allSequences) {
      final score = _computeScore(seq);
      final label = '${score['s']}-${score['p']}${score['t']! > 0 ? ' (${score['t']}${isFR ? ' éga' : ' tie'}.)' : ''}';
      grouped.putIfAbsent(label, () => []).add(seq);
    }

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: hasCustom ? Colors.green.withValues(alpha: 0.5) : AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(_isExpanded ? Icons.expand_less : Icons.expand_more, color: AppTheme.textSecondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(isFR ? 'Banque Séquences' : 'Sequence Bank',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                        const SizedBox(height: 2),
                        Text('${allSequences.length} séquences',
                            style: const TextStyle(fontSize: 13, color: AppTheme.accent)),
                      ],
                    ),
                  ),
                  if (hasCustom)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
                      child: Text('$_configuredCount / ${allSequences.length}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.green)),
                    ),
                ],
              ),
            ),
          ),

          if (_isExpanded) ...[
            const Divider(height: 1, color: AppTheme.border),

            // Performer sequence reminder
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: AppTheme.background.withValues(alpha: 0.5),
              child: Row(
                children: [
                  Text('Performer : ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.orange.shade300)),
                  for (int i = 0; i < widget.performerSequence.length && i < widget.nbRounds; i++) ...[
                    if (i > 0) const Text(' → ', style: TextStyle(fontSize: 10, color: AppTheme.textTertiary)),
                    Text(
                      widget.performerSequence[i] < widget.labels.length
                          ? widget.labels[widget.performerSequence[i]]
                          : '?',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.orange.shade300),
                    ),
                  ],
                ],
              ),
            ),

            // Action buttons
            Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _ActionButton(
                    icon: Icons.auto_fix_high,
                    label: 'IA Import',
                    onTap: _openDuelSequenceImportModal,
                    color: Colors.teal,
                  ),
                  _ActionButton(
                    icon: Icons.copy,
                    label: isFR ? 'Copier JSON' : 'Copy JSON',
                    onTap: _copyAsJson,
                  ),
                  if (hasCustom)
                    _ActionButton(
                      icon: Icons.clear_all,
                      label: isFR ? 'Effacer' : 'Clear',
                      onTap: _clearAll,
                      color: Colors.red,
                    ),
                ],
              ),
            ),

            const Divider(height: 1, color: AppTheme.border),

            // Sequences grouped by score
            for (final entry in grouped.entries) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: AppTheme.background.withValues(alpha: 0.5),
                child: Text('Score ${entry.key}  (${entry.value.length})',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
              ),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: entry.value.length,
                separatorBuilder: (_, __) => const Divider(height: 1, color: AppTheme.border),
                itemBuilder: (context, index) => _buildSequenceEditor(entry.value[index]),
              ),
              const Divider(height: 1, color: AppTheme.border),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildSequenceEditor(List<int> spectatorSeq) {
    final key = _seqKey(spectatorSeq);
    final controller = _controllers[key];
    final hasText = _templates[key]?.trim().isNotEmpty ?? false;
    final perfSeq = widget.performerSequence;
    final optCount = widget.labels.length;
    final score = _computeScore(spectatorSeq);

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Spectator sequence + score + hit/miss indicators
          Row(
            children: [
              Text('S: ', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.blue.shade300)),
              for (int i = 0; i < spectatorSeq.length && i < perfSeq.length; i++) ...[
                if (i > 0) const Text(' → ', style: TextStyle(fontSize: 9, color: AppTheme.textTertiary)),
                Builder(builder: (_) {
                  final result = _roundResult(perfSeq[i], spectatorSeq[i], optCount);
                  // spectator wins = green check, performer wins = red cross, tie = grey dash
                  final icon = result < 0 ? Icons.check_circle : result > 0 ? Icons.cancel : Icons.remove_circle_outline;
                  final color = result < 0 ? Colors.green : result > 0 ? Colors.red : Colors.grey;
                  final label = spectatorSeq[i] < widget.labels.length ? widget.labels[spectatorSeq[i]] : '?';
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
                      const SizedBox(width: 2),
                      Icon(icon, size: 12, color: color),
                    ],
                  );
                }),
              ],
              const Spacer(),
              // Score badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${score['s']}-${score['p']}${score['t']! > 0 ? ' (${score['t']}T)' : ''}',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.accent),
                ),
              ),
              const SizedBox(width: 4),
              if (hasText) const Icon(Icons.check_circle, size: 16, color: Colors.green),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            textCapitalization: TextCapitalization.sentences,
            maxLines: 6,
            minLines: 2,
            style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary),
            decoration: InputDecoration(
              hintText: isFR ? 'Template vide = utilise le défaut' : 'Empty = use default',
              hintStyle: const TextStyle(fontSize: 11, color: AppTheme.textTertiary, fontStyle: FontStyle.italic),
              filled: true,
              fillColor: AppTheme.background,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: hasText ? Colors.green.withValues(alpha: 0.5) : AppTheme.border)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppTheme.primary, width: 2)),
              contentPadding: const EdgeInsets.all(10),
            ),
            onChanged: (text) => _onTextChanged(key, text),
          ),
          // Performer sequence reminder below text
          const SizedBox(height: 6),
          Row(
            children: [
              Text('P: ', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.orange.shade300)),
              for (int i = 0; i < perfSeq.length && i < widget.nbRounds; i++) ...[
                if (i > 0) const Text(' → ', style: TextStyle(fontSize: 9, color: AppTheme.textTertiary)),
                Text(
                  perfSeq[i] < widget.labels.length ? widget.labels[perfSeq[i]] : '?',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.orange.shade300),
                ),
              ],
            ],
          ),
          // Preview
          if (hasText && TemplatePreview.hasVariables(controller?.text ?? '')) ...[
            const SizedBox(height: 8),
            _buildPreview(controller!.text, spectatorSeq),
          ],
        ],
      ),
    );
  }

  Widget _buildPreview(String template, List<int> spectatorSeq) {
    final vars = TemplatePreview.buildDuelSequenceVars(
      spectatorSeq: spectatorSeq,
      performerSeq: widget.performerSequence,
      labels: widget.labels,
      templates: _templates,
      roundResult: _roundResult,
    );
    final rendered = TemplatePreview.render(template, vars);
    final unresolved = TemplatePreview.findUnresolved(rendered, {});

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: unresolved.isEmpty ? AppTheme.primary.withValues(alpha: 0.2) : Colors.orange.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.visibility, size: 12, color: AppTheme.primary.withValues(alpha: 0.6)),
              const SizedBox(width: 4),
              Text('Aperçu', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.primary.withValues(alpha: 0.6))),
              if (unresolved.isNotEmpty) ...[
                const SizedBox(width: 8),
                Icon(Icons.warning_amber, size: 12, color: Colors.orange),
                const SizedBox(width: 2),
                Text('Variables manquantes', style: TextStyle(fontSize: 9, color: Colors.orange)),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(rendered, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary, fontStyle: FontStyle.italic, height: 1.4)),
        ],
      ),
    );
  }

  bool get isFR => widget.locale == Language.french;
}

// _OutputOverrideSection has been extracted to lib/ui/widgets/output_override_section.dart
// (now the public OutputOverrideSection) so the Confabulation editor can reuse it.

/// Phone mockup showing the tap zone layout for a Multiple Out preset.
/// Picks a sensible layout based on the number of texts (2..6).
class _MultipleOutTapHelpPanel extends StatelessWidget {
  final Language locale;
  final List<String> zoneLabels;

  const _MultipleOutTapHelpPanel({
    required this.locale,
    required this.zoneLabels,
  });

  @override
  Widget build(BuildContext context) {
    final isFrench = locale == Language.french;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.fingerprint, color: AppTheme.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                isFrench ? 'Mode Tap' : 'Tap Mode',
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            isFrench
                ? 'Tape la zone correspondant au texte à révéler. Écran noir, rien de visible par le spectateur.'
                : 'Tap the zone matching the text you want to reveal. Black screen, invisible to the spectator.',
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 12),
          Center(child: _buildMockup()),
        ],
      ),
    );
  }

  Widget _buildMockup() {
    return Container(
      width: 160,
      height: 280,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.textSecondary.withValues(alpha: 0.3), width: 2),
      ),
      padding: const EdgeInsets.all(8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: _buildZones(),
      ),
    );
  }

  Widget _buildZones() {
    final n = zoneLabels.length;
    final colors = [
      AppTheme.primary, AppTheme.accent, Colors.teal,
      Colors.deepOrange, Colors.purple, Colors.lightBlue,
    ];

    Widget zone(int i) => _Zone(label: zoneLabels[i], color: colors[i % colors.length]);
    Widget hSep() => Container(height: 1.5, color: AppTheme.textSecondary.withValues(alpha: 0.4));
    Widget vSep() => Container(width: 1.5, color: AppTheme.textSecondary.withValues(alpha: 0.4));

    if (n == 2) {
      // top / bottom
      return Column(children: [
        Expanded(child: zone(0)), hSep(), Expanded(child: zone(1)),
      ]);
    }
    if (n == 3) {
      return Column(children: [
        Expanded(child: zone(0)), hSep(), Expanded(child: zone(1)), hSep(), Expanded(child: zone(2)),
      ]);
    }
    if (n == 4) {
      return Column(children: [
        Expanded(child: Row(children: [Expanded(child: zone(0)), vSep(), Expanded(child: zone(1))])),
        hSep(),
        Expanded(child: Row(children: [Expanded(child: zone(2)), vSep(), Expanded(child: zone(3))])),
      ]);
    }
    // 5 zones: 2x3 with 1 disabled (position 5 = bottom-right disabled)
    if (n == 5) {
      return Column(children: [
        Expanded(child: Row(children: [Expanded(child: zone(0)), vSep(), Expanded(child: zone(1))])),
        hSep(),
        Expanded(child: Row(children: [Expanded(child: zone(2)), vSep(), Expanded(child: zone(3))])),
        hSep(),
        Expanded(child: Row(children: [
          Expanded(child: zone(4)),
          vSep(),
          Expanded(
            child: Container(
              color: Colors.white.withValues(alpha: 0.05),
              child: const Center(
                child: Icon(Icons.block, color: Colors.white24, size: 18),
              ),
            ),
          ),
        ])),
      ]);
    }
    // 6 zones: 2x3
    return Column(children: [
      Expanded(child: Row(children: [Expanded(child: zone(0)), vSep(), Expanded(child: zone(1))])),
      hSep(),
      Expanded(child: Row(children: [Expanded(child: zone(2)), vSep(), Expanded(child: zone(3))])),
      hSep(),
      Expanded(child: Row(children: [Expanded(child: zone(4)), vSep(), Expanded(child: zone(5))])),
    ]);
  }
}

class _Zone extends StatelessWidget {
  final String label;
  final Color color;
  const _Zone({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: color.withValues(alpha: 0.3),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}

/// Input field for the per-preset Assistant redirect URL.
/// Leaving it empty falls back to the global `SettingsProvider.freeTextRedirectUrl`.
class _AssistantRedirectField extends StatelessWidget {
  final TextEditingController controller;
  final Language locale;
  final ValueChanged<String>? onChanged;

  const _AssistantRedirectField({
    required this.controller,
    required this.locale,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isFR = locale == Language.french;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.link, size: 16, color: AppTheme.textSecondary),
              const SizedBox(width: 6),
              Text(
                isFR ? 'Redirection Assistant (optionnel)' : 'Assistant Redirect (optional)',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            isFR
                ? 'Après l\'input de l\'assistant sur oass.app, sa page est redirigée vers cette URL. Vide = utilise la redirection globale des Paramètres.'
                : 'After the assistant sends input on oass.app, their page redirects to this URL. Empty = fall back to the global one in Settings.',
            style: const TextStyle(fontSize: 10, color: AppTheme.textTertiary, height: 1.3),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            keyboardType: TextInputType.url,
            style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary),
            decoration: InputDecoration(
              hintText: 'https://...',
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
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

/// Per-preset decoy image URL input. Empty = inherit
/// `SettingsProvider.defaultDecoyImageUrl`.
class _DecoyImageUrlField extends StatefulWidget {
  final TextEditingController controller;
  final Language locale;
  final ValueChanged<String>? onChanged;
  final String inputType; // 'tap' or 'swipe'
  final ValueChanged<String> onInputTypeChanged;
  final TextEditingController redirectController;
  final ValueChanged<String>? onRedirectChanged;

  const _DecoyImageUrlField({
    required this.controller,
    required this.locale,
    this.onChanged,
    required this.inputType,
    required this.onInputTypeChanged,
    required this.redirectController,
    this.onRedirectChanged,
  });

  @override
  State<_DecoyImageUrlField> createState() => _DecoyImageUrlFieldState();
}

class _DecoyImageUrlFieldState extends State<_DecoyImageUrlField> {
  bool _uploading = false;

  Future<void> _pickAndUpload() async {
    final isFR = widget.locale == Language.french;
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1920,
    );
    if (picked == null) return;
    setState(() => _uploading = true);
    final url = await CloudinaryService.uploadDecoyImage(picked.path);
    if (!mounted) return;
    setState(() => _uploading = false);
    if (url != null) {
      widget.controller.text = url;
      widget.onChanged?.call(url);
      setState(() {});
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isFR ? 'Échec de l\'upload' : 'Upload failed'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _clearImage() {
    widget.controller.text = '';
    widget.onChanged?.call('');
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isFR = widget.locale == Language.french;
    final url = widget.controller.text.trim();
    final hasImage = url.isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.image_outlined, size: 16, color: AppTheme.textSecondary),
              const SizedBox(width: 6),
              Text(
                isFR ? 'Image Decoy (optionnel)' : 'Decoy Image (optional)',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            isFR
                ? 'Image affichée plein écran sur oass.app/{id} pendant le mode decoy. Vide = utilise l\'image par défaut des Paramètres.'
                : 'Image shown fullscreen on oass.app/{id} during decoy mode. Empty = fall back to the global default in Settings.',
            style: const TextStyle(fontSize: 10, color: AppTheme.textTertiary, height: 1.3),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hasImage) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.network(
                    url,
                    width: 40, height: 40, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 40, height: 40,
                      color: AppTheme.background,
                      child: const Icon(Icons.broken_image, size: 18, color: AppTheme.textTertiary),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  keyboardType: TextInputType.url,
                  style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'https://...',
                    hintStyle: const TextStyle(fontSize: 11, color: AppTheme.textTertiary),
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
                  onChanged: (v) {
                    widget.onChanged?.call(v);
                    setState(() {});
                  },
                ),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: _uploading ? null : _pickAndUpload,
                child: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.primary.withValues(alpha: 0.4)),
                  ),
                  child: _uploading
                      ? const Padding(
                          padding: EdgeInsets.all(10),
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
                        )
                      : const Icon(Icons.upload, size: 18, color: AppTheme.primary),
                ),
              ),
              if (hasImage) ...[
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: _clearImage,
                  child: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: AppTheme.background,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: const Icon(Icons.close, size: 18, color: AppTheme.textSecondary),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                isFR ? 'Geste :' : 'Gesture:',
                style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
              ),
              const SizedBox(width: 10),
              Expanded(child: _DecoyInputTypePill(
                label: 'Tap',
                selected: widget.inputType == 'tap',
                onTap: () => widget.onInputTypeChanged('tap'),
              )),
              const SizedBox(width: 6),
              Expanded(child: _DecoyInputTypePill(
                label: 'Swipe',
                selected: widget.inputType == 'swipe',
                onTap: () => widget.onInputTypeChanged('swipe'),
              )),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            isFR ? 'Redirection après input (vide = défaut global)' : 'Redirect URL after input (empty = global default)',
            style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: widget.redirectController,
            keyboardType: TextInputType.url,
            style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary),
            decoration: InputDecoration(
              hintText: 'https://...',
              hintStyle: const TextStyle(fontSize: 11, color: AppTheme.textTertiary),
              filled: true,
              fillColor: AppTheme.background,
              isDense: true,
              prefixIcon: const Icon(Icons.link, size: 16, color: AppTheme.textSecondary),
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
            onChanged: widget.onRedirectChanged,
          ),
        ],
      ),
    );
  }
}

class _DecoyInputTypePill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _DecoyInputTypePill({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primary.withValues(alpha: 0.15) : AppTheme.background,
          borderRadius: BorderRadius.circular(7),
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

/// Per-preset decoy template picker. Lets the user pick from the user's
/// saved templates (Settings → Display → Decoy Templates) or pick "None"
/// to fall back to the global default. Also exposes the gesture toggle and
/// the per-preset redirect URL.
class _DecoyTemplatePickerField extends StatelessWidget {
  final Language locale;
  final String? selectedId;
  final ValueChanged<String?> onChanged;
  final String inputType;
  final ValueChanged<String> onInputTypeChanged;
  final TextEditingController redirectController;
  final ValueChanged<String>? onRedirectChanged;

  const _DecoyTemplatePickerField({
    required this.locale,
    required this.selectedId,
    required this.onChanged,
    required this.inputType,
    required this.onInputTypeChanged,
    required this.redirectController,
    this.onRedirectChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isFR = locale == Language.french;
    final settings = context.watch<SettingsProvider>();
    final templates = settings.decoyTemplates;
    final defaultId = settings.defaultDecoyTemplateId;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.image_outlined, size: 16, color: AppTheme.textSecondary),
              const SizedBox(width: 6),
              Text(
                isFR ? 'Decoy template' : 'Decoy template',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            isFR
                ? 'Choisis un template (créés dans Paramètres → Display). Vide = défaut global.'
                : 'Pick a template (managed in Settings → Display). Empty = global default.',
            style: const TextStyle(fontSize: 10, color: AppTheme.textTertiary, height: 1.3),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String?>(
            value: selectedId,
            isExpanded: true,
            decoration: InputDecoration(
              filled: true,
              fillColor: AppTheme.background,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.border)),
            ),
            dropdownColor: AppTheme.surface,
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
            items: [
              DropdownMenuItem<String?>(
                value: null,
                child: Text(defaultId == null
                    ? (isFR ? '— Aucun (défaut global non défini) —' : '— None (no global default) —')
                    : (isFR
                        ? '— Défaut global (${settings.decoyTemplateById(defaultId)?.name ?? 'unknown'}) —'
                        : '— Global default (${settings.decoyTemplateById(defaultId)?.name ?? 'unknown'}) —')),
              ),
              for (final t in templates)
                DropdownMenuItem<String?>(value: t.id, child: Text(t.name)),
            ],
            onChanged: onChanged,
          ),
          if (templates.isEmpty) ...[
            const SizedBox(height: 6),
            Text(
              isFR
                  ? 'Aucun template encore. Crée-en dans Paramètres → Display → Decoy Templates.'
                  : 'No template yet. Create one in Settings → Display → Decoy Templates.',
              style: const TextStyle(fontSize: 10, color: AppTheme.textTertiary),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                isFR ? 'Geste :' : 'Gesture:',
                style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
              ),
              const SizedBox(width: 10),
              Expanded(child: _DecoyInputTypePill(
                label: 'Tap',
                selected: inputType == 'tap',
                onTap: () => onInputTypeChanged('tap'),
              )),
              const SizedBox(width: 6),
              Expanded(child: _DecoyInputTypePill(
                label: 'Swipe',
                selected: inputType == 'swipe',
                onTap: () => onInputTypeChanged('swipe'),
              )),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            isFR ? 'Redirection après input (vide = défaut global)' : 'Redirect URL after input (empty = global default)',
            style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: redirectController,
            keyboardType: TextInputType.url,
            style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary),
            decoration: InputDecoration(
              hintText: 'https://...',
              hintStyle: const TextStyle(fontSize: 11, color: AppTheme.textTertiary),
              filled: true,
              fillColor: AppTheme.background,
              isDense: true,
              prefixIcon: const Icon(Icons.link, size: 16, color: AppTheme.textSecondary),
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.border)),
            ),
            onChanged: onRedirectChanged,
          ),
        ],
      ),
    );
  }
}
