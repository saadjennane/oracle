import 'package:flutter/material.dart';
import '../theme/theme_variants.dart';
import '../theme/app_theme.dart';

/// Visual comparator for candidate themes. For each variant in
/// [kThemeCandidates], renders a high-fidelity mock of the home screen
/// AND a mock of the settings screen with the variant's colors,
/// typography, and radii applied. The user picks a direction before the
/// real `AppTheme` refactor.
class ThemePreviewScreen extends StatelessWidget {
  const ThemePreviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: kThemeCandidates.length,
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          title: const Text('Theme preview'),
          backgroundColor: AppTheme.background,
          foregroundColor: AppTheme.textPrimary,
          bottom: TabBar(
            isScrollable: true,
            labelColor: AppTheme.primary,
            unselectedLabelColor: AppTheme.textSecondary,
            indicatorColor: AppTheme.primary,
            tabs: kThemeCandidates
                .map((v) => Tab(text: v.name))
                .toList(),
          ),
        ),
        body: TabBarView(
          children: kThemeCandidates
              .map((v) => _VariantPreview(variant: v))
              .toList(),
        ),
      ),
    );
  }
}

/// Stacks the two mockups (Home + Settings) for a single variant. Wrapped
/// in a SingleChildScrollView so the user can scroll between them.
class _VariantPreview extends StatelessWidget {
  final ThemeVariant variant;
  const _VariantPreview({required this.variant});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.background,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        child: Column(
          children: [
            _MockLabel(text: 'Home screen'),
            _HomeMock(variant: variant),
            const SizedBox(height: 28),
            _MockLabel(text: 'Settings screen'),
            _SettingsMock(variant: variant),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _MockLabel extends StatelessWidget {
  final String text;
  const _MockLabel({required this.text});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Row(children: [
        Text(
          text.toUpperCase(),
          style: TextStyle(
            fontSize: 10,
            letterSpacing: 2.5,
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(height: 1, color: AppTheme.border),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// SHARED PRIMITIVES — themed widgets that read tokens from a ThemeVariant
// ─────────────────────────────────────────────────────────────────────

class _MockFrame extends StatelessWidget {
  final ThemeVariant variant;
  final Widget child;
  const _MockFrame({required this.variant, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: variant.background,
        border: Border.all(color: variant.border),
        borderRadius: BorderRadius.circular(20),
      ),
      clipBehavior: Clip.hardEdge,
      child: child,
    );
  }
}

TextStyle _displayStyle(ThemeVariant v,
    {required double size, Color? color, FontWeight? weight}) {
  return TextStyle(
    fontFamily: v.displayFont == 'serif' ? 'serif' : null,
    fontWeight: weight ?? v.displayWeight,
    fontSize: size,
    letterSpacing: v.displayLetterSpacing,
    color: color ?? v.text,
    height: 1.1,
  );
}

String _fmt(ThemeVariant v, String text) =>
    v.displayUppercase ? text.toUpperCase() : text;

// ─────────────────────────────────────────────────────────────────────
// HOME MOCK
// ─────────────────────────────────────────────────────────────────────

class _HomeMock extends StatelessWidget {
  final ThemeVariant variant;
  const _HomeMock({required this.variant});

  @override
  Widget build(BuildContext context) {
    return _MockFrame(
      variant: variant,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // App bar
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 14),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: variant.border)),
            ),
            child: Row(
              children: [
                Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    color: variant.accent.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  alignment: Alignment.center,
                  child: Text('O',
                      style: _displayStyle(variant, size: 18, color: variant.accent)),
                ),
                const SizedBox(width: 10),
                Text(
                  _fmt(variant, 'Oracle.'),
                  style: _displayStyle(variant, size: 22),
                ),
                const Spacer(),
                _MockIcon(variant: variant, icon: Icons.history),
                _MockIcon(variant: variant, icon: Icons.settings_outlined),
              ],
            ),
          ),

          // Remote Input toggle bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 14),
              decoration: BoxDecoration(
                color: variant.accent,
                borderRadius: BorderRadius.circular(variant.cardRadius / 2 + 4),
              ),
              child: Row(
                children: [
                  Icon(Icons.wifi_tethering, size: 16, color: variant.ctaText),
                  const SizedBox(width: 8),
                  Text(
                    _fmt(variant, 'Remote Input · ON'),
                    style: TextStyle(
                      color: variant.ctaText,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: variant.displayUppercase ? 1.5 : 0,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Routines eyebrow
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Text(
              _fmt(variant, 'ROUTINES'),
              style: TextStyle(
                fontSize: 10,
                letterSpacing: variant.eyebrowLetterSpacing,
                color: variant.muted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          _MockPresetCard(
            variant: variant,
            tag: 'ROUTINE',
            name: 'Cocktail party set',
            subtitle: 'Knife/Fork/Spoon → RPS → Birthday',
            tagColor: variant.muted,
          ),

          // Presets eyebrow
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
            child: Text(
              _fmt(variant, 'PRESETS'),
              style: TextStyle(
                fontSize: 10,
                letterSpacing: variant.eyebrowLetterSpacing,
                color: variant.muted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          _MockPresetCard(
            variant: variant,
            tag: 'DUEL',
            name: 'RPS · Best of 3',
            subtitle: '3 rounds · Volume input',
          ),
          _MockPresetCard(
            variant: variant,
            tag: 'CHOICES',
            name: 'Which Hand?',
            subtitle: '2 options · Tap zones',
          ),
          _MockPresetCard(
            variant: variant,
            tag: 'FREE WILL',
            name: 'Knife · Fork · Spoon',
            subtitle: 'Change of mind enabled',
          ),
          _MockPresetCard(
            variant: variant,
            tag: 'NUMBER',
            name: 'Birthday predict',
            subtitle: 'Audio + GPT-4o',
          ),

          // Add button
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 13),
              decoration: BoxDecoration(
                border: Border.all(color: variant.border, width: 1.2),
                borderRadius: BorderRadius.circular(variant.cardRadius),
              ),
              alignment: Alignment.center,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add, size: 18, color: variant.muted),
                  const SizedBox(width: 8),
                  Text(
                    _fmt(variant, 'Add a preset'),
                    style: TextStyle(
                      fontSize: 13,
                      color: variant.muted,
                      fontWeight: FontWeight.w500,
                      letterSpacing: variant.displayUppercase ? 1 : 0,
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

class _MockIcon extends StatelessWidget {
  final ThemeVariant variant;
  final IconData icon;
  const _MockIcon({required this.variant, required this.icon});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Icon(icon, size: 20, color: variant.muted),
    );
  }
}

class _MockPresetCard extends StatelessWidget {
  final ThemeVariant variant;
  final String tag;
  final String name;
  final String subtitle;
  final Color? tagColor;
  const _MockPresetCard({
    required this.variant,
    required this.tag,
    required this.name,
    required this.subtitle,
    this.tagColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: variant.surface,
          border: Border.all(color: variant.border),
          borderRadius: BorderRadius.circular(variant.cardRadius),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: (tagColor ?? variant.accent).withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(
                tag,
                style: TextStyle(
                  fontSize: 9,
                  letterSpacing: variant.eyebrowLetterSpacing,
                  color: tagColor ?? variant.accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 14,
                      color: variant.text,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: variant.muted,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.play_arrow, size: 20, color: variant.accent),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// SETTINGS MOCK
// ─────────────────────────────────────────────────────────────────────

class _SettingsMock extends StatelessWidget {
  final ThemeVariant variant;
  const _SettingsMock({required this.variant});

  @override
  Widget build(BuildContext context) {
    return _MockFrame(
      variant: variant,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // App bar
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 14),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: variant.border)),
            ),
            child: Row(children: [
              Icon(Icons.arrow_back, size: 20, color: variant.muted),
              const SizedBox(width: 12),
              Text(_fmt(variant, 'Settings'),
                  style: _displayStyle(variant, size: 22)),
            ]),
          ),

          _SettingsSection(variant: variant, title: 'GENERAL', children: [
            _SettingsRow(variant: variant, icon: Icons.language, label: 'Language', value: 'French'),
            _SettingsRow(variant: variant, icon: Icons.record_voice_over, label: 'Default narrator voice', value: 'First-person'),
          ]),

          _SettingsSection(variant: variant, title: 'DISPLAY', children: [
            _SettingsRow(variant: variant, icon: Icons.palette_outlined, label: 'Theme', value: variant.name, valueColor: variant.accent),
            _SettingsToggleRow(variant: variant, icon: Icons.touch_app_outlined, label: 'Haptic feedback', on: true),
            _SettingsToggleRow(variant: variant, icon: Icons.visibility_outlined, label: 'Visual feedback', on: true),
          ]),

          _SettingsSection(variant: variant, title: 'REMOTE INPUT', children: [
            _SettingsRow(variant: variant, icon: Icons.image_outlined, label: 'Default decoy', value: 'IMDb · Tom Cruise'),
            _SettingsToggleRow(variant: variant, icon: Icons.adjust, label: 'Indicator dot', on: false),
          ]),

          _SettingsSection(variant: variant, title: 'INTEGRATIONS', children: [
            _SettingsRow(variant: variant, icon: Icons.api, label: 'Inject', value: 'Connected', valueColor: variant.accent),
            _SettingsRow(variant: variant, icon: Icons.music_note_outlined, label: 'Elips', value: 'Connected', valueColor: variant.accent),
            _SettingsRow(variant: variant, icon: Icons.emoji_events_outlined, label: 'High Score', value: '—'),
          ]),

          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final ThemeVariant variant;
  final String title;
  final List<Widget> children;
  const _SettingsSection({required this.variant, required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
          child: Text(
            _fmt(variant, title),
            style: TextStyle(
              fontSize: 10,
              letterSpacing: variant.eyebrowLetterSpacing,
              color: variant.muted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: variant.surface,
            border: Border.all(color: variant.border),
            borderRadius: BorderRadius.circular(variant.cardRadius),
          ),
          clipBehavior: Clip.hardEdge,
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final ThemeVariant variant;
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  const _SettingsRow({
    required this.variant,
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: variant.border.withValues(alpha: 0.4))),
      ),
      child: Row(children: [
        Icon(icon, size: 18, color: variant.muted),
        const SizedBox(width: 12),
        Expanded(
          child: Text(label,
              style: TextStyle(
                fontSize: 14,
                color: variant.text,
                fontWeight: FontWeight.w500,
              )),
        ),
        Text(value,
            style: TextStyle(
              fontSize: 13,
              color: valueColor ?? variant.muted,
              fontWeight: valueColor != null ? FontWeight.w600 : FontWeight.normal,
            )),
        const SizedBox(width: 6),
        Icon(Icons.chevron_right, size: 18, color: variant.muted),
      ]),
    );
  }
}

class _SettingsToggleRow extends StatelessWidget {
  final ThemeVariant variant;
  final IconData icon;
  final String label;
  final bool on;
  const _SettingsToggleRow({
    required this.variant,
    required this.icon,
    required this.label,
    required this.on,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: variant.border.withValues(alpha: 0.4))),
      ),
      child: Row(children: [
        Icon(icon, size: 18, color: variant.muted),
        const SizedBox(width: 12),
        Expanded(
          child: Text(label,
              style: TextStyle(
                fontSize: 14,
                color: variant.text,
                fontWeight: FontWeight.w500,
              )),
        ),
        // Faux iOS toggle
        Container(
          width: 38, height: 22,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: on ? variant.accent : variant.border,
            borderRadius: BorderRadius.circular(11),
          ),
          alignment: on ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 18, height: 18,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ]),
    );
  }
}
