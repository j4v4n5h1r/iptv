import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/channel.dart';

/// M3U/M3U8 URL'den kanal listesi parse eder.
/// Saved playlist'lerde type: 'm3u' olarak saklanır.
class M3uService {
  // --- Parse ---

  static List<Channel> parseM3u(String content) {
    final channels = <Channel>[];
    final lines = content.split('\n');

    String? name;
    String? logo;
    String? group;
    String? epgId;
    int? num;

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      if (line.startsWith('#EXTINF:')) {
        // Parse attributes
        name = _attr(line, 'tvg-name') ?? _attr(line, 'name');
        logo = _attr(line, 'tvg-logo') ?? _attr(line, 'logo');
        group = _attr(line, 'group-title');
        epgId = _attr(line, 'tvg-id');
        final numStr = _attr(line, 'tvg-chno') ?? _attr(line, 'channel-number');
        num = numStr != null ? int.tryParse(numStr) : null;

        // Fallback: name after last comma
        if (name == null) {
          final comma = line.lastIndexOf(',');
          if (comma >= 0 && comma < line.length - 1) {
            name = line.substring(comma + 1).trim();
          }
        }
      } else if (line.startsWith('#')) {
        // Skip other directives
        continue;
      } else {
        // It's a URL
        if (name != null) {
          channels.add(Channel(
            name: name,
            url: line,
            logo: logo,
            categoryName: group,
            epgChannelId: epgId,
            num: num,
            streamType: 'live',
          ));
        }
        name = null;
        logo = null;
        group = null;
        epgId = null;
        num = null;
      }
    }

    return channels;
  }

  static String? _attr(String line, String key) {
    // Match key="value" or key='value'
    final pattern = RegExp('$key=["\']([^"\']*)["\']', caseSensitive: false);
    final match = pattern.firstMatch(line);
    return match?.group(1);
  }

  // --- Fetch + parse ---

  static Future<List<Channel>?> fetchAndParse(String url) async {
    try {
      final uri = Uri.parse(url.trim());
      final res = await http.get(uri).timeout(const Duration(seconds: 20));
      if (res.statusCode == 200) {
        final body = utf8.decode(res.bodyBytes, allowMalformed: true);
        if (body.contains('#EXTM3U') || body.contains('#EXTINF')) {
          return parseM3u(body);
        }
      }
    } catch (_) {}
    return null;
  }

  // --- Validate ---

  static Future<bool> validate(String url) async {
    final result = await fetchAndParse(url);
    return result != null && result.isNotEmpty;
  }

  // --- Groups (categories) from channel list ---

  static List<Category> getGroups(List<Channel> channels) {
    final seen = <String>{};
    final cats = <Category>[];
    for (final ch in channels) {
      final g = ch.categoryName ?? 'General';
      if (seen.add(g)) {
        cats.add(Category(id: g, name: g, type: 'live'));
      }
    }
    return cats;
  }

  // --- Saved M3U playlists ---

  static Future<List<M3uPlaylist>> getSavedPlaylists() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('m3u_playlists') ?? '[]';
    final List<dynamic> list = json.decode(raw);
    return list.map((e) => M3uPlaylist.fromJson(e)).toList();
  }

  static Future<void> savePlaylist(M3uPlaylist playlist) async {
    final prefs = await SharedPreferences.getInstance();
    final list = await getSavedPlaylists();
    final idx = list.indexWhere((p) => p.url == playlist.url);
    if (idx >= 0) {
      list[idx] = playlist;
    } else {
      list.add(playlist);
    }
    await prefs.setString('m3u_playlists', json.encode(list.map((p) => p.toJson()).toList()));
  }

  static Future<void> removePlaylist(M3uPlaylist playlist) async {
    final prefs = await SharedPreferences.getInstance();
    final list = await getSavedPlaylists();
    list.removeWhere((p) => p.url == playlist.url);
    await prefs.setString('m3u_playlists', json.encode(list.map((p) => p.toJson()).toList()));
  }

  static Future<void> setActive(M3uPlaylist playlist) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('m3u_active_url', playlist.url);
    await prefs.setString('m3u_active_name', playlist.name);
  }

  static Future<M3uPlaylist?> getActive() async {
    final prefs = await SharedPreferences.getInstance();
    final url = prefs.getString('m3u_active_url');
    if (url == null) return null;
    final name = prefs.getString('m3u_active_name') ?? url;
    return M3uPlaylist(name: name, url: url);
  }

  static Future<void> clearActive() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('m3u_active_url');
    await prefs.remove('m3u_active_name');
  }
}

class M3uPlaylist {
  final String name;
  final String url;

  M3uPlaylist({required this.name, required this.url});

  factory M3uPlaylist.fromJson(Map<String, dynamic> j) =>
      M3uPlaylist(name: j['name'] ?? j['url'], url: j['url']);

  Map<String, dynamic> toJson() => {'name': name, 'url': url};
}
