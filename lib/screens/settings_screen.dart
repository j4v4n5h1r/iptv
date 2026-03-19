import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/app_settings.dart';
import '../services/app_localizations.dart';
import '../services/update_service.dart';
import 'parental_lock_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _backFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
      _backFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _backFocus.dispose();
    super.dispose();
  }

  // ── Helpers ─────────────────────────────────────────────────────────────
  Widget _sectionHeader(String title) => Padding(
        padding: const EdgeInsets.fromLTRB(0, 20, 0, 8),
        child: Text(title.toUpperCase(),
            style: const TextStyle(
                color: Colors.white38, fontSize: 11, letterSpacing: 1.2)),
      );

  Widget _settingsTile({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
    bool focused = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: focused ? Colors.deepOrange : Colors.white12, width: 1.5),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white70, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(color: Colors.white, fontSize: 14)),
                  if (subtitle != null)
                    Text(subtitle,
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 12)),
                ],
              ),
            ),
            if (trailing != null) trailing,
          ],
        ),
      ),
    );
  }

  // ── Parental Control ────────────────────────────────────────────────────
  void _showPinDialog({required String title, required Function(String) onSubmit}) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          obscureText: true,
          maxLength: 4,
          autofocus: true,
          style: const TextStyle(color: Colors.white, fontSize: 22, letterSpacing: 8),
          decoration: const InputDecoration(
            counterText: '',
            hintText: '• • • •',
            hintStyle: TextStyle(color: Colors.white24),
            filled: true,
            fillColor: Color(0xFF0A0A0A),
            border: OutlineInputBorder(),
          ),
          onSubmitted: (v) { Navigator.pop(ctx); onSubmit(v); },
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
          TextButton(
              onPressed: () { Navigator.pop(ctx); onSubmit(ctrl.text); },
              child: const Text('OK', style: TextStyle(color: Colors.deepOrange))),
        ],
      ),
    );
  }

  void _setupParentalPin(AppSettings s) {
    _showPinDialog(
      title: 'Set 4-digit PIN',
      onSubmit: (pin) async {
        if (pin.length == 4) {
          await s.setParentalPin(pin);
          await s.setParentalEnabled(true);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Parental control enabled')));
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('PIN must be 4 digits')));
          }
        }
      },
    );
  }

  void _disableParental(AppSettings s) {
    _showPinDialog(
      title: 'Enter PIN to disable',
      onSubmit: (pin) async {
        if (pin == s.parentalPin) {
          await s.setParentalEnabled(false);
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Wrong PIN')));
        }
      },
    );
  }

  // ── Clear history ───────────────────────────────────────────────────────
  void _clearHistory() {
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: const Text('Clear Watch History',
            style: TextStyle(color: Colors.white)),
        content: const Text('Are you sure? This will remove all recently watched channels.',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    ).then((confirmed) async {
      if (confirmed != true) return;
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('watchlist');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Watch history cleared')));
      }
    });
  }

  // ── Update check ────────────────────────────────────────────────────────
  Future<void> _checkForUpdate(BuildContext context) async {
    final info = await UpdateService.checkForUpdate(force: true);
    if (!mounted) return;
    if (info == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You are on the latest version.')));
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: Text('Update Available  v${info.version}',
            style: const TextStyle(color: Colors.white)),
        content: Text(
          info.releaseNotes.isNotEmpty ? info.releaseNotes : 'A new version is available.',
          style: const TextStyle(color: Colors.white70, fontSize: 13),
          maxLines: 6,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Later', style: TextStyle(color: Colors.white54))),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK', style: TextStyle(color: Colors.deepOrange))),
        ],
      ),
    );
  }

  // ── Build ───────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Consumer<AppSettings>(
      builder: (ctx, settings, _) {
        final l10n = AppL10n(settings.language);
        return Shortcuts(
          shortcuts: {
            LogicalKeySet(LogicalKeyboardKey.arrowDown): const NextFocusIntent(),
            LogicalKeySet(LogicalKeyboardKey.arrowUp): const PreviousFocusIntent(),
            LogicalKeySet(LogicalKeyboardKey.select): const ActivateIntent(),
            LogicalKeySet(LogicalKeyboardKey.enter): const ActivateIntent(),
          },
          child: Scaffold(
            appBar: AppBar(
              title: Text(l10n.get('settings'),
                  style: const TextStyle(color: Colors.white)),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            body: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              children: [
                // ── Appearance ────────────────────────────────────────────
                _sectionHeader(l10n.get('settings_theme')),

                // Accent color
                _settingsTile(
                  icon: Icons.palette,
                  title: l10n.get('settings_theme_accent'),
                  subtitle: settings.accentColor,
                  onTap: () => _showColorPicker(settings),
                  trailing: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: settings.accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),

                // ── Language ──────────────────────────────────────────────
                _sectionHeader(l10n.get('settings_language')),
                _settingsTile(
                  icon: Icons.language,
                  title: l10n.get('settings_language'),
                  subtitle: _languageLabel(settings.language),
                  onTap: () => _showLanguagePicker(settings),
                  trailing: const Icon(Icons.chevron_right, color: Colors.white24),
                ),

                // ── Playback ──────────────────────────────────────────────
                _sectionHeader(l10n.get('settings_stream')),

                // Stream mode
                _settingsTile(
                  icon: Icons.stream,
                  title: l10n.get('settings_stream_mode'),
                  subtitle: _streamModeLabel(settings.streamMode, l10n),
                  onTap: () => _showStreamModePicker(settings, l10n),
                  trailing: const Icon(Icons.chevron_right, color: Colors.white24),
                ),
                const SizedBox(height: 8),

                // Buffer
                _settingsTile(
                  icon: Icons.hourglass_bottom,
                  title: l10n.get('settings_buffer'),
                  subtitle: '${settings.bufferSeconds}s',
                  onTap: () => _showBufferPicker(settings),
                  trailing: const Icon(Icons.chevron_right, color: Colors.white24),
                ),
                const SizedBox(height: 8),

                // HW decode
                _settingsTile(
                  icon: Icons.memory,
                  title: l10n.get('settings_hw_decode'),
                  subtitle: settings.hwDecode ? 'On' : 'Off',
                  trailing: Switch(
                    value: settings.hwDecode,
                    activeThumbColor: settings.accent,
                    onChanged: (v) => settings.setHwDecode(v),
                  ),
                ),

                // ── Parental Control ───────────────────────────────────────
                _sectionHeader(l10n.get('settings_parental')),
                _settingsTile(
                  icon: Icons.lock,
                  title: l10n.get('settings_parental_enable'),
                  subtitle: settings.parentalEnabled ? 'Enabled' : 'Disabled',
                  trailing: Switch(
                    value: settings.parentalEnabled,
                    activeThumbColor: settings.accent,
                    onChanged: (v) {
                      if (v) {
                        _setupParentalPin(settings);
                      } else {
                        _disableParental(settings);
                      }
                    },
                  ),
                ),
                if (settings.parentalEnabled) ...[
                  const SizedBox(height: 8),
                  _settingsTile(
                    icon: Icons.pin,
                    title: l10n.get('settings_parental_pin'),
                    onTap: () => _setupParentalPin(settings),
                    trailing: const Icon(Icons.chevron_right, color: Colors.white24),
                  ),
                  const SizedBox(height: 8),
                  _settingsTile(
                    icon: Icons.lock,
                    title: l10n.get('settings_parental_lock_cats'),
                    subtitle: '${settings.lockedCategories.length} locked',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ParentalLockScreen()),
                    ),
                    trailing: const Icon(Icons.chevron_right, color: Colors.white24),
                  ),
                ],

                // ── Storage ───────────────────────────────────────────────
                _sectionHeader(l10n.get('settings_storage')),
                _settingsTile(
                  icon: Icons.history,
                  title: l10n.get('settings_clear_history'),
                  subtitle: l10n.get('settings_clear_history_sub'),
                  onTap: _clearHistory,
                  trailing: const Icon(Icons.chevron_right, color: Colors.white24),
                ),

                // ── Update ────────────────────────────────────────────────
                _sectionHeader('Update'),
                _settingsTile(
                  icon: Icons.system_update_alt,
                  title: 'Check for Updates',
                  subtitle: 'Current version: v1.0.0',
                  onTap: () => _checkForUpdate(context),
                  trailing: const Icon(Icons.chevron_right, color: Colors.white24),
                ),

                // ── Version ───────────────────────────────────────────────
                const SizedBox(height: 24),
                Center(
                  child: Column(children: [
                    const Icon(Icons.connected_tv, color: Colors.white12, size: 32),
                    const SizedBox(height: 6),
                    Text('Wallyt IPTV  v1.0.0',
                        style: TextStyle(color: Colors.white12, fontSize: 12)),
                  ]),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Pickers ─────────────────────────────────────────────────────────────
  void _showColorPicker(AppSettings s) {
    final colors = {
      'deepOrange': Colors.deepOrange,
      'blue': Colors.blue,
      'green': Colors.green,
      'purple': Colors.purple,
      'red': Colors.red,
      'teal': Colors.teal,
    };
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: const Text('Accent Color', style: TextStyle(color: Colors.white)),
        content: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: colors.entries.map((e) {
            final selected = s.accentColor == e.key;
            return GestureDetector(
              onTap: () { s.setAccentColor(e.key); Navigator.pop(context); },
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: e.value,
                  shape: BoxShape.circle,
                  border: selected ? Border.all(color: Colors.white, width: 3) : null,
                ),
                child: selected
                    ? const Icon(Icons.check, color: Colors.white, size: 20)
                    : null,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  String _languageLabel(String code) {
    switch (code) {
      case 'tr': return 'Türkçe';
      case 'ar': return 'العربية';
      case 'hi': return 'हिन्दी';
      case 'ur': return 'اردو';
      case 'id': return 'Bahasa Indonesia';
      case 'bn': return 'বাংলা';
      default:   return 'English';
    }
  }

  void _showLanguagePicker(AppSettings s) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: const Text('Language', style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _langOption(s, 'en', '🇬🇧  English'),
              const SizedBox(height: 8),
              _langOption(s, 'tr', '🇹🇷  Türkçe'),
              const SizedBox(height: 8),
              _langOption(s, 'ar', '🇸🇦  العربية'),
              const SizedBox(height: 8),
              _langOption(s, 'hi', '🇮🇳  हिन्दी'),
              const SizedBox(height: 8),
              _langOption(s, 'ur', '🇵🇰  اردو'),
              const SizedBox(height: 8),
              _langOption(s, 'id', '🇮🇩  Bahasa Indonesia'),
              const SizedBox(height: 8),
              _langOption(s, 'bn', '🇧🇩  বাংলা'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _langOption(AppSettings s, String code, String label) {
    final selected = s.language == code;
    return InkWell(
      onTap: () { s.setLanguage(code); Navigator.pop(context); },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? Colors.deepOrange.withValues(alpha: 0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: selected ? Colors.deepOrange : Colors.white12),
        ),
        child: Row(
          children: [
            Expanded(child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 15))),
            if (selected) const Icon(Icons.check, color: Colors.deepOrange, size: 18),
          ],
        ),
      ),
    );
  }

  void _showStreamModePicker(AppSettings s, AppL10n l10n) {
    final modes = ['auto', 'hls', 'ts'];
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: Text(l10n.get('settings_stream_mode'),
            style: const TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: modes.map((m) {
            final selected = s.streamMode == m;
            return InkWell(
              onTap: () { s.setStreamMode(m); Navigator.pop(context); },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(_streamModeLabel(m, l10n),
                          style: TextStyle(
                            color: selected ? Colors.deepOrange : Colors.white,
                            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                          )),
                    ),
                    if (selected) const Icon(Icons.check, color: Colors.deepOrange, size: 18),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showBufferPicker(AppSettings s) {
    final values = [2, 5, 10, 15, 30];
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: const Text('Buffer Size', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: values.map((v) {
            final selected = s.bufferSeconds == v;
            return InkWell(
              onTap: () { s.setBufferSeconds(v); Navigator.pop(context); },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text('$v seconds',
                          style: TextStyle(
                            color: selected ? Colors.deepOrange : Colors.white,
                            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                          )),
                    ),
                    if (selected) const Icon(Icons.check, color: Colors.deepOrange, size: 18),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  String _streamModeLabel(String mode, AppL10n l10n) {
    switch (mode) {
      case 'hls': return l10n.get('stream_hls');
      case 'ts': return l10n.get('stream_ts');
      default: return l10n.get('stream_auto');
    }
  }
}
