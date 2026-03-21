import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tüm uygulama ayarlarını yöneten servis.
/// ChangeNotifier — UI otomatik rebuild yapar.
class AppSettings extends ChangeNotifier {
  // ── Parental Control ─────────────────────────────────────────────────────
  bool _parentalEnabled = false;
  String _parentalPin = '';
  Set<String> _lockedCategories = {};

  bool get parentalEnabled => _parentalEnabled;
  String get parentalPin => _parentalPin;
  Set<String> get lockedCategories => _lockedCategories;

  // ── Tema ─────────────────────────────────────────────────────────────────
  bool _darkMode = true;
  bool get darkMode => _darkMode;

  // Sabit Ubuntu turuncu — değiştirilemez
  Color get accent => const Color(0xFFE95420);

  // ── Dil ──────────────────────────────────────────────────────────────────
  String _language = 'en'; // en | tr

  String get language => _language;

  // ── Stream Modu ──────────────────────────────────────────────────────────
  // auto | hls | ts
  String _streamMode = 'auto';
  // Buffer boyutu (saniye)
  int _bufferSeconds = 5;
  // Hardware decode
  bool _hwDecode = true;

  String get streamMode => _streamMode;
  int get bufferSeconds => _bufferSeconds;
  bool get hwDecode => _hwDecode;

  // ── Yükle / Kaydet ───────────────────────────────────────────────────────
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _parentalEnabled = prefs.getBool('parental_enabled') ?? false;
    _parentalPin = prefs.getString('parental_pin') ?? '';
    final locked = prefs.getStringList('locked_categories') ?? [];
    _lockedCategories = locked.toSet();
    _darkMode = prefs.getBool('dark_mode') ?? true;
    _language = prefs.getString('language') ?? 'en';
    _streamMode = prefs.getString('stream_mode') ?? 'auto';
    _bufferSeconds = prefs.getInt('buffer_seconds') ?? 5;
    _hwDecode = prefs.getBool('hw_decode') ?? true;
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('parental_enabled', _parentalEnabled);
    await prefs.setString('parental_pin', _parentalPin);
    await prefs.setStringList('locked_categories', _lockedCategories.toList());
    await prefs.setBool('dark_mode', _darkMode);
    await prefs.setString('language', _language);
    await prefs.setString('stream_mode', _streamMode);
    await prefs.setInt('buffer_seconds', _bufferSeconds);
    await prefs.setBool('hw_decode', _hwDecode);
  }

  // ── Parental Control ─────────────────────────────────────────────────────
  Future<void> setParentalEnabled(bool v) async {
    _parentalEnabled = v;
    await _save();
    notifyListeners();
  }

  Future<void> setParentalPin(String pin) async {
    _parentalPin = pin;
    await _save();
    notifyListeners();
  }

  Future<void> toggleLockedCategory(String catId) async {
    if (_lockedCategories.contains(catId)) {
      _lockedCategories.remove(catId);
    } else {
      _lockedCategories.add(catId);
    }
    await _save();
    notifyListeners();
  }

  bool isCategoryLocked(String catId) =>
      _parentalEnabled && _lockedCategories.contains(catId);

  // ── Tema ─────────────────────────────────────────────────────────────────
  Future<void> setDarkMode(bool v) async {
    _darkMode = v;
    await _save();
    notifyListeners();
  }

  // ── Dil ──────────────────────────────────────────────────────────────────
  Future<void> setLanguage(String lang) async {
    _language = lang;
    await _save();
    notifyListeners();
  }

  // ── Stream Modu ──────────────────────────────────────────────────────────
  Future<void> setStreamMode(String mode) async {
    _streamMode = mode;
    await _save();
    notifyListeners();
  }

  Future<void> setBufferSeconds(int v) async {
    _bufferSeconds = v;
    await _save();
    notifyListeners();
  }

  Future<void> setHwDecode(bool v) async {
    _hwDecode = v;
    await _save();
    notifyListeners();
  }

  // ── Stream URL builder ────────────────────────────────────────────────────
  /// Kanal URL'sini stream moduna göre dönüştürür.
  String resolveStreamUrl(String url) {
    if (_streamMode == 'auto') return url;
    // .m3u8 → .ts veya tersi
    if (_streamMode == 'ts' && url.endsWith('.m3u8')) {
      return url.replaceAll('.m3u8', '.ts');
    }
    if (_streamMode == 'hls' && url.endsWith('.ts')) {
      return url.replaceAll('.ts', '.m3u8');
    }
    return url;
  }
}
