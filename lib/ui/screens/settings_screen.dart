import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../../models/models.dart';
import '../../utils/settings_provider.dart';
import '../../utils/haptic_helper.dart';
import '../../utils/history_provider.dart';
import '../../utils/reveal_provider.dart';
import '../../services/firebase_service.dart';
import '../../services/external_api_service.dart';
import '../../services/icloud_sync_service.dart';
import '../../services/cloudinary_service.dart';
import '../../data/local_storage.dart';
import '../theme/app_theme.dart';

void _showEditAssistantIdDialog(BuildContext context, SettingsProvider settings) {
  final controller = TextEditingController(text: settings.assistantId);
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppTheme.surface,
      title: const Text('Edit Web Input ID', style: TextStyle(color: AppTheme.textPrimary, fontSize: 16)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: controller,
            autofocus: true,
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontFamily: 'monospace'),
            decoration: InputDecoration(
              hintText: 'ex: sj, magic42, oracle',
              hintStyle: TextStyle(color: AppTheme.textTertiary),
              filled: true,
              fillColor: AppTheme.background,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Only lowercase letters, numbers, - and _',
            style: TextStyle(fontSize: 11, color: AppTheme.textTertiary),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () {
            settings.setAssistantId(controller.text);
            Navigator.pop(ctx);
          },
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
          child: const Text('Save'),
        ),
      ],
    ),
  );
}

