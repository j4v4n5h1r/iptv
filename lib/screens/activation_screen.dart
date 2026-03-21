import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/backend_service.dart';
import 'dashboard_screen.dart';

const _kBg   = Color(0xFF0B1118);
const _kCard = Color(0xFF1A242D);
const _kBlue = Color(0xFF60A5FA);

class ActivationScreen extends StatefulWidget {
  final String deviceId;
  const ActivationScreen({super.key, required this.deviceId});

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

    final err = await BackendService.activateDevice(widget.deviceId, _formattedCode);
    if (!mounted) return;

    if (err != null) {
      setState(() { _isLoading = false; _error = err; });
      return;
    }

    final auth = await BackendService.authenticate(widget.deviceId);
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
    final prefs = await SharedPreferences.getInstance();

    if (user.m3uUrl.isNotEmpty) {
      await prefs.setString('m3u_active_url', user.m3uUrl);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const DashboardScreen(sessionType: 'm3u')),
      );
    } else {
      await prefs.setString('xtream_server', user.serverUrl);
      await prefs.setString('xtream_username', user.username);
      await prefs.setString('xtream_password', user.password);
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
      backgroundColor: _kBg,
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RichText(
                text: const TextSpan(
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 4),
                  children: [
                    TextSpan(text: 'WALLYT', style: TextStyle(color: _kBlue)),
                    TextSpan(text: 'TV', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Device ID: ${widget.deviceId}',
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
              const SizedBox(height: 32),

              // Code display
              Container(
                width: 340,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: BoxDecoration(
                  color: _kCard,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    const Text('Enter Activation Code',
                        style: TextStyle(color: Colors.white70, fontSize: 14)),
                    const SizedBox(height: 12),
                    Text(
                      _formattedCode.isEmpty ? '---- ---- ---- ----' : _formattedCode,
                      style: TextStyle(
                        color: _formattedCode.isEmpty ? Colors.white24 : Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 3,
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 8),
                      Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),

              _buildNumpad(),
              const SizedBox(height: 20),

              // Activate button
              SizedBox(
                width: 340,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _isLoading ? null : _activate,
                  child: _isLoading
                      ? const SizedBox(
                          width: 22, height: 22,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Activate',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 12),

              // Demo button
              SizedBox(
                width: 340,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: const BorderSide(color: Colors.white24),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _isDemoLoading ? null : _tryDemo,
                  child: _isDemoLoading
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(color: Colors.white54, strokeWidth: 2))
                      : const Text('Try Demo'),
                ),
              ),
            ],
          ),
        ),
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
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      width: 76,
                      height: 56,
                      decoration: BoxDecoration(
                        color: focused ? _kBlue : _kCard,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: focused ? _kBlue : Colors.white12,
                          width: focused ? 2 : 1,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        key,
                        style: TextStyle(
                          color: focused ? Colors.white : Colors.white70,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
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
