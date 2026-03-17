import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../services/xtream_service.dart';
import '../services/m3u_service.dart';
import 'home_screen.dart';
import 'playlists_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  // Xtream fields
  final _serverCtrl = TextEditingController();
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  // M3U fields
  final _m3uUrlCtrl = TextEditingController();
  final _m3uNameCtrl = TextEditingController();

  bool _isLoading = false;
  bool _obscurePass = true;

  // Focus nodes — Xtream
  final _serverFocus = FocusNode();
  final _userFocus = FocusNode();
  final _passFocus = FocusNode();
  final _xtreamLoginFocus = FocusNode();

  // Focus nodes — M3U
  final _m3uUrlFocus = FocusNode();
  final _m3uNameFocus = FocusNode();
  final _m3uLoginFocus = FocusNode();

  final _savedFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _serverCtrl.dispose();
    _userCtrl.dispose();
    _passCtrl.dispose();
    _m3uUrlCtrl.dispose();
    _m3uNameCtrl.dispose();
    _serverFocus.dispose();
    _userFocus.dispose();
    _passFocus.dispose();
    _xtreamLoginFocus.dispose();
    _m3uUrlFocus.dispose();
    _m3uNameFocus.dispose();
    _m3uLoginFocus.dispose();
    _savedFocus.dispose();
    super.dispose();
  }

  // ── Xtream login ────────────────────────────────────────────────────────────
  Future<void> _loginXtream() async {
    final server = _serverCtrl.text.trim();
    final user = _userCtrl.text.trim();
    final pass = _passCtrl.text.trim();

    if (server.isEmpty || user.isEmpty || pass.isEmpty) {
      _snack('Please fill all fields');
      return;
    }
    setState(() => _isLoading = true);
    final xtream = Provider.of<XtreamService>(context, listen: false);
    final ok = await xtream.login(server, user, pass);
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (ok) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const HomeScreen(sessionType: 'xtream'),
        ),
      );
    } else {
      _snack('Login failed. Check server, username and password.');
    }
  }

  // ── M3U login ───────────────────────────────────────────────────────────────
  Future<void> _loginM3u() async {
    final url = _m3uUrlCtrl.text.trim();
    if (url.isEmpty) {
      _snack('Please enter M3U URL');
      return;
    }
    setState(() => _isLoading = true);
    final ok = await M3uService.validate(url);
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (ok) {
      final name = _m3uNameCtrl.text.trim().isNotEmpty
          ? _m3uNameCtrl.text.trim()
          : Uri.parse(url).host.isNotEmpty
              ? Uri.parse(url).host
              : 'M3U Playlist';
      final playlist = M3uPlaylist(name: name, url: url);
      await M3uService.savePlaylist(playlist);
      await M3uService.setActive(playlist);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const HomeScreen(sessionType: 'm3u'),
        ),
      );
    } else {
      _snack('Could not load playlist. Check the URL.');
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ── Widgets ─────────────────────────────────────────────────────────────────

  Widget _buildTextField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String label,
    bool obscure = false,
    TextInputType keyboard = TextInputType.text,
    Widget? suffix,
    FocusNode? nextFocus,
  }) {
    return Focus(
      focusNode: focusNode,
      child: Builder(builder: (ctx) {
        final focused = focusNode.hasFocus;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: focused ? Border.all(color: Colors.deepOrange, width: 2) : null,
          ),
          child: TextField(
            controller: controller,
            obscureText: obscure,
            keyboardType: keyboard,
            style: const TextStyle(color: Colors.white),
            onSubmitted: (_) {
              if (nextFocus != null) {
                nextFocus.requestFocus();
              }
            },
            decoration: InputDecoration(
              labelText: label,
              labelStyle: const TextStyle(color: Colors.white70),
              filled: true,
              fillColor: Colors.grey[850],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              suffixIcon: suffix,
            ),
          ),
        );
      }),
    );
  }

  Widget _buildLoginButton(FocusNode focusNode, VoidCallback onPressed, String label) {
    return FocusableActionDetector(
      focusNode: focusNode,
      onShowFocusHighlight: (_) => setState(() {}),
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) => onPressed(),
        ),
      },
      child: Builder(builder: (ctx) {
        final focused = focusNode.hasFocus;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: focused ? Border.all(color: Colors.white, width: 2) : null,
            boxShadow: focused
                ? [BoxShadow(color: Colors.deepOrange.withValues(alpha: 0.5), blurRadius: 8)]
                : null,
          ),
          child: ElevatedButton(
            onPressed: _isLoading ? null : onPressed,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: focused ? Colors.deepOrange.shade700 : Colors.deepOrange,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : Text(label, style: const TextStyle(fontSize: 17, color: Colors.white)),
          ),
        );
      }),
    );
  }

  // ── Xtream tab ──────────────────────────────────────────────────────────────
  Widget _buildXtreamTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 24),
          _buildTextField(
            controller: _serverCtrl,
            focusNode: _serverFocus,
            label: 'Server URL  (e.g. http://example.com)',
            keyboard: TextInputType.url,
            nextFocus: _userFocus,
          ),
          const SizedBox(height: 12),
          _buildTextField(
            controller: _userCtrl,
            focusNode: _userFocus,
            label: 'Username',
            nextFocus: _passFocus,
          ),
          const SizedBox(height: 12),
          _buildTextField(
            controller: _passCtrl,
            focusNode: _passFocus,
            label: 'Password',
            obscure: _obscurePass,
            nextFocus: _xtreamLoginFocus,
            suffix: IconButton(
              icon: Icon(
                _obscurePass ? Icons.visibility_off : Icons.visibility,
                color: Colors.white38,
              ),
              onPressed: () => setState(() => _obscurePass = !_obscurePass),
            ),
          ),
          const SizedBox(height: 24),
          _buildLoginButton(_xtreamLoginFocus, _loginXtream, 'Connect'),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ── M3U tab ─────────────────────────────────────────────────────────────────
  Widget _buildM3uTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 24),
          _buildTextField(
            controller: _m3uUrlCtrl,
            focusNode: _m3uUrlFocus,
            label: 'M3U / M3U8 URL',
            keyboard: TextInputType.url,
            nextFocus: _m3uNameFocus,
          ),
          const SizedBox(height: 12),
          _buildTextField(
            controller: _m3uNameCtrl,
            focusNode: _m3uNameFocus,
            label: 'Playlist name (optional)',
            nextFocus: _m3uLoginFocus,
          ),
          const SizedBox(height: 6),
          const Padding(
            padding: EdgeInsets.only(left: 4),
            child: Text(
              'Paste any direct M3U/M3U8 link. No account needed.',
              style: TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ),
          const SizedBox(height: 24),
          _buildLoginButton(_m3uLoginFocus, _loginM3u, 'Load Playlist'),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Shortcuts(
          shortcuts: {
            LogicalKeySet(LogicalKeyboardKey.arrowDown): const NextFocusIntent(),
            LogicalKeySet(LogicalKeyboardKey.arrowUp): const PreviousFocusIntent(),
            LogicalKeySet(LogicalKeyboardKey.select): const ActivateIntent(),
            LogicalKeySet(LogicalKeyboardKey.enter): const ActivateIntent(),
          },
          child: FocusTraversalGroup(
            policy: OrderedTraversalPolicy(),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 32),
                  // Logo
                  const Icon(Icons.connected_tv, color: Colors.deepOrange, size: 64),
                  const SizedBox(height: 10),
                  const Text(
                    'Wallyt IPTV',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Tabs
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 32),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A2E),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      indicatorColor: Colors.deepOrange,
                      labelColor: Colors.deepOrange,
                      unselectedLabelColor: Colors.white38,
                      indicatorSize: TabBarIndicatorSize.tab,
                      dividerColor: Colors.transparent,
                      tabs: const [
                        Tab(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.dns, size: 16),
                              SizedBox(width: 6),
                              Text('Xtream Codes'),
                            ],
                          ),
                        ),
                        Tab(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.link, size: 16),
                              SizedBox(width: 6),
                              Text('M3U URL'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Tab content
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildXtreamTab(),
                        _buildM3uTab(),
                      ],
                    ),
                  ),

                  // Saved playlists button
                  Padding(
                    padding: const EdgeInsets.fromLTRB(32, 0, 32, 32),
                    child: FocusableActionDetector(
                      focusNode: _savedFocus,
                      onShowFocusHighlight: (_) => setState(() {}),
                      actions: {
                        ActivateIntent: CallbackAction<ActivateIntent>(
                          onInvoke: (_) => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const PlaylistsScreen()),
                          ),
                        ),
                      },
                      child: Builder(builder: (ctx) {
                        final focused = _savedFocus.hasFocus;
                        return OutlinedButton.icon(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const PlaylistsScreen()),
                          ),
                          icon: const Icon(Icons.playlist_play, color: Colors.white70),
                          label: const Text('Saved Playlists',
                              style: TextStyle(color: Colors.white70)),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: BorderSide(
                                color: focused ? Colors.deepOrange : Colors.white24),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
