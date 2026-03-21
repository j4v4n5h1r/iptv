# Media Player — Required Changes for Backend Integration

Repository: `git@github.com:j4v4n5h1r/iptv.git`

Backend panel: This repo (`iptv-media-player-panel`), running on `http://YOUR_SERVER_IP:3000`

---

## Backend URL Config

Add a single config file so the URL is changed in one place:

```dart
// lib/config.dart
const String kBackendUrl = 'http://YOUR_SERVER_IP:3000';
```

---

## App Startup Flow

On every cold launch, run these calls **in order**:

```
1. GET  /api/settings       → load login title/subtitle, MAC format
2. POST /api/device/register { mac_address } → check if device is known
   ├─ registered == true  → POST /api/auth { mac_address } → go to home
   └─ registered == false → show ActivationCodeScreen
3. GET  /api/update         → check for APK update (show dialog if newer)
4. GET  /api/notification   → show banner/dialog if title is non-empty
```

---

## 1. Replace Firebase Auth with MAC-Based Auth

**Current:** Firebase email/password auth
**Change:** On first launch, read the device MAC address and call the backend.

```dart
// lib/services/auth_service.dart
Future<Map<String, dynamic>> authenticateByMac(String macAddress) async {
  final res = await http.post(
    Uri.parse('$kBackendUrl/api/auth'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'mac_address': macAddress}),
  );
  return jsonDecode(res.body) as Map<String, dynamic>;
}
```

Remove Firebase packages (`firebase_auth`, `firebase_core`) unless used elsewhere.

---

## 2. Get Device MAC / Stable Device ID

**Add package:** `device_info_plus`

> On Android 10+, Wi-Fi MAC is randomized per network — use `androidId` as a stable identifier instead.

```dart
// lib/services/device_service.dart
import 'package:device_info_plus/device_info_plus.dart';

Future<String> getDeviceId() async {
  final info = DeviceInfoPlugin();
  if (Platform.isAndroid) {
    final android = await info.androidInfo;
    // androidId is stable per device/signing key (treat as MAC)
    return android.id.toUpperCase();
  } else if (Platform.isIOS) {
    final ios = await info.iosInfo;
    return ios.identifierForVendor?.toUpperCase() ?? 'UNKNOWN';
  }
  return 'UNKNOWN';
}
```

Pass this value everywhere a `mac_address` field is required.

---

## 3. Check Device Registration on Startup

```dart
// POST /api/device/register
// Body: { "mac_address": "DEVICE_ID" }
// Response:
// {
//   "success": true,
//   "registered": true/false,
//   "trial_active": true/false,
//   "trial_expire": "2025-12-31" | null
// }

Future<Map> checkRegistration(String macAddress) async {
  final res = await http.post(
    Uri.parse('$kBackendUrl/api/device/register'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'mac_address': macAddress}),
  );
  return jsonDecode(res.body);
}
```

If `registered == false` → navigate to `ActivationCodeScreen`.
If `registered == true` AND `trial_active == false` → show "subscription expired" screen.

---

## 4. Activation Code Screen

Add a screen where users enter a code if their device is not registered.

```dart
// Activation flow:
// 1. App starts → POST /api/device/register
// 2. registered == false → show ActivationCodeScreen
// 3. User enters code → POST /api/activate
// 4. On success → POST /api/auth → go home

// POST /api/activate
// Body: { "mac_address": "DEVICE_ID", "code": "XXXX-XXXX-XXXX-XXXX" }
// Response (success):
// {
//   "success": true,
//   "message": "Activated successfully.",
//   "server": { "url": "http://...", "title": "..." }
// }
```

New screen: `lib/screens/activation_screen.dart`

---

## 5. Authenticate and Get Stream Credentials

```dart
// POST /api/auth
// Body: { "mac_address": "DEVICE_ID" }
// Response (success):
// {
//   "success": true,
//   "user": {
//     "id": 1,
//     "title": "John Doe",
//     "username": "stream_user",
//     "password": "stream_pass",
//     "server_url": "http://iptv-server:8080",
//     "server_title": "Main Server",
//     "m3u_url": "",          // optional direct M3U override
//     "protection": "YES"/"NO"
//   },
//   "trial": { "expire_date": "2025-12-31" } | null,
//   "notification": { "title": "", "content": "" },
//   "login_text": { "title": "Welcome", "subtitle": "Sign in to continue" }
// }
```

