import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/xtream_service.dart';
import '../models/channel.dart';
import 'home_screen.dart';

class PlaylistsScreen extends StatefulWidget {
  const PlaylistsScreen({super.key});

  @override
  State<PlaylistsScreen> createState() => _PlaylistsScreenState();
}

class _PlaylistsScreenState extends State<PlaylistsScreen> {
  List<XtreamPlaylist> _playlists = [];
  bool _loading = true;
  bool _switching = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final xtream = Provider.of<XtreamService>(context, listen: false);
    final list = await xtream.getSavedPlaylists();
    if (mounted) setState(() { _playlists = list; _loading = false; });
  }

  Future<void> _switchTo(XtreamPlaylist playlist) async {
    setState(() => _switching = true);
    final xtream = Provider.of<XtreamService>(context, listen: false);
    await xtream.switchPlaylist(playlist);
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );
    }
  }

  Future<void> _delete(XtreamPlaylist playlist) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Remove Playlist', style: TextStyle(color: Colors.white)),
        content: Text(
          'Remove "${playlist.name}" (${playlist.username})?',
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
    if (confirmed == true && mounted) {
      final xtream = Provider.of<XtreamService>(context, listen: false);
      await xtream.removePlaylist(playlist);
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final xtream = Provider.of<XtreamService>(context, listen: false);
    final activeServer = xtream.serverUrl;
    final activeUser = xtream.username;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Saved Playlists', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _switching
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Colors.deepOrange),
                  SizedBox(height: 16),
                  Text('Switching playlist...', style: TextStyle(color: Colors.white54)),
                ],
              ),
            )
          : _loading
              ? const Center(child: CircularProgressIndicator(color: Colors.deepOrange))
              : _playlists.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.playlist_add, color: Colors.white24, size: 56),
                          SizedBox(height: 12),
                          Text('No saved playlists', style: TextStyle(color: Colors.white38)),
                          SizedBox(height: 6),
                          Text('Login to add a playlist', style: TextStyle(color: Colors.white24, fontSize: 12)),
                        ],
                      ),
                    )
                  : Shortcuts(
                      shortcuts: {
                        LogicalKeySet(LogicalKeyboardKey.arrowDown): const NextFocusIntent(),
                        LogicalKeySet(LogicalKeyboardKey.arrowUp): const PreviousFocusIntent(),
                        LogicalKeySet(LogicalKeyboardKey.select): const ActivateIntent(),
                        LogicalKeySet(LogicalKeyboardKey.enter): const ActivateIntent(),
                      },
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: _playlists.length,
                        itemBuilder: (ctx, i) {
                          final p = _playlists[i];
                          final isActive = p.serverUrl == activeServer && p.username == activeUser;
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            child: Material(
                              color: isActive
                                  ? Colors.deepOrange.withValues(alpha: 0.15)
                                  : const Color(0xFF1A1A2E),
                              borderRadius: BorderRadius.circular(10),
                              child: InkWell(
                                onTap: () => _switchTo(p),
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: isActive ? Colors.deepOrange : Colors.white12,
                                      width: isActive ? 1.5 : 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 42,
                                        height: 42,
                                        decoration: BoxDecoration(
                                          color: isActive
                                              ? Colors.deepOrange
                                              : Colors.white10,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          isActive ? Icons.check : Icons.playlist_play,
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
                                                    p.name,
                                                    style: TextStyle(
                                                      color: isActive ? Colors.deepOrange : Colors.white,
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
                                                      color: Colors.deepOrange,
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
                                              p.serverUrl,
                                              style: const TextStyle(color: Colors.white38, fontSize: 11),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            Text(
                                              p.username,
                                              style: const TextStyle(color: Colors.white54, fontSize: 12),
                                            ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, color: Colors.white38, size: 20),
                                        onPressed: () => _delete(p),
                                        tooltip: 'Remove',
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
