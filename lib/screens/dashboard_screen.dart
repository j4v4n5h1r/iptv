import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/app_settings.dart';
import '../services/m3u_service.dart';
import 'home_screen.dart';
import 'settings_screen.dart';
import 'login_screen.dart';

class DashboardScreen extends StatefulWidget {
  final String sessionType; // 'xtream' or 'm3u'
  const DashboardScreen({super.key, this.sessionType = 'xtream'});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // Focus nodes
  final _liveFocus    = FocusNode();
  final _moviesFocus  = FocusNode();
  final _seriesFocus  = FocusNode();
  final _cacheFocus   = FocusNode();
  final _playlistFocus = FocusNode();
  final _settingsFocus = FocusNode();
  final _reloadFocus  = FocusNode();
  final _exitFocus    = FocusNode();

  bool get _isM3u => widget.sessionType == 'm3u';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
      _liveFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _liveFocus.dispose();
    _moviesFocus.dispose();
    _seriesFocus.dispose();
    _cacheFocus.dispose();
    _playlistFocus.dispose();
    _settingsFocus.dispose();
    _reloadFocus.dispose();
    _exitFocus.dispose();
    super.dispose();
  }

  void _openSection(String section) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HomeScreen(
          sessionType: widget.sessionType,
          initialTab: section,
        ),
      ),
    );
  }

  void _reload() async {
    if (_isM3u) {
      final playlist = await M3uService.getActive();
      if (playlist != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reloading playlist...')),
        );
        await M3uService.fetchAndParse(playlist.url);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Playlist reloaded')),
          );
        }
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reloading channels...')),
        );
      }
    }
  }

  void _exit() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Exit', style: TextStyle(color: Colors.white)),
        content: const Text('Are you sure you want to exit?',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => SystemNavigator.pop(),
            child: const Text('Exit', style: TextStyle(color: Colors.deepOrange)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accent = Provider.of<AppSettings>(context).accent;

    return Shortcuts(
      shortcuts: {
        LogicalKeySet(LogicalKeyboardKey.arrowDown): const NextFocusIntent(),
        LogicalKeySet(LogicalKeyboardKey.arrowUp): const PreviousFocusIntent(),
        LogicalKeySet(LogicalKeyboardKey.arrowLeft): const PreviousFocusIntent(),
        LogicalKeySet(LogicalKeyboardKey.arrowRight): const NextFocusIntent(),
        LogicalKeySet(LogicalKeyboardKey.select): const ActivateIntent(),
        LogicalKeySet(LogicalKeyboardKey.enter): const ActivateIntent(),
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0A14),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Icon(Icons.connected_tv, color: accent, size: 36),
                    const SizedBox(width: 12),
                    Text(
                      'Wallyt IPTV',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // Main content
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left: big grid buttons
                      Expanded(
                        flex: 3,
                        child: Column(
                          children: [
                            // Live TV — big card
                            Expanded(
                              flex: 2,
                              child: _DashboardCard(
                                focusNode: _liveFocus,
                                icon: Icons.live_tv,
                                label: 'Live TV',
                                accent: accent,
                                large: true,
                                onPressed: () => _openSection('live'),
                              ),
                            ),
                            const SizedBox(height: 12),
                            // Movies + Series
                            if (!_isM3u) ...[
                              Expanded(
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: _DashboardCard(
                                        focusNode: _moviesFocus,
                                        icon: Icons.movie,
                                        label: 'Movies',
                                        accent: accent,
                                        onPressed: () => _openSection('vod'),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _DashboardCard(
                                        focusNode: _seriesFocus,
                                        icon: Icons.video_library,
                                        label: 'Series',
                                        accent: accent,
                                        onPressed: () => _openSection('series'),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ] else ...[
                              Expanded(
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: _DashboardCard(
                                        focusNode: _cacheFocus,
                                        icon: Icons.clear_all,
                                        label: 'Clear Cache',
                                        accent: accent,
                                        onPressed: () async {
                                          await M3uService.clearCache();
                                          if (mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(content: Text('Cache cleared')),
                                            );
                                          }
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _DashboardCard(
                                        focusNode: _playlistFocus,
                                        icon: Icons.playlist_play,
                                        label: 'Change Playlist',
                                        accent: accent,
                                        onPressed: () => Navigator.pushReplacement(
                                          context,
                                          MaterialPageRoute(builder: (_) => const LoginScreen()),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                      const SizedBox(width: 16),

                      // Right: action buttons
                      SizedBox(
                        width: 200,
                        child: Column(
                          children: [
                            _ActionButton(
                              focusNode: _settingsFocus,
                              icon: Icons.settings,
                              label: 'Settings',
                              accent: accent,
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const SettingsScreen()),
                              ),
                            ),
                            const SizedBox(height: 10),
                            _ActionButton(
                              focusNode: _reloadFocus,
                              icon: Icons.refresh,
                              label: 'Reload',
                              accent: accent,
                              onPressed: _reload,
                            ),
                            const SizedBox(height: 10),
                            _ActionButton(
                              focusNode: _exitFocus,
                              icon: Icons.exit_to_app,
                              label: 'Exit',
                              accent: accent,
                              onPressed: _exit,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Big grid card ────────────────────────────────────────────────────────────
class _DashboardCard extends StatelessWidget {
  final FocusNode focusNode;
  final IconData icon;
  final String label;
  final Color accent;
  final bool large;
  final VoidCallback onPressed;

  const _DashboardCard({
    required this.focusNode,
    required this.icon,
    required this.label,
    required this.accent,
    required this.onPressed,
    this.large = false,
  });

  @override
  Widget build(BuildContext context) {
    return FocusableActionDetector(
      focusNode: focusNode,
      onShowFocusHighlight: (_) {},
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) => onPressed()),
      },
      child: ListenableBuilder(
        listenable: focusNode,
        builder: (context, _) {
          final focused = focusNode.hasFocus;
          return GestureDetector(
            onTap: onPressed,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              decoration: BoxDecoration(
                color: focused
                    ? accent.withValues(alpha: 0.25)
                    : const Color(0xFF161624),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: focused ? accent : Colors.white12,
                  width: focused ? 2 : 1,
                ),
                boxShadow: focused
                    ? [BoxShadow(color: accent.withValues(alpha: 0.3), blurRadius: 16)]
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon,
                      color: focused ? accent : Colors.white60,
                      size: large ? 52 : 36),
                  const SizedBox(height: 10),
                  Text(
                    label,
                    style: TextStyle(
                      color: focused ? Colors.white : Colors.white70,
                      fontSize: large ? 20 : 15,
                      fontWeight: focused ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Small action button ──────────────────────────────────────────────────────
class _ActionButton extends StatelessWidget {
  final FocusNode focusNode;
  final IconData icon;
  final String label;
  final Color accent;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.focusNode,
    required this.icon,
    required this.label,
    required this.accent,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return FocusableActionDetector(
      focusNode: focusNode,
      onShowFocusHighlight: (_) {},
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) => onPressed()),
      },
      child: ListenableBuilder(
        listenable: focusNode,
        builder: (context, _) {
          final focused = focusNode.hasFocus;
          return GestureDetector(
            onTap: onPressed,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: focused
                    ? accent.withValues(alpha: 0.15)
                    : const Color(0xFF161624),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: focused ? accent : Colors.white12,
                  width: focused ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(icon, color: focused ? accent : Colors.white54, size: 22),
                  const SizedBox(width: 12),
                  Text(
                    label,
                    style: TextStyle(
                      color: focused ? Colors.white : Colors.white70,
                      fontSize: 15,
                      fontWeight: focused ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
