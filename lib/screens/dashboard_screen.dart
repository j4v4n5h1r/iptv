import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/m3u_service.dart';
import 'home_screen.dart';
import 'recents_screen.dart';
import 'settings_screen.dart';
import 'login_screen.dart';

// Renk paleti — HTML'den alındı
const _kBg     = Color(0xFF0B1118);
const _kCard   = Color(0xFF1A242D);
const _kCardHover = Color(0xFF25313D);
const _kBlue   = Color(0xFF60A5FA); // blue-400
const _kBorder = Color(0xFF2A3542);

class DashboardScreen extends StatefulWidget {
  final String sessionType;
  const DashboardScreen({super.key, this.sessionType = 'xtream'});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _liveFocus     = FocusNode();
  final _moviesFocus   = FocusNode();
  final _seriesFocus   = FocusNode();
  final _cacheFocus    = FocusNode();
  final _playlistFocus = FocusNode();
  final _settingsFocus = FocusNode();
  final _reloadFocus   = FocusNode();
  final _exitFocus     = FocusNode();

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
    if (section == 'recents') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const RecentsScreen()));
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HomeScreen(sessionType: widget.sessionType, initialTab: section),
      ),
    );
  }

  void _reload() async {
    if (_isM3u) {
      final playlist = await M3uService.getActive();
      if (playlist != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reloading playlist...')));
        await M3uService.fetchAndParse(playlist.url);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Playlist reloaded')));
      }
    } else {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reloading channels...')));
    }
  }

  void _exit() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _kCard,
        title: const Text('Exit', style: TextStyle(color: Colors.white)),
        content: const Text('Are you sure you want to exit?',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
          TextButton(onPressed: () => SystemNavigator.pop(),
              child: const Text('Exit', style: TextStyle(color: _kBlue))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: {
        LogicalKeySet(LogicalKeyboardKey.arrowDown):  const DirectionalFocusIntent(TraversalDirection.down),
        LogicalKeySet(LogicalKeyboardKey.arrowUp):    const DirectionalFocusIntent(TraversalDirection.up),
        LogicalKeySet(LogicalKeyboardKey.arrowLeft):  const DirectionalFocusIntent(TraversalDirection.left),
        LogicalKeySet(LogicalKeyboardKey.arrowRight): const DirectionalFocusIntent(TraversalDirection.right),
        LogicalKeySet(LogicalKeyboardKey.select):     const ActivateIntent(),
        LogicalKeySet(LogicalKeyboardKey.enter):      const ActivateIntent(),
      },
      child: Scaffold(
        backgroundColor: _kBg,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: Column(
              children: [
                // ── Logo / Title ──────────────────────────────────────────
                Column(
                  children: [
                    RichText(
                      text: const TextSpan(
                        style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 4),
                        children: [
                          TextSpan(text: 'WALLYT', style: TextStyle(color: _kBlue)),
                          TextSpan(text: 'TV', style: TextStyle(color: Colors.white)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),


                // ── Main grid ────────────────────────────────────────────
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Sol: Live TV büyük kart (5/12)
                      Expanded(
                        flex: 5,
                        child: _BigCard(
                          focusNode: _liveFocus,
                          icon: Icons.tv,
                          label: 'Live TV',
                          onPressed: () => _openSection('live'),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Orta: 2x2 grid (4/12)
                      Expanded(
                        flex: 4,
                        child: _isM3u
                            ? _GridFour(
                                items: [
                                  _GridItem(focusNode: _cacheFocus,    icon: Icons.history,       label: 'Recents',
                                    onPressed: () => _openSection('recents')),
                                  _GridItem(focusNode: _playlistFocus, icon: Icons.people,        label: 'Change\nPlaylist',
                                    onPressed: () => Navigator.pushReplacement(context,
                                      MaterialPageRoute(builder: (_) => const LoginScreen()))),
                                  _GridItem(focusNode: _moviesFocus,   icon: Icons.play_circle,   label: 'Movies',    onPressed: () {}),
                                  _GridItem(focusNode: _seriesFocus,   icon: Icons.movie_filter,  label: 'Series',    onPressed: () {}),
                                ],
                              )
                            : _GridFour(
                                items: [
                                  _GridItem(focusNode: _moviesFocus,   icon: Icons.play_circle,   label: 'Movies',           onPressed: () => _openSection('vod')),
                                  _GridItem(focusNode: _seriesFocus,   icon: Icons.movie_filter,  label: 'Series',           onPressed: () => _openSection('series')),
                                  _GridItem(focusNode: _cacheFocus,    icon: Icons.history,       label: 'Recents',
                                    onPressed: () => _openSection('recents')),
                                  _GridItem(focusNode: _playlistFocus, icon: Icons.people,        label: 'Change\nPlaylist',
                                    onPressed: () => Navigator.pushReplacement(context,
                                      MaterialPageRoute(builder: (_) => const LoginScreen()))),
                                ],
                              ),
                      ),
                      const SizedBox(width: 12),

                      // Sağ: aksiyon butonları (3/12)
                      SizedBox(
                        width: 180,
                        child: Column(
                          children: [
                            _ActionBtn(focusNode: _settingsFocus, icon: Icons.settings,     label: 'Settings',
                              onPressed: () => Navigator.push(context,
                                MaterialPageRoute(builder: (_) => const SettingsScreen()))),
                            const SizedBox(height: 10),
                            _ActionBtn(focusNode: _reloadFocus,   icon: Icons.refresh,      label: 'Reload',    onPressed: _reload),
                            const SizedBox(height: 10),
                            _ActionBtn(focusNode: _exitFocus,     icon: Icons.exit_to_app,  label: 'Exit',      onPressed: _exit),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Footer ───────────────────────────────────────────────
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _FooterItem(icon: Icons.telegram, iconColor: _kBlue,                    text: 't.me/Indiantvstore'),
                    const SizedBox(width: 32),
                    _FooterItem(icon: Icons.headset,  iconColor: Color(0xFFFBBF24),          text: 'www.indiantvstore.chat'),
                    const SizedBox(width: 32),
                    _FooterItem(icon: Icons.phone,    iconColor: Color(0xFFF59E0B),          text: '+44 20 7946 0958'),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Big card (Live TV) ────────────────────────────────────────────────────────
class _BigCard extends StatelessWidget {
  final FocusNode focusNode;
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _BigCard({required this.focusNode, required this.icon, required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return FocusableActionDetector(
      focusNode: focusNode,
      actions: {ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) => onPressed())},
      child: ListenableBuilder(
        listenable: focusNode,
        builder: (_, __) {
          final focused = focusNode.hasFocus;
          return GestureDetector(
            onTap: onPressed,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                color: focused ? _kCardHover : _kCard,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: focused ? _kBlue : _kBorder, width: focused ? 2 : 1),
                boxShadow: focused ? [BoxShadow(color: _kBlue.withValues(alpha: 0.25), blurRadius: 20)] : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: focused ? _kBlue : Colors.white70, size: 64),
                  const SizedBox(height: 16),
                  Text(label,
                    style: TextStyle(
                      color: focused ? Colors.white : Colors.white70,
                      fontSize: 22,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 2,
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

// ── 2x2 Grid ────────────────────────────────────────────────────────────────
class _GridItem {
  final FocusNode focusNode;
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  const _GridItem({required this.focusNode, required this.icon, required this.label, required this.onPressed});
}

class _GridFour extends StatelessWidget {
  final List<_GridItem> items;
  const _GridFour({required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(child: Row(children: [
          Expanded(child: _SmallCard(item: items[0])),
          const SizedBox(width: 10),
          Expanded(child: _SmallCard(item: items[1])),
        ])),
        const SizedBox(height: 10),
        Expanded(child: Row(children: [
          Expanded(child: _SmallCard(item: items[2])),
          const SizedBox(width: 10),
          Expanded(child: _SmallCard(item: items[3])),
        ])),
      ],
    );
  }
}

class _SmallCard extends StatelessWidget {
  final _GridItem item;
  const _SmallCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return FocusableActionDetector(
      focusNode: item.focusNode,
      actions: {ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) => item.onPressed())},
      child: ListenableBuilder(
        listenable: item.focusNode,
        builder: (_, __) {
          final focused = item.focusNode.hasFocus;
          return GestureDetector(
            onTap: item.onPressed,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                color: focused ? _kCardHover : _kCard,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: focused ? _kBlue : _kBorder, width: focused ? 2 : 1),
                boxShadow: focused ? [BoxShadow(color: _kBlue.withValues(alpha: 0.2), blurRadius: 12)] : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(item.icon, color: focused ? _kBlue : Colors.white60, size: 32),
                  const SizedBox(height: 8),
                  Text(item.label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: focused ? Colors.white : Colors.white60,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1,
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

// ── Footer item ───────────────────────────────────────────────────────────────
class _FooterItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String text;
  const _FooterItem({required this.icon, required this.iconColor, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: iconColor, size: 16),
        const SizedBox(width: 6),
        Text(text, style: const TextStyle(color: Colors.white38, fontSize: 11)),
      ],
    );
  }
}

// ── Action button (sağ kolon) ────────────────────────────────────────────────
class _ActionBtn extends StatelessWidget {
  final FocusNode focusNode;
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _ActionBtn({required this.focusNode, required this.icon, required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return FocusableActionDetector(
      focusNode: focusNode,
      actions: {ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) => onPressed())},
      child: ListenableBuilder(
        listenable: focusNode,
        builder: (_, __) {
          final focused = focusNode.hasFocus;
          return GestureDetector(
            onTap: onPressed,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: focused ? _kCardHover : _kCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: focused ? _kBlue : _kBorder, width: focused ? 2 : 1),
              ),
              child: Row(
                children: [
                  Icon(icon, color: focused ? _kBlue : Colors.white54, size: 20),
                  const SizedBox(width: 12),
                  Text(label,
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
