import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/backend_service.dart';
import '../services/xtream_service.dart';
import 'dashboard_screen.dart';

const _kBg   = Color(0xFF1A0F00);
const _kCard = Color(0xFF2C1A06);
const _kBlue = Color(0xFFD4A017);

class ActivationScreen extends StatefulWidget {
  final String appKey;
  const ActivationScreen({super.key, required this.appKey});

  @override
  State<ActivationScreen> createState() => _ActivationScreenState();
}

class _ActivationScreenState extends State<ActivationScreen> {
  bool _isLoading = false;
  bool _isDemoLoading = false;
  String? _error;
  String _enteredCode = ''; // raw digits only, max 16

  String get _formattedCode {
    final raw = _enteredCode;
    final buf = StringBuffer();
    for (int i = 0; i < raw.length; i++) {
      if (i > 0 && i % 4 == 0) buf.write('-');
      buf.write(raw[i]);
    }
    return buf.toString();
  }

  void _addChar(String ch) {
    if (_enteredCode.length >= 16) return;
    setState(() => _enteredCode = _enteredCode + ch);
  }

  void _backspace() {
    if (_enteredCode.isEmpty) return;
    setState(() => _enteredCode = _enteredCode.substring(0, _enteredCode.length - 1));
  }

  Future<void> _activate() async {
    if (_enteredCode.length < 4) {
      setState(() => _error = 'Please enter your activation code');
      return;
    }
    setState(() { _isLoading = true; _error = null; });

    final err = await BackendService.activateDevice(widget.appKey, _enteredCode);
    if (!mounted) return;

    if (err != null) {
      setState(() { _isLoading = false; _error = err; });
      return;
    }

    final auth = await BackendService.authenticate(widget.appKey);
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (!auth.success) {
      setState(() => _error = auth.error ?? 'Authentication failed');
      return;
    }

    await _saveAndNavigate(auth);
  }

