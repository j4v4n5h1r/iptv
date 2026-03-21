import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:media_kit/media_kit.dart' show MediaKit; // ignore: depend_on_referenced_packages
import 'screens/login_screen.dart';
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
  if (_hasXtreamSession(prefs)) await xtreamService.loadSavedPlaylist();
  await appSettings.load();

  // ── Startup flow ──────────────────────────────────────────────────────────
  // 1. Fetch panel settings — best effort, currently unused at runtime
  await BackendService.fetchSettings();

  // 2. Get stable device ID
  final deviceId = await DeviceService.getDeviceId();

  // 3. Register device → decide which screen to show
  Widget homeScreen;

  final reg = await BackendService.registerDevice(deviceId);

  if (!reg.success) {
    // Backend unreachable — fall back to existing session or manual login
    final hasSession = _hasXtreamSession(prefs) || _hasM3uSession(prefs);
    if (hasSession) {
      final sessionType = _hasXtreamSession(prefs) ? 'xtream' : 'm3u';
      homeScreen = DashboardScreen(sessionType: sessionType);
    } else {
      homeScreen = const LoginScreen();
    }
  } else if (!reg.registered) {
    // Device not registered → show activation screen
    homeScreen = ActivationScreen(deviceId: deviceId);
  } else if (!reg.trialActive) {
    // Trial/subscription expired
    homeScreen = _SubscriptionExpiredScreen(
      deviceId: deviceId,
      expireDate: reg.trialExpire,
    );
  } else {
    // Registered + active → authenticate to get/refresh stream credentials
    final auth = await BackendService.authenticate(deviceId);

    if (auth.success && auth.user != null) {
      final user = auth.user!;
      // Save/update credentials
      if (user.m3uUrl.isNotEmpty) {
        await prefs.setString('m3u_active_url', user.m3uUrl);
        await prefs.remove('xtream_server');
        homeScreen = const DashboardScreen(sessionType: 'm3u');
      } else {
        await prefs.setString('xtream_server', user.serverUrl);
        await prefs.setString('xtream_username', user.username);
        await prefs.setString('xtream_password', user.password);
        await prefs.remove('m3u_active_url');
        await xtreamService.loadSavedPlaylist();
        homeScreen = const DashboardScreen(sessionType: 'xtream');
      }
    } else if (auth.statusCode == 404) {
      homeScreen = ActivationScreen(deviceId: deviceId);
    } else if (auth.statusCode == 403) {
      homeScreen = _SubscriptionExpiredScreen(deviceId: deviceId);
    } else {
      // Auth failed but we may have a cached session
      final hasSession = _hasXtreamSession(prefs) || _hasM3uSession(prefs);
      if (hasSession) {
        final sessionType = _hasXtreamSession(prefs) ? 'xtream' : 'm3u';
        homeScreen = DashboardScreen(sessionType: sessionType);
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
