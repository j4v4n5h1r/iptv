import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import '../config.dart';

/// Represents the result of POST /api/device/register
class RegistrationResult {
  final bool success;
  final bool registered;
  final bool trialActive;
  final String? trialExpire;
  final String? error;

  const RegistrationResult({
    required this.success,
    required this.registered,
    required this.trialActive,
    this.trialExpire,
    this.error,
  });
}

/// Represents the authenticated user from POST /api/auth
class AuthUser {
  final int id;
  final String title;
  final String username;
  final String password;
  final String serverUrl;
  final String serverTitle;
  final String m3uUrl;
  final bool protection;

  const AuthUser({
    required this.id,
    required this.title,
    required this.username,
    required this.password,
    required this.serverUrl,
    required this.serverTitle,
    required this.m3uUrl,
    required this.protection,
  });

  /// Build the playlist URL: direct M3U override or standard XtreamCodes URL
  String get playlistUrl => m3uUrl.isNotEmpty
      ? m3uUrl
      : '$serverUrl/get.php?username=$username&password=$password&type=m3u_plus';

  /// XtreamCodes API base URL
  String get apiBase =>
      '$serverUrl/player_api.php?username=$username&password=$password';
}

class AuthResult {
  final bool success;
  final AuthUser? user;
  final String? trialExpire;
  final String? notificationTitle;
  final String? notificationContent;
  final String? error;
  final int statusCode;

  const AuthResult({
    required this.success,
    this.user,
    this.trialExpire,
    this.notificationTitle,
    this.notificationContent,
    this.error,
    required this.statusCode,
  });
}

class AppSettingsResult {
  final bool success;
  final int macLength;
  final String loginTitle;
  final String loginSubtitle;
  final String? error;

  const AppSettingsResult({
    required this.success,
    required this.macLength,
    required this.loginTitle,
    required this.loginSubtitle,
    this.error,
  });
}

class DemoResult {
  final bool success;
  final String? dns;
  final String? username;
  final String? password;
  final String? playlistName;
  final String? error;

  const DemoResult({
    required this.success,
    this.dns,
    this.username,
    this.password,
    this.playlistName,
    this.error,
  });
}

class BackendService {
  static const _timeout = Duration(seconds: 15);

  static Map<String, String> get _headers => {'Content-Type': 'application/json'};

