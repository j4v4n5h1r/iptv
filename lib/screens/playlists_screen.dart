import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/xtream_service.dart';
import '../services/m3u_service.dart';
import '../models/channel.dart';
import 'dashboard_screen.dart';

class PlaylistsScreen extends StatefulWidget {
  const PlaylistsScreen({super.key});

  @override
  State<PlaylistsScreen> createState() => _PlaylistsScreenState();
}

class _PlaylistsScreenState extends State<PlaylistsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Xtream
  List<XtreamPlaylist> _xtreamPlaylists = [];
  // M3U
  List<M3uPlaylist> _m3uPlaylists = [];

  bool _loading = true;
  bool _switching = false;
  String? _activeXtreamServer;
  String? _activeXtreamUser;
  String? _activeM3uUrl;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final xtream = Provider.of<XtreamService>(context, listen: false);
    final xtreamList = await xtream.getSavedPlaylists();
    final m3uList = await M3uService.getSavedPlaylists();
    final activeM3u = await M3uService.getActive();
    if (mounted) {
      setState(() {
        _xtreamPlaylists = xtreamList;
        _m3uPlaylists = m3uList;
        _activeXtreamServer = xtream.serverUrl;
        _activeXtreamUser = xtream.username;
        _activeM3uUrl = activeM3u?.url;
        _loading = false;
      });
    }
  }

  // ── Xtream ───────────────────────────────────────────────────────────────
  Future<void> _switchXtream(XtreamPlaylist playlist) async {
    setState(() => _switching = true);
    final xtream = Provider.of<XtreamService>(context, listen: false);
    await xtream.switchPlaylist(playlist);
    // Also clear active M3U so session type = xtream
    await M3uService.clearActive();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const DashboardScreen(sessionType: 'xtream')),
        (route) => false,
      );
    }
  }

  Future<void> _deleteXtream(XtreamPlaylist playlist) async {
    final confirmed = await _confirmDelete(playlist.name, playlist.username);
    if (confirmed == true && mounted) {
      final xtream = Provider.of<XtreamService>(context, listen: false);
      await xtream.removePlaylist(playlist);
      await _load();
    }
  }

  // ── M3U ──────────────────────────────────────────────────────────────────
  Future<void> _switchM3u(M3uPlaylist playlist) async {
    setState(() => _switching = true);
    await M3uService.setActive(playlist);
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const DashboardScreen(sessionType: 'm3u')),
        (route) => false,
      );
    }
  }

  Future<void> _deleteM3u(M3uPlaylist playlist) async {
    final confirmed = await _confirmDelete(playlist.name, playlist.url);
    if (confirmed == true && mounted) {
      await M3uService.removePlaylist(playlist);
      await _load();
    }
  }

  // ── Shared ───────────────────────────────────────────────────────────────
  Future<bool?> _confirmDelete(String name, String sub) => showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A2E),
          title: const Text('Remove Playlist', style: TextStyle(color: Colors.white)),
          content: Text(
            'Remove "$name"\n$sub?',
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Remove', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Saved Playlists', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFE95420),
          labelColor: const Color(0xFFE95420),
          unselectedLabelColor: Colors.white54,
          tabs: const [
            Tab(icon: Icon(Icons.dns), text: 'Xtream'),
            Tab(icon: Icon(Icons.list), text: 'M3U'),
          ],
        ),
      ),
      body: _switching
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: const Color(0xFFE95420)),
                  SizedBox(height: 16),
                  Text('Switching playlist...', style: TextStyle(color: Colors.white54)),
                ],
              ),
            )
          : _loading
              ? const Center(child: CircularProgressIndicator(color: const Color(0xFFE95420)))
              : Shortcuts(
                  shortcuts: {
                    LogicalKeySet(LogicalKeyboardKey.arrowDown): const NextFocusIntent(),
                    LogicalKeySet(LogicalKeyboardKey.arrowUp): const PreviousFocusIntent(),
                    LogicalKeySet(LogicalKeyboardKey.select): const ActivateIntent(),
                    LogicalKeySet(LogicalKeyboardKey.enter): const ActivateIntent(),
                  },
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildXtreamTab(),
                      _buildM3uTab(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildXtreamTab() {
    if (_xtreamPlaylists.isEmpty) {
      return _buildEmpty('No Xtream playlists saved', 'Login with Xtream Codes to add one');
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _xtreamPlaylists.length,
      itemBuilder: (ctx, i) {
        final p = _xtreamPlaylists[i];
        final isActive = p.serverUrl == _activeXtreamServer && p.username == _activeXtreamUser;
        return _buildPlaylistTile(
          name: p.name,
          line1: p.serverUrl,
          line2: p.username,
          isActive: isActive,
          onTap: () => _switchXtream(p),
          onDelete: () => _deleteXtream(p),
          icon: Icons.dns,
        );
      },
    );
  }

  Widget _buildM3uTab() {
    if (_m3uPlaylists.isEmpty) {
      return _buildEmpty('No M3U playlists saved', 'Login with M3U URL to add one');
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _m3uPlaylists.length,
      itemBuilder: (ctx, i) {
        final p = _m3uPlaylists[i];
        final isActive = p.url == _activeM3uUrl;
        return _buildPlaylistTile(
          name: p.name,
          line1: p.url,
          isActive: isActive,
          onTap: () => _switchM3u(p),
          onDelete: () => _deleteM3u(p),
          icon: Icons.list,
        );
      },
    );
  }

  Widget _buildPlaylistTile({
    required String name,
    required String line1,
    String? line2,
    required bool isActive,
    required VoidCallback onTap,
    required VoidCallback onDelete,
    required IconData icon,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(
        color: isActive ? const Color(0xFFE95420).withValues(alpha: 0.15) : const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isActive ? const Color(0xFFE95420) : Colors.white12,
                width: isActive ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: isActive ? const Color(0xFFE95420) : Colors.white10,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isActive ? Icons.check : icon,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              style: TextStyle(
                                color: isActive ? const Color(0xFFE95420) : Colors.white,
                                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                                fontSize: 15,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isActive)
                            Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE95420),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text(
                                'ACTIVE',
                                style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        line1,
                        style: const TextStyle(color: Colors.white38, fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (line2 != null)
                        Text(
                          line2,
                          style: const TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.white38, size: 20),
                  onPressed: onDelete,
                  tooltip: 'Remove',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty(String title, String subtitle) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.playlist_add, color: Colors.white24, size: 56),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(color: Colors.white38)),
          const SizedBox(height: 6),
          Text(subtitle, style: const TextStyle(color: Colors.white24, fontSize: 12)),
        ],
      ),
    );
  }
}
