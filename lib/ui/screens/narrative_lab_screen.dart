import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../utils/presets_provider.dart';
import '../../engine/narrative_lab_generator.dart';
import '../theme/app_theme.dart';

class NarrativeLabScreen extends StatefulWidget {
  const NarrativeLabScreen({super.key});

  @override
  State<NarrativeLabScreen> createState() => _NarrativeLabScreenState();
}

class _NarrativeLabScreenState extends State<NarrativeLabScreen> {
  Preset? _selectedPreset;
  int _permutationsCount = 5;
  bool _isGenerating = false;
  List<LabScenarioResult>? _results;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Load presets if not already loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<PresetsProvider>();
      if (provider.isEmpty) {
        provider.loadPresets();
      }
    });
  }

  void _generate() {
    if (_selectedPreset == null) {
      setState(() => _error = 'Please select a preset');
      return;
    }

    // Only allow Choices presets (not Duel)
    if (_selectedPreset!.type == PresetType.duel) {
      setState(() => _error = 'Duel presets are not supported in Narrative Lab');
      return;
    }

    setState(() {
      _isGenerating = true;
      _error = null;
      _results = null;
    });

    // Generate in a microtask to allow UI to update
    Future.microtask(() {
      try {
        final generator = NarrativeLabGenerator(
          preset: _selectedPreset!,
          permutationsCount: _permutationsCount,
        );
        final results = generator.generateCanonicalScenarios();
        if (mounted) {
          setState(() {
            _results = results;
            _isGenerating = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _error = 'Generation failed: $e';
            _isGenerating = false;
          });
        }
      }
    });
  }

  void _copyAllLogs() {
    if (_selectedPreset == null || _results == null) return;

    final log = NarrativeLabGenerator.generateFullLog(
      preset: _selectedPreset!,
      results: _results!,
    );

    Clipboard.setData(ClipboardData(text: log));
    _showSnackBar('Full log copied to clipboard');
  }

  void _copyScenarioLog(LabScenarioResult result) {
    final log = result.toLogString();
    Clipboard.setData(ClipboardData(text: log));
    _showSnackBar('Scenario log copied');
  }

  void _copyVariantOutput(LabVariant variant) {
    Clipboard.setData(ClipboardData(text: variant.text));
    _showSnackBar('Output copied');
  }

  void _copyVariantTrace(LabVariant variant) {
    Clipboard.setData(ClipboardData(text: variant.traceString));
    _showSnackBar('Trace copied');
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Narrative Lab'),
        backgroundColor: AppTheme.surface,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
        actions: [
          if (_results != null)
            IconButton(
              icon: const Icon(Icons.copy_all),
              tooltip: 'Copy All Logs',
              onPressed: _copyAllLogs,
            ),
        ],
      ),
      body: Column(
        children: [
          _buildControlPanel(),
          if (_error != null) _buildErrorBanner(),
          Expanded(
            child: _buildResultsSection(),
          ),
        ],
      ),
    );
  }

  Widget _buildControlPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border(
          bottom: BorderSide(color: AppTheme.divider),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Preset Selector
          _buildPresetSelector(),
          const SizedBox(height: 16),

          // Preset Summary
          if (_selectedPreset != null) ...[
            _buildPresetSummary(),
            const SizedBox(height: 16),
          ],

          // Controls Row
          Row(
            children: [
              // Permutations Stepper
              _buildPermutationsStepper(),
              const Spacer(),
              // Generate Button
              _buildGenerateButton(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPresetSelector() {
    return Consumer<PresetsProvider>(
      builder: (context, provider, child) {
        // Filter to only show Choices presets
        final choicesPresets = provider.presets
            .where((p) => p.type == PresetType.choices)
            .toList();

        if (provider.isLoading) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(8),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }

        if (choicesPresets.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.divider),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.grey[500]),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'No Choices presets found. Create one in Preset Builder.',
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                ),
              ],
            ),
          );
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.divider),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<Preset>(
              value: _selectedPreset,
              isExpanded: true,
              hint: const Text('Select a Choices preset'),
              dropdownColor: AppTheme.surface,
              style: const TextStyle(
                fontSize: 16,
                color: AppTheme.textPrimary,
              ),
              icon: const Icon(Icons.keyboard_arrow_down, color: AppTheme.accent),
              items: choicesPresets.map((preset) {
                return DropdownMenuItem<Preset>(
                  value: preset,
                  child: Text(
                    '${preset.name} (${preset.language.code})',
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: (preset) {
                setState(() {
                  _selectedPreset = preset;
                  _results = null;
                  _error = null;
                });
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildPresetSummary() {
    final preset = _selectedPreset!;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildSummaryChip(
                preset.predictionMode == PredictionMode.game ? 'GAME' : 'DIRECT',
                preset.predictionMode == PredictionMode.game
                    ? Colors.green
                    : Colors.orange,
              ),
              const SizedBox(width: 8),
              _buildSummaryChip(preset.language.code, Colors.blue),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Options: ${preset.labels.join(", ")} (${preset.nbOptions})',
            style: TextStyle(fontSize: 13, color: Colors.grey[400]),
          ),
          Text(
            'Rounds: ${preset.nbRounds} | Input: ${preset.inputMode.name}',
            style: TextStyle(fontSize: 13, color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _buildPermutationsStepper() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Perms:',
          style: TextStyle(color: Colors.grey[400], fontSize: 14),
        ),
        const SizedBox(width: 8),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.background,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.remove, size: 18),
                color: AppTheme.accent,
                onPressed: _permutationsCount > 1
                    ? () => setState(() => _permutationsCount--)
                    : null,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                padding: EdgeInsets.zero,
              ),
              Container(
                width: 28,
                alignment: Alignment.center,
                child: Text(
                  '$_permutationsCount',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add, size: 18),
                color: AppTheme.accent,
                onPressed: _permutationsCount < 20
                    ? () => setState(() => _permutationsCount++)
                    : null,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                padding: EdgeInsets.zero,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGenerateButton() {
    return ElevatedButton.icon(
      onPressed: _isGenerating ? null : _generate,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.accent,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      icon: _isGenerating
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Icon(Icons.play_arrow, size: 20),
      label: Text(_isGenerating ? 'Gen...' : 'Generate'),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      color: Colors.red.withOpacity(0.2),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _error!,
              style: const TextStyle(color: Colors.red),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            color: Colors.red,
            onPressed: () => setState(() => _error = null),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsSection() {
    if (_results == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.science_outlined, size: 64, color: Colors.grey[600]),
            const SizedBox(height: 16),
            Text(
              'Select a preset and generate scenarios',
              style: TextStyle(color: Colors.grey[500], fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _results!.length,
      itemBuilder: (context, index) {
        return _buildScenarioCard(_results![index]);
      },
    );
  }

  Widget _buildScenarioCard(LabScenarioResult result) {
    return Card(
      color: AppTheme.surface,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        childrenPadding: const EdgeInsets.all(16),
        shape: const Border(),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.accent.withOpacity(0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                result.scenario.id,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.accent,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                result.scenario.name,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Spectator: ${result.spectatorLabels.join(" -> ")}',
                style: TextStyle(fontSize: 12, color: Colors.grey[400]),
              ),
              if (result.performerLabels != null)
                Text(
                  'Performer: ${result.performerLabels!.join(" -> ")}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                ),
              const SizedBox(height: 4),
              Row(
                children: [
                  _buildOutcomeChip(result.summary.outcomeType),
                  const SizedBox(width: 6),
                  _buildPatternChip(result.summary.patternType),
                ],
              ),
            ],
          ),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.copy, size: 20),
          color: AppTheme.accent,
          tooltip: 'Copy Scenario Log',
          onPressed: () => _copyScenarioLog(result),
        ),
        children: [
          // Summary details
          _buildSummaryDetails(result.summary),
          const Divider(height: 24),

          // Variants
          Text(
            'VARIANTS (${result.variants.length})',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey[500],
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 12),
          ...result.variants.asMap().entries.map((entry) {
            return _buildVariantCard(entry.key + 1, entry.value);
          }),
        ],
      ),
    );
  }

  Widget _buildOutcomeChip(String outcome) {
    Color color;
    switch (outcome) {
      case 'allHit':
        color = Colors.green;
        break;
      case 'allMiss':
        color = Colors.red;
        break;
      case 'oneMiss':
        color = Colors.orange;
        break;
      case 'twoMiss':
        color = Colors.deepOrange;
        break;
      case 'direct':
        color = Colors.blue;
        break;
      default:
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        outcome,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }

  Widget _buildPatternChip(String pattern) {
    Color color;
    switch (pattern) {
      case 'repeatHeavy':
        color = Colors.purple;
        break;
      case 'oneSwitch':
        color = Colors.teal;
        break;
      case 'alternating':
        color = Colors.cyan;
        break;
      case 'mixed':
        color = Colors.amber;
        break;
      default:
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        pattern,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }

  Widget _buildSummaryDetails(LabComputedSummary summary) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildDetailItem('Hits', '${summary.hitCount}', Colors.green),
              const SizedBox(width: 16),
              _buildDetailItem('Misses', '${summary.missCount}', Colors.red),
              const SizedBox(width: 16),
              _buildDetailItem('Dominant', summary.dominant, Colors.purple),
              const SizedBox(width: 16),
              _buildDetailItem('Dom. Count', '${summary.dominantCount}', Colors.purple),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildDetailItem('Streak', '${summary.streakLen}', Colors.blue),
              const SizedBox(width: 16),
              _buildDetailItem('Switches', '${summary.switchCount}', Colors.orange),
              if (summary.missIndices.isNotEmpty) ...[
                const SizedBox(width: 16),
                _buildDetailItem(
                  'Miss Rounds',
                  summary.missIndices.map((i) => i + 1).join(', '),
                  Colors.red,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(String label, String value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label: ',
          style: TextStyle(fontSize: 11, color: Colors.grey[500]),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildVariantCard(int index, LabVariant variant) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'V$index',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'seed=${variant.seed}',
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
              ),
              const SizedBox(width: 8),
              Text(
                '${variant.wordCount} words',
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.content_copy, size: 16),
                tooltip: 'Copy Output',
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                padding: EdgeInsets.zero,
                color: AppTheme.accent,
                onPressed: () => _copyVariantOutput(variant),
              ),
              IconButton(
                icon: const Icon(Icons.bug_report_outlined, size: 16),
                tooltip: 'Copy Trace',
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                padding: EdgeInsets.zero,
                color: Colors.orange,
                onPressed: () => _copyVariantTrace(variant),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // IDs
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              _buildIdChip('Hook', variant.hookId),
              if (variant.performerLineId != null)
                _buildIdChip('Perf', variant.performerLineId!),
              _buildIdChip('Pattern', variant.patternLineId),
              if (variant.intentLineId != null)
                _buildIdChip('Intent', variant.intentLineId!),
              if (variant.missLineId != null)
                _buildIdChip('Miss', variant.missLineId!),
              _buildIdChip('Closer', variant.closerId),
            ],
          ),
          const SizedBox(height: 12),

          // Output text
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              variant.text,
              style: const TextStyle(
                fontSize: 14,
                height: 1.5,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIdChip(String label, String id) {
    // Truncate long IDs
    final displayId = id.length > 30 ? '${id.substring(0, 27)}...' : id;

    return Tooltip(
      message: id,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.2),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          '$label: $displayId',
          style: TextStyle(
            fontSize: 9,
            fontFamily: 'monospace',
            color: Colors.grey[400],
          ),
        ),
      ),
    );
  }
}
