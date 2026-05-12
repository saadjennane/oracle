import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/models.dart';
import '../../utils/game_provider.dart';
import '../../utils/settings_provider.dart';
import '../../utils/reveal_provider.dart';
import '../theme/note_theme.dart';
import '../widgets/quick_cues_panel.dart';

class FakeNoteScreen extends StatefulWidget {
  const FakeNoteScreen({super.key});

  @override
  State<FakeNoteScreen> createState() => _FakeNoteScreenState();
}

class _FakeNoteScreenState extends State<FakeNoteScreen> {
  bool _showQuickCues = false;
  LiveCues _currentCues = const LiveCues();

  // For subtle indicator animation
  bool _showIndicator = false;

  bool _immersiveApplied = false;

  /// Hides the iOS status bar / home indicator overlay so a custom-background
  /// screenshot reads clean (no doubled clock / battery on top). Idempotent.
  void _enterImmersiveOnce() {
    if (_immersiveApplied) return;
    _immersiveApplied = true;
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    if (_immersiveApplied) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    super.dispose();
  }

  void _toggleQuickCues() {
    setState(() {
      _showQuickCues = !_showQuickCues;
      if (_showQuickCues) {
        // Show subtle indicator briefly
        _showIndicator = true;
        Future.delayed(const Duration(milliseconds: 600), () {
          if (mounted) {
            setState(() => _showIndicator = false);
          }
        });
      }
    });
  }

