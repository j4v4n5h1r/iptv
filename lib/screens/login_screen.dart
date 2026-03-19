import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../services/xtream_service.dart';
import '../services/m3u_service.dart';
import '../services/app_settings.dart';
import '../services/app_localizations.dart';
import '../models/channel.dart';
import 'home_screen.dart';
import 'player_screen.dart';
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
  // Direkt stream URL mi? (.m3u8, .ts, .mp4, rtmp, rtsp vb.)
  bool _isDirectStreamUrl(String url) {
    final lower = url.toLowerCase();
    // Sadece uzantı ve protokol bazlı kontrol — /live/ /stream/ içeren
    // URL'ler M3U playlist de olabilir, bu yüzden bu kontrolü kaldırdık.
    return lower.endsWith('.m3u8') ||
        lower.endsWith('.ts') ||
        lower.endsWith('.mp4') ||
        lower.endsWith('.mkv') ||
        lower.startsWith('rtmp://') ||
        lower.startsWith('rtsp://');
  }

  Future<void> _loginM3u() async {
    final url = _m3uUrlCtrl.text.trim();
    if (url.isEmpty) {
      _snack('Please enter M3U URL or stream link');
      return;
    }

    // Direkt stream link — playlist yüklemeye gerek yok, player'a yönlendir
    if (_isDirectStreamUrl(url)) {
      final name = _m3uNameCtrl.text.trim().isNotEmpty
          ? _m3uNameCtrl.text.trim()
          : url.split('/').last.split('?').first;
      final channel = Channel(
        name: name.isEmpty ? 'Stream' : name,
        url: url,
        streamType: 'live',
      );
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PlayerScreen(
            channel: channel,
            channels: [channel],
            isMovie: false,
            onFavoriteToggled: (_) {},
          ),
        ),
      );
      return;
    }

    // M3U playlist URL — URL formatını kontrol et, sunucudan doğrulama yapma
    // Bazı sunucular VLC User-Agent ile 401 döner ama stream çalışır
    setState(() => _isLoading = true);
    final channels = await M3uService.fetchAndParse(url);
    if (!mounted) return;
    setState(() => _isLoading = false);

    final name = _m3uNameCtrl.text.trim().isNotEmpty
        ? _m3uNameCtrl.text.trim()
        : Uri.parse(url).host.isNotEmpty
            ? Uri.parse(url).host
            : 'M3U Playlist';

    if (channels != null && channels.isNotEmpty) {
      // Başarıyla yüklendi
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
    } else if (channels != null && channels.isEmpty) {
      // Sunucu 401/403 veya auth error döndürdü — yine de kaydet, player'da denesin
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
      // null — network hatası, URL'ye ulaşılamıyor
      _snack('Could not load playlist. Check the URL or your internet connection.');
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
    return ListenableBuilder(
      listenable: focusNode,
      builder: (context, _) {
        final focused = focusNode.hasFocus;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: focused ? Border.all(color: Colors.deepOrange, width: 2) : null,
          ),
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            obscureText: obscure,
            keyboardType: keyboard,
            textInputAction: nextFocus != null ? TextInputAction.next : TextInputAction.done,
            style: const TextStyle(color: Colors.white),
            onEditingComplete: () {
              if (nextFocus != null) {
                nextFocus.requestFocus();
              } else {
                focusNode.unfocus();
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
      },
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
  Widget _buildXtreamTab(AppL10n l10n) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 24),
          _buildTextField(
            controller: _serverCtrl,
            focusNode: _serverFocus,
            label: l10n.get('login_server'),
            keyboard: TextInputType.url,
            nextFocus: _userFocus,
          ),
          const SizedBox(height: 12),
          _buildTextField(
            controller: _userCtrl,
            focusNode: _userFocus,
            label: l10n.get('login_username'),
            nextFocus: _passFocus,
          ),
          const SizedBox(height: 12),
          _buildTextField(
            controller: _passCtrl,
            focusNode: _passFocus,
            label: l10n.get('login_password'),
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
          _buildLoginButton(_xtreamLoginFocus, _loginXtream, l10n.get('login_connect')),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ── M3U tab ─────────────────────────────────────────────────────────────────
  Widget _buildM3uTab(AppL10n l10n) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 24),
          _buildTextField(
            controller: _m3uUrlCtrl,
            focusNode: _m3uUrlFocus,
            label: l10n.get('login_m3u_url'),
            keyboard: TextInputType.url,
            nextFocus: _m3uNameFocus,
          ),
          const SizedBox(height: 12),
          _buildTextField(
            controller: _m3uNameCtrl,
            focusNode: _m3uNameFocus,
            label: l10n.get('login_m3u_name'),
            nextFocus: _m3uLoginFocus,
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'e.g. http://SERVER/get.php?username=X&password=Y&type=m3u_plus',
                  style: const TextStyle(color: Colors.white24, fontSize: 10),
                ),
                const SizedBox(height: 4),
                Text(
                  'or: http://SERVER/live/user/pass/ID.m3u8',
                  style: const TextStyle(color: Colors.white24, fontSize: 10),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildLoginButton(_m3uLoginFocus, _loginM3u, l10n.get('login_load')),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n(Provider.of<AppSettings>(context).language);
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: FocusTraversalGroup(
            policy: ReadingOrderTraversalPolicy(),
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
                        _buildXtreamTab(l10n),
                        _buildM3uTab(l10n),
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
                          label: Text(l10n.get('login_saved'),
                              style: const TextStyle(color: Colors.white70)),
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
    );
  }
}

