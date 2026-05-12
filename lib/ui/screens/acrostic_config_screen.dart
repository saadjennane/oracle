import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../utils/acrostic_provider.dart';
import '../theme/app_theme.dart';

class AcrosticConfigScreen extends StatefulWidget {
  const AcrosticConfigScreen({super.key});

  @override
  State<AcrosticConfigScreen> createState() => _AcrosticConfigScreenState();
}

class _AcrosticConfigScreenState extends State<AcrosticConfigScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showAddWordsDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Add Words', style: TextStyle(color: AppTheme.textPrimary, fontSize: 16)),
        content: SizedBox(
          width: double.maxFinite,
          child: TextField(
            controller: controller,
            maxLines: 10,
            autofocus: true,
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'One word per line...',
              hintStyle: TextStyle(color: AppTheme.textTertiary),
              filled: true, fillColor: AppTheme.background,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final words = controller.text
                  .split('\n')
                  .map((w) => w.trim())
                  .where((w) => w.isNotEmpty)
                  .toList();
              if (words.isNotEmpty) {
                context.read<AcrosticProvider>().addWords(words);
              }
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showLanguageInfoDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Adding a Language', style: TextStyle(color: AppTheme.textPrimary, fontSize: 16)),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('1. Tap the + button next to the language tabs to create a new language (e.g. "en" for English, "es" for Spanish).',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.5)),
              SizedBox(height: 12),
              Text('2. The new language starts with an empty word bank. Add words using the + button in the top right (one word per line).',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.5)),
              SizedBox(height: 12),
              Text('3. Aim for 300-500 common words with good coverage of all 26 letters at positions 1-6.',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.5)),
              SizedBox(height: 12),
              Text('4. Use the position views to check coverage. Green = ready, orange = needs more words.',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.5)),
              SizedBox(height: 12),
              Text('Tip: You can generate a word list using ChatGPT with the prompt:\n"Generate 500 common [language] words for an acrostic system, one per line, covering all letters at positions 1-6"',
                  style: TextStyle(color: AppTheme.textTertiary, fontSize: 12, fontStyle: FontStyle.italic, height: 1.5)),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
        ],
      ),
    );
  }

  void _showAddLanguageDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Add Language', style: TextStyle(color: AppTheme.textPrimary, fontSize: 16)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Language code (e.g. en, es, de)',
            hintStyle: TextStyle(color: AppTheme.textTertiary),
            filled: true, fillColor: AppTheme.background,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              context.read<AcrosticProvider>().addLanguage(controller.text);
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AcrosticProvider>(
      builder: (context, provider, _) {
        final words = provider.currentWords;
        final filteredWords = _searchQuery.isEmpty
            ? words
            : words.where((w) => w.contains(_searchQuery.toLowerCase())).toList();

        return Scaffold(
          backgroundColor: AppTheme.background,
          appBar: AppBar(
            backgroundColor: AppTheme.background,
            title: Text('Acrostic Bank (${words.length} words)'),
            actions: [
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: _showAddWordsDialog,
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Language selector
              Row(
                children: [
                  ...provider.languages.map((lang) {
                    final isSelected = lang == provider.currentLanguage;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () => provider.setCurrentLanguage(lang),
                        onLongPress: provider.languages.length > 1 ? () {
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              backgroundColor: AppTheme.surface,
                              title: Text('Remove "$lang"?', style: const TextStyle(color: AppTheme.textPrimary)),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                                TextButton(
                                  onPressed: () { provider.removeLanguage(lang); Navigator.pop(ctx); },
                                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                                  child: const Text('Remove'),
                                ),
                              ],
                            ),
                          );
                        } : null,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? AppTheme.primary : AppTheme.surface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: isSelected ? AppTheme.primary : AppTheme.border),
                          ),
                          child: Text(
                            lang.toUpperCase(),
                            style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14,
                              color: isSelected ? Colors.white : AppTheme.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                  GestureDetector(
                    onTap: _showAddLanguageDialog,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.border, style: BorderStyle.solid),
                      ),
                      child: const Icon(Icons.add, size: 18, color: AppTheme.textSecondary),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _showLanguageInfoDialog(),
                    child: const Icon(Icons.info_outline, size: 18, color: AppTheme.textTertiary),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Legend
              Row(
                children: [
                  Icon(Icons.check_circle, size: 12, color: Colors.green),
                  const SizedBox(width: 3),
                  Text('4+', style: TextStyle(fontSize: 11, color: AppTheme.textTertiary)),
                  const SizedBox(width: 12),
                  Icon(Icons.warning_amber, size: 12, color: Colors.orange),
                  const SizedBox(width: 3),
                  Text('1-3', style: TextStyle(fontSize: 11, color: AppTheme.textTertiary)),
                  const SizedBox(width: 12),
                  Icon(Icons.error, size: 12, color: Colors.red),
                  const SizedBox(width: 3),
                  Text('0', style: TextStyle(fontSize: 11, color: AppTheme.textTertiary)),
                  const SizedBox(width: 6),
                  Text('words per letter', style: TextStyle(fontSize: 11, color: AppTheme.textTertiary)),
                ],
              ),

              const SizedBox(height: 12),

              // Position coverage overview
              ...List.generate(6, (pos) {
                final covered = provider.coveredLettersCount(pos);
                final allCovered = covered == 26;
                return _PositionSection(position: pos, provider: provider, allCovered: allCovered, coveredCount: covered);
              }),

              const SizedBox(height: 16),

              // All words section
              _AllWordsSection(
                words: filteredWords,
                searchController: _searchController,
                onSearchChanged: (q) => setState(() => _searchQuery = q),
                onRemove: (word) => provider.removeWord(word),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ============= POSITION SECTION =============

class _PositionSection extends StatefulWidget {
  final int position; // 0-based
  final AcrosticProvider provider;
  final bool allCovered;
  final int coveredCount;

  const _PositionSection({
    required this.position,
    required this.provider,
    required this.allCovered,
    required this.coveredCount,
  });

  @override
  State<_PositionSection> createState() => _PositionSectionState();
}

class _PositionSectionState extends State<_PositionSection> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: () => setState(() => _isExpanded = !_isExpanded),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            margin: const EdgeInsets.only(bottom: 2),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(_isExpanded ? Icons.expand_less : Icons.expand_more, size: 18, color: AppTheme.textSecondary),
                const SizedBox(width: 8),
                Text('Position ${widget.position + 1}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppTheme.textPrimary)),
                const Spacer(),
                Builder(builder: (_) {
                  final coverage = widget.provider.getCoverageForPosition(widget.position);
                  final hasZero = coverage.values.any((c) => c == 0);
                  final hasWarning = coverage.values.any((c) => c > 0 && c <= 3);
                  final Color color;
                  final IconData icon;
                  if (hasZero) {
                    color = Colors.red;
                    icon = Icons.error;
                  } else if (hasWarning) {
                    color = Colors.orange;
                    icon = Icons.warning_amber;
                  } else {
                    color = Colors.green;
                    icon = Icons.check_circle;
                  }
                  return Row(children: [
                    Text('${widget.coveredCount}/26', style: TextStyle(fontSize: 12, color: color)),
                    const SizedBox(width: 4),
                    Icon(icon, size: 14, color: color),
                  ]);
                }),
              ],
            ),
          ),
        ),
        if (_isExpanded)
          Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 8),
            child: Column(
              children: List.generate(26, (i) {
                final letter = String.fromCharCode(97 + i);
                return _LetterSection(letter: letter, position: widget.position, provider: widget.provider);
              }),
            ),
          ),
      ],
    );
  }
}

