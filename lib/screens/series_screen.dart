import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../models/channel.dart';
import 'player_screen.dart';

class SeriesScreen extends StatefulWidget {
  final Channel series;
  final String serverUrl;
  final String username;
  final String password;

  const SeriesScreen({
    super.key,
    required this.series,
    required this.serverUrl,
    required this.username,
    required this.password,
  });

  @override
  State<SeriesScreen> createState() => _SeriesScreenState();
}

class _SeriesScreenState extends State<SeriesScreen> {
  Map<String, dynamic>? _info;
  bool _loading = true;
  int _selectedSeason = 1;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSeriesInfo();
  }

  Future<void> _loadSeriesInfo() async {
    try {
      final url = '${widget.serverUrl}/player_api.php'
          '?username=${widget.username}&password=${widget.password}'
          '&action=get_series_info&series_id=${widget.series.streamId}';
      final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (mounted) setState(() { _info = data; _loading = false; });
        return;
      }
    } catch (_) {}
    if (mounted) setState(() { _loading = false; _error = 'Could not load series info'; });
  }

  List<int> get _seasons {
    final episodes = _info?['episodes'] as Map<String, dynamic>?;
    if (episodes == null) return [];
    return episodes.keys.map((k) => int.tryParse(k) ?? 0).toList()..sort();
  }

  List<Map<String, dynamic>> get _currentEpisodes {
    final episodes = _info?['episodes'] as Map<String, dynamic>?;
    if (episodes == null) return [];
    final season = episodes[_selectedSeason.toString()];
    if (season == null) return [];
    return List<Map<String, dynamic>>.from(season);
  }

  void _playEpisode(Map<String, dynamic> ep) {
    final id = ep['id']?.toString() ?? '';
    final ext = ep['container_extension'] ?? 'mp4';
    final url = '${widget.serverUrl}/series/${widget.username}/${widget.password}/$id.$ext';
    final channel = Channel(
      name: '${widget.series.name} S${_selectedSeason}E${ep['episode_num']} - ${ep['title'] ?? ''}',
      url: url,
      logo: widget.series.logo,
      isMovie: true,
      streamType: 'series',
    );
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerScreen(
          channel: channel,
          channels: [channel],
          isMovie: true,
          onFavoriteToggled: (_) {},
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        title: Text(widget.series.name, style: const TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Shortcuts(
        shortcuts: {
          LogicalKeySet(LogicalKeyboardKey.arrowDown): const NextFocusIntent(),
          LogicalKeySet(LogicalKeyboardKey.arrowUp): const PreviousFocusIntent(),
          LogicalKeySet(LogicalKeyboardKey.select): const ActivateIntent(),
          LogicalKeySet(LogicalKeyboardKey.enter): const ActivateIntent(),
        },
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: Colors.deepOrange))
            : _error != null
                ? Center(child: Text(_error!, style: const TextStyle(color: Colors.white54)))
                : _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    final info = _info?['info'] as Map<String, dynamic>?;
    final seasons = _seasons;

    return Row(
      children: [
        // Left: Series poster + info
        SizedBox(
          width: 220,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.series.logo != null && widget.series.logo!.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      widget.series.logo!,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        height: 140,
                        color: Colors.grey[850],
                        child: const Icon(Icons.tv, color: Colors.white24, size: 48),
                      ),
                    ),
                  ),
                const SizedBox(height: 10),
                Text(
                  widget.series.name,
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                ),
                if (info?['plot'] != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    info!['plot'],
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                    maxLines: 5,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (info?['rating'] != null) ...[
                  const SizedBox(height: 6),
                  Row(children: [
                    const Icon(Icons.star, color: Colors.amber, size: 14),
                    const SizedBox(width: 4),
                    Text(info!['rating'].toString(), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  ]),
                ],
                const SizedBox(height: 12),
                // Season selector
                if (seasons.isNotEmpty) ...[
                  const Text('Season', style: TextStyle(color: Colors.white54, fontSize: 11)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: seasons.map((s) {
                      final selected = s == _selectedSeason;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedSeason = s),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: selected ? Colors.deepOrange : Colors.white12,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'S$s',
                            style: TextStyle(
                              color: selected ? Colors.white : Colors.white70,
                              fontSize: 12,
                              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        ),
        Container(width: 1, color: Colors.white12),
        // Right: Episodes list
        Expanded(
          child: _currentEpisodes.isEmpty
              ? const Center(child: Text('No episodes', style: TextStyle(color: Colors.white38)))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _currentEpisodes.length,
                  itemBuilder: (ctx, i) {
                    final ep = _currentEpisodes[i];
                    final epNum = ep['episode_num']?.toString() ?? '${i + 1}';
                    final title = ep['title'] ?? 'Episode $epNum';
                    final duration = ep['info']?['duration'] ?? '';
                    final plot = ep['info']?['plot'] ?? '';
                    return InkWell(
                      onTap: () => _playEpisode(ep),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: const BoxDecoration(
                          border: Border(bottom: BorderSide(color: Colors.white10)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: Colors.deepOrange.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Center(
                                child: Text(
                                  epNum,
                                  style: const TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(title, style: const TextStyle(color: Colors.white, fontSize: 13)),
                                  if (duration.isNotEmpty || plot.isNotEmpty)
                                    Text(
                                      duration.isNotEmpty ? duration : plot,
                                      style: const TextStyle(color: Colors.white38, fontSize: 11),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                ],
                              ),
                            ),
                            const Icon(Icons.play_circle_outline, color: Colors.white38, size: 22),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