void _launchFreeTextMode(BuildContext context, SettingsProvider settings) async {
  await FirebaseService.pushFreeTextMode(settings.assistantId);
  if (context.mounted) {
    Navigator.pushNamed(context, '/assistant-free-text');
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          title: const Text('Settings'),
          backgroundColor: AppTheme.surface,
          foregroundColor: AppTheme.textPrimary,
          elevation: 0,
          actions: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              child: TextButton.icon(
                onPressed: () => Navigator.pushNamed(context, '/tutorial'),
                icon: const Icon(Icons.menu_book_outlined, size: 18, color: AppTheme.primary),
                label: const Text(
                  'Tutorial',
                  style: TextStyle(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.4)),
                  ),
                ),
              ),
            ),
          ],
          bottom: TabBar(
            indicatorColor: AppTheme.primary,
            labelColor: AppTheme.primary,
            unselectedLabelColor: AppTheme.textSecondary,
            labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            tabs: const [
              Tab(icon: Icon(Icons.tune, size: 18), text: 'General'),
              Tab(icon: Icon(Icons.extension, size: 18), text: 'Integrations'),
              Tab(icon: Icon(Icons.palette, size: 18), text: 'Display'),
            ],
          ),
        ),
        body: Consumer<SettingsProvider>(
          builder: (context, settings, child) {
            return TabBarView(
              children: [
                _buildPerformanceTab(context, settings),
                _buildIntegrationsTab(context, settings),
                _buildDisplayTab(context, settings),
              ],
            );
          },
        ),
      ),
    );
  }

  // ============ TAB 1: GENERAL ============
  Widget _buildPerformanceTab(BuildContext context, SettingsProvider settings) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // App Language
        _buildSectionHeader('Language'),
        const SizedBox(height: 8),
        _buildSettingsCard([
          ListTile(
            title: const Text('App Language', style: TextStyle(color: AppTheme.textPrimary, fontSize: 14)),
            trailing: SegmentedButton<Language>(
              segments: const [
                ButtonSegment(value: Language.english, label: Text('EN', style: TextStyle(fontSize: 12))),
                ButtonSegment(value: Language.french, label: Text('FR', style: TextStyle(fontSize: 12))),
                ButtonSegment(value: Language.spanish, label: Text('ES', style: TextStyle(fontSize: 12))),
              ],
              selected: {settings.appLanguage},
              onSelectionChanged: (s) => settings.setAppLanguage(s.first),
              style: ButtonStyle(visualDensity: VisualDensity.compact),
            ),
          ),
        ]),
        const SizedBox(height: 24),

        // Stealth
        _buildSectionHeader('Stealth'),
        const SizedBox(height: 8),
        _buildSettingsCard([
          _buildSwitchTile(
            title: 'Test Mode',
            subtitle: 'Show live feedback on stealth screen',
            value: settings.testModeEnabled,
            onChanged: settings.setTestModeEnabled,
          ),
          Divider(height: 1, color: AppTheme.divider),
          _buildSwitchTile(
            title: 'Double Tap Fallback',
            subtitle: 'Enable double tap to start stealth input',
            value: settings.doubleTapFallbackEnabled,
            onChanged: settings.setDoubleTapFallbackEnabled,
          ),
          Divider(height: 1, color: AppTheme.divider),
          _buildSwitchTile(
            title: 'Visual Feedback',
            subtitle: 'Show subtle pixel indicators on stealth screens',
            value: settings.visualFeedbackEnabled,
            onChanged: settings.setVisualFeedbackEnabled,
          ),
        ]),
        const SizedBox(height: 24),

        // Haptic
        _buildSectionHeader('Haptic'),
        const SizedBox(height: 8),
        _buildSettingsCard([
          _buildSwitchTile(
            title: 'Haptic Feedback',
            subtitle: 'Vibrate on option selection',
            value: settings.hapticFeedback,
            onChanged: settings.setHapticFeedback,
          ),
          if (settings.hapticFeedback) ...[
            Divider(height: 1, color: AppTheme.divider),
            _buildDropdownTile<HapticIntensity>(
              title: 'Haptic Intensity',
              subtitle: 'Strength of vibration pulses',
              value: settings.hapticIntensity,
              items: HapticIntensity.values,
              itemLabel: (i) => i.displayName,
              onChanged: (i) {
                if (i != null) settings.setHapticIntensity(i);
              },
            ),
            Divider(height: 1, color: AppTheme.divider),
            ListTile(
              leading: const Icon(Icons.vibration, size: 18, color: AppTheme.accent),
              title: const Text('Test Haptic', style: TextStyle(color: AppTheme.textPrimary, fontSize: 14)),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(3, (i) => Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: ElevatedButton(
                    onPressed: () => HapticHelper.confirmOption(i, intensity: settings.hapticIntensity),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.surface,
                      foregroundColor: AppTheme.textPrimary,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      minimumSize: Size.zero,
                    ),
                    child: Text('${i + 1}', style: const TextStyle(fontSize: 12)),
                  ),
                )),
              ),
            ),
          ],
        ]),
        const SizedBox(height: 24),

        // Pre-Screen
        _buildSectionHeader('Performance Flow'),
        const SizedBox(height: 8),
        _buildSettingsCard([
          _buildSwitchTile(
            title: 'Pre-Screen',
            subtitle: 'Show a fake screen before stealth input',
            value: settings.preScreenEnabled,
            onChanged: settings.setPreScreenEnabled,
          ),
          if (settings.preScreenEnabled) ...[
            Divider(height: 1, color: AppTheme.divider),
            _buildSegmentTile(
              title: 'Screen Type',
              value: settings.preScreenType,
              options: const {'notes': 'Notes', 'homescreen': 'Homescreen'},
              onChanged: (v) => settings.setPreScreenType(v),
            ),
            if (settings.preScreenType == 'notes') ...[
              Divider(height: 1, color: AppTheme.divider),
              const _PreScreenNotesStatusTile(),
            ],
            if (settings.preScreenType == 'homescreen') ...[
              Divider(height: 1, color: AppTheme.divider),
              _HomescreenUploadTile(
                currentPath: settings.homescreenPath,
                onChanged: settings.setHomescreenPath,
              ),
            ],
          ],
        ]),
        const SizedBox(height: 24),

        // Bluetooth Remote
        _buildSectionHeader('Bluetooth Remote'),
        const SizedBox(height: 8),
        _buildSettingsCard([
          _buildSwitchTile(
            title: 'Enable Remote',
            subtitle: 'Use a Bluetooth remote for input',
            value: settings.remoteEnabled,
            onChanged: settings.setRemoteEnabled,
          ),
          if (settings.remoteEnabled)
            _RemoteKeyMapper(settings: settings),
        ]),
        const SizedBox(height: 24),

        _buildFooter(context),
      ],
    );
  }

  // ============ TAB 2: INTEGRATIONS ============
  Widget _buildIntegrationsTab(BuildContext context, SettingsProvider settings) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Web Input
        _buildSectionHeader('Web Input'),
        const SizedBox(height: 8),
        _buildSettingsCard([
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('Web Input ID', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.textPrimary)),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.edit, size: 16, color: AppTheme.textSecondary),
                      onPressed: () => _showEditAssistantIdDialog(context, settings),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: settings.assistantUrl));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('URL copied'), backgroundColor: AppTheme.surface),
                    );
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.background,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.withOpacity(0.5)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            settings.assistantUrl,
                            style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary, fontFamily: 'monospace'),
                          ),
                        ),
                        const Icon(Icons.copy, size: 14, color: AppTheme.textSecondary),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ]),
        const SizedBox(height: 12),

        // Preferred stealth input mode shown on the assistant webapp when a
        // preset is mirrored (Assistant Mode ON at runtime).
        _buildSettingsCard([
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Web Input Method',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.textPrimary)),
                const SizedBox(height: 2),
                const Text(
                  'How the webapp displays preset options when no decoy image is set.',
                  style: TextStyle(fontSize: 11, color: AppTheme.textTertiary, height: 1.3),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: _AssistantStealthChip(
                      selected: settings.assistantStealthMode == 'buttons',
                      icon: Icons.view_module,
                      label: 'Buttons',
                      onTap: () => settings.setAssistantStealthMode('buttons'),
                    )),
                    const SizedBox(width: 8),
                    Expanded(child: _AssistantStealthChip(
                      selected: settings.assistantStealthMode == 'blackscreen_tap',
                      icon: Icons.fingerprint,
                      label: 'Tap',
                      onTap: () => settings.setAssistantStealthMode('blackscreen_tap'),
                    )),
                    const SizedBox(width: 8),
                    Expanded(child: _AssistantStealthChip(
                      selected: settings.assistantStealthMode == 'blackscreen_swipe',
                      icon: Icons.swipe,
                      label: 'Swipe',
                      onTap: () => settings.setAssistantStealthMode('blackscreen_swipe'),
                    )),
                  ],
                ),
              ],
            ),
          ),
        ]),
        const SizedBox(height: 24),

        // OpenAI API Key
        _buildSectionHeader('AI / OpenAI'),
        const SizedBox(height: 8),
        _buildSettingsCard([
          _OpenAIKeyField(
            value: settings.openaiApiKey,
            onChanged: settings.setOpenaiApiKey,
          ),
          if (settings.hasOpenaiApiKey) ...[
            const Divider(height: 1, color: AppTheme.divider),
            _AITransformTest(apiKey: settings.openaiApiKey),
          ],
        ]),
        const SizedBox(height: 24),

        // External APIs
        _buildSectionHeader('External APIs'),
        const SizedBox(height: 8),
        _buildSettingsCard([
          _ApiCredentialField(label: 'Inject ID', hint: 'Secondary Inject ID', value: settings.injectId, onChanged: settings.setInjectId),
          if (settings.hasInjectConfig) ...[
            Divider(height: 1, color: AppTheme.divider),
            _ApiTestButton(
              label: 'Test Inject',
              onTest: () async {
                final data = await ExternalApiService.fetchInject(settings.injectId);
                return data != null ? 'value: ${data.value}\ncount: ${data.count}' : 'Error: no response';
              },
            ),
          ],
          const Divider(height: 1, color: AppTheme.divider),
          _ApiCredentialField(label: 'Elips ID', hint: 'Elips Page ID', value: settings.elipsId, onChanged: settings.setElipsId),
          const Divider(height: 1, color: AppTheme.divider),
          _ApiCredentialField(label: 'Elips API Key', hint: 'Elips API Key', value: settings.elipsApiKey, onChanged: settings.setElipsApiKey),
          if (settings.hasElipsConfig) ...[
            Divider(height: 1, color: AppTheme.divider),
            _ApiTestButton(
              label: 'Test Elips',
              onTest: () async {
                final data = await ExternalApiService.fetchElips(settings.elipsId, settings.elipsApiKey);
                return data != null ? 'artist: ${data.artist}\nsong: ${data.song}\nword: ${data.outputWord}' : 'Error: no response';
              },
            ),
          ],
          const Divider(height: 1, color: AppTheme.divider),
          _ApiCredentialField(label: 'HighScore API Key', hint: 'Sky Hop API Key', value: settings.highScoreApiKey, onChanged: settings.setHighScoreApiKey),
          if (settings.hasHighScoreConfig) ...[
            Divider(height: 1, color: AppTheme.divider),
            _ApiTestButton(
              label: 'Test HighScore',
              onTest: () async {
                final data = await ExternalApiService.fetchHighScore(settings.highScoreApiKey);
                return data != null ? 'score: ${data.effectiveScore}\nranking: ${data.leaderboardRank}' : 'Error: no response';
              },
            ),
          ],
        ]),
        const SizedBox(height: 24),

        // Decoy Mode — global settings. Templates themselves are managed
        // in the Display tab (Decoy Templates section).
        _buildSectionHeader('Decoy Mode'),
        const SizedBox(height: 8),
        _buildSettingsCard([
          _DecoyDefaultTemplatePicker(settings: settings),
          Divider(height: 1, color: AppTheme.divider),
          _ApiCredentialField(
            label: 'Redirect URL',
            hint: 'https://www.google.com',
            value: settings.decoyRedirectUrl,
            onChanged: settings.setDecoyRedirectUrl,
            obscure: false,
            stackedLabel: true,
          ),
          Divider(height: 1, color: AppTheme.divider),
          _buildSwitchTile(
            title: 'Show input indicator',
            subtitle: 'Discreet pulse on the decoy page after each input',
            value: settings.decoyShowIndicator,
            onChanged: settings.setDecoyShowIndicator,
          ),
        ]),
        const SizedBox(height: 24),

        // Acrostic Word Bank
        _buildSectionHeader('Acrostic'),
        const SizedBox(height: 8),
        _buildSettingsCard([
          _buildActionTile(
            title: 'Word Bank',
            subtitle: 'Configure acrostic words by language',
            icon: Icons.text_rotation_none,
            iconColor: AppTheme.primary,
            onTap: () => Navigator.pushNamed(context, '/acrostic-config'),
          ),
        ]),

        _buildFooter(context),
      ],
    );
  }

  // ============ TAB 3: DISPLAY ============
  Widget _buildDisplayTab(BuildContext context, SettingsProvider settings) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Auto-copy and shortcut name are configured per-preset in the
        // builder ("Copy & shortcut" section). The previous global toggle was
        // removed to avoid silent inheritance — what you set on a preset is
        // exactly what fires.

        // Reveal Background
        _buildSectionHeader('Reveal Background'),
        const SizedBox(height: 8),
        _buildSettingsCard([
          _buildDropdownTile<RevealThemeMode>(
            title: 'Theme',
            subtitle: 'Which screenshot to use for reveal',
            value: settings.revealThemeMode,
            items: RevealThemeMode.values,
            itemLabel: (mode) => mode.displayName,
            onChanged: (mode) {
              if (mode != null) settings.setRevealThemeMode(mode);
            },
          ),
        ]),
        const SizedBox(height: 12),
        _RevealBackgroundSection(),
        const SizedBox(height: 24),

        // Decoy Templates (managed here, used by Decoy Mode in Integrations)
        _buildSectionHeader('Decoy Templates'),
        const SizedBox(height: 8),
        _DecoyTemplatesSection(settings: settings),
        const SizedBox(height: 24),

        // Data & Sync
        _buildSectionHeader('Data & Sync'),
        const SizedBox(height: 8),
        _buildSettingsCard([
          _ICloudSyncTile(),
          const Divider(height: 1, color: AppTheme.divider),
          _buildActionTile(
            title: 'Clear History',
            subtitle: 'Delete all saved sessions',
            icon: Icons.delete_outline,
            iconColor: Colors.red,
            onTap: () => _showClearHistoryDialog(context),
          ),
        ]),

        _buildFooter(context),
      ],
    );
  }

  // ============ FOOTER (version + hidden admin reveal) ============
  Widget _buildFooter(BuildContext context) {
    return const _FooterWithAdminReveal();
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Colors.grey[500],
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildSettingsCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeColor: AppTheme.accent,
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentTile({
    required String title,
    required String value,
    required Map<String, String> options,
    required ValueChanged<String> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.textPrimary)),
          const SizedBox(height: 8),
          Row(
            children: options.entries.map((e) {
              final isSelected = value == e.key;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: e.key != options.keys.last ? 8 : 0),
                  child: GestureDetector(
                    onTap: () => onChanged(e.key),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected ? AppTheme.primary : AppTheme.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: isSelected ? AppTheme.primary : AppTheme.border),
                      ),
                      child: Center(
                        child: Text(e.value, style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600,
                          color: isSelected ? Colors.white : AppTheme.textSecondary)),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownTile<T>({
    required String title,
    required String subtitle,
    required T value,
    required List<T> items,
    required String Function(T) itemLabel,
    required ValueChanged<T?> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.background,
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<T>(
                value: value,
                dropdownColor: AppTheme.surface,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppTheme.accent,
                ),
                icon: const Icon(
                  Icons.keyboard_arrow_down,
                  color: AppTheme.accent,
                  size: 20,
                ),
                items: items.map((item) {
                  return DropdownMenuItem<T>(
                    value: item,
                    child: Text(itemLabel(item)),
                  );
                }).toList(),
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(icon, color: iconColor, size: 24),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: iconColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: Colors.grey[600],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoTile({
    required String title,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: AppTheme.textPrimary,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPocInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.accent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.accent.withOpacity(0.3),
        ),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.science_outlined,
            color: AppTheme.accent,
            size: 32,
          ),
          const SizedBox(height: 8),
          const Text(
            'ORACLE POC',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.accent,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Proof of Concept Build',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'This is a prototype for validating the core experience: '
            'discreet input flow, narrative generation, and Notes-style reveal.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  String _getFlutterVersion() {
    // In a real app, this would come from package_info_plus
    return '3.24+';
  }

  void _showClearHistoryDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text(
          'Clear All History?',
          style: TextStyle(color: AppTheme.textPrimary),
        ),
        content: const Text(
          'This will permanently delete all saved sessions. This action cannot be undone.',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              context.read<HistoryProvider>().clearHistory();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('History cleared'),
                  duration: Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }
}

class _RevealBackgroundSection extends StatelessWidget {
  final ImagePicker _picker = ImagePicker();

  _RevealBackgroundSection();

  Future<void> _pickNoteImage(BuildContext context, bool isLight) async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image == null || !context.mounted) return;

    final revealProvider = context.read<RevealProvider>();
    final file = File(image.path);

    if (isLight) {
      await revealProvider.setLightBackground(file);
    } else {
      await revealProvider.setDarkBackground(file);
    }
  }

  Future<void> _pickListImage(BuildContext context, bool isLight) async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image == null || !context.mounted) return;

    final revealProvider = context.read<RevealProvider>();
    final file = File(image.path);

    if (isLight) {
      await revealProvider.setLightListBackground(file);
    } else {
      await revealProvider.setDarkListBackground(file);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<RevealProvider>(
      builder: (context, revealProvider, child) {
        return Container(
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              // Section: Note Screenshots
              _SectionHeader(title: 'NOTE SCREEN'),
              _BackgroundTile(
                title: 'Light Mode',
                subtitle: revealProvider.hasLightBackground
                    ? 'Background set'
                    : 'No background',
                hasImage: revealProvider.hasLightBackground,
                imagePath: revealProvider.config.lightBackgroundPath,
                onUpload: () => _pickNoteImage(context, true),
                onDelete: revealProvider.hasLightBackground
                    ? () => revealProvider.removeLightBackground()
                    : null,
              ),
              Divider(height: 1, color: AppTheme.divider),
              _BackgroundTile(
                title: 'Dark Mode',
                subtitle: revealProvider.hasDarkBackground
                    ? 'Background set'
                    : 'No background',
                hasImage: revealProvider.hasDarkBackground,
                imagePath: revealProvider.config.darkBackgroundPath,
                onUpload: () => _pickNoteImage(context, false),
                onDelete: revealProvider.hasDarkBackground
                    ? () => revealProvider.removeDarkBackground()
                    : null,
              ),
              // Calibrate buttons for Note
              if (revealProvider.hasLightBackground) ...[
                Divider(height: 1, color: AppTheme.divider),
                _CalibrateTile(
                  title: 'Calibrate Light',
                  onTap: () => Navigator.pushNamed(
                    context,
                    '/reveal-calibration',
                    arguments: false,
                  ),
                ),
              ],
              if (revealProvider.hasDarkBackground) ...[
                Divider(height: 1, color: AppTheme.divider),
                _CalibrateTile(
                  title: 'Calibrate Dark',
                  onTap: () => Navigator.pushNamed(
                    context,
                    '/reveal-calibration',
                    arguments: true,
                  ),
                ),
              ],

              // Divider between sections
              Divider(height: 1, color: AppTheme.divider),

              // Section: List Screenshots
              _SectionHeader(title: 'LIST SCREEN (OPTIONAL)'),
              _BackgroundTile(
                title: 'Light Mode',
                subtitle: revealProvider.hasLightListBackground
                    ? 'Background set'
                    : 'No background',
                hasImage: revealProvider.hasLightListBackground,
                imagePath: revealProvider.config.lightListBackgroundPath,
                onUpload: () => _pickListImage(context, true),
                onDelete: revealProvider.hasLightListBackground
                    ? () => revealProvider.removeLightListBackground()
                    : null,
              ),
              Divider(height: 1, color: AppTheme.divider),
              _BackgroundTile(
                title: 'Dark Mode',
                subtitle: revealProvider.hasDarkListBackground
                    ? 'Background set'
                    : 'No background',
                hasImage: revealProvider.hasDarkListBackground,
                imagePath: revealProvider.config.darkListBackgroundPath,
                onUpload: () => _pickListImage(context, false),
                onDelete: revealProvider.hasDarkListBackground
                    ? () => revealProvider.removeDarkListBackground()
                    : null,
              ),

              // Divider between sections
              Divider(height: 1, color: AppTheme.divider),

              // Section: Calculator Screenshot
              _SectionHeader(title: 'CALCULATOR SCREEN'),
              _BackgroundTile(
                title: 'Calculator Screenshot',
                subtitle: revealProvider.hasCalculatorBackground
                    ? 'Screenshot set'
                    : 'No screenshot',
                hasImage: revealProvider.hasCalculatorBackground,
                imagePath: revealProvider.config.calculatorBackgroundPath,
                onUpload: () => _pickCalculatorImage(context),
                onDelete: revealProvider.hasCalculatorBackground
                    ? () => revealProvider.removeCalculatorBackground()
                    : null,
              ),
              if (revealProvider.hasCalculatorBackground) ...[
                Divider(height: 1, color: AppTheme.divider),
                ListTile(
                  leading: const Icon(Icons.edit, size: 18, color: AppTheme.primary),
                  title: const Text('Edit Screenshot', style: TextStyle(color: AppTheme.textPrimary, fontSize: 14)),
                  subtitle: const Text('Erase the "0" from the screenshot', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                  trailing: const Icon(Icons.chevron_right, size: 18, color: AppTheme.textTertiary),
                  onTap: () => Navigator.pushNamed(
                    context,
                    '/calculator-editor',
                    arguments: revealProvider.config.calculatorBackgroundPath!,
                  ),
                ),
                Divider(height: 1, color: AppTheme.divider),
                ListTile(
                  leading: const Icon(Icons.tune, size: 18, color: AppTheme.accent),
                  title: const Text('Calibrate', style: TextStyle(color: AppTheme.textPrimary, fontSize: 14)),
                  subtitle: const Text('Position, size and font of the number', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                  trailing: const Icon(Icons.chevron_right, size: 18, color: AppTheme.textTertiary),
                  onTap: () => Navigator.pushNamed(context, '/calculator-calibration'),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickCalculatorImage(BuildContext context) async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image == null || !context.mounted) return;
    final revealProvider = context.read<RevealProvider>();
    await revealProvider.setCalculatorBackground(File(image.path));
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.background.withOpacity(0.5),
      ),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppTheme.textSecondary,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

class _BackgroundTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool hasImage;
  final String? imagePath;
  final VoidCallback onUpload;
  final VoidCallback? onDelete;

  const _BackgroundTile({
    required this.title,
    required this.subtitle,
    required this.hasImage,
    this.imagePath,
    required this.onUpload,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Thumbnail or placeholder
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppTheme.background,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.divider),
            ),
            child: hasImage && imagePath != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(7),
                    child: Image.file(
                      File(imagePath!),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Icon(
                        Icons.broken_image_outlined,
                        color: AppTheme.textTertiary,
                        size: 24,
                      ),
                    ),
                  )
                : Icon(
                    Icons.image_outlined,
                    color: AppTheme.textTertiary,
                    size: 24,
                  ),
          ),
          const SizedBox(width: 12),
          // Text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: hasImage ? AppTheme.accent : Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
          // Actions
          if (onDelete != null)
            IconButton(
              icon: Icon(Icons.delete_outline, color: Colors.red[400], size: 22),
              onPressed: onDelete,
              padding: const EdgeInsets.all(8),
              constraints: const BoxConstraints(),
            ),
          const SizedBox(width: 4),
          IconButton(
            icon: Icon(
              hasImage ? Icons.edit_outlined : Icons.add_photo_alternate_outlined,
              color: AppTheme.accent,
              size: 22,
            ),
            onPressed: onUpload,
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}

class _ShortcutNameField extends StatefulWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const _ShortcutNameField({required this.value, required this.onChanged});

  @override
  State<_ShortcutNameField> createState() => _ShortcutNameFieldState();
}

class _ShortcutNameFieldState extends State<_ShortcutNameField> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(_ShortcutNameField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && _controller.text != widget.value) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'iOS Shortcut Name',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Run this Shortcut after copying (leave empty to skip)',
            style: TextStyle(fontSize: 13, color: Colors.grey[500]),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _controller,
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'e.g. Coller Prédiction',
              hintStyle: TextStyle(color: Colors.grey[600]),
              filled: true,
              fillColor: AppTheme.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppTheme.divider),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppTheme.divider),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppTheme.accent),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              suffixIcon: _controller.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18, color: AppTheme.textSecondary),
                      onPressed: () {
                        _controller.clear();
                        widget.onChanged('');
                      },
                    )
                  : null,
            ),
            onChanged: widget.onChanged,
          ),
        ],
      ),
    );
  }
}

