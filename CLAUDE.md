# ViewNax IPTV Player — Project Notes

## Server
- **IP:** 137.74.16.146
- **User:** ubuntu
- **Password:** IpTv@2026
- **Panel URL:** http://137.74.16.146 (port 80)
- **Panel default login:** admin / admin123
- **Panel path:** /var/www/html
- **DB path:** /var/www/html/data/iptv.db
- **PM2 process:** iptv-panel (runs as root)
- **SSH key:** ~/.ssh/id_ed25519 (javanshir@decentralizedlabs.ai)

## Deploy
```bash
ssh-add ~/.ssh/id_ed25519
sshpass -p "IpTv@2026" rsync -avz --exclude='node_modules' --exclude='data' panel/ ubuntu@137.74.16.146:/var/www/html/
sshpass -p "IpTv@2026" ssh ubuntu@137.74.16.146 "sudo pm2 restart iptv-panel"
```

## Architecture
- **Flutter app:** Android/Fire TV IPTV player
- **Panel:** Node.js/Express + EJS + SQLite (better-sqlite3)
- **Auth flow:** Device MAC → activation code → backend assigns xtream credentials

## Auth Flow
1. App starts → reads MAC address as deviceId
2. POST /api/device/register → checks if MAC is in mac_users
3. If registered → POST /api/auth → returns xtream server/username/password
4. App saves credentials to SharedPreferences, loads playlist
5. On logout → clears SharedPreferences → shows ActivationScreen

## Key Decisions
- LoginScreen (manual server/user/pass) removed from flow — all auth via activation code
- Activation code = alphanumeric, entered on ActivationScreen numpad
- After activation, xtream credentials come from panel automatically
- Fast startup: if cached session exists, show dashboard immediately; refresh credentials in background

## Flutter App
- **Entry:** lib/main.dart
- **Screens:** activation_screen.dart, dashboard_screen.dart, home_screen.dart, player_screen.dart
- **Services:** backend_service.dart (timeout: 6s), xtream_service.dart, device_service.dart
- Backend URL defined in: lib/config.dart

## Panel Pages
- MAC Users — add users with server_url + xtream username/password
- MAC Users page also has activation code generation and list
- DNS Settings — IPTV server list
- No separate Activation Codes nav item (merged into MAC Users)

## Git
- Remote: git@github.com:j4v4n5h1r/iptv.git
- Branch: main
- SSH key must be id_ed25519 (j4v4n5h1r account)
