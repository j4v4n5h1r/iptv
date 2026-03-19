import 'package:flutter/services.dart';

class PipService {
  static const _channel = MethodChannel('com.wallyt.iptv/pip');

  static Future<bool> enterPip() async {
    try {
      final result = await _channel.invokeMethod<bool>('enterPip');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }
}