class _CalibrateTile extends StatelessWidget {
  final String title;
  final VoidCallback onTap;

  const _CalibrateTile({required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(Icons.tune, color: AppTheme.accent, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.accent,
                  ),
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey[600]),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomescreenUploadTile extends StatelessWidget {
  final String? currentPath;
  final ValueChanged<String?> onChanged;

  const _HomescreenUploadTile({required this.currentPath, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final hasImage = currentPath != null && currentPath!.isNotEmpty && File(currentPath!).existsSync();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Homescreen Screenshot', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.textPrimary)),
          const SizedBox(height: 8),
          if (hasImage) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(File(currentPath!), height: 200, fit: BoxFit.cover),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton.icon(
                  onPressed: () => _pickImage(context),
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Replace'),
                ),
                TextButton.icon(
                  onPressed: () => onChanged(null),
                  icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                  label: const Text('Remove', style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
          ] else
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _pickImage(context),
                icon: const Icon(Icons.upload, size: 16),
                label: const Text('Upload Screenshot'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primary,
                  side: const BorderSide(color: AppTheme.primary),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _pickImage(BuildContext context) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    // Copy to app documents directory
    final dir = await getApplicationDocumentsDirectory();
    final fileName = 'homescreen_${DateTime.now().millisecondsSinceEpoch}.png';
    final savedFile = await File(image.path).copy('${dir.path}/$fileName');

    onChanged(savedFile.path);
  }
}

class _PreScreenNotesStatusTile extends StatelessWidget {
  const _PreScreenNotesStatusTile();

  @override
  Widget build(BuildContext context) {
    final reveal = context.watch<RevealProvider>();
    final lightPath = reveal.config.lightListBackgroundPath;
    final darkPath = reveal.config.darkListBackgroundPath;
    final hasLight = lightPath != null && lightPath.isNotEmpty && File(lightPath).existsSync();
    final hasDark = darkPath != null && darkPath.isNotEmpty && File(darkPath).existsSync();
    final hasAny = hasLight || hasDark;

    Widget thumb(String label, String path) {
      return Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(File(path), height: 80, fit: BoxFit.cover, width: double.infinity),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Notes Pre-Screen', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.textPrimary)),
          const SizedBox(height: 6),
          Text(
            hasAny
                ? 'Using uploaded LIST SCREEN screenshots from Reveal Background'
                : 'No Notes screenshot uploaded yet',
            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 10),
          if (hasAny) ...[
            Row(
              children: [
                if (hasLight) thumb('Light', lightPath!),
                if (hasLight && hasDark) const SizedBox(width: 8),
                if (hasDark) thumb('Dark', darkPath!),
              ],
            ),
            const SizedBox(height: 10),
          ],
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Use the "Reveal Background" section below to upload Notes screenshots.'),
                    duration: Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              icon: Icon(hasAny ? Icons.tune : Icons.upload, size: 16),
              label: Text(hasAny ? 'Manage in Reveal Background' : 'Upload in Reveal Background'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primary,
                side: const BorderSide(color: AppTheme.primary),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OpenAIKeyField extends StatefulWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const _OpenAIKeyField({required this.value, required this.onChanged});

  @override
  State<_OpenAIKeyField> createState() => _OpenAIKeyFieldState();
}

class _OpenAIKeyFieldState extends State<_OpenAIKeyField> {
  late TextEditingController _controller;
  bool _obscured = true;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(_OpenAIKeyField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && _controller.text != widget.value) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('OpenAI API Key',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: AppTheme.textPrimary)),
          const SizedBox(height: 2),
          Text('Required for AI audio mode (GPT-4o-mini)',
              style: TextStyle(fontSize: 13, color: Colors.grey[500])),
          const SizedBox(height: 8),
          TextField(
            controller: _controller,
            obscureText: _obscured,
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontFamily: 'monospace'),
            decoration: InputDecoration(
              hintText: 'sk-...',
              hintStyle: TextStyle(color: Colors.grey[600]),
              filled: true,
              fillColor: AppTheme.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppTheme.divider),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: _controller.text.isNotEmpty ? Colors.green.withOpacity(0.5) : AppTheme.divider),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppTheme.accent),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(_obscured ? Icons.visibility_off : Icons.visibility, size: 18, color: AppTheme.textSecondary),
                    onPressed: () => setState(() => _obscured = !_obscured),
                  ),
                  if (_controller.text.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.clear, size: 18, color: AppTheme.textSecondary),
                      onPressed: () {
                        _controller.clear();
                        widget.onChanged('');
                      },
                    ),
                ],
              ),
            ),
            onChanged: widget.onChanged,
          ),
          if (_controller.text.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.check_circle, size: 14, color: Colors.green),
                const SizedBox(width: 4),
                Text('AI audio mode enabled', style: TextStyle(fontSize: 11, color: Colors.green)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _RemoteKeyMapper extends StatefulWidget {
  final SettingsProvider settings;
  const _RemoteKeyMapper({required this.settings});

  @override
  State<_RemoteKeyMapper> createState() => _RemoteKeyMapperState();
}

class _RemoteKeyMapperState extends State<_RemoteKeyMapper> {
  String? _listeningFor; // 'up', 'down', 'left', 'right' or null
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _startListening(String direction) {
    setState(() => _listeningFor = direction);
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.settings;

    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: false,
      onKeyEvent: (event) {
        if (_listeningFor == null || event is! KeyDownEvent) return;
        final keyLabel = event.logicalKey.keyLabel;
        s.setRemoteKey(_listeningFor!, keyLabel);
        setState(() => _listeningFor = null);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          children: [
            _buildKeyRow('UP', 'up', s.remoteKeyUp, Icons.arrow_upward),
            _buildKeyRow('DOWN', 'down', s.remoteKeyDown, Icons.arrow_downward),
            _buildKeyRow('LEFT', 'left', s.remoteKeyLeft, Icons.arrow_back),
            _buildKeyRow('RIGHT', 'right', s.remoteKeyRight, Icons.arrow_forward),
            const SizedBox(height: 4),
            Text(
              s.hasRemote4Buttons ? '4-button remote (Volume + ClockSwipe)' : '2-button remote (Volume only)',
              style: TextStyle(fontSize: 10, color: AppTheme.textTertiary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKeyRow(String label, String direction, String currentKey, IconData icon) {
    final isListening = _listeningFor == direction;
    final isSet = currentKey.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppTheme.textSecondary),
          const SizedBox(width: 8),
          SizedBox(
            width: 50,
            child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => _startListening(direction),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isListening ? AppTheme.primary.withOpacity(0.15) : AppTheme.background,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isListening ? AppTheme.primary : isSet ? Colors.green.withOpacity(0.5) : AppTheme.border,
                  ),
                ),
                child: Text(
                  isListening ? 'Press a button...' : isSet ? currentKey : 'Tap to set',
                  style: TextStyle(
                    fontSize: 12,
                    fontFamily: isSet ? 'monospace' : null,
                    color: isListening ? AppTheme.primary : isSet ? AppTheme.textPrimary : AppTheme.textTertiary,
                  ),
                ),
              ),
            ),
          ),
          if (isSet && !isListening)
            GestureDetector(
              onTap: () => widget.settings.setRemoteKey(direction, ''),
              child: const Padding(
                padding: EdgeInsets.only(left: 6),
                child: Icon(Icons.clear, size: 14, color: AppTheme.textSecondary),
              ),
            ),
        ],
      ),
    );
  }
}

