import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DeviceService {
  static const _kAppKey = 'app_key';

  /// Returns a stable App Key — generated once from device hardware ID,
  /// cached forever in SharedPreferences.
  /// Format: VNUX-XXXX-XXXX  (letters + digits, easy to read/type)
  static Future<String> getAppKey() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_kAppKey);
    if (cached != null && cached.isNotEmpty) return cached;

    // Read hardware ID
    String hardwareId;
    try {
      final info = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final android = await info.androidInfo;
        // Combine stable hardware identifiers — survives app reinstall
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

    // Generate deterministic short key from hardware ID
    final key = _generateKey(hardwareId);
    await prefs.setString(_kAppKey, key);
    return key;
  }

  /// Deterministic key from hardware ID — same device always gets same key.
  /// Format: VNUX-XXXX-XXXX
  static String _generateKey(String seed) {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // no 0/O/1/I confusion
    var hash = seed.codeUnits.fold<int>(5381, (h, c) => ((h << 5) + h) ^ c);
    hash = hash.abs();

    final rng = _SeededRandom(hash);
    final part1 = List.generate(4, (_) => chars[rng.next() % chars.length]).join();
    final part2 = List.generate(4, (_) => chars[rng.next() % chars.length]).join();

    return 'VNUX-$part1-$part2';
  }
}

/// Simple seeded pseudo-random — deterministic, no dart:math Random seed issues
class _SeededRandom {
  int _state;
  _SeededRandom(this._state);

  int next() {
    _state = (_state * 1664525 + 1013904223) & 0xFFFFFFFF;
    return _state;
  }
}
