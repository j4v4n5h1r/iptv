// lib/screens/login_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import 'home_screen.dart';
import 'registration_screen.dart'; // Import the new screen

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  final FocusNode _usernameFocusNode = FocusNode();
  final FocusNode _passwordFocusNode = FocusNode();
  final FocusNode _loginButtonFocusNode = FocusNode();
  final FocusNode _registerButtonFocusNode = FocusNode(); // New focus node

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _usernameFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _usernameFocusNode.dispose();
    _passwordFocusNode.dispose();
    _loginButtonFocusNode.dispose();
    _registerButtonFocusNode.dispose(); // Dispose the new focus node
    super.dispose();
  }

  void _handleLogin() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final success = await authService.signIn(
      _usernameController.text,
      _passwordController.text,
    );
    if (success && mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Login failed')),
      );
    }
  }

  void _navigateToRegistration() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const RegistrationScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Shortcuts(
          shortcuts: {
            LogicalKeySet(LogicalKeyboardKey.arrowDown): const NextFocusIntent(),
            LogicalKeySet(LogicalKeyboardKey.arrowUp): const PreviousFocusIntent(),
            LogicalKeySet(LogicalKeyboardKey.select): const ActivateIntent(),
            LogicalKeySet(LogicalKeyboardKey.enter): const ActivateIntent(),
          },
          child: FocusTraversalGroup(
            policy: OrderedTraversalPolicy(),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.connected_tv,
                    color: Colors.deepOrange,
                    size: 80,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Wallyt Login',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 50),
                  Focus(
                    focusNode: _usernameFocusNode,
                    child: Builder(
                      builder: (context) {
                        final hasFocus = _usernameFocusNode.hasFocus;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 100),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10.0),
                            border: hasFocus
                                ? Border.all(color: Colors.deepOrange, width: 2)
                                : null,
                          ),
                          child: TextField(
                            controller: _usernameController,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: 'Username',
                              labelStyle: const TextStyle(color: Colors.white70),
                              filled: true,
                              fillColor: Colors.grey[800],
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10.0),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  Focus(
                    focusNode: _passwordFocusNode,
                    child: Builder(
                      builder: (context) {
                        final hasFocus = _passwordFocusNode.hasFocus;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 100),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10.0),
                            border: hasFocus
                                ? Border.all(color: Colors.deepOrange, width: 2)
                                : null,
                          ),
                          child: TextField(
                            controller: _passwordController,
                            obscureText: true,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: 'Password',
                              labelStyle: const TextStyle(color: Colors.white70),
                              filled: true,
                              fillColor: Colors.grey[800],
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10.0),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                  FocusableActionDetector(
                    focusNode: _loginButtonFocusNode,
                    onShowFocusHighlight: (value) => setState(() {}),
                    actions: <Type, Action<Intent>>{
                      ActivateIntent: CallbackAction<ActivateIntent>(
                        onInvoke: (ActivateIntent intent) => _handleLogin(),
                      ),
                    },
                    child: Builder(
                      builder: (context) {
                        final hasFocus = _loginButtonFocusNode.hasFocus;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 100),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10.0),
                            border: hasFocus
                                ? Border.all(color: Colors.white, width: 2)
                                : null,
                            boxShadow: hasFocus
                                ? [
                                    BoxShadow(
                                      color: Colors.deepOrange.withOpacity(0.5),
                                      spreadRadius: 2,
                                      blurRadius: 5,
                                      offset: const Offset(0, 0),
                                    )
                                  ]
                                : null,
                          ),
                          child: ElevatedButton(
                            onPressed: _handleLogin,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              backgroundColor: hasFocus
                                  ? Colors.deepOrange.shade700
                                  : Colors.deepOrange,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                            ),
                            child: const Text(
                              'Login',
                              style: TextStyle(fontSize: 18, color: Colors.white),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16), // Add spacing
                  FocusableActionDetector(
                    focusNode: _registerButtonFocusNode,
                    onShowFocusHighlight: (value) => setState(() {}),
                    actions: <Type, Action<Intent>>{
                      ActivateIntent: CallbackAction<ActivateIntent>(
                        onInvoke: (ActivateIntent intent) => _navigateToRegistration(),
                      ),
                    },
                    child: Builder(
                      builder: (context) {
                        final hasFocus = _registerButtonFocusNode.hasFocus;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 100),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10.0),
                            border: hasFocus
                                ? Border.all(color: Colors.white, width: 2)
                                : null,
                            boxShadow: hasFocus
                                ? [
                                    BoxShadow(
                                      color: Colors.deepOrange.withOpacity(0.5),
                                      spreadRadius: 2,
                                      blurRadius: 5,
                                      offset: const Offset(0, 0),
                                    )
                                  ]
                                : null,
                          ),
                          child: ElevatedButton(
                            onPressed: _navigateToRegistration,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              backgroundColor: hasFocus
                                  ? Colors.deepOrange.shade700
                                  : Colors.deepOrange,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                            ),
                            child: const Text(
                              'Register',
                              style: TextStyle(fontSize: 18, color: Colors.white),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}