class _FreeTextAssistantSettings extends StatefulWidget {
  final String redirectUrl;
  final String transformPrompt;
  final ValueChanged<String> onRedirectUrlChanged;
  final ValueChanged<String> onTransformPromptChanged;
  final bool hasOpenaiKey;
  final String openaiApiKey;

  const _FreeTextAssistantSettings({
    required this.redirectUrl,
    required this.transformPrompt,
    required this.onRedirectUrlChanged,
    required this.onTransformPromptChanged,
    required this.hasOpenaiKey,
    required this.openaiApiKey,
  });

  @override
  State<_FreeTextAssistantSettings> createState() => _FreeTextAssistantSettingsState();
}

class _FreeTextAssistantSettingsState extends State<_FreeTextAssistantSettings> {
  late TextEditingController _redirectController;
  late TextEditingController _promptController;
  final TextEditingController _testInputController = TextEditingController();
  String? _testResult;
  bool _isTesting = false;

  @override
  void initState() {
    super.initState();
    _redirectController = TextEditingController(text: widget.redirectUrl);
    _promptController = TextEditingController(text: widget.transformPrompt);
  }

  @override
  void dispose() {
    _redirectController.dispose();
    _promptController.dispose();
    _testInputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Redirect URL
          const Text('Redirect URL (optional)',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppTheme.textPrimary)),
          const SizedBox(height: 4),
          TextField(
            controller: _redirectController,
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'https://...',
              hintStyle: TextStyle(color: Colors.grey[600], fontSize: 12),
              filled: true, fillColor: AppTheme.background,
              isDense: true,
              prefixIcon: const Icon(Icons.open_in_new, size: 16),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            onChanged: widget.onRedirectUrlChanged,
          ),