  void _applyQuickCues(LiveCues cues) {
    final gameProvider = context.read<GameProvider>();
    _currentCues = cues;

    if (!cues.isEmpty) {
      gameProvider.regenerateWithCues(cues);
    }

    setState(() {
      _showQuickCues = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer3<GameProvider, SettingsProvider, RevealProvider>(
      builder: (context, gameProvider, settingsProvider, revealProvider, child) {
        final narrative = gameProvider.generatedNarrative ?? '';
        final predictionDate = DateTime.now();

        // Determine which background to use based on reveal theme setting
        final isDarkMode = settingsProvider.revealIsDarkMode;

        // Get session language for QuickCuesPanel
        final language = gameProvider.currentSession?.language ?? Language.english;

        // Check if we have a custom background
        final backgroundPath = revealProvider.getBackgroundPath(isDarkMode: isDarkMode);
        final hasCustomBackground = backgroundPath != null;

        if (hasCustomBackground) {
          // Hide the iOS system status/home bar so the screenshot reads clean.
          WidgetsBinding.instance.addPostFrameCallback((_) => _enterImmersiveOnce());
          return _buildCustomBackgroundScreen(
            context,
            gameProvider,
            settingsProvider,
            revealProvider,
            narrative,
            backgroundPath,
            isDarkMode,
            language,
          );
        }

        // Default Notes-style UI
        return _buildDefaultScreen(
          context,
          gameProvider,
          settingsProvider,
          narrative,
          predictionDate,
          language,
        );
      },
    );
  }

  Widget _buildDefaultScreen(
    BuildContext context,
    GameProvider gameProvider,
    SettingsProvider settingsProvider,
    String narrative,
    DateTime predictionDate,
    Language language,
  ) {
    return Scaffold(
      backgroundColor: NoteTheme.noteBackground,
      body: Stack(
        children: [
          // Main content
          SafeArea(
            child: Column(
              children: [
                // iOS Notes-style toolbar with hidden hotspot
                _buildToolbar(context, gameProvider, settingsProvider),

                // Scrollable note content
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Timestamp
                        _buildTimestamp(predictionDate),
                        const SizedBox(height: 20),

                        // Main narrative content
                        _NoteBody(text: narrative),
                      ],
                    ),
                  ),
                ),

                // Action bar
                _buildActionBar(context, narrative, gameProvider),
              ],
            ),
          ),

          // Quick Cues Panel overlay
          if (_showQuickCues)
            Positioned(
              left: 0,
              right: 0,
              bottom: 100,
              child: QuickCuesPanel(
                initialCues: _currentCues,
                language: language,
                onClose: () => setState(() => _showQuickCues = false),
                onApply: _applyQuickCues,
              ),
            ),

          // Subtle indicator when panel opens
          if (_showIndicator)
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              right: 16,
              child: AnimatedOpacity(
                opacity: _showIndicator ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    '\u22ef',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCustomBackgroundScreen(
    BuildContext context,
    GameProvider gameProvider,
    SettingsProvider settingsProvider,
    RevealProvider revealProvider,
    String narrative,
    String backgroundPath,
    bool isDarkMode,
    Language language,
  ) {
    final layout = revealProvider.getTextLayout(isDarkMode: isDarkMode);
    final screenWidth = MediaQuery.of(context).size.width;
    final effectiveMaxWidth = layout.maxWidth > 0 ? layout.maxWidth : screenWidth - 48;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Background image - tappable to exit (but not when QuickCues is open)
          Positioned.fill(
            child: GestureDetector(
              onTap: _showQuickCues
                  ? null
                  : () {
                      gameProvider.reset();
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    },
              child: Image.file(
                File(backgroundPath),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: NoteTheme.noteBackground,
                  child: const Center(
                    child: Text('Background not found', style: TextStyle(color: Colors.grey)),
                  ),
                ),
              ),
            ),
          ),

          // Narrative text overlay at calibrated position
          Positioned(
            left: layout.offsetX,
            top: layout.offsetY,
            child: Container(
              constraints: BoxConstraints(maxWidth: effectiveMaxWidth),
              child: Text(
                narrative,
                style: TextStyle(
                  fontSize: layout.fontSize,
                  height: layout.lineHeight,
                  color: isDarkMode ? Colors.white : Colors.black,
                  fontFamily: '.SF Pro Text',
                ),
              ),
            ),
          ),

          // Hidden hotspot (top-right corner, 44x44)
          Positioned(
            top: MediaQuery.of(context).padding.top,
            right: 0,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onLongPress: _toggleQuickCues,
              child: Container(
                width: 44,
                height: 44,
                color: settingsProvider.testModeEnabled
                    ? Colors.red.withOpacity(0.2)
                    : Colors.transparent,
              ),
            ),
          ),

          // Quick Cues Panel overlay
          if (_showQuickCues)
            Positioned(
              left: 0,
              right: 0,
              bottom: 40,
              child: QuickCuesPanel(
                initialCues: _currentCues,
                language: language,
                onClose: () => setState(() => _showQuickCues = false),
                onApply: _applyQuickCues,
              ),
            ),

          // Subtle indicator when panel opens
          if (_showIndicator)
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              right: 16,
              child: AnimatedOpacity(
                opacity: _showIndicator ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    '\u22ef',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildToolbar(BuildContext context, GameProvider provider, SettingsProvider settingsProvider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: NoteTheme.headerDecoration,
      child: Stack(
        children: [
          Row(
            children: [
              // Back chevron (looks like Notes app)
              TextButton.icon(
                onPressed: () {
                  // Go back to home
                  provider.reset();
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                icon: const Icon(
                  Icons.chevron_left,
                  color: NoteTheme.headerIconColor,
                  size: 28,
                ),
                label: const Text(
                  'Notes',
                  style: TextStyle(
                    color: NoteTheme.headerIconColor,
                    fontSize: 17,
                  ),
                ),
              ),

              const Spacer(),

              // Folder indicator
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.folder_outlined, color: Colors.grey[600], size: 16),
                  const SizedBox(width: 4),
                  Text('Notes', style: NoteTheme.noteTimestamp),
                ],
              ),

              const Spacer(),

              // Share icon (for visual consistency with Notes)
              IconButton(
                icon: const Icon(Icons.share_outlined, size: 22),
                color: NoteTheme.headerIconColor,
                onPressed: () {},
              ),
            ],
          ),

          // Hidden hotspot for default UI (top-right of toolbar)
          Positioned(
            top: 0,
            right: 0,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onLongPress: _toggleQuickCues,
              child: Container(
                width: 44,
                height: 44,
                color: settingsProvider.testModeEnabled
                    ? Colors.red.withOpacity(0.2)
                    : Colors.transparent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimestamp(DateTime date) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          NoteTheme.formatDate(date),
          style: NoteTheme.noteTimestamp,
        ),
        const SizedBox(height: 2),
        Text(
          NoteTheme.formatTime(date),
          style: NoteTheme.noteTimestampSmall,
        ),
      ],
    );
  }

  Widget _buildActionBar(BuildContext context, String narrative, GameProvider provider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: NoteTheme.actionBarDecoration,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _ActionButton(
            icon: Icons.copy_outlined,
            label: 'Copy',
            onTap: () => _copyToClipboard(context, narrative),
          ),
          _ActionButton(
            icon: Icons.share_outlined,
            label: 'Share',
            onTap: () => _share(narrative),
          ),
          _ActionButton(
            icon: Icons.check_circle_outline,
            label: 'Done',
            onTap: () {
              provider.reset();
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
          ),
        ],
      ),
    );
  }

  void _copyToClipboard(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied to clipboard'),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _share(String text) {
    Share.share(text, subject: 'My Prediction');
  }
}

class _NoteBody extends StatelessWidget {
  final String text;

  const _NoteBody({required this.text});

  @override
  Widget build(BuildContext context) {
    // Split text into paragraphs
    final paragraphs = text.split('\n\n');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: paragraphs.asMap().entries.map((entry) {
        final isFirst = entry.key == 0;
        final paragraph = entry.value.trim();

        if (paragraph.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: EdgeInsets.only(top: isFirst ? 0 : 16),
          child: Text(
            paragraph,
            style: NoteTheme.noteBody,
          ),
        );
      }).toList(),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: NoteTheme.headerIconColor, size: 24),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }
}
