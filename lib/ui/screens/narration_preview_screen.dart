import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import '../../models/models.dart';
import '../../engine/engine.dart';
import '../../utils/game_provider.dart';
import '../../utils/settings_provider.dart';
import '../theme/app_theme.dart';

class NarrationPreviewScreen extends StatefulWidget {
  const NarrationPreviewScreen({super.key});

  @override
  State<NarrationPreviewScreen> createState() => _NarrationPreviewScreenState();
}

class _NarrationPreviewScreenState extends State<NarrationPreviewScreen> {
  bool _showDebugJson = false;

  /// Show the debug panel bottom sheet
  void _showDebugPanel(BuildContext context, GameProvider provider) {
    final trace = provider.lastNarrativeTrace;
    if (trace == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No trace data available')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => _DebugPanelContent(
          trace: trace,
          scrollController: scrollController,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<GameProvider>(
      builder: (context, provider, child) {
        final narrative = provider.generatedNarrative;
        if (narrative == null) {
          return Scaffold(
            backgroundColor: AppTheme.background,
            body: const Center(
              child: CircularProgressIndicator(color: AppTheme.primary),
            ),
          );
        }

        final settings = context.watch<SettingsProvider>();

        return Scaffold(
          backgroundColor: AppTheme.background,
          appBar: AppBar(
            backgroundColor: AppTheme.background,
            title: const Text('Preview'),
            automaticallyImplyLeading: false,
            actions: [
              // Debug panel button (only if debugPanelEnabled)
              if (settings.debugPanelEnabled)
                IconButton(
                  icon: const Icon(
                    Icons.bug_report,
                    color: AppTheme.accent,
                  ),
                  tooltip: 'Debug Panel',
                  onPressed: () => _showDebugPanel(context, provider),
                ),
              IconButton(
                icon: Icon(
                  _showDebugJson ? Icons.text_snippet : Icons.code,
                  color: AppTheme.textSecondary,
                ),
                onPressed: () {
                  setState(() => _showDebugJson = !_showDebugJson);
                },
              ),
            ],
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Content area
                  Expanded(
                    child: _showDebugJson
                        ? _DebugJsonView(provider: provider)
                        : _NarrativePreview(narrative: narrative),
                  ),
                  const SizedBox(height: 20),

                  // Buttons
                  Row(
                    children: [
                      // Back button
                      OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Icon(Icons.arrow_back, size: 18),
                      ),
                      const SizedBox(width: 12),
                      // Reveal button
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: () async {
                            await provider.confirmAndSave();
                            if (context.mounted) {
                              Navigator.pushReplacementNamed(context, '/reveal');
                            }
                          },
                          child: const Text('Reveal in Note'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _NarrativePreview extends StatelessWidget {
  final String narrative;

  const _NarrativePreview({required this.narrative});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: SingleChildScrollView(
        child: Text(
          narrative,
          style: const TextStyle(
            fontSize: 15,
            height: 1.6,
            color: AppTheme.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _DebugJsonView extends StatelessWidget {
  final GameProvider provider;

  const _DebugJsonView({required this.provider});

  @override
  Widget build(BuildContext context) {
    final session = provider.currentSession;
    if (session == null) {
      return const Center(child: Text('No session data'));
    }

    final jsonString = const JsonEncoder.withIndent('  ').convert(session.toJson());

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: SingleChildScrollView(
        child: Text(
          jsonString,
          style: const TextStyle(
            fontSize: 12,
            fontFamily: 'monospace',
            color: AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}

/// Debug panel content widget
class _DebugPanelContent extends StatelessWidget {
  final NarrativeTrace trace;
  final ScrollController scrollController;

  const _DebugPanelContent({
    required this.trace,
    required this.scrollController,
  });

  void _copyToClipboard(BuildContext context, String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            border: Border(
              bottom: BorderSide(color: AppTheme.divider, width: 1),
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.bug_report, color: AppTheme.accent, size: 24),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Debug / Narrative Trace',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: AppTheme.textSecondary),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),

        // Copy buttons row
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(
            color: AppTheme.background,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Primary: Copy All Logs
              ElevatedButton.icon(
                onPressed: () => _copyToClipboard(context, trace.toTraceString(), 'Logs'),
                icon: const Icon(Icons.copy_all, size: 18),
                label: const Text('Copy All Logs'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
              const SizedBox(height: 8),
              // Secondary: Section buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _copyToClipboard(
                        context,
                        trace.toInputsString(),
                        'Inputs',
                      ),
                      child: const Text('Copy Inputs', style: TextStyle(fontSize: 12)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _copyToClipboard(
                        context,
                        trace.toComputedString(),
                        'Computed',
                      ),
                      child: const Text('Copy Computed', style: TextStyle(fontSize: 12)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _copyToClipboard(
                        context,
                        trace.toOutputString(),
                        'Output',
                      ),
                      child: const Text('Copy Output', style: TextStyle(fontSize: 12)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Trace content (scrollable)
        Expanded(
          child: Container(
            color: AppTheme.background,
            child: SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E), // Dark code background
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SelectableText(
                  trace.toTraceString(),
                  style: const TextStyle(
                    fontSize: 11,
                    fontFamily: 'Menlo',
                    height: 1.4,
                    color: Color(0xFFD4D4D4), // Light text on dark
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