          const SizedBox(height: 16),

          // Transform prompt
          const Text('Transform Prompt (optional)',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppTheme.textPrimary)),
          const SizedBox(height: 2),
          Text('Use {value} for the received text',
              style: TextStyle(fontSize: 10, color: Colors.grey[600])),
          const SizedBox(height: 4),
          TextField(
            controller: _promptController,
            maxLines: 3,
            minLines: 1,
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Ex: Give me the capital of this country: {value}',
              hintStyle: TextStyle(color: Colors.grey[600], fontSize: 11),
              filled: true, fillColor: AppTheme.background,
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.all(10),
            ),
            onChanged: widget.onTransformPromptChanged,
          ),

          // Test section
          if (_promptController.text.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _testInputController,
                    style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12),
                    decoration: InputDecoration(
                      hintText: 'Test input...',
                      hintStyle: TextStyle(color: Colors.grey[600], fontSize: 11),
                      filled: true, fillColor: AppTheme.background,
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                SizedBox(
                  height: 32,
                  child: ElevatedButton(
                    onPressed: _isTesting || !widget.hasOpenaiKey ? null : () async {
                      final prompt = _promptController.text.trim();
                      final input = _testInputController.text.trim();
                      if (prompt.isEmpty || input.isEmpty) return;

                      setState(() { _isTesting = true; _testResult = null; });

                      final result = await ExternalApiService.transformWithPrompt(
                        prompt: prompt,
                        openaiApiKey: widget.openaiApiKey,
                        variables: {'value': input},
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
                  child: Text(_testResult!, style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary)),
                ),
              ),
            if (!widget.hasOpenaiKey)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('OpenAI API key required for transform', style: TextStyle(fontSize: 10, color: Colors.orange[400])),
              ),
          ],
        ],
      ),
    );
  }
}

class _ApiCredentialField extends StatefulWidget {
  final String label;
  final String hint;
  final String value;
  final ValueChanged<String> onChanged;
  /// Obscure the value with dots and offer an eye toggle. Defaults to true
  /// for genuine credentials (API keys, IDs); set to false for plain URLs
  /// the user wants to see at a glance.
  final bool obscure;
  /// When true, render the label above the input field (full width) instead
  /// of side-by-side. Useful for long values like URLs that would otherwise
  /// be truncated in the narrow inline layout.
  final bool stackedLabel;

  const _ApiCredentialField({
    required this.label,
    required this.hint,
    required this.value,
    required this.onChanged,
    this.obscure = true,
    this.stackedLabel = false,
  });

  @override
  State<_ApiCredentialField> createState() => _ApiCredentialFieldState();
}

class _ApiCredentialFieldState extends State<_ApiCredentialField> {
  late TextEditingController _controller;
  late bool _obscured;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
    _obscured = widget.obscure;
  }

  @override
  void didUpdateWidget(_ApiCredentialField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && _controller.text != widget.value) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isConfigured = _controller.text.isNotEmpty;
    final field = TextField(
      controller: _controller,
      obscureText: _obscured,
      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontFamily: 'monospace'),
      decoration: InputDecoration(
        hintText: widget.hint,
        hintStyle: TextStyle(fontSize: 12, color: Colors.grey[600]),
        filled: true,
        fillColor: AppTheme.background,
        isDense: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: isConfigured ? Colors.green.withOpacity(0.5) : AppTheme.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: isConfigured ? Colors.green.withOpacity(0.5) : AppTheme.divider),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.obscure)
              GestureDetector(
                onTap: () => setState(() => _obscured = !_obscured),
                child: Icon(_obscured ? Icons.visibility_off : Icons.visibility, size: 16, color: AppTheme.textSecondary),
              ),
            if (isConfigured) ...[
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () {
                  _controller.clear();
                  widget.onChanged('');
                },
                child: const Icon(Icons.clear, size: 16, color: AppTheme.textSecondary),
              ),
            ],
            const SizedBox(width: 8),
          ],
        ),
      ),
      onChanged: widget.onChanged,
    );

    if (widget.stackedLabel) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                if (isConfigured)
                  const Icon(Icons.check_circle, size: 14, color: Colors.green)
                else
                  Icon(Icons.circle_outlined, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Text(widget.label,
                    style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary)),
              ],
            ),
            const SizedBox(height: 8),
            field,
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          if (isConfigured)
            const Icon(Icons.check_circle, size: 14, color: Colors.green)
          else
            Icon(Icons.circle_outlined, size: 14, color: Colors.grey[600]),
          const SizedBox(width: 8),
          SizedBox(
            width: 110,
            child: Text(widget.label,
                style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary)),
          ),
          Expanded(child: field),
        ],
      ),
    );
  }
}

// ============ API TEST BUTTON ============

class _ApiTestButton extends StatefulWidget {
  final String label;
  final Future<String> Function() onTest;

  const _ApiTestButton({required this.label, required this.onTest});

  @override
  State<_ApiTestButton> createState() => _ApiTestButtonState();
}

class _ApiTestButtonState extends State<_ApiTestButton> {
  bool _loading = false;
  String? _result;

