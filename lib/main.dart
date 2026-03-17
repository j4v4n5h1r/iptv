import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:media_kit/media_kit.dart'; // ignore: depend_on_referenced_packages
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'services/xtream_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  // Force landscape on TV/FireStick
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  final prefs = await SharedPreferences.getInstance();
  final xtreamService = XtreamService();

  // Oturum türünü kontrol et: xtream veya m3u
  final hasXtream = prefs.getString('xtream_server') != null;
  final hasM3u = prefs.getString('m3u_active_url') != null;

  if (hasXtream) await xtreamService.loadSavedPlaylist();

  runApp(
    MultiProvider(
      providers: [
        Provider<XtreamService>.value(value: xtreamService),
      ],
      child: MyApp(
        hasSession: hasXtream || hasM3u,
        sessionType: hasXtream ? 'xtream' : hasM3u ? 'm3u' : null,
      ),
    ),
  );
}

class MyApp extends StatelessWidget {
  final bool hasSession;
  final String? sessionType;

  const MyApp({super.key, required this.hasSession, this.sessionType});

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
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
            primarySwatch: Colors.deepOrange,
            scaffoldBackgroundColor: Colors.black,
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFF1A1A2E),
              elevation: 0,
            ),
          ),
          home: hasSession
              ? HomeScreen(sessionType: sessionType!)
              : const LoginScreen(),
          onGenerateRoute: (_) => PageRouteBuilder(
            pageBuilder: (_, __, ___) => const LoginScreen(),
            transitionsBuilder: (_, animation, __, child) =>
                FadeTransition(opacity: animation, child: child),
            transitionDuration: const Duration(milliseconds: 300),
          ),
        ),
      ),
    );
  }
}
