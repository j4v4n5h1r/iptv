import 'package:firebase_auth/firebase_auth.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'dart:io' show Platform;

/// A service class for handling user authentication with Firebase.
///
/// This class uses a ChangeNotifier to notify UI components of authentication
/// state changes (e.g., when a user signs in or out).
class AuthService extends ChangeNotifier {
  // The Firebase Auth instance.
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Retrieves a unique device ID.
  ///
  /// The ID is retrieved from shared preferences if it already exists.
  /// Otherwise, it gets a platform-specific ID (Android ID, iOS vendor ID)
  /// and saves it to shared preferences for future use.
  /// A timestamp is used as a fallback if the platform-specific ID cannot be retrieved.
  Future<String?> getDeviceId() async {
    final deviceInfo = DeviceInfoPlugin();
    final prefs = await SharedPreferences.getInstance();

    // Try to get an existing device ID from local storage
    String? deviceId = prefs.getString('device_id');
    if (deviceId != null) {
      return deviceId;
    }

    // If no device ID exists, generate a new one based on the platform.
    try {
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        deviceId = androidInfo.id;
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        deviceId = iosInfo.identifierForVendor;
      } else {
        // Fallback for other platforms or in case of an error
        deviceId = DateTime.now().millisecondsSinceEpoch.toString();
      }
    } catch (e) {
      // Use a fallback ID if an error occurs during retrieval
      debugPrint('Error getting device ID: $e');
      deviceId = DateTime.now().millisecondsSinceEpoch.toString();
    }

    // Save the new device ID to shared preferences
    if (deviceId != null) {
      await prefs.setString('device_id', deviceId);
    }
    
    return deviceId;
  }

  /// Signs in a user with an email and password.
  ///
  /// Upon successful sign-in, it calls a method to register the device ID
  /// with a backend.
  Future<bool> signIn(String username, String password) async {
    try {
      final result = await _auth.signInWithEmailAndPassword(
        email: username,
        password: password,
      );
      if (result.user != null) {
        final deviceId = await getDeviceId();
        if (deviceId != null) {
          // Register the device with the backend
          await _registerDeviceWithBackend(result.user!.uid, deviceId);
        }
      }
      // Notify listeners that the user has successfully logged in
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      // Handle login errors, providing more specific feedback
      debugPrint('Firebase Auth Error: ${e.code}');
      // You could return a specific error message here for the UI
      return false;
    } catch (e) {
      // Catch any other unexpected errors
      debugPrint('General Sign-In Error: $e');
      return false;
    }
  }

  /// Registers a new user with an email and password.
  ///
  /// Upon successful registration, it calls a method to register the device ID
  /// with a backend.
  Future<bool> register(String username, String password) async {
    try {
      final result = await _auth.createUserWithEmailAndPassword(
        email: username,
        password: password,
      );
      if (result.user != null) {
        final deviceId = await getDeviceId();
        if (deviceId != null) {
          // Register the device with the backend
          await _registerDeviceWithBackend(result.user!.uid, deviceId);
        }
      }
      // Notify listeners that the user has successfully registered
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      // Handle registration errors, providing more specific feedback
      debugPrint('Firebase Auth Registration Error: ${e.code}');
      // You could return a specific error message here for the UI
      return false;
    } catch (e) {
      // Catch any other unexpected errors
      debugPrint('General Registration Error: $e');
      return false;
    }
  }

  /// Signs out the current user.
  ///
  /// Notifies listeners of the change in state.
  Future<void> signOut() async {
    await _auth.signOut();
    // Notify listeners that the user has logged out
    notifyListeners();
  }

  /// Placeholder for registering the user's device with a backend service.
  ///
  /// This method would typically make an API call (e.g., using the `http` package)
  /// to your server to associate the user's ID with their device ID.
  Future<void> _registerDeviceWithBackend(
      String userId, String deviceId) async {
    // TODO: Implement your backend API call here.
    // Example:
    /*
    final url = Uri.parse('YOUR_API_ENDPOINT/register-device');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'userId': userId,
        'deviceId': deviceId,
      }),
    );
    if (response.statusCode == 200) {
      debugPrint('Device registered successfully.');
    } else {
      debugPrint('Failed to register device: ${response.body}');
    }
    */
  }
}
