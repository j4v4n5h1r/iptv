import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DeviceService {
  static const _kAppKey = 'app_key';
  static const _kKeyFile = '/sdcard/.wallyt_device_key';

  static Future<String> getAppKey() async {
    // 1. SharedPreferences cache (fastest)
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_kAppKey);
    if (cached != null && cached.isNotEmpty) return cached;

    // 2. Persistent file on external storage (survives app reinstall)
    try {
      final file = File(_kKeyFile);
      if (await file.exists()) {
        final stored = (await file.readAsString()).trim();
        if (stored.isNotEmpty && stored.startsWith('VNUX-')) {
          await prefs.setString(_kAppKey, stored);
          return stored;
        }
      }
    } catch (_) {}

    // 3. Generate from hardware — deterministic, same device = same key
    String hardwareId;
    try {
      final info = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final android = await info.androidInfo;
        hardwareId = '${android.board}|${android.hardware}|${android.device}|${android.model}|${android.product}';
      } else if (Platform.isIOS) {
        final ios = await info.iosInfo;
        hardwareId = ios.identifierForVendor ?? 'UNKNOWN';
      } else {
        hardwareId = 'UNKNOWN';
      }
    } catch (_) {
      hardwareId = 'UNKNOWN';
    }

    final key = _generateKey(hardwareId);

    // Save to both locations
    await prefs.setString(_kAppKey, key);
    try {
      await File(_kKeyFile).writeAsString(key);
    } catch (_) {}

    return key;
  }

  static String _generateKey(String seed) {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    var hash = seed.codeUnits.fold<int>(5381, (h, c) => ((h << 5) + h) ^ c);
    hash = hash.abs();
    final rng = _SeededRandom(hash);
    final part1 = List.generate(4, (_) => chars[rng.next() % chars.length]).join();
    final part2 = List.generate(4, (_) => chars[rng.next() % chars.length]).join();
    return 'VNUX-$part1-$part2';
  }
}

class _SeededRandom {
  int _state;
  _SeededRandom(this._state);
  int next() {
    _state = (_state * 1664525 + 1013904223) & 0xFFFFFFFF;
    return _state;
  }
}
