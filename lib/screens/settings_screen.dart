// lib/screens/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _deviceInfo = 'Getting device info...';
  String _networkInfo = 'Getting network info...';
  final FocusNode _logoutFocusNode = FocusNode();
  final FocusNode _backButtonFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _getDeviceInfo();
    _getNetworkInfo();
    // Request focus after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
      _logoutFocusNode.requestFocus();
    });
  }

  Future<void> _getDeviceInfo() async {
    final deviceInfoPlugin = DeviceInfoPlugin();
    String deviceInfoText;

    try {
      if (Theme.of(context).platform == TargetPlatform.android) {
        final androidInfo = await deviceInfoPlugin.androidInfo;
        deviceInfoText = 'Android: ${androidInfo.model}';
      } else if (Theme.of(context).platform == TargetPlatform.iOS) {
        final iosInfo = await deviceInfoPlugin.iosInfo;
        deviceInfoText = 'iOS: ${iosInfo.name}';
      } else {
        deviceInfoText = 'Platform not supported';
      }
    } catch (e) {
      deviceInfoText = 'Failed to get device info: $e';
    }

    if (mounted) {
      setState(() {
        _deviceInfo = deviceInfoText;
      });
    }
  }

  Future<void> _getNetworkInfo() async {
    final networkInfo = NetworkInfo();
    String networkInfoText;

    try {
      final wifiIP = await networkInfo.getWifiIP();
      final wifiName = await networkInfo.getWifiName();
      networkInfoText = 'Wi-Fi Name: $wifiName\nIP Address: $wifiIP';
    } catch (e) {
      networkInfoText = 'Failed to get network info: $e';
    }

    if (mounted) {
      setState(() {
        _networkInfo = networkInfoText;
      });
    }
  }

  void _handleLogout(BuildContext context) async {
    final authService = Provider.of<AuthService>(context, listen: false);
    await authService.signOut();
    Navigator.pushNamedAndRemoveUntil(
      context,
      '/login',
      (Route<dynamic> route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: {
        LogicalKeySet(LogicalKeyboardKey.select): const ActivateIntent(),
        LogicalKeySet(LogicalKeyboardKey.enter): const ActivateIntent(),
        LogicalKeySet(LogicalKeyboardKey.arrowUp): const DirectionalFocusIntent(TraversalDirection.up),
        LogicalKeySet(LogicalKeyboardKey.arrowDown): const DirectionalFocusIntent(TraversalDirection.down),
      },
      child: FocusTraversalGroup(
        policy: OrderedTraversalPolicy(),
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Settings'),
            leading: FocusableActionDetector(
              focusNode: _backButtonFocusNode,
              onShowFocusHighlight: (value) => setState(() {}),
              actions: <Type, Action<Intent>>{
                ActivateIntent: CallbackAction<ActivateIntent>(
                  onInvoke: (ActivateIntent intent) => Navigator.pop(context),
                ),
              },
              child: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
                style: IconButton.styleFrom(
                  backgroundColor: _backButtonFocusNode.hasFocus
                      ? Colors.deepOrange.withOpacity(0.3)
                      : null,
                ),
              ),
            ),
          ),
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Device Information',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8.0),
                Text(
                  _deviceInfo,
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 16.0),
                Text(
                  'Network Information',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8.0),
                Text(
                  _networkInfo,
                  style: const TextStyle(color: Colors.white70),
                ),
                const Spacer(),
                Center(
                  child: FocusableActionDetector(
                    focusNode: _logoutFocusNode,
                    onShowFocusHighlight: (value) => setState(() {}),
                    actions: <Type, Action<Intent>>{
                      ActivateIntent: CallbackAction<ActivateIntent>(
                        onInvoke: (ActivateIntent intent) => _handleLogout(context),
                      ),
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 100),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: _logoutFocusNode.hasFocus
                            ? Border.all(color: Colors.white, width: 2)
                            : null,
                        boxShadow: _logoutFocusNode.hasFocus
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
                        onPressed: () => _handleLogout(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _logoutFocusNode.hasFocus
                              ? Colors.deepOrange.shade700
                              : Colors.deepOrange,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Logout',
                          style: TextStyle(fontSize: 18, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _logoutFocusNode.dispose();
    _backButtonFocusNode.dispose();
    super.dispose();
  }
}