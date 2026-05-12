import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/preset_templates.dart';
import '../../models/models.dart';
import '../../models/confabulation_preset.dart';
import '../../services/firebase_service.dart';
import '../../utils/presets_provider.dart';
import '../../utils/confabulation_provider.dart';
import '../../utils/settings_provider.dart';
import '../theme/app_theme.dart';

class TemplatesScreen extends StatefulWidget {
  const TemplatesScreen({super.key});

  @override
  State<TemplatesScreen> createState() => _TemplatesScreenState();
}

class _TemplatesScreenState extends State<TemplatesScreen> {
  bool _loading = true;
  List<_TemplateEntry> _entries = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final raw = await FirebaseService.fetchTemplates();
      final remote = raw.entries
          .map((e) => _TemplateEntry.remote(e.key, e.value as Map))
          .whereType<_TemplateEntry>()
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      final local = presetTemplates.map(_TemplateEntry.local).toList();

      if (!mounted) return;
      setState(() {
        _entries = [...remote, ...local];
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final lang = settings.appLanguage;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(_t(lang, 'Templates', 'Templates', 'Plantillas')),
        backgroundColor: AppTheme.surface,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _refresh,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Localized note
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 16, color: AppTheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _t(
                        lang,
                        'Add a template to your presets — you can edit it after just like a normal preset.',
                        'Ajoute un template à tes presets — tu peux le modifier ensuite comme un preset normal.',
                        'Añade una plantilla a tus presets — puedes editarla después como un preset normal.',
                      ),
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                  ),
                ],
              ),
            ),

            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    _t(
                      lang,
                      'Loading error: $_error',
                      'Erreur de chargement: $_error',
                      'Error de carga: $_error',
                    ),
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ),
              if (_entries.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: Text(
                      _t(
                        lang,
                        'No templates available.',
                        'Aucun template disponible.',
                        'No hay plantillas disponibles.',
                      ),
                      style: TextStyle(
                        color: AppTheme.textTertiary,
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ),
              ..._entries.map(
                (t) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _TemplateCard(
                    entry: t,
                    lang: lang,
                    onAdded: () {},
                    onDeleted: _refresh,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _t(Language lang, String en, String fr, String es) {
  switch (lang) {
    case Language.french:
      return fr;
    case Language.spanish:
      return es;
    case Language.english:
      return en;
  }
}

/// Unified template entry. Wraps either a local hardcoded template or a remote
/// Firebase template (regular preset or confabulation).
class _TemplateEntry {
  final String name;
  final String description;
  final int createdAt;
  final bool isRemote;
  final String? remoteId;
  final String _kind; // 'preset', 'confabulation'
  final Map<String, dynamic>? presetJson;
  final PresetTemplate? localTemplate;

  const _TemplateEntry._({
    required this.name,
    required this.description,
    required this.createdAt,
    required this.isRemote,
    this.remoteId,
    required String kind,
    this.presetJson,
    this.localTemplate,
  }) : _kind = kind;

  factory _TemplateEntry.local(PresetTemplate t) {
    final p = t.build();
    return _TemplateEntry._(
      name: t.name,
      description: t.description,
      createdAt: 0,
      isRemote: false,
      kind: 'preset',
      localTemplate: t,
      presetJson: p.toJson(),
    );
  }

  static _TemplateEntry? remote(String id, Map raw) {
    try {
      final preset = raw['preset'];
      if (preset is! Map) return null;
      final json = Map<String, dynamic>.from(preset);
      final kind = (json.remove('kind') as String?) ?? 'preset';
      return _TemplateEntry._(
        name: (raw['name'] as String?) ?? 'Untitled',
        description: (raw['description'] as String?) ?? '',
        createdAt: (raw['createdAt'] as int?) ?? 0,
        isRemote: true,
        remoteId: id,
        kind: kind,
        presetJson: json,
      );
    } catch (_) {
      return null;
    }
  }

  bool get isConfabulation => _kind == 'confabulation';

  /// Color matches the preset/confab type — same palette as the home cards.
  Color get color {
    if (isConfabulation) return AppTheme.confabulationColor;
    final type = presetJson?['type'] as String?;
    return switch (type) {
      'duel' => AppTheme.duelColor,
      'freeWill' => AppTheme.freeWillColor,
      'multipleOut' => AppTheme.multipleOutColor,
      'number' => const Color(0xFFFF6B6B),
      _ => AppTheme.multiChoiceColor,
    };
  }

  String get badgeLabel {
    if (isConfabulation) return 'Confabulation';
    final type = presetJson?['type'] as String?;
    return switch (type) {
      'choices' => 'Choices',
      'duel' => 'Duel',
      'freeWill' => 'Free Will',
      'multipleOut' => 'Multiple Out',
      'number' => 'Number',
      _ => 'Preset',
    };
  }

  Future<String?> add(BuildContext context) async {
    if (presetJson == null) return null;
    if (localTemplate != null) {
      final preset = localTemplate!.build();
      final ok = await context.read<PresetsProvider>().addPreset(preset);
      return ok ? preset.name : null;
    }
    final json = Map<String, dynamic>.from(presetJson!);
    json.remove('id');
    if (isConfabulation) {
      final confab = ConfabulationPreset.fromJson({
        ...json,
        'id': DateTime.now().microsecondsSinceEpoch.toString(),
      });
      final ok = await context.read<ConfabulationProvider>().addPreset(confab);
      return ok ? confab.name : null;
    } else {
      final preset = Preset.fromJson(json);
      final ok = await context.read<PresetsProvider>().addPreset(preset);
      return ok ? preset.name : null;
    }
  }
}

/// Detail chips identical in style to the home preset cards
/// (`3r`, `3 opt`, `Vol`, `PS:HMH`, etc.).
class _TplChip extends StatelessWidget {
  final IconData? icon;
  final String label;
  const _TplChip({this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: AppTheme.textTertiary),
            const SizedBox(width: 4),
          ],
          Text(label,
              style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
        ],
      ),
    );
  }
}

List<Widget> _buildDetailChips(_TemplateEntry entry) {
  final j = entry.presetJson ?? const {};
  if (entry.isConfabulation) {
    final slots = j['slots'];
    final method = j['inputMethod'] as String? ?? '';
    return [
      if (slots is List && slots.isNotEmpty)
        _TplChip(icon: Icons.layers, label: '${slots.length} slots'),
      if (method.isNotEmpty)
        _TplChip(icon: _confabIcon(method), label: _confabLabel(method)),
    ];
  }

  final chips = <Widget>[];
  final type = j['type'] as String?;
  final stealth = j['stealthInputMethod'] as String?;

  if (type == 'freeWill') {
    final cfg = j['freeWillConfig'];
    if (cfg is Map && cfg['objects'] is List) {
      chips.add(_TplChip(
        icon: Icons.inventory_2_outlined,
        label: (cfg['objects'] as List).join(' · '),
      ));
    }
    if (stealth != null && stealth != 'assistant') {
      chips.add(_TplChip(icon: _stealthIcon(stealth), label: _stealthLabel(stealth)));
    }
  } else if (type == 'multipleOut') {
    final texts = j['multipleOutTexts'];
    chips.add(_TplChip(
      icon: Icons.format_list_numbered,
      label: '${texts is List ? texts.length : 0} texts',
    ));
    if (stealth != null && stealth != 'assistant') {
      chips.add(_TplChip(icon: _stealthIcon(stealth), label: _stealthLabel(stealth)));
    }
  } else if (type == 'number') {
    final mode = j['numberMode'];
    if (mode != null) chips.add(_TplChip(icon: Icons.calculate, label: mode.toString()));
    final out = j['numberOutputMode'] ?? 'calculator';
    chips.add(_TplChip(
      icon: out == 'calculator' ? Icons.calculate : Icons.note,
      label: out == 'calculator' ? 'Calculator' : 'Notes',
    ));
  } else {
    // Choices, Duel, default
    final rounds = j['nbRounds'];
    final opts = j['nbOptions'];
    if (rounds != null) chips.add(_TplChip(icon: Icons.repeat, label: '${rounds}r'));
    if (opts != null) chips.add(_TplChip(icon: Icons.list, label: '$opts opt'));
    if (stealth != null && stealth != 'assistant') {
      chips.add(_TplChip(icon: _stealthIcon(stealth), label: _stealthLabel(stealth)));
    }
    final perfSeq = j['performerSequence'];
    final inputMode = j['inputMode'];
    final labels = j['labels'];
    if (inputMode == 'preprogrammed' &&
        perfSeq is List &&
        perfSeq.isNotEmpty &&
        labels is List) {
      final ps = perfSeq
          .map((i) => i is int && i < labels.length
              ? (labels[i] as String).substring(0, 1).toUpperCase()
              : '?')
          .join();
      chips.add(_TplChip(icon: Icons.playlist_play, label: 'PS:$ps'));
    }
    if (inputMode == 'twoInputs') {
      chips.add(const _TplChip(icon: Icons.swap_vert, label: '2 inputs'));
    }
  }
  return chips;
}

IconData _stealthIcon(String s) => switch (s) {
      'volume' => Icons.volume_up,
      'tap' => Icons.fingerprint,
      'audio' => Icons.mic,
      'clockSwipe' => Icons.swipe,
      _ => Icons.touch_app,
    };
String _stealthLabel(String s) => switch (s) {
      'volume' => 'Vol',
      'tap' => 'Tap',
      'audio' => 'IA',
      'clockSwipe' => 'Swipe',
      _ => s,
    };
IconData _confabIcon(String s) => _stealthIcon(s);
String _confabLabel(String s) => _stealthLabel(s);

class _TemplateCard extends StatelessWidget {
  final _TemplateEntry entry;
  final Language lang;
  final VoidCallback onAdded;
  final VoidCallback onDeleted;
  const _TemplateCard({
    required this.entry,
    required this.lang,
    required this.onAdded,
    required this.onDeleted,
  });

  Future<void> _add(BuildContext context) async {
    try {
      final addedName = await entry.add(context);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.surface,
          content: Text(
            addedName != null
                ? _t(lang, 'Preset "$addedName" added',
                    'Preset "$addedName" ajouté', 'Preset "$addedName" añadido')
                : _t(lang, 'Failed to add', 'Échec de l\'ajout', 'Error al añadir'),
            style: TextStyle(color: addedName != null ? AppTheme.textPrimary : Colors.red),
          ),
        ),
      );
      if (addedName != null) onAdded();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.surface,
          content: Text('Erreur: $e', style: const TextStyle(color: Colors.red)),
        ),
      );
    }
  }

  void _openInfo(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _TemplateDetailScreen(
          entry: entry,
          lang: lang,
          onDeleted: onDeleted,
        ),
      ),
    );
  }

  Future<void> _quickDelete(BuildContext context) async {
    final settings = context.read<SettingsProvider>();
    if (entry.remoteId == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text(_t(lang, 'Delete "${entry.name}"?',
            'Supprimer "${entry.name}" ?', '¿Eliminar "${entry.name}"?'),
            style: const TextStyle(color: AppTheme.textPrimary)),
        content: Text(
          _t(lang,
              'The template will be removed for everyone.',
              'Le template sera retiré pour tous les utilisateurs.',
              'La plantilla se eliminará para todos.'),
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(_t(lang, 'Cancel', 'Annuler', 'Cancelar')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(_t(lang, 'Delete', 'Supprimer', 'Eliminar')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final ok = await FirebaseService.deleteTemplate(
      id: entry.remoteId!,
      adminToken: settings.templatesAdminToken,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppTheme.surface,
        content: Text(
          ok
              ? _t(lang, 'Template deleted', 'Template supprimé', 'Plantilla eliminada')
              : _t(lang, 'Delete failed', 'Échec de la suppression', 'Error al eliminar'),
          style: TextStyle(color: ok ? AppTheme.textPrimary : Colors.red),
        ),
      ),
    );
    if (ok) onDeleted();
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.watch<SettingsProvider>().isTemplatesAdmin;
    final color = entry.color;
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 4,
                  height: 60,
                  decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              entry.badgeLabel,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: color,
                              ),
                            ),
                          ),
                          ..._buildDetailChips(entry),
                          if (entry.isRemote)
                            const Icon(Icons.cloud_done, size: 14, color: AppTheme.primary),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () => _add(context),
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(_t(lang, 'Add', 'Add', 'Añadir')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  onPressed: () => _openInfo(context),
                  icon: const Icon(Icons.info_outline, color: AppTheme.textSecondary, size: 20),
                  tooltip: _t(lang, 'See structure', 'Voir la structure', 'Ver estructura'),
                  padding: const EdgeInsets.all(8),
                  constraints: const BoxConstraints(),
                ),
                if (isAdmin && entry.remoteId != null)
                  IconButton(
                    onPressed: () => _quickDelete(context),
                    icon: Icon(Icons.delete_outline, color: Colors.red.withOpacity(0.7), size: 20),
                    tooltip: _t(lang, 'Delete (admin)', 'Supprimer (admin)', 'Eliminar (admin)'),
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Read-only structure view for a template.
class _TemplateDetailScreen extends StatelessWidget {
  final _TemplateEntry entry;
  final Language lang;
  final VoidCallback onDeleted;
  const _TemplateDetailScreen({
    required this.entry,
    required this.lang,
    required this.onDeleted,
  });

  Future<void> _delete(BuildContext context) async {
    final settings = context.read<SettingsProvider>();
    if (entry.remoteId == null || !settings.isTemplatesAdmin) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text(_t(lang, 'Delete "${entry.name}"?',
            'Supprimer "${entry.name}" ?', '¿Eliminar "${entry.name}"?'),
            style: const TextStyle(color: AppTheme.textPrimary)),
        content: Text(
          _t(lang, 'The template will be removed for everyone.',
              'Le template sera retiré pour tous les utilisateurs.',
              'La plantilla se eliminará para todos.'),
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(_t(lang, 'Cancel', 'Annuler', 'Cancelar')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(_t(lang, 'Delete', 'Supprimer', 'Eliminar')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final ok = await FirebaseService.deleteTemplate(
      id: entry.remoteId!,
      adminToken: settings.templatesAdminToken,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppTheme.surface,
        content: Text(
          ok
              ? _t(lang, 'Template deleted', 'Template supprimé', 'Plantilla eliminada')
              : _t(lang, 'Delete failed', 'Échec de la suppression', 'Error al eliminar'),
          style: TextStyle(color: ok ? AppTheme.textPrimary : Colors.red),
        ),
      ),
    );
    if (ok && context.mounted) {
      onDeleted();
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.watch<SettingsProvider>().isTemplatesAdmin;
    final color = entry.color;
    final json = entry.presetJson ?? const {};

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(entry.name),
        backgroundColor: AppTheme.surface,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  entry.badgeLabel,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Description
          if (entry.description.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.border),
              ),
              child: Text(
                entry.description,
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13, height: 1.4),
              ),
            )
          else
            Text(
              _t(lang, 'No description.', 'Pas de description.', 'Sin descripción.'),
              style: TextStyle(
                color: AppTheme.textTertiary,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          const SizedBox(height: 24),

          _SectionLabel(_t(lang, 'STRUCTURE', 'STRUCTURE', 'ESTRUCTURA')),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _buildStructureRows(json),
            ),
          ),

          // Multiple Out texts (text bank)
          if (json['multipleOutTexts'] is List && (json['multipleOutTexts'] as List).isNotEmpty) ...[
            const SizedBox(height: 24),
            _SectionLabel(_t(lang, 'TEXT BANK', 'BANQUE DE TEXTES', 'BANCO DE TEXTOS')),
            const SizedBox(height: 8),
            ..._buildMultipleOutTextsBlock(json),
          ],

          // Image bank — preset's bankImages map
          if (json['bankImages'] is Map && (json['bankImages'] as Map).isNotEmpty) ...[
            const SizedBox(height: 24),
            _SectionLabel(_t(lang, 'IMAGE BANK', 'BANQUE D\'IMAGES', 'BANCO DE IMÁGENES')),
            const SizedBox(height: 8),
            _imagesBlock(json),
          ],

          // Custom narrative banks (Choices / Duel / Free Will)
          if (_hasCustomBanks(json)) ...[
            const SizedBox(height: 24),
            _SectionLabel(_t(lang, 'CUSTOM TEXT BANK', 'BANQUE DE TEXTES CUSTOM', 'BANCO DE TEXTOS CUSTOM')),
            const SizedBox(height: 8),
            ..._customBanksBlock(json),
          ],

          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _addAndPop(context),
            icon: const Icon(Icons.add),
            label: Text(_t(lang, 'Add to my presets', 'Ajouter à mes presets', 'Añadir a mis presets')),
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _t(lang,
                'You can edit the preset normally after adding it.',
                'Tu pourras modifier le preset normalement après l\'ajout.',
                'Podrás editar el preset normalmente después de añadirlo.'),
            style: TextStyle(
              color: AppTheme.textTertiary,
              fontSize: 11,
              fontStyle: FontStyle.italic,
            ),
            textAlign: TextAlign.center,
          ),

          if (isAdmin && entry.remoteId != null) ...[
            const SizedBox(height: 24),
            const Divider(color: AppTheme.divider),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _delete(context),
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              label: Text(
                _t(lang, 'Delete this template', 'Supprimer ce template', 'Eliminar esta plantilla'),
                style: const TextStyle(color: Colors.red),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.red),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _addAndPop(BuildContext context) async {
    try {
      final addedName = await entry.add(context);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.surface,
          content: Text(
            addedName != null
                ? _t(lang, 'Preset "$addedName" added',
                    'Preset "$addedName" ajouté', 'Preset "$addedName" añadido')
                : _t(lang, 'Failed to add', 'Échec de l\'ajout', 'Error al añadir'),
            style: TextStyle(color: addedName != null ? AppTheme.textPrimary : Colors.red),
          ),
        ),
      );
      if (addedName != null && context.mounted) Navigator.pop(context);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.surface,
          content: Text('Erreur: $e', style: const TextStyle(color: Colors.red)),
        ),
      );
    }
  }

  List<Widget> _buildStructureRows(Map<String, dynamic> json) {
    if (entry.isConfabulation) return _confabRows(json);
    return _presetRows(json);
  }

  List<Widget> _presetRows(Map<String, dynamic> json) {
    final rows = <Widget>[];
    void add(String label, String value) {
      rows.add(_KvRow(label: label, value: value));
    }

    add(_t(lang, 'Type', 'Type', 'Tipo'), _humanType(json['type']?.toString()));
    add(_t(lang, 'Language', 'Langue', 'Idioma'),
        (json['language'] as String? ?? '').toUpperCase());
    if (json['nbRounds'] != null) {
      add(_t(lang, 'Rounds', 'Manches', 'Rondas'), json['nbRounds'].toString());
    }
    if (json['nbOptions'] != null) {
      add(_t(lang, 'Options', 'Options', 'Opciones'), json['nbOptions'].toString());
    }
    final labels = json['labels'];
    if (labels is List && labels.isNotEmpty) {
      add('Labels', labels.join(' · '));
    }
    if (json['inputMode'] != null) {
      add(_t(lang, 'Input mode', 'Mode input', 'Modo input'), json['inputMode'].toString());
    }
    if (json['stealthInputMethod'] != null) {
      add(_t(lang, 'Stealth method', 'Méthode stealth', 'Método sigiloso'),
          json['stealthInputMethod'].toString());
    }
    final perfSeq = json['performerSequence'];
    if (perfSeq is List && perfSeq.isNotEmpty) {
      add(_t(lang, 'Performer sequence', 'Séquence performer', 'Secuencia performer'),
          perfSeq.join(', '));
    }
    return rows;
  }

  List<Widget> _confabRows(Map<String, dynamic> json) {
    final rows = <Widget>[];
    void add(String label, String value) {
      rows.add(_KvRow(label: label, value: value));
    }

    if (json['inputMethod'] != null) {
      add(_t(lang, 'Input method', 'Méthode input', 'Método input'),
          json['inputMethod'].toString());
    }
    final slots = json['slots'];
    if (slots is List) {
      add(_t(lang, 'Slots', 'Nb slots', 'N.º slots'), slots.length.toString());
      for (var i = 0; i < slots.length; i++) {
        final s = slots[i];
        if (s is Map) {
          final label = (s['label'] as String?) ?? '?';
          final options = s['options'];
          final n = options is List ? options.length : 0;
          add('  Slot ${i + 1}', '$label ($n options)');
        }
      }
    }
    if (json['acrosticLanguage'] != null) {
      add(_t(lang, 'Acrostic bank', 'Acrostic banque', 'Banco acrostic'),
          json['acrosticLanguage'].toString());
    }
    if (json['acrosticPosition'] != null) {
      final pos = json['acrosticPosition'] as int? ?? 0;
      add(_t(lang, 'Acrostic position', 'Acrostic position', 'Posición acrostic'),
          pos == -1 ? 'Input' : pos == 0 ? 'Auto' : '$pos');
    }
    final template = json['textTemplate'] as String?;
    if (template != null && template.isNotEmpty) {
      rows.add(const SizedBox(height: 12));
      rows.add(Text(
        'TEMPLATE',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: AppTheme.textSecondary,
          letterSpacing: 1.0,
        ),
      ));
      rows.add(const SizedBox(height: 6));
      rows.add(
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppTheme.background,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            template,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 12,
              fontFamily: 'monospace',
              height: 1.4,
            ),
          ),
        ),
      );
    }
    return rows;
  }

  List<Widget> _buildMultipleOutTextsBlock(Map<String, dynamic> json) {
    final texts = (json['multipleOutTexts'] as List).cast<dynamic>();
    final titles = (json['multipleOutTitles'] is List)
        ? (json['multipleOutTitles'] as List).cast<dynamic>()
        : <dynamic>[];
    return [
      for (int i = 0; i < texts.length; i++)
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                i < titles.length && titles[i] is String && (titles[i] as String).isNotEmpty
                    ? '${i + 1}. ${titles[i]}'
                    : '${i + 1}.',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                texts[i]?.toString() ?? '',
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12, height: 1.3),
              ),
            ],
          ),
        ),
    ];
  }

  Widget _imagesBlock(Map<String, dynamic> json) {
    final images = (json['bankImages'] as Map).cast<String, dynamic>();
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
          for (final entry in images.entries)
            _KvRow(label: entry.key, value: entry.value.toString()),
        ],
      ),
    );
  }

  bool _hasCustomBanks(Map<String, dynamic> json) {
    return (json['customChoicesBankTemplates'] is Map &&
            (json['customChoicesBankTemplates'] as Map).isNotEmpty) ||
        (json['customDuelBankTemplates'] is Map &&
            (json['customDuelBankTemplates'] as Map).isNotEmpty) ||
        (json['customFreeWillBankTemplates'] is Map &&
            (json['customFreeWillBankTemplates'] as Map).isNotEmpty) ||
        (json['customPreprogrammedBanks'] is Map &&
            (json['customPreprogrammedBanks'] as Map).isNotEmpty);
  }

  List<Widget> _customBanksBlock(Map<String, dynamic> json) {
    final widgets = <Widget>[];
    void section(String title, Map? bank) {
      if (bank == null || bank.isEmpty) return;
      widgets.add(Padding(
        padding: const EdgeInsets.only(top: 6, bottom: 4),
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppTheme.textSecondary,
          ),
        ),
      ));
      for (final entry in bank.entries) {
        widgets.add(Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(entry.key.toString(),
                  style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textTertiary,
                      fontFamily: 'monospace')),
              const SizedBox(height: 4),
              Text(entry.value.toString(),
                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12, height: 1.3)),
            ],
          ),
        ));
      }
    }

    section('Choices', json['customChoicesBankTemplates'] as Map?);
    section('Duel', json['customDuelBankTemplates'] as Map?);
    section('Free Will', json['customFreeWillBankTemplates'] as Map?);
    section('Preprogrammed', json['customPreprogrammedBanks'] as Map?);
    return widgets;
  }

  String _humanType(String? type) {
    return switch (type) {
      'choices' => 'Choices',
      'duel' => 'Duel',
      'freeWill' => 'Free Will',
      'multipleOut' => 'Multiple Out',
      'number' => 'Number',
      _ => type ?? '?',
    };
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppTheme.textSecondary,
          letterSpacing: 1.2,
        ),
      );
}

class _KvRow extends StatelessWidget {
  final String label;
  final String value;
  const _KvRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