  Future<void> _test() async {
    setState(() { _loading = true; _result = null; });
    try {
      final result = await widget.onTest();
      if (mounted) setState(() { _result = result; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _result = 'Error: $e'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _loading ? null : _test,
                  icon: _loading
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.play_arrow, size: 16),
                  label: Text(widget.label, style: const TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
            ],
          ),
          if (_result != null) ...[
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.background,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _result!.startsWith('Error') ? Colors.red.withValues(alpha: 0.5) : Colors.green.withValues(alpha: 0.5)),
              ),
              child: Text(
                _result!,
                style: TextStyle(
                  fontSize: 11,
                  fontFamily: 'monospace',
                  color: _result!.startsWith('Error') ? Colors.red : AppTheme.textPrimary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ============ AI TRANSFORM TEST ============

class _AITransformTest extends StatefulWidget {
  final String apiKey;

  const _AITransformTest({required this.apiKey});

  @override
  State<_AITransformTest> createState() => _AITransformTestState();
}

class _AITransformTestState extends State<_AITransformTest> {
  final _promptController = TextEditingController(text: 'Translate {value} to French');
  final _inputController = TextEditingController(text: 'Hello World');
  bool _loading = false;
  String? _result;

  @override
  void dispose() {
    _promptController.dispose();
    _inputController.dispose();
    super.dispose();
  }

  Future<void> _test() async {
    if (_promptController.text.trim().isEmpty || _inputController.text.trim().isEmpty) return;
    setState(() { _loading = true; _result = null; });
    try {
      final result = await ExternalApiService.transformWithPrompt(
        prompt: _promptController.text.trim(),
        openaiApiKey: widget.apiKey,
        variables: {'value': _inputController.text.trim()},
      );
      if (mounted) setState(() { _result = result ?? 'No response'; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _result = 'Error: $e'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Test AI Transform', style: TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextField(
            controller: _promptController,
            style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary),
            maxLines: 2,
            decoration: InputDecoration(
              labelText: 'Prompt (use {value})',
              labelStyle: TextStyle(fontSize: 11, color: AppTheme.textTertiary),
              filled: true, fillColor: AppTheme.background,
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppTheme.border)),
              contentPadding: const EdgeInsets.all(10),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _inputController,
                  style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Input value',
                    labelStyle: TextStyle(fontSize: 11, color: AppTheme.textTertiary),
                    filled: true, fillColor: AppTheme.background,
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppTheme.border)),
                    contentPadding: const EdgeInsets.all(10),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _loading ? null : _test,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                child: _loading
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Transform', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          if (_result != null) ...[
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.background,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.withValues(alpha: 0.5)),
              ),
              child: Text(
                _result!,
                style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ============ iCLOUD SYNC TILE ============

class _ICloudSyncTile extends StatefulWidget {
  @override
  State<_ICloudSyncTile> createState() => _ICloudSyncTileState();
}

class _ICloudSyncTileState extends State<_ICloudSyncTile> {
  bool _syncing = false;
  String? _status;
  String? _lastSyncText;
  StreamSubscription? _statusSub;

  @override
  void initState() {
    super.initState();
    _refreshLastSync();
    _statusSub = ICloudSyncService.onStatusChange.listen((s) {
      if (!mounted) return;
      setState(() {
        if (s.state == 'pushing') _status = 'Syncing…';
        if (s.state == 'pushed') { _status = 'Synced'; _refreshLastSync(); }
        if (s.state == 'pulled') _refreshLastSync();
        if (s.state == 'unavailable') _status = 'iCloud unavailable';
      });
    });
  }

  @override
  void dispose() {
    _statusSub?.cancel();
    super.dispose();
  }

  Future<void> _refreshLastSync() async {
    final iso = await ICloudSyncService.getLastSyncTime();
    if (!mounted) return;
    setState(() {
      if (iso == null) { _lastSyncText = 'Never synced'; return; }
      final dt = DateTime.tryParse(iso)?.toLocal();
      if (dt == null) { _lastSyncText = iso; return; }
      final diff = DateTime.now().difference(dt);
      String rel;
      if (diff.inSeconds < 60) {
        rel = 'just now';
      } else if (diff.inMinutes < 60) {
        rel = '${diff.inMinutes} min ago';
      } else if (diff.inHours < 24) {
        rel = '${diff.inHours} h ago';
      } else {
        rel = '${diff.inDays} d ago';
      }
      _lastSyncText = 'Last sync: $rel';
    });
  }

  Future<void> _pushToCloud() async {
    setState(() { _syncing = true; _status = null; });
    try {
      final storage = LocalStorage();
      await storage.init();
      await ICloudSyncService.pushToCloud(storage);
      if (mounted) setState(() { _syncing = false; _status = 'Pushed to iCloud'; });
    } catch (e) {
      if (mounted) setState(() { _syncing = false; _status = 'Error: $e'; });
    }
  }

  Future<void> _pullFromCloud() async {
    setState(() { _syncing = true; _status = null; });
    try {
      final storage = LocalStorage();
      await storage.init();
      final hasData = await ICloudSyncService.pullFromCloud(storage);
      if (mounted) {
        setState(() {
          _syncing = false;
          _status = hasData ? 'Restored from iCloud — restart app' : 'No cloud data found';
        });
      }
    } catch (e) {
      if (mounted) setState(() { _syncing = false; _status = 'Error: $e'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.cloud, size: 18, color: AppTheme.primary),
              const SizedBox(width: 8),
              const Text('iCloud Sync', style: TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w500)),
            ],
          ),
          const SizedBox(height: 4),
          Text('Sync presets, routines and settings', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
          if (_lastSyncText != null) ...[
            const SizedBox(height: 4),
            Text(_lastSyncText!, style: TextStyle(fontSize: 10, color: AppTheme.textTertiary, fontStyle: FontStyle.italic)),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _syncing ? null : _pushToCloud,
                  icon: _syncing ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.cloud_upload, size: 16),
                  label: const Text('Backup', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _syncing ? null : _pullFromCloud,
                  icon: const Icon(Icons.cloud_download, size: 16),
                  label: const Text('Restore', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.surface,
                    foregroundColor: AppTheme.textPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.5)),
                  ),
                ),
              ),
            ],
          ),
          if (_status != null) ...[
            const SizedBox(height: 6),
            Text(_status!, style: TextStyle(fontSize: 11, color: _status!.startsWith('Error') ? Colors.red : Colors.green)),
          ],
        ],
      ),
    );
  }
}


class _AssistantStealthChip extends StatelessWidget {
  final bool selected;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _AssistantStealthChip({
    required this.selected,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primary : AppTheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: selected ? AppTheme.primary : AppTheme.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: selected ? Colors.white : AppTheme.textSecondary),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Footer showing the version. Long-press the version to reveal a hidden
/// admin-token field above it (used to publish presets as templates).
/// The reveal is per-session — closing Settings hides it again.
class _FooterWithAdminReveal extends StatefulWidget {
  const _FooterWithAdminReveal();

  @override
  State<_FooterWithAdminReveal> createState() => _FooterWithAdminRevealState();
}

class _FooterWithAdminRevealState extends State<_FooterWithAdminReveal> {
  bool _unlocked = false;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    return Column(
      children: [
        const SizedBox(height: 32),
        if (_unlocked) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TEMPLATES ADMIN',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[500],
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: _ApiCredentialField(
                    label: 'Admin Token',
                    hint: 'Required to publish/delete templates',
                    value: settings.templatesAdminToken,
                    onChanged: settings.setTemplatesAdminToken,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        GestureDetector(
          onLongPress: () {
            HapticFeedback.mediumImpact();
            setState(() => _unlocked = !_unlocked);
          },
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 24),
            child: Text(
              'v1.8.0',
              style: TextStyle(fontSize: 11, color: AppTheme.textTertiary),
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

/// Tile that lets the user pick an image from their gallery, upload it to
/// Cloudinary, and write the resulting public URL into the global decoy
/// image setting. Shows a thumbnail when an image is set.
class _DecoyUploadTile extends StatefulWidget {
  final String currentUrl;
  final ValueChanged<String> onUploaded;
  const _DecoyUploadTile({required this.currentUrl, required this.onUploaded});

  @override
  State<_DecoyUploadTile> createState() => _DecoyUploadTileState();
}

class _DecoyUploadTileState extends State<_DecoyUploadTile> {
  bool _uploading = false;

  Future<void> _pick() async {
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
      widget.onUploaded(url);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Upload failed'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = widget.currentUrl.trim().isNotEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          if (hasImage) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.network(
                widget.currentUrl,
                width: 40, height: 40, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 40, height: 40,
                  color: AppTheme.background,
                  child: const Icon(Icons.broken_image, size: 18, color: AppTheme.textTertiary),
                ),
              ),
            ),
            const SizedBox(width: 12),
          ] else ...[
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: AppTheme.background,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.image_outlined, size: 18, color: AppTheme.textTertiary),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Text(
              hasImage ? 'Replace image' : 'Upload image to Cloudinary',
              style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary),
            ),
          ),
          GestureDetector(
            onTap: _uploading ? null : _pick,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.primary.withValues(alpha: 0.4)),
              ),
              child: _uploading
                  ? const SizedBox(
                      width: 14, height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
                    )
                  : const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.upload, size: 14, color: AppTheme.primary),
                      SizedBox(width: 6),
                      Text('Upload', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primary)),
                    ]),
            ),
          ),
        ],
      ),
    );
  }
}