// ============= LETTER SECTION =============

class _LetterSection extends StatefulWidget {
  final String letter;
  final int position; // 0-based
  final AcrosticProvider provider;

  const _LetterSection({required this.letter, required this.position, required this.provider});

  @override
  State<_LetterSection> createState() => _LetterSectionState();
}

class _LetterSectionState extends State<_LetterSection> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final words = widget.provider.getWordsForLetterAtPosition(widget.letter, widget.position);
    final count = words.length;
    final statusIcon = count > 3 ? Icons.check_circle : count > 0 ? Icons.warning_amber : Icons.error;
    final statusColor = count > 3 ? Colors.green : count > 0 ? Colors.orange : Colors.red;

    return Column(
      children: [
        GestureDetector(
          onTap: () => setState(() => _isExpanded = !_isExpanded),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            margin: const EdgeInsets.only(bottom: 1),
            decoration: BoxDecoration(
              color: _isExpanded ? AppTheme.surface : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 24,
                  child: Text(widget.letter.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textPrimary)),
                ),
                Text('$count', style: TextStyle(fontSize: 12, color: statusColor)),
                const SizedBox(width: 4),
                Icon(statusIcon, size: 12, color: statusColor),
                const Spacer(),
                if (_isExpanded) Icon(Icons.expand_less, size: 14, color: AppTheme.textTertiary)
                else Icon(Icons.expand_more, size: 14, color: AppTheme.textTertiary),
              ],
            ),
          ),
        ),
        if (_isExpanded)
          Padding(
            padding: const EdgeInsets.only(left: 24, bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...words.map((word) {
                  final isFav = widget.provider.isFavorite(word, widget.letter, widget.position);
                  return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: GestureDetector(
                    onDoubleTap: () {
                      if (isFav) {
                        widget.provider.setFavorite(widget.letter, widget.position, null);
                      } else {
                        widget.provider.setFavorite(widget.letter, widget.position, word);
                      }
                    },
                    child: Row(
                    children: [
                      if (isFav)
                        const Padding(
                          padding: EdgeInsets.only(right: 4),
                          child: Icon(Icons.star, size: 12, color: Colors.amber),
                        ),
                      // Highlight the letter at position
                      Expanded(
                        child: RichText(
                          text: TextSpan(
                            children: [
                              if (widget.position > 0)
                                TextSpan(text: word.substring(0, widget.position), style: TextStyle(fontSize: 12, color: isFav ? AppTheme.textPrimary : AppTheme.textSecondary, fontWeight: isFav ? FontWeight.w600 : FontWeight.normal)),
                              TextSpan(text: word[widget.position], style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isFav ? Colors.amber : AppTheme.primary)),
                              if (widget.position < word.length - 1)
                                TextSpan(text: word.substring(widget.position + 1), style: TextStyle(fontSize: 12, color: isFav ? AppTheme.textPrimary : AppTheme.textSecondary, fontWeight: isFav ? FontWeight.w600 : FontWeight.normal)),
                            ],
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => widget.provider.removeWord(word),
                        child: const Icon(Icons.close, size: 14, color: AppTheme.textTertiary),
                      ),
                    ],
                  )),
                );
                }),
                // Add word button
                GestureDetector(
                  onTap: () {
                    final controller = TextEditingController();
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: AppTheme.surface,
                        title: Text('Add word (${widget.letter.toUpperCase()} at pos ${widget.position + 1})',
                            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14)),
                        content: TextField(
                          controller: controller,
                          autofocus: true,
                          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                          decoration: InputDecoration(
                            hintText: 'Word...',
                            filled: true, fillColor: AppTheme.background,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                        ),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                          ElevatedButton(
                            onPressed: () {
                              widget.provider.addWords([controller.text]);
                              Navigator.pop(ctx);
                            },
                            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
                            child: const Text('Add'),
                          ),
                        ],
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Icon(Icons.add_circle_outline, size: 14, color: AppTheme.primary),
                        const SizedBox(width: 4),
                        Text('Add word', style: TextStyle(fontSize: 11, color: AppTheme.primary)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ============= ALL WORDS SECTION =============

class _AllWordsSection extends StatefulWidget {
  final List<String> words;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onRemove;

  const _AllWordsSection({
    required this.words,
    required this.searchController,
    required this.onSearchChanged,
    required this.onRemove,
  });

  @override
  State<_AllWordsSection> createState() => _AllWordsSectionState();
}

class _AllWordsSectionState extends State<_AllWordsSection> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: () => setState(() => _isExpanded = !_isExpanded),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(_isExpanded ? Icons.expand_less : Icons.expand_more, size: 18, color: AppTheme.textSecondary),
                const SizedBox(width: 8),
                Text('All Words (${widget.words.length})', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppTheme.textPrimary)),
              ],
            ),
          ),
        ),
        if (_isExpanded) ...[
          const SizedBox(height: 8),
          TextField(
            controller: widget.searchController,
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Search...',
              hintStyle: TextStyle(color: AppTheme.textTertiary),
              prefixIcon: const Icon(Icons.search, size: 18),
              filled: true, fillColor: AppTheme.surface,
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            onChanged: widget.onSearchChanged,
          ),
          const SizedBox(height: 8),
          ...widget.words.map((word) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 1),
            child: Row(
              children: [
                Expanded(child: Text(word, style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary))),
                GestureDetector(
                  onTap: () => widget.onRemove(word),
                  child: const Icon(Icons.close, size: 14, color: AppTheme.textTertiary),
                ),
              ],
            ),
          )),
        ],
      ],
    );
  }
}