**Build the M3U playlist URL from the response:**

```dart
final serverUrl = authResponse['user']['server_url'];  // e.g. http://iptv.example.com:8080
final username  = authResponse['user']['username'];
final password  = authResponse['user']['password'];
final m3uUrl    = authResponse['user']['m3u_url'];  // direct override (may be empty)

// If direct M3U URL is provided, use it; otherwise build standard XtreamCodes URL:
final playlistUrl = m3uUrl.isNotEmpty
    ? m3uUrl
    : '$serverUrl/get.php?username=$username&password=$password&type=m3u_plus';

// XtreamCodes API URL (for categories/streams):
final apiBase = '$serverUrl/player_api.php?username=$username&password=$password';
```

Error cases from `/api/auth`:
- `404` → MAC not registered → show activation screen
- `403` → subscription expired → show renewal message

---

## 6. Load App Settings on Startup

```dart
// GET /api/settings
// Response:
// {
//   "success": true,
//   "settings": {
//     "mac_length": "12",
//     "login_title": "Welcome",
//     "login_subtitle": "Sign in to continue",
//     "notification": { "title": "", "content": "" },
//     "update": { "version": "1.2.0", "url": "http://..." }
//   }
// }

// Use mac_length to format/validate the device ID input on the activation screen
```

---

## 7. Fetch Notification

```dart
// GET /api/notification
// Response:
// { "success": true, "notification": { "title": "...", "content": "..." } }

// After successful auth, if notification.title is non-empty → show dialog/banner
```

---

## 8. Check for App Update

```dart
import 'package:package_info_plus/package_info_plus.dart';

Future<void> checkForUpdate() async {
  final res = await http.get(Uri.parse('$kBackendUrl/api/update'));
  final data = jsonDecode(res.body);
  if (data['update']['has_update'] == true) {
    final info = await PackageInfo.fromPlatform();
    if (data['update']['version'] != info.version) {
      // Show update dialog with APK download URL:
      final apkUrl = data['update']['url'];
      // Open apkUrl in browser or download directly
    }
  }
}
```

---

## 9. Get Demo Playlist (Guest / Unregistered Users)

```dart
// GET /api/demo
// Response (if demo is configured):
// {
//   "success": true,
//   "demo": {
//     "playlist_name": "Demo",
//     "dns": "http://demo-server:8080",
//     "username": "demo_user",
//     "password": "demo_pass"
//   }
// }
// Response (if no demo): 404 { "success": false, "error": "No demo configured." }
```

Show a "Try Demo" button on the activation screen. On tap, call `GET /api/demo` and use those credentials to load a limited playlist.

---

## Summary of API Calls

| When | Method | Endpoint | Purpose |
|------|--------|----------|---------|
| App start | GET | `/api/settings` | Login text, MAC format |
| App start | POST | `/api/device/register` | Check if device is known |
| Not registered | POST | `/api/activate` | Activate with code |
| Login | POST | `/api/auth` | Get stream credentials |
| After login | GET | `/api/notification` | Show notification if any |
| After login | GET | `/api/update` | Check for APK update |
| Guest | GET | `/api/demo` | Demo playlist credentials |

---

## Flutter Packages Needed

```yaml
# pubspec.yaml
dependencies:
  http: ^1.1.0
  device_info_plus: ^9.1.0
  package_info_plus: ^5.0.1
  shared_preferences: ^2.2.2   # cache device ID + auth response locally
```

---

## Error Handling Pattern

```dart
// All API responses follow: { "success": true/false, "error": "..." }
// Always check success before reading data:

final body = jsonDecode(res.body);
if (res.statusCode != 200 || body['success'] != true) {
  final msg = body['error'] ?? 'Unknown error';
  // show error to user
  return;
}
// use body['user'], body['demo'], etc.
```

---

## Notes

- `protection` field: if `"YES"`, show a PIN/password lock UI before loading the playlist.
- `trial.expire_date`: display expiry date to user in the settings/account screen.
- The panel also supports `m3u_url` as a direct override URL per user — check if non-empty before constructing the standard XtreamCodes URL.
- `mac_length` from settings tells the app how many characters to expect in the activation code entry — use it to format the MAC display or validate entry length on the activation screen.
