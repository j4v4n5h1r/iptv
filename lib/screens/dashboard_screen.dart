import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_screen.dart';
import 'recents_screen.dart';
import 'settings_screen.dart';
import 'activation_screen.dart';
import '../services/device_service.dart';

// Card sizes & spacing
const double _kCardSize    = 160.0;
const double _kCardGap     = 28.0;
const double _kCardStep    = _kCardSize + _kCardGap; // total slot width per card

class DashboardScreen extends StatefulWidget {
  final String sessionType;
  const DashboardScreen({super.key, this.sessionType = 'xtream'});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 1; // Live TV default

  late final List<_MenuItem> _items;

  @override
  void initState() {
    super.initState();
    _items = [
      _MenuItem(icon: Icons.settings,      label: 'Settings',  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()))),
      _MenuItem(icon: Icons.tv,            label: 'Live TV',   onPressed: () => _open('live')),
      _MenuItem(icon: Icons.movie,         label: 'Movies',    onPressed: () => _open('vod')),
      _MenuItem(icon: Icons.video_library, label: 'Series',    onPressed: () => _open('series')),
      _MenuItem(icon: Icons.favorite,      label: 'Favorites', onPressed: () => _open('favorites')),
      _MenuItem(icon: Icons.logout,        label: 'Logout',    onPressed: _logout),
    ];
  }

  void _open(String section) {
    if (section == 'recents') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const RecentsScreen()));
      return;
    }
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => HomeScreen(sessionType: widget.sessionType, initialTab: section),
    ));
  }

  void _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A0D00),
        title: const Text('Logout', style: TextStyle(color: Color(0xFFF5E6D0))),
        content: const Text('Are you sure?', style: TextStyle(color: Color(0xFFF5E6D0))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFFF5E6D0)))),
          TextButton(onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Logout', style: TextStyle(color: Colors.white))),
        ],
      ),
    );
    if (ok != true) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('xtream_server');
    await prefs.remove('xtream_username');
    await prefs.remove('xtream_password');
    await prefs.remove('m3u_active_url');
    final id = await DeviceService.getDeviceId();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(context,
      MaterialPageRoute(builder: (_) => ActivationScreen(deviceId: id)),
      (r) => false);
  }

  KeyEventResult _handleKey(KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final k = event.logicalKey;
    if (k == LogicalKeyboardKey.arrowLeft) {
      if (_selectedIndex > 0) { setState(() => _selectedIndex--); }
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.arrowRight) {
      if (_selectedIndex < _items.length - 1) { setState(() => _selectedIndex++); }
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.select || k == LogicalKeyboardKey.enter) {
      _items[_selectedIndex].onPressed();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: (_, event) => _handleKey(event),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // ── Background: dark wood photo ───────────────────────────
            Positioned.fill(
              child: Image.asset('assets/wood-bg-dark.jpg', fit: BoxFit.cover),
            ),
            Container(color: Colors.black.withValues(alpha: 0.40)),

            // ── VIEWNUX logo top-center ───────────────────────────────
            Positioned(
              top: 24, left: 0, right: 0,
              child: Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    children: [
                      ColorFiltered(
                        colorFilter: const ColorFilter.matrix([
                          0.55,0,0,0,0, 0,0.55,0,0,0, 0,0,0.55,0,0, 0,0,0,1,0
                        ]),
                        child: Image.asset('assets/wood-tile-warm.png',
                            width: 260, height: 56, fit: BoxFit.cover),
                      ),
                      Container(
                        width: 260, height: 56,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.30),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.tv, color: Color(0xFFF5E6D0), size: 22),
                            SizedBox(width: 10),
                            Text('VIEWNUX',
                              style: TextStyle(
                                color: Color(0xFFF5E6D0),
                                fontWeight: FontWeight.bold,
                                fontSize: 22,
                                letterSpacing: 5,
                                shadows: [Shadow(color: Colors.black, blurRadius: 6)],
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

            // ── Carousel + fixed center frame ─────────────────────────
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: _kCardSize + 32, // extra for glow overflow
                    child: LayoutBuilder(builder: (context, constraints) {
                      final screenW = MediaQuery.of(context).size.width;
                      return Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.center,
                        children: [
                          // Scrolling cards layer
                          AnimatedBuilder(
                            animation: const AlwaysStoppedAnimation(0),
                            builder: (_, __) => _buildCarousel(screenW),
                          ),
                          // Fixed center selection frame (always on top)
                          _buildSelectionFrame(),
                        ],
                      );
                    }),
                  ),
                  const SizedBox(height: 24),
                  // Label
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: Text(
                      _items[_selectedIndex].label.toUpperCase(),
                      key: ValueKey(_selectedIndex),
                      style: const TextStyle(
                        color: Color(0xFFF5E6D0),
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 4,
                        shadows: [Shadow(color: Colors.black, blurRadius: 10, offset: Offset(0, 2))],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCarousel(double screenW) {
    // Offset: how much the strip shifts so selected card is at center
    // Card center position in strip = _selectedIndex * _kCardStep + _kCardSize/2
    // We want that to be at screenW/2
    final double stripOffset = screenW / 2 - _selectedIndex * _kCardStep - _kCardSize / 2;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
      // Use transform to slide the row
      transform: Matrix4.translationValues(stripOffset, 0, 0),
      transformAlignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: List.generate(_items.length, (i) {
          final bool focused = i == _selectedIndex;
          return Padding(
            padding: EdgeInsets.only(right: i < _items.length - 1 ? _kCardGap : 0),
            child: _buildCard(i, focused),
          );
        }),
      ),
    );
  }

  Widget _buildCard(int index, bool focused) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      width: _kCardSize,
      height: _kCardSize,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: focused ? 0.3 : 0.7),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // Wood tile image — dimmed when not focused
            Positioned.fill(
              child: ColorFiltered(
                colorFilter: ColorFilter.matrix(focused
                    ? [1.05,0,0,0,0, 0,1.05,0,0,0, 0,0,1.05,0,0, 0,0,0,1,0]
                    : [0.65,0,0,0,0, 0,0.65,0,0,0, 0,0,0.65,0,0, 0,0,0,1,0]),
                child: Image.asset('assets/wood-tile-warm.png', fit: BoxFit.cover),
              ),
            ),
            // Top shine
            Positioned(
              top: 0, left: 0, right: 0,
              child: Container(
                height: _kCardSize * 0.38,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withValues(alpha: focused ? 0.20 : 0.08),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            // Bottom shadow
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: Container(
                height: _kCardSize * 0.3,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Colors.black.withValues(alpha: 0.45), Colors.transparent],
                  ),
                ),
              ),
            ),
            // Icon
            Center(
              child: AnimatedScale(
                scale: focused ? 1.0 : 0.75,
                duration: const Duration(milliseconds: 220),
                child: Icon(
                  _items[index].icon,
                  color: focused ? Colors.white : const Color(0xFF3B1A00),
                  size: 68,
                  shadows: focused
                      ? [const Shadow(color: Colors.black87, blurRadius: 14, offset: Offset(2, 4))]
                      : [const Shadow(color: Colors.white30, blurRadius: 4, offset: Offset(-1, -1)),
                         const Shadow(color: Colors.black54, blurRadius: 6, offset: Offset(2, 3))],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectionFrame() {
    return IgnorePointer(
      child: Container(
        width: _kCardSize + 12,
        height: _kCardSize + 12,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.85), width: 3),
          boxShadow: [
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.35),
              blurRadius: 40,
              spreadRadius: 8,
            ),
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.12),
              blurRadius: 80,
              spreadRadius: 20,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Model ─────────────────────────────────────────────────────────────────────
class _MenuItem {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  const _MenuItem({required this.icon, required this.label, required this.onPressed});
}
