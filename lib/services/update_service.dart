import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// Mevcut uygulama versiyonu (pubspec.yaml ile eşleşmeli)
const String _appVersion = '1.0.0';

// GitHub releases API — kendi repo adresinizi buraya yazın
const String _apiUrl =
    'https://api.github.com/repos/wallyt/iptv-player/releases/latest';

class UpdateService {
  static const _lastCheckKey = 'last_update_check';

  /// Yeni sürüm varsa [UpdateInfo] döner, yoksa null.
  /// 24 saatte bir kontrol eder (force=true ile her zaman).
  static Future<UpdateInfo?> checkForUpdate({bool force = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastCheck = prefs.getInt(_lastCheckKey) ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      final oneDayMs = const Duration(hours: 24).inMilliseconds;

      if (!force && now - lastCheck < oneDayMs) return null;

      final res = await http
          .get(Uri.parse(_apiUrl),
              headers: {'Accept': 'application/vnd.github+json'})
          .timeout(const Duration(seconds: 8));

      if (res.statusCode != 200) return null;
      await prefs.setInt(_lastCheckKey, now);

      final data = json.decode(res.body);
      final tagName =
          (data['tag_name'] as String?)?.replaceFirst('v', '') ?? '';
      final body = data['body'] as String? ?? '';
      final htmlUrl = data['html_url'] as String? ?? '';

      if (_isNewer(tagName, _appVersion)) {
        return UpdateInfo(
            version: tagName, releaseNotes: body, downloadUrl: htmlUrl);
      }
    } catch (_) {}
    return null;
  }

  static bool _isNewer(String remote, String current) {
    final r = _parse(remote);
    final c = _parse(current);
    for (int i = 0; i < 3; i++) {
      if (r[i] > c[i]) return true;
      if (r[i] < c[i]) return false;
    }
    return false;
  }

  static List<int> _parse(String v) {
    final parts = v.split('.').map((p) => int.tryParse(p) ?? 0).toList();
    while (parts.length < 3) {
      parts.add(0);
    }
    return parts;
  }
}

class UpdateInfo {
  final String version;
  final String releaseNotes;
  final String downloadUrl;

  const UpdateInfo({
    required this.version,
    required this.releaseNotes,
    required this.downloadUrl,
  });
}
