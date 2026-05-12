import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../theme/app_theme.dart';

class QuickCuesPanel extends StatefulWidget {
  final LiveCues initialCues;
  final Language language;
  final VoidCallback onClose;
  final void Function(LiveCues cues) onApply;

  const QuickCuesPanel({
    super.key,
    this.initialCues = const LiveCues(),
    this.language = Language.english,
    required this.onClose,
    required this.onApply,
  });

  @override
  State<QuickCuesPanel> createState() => _QuickCuesPanelState();
}

class _QuickCuesPanelState extends State<QuickCuesPanel> {
  late TextEditingController _nameController;
  ReferenceMode? _selectedMode;
  Handedness? _selectedHandedness;
  final FocusNode _nameFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialCues.spectatorName ?? '');
    _selectedMode = widget.initialCues.referenceMode;
    _selectedHandedness = widget.initialCues.handedness;

    // Auto-focus the name field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _nameFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nameFocusNode.dispose();
    super.dispose();
  }

  void _apply() {
    final cues = LiveCues(
      spectatorName: _nameController.text.trim().isEmpty ? null : _nameController.text.trim(),
      referenceMode: _selectedMode,
      handedness: _selectedHandedness,
    );
    widget.onApply(cues);
  }

  @override
  Widget build(BuildContext context) {
    final isFrench = widget.language == Language.french;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.92),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24, width: 0.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isFrench ? 'Quick Cues' : 'Quick Cues',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              GestureDetector(
                onTap: widget.onClose,
                child: const Icon(Icons.close, color: Colors.white54, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Spectator Name
          TextField(
            controller: _nameController,
            focusNode: _nameFocusNode,
            style: const TextStyle(color: Colors.white, fontSize: 15),
            decoration: InputDecoration(
              hintText: isFrench ? 'Nom du spectateur' : 'Spectator name',
              hintStyle: TextStyle(color: Colors.white38),
              filled: true,
              fillColor: Colors.white.withOpacity(0.1),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              isDense: true,
            ),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _apply(),
          ),
          const SizedBox(height: 12),

          // Reference Mode
          Text(
            isFrench ? 'Mode de r\u00e9f\u00e9rence' : 'Reference mode',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 6),
          _buildModeSelector(isFrench),
          const SizedBox(height: 12),

          // Handedness
          Text(
            isFrench ? 'Main dominante' : 'Handedness',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 6),
          _buildHandednessSelector(isFrench),
          const SizedBox(height: 16),

          // Buttons
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: widget.onClose,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white54,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  child: Text(isFrench ? 'Fermer' : 'Close'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _apply,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(isFrench ? 'Appliquer' : 'Apply'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModeSelector(bool isFrench) {
    return Row(
      children: ReferenceMode.values.map((mode) {
        final isSelected = _selectedMode == mode;
        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _selectedMode = mode),
            child: Container(
              margin: EdgeInsets.only(right: mode != ReferenceMode.neutre ? 6 : 0),
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.accent.withOpacity(0.3) : Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(6),
                border: isSelected ? Border.all(color: AppTheme.accent, width: 1) : null,
              ),
              child: Text(
                mode.displayName(widget.language),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isSelected ? AppTheme.accent : Colors.white70,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildHandednessSelector(bool isFrench) {
    return Row(
      children: Handedness.values.map((hand) {
        final isSelected = _selectedHandedness == hand;
        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _selectedHandedness = hand),
            child: Container(
              margin: EdgeInsets.only(right: hand != Handedness.unknown ? 6 : 0),
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.accent.withOpacity(0.3) : Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(6),
                border: isSelected ? Border.all(color: AppTheme.accent, width: 1) : null,
              ),
              child: Text(
                hand.displayName(widget.language),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isSelected ? AppTheme.accent : Colors.white70,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
