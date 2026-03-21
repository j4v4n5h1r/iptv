import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DeviceService {
  static const _kCachedId = 'device_id';

  /// Returns a stable device ID — cached in SharedPreferences.
  /// Android: uses androidId. iOS: identifierForVendor.
  static Future<String> getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_kCachedId);
    if (cached != null && cached.isNotEmpty) return cached;

    String id;
    try {
      final info = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final android = await info.androidInfo;
        id = android.id.toUpperCase();
      } else if (Platform.isIOS) {
        final ios = await info.iosInfo;
        id = (ios.identifierForVendor ?? 'UNKNOWN').toUpperCase();
      } else {
        id = 'UNKNOWN';
      }
    } catch (_) {
      id = 'UNKNOWN';
    }

    await prefs.setString(_kCachedId, id);
    return id;
  }
}