  Future<void> _tryDemo() async {
    setState(() { _isDemoLoading = true; _error = null; });
    final demo = await BackendService.fetchDemo();
    if (!mounted) return;
    setState(() => _isDemoLoading = false);

    if (!demo.success || demo.dns == null) {
      setState(() => _error = demo.error ?? 'No demo available');
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('xtream_server', demo.dns!);
    await prefs.setString('xtream_username', demo.username ?? '');
    await prefs.setString('xtream_password', demo.password ?? '');
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const DashboardScreen(sessionType: 'xtream')),
    );
  }

  Future<void> _saveAndNavigate(AuthResult auth) async {
    final user = auth.user!;
    final xtream = Provider.of<XtreamService>(context, listen: false);
    final prefs = await SharedPreferences.getInstance();

    if (user.m3uUrl.isNotEmpty) {
      await prefs.setString('m3u_active_url', user.m3uUrl);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const DashboardScreen(sessionType: 'm3u')),
      );
    } else if (user.serverUrl.isNotEmpty) {
      await prefs.setString('xtream_server', user.serverUrl);
      await prefs.setString('xtream_username', user.username);
      await prefs.setString('xtream_password', user.password);
      await xtream.loadSavedPlaylist();
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const DashboardScreen(sessionType: 'xtream')),
      );
    } else {
      // Backend'de credentials henüz girilmemiş — yine de dashboard'a geç
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const DashboardScreen(sessionType: 'xtream')),
      );
    }

    if (auth.notificationTitle != null && auth.notificationTitle!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: _kCard,
            title: Text(auth.notificationTitle!, style: const TextStyle(color: Colors.white)),
            content: Text(auth.notificationContent ?? '', style: const TextStyle(color: Colors.white70)),
            actions: [
              TextButton(
                autofocus: true,
                onPressed: () => Navigator.pop(context),
                child: const Text('OK', style: TextStyle(color: _kBlue)),
              ),
            ],
          ),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(child: Image.asset('assets/wood-bg-dark.jpg', fit: BoxFit.cover)),
          Container(color: Colors.black.withValues(alpha: 0.45)),
          SafeArea(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Stack(
                      children: [
                        ColorFiltered(
                          colorFilter: const ColorFilter.matrix([
                            0.55,0,0,0,0, 0,0.55,0,0,0, 0,0,0.55,0,0, 0,0,0,1,0
                          ]),
                          child: Image.asset('assets/wood-tile-warm.png',
                              width: 220, height: 48, fit: BoxFit.cover),
                        ),
                        Container(
                          width: 220, height: 48,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.30),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.tv, color: Color(0xFFF5E6D0), size: 18),
                              SizedBox(width: 8),
                              Text('VIEWNUX',
                                style: TextStyle(
                                  color: Color(0xFFF5E6D0),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  letterSpacing: 5,
                                  shadows: [Shadow(color: Colors.black, blurRadius: 6)],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  // App Key
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                    ),
                    child: Column(
                      children: [
                        const Text('App Key', style: TextStyle(color: Colors.white38, fontSize: 10, letterSpacing: 1)),
                        const SizedBox(height: 2),
                        Text(
                          widget.appKey,
                          style: const TextStyle(
                            color: Color(0xFFD4A017),
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Code display
                  Container(
                    width: 320,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                    ),
                    child: Column(
                      children: [
                        const Text('Enter Activation Code',
                            style: TextStyle(color: Color(0xFFF5E6D0), fontSize: 13)),
                        const SizedBox(height: 8),
                        Text(
                          _formattedCode.isEmpty ? '---- ---- ---- ----' : _formattedCode,
                          style: TextStyle(
                            color: _formattedCode.isEmpty ? Colors.white24 : Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 3,
                          ),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 6),
                          Text(_error!, style: const TextStyle(color: Color(0xFFFFB347), fontSize: 11)),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  _buildNumpad(),
                  const SizedBox(height: 12),

                  // Activate button
                  SizedBox(
                    width: 320,
                    height: 48,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ColorFiltered(
                            colorFilter: const ColorFilter.matrix([
                              0.7,0,0,0,0, 0,0.7,0,0,0, 0,0,0.7,0,0, 0,0,0,1,0
                            ]),
                            child: Image.asset('assets/wood-tile-warm.png', fit: BoxFit.cover),
                          ),
                          Material(
                            color: Colors.black.withValues(alpha: 0.20),
                            child: InkWell(
                              onTap: _isLoading ? null : _activate,
                              child: Center(
                                child: _isLoading
                                    ? const SizedBox(width: 20, height: 20,
                                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                    : const Text('Activate',
                                        style: TextStyle(color: Color(0xFFF5E6D0),
                                            fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 1)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Demo button
                  SizedBox(
                    width: 320,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: const BorderSide(color: Colors.white24),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _isDemoLoading ? null : _tryDemo,
                      child: _isDemoLoading
                          ? const SizedBox(width: 18, height: 18,
                              child: CircularProgressIndicator(color: Colors.white54, strokeWidth: 2))
                          : const Text('Try Demo'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNumpad() {
    final rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['⌫', '0', '✓'],
    ];

    return Column(
      children: rows.map((row) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: row.map((key) {
            return Padding(
              padding: const EdgeInsets.all(4),
              child: Focus(
                onKeyEvent: (node, event) {
                  if (event is! KeyDownEvent) return KeyEventResult.ignored;
                  final k = event.logicalKey;
                  if (k == LogicalKeyboardKey.select || k == LogicalKeyboardKey.enter) {
                    if (key == '⌫') {
                      _backspace();
                    } else if (key == '✓') {
                      _activate();
                    } else {
                      _addChar(key);
                    }
                    return KeyEventResult.handled;
                  }
                  return KeyEventResult.ignored;
                },
                child: Builder(builder: (ctx) {
                  final focused = Focus.of(ctx).hasFocus;
                  return GestureDetector(
                    onTap: () {
                      if (key == '⌫') {
                        _backspace();
                      } else if (key == '✓') {
                        _activate();
                      } else {
                        _addChar(key);
                      }
                    },
                    child: SizedBox(
                      width: 76, height: 56,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            ColorFiltered(
                              colorFilter: ColorFilter.matrix(focused
                                  ? [0.85,0,0,0,0, 0,0.85,0,0,0, 0,0,0.85,0,0, 0,0,0,1,0]
                                  : [0.45,0,0,0,0, 0,0.45,0,0,0, 0,0,0.45,0,0, 0,0,0,1,0]),
                              child: Image.asset('assets/wood-tile-warm.png', fit: BoxFit.cover),
                            ),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 120),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: focused ? 0.10 : 0.35),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: focused ? Colors.white.withValues(alpha: 0.7) : Colors.white.withValues(alpha: 0.12),
                                  width: focused ? 2 : 1,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                key,
                                style: TextStyle(
                                  color: focused ? Colors.white : const Color(0xFFF5E6D0),
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  shadows: const [Shadow(color: Colors.black, blurRadius: 4)],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            );
          }).toList(),
        );
      }).toList(),
    );
  }
}
