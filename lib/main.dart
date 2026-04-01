import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:media_kit/media_kit.dart' show MediaKit; // ignore: depend_on_referenced_packages
import 'screens/dashboard_screen.dart';
import 'screens/activation_screen.dart';
import 'services/xtream_service.dart';
import 'services/app_settings.dart';
import 'services/backend_service.dart';
import 'services/device_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  final prefs = await SharedPreferences.getInstance();
  final xtreamService = XtreamService();
  final appSettings = AppSettings();
  await appSettings.load();

  // ── Fast path: if we have a cached session, show dashboard immediately ──
  // Backend auth runs in background and updates credentials silently.
  final hasXtream = _hasXtreamSession(prefs);
  final hasM3u = _hasM3uSession(prefs);

  Widget homeScreen;

  if (hasXtream || hasM3u) {
    // Load cached playlist without waiting for backend
    if (hasXtream) await xtreamService.loadSavedPlaylist();
    final sessionType = hasXtream ? 'xtream' : 'm3u';
    homeScreen = DashboardScreen(sessionType: sessionType);
    // Background: refresh credentials from backend (fire & forget)
    DeviceService.getDeviceId().then((deviceId) async {
      BackendService.fetchSettings(); // fire & forget
      final reg = await BackendService.registerDevice(deviceId);
      if (!reg.success || !reg.registered) return;
      if (reg.trialExpire != null && !reg.trialActive) return;
      final auth = await BackendService.authenticate(deviceId);
      if (!auth.success || auth.user == null) return;
      final user = auth.user!;
      if (user.m3uUrl.isNotEmpty) {
        await prefs.setString('m3u_active_url', user.m3uUrl);
      } else if (user.serverUrl.isNotEmpty) {
        await prefs.setString('xtream_server', user.serverUrl);
        await prefs.setString('xtream_username', user.username);
        await prefs.setString('xtream_password', user.password);
      }
    });
  } else {
    // No cached session — must contact backend to decide screen
    BackendService.fetchSettings(); // fire & forget
    final deviceId = await DeviceService.getDeviceId();
    final reg = await BackendService.registerDevice(deviceId);

    if (!reg.success) {
      homeScreen = ActivationScreen(deviceId: deviceId);
    } else if (!reg.registered) {
      homeScreen = ActivationScreen(deviceId: deviceId);
    } else if (reg.trialExpire != null && !reg.trialActive) {
      homeScreen = _SubscriptionExpiredScreen(
        deviceId: deviceId,
        expireDate: reg.trialExpire,
      );
    } else {
      final auth = await BackendService.authenticate(deviceId);
      if (auth.success && auth.user != null) {
        final user = auth.user!;
        if (user.m3uUrl.isNotEmpty) {
          await prefs.setString('m3u_active_url', user.m3uUrl);
          await prefs.remove('xtream_server');
          homeScreen = const DashboardScreen(sessionType: 'm3u');
        } else if (user.serverUrl.isNotEmpty) {
          await prefs.setString('xtream_server', user.serverUrl);
          await prefs.setString('xtream_username', user.username);
          await prefs.setString('xtream_password', user.password);
          await prefs.remove('m3u_active_url');
          await xtreamService.loadSavedPlaylist();
          homeScreen = const DashboardScreen(sessionType: 'xtream');
        } else {
          homeScreen = const DashboardScreen(sessionType: 'xtream');
        }
      } else if (auth.statusCode == 403) {
        homeScreen = _SubscriptionExpiredScreen(deviceId: deviceId);
      } else {
        homeScreen = ActivationScreen(deviceId: deviceId);
      }
    }
  }

  runApp(
    MultiProvider(
      providers: [
        Provider<XtreamService>.value(value: xtreamService),
        ChangeNotifierProvider<AppSettings>.value(value: appSettings),
      ],
      child: MyApp(homeScreen: homeScreen),
    ),
  );
}

bool _hasXtreamSession(SharedPreferences prefs) =>
    prefs.getString('xtream_server') != null;

bool _hasM3uSession(SharedPreferences prefs) =>
    prefs.getString('m3u_active_url') != null;

class MyApp extends StatelessWidget {
  final Widget homeScreen;
  const MyApp({super.key, required this.homeScreen});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppSettings>(
      builder: (_, settings, __) => Shortcuts(
        shortcuts: {
          LogicalKeySet(LogicalKeyboardKey.select): const ActivateIntent(),
          LogicalKeySet(LogicalKeyboardKey.enter): const ActivateIntent(),
        },
        child: FocusTraversalGroup(
          policy: WidgetOrderTraversalPolicy(),
          child: MaterialApp(
            title: 'Wallyt IPTV',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              brightness: Brightness.dark,
              colorScheme: ColorScheme.fromSeed(
                seedColor: settings.accent,
                brightness: Brightness.dark,
              ),
              scaffoldBackgroundColor: const Color(0xFF0E001A),
              appBarTheme: AppBarTheme(
                backgroundColor: settings.accent.withValues(alpha: 0.85),
                foregroundColor: Colors.white,
                elevation: 0,
              ),
              cardColor: Color.lerp(const Color(0xFF1A0030), settings.accent, 0.12),
              dialogTheme: DialogThemeData(
                backgroundColor: Color.lerp(const Color(0xFF1A0030), settings.accent, 0.12),
              ),
              switchTheme: SwitchThemeData(
                thumbColor: WidgetStateProperty.resolveWith(
                  (s) => s.contains(WidgetState.selected) ? settings.accent : null,
                ),
              ),
            ),
            themeMode: ThemeMode.dark,
            home: homeScreen,
          ),
        ),
      ),
    );
  }
}

// ── Subscription expired screen ───────────────────────────────────────────
class _SubscriptionExpiredScreen extends StatelessWidget {
  final String deviceId;
  final String? expireDate;
  const _SubscriptionExpiredScreen({required this.deviceId, this.expireDate});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E001A),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RichText(
              text: const TextSpan(
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 4),
                children: [
                  TextSpan(text: 'WALLYT', style: TextStyle(color: Color(0xFFE95420))),
                  TextSpan(text: 'TV', style: TextStyle(color: Colors.white)),
                ],
              ),
            ),
            const SizedBox(height: 32),
            const Icon(Icons.lock_clock, color: Colors.orange, size: 64),
            const SizedBox(height: 16),
            const Text('Subscription Expired',
                style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
            if (expireDate != null) ...[
              const SizedBox(height: 8),
              Text('Expired: $expireDate',
                  style: const TextStyle(color: Colors.white54, fontSize: 14)),
            ],
            const SizedBox(height: 8),
            Text('Device ID: $deviceId',
                style: const TextStyle(color: Colors.white38, fontSize: 11)),
            const SizedBox(height: 24),
            const Text('Please contact support to renew your subscription.',
                style: TextStyle(color: Colors.white54, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
