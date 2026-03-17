
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/channel.dart';

class XtreamService {
  String? _serverUrl;
  String? _username;
  String? _password;

  String? get serverUrl => _serverUrl;
  String? get username => _username;
  String? get password => _password;

  Future<void> loadSavedPlaylist() async {
    final prefs = await SharedPreferences.getInstance();
    _serverUrl = prefs.getString('xtream_server');
    _username = prefs.getString('xtream_username');
    _password = prefs.getString('xtream_password');
  }

  Future<bool> login(String serverUrl, String username, String password) async {
    // Normalize server URL
    String url = serverUrl.trim();
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'http://$url';
    }
    if (url.endsWith('/')) url = url.substring(0, url.length - 1);

    try {
      final response = await http
          .get(Uri.parse('$url/player_api.php?username=$username&password=$password'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['user_info'] != null && data['user_info']['auth'] == 1) {
          _serverUrl = url;
          _username = username;
          _password = password;

          // Save to prefs
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('xtream_server', url);
          await prefs.setString('xtream_username', username);
          await prefs.setString('xtream_password', password);

          // Save playlists list
          await _savePlaylistToList(url, username, password);
          return true;
        }
      }
      return false;
    } catch (e) {
      print('Xtream login error: $e');
      return false;
    }
  }

  Future<void> _savePlaylistToList(String server, String user, String pass) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('playlists') ?? '[]';
    final List<dynamic> list = json.decode(raw);

    final existing = list.indexWhere((p) => p['serverUrl'] == server && p['username'] == user);
    final playlist = XtreamPlaylist(
      name: Uri.parse(server).host,
      serverUrl: server,
      username: user,
      password: pass,
    );

    if (existing >= 0) {
      list[existing] = playlist.toJson();
    } else {
      list.add(playlist.toJson());
    }
    await prefs.setString('playlists', json.encode(list));
  }

  Future<List<XtreamPlaylist>> getSavedPlaylists() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('playlists') ?? '[]';
    final List<dynamic> list = json.decode(raw);
    return list.map((p) => XtreamPlaylist.fromJson(p)).toList();
  }

  Future<void> removePlaylist(XtreamPlaylist playlist) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('playlists') ?? '[]';
    final List<dynamic> list = json.decode(raw);
    list.removeWhere(
        (p) => p['serverUrl'] == playlist.serverUrl && p['username'] == playlist.username);
    await prefs.setString('playlists', json.encode(list));
  }

  Future<void> switchPlaylist(XtreamPlaylist playlist) async {
    _serverUrl = playlist.serverUrl;
    _username = playlist.username;
    _password = playlist.password;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('xtream_server', playlist.serverUrl);
    await prefs.setString('xtream_username', playlist.username);
    await prefs.setString('xtream_password', playlist.password);
  }

  String _apiUrl(String action) =>
      '$_serverUrl/player_api.php?username=$_username&password=$_password&action=$action';

  Future<List<Category>> getLiveCategories() async {
    try {
      final res = await http.get(Uri.parse(_apiUrl('get_live_categories'))).timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        final List data = json.decode(res.body);
        return data.map((c) => Category(id: c['category_id'].toString(), name: c['category_name'], type: 'live')).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<List<Category>> getVodCategories() async {
    try {
      final res = await http.get(Uri.parse(_apiUrl('get_vod_categories'))).timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        final List data = json.decode(res.body);
        return data.map((c) => Category(id: c['category_id'].toString(), name: c['category_name'], type: 'vod')).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<List<Category>> getSeriesCategories() async {
    try {
      final res = await http.get(Uri.parse(_apiUrl('get_series_categories'))).timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        final List data = json.decode(res.body);
        return data.map((c) => Category(id: c['category_id'].toString(), name: c['category_name'], type: 'series')).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<List<Channel>> getLiveStreams({String? categoryId}) async {
    try {
      String url = _apiUrl('get_live_streams');
      if (categoryId != null) url += '&category_id=$categoryId';
      final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 20));
      if (res.statusCode == 200) {
        final List data = json.decode(res.body);
        return data.map((s) {
          final id = s['stream_id'].toString();
          return Channel(
            name: s['name'] ?? '',
            url: '$_serverUrl/live/$_username/$_password/$id.m3u8',
            logo: s['stream_icon'],
            num: s['num'] is int ? s['num'] : int.tryParse(s['num'].toString()),
            categoryId: s['category_id']?.toString(),
            epgChannelId: s['epg_channel_id'],
            streamId: id,
            streamType: 'live',
          );
        }).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<List<Channel>> getVodStreams({String? categoryId}) async {
    try {
      String url = _apiUrl('get_vod_streams');
      if (categoryId != null) url += '&category_id=$categoryId';
      final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 20));
      if (res.statusCode == 200) {
        final List data = json.decode(res.body);
        return data.map((s) {
          final id = s['stream_id'].toString();
          final ext = s['container_extension'] ?? 'mp4';
          return Channel(
            name: s['name'] ?? '',
            url: '$_serverUrl/movie/$_username/$_password/$id.$ext',
            logo: s['stream_icon'],
            num: s['num'] is int ? s['num'] : int.tryParse(s['num'].toString()),
            categoryId: s['category_id']?.toString(),
            streamId: id,
            containerExtension: ext,
            isMovie: true,
            streamType: 'movie',
          );
        }).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<List<Channel>> getSeriesList({String? categoryId}) async {
    try {
      String url = _apiUrl('get_series');
      if (categoryId != null) url += '&category_id=$categoryId';
      final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 20));
      if (res.statusCode == 200) {
        final List data = json.decode(res.body);
        return data.map((s) {
          return Channel(
            name: s['name'] ?? '',
            url: '',
            logo: s['cover'],
            categoryId: s['category_id']?.toString(),
            streamId: s['series_id']?.toString(),
            streamType: 'series',
          );
        }).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<List<EpgProgram>> getShortEpg(String streamId) async {
    try {
      final url = '$_serverUrl/player_api.php?username=$_username&password=$_password&action=get_short_epg&stream_id=$streamId&limit=5';
      final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final List epgList = data['epg_listings'] ?? [];
        return epgList.map((e) {
          final start = DateTime.fromMillisecondsSinceEpoch(
              int.parse(e['start_timestamp'].toString()) * 1000);
          final end = DateTime.fromMillisecondsSinceEpoch(
              int.parse(e['stop_timestamp'].toString()) * 1000);
          return EpgProgram(
            title: utf8.decode(base64.decode(e['title'] ?? '')),
            description: utf8.decode(base64.decode(e['description'] ?? '')),
            start: start,
            end: end,
          );
        }).toList();
      }
    } catch (_) {}
    return [];
  }

  void logout() {
    _serverUrl = null;
    _username = null;
    _password = null;
  }
}
