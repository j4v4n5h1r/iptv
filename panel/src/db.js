const Database = require('better-sqlite3');
const bcrypt = require('bcryptjs');
const path = require('path');

const DB_PATH = path.join(__dirname, '..', 'data', 'iptv.db');

// Ensure data directory exists
const fs = require('fs');
const dataDir = path.join(__dirname, '..', 'data');
if (!fs.existsSync(dataDir)) fs.mkdirSync(dataDir, { recursive: true });

const db = new Database(DB_PATH);

// Enable WAL mode for better performance
db.pragma('journal_mode = WAL');
db.pragma('foreign_keys = ON');

// ─── Schema ────────────────────────────────────────────────────────────────────

db.exec(`
  CREATE TABLE IF NOT EXISTS admin (
    id INTEGER PRIMARY KEY,
    username TEXT NOT NULL UNIQUE,
    password TEXT NOT NULL
  );

  CREATE TABLE IF NOT EXISTS servers (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    title TEXT NOT NULL,
    url TEXT NOT NULL,
    username TEXT NOT NULL DEFAULT '',
    password TEXT NOT NULL DEFAULT '',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
  );

  CREATE TABLE IF NOT EXISTS mac_users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    title TEXT NOT NULL,
    app_key TEXT NOT NULL UNIQUE,
    username TEXT NOT NULL,
    password TEXT NOT NULL,
    protection TEXT NOT NULL DEFAULT 'NO',
    m3u_address TEXT,
    server_id INTEGER REFERENCES servers(id) ON DELETE SET NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
  );

  CREATE TABLE IF NOT EXISTS activation_codes (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    code TEXT NOT NULL UNIQUE,
    status TEXT NOT NULL DEFAULT 'unused',
    server_id INTEGER REFERENCES servers(id) ON DELETE SET NULL,
    mac_user_id INTEGER REFERENCES mac_users(id) ON DELETE SET NULL,
    used_by TEXT,
    device_limit INTEGER NOT NULL DEFAULT 5,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
  );

  CREATE TABLE IF NOT EXISTS code_devices (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    code_id INTEGER NOT NULL REFERENCES activation_codes(id) ON DELETE CASCADE,
    app_key TEXT NOT NULL,
    activated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(code_id, app_key)
  );

  CREATE TABLE IF NOT EXISTS allowed_app_keys (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    code_id INTEGER NOT NULL REFERENCES activation_codes(id) ON DELETE CASCADE,
    app_key TEXT NOT NULL,
    UNIQUE(code_id, app_key)
  );

  CREATE TABLE IF NOT EXISTS user_app_keys (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    mac_user_id INTEGER NOT NULL REFERENCES mac_users(id) ON DELETE CASCADE,
    app_key TEXT NOT NULL UNIQUE,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
  );

  CREATE TABLE IF NOT EXISTS trials (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    app_key TEXT NOT NULL UNIQUE,
    expire_date TEXT NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
  );

  CREATE TABLE IF NOT EXISTS settings (
    key TEXT PRIMARY KEY,
    value TEXT
  );
`);

// ─── Seed default admin ────────────────────────────────────────────────────────

const adminExists = db.prepare('SELECT id FROM admin WHERE id = 1').get();
if (!adminExists) {
  const hash = bcrypt.hashSync('admin123', 10);
  db.prepare('INSERT INTO admin (username, password) VALUES (?, ?)').run('admin', hash);
}

// ─── Seed default settings ─────────────────────────────────────────────────────

const defaultSettings = {
  mac_length: '12',
  notification_title: '',
  notification_content: '',
  login_title: 'Welcome',
  login_subtitle: 'Sign in to continue',
  demo_playlist_name: '',
  demo_dns: '',
  demo_username: '',
  demo_password: '',
  update_version: '',
  update_url: '',
  license_key: '',
};

const insertSetting = db.prepare(
  'INSERT OR IGNORE INTO settings (key, value) VALUES (?, ?)'
);
for (const [key, value] of Object.entries(defaultSettings)) {
  insertSetting.run(key, value);
}

// ─── Migrations ────────────────────────────────────────────────────────────────
// mac_address → app_key rename (run once, safe to re-run)
try {
  const cols = db.prepare("PRAGMA table_info(mac_users)").all().map(c => c.name);
  if (cols.includes('mac_address') && !cols.includes('app_key')) {
    db.exec(`ALTER TABLE mac_users RENAME COLUMN mac_address TO app_key`);
  }
} catch (_) {}

try {
  const cols = db.prepare("PRAGMA table_info(trials)").all().map(c => c.name);
  if (cols.includes('mac_address') && !cols.includes('app_key')) {
    db.exec(`ALTER TABLE trials RENAME COLUMN mac_address TO app_key`);
  }
} catch (_) {}

try {
  const cols = db.prepare("PRAGMA table_info(code_devices)").all().map(c => c.name);
  if (cols.includes('mac_address') && !cols.includes('app_key')) {
    db.exec(`ALTER TABLE code_devices RENAME COLUMN mac_address TO app_key`);
  }
} catch (_) {}

module.exports = db;