  /// GET /api/settings
  static Future<AppSettingsResult> fetchSettings() async {
    try {
      final res = await http
          .get(Uri.parse('$kBackendUrl/api/settings'), headers: _headers)
          .timeout(_timeout);
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode != 200 || body['success'] != true) {
        return AppSettingsResult(
          success: false,
          macLength: 12,
          loginTitle: 'Welcome',
          loginSubtitle: 'Activate your device',
          error: body['error']?.toString(),
        );
      }
      final s = body['settings'] as Map<String, dynamic>? ?? {};
      return AppSettingsResult(
        success: true,
        macLength: int.tryParse(s['mac_length']?.toString() ?? '12') ?? 12,
        loginTitle: s['login_title']?.toString() ?? 'Welcome',
        loginSubtitle: s['login_subtitle']?.toString() ?? 'Activate your device',
      );
    } catch (e) {
      return AppSettingsResult(
        success: false,
        macLength: 12,
        loginTitle: 'Welcome',
        loginSubtitle: 'Activate your device',
        error: e.toString(),
      );
    }
  }

  /// POST /api/device/register  { mac_address }
  static Future<RegistrationResult> registerDevice(String deviceId) async {
    try {
      final res = await http
          .post(
            Uri.parse('$kBackendUrl/api/device/register'),
            headers: _headers,
            body: jsonEncode({'mac_address': deviceId}),
          )
          .timeout(_timeout);
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      return RegistrationResult(
        success: body['success'] == true,
        registered: body['registered'] == true,
        trialActive: body['trial_active'] == true,
        trialExpire: body['trial_expire']?.toString(),
        error: body['error']?.toString(),
      );
    } catch (e) {
      return RegistrationResult(
        success: false,
        registered: false,
        trialActive: false,
        error: e.toString(),
      );
    }
  }

  /// POST /api/activate  { mac_address, code }
  /// Returns null error on success, error string on failure.
  static Future<String?> activateDevice(String deviceId, String code) async {
    try {
      final res = await http
          .post(
            Uri.parse('$kBackendUrl/api/activate'),
            headers: _headers,
            body: jsonEncode({'mac_address': deviceId, 'code': code}),
          )
          .timeout(_timeout);
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode == 200 && body['success'] == true) return null;
      return body['error']?.toString() ?? 'Activation failed';
    } catch (e) {
      return e.toString();
    }
  }

  /// POST /api/auth  { mac_address }
  static Future<AuthResult> authenticate(String deviceId) async {
    try {
      final res = await http
          .post(
            Uri.parse('$kBackendUrl/api/auth'),
            headers: _headers,
            body: jsonEncode({'mac_address': deviceId}),
          )
          .timeout(_timeout);
      final body = jsonDecode(res.body) as Map<String, dynamic>;

      if (body['success'] != true) {
        return AuthResult(
          success: false,
          error: body['error']?.toString() ?? 'Authentication failed',
          statusCode: res.statusCode,
        );
      }

      final u = body['user'] as Map<String, dynamic>;
      final notif = body['notification'] as Map<String, dynamic>?;
      final trial = body['trial'] as Map<String, dynamic>?;

      return AuthResult(
        success: true,
        user: AuthUser(
          id: (u['id'] as num?)?.toInt() ?? 0,
          title: u['title']?.toString() ?? '',
          username: u['username']?.toString() ?? '',
          password: u['password']?.toString() ?? '',
          serverUrl: (u['server_url']?.toString() ?? '').trimRight().replaceAll(RegExp(r'/$'), ''),
          serverTitle: u['server_title']?.toString() ?? '',
          m3uUrl: u['m3u_url']?.toString() ?? '',
          protection: u['protection']?.toString().toUpperCase() == 'YES',
        ),
        trialExpire: trial?['expire_date']?.toString(),
        notificationTitle: notif?['title']?.toString(),
        notificationContent: notif?['content']?.toString(),
        statusCode: res.statusCode,
      );
    } catch (e) {
      return AuthResult(success: false, error: e.toString(), statusCode: 0);
    }
  }

  /// GET /api/notification
  static Future<Map<String, String>?> fetchNotification() async {
    try {
      final res = await http
          .get(Uri.parse('$kBackendUrl/api/notification'), headers: _headers)
          .timeout(_timeout);
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (body['success'] != true) return null;
      final notif = body['notification'] as Map<String, dynamic>?;
      final title = notif?['title']?.toString() ?? '';
      if (title.isEmpty) return null;
      return {
        'title': title,
        'content': notif?['content']?.toString() ?? '',
      };
    } catch (_) {
      return null;
    }
  }

  /// GET /api/update — returns APK URL if update available, null otherwise
  static Future<String?> checkForUpdate() async {
    try {
      final res = await http
          .get(Uri.parse('$kBackendUrl/api/update'), headers: _headers)
          .timeout(_timeout);
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final update = body['update'] as Map<String, dynamic>?;
      if (update == null || update['has_update'] != true) return null;
      final remoteVersion = update['version']?.toString() ?? '';
      final info = await PackageInfo.fromPlatform();
      if (remoteVersion == info.version) return null;
      return update['url']?.toString();
    } catch (_) {
      return null;
    }
  }

  /// GET /api/demo
  static Future<DemoResult> fetchDemo() async {
    try {
      final res = await http
          .get(Uri.parse('$kBackendUrl/api/demo'), headers: _headers)
          .timeout(_timeout);
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode != 200 || body['success'] != true) {
        return DemoResult(success: false, error: body['error']?.toString());
      }
      final demo = body['demo'] as Map<String, dynamic>;
      return DemoResult(
        success: true,
        dns: demo['dns']?.toString(),
        username: demo['username']?.toString(),
        password: demo['password']?.toString(),
        playlistName: demo['playlist_name']?.toString(),
      );
    } catch (e) {
      return DemoResult(success: false, error: e.toString());
    }
  }
}