/// Picker for the global default decoy template (shown in Integrations →
/// Decoy Mode). Lists user-defined templates from SettingsProvider plus a
/// "None" option.
class _DecoyDefaultTemplatePicker extends StatelessWidget {
  final SettingsProvider settings;
  const _DecoyDefaultTemplatePicker({required this.settings});

  @override
  Widget build(BuildContext context) {
    final templates = settings.decoyTemplates;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Default decoy template',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.textPrimary)),
          const SizedBox(height: 4),
          Text(
            templates.isEmpty
                ? 'Create a template in Display tab → Decoy Templates first.'
                : 'Used by presets that don\'t pick their own template.',
            style: const TextStyle(fontSize: 11, color: AppTheme.textTertiary),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String?>(
            value: settings.defaultDecoyTemplateId,
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
              const DropdownMenuItem<String?>(value: null, child: Text('— None —')),
              for (final t in templates)
                DropdownMenuItem<String?>(value: t.id, child: Text(t.name)),
            ],
            onChanged: templates.isEmpty ? null : (v) => settings.setDefaultDecoyTemplateId(v),
          ),
        ],
      ),
    );
  }
}

/// Section that lists existing decoy templates and offers a "+ Add" button
/// up to the 3-template cap. Each row shows a thumbnail of the main image,
/// the template name + title, and edit / delete actions.
class _DecoyTemplatesSection extends StatelessWidget {
  final SettingsProvider settings;
  const _DecoyTemplatesSection({required this.settings});

  void _openEditor(BuildContext context, {DecoyTemplate? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _DecoyTemplateEditor(
        settings: settings,
        existing: existing,
      ),
    );
  }

