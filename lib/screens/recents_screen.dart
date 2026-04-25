import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/channel.dart';
import 'player_screen.dart';

class RecentsScreen extends StatefulWidget {
  const RecentsScreen({super.key});

  @override
  State<RecentsScreen> createState() => _RecentsScreenState();
}

class _RecentsScreenState extends State<RecentsScreen> {
  List<Channel> _watchlist = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('watchlist') ?? '[]';
    final List<dynamic> list = json.decode(raw);
    if (mounted) {
      setState(() {
        _watchlist = list.map((e) => Channel.fromJson(e)).toList();
        _loading = false;
      });
    }
  }

  void _play(Channel channel) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerScreen(
          channel: channel,
          channels: _watchlist,
          isMovie: channel.isMovie,
          onFavoriteToggled: (_) {},
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: {
        LogicalKeySet(LogicalKeyboardKey.arrowDown):  const DirectionalFocusIntent(TraversalDirection.down),
        LogicalKeySet(LogicalKeyboardKey.arrowUp):    const DirectionalFocusIntent(TraversalDirection.up),
        LogicalKeySet(LogicalKeyboardKey.select):     const ActivateIntent(),
        LogicalKeySet(LogicalKeyboardKey.enter):      const ActivateIntent(),
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0B1118),
        appBar: AppBar(
          backgroundColor: const Color(0xFF0B1118),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text('Recently Watched', style: TextStyle(color: Colors.white)),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF60A5FA)))
            : _watchlist.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.history, color: Colors.white24, size: 64),
                        SizedBox(height: 16),
                        Text('No recently watched channels',
                            style: TextStyle(color: Colors.white38, fontSize: 16)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: _watchlist.length,
                    itemBuilder: (_, i) {
                      final ch = _watchlist[i];
                      final focusNode = FocusNode();
                      return Focus(
                        focusNode: focusNode,
                        autofocus: i == 0,
                        onKeyEvent: (node, event) {
                          if (event is KeyDownEvent &&
                              (event.logicalKey == LogicalKeyboardKey.select ||
                               event.logicalKey == LogicalKeyboardKey.enter)) {
                            _play(ch);
                            return KeyEventResult.handled;
                          }
                          return KeyEventResult.ignored;
                        },
                        child: ListenableBuilder(
                          listenable: focusNode,
                          builder: (_, __) {
                            final focused = focusNode.hasFocus;
                            return GestureDetector(
                              onTap: () => _play(ch),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: focused ? const Color(0xFF25313D) : const Color(0xFF1A242D),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: focused ? const Color(0xFF60A5FA) : const Color(0xFF2A3542),
                                    width: focused ? 2 : 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    if (ch.logo != null && ch.logo!.isNotEmpty)
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(6),
                                        child: Image.network(
                                          ch.logo!,
                                          width: 48,
                                          height: 36,
                                          fit: BoxFit.contain,
                                          errorBuilder: (_, __, ___) => const Icon(
                                              Icons.tv, color: Colors.white38, size: 36),
                                        ),
                                      )
                                    else
                                      Icon(
                                        ch.isMovie ? Icons.movie : Icons.tv,
                                        color: focused ? const Color(0xFF60A5FA) : Colors.white38,
                                        size: 36,
                                      ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(ch.name,
                                              style: TextStyle(
                                                color: focused ? Colors.white : Colors.white70,
                                                fontSize: 15,
                                                fontWeight: FontWeight.w600,
                                              )),
                                          if (ch.categoryName != null)
                                            Text(ch.categoryName!,
                                                style: const TextStyle(
                                                    color: Colors.white38, fontSize: 12)),
                                        ],
                                      ),
                                    ),
                                    Icon(Icons.play_circle_outline,
                                        color: focused ? const Color(0xFF60A5FA) : Colors.white24,
                                        size: 28),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
