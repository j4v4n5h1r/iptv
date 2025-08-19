// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'services/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Set system UI overlay style for TV
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.leanBack);
  
  runApp(
    ChangeNotifierProvider(
      create: (context) => AuthService(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

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
              backgroundColor: Colors.black,
              elevation: 0,
            ),
            // Add TV-friendly text styles
            textTheme: const TextTheme(
              displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
              displayMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              displaySmall: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              headlineMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              headlineSmall: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              titleLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          home: StreamBuilder<User?>(
            stream: FirebaseAuth.instance.authStateChanges(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(
                    child: CircularProgressIndicator(
                      color: Colors.deepOrange,
                    ),
                  ),
                );
              }
              if (snapshot.hasData) {
                return const HomeScreen();
              }
              return const LoginScreen();
            },
          ),
          // Add TV-friendly page transitions
          onGenerateRoute: (settings) {
            return PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) {
                switch (settings.name) {
                  default:
                    return const LoginScreen();
                }
              },
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                return FadeTransition(
                  opacity: animation,
                  child: child,
                );
              },
              transitionDuration: const Duration(milliseconds: 300),
            );
          },
        ),
      ),
    );
  }
}