  void _confirmDelete(BuildContext context, DecoyTemplate t) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Delete decoy?', style: TextStyle(color: AppTheme.textPrimary, fontSize: 16)),
        content: Text('Remove "${t.name}"? Presets that point to it will fall back to the global default.',
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () { settings.deleteDecoyTemplate(t.id); Navigator.pop(ctx); },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _publish(BuildContext context, DecoyTemplate t) async {
    final ok = await FirebaseService.publishDecoyTemplate(
      template: t,
      adminToken: settings.templatesAdminToken,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok ? 'Published "${t.name}"' : 'Publish failed'),
      backgroundColor: ok ? Colors.green : Colors.red,
      duration: const Duration(seconds: 2),
    ));
  }

  void _openShared(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _SharedDecoysSheet(settings: settings),
    );
  }

  @override
  Widget build(BuildContext context) {
    final templates = settings.decoyTemplates;
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (templates.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'No decoy templates yet. Create one to use it in your presets.',
                style: TextStyle(fontSize: 12, color: AppTheme.textTertiary),
              ),
            )
          else
            ...templates.map((t) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.background,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: t.mainImageUrl.trim().isEmpty
                          ? Container(width: 44, height: 44, color: AppTheme.surface, child: const Icon(Icons.image_outlined, size: 18, color: AppTheme.textTertiary))
                          : Image.network(t.mainImageUrl, width: 44, height: 44, fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(width: 44, height: 44, color: AppTheme.surface, child: const Icon(Icons.broken_image, size: 18, color: AppTheme.textTertiary))),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary), overflow: TextOverflow.ellipsis),
                          if (t.title.trim().isNotEmpty)
                            Text(t.title, style: const TextStyle(fontSize: 11, color: AppTheme.textTertiary), overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                    if (settings.isTemplatesAdmin)
                      IconButton(
                        icon: const Icon(Icons.cloud_upload_outlined, size: 18, color: AppTheme.textSecondary),
                        tooltip: 'Publish to shared library',
                        onPressed: () => _publish(context, t),
                      ),
                    IconButton(icon: const Icon(Icons.edit, size: 18, color: AppTheme.textSecondary), onPressed: () => _openEditor(context, existing: t)),
                    IconButton(icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.textSecondary), onPressed: () => _confirmDelete(context, t)),
                  ],
                ),
              ),
            )),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: settings.canCreateDecoyTemplate ? () => _openEditor(context) : null,
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(settings.isTemplatesAdmin
                      ? 'Add decoy (${templates.length})'
                      : (settings.canCreateDecoyTemplate
                          ? 'Add decoy (${templates.length}/${SettingsProvider.maxDecoyTemplates})'
                          : 'Maximum ${SettingsProvider.maxDecoyTemplates} reached')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppTheme.background,
                    disabledForegroundColor: AppTheme.textTertiary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () => _openShared(context),
                icon: const Icon(Icons.cloud_download_outlined, size: 18),
                label: const Text('Browse'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primary,
                  side: const BorderSide(color: AppTheme.primary),
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Modal editor for creating or updating a [DecoyTemplate].
class _DecoyTemplateEditor extends StatefulWidget {
  final SettingsProvider settings;
  final DecoyTemplate? existing;
  const _DecoyTemplateEditor({required this.settings, this.existing});

  @override
  State<_DecoyTemplateEditor> createState() => _DecoyTemplateEditorState();
}

class _DecoyTemplateEditorState extends State<_DecoyTemplateEditor> {
  late TextEditingController _name;
  late TextEditingController _mainImg;
  late List<TextEditingController> _thumbs;
  late TextEditingController _title;
  late TextEditingController _siteName;
  late TextEditingController _faviconImg;
  late TextEditingController _faviconText;
  late TextEditingController _faviconBg;
  late TextEditingController _faviconFg;
  late TextEditingController _copyright;
  bool _uploadingMain = false;
  bool _uploadingFavicon = false;
  final List<bool> _uploadingThumb =
      List<bool>.filled(DecoyTemplate.maxThumbnails, false);

  @override
  void initState() {
    super.initState();
    final t = widget.existing ?? DecoyTemplate.create();
    _name = TextEditingController(text: t.name);
    _mainImg = TextEditingController(text: t.mainImageUrl);
    final padded = List<String>.from(t.thumbnailUrls);
    while (padded.length < DecoyTemplate.maxThumbnails) { padded.add(''); }
    _thumbs = padded.take(DecoyTemplate.maxThumbnails).map((u) => TextEditingController(text: u)).toList();
    _title = TextEditingController(text: t.title);
    _siteName = TextEditingController(text: t.siteName);
    _faviconImg = TextEditingController(text: t.faviconImageUrl);
    _faviconText = TextEditingController(text: t.faviconText);
    _faviconBg = TextEditingController(text: t.faviconBgColor);
    _faviconFg = TextEditingController(text: t.faviconTextColor);
    _copyright = TextEditingController(text: t.copyright);
  }

  @override
  void dispose() {
    _name.dispose(); _mainImg.dispose();
    for (final c in _thumbs) { c.dispose(); }
    _title.dispose(); _siteName.dispose();
    _faviconImg.dispose();
    _faviconText.dispose(); _faviconBg.dispose(); _faviconFg.dispose();
    _copyright.dispose();
    super.dispose();
  }

  Future<void> _pickImageInto(TextEditingController controller, {required void Function(bool) setUploading}) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85, maxWidth: 1920);
    if (picked == null) return;
    setUploading(true);
    final url = await CloudinaryService.uploadDecoyImage(picked.path);
    if (!mounted) return;
    setUploading(false);
    if (url != null) {
      setState(() => controller.text = url);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Upload failed'), backgroundColor: Colors.red),
      );
    }
  }

  void _save() {
    final base = widget.existing ?? DecoyTemplate.create();
    final updated = base.copyWith(
      name: _name.text.trim().isEmpty ? 'Decoy' : _name.text.trim(),
      mainImageUrl: _mainImg.text.trim(),
      thumbnailUrls: _thumbs.map((c) => c.text.trim()).where((u) => u.isNotEmpty).toList(),
      title: _title.text.trim(),
      siteName: _siteName.text.trim(),
      faviconImageUrl: _faviconImg.text.trim(),
      faviconText: _faviconText.text.trim().isEmpty ? 'G' : _faviconText.text.trim(),
      faviconBgColor: _faviconBg.text.trim().isEmpty ? '#1a73e8' : _faviconBg.text.trim(),
      faviconTextColor: _faviconFg.text.trim().isEmpty ? '#ffffff' : _faviconFg.text.trim(),
      copyright: _copyright.text.trim().isEmpty ? 'Images may be subject to copyright. Learn More' : _copyright.text.trim(),
    );
    if (widget.existing == null) {
      widget.settings.addDecoyTemplate(updated);
    } else {
      widget.settings.updateDecoyTemplate(updated);
    }
    Navigator.pop(context);
  }

  Widget _field(String label, TextEditingController c, {String? hint}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppTheme.textSecondary)),
          const SizedBox(height: 4),
          TextField(
            controller: c,
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(fontSize: 12, color: AppTheme.textTertiary),
              filled: true, fillColor: AppTheme.background,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.border)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _imageField(String label, TextEditingController c, bool uploading, void Function(bool) setUploading) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppTheme.textSecondary)),
          const SizedBox(height: 4),
          Row(
            children: [
              if (c.text.trim().isNotEmpty) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.network(c.text.trim(), width: 40, height: 40, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(width: 40, height: 40, color: AppTheme.background, child: const Icon(Icons.broken_image, size: 18, color: AppTheme.textTertiary))),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: TextField(
                  controller: c,
                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12),
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'https://...',
                    hintStyle: const TextStyle(fontSize: 11, color: AppTheme.textTertiary),
                    filled: true, fillColor: AppTheme.background,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.border)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.border)),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: uploading ? null : () => _pickImageInto(c, setUploading: setUploading),
                child: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.primary.withValues(alpha: 0.4)),
                  ),
                  child: uploading
                      ? const Padding(padding: EdgeInsets.all(10), child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary))
                      : const Icon(Icons.upload, size: 18, color: AppTheme.primary),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // The iOS keyboard overlays the modal without resizing the sheet, so the
    // bottom fields can become unreachable. Add keyboard-height padding to
    // the ListView so the user can scroll past visible content and bring the
    // last fields above the keyboard.
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (_, controller) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          children: [
            // Drag handle
            Container(width: 36, height: 4, decoration: BoxDecoration(color: AppTheme.textTertiary, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(widget.existing == null ? 'New decoy' : 'Edit decoy',
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                const Spacer(),
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
                  child: const Text('Save'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                controller: controller,
                // Tap-to-dismiss the keyboard via drag — quick escape if a
                // user gets stuck behind it.
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.only(bottom: 24 + keyboardInset),
                children: [
                  _field('Name (private)', _name, hint: 'IMDb Tom Cruise'),
                  _imageField('Main image', _mainImg, _uploadingMain, (v) => setState(() => _uploadingMain = v)),
                  for (int i = 0; i < DecoyTemplate.maxThumbnails; i++)
                    _imageField('Thumbnail ${i + 1}', _thumbs[i], _uploadingThumb[i], (v) => setState(() => _uploadingThumb[i] = v)),
                  _field('Site name (header)', _siteName, hint: 'IMDb'),
                  _imageField('Favicon image (overrides text+colors)', _faviconImg, _uploadingFavicon, (v) => setState(() => _uploadingFavicon = v)),
                  _field('Favicon text (used if no image)', _faviconText, hint: 'IMDb'),
                  Row(children: [
                    Expanded(child: _field('Favicon bg color', _faviconBg, hint: '#f5c518')),
                    const SizedBox(width: 8),
                    Expanded(child: _field('Favicon text color', _faviconFg, hint: '#000000')),
                  ]),
                  _field('Title (under image)', _title, hint: 'Tom Cruise - IMDb'),
                  _field('Copyright text', _copyright, hint: 'Images may be subject to copyright. Learn More'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet showing decoy templates published to Firebase by admins.
/// Each row has an "Add to library" button that imports a copy locally.
class _SharedDecoysSheet extends StatefulWidget {
  final SettingsProvider settings;
  const _SharedDecoysSheet({required this.settings});

  @override
  State<_SharedDecoysSheet> createState() => _SharedDecoysSheetState();
}

class _SharedDecoysSheetState extends State<_SharedDecoysSheet> {
  bool _loading = true;
  List<DecoyTemplate> _shared = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final raw = await FirebaseService.fetchSharedDecoyTemplates();
      final list = <DecoyTemplate>[];
      raw.forEach((id, val) {
        if (val is Map) {
          try {
            final m = Map<String, dynamic>.from(val);
            // Ignore meta fields stored alongside (adminToken, publishedAt).
            m['id'] = id;
            list.add(DecoyTemplate.fromJson(m));
          } catch (_) {}
        }
      });
      if (!mounted) return;
      setState(() { _shared = list; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _import(DecoyTemplate t) async {
    if (!widget.settings.canCreateDecoyTemplate) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Library full (max ${SettingsProvider.maxDecoyTemplates}). Delete one first.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    // Give the imported copy a fresh local id so we don't collide with the
    // shared one if it's republished later.
    final copy = t.copyWith().toJson();
    copy['id'] = const Uuid().v4();
    await widget.settings.addDecoyTemplate(DecoyTemplate.fromJson(copy));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Imported "${t.name}"'),
      backgroundColor: Colors.green,
      duration: const Duration(seconds: 2),
    ));
  }

  Future<void> _deleteShared(DecoyTemplate t) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Delete shared decoy?', style: TextStyle(color: AppTheme.textPrimary, fontSize: 16)),
        content: Text('Remove "${t.name}" from the public library? Other users will no longer see it.',
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    final ok = await FirebaseService.deleteSharedDecoyTemplate(
      id: t.id,
      adminToken: widget.settings.templatesAdminToken,
    );
    if (!mounted) return;
    if (ok) {
      setState(() => _shared.removeWhere((s) => s.id == t.id));
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Deleted'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Delete failed'),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 2),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.9,
      minChildSize: 0.4,
      expand: false,
      builder: (_, controller) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          children: [
            Container(width: 36, height: 4, decoration: BoxDecoration(color: AppTheme.textTertiary, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('Shared decoys', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                const Spacer(),
                IconButton(icon: const Icon(Icons.refresh, color: AppTheme.textSecondary), onPressed: _load),
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
                  : _error != null
                      ? Center(child: Text(_error!, style: const TextStyle(color: AppTheme.textSecondary)))
                      : _shared.isEmpty
                          ? const Center(child: Text('No shared decoys yet.', style: TextStyle(color: AppTheme.textSecondary)))
                          : ListView.builder(
                              controller: controller,
                              itemCount: _shared.length,
                              itemBuilder: (_, i) {
                                final t = _shared[i];
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppTheme.background,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: AppTheme.border),
                                  ),
                                  child: Row(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(6),
                                        child: t.mainImageUrl.trim().isEmpty
                                            ? Container(width: 44, height: 44, color: AppTheme.surface, child: const Icon(Icons.image_outlined, size: 18, color: AppTheme.textTertiary))
                                            : Image.network(t.mainImageUrl, width: 44, height: 44, fit: BoxFit.cover,
                                                errorBuilder: (_, __, ___) => Container(width: 44, height: 44, color: AppTheme.surface, child: const Icon(Icons.broken_image, size: 18, color: AppTheme.textTertiary))),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(t.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                                            if (t.title.trim().isNotEmpty)
                                              Text(t.title, style: const TextStyle(fontSize: 11, color: AppTheme.textTertiary)),
                                          ],
                                        ),
                                      ),
                                      if (widget.settings.isTemplatesAdmin)
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.textSecondary),
                                          tooltip: 'Delete from public library',
                                          onPressed: () => _deleteShared(t),
                                        ),
                                      ElevatedButton.icon(
                                        onPressed: () => _import(t),
                                        icon: const Icon(Icons.add, size: 16),
                                        label: const Text('Add'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppTheme.primary,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }
}
