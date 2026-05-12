import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../utils/presets_provider.dart';
import '../../utils/confabulation_provider.dart';
import '../../utils/routine_provider.dart';
import '../theme/app_theme.dart';

class RoutineBuilderScreen extends StatefulWidget {
  const RoutineBuilderScreen({super.key});

  @override
  State<RoutineBuilderScreen> createState() => _RoutineBuilderScreenState();
}

class _RoutineBuilderScreenState extends State<RoutineBuilderScreen> {
  final _nameController = TextEditingController();
  List<String> _inputOrder = [];
  List<String> _outputOrder = [];
  String? _editingId;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;

    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Routine) {
      _editingId = args.id;
      _nameController.text = args.name;
      _inputOrder = List.from(args.inputOrder);
      _outputOrder = List.from(args.outputOrder);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _addPreset(String presetId) {
    setState(() {
      _inputOrder.add(presetId);
      _outputOrder.add(presetId);
    });
  }

  void _removePreset(String presetId) {
    setState(() {
      _inputOrder.remove(presetId);
      _outputOrder.remove(presetId);
    });
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name is required')),
      );
      return;
    }
    if (_inputOrder.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least 2 presets')),
      );
      return;
    }

    final routine = Routine(
      id: _editingId,
      name: name,
      inputOrder: _inputOrder,
      outputOrder: _outputOrder,
    );

    final provider = context.read<RoutineProvider>();
    bool success;
    if (_editingId != null) {
      success = await provider.updateRoutine(routine);
    } else {
      success = await provider.addRoutine(routine);
    }

    if (success && mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final presetsProvider = context.watch<PresetsProvider>();
    final confabProvider = context.watch<ConfabulationProvider>();

    // Available presets (not yet in inputOrder)
    final allPresets = presetsProvider.presets;
    final availablePresets = allPresets.where((p) => !_inputOrder.contains(p.id)).toList();

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(_editingId != null ? 'Edit Routine' : 'New Routine'),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Name field
            TextField(
              controller: _nameController,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: InputDecoration(
                labelText: 'Routine Name',
                labelStyle: TextStyle(color: AppTheme.textSecondary),
                filled: true,
                fillColor: AppTheme.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: AppTheme.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: AppTheme.border),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Available presets to add
            if (availablePresets.isNotEmpty) ...[
              Text(
                'Available Presets',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: availablePresets.map((p) {
                  return ActionChip(
                    avatar: const Icon(Icons.add, size: 16),
                    label: Text(p.name, style: const TextStyle(fontSize: 12)),
                    backgroundColor: AppTheme.surface,
                    side: BorderSide(color: AppTheme.border),
                    onPressed: () => _addPreset(p.id),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
            ],

            // Input Order (drag & drop)
            _buildOrderSection(
              title: 'Input Order (performance)',
              subtitle: 'Order in which you collect info during the show',
              order: _inputOrder,
              presetsProvider: presetsProvider,
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (oldIndex < newIndex) newIndex -= 1;
                  final item = _inputOrder.removeAt(oldIndex);
                  _inputOrder.insert(newIndex, item);
                });
              },
              onRemove: _removePreset,
            ),

            const SizedBox(height: 24),

            // Output Order (drag & drop)
            _buildOrderSection(
              title: 'Output Order (revelation)',
              subtitle: 'Order in which prediction text is assembled',
              order: _outputOrder,
              presetsProvider: presetsProvider,
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (oldIndex < newIndex) newIndex -= 1;
                  final item = _outputOrder.removeAt(oldIndex);
                  _outputOrder.insert(newIndex, item);
                });
              },
              onRemove: null, // Only remove from input order
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderSection({
    required String title,
    required String subtitle,
    required List<String> order,
    required PresetsProvider presetsProvider,
    required void Function(int, int) onReorder,
    void Function(String)? onRemove,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(fontSize: 11, color: AppTheme.textTertiary),
        ),
        const SizedBox(height: 8),
        if (order.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.border),
            ),
            child: Text(
              'Add presets above',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textTertiary, fontSize: 13),
            ),
          )
        else
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            proxyDecorator: (child, index, animation) {
              return Material(
                color: Colors.transparent,
                elevation: 4,
                shadowColor: Colors.black54,
                borderRadius: BorderRadius.circular(10),
                child: child,
              );
            },
            onReorder: onReorder,
            itemCount: order.length,
            itemBuilder: (context, index) {
              final presetId = order[index];
              final preset = presetsProvider.getPresetById(presetId);
              final name = preset?.name ?? '?';
              final typeName = preset?.type.name ?? '';

              return Container(
                key: ValueKey('${title}_$presetId'),
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Row(
                  children: [
                    Icon(Icons.drag_handle, size: 18, color: AppTheme.textTertiary),
                    const SizedBox(width: 8),
                    Text(
                      '${index + 1}',
                      style: TextStyle(
                        color: AppTheme.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        name,
                        style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      typeName,
                      style: TextStyle(fontSize: 10, color: AppTheme.textTertiary),
                    ),
                    if (onRemove != null) ...[
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => onRemove(presetId),
                        child: Icon(Icons.close, size: 18, color: AppTheme.textTertiary),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}
