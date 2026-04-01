/**
 * REST API — consumed by the Flutter IPTV media player
 * Base path: /api
 */
const express = require('express');
const db = require('../db');
const router = express.Router();

function getSetting(key) {
  const row = db.prepare('SELECT value FROM settings WHERE key = ?').get(key);
  return row ? row.value : '';
}

function apiError(res, status, message) {
  return res.status(status).json({ success: false, error: message });
}

// ─── POST /api/auth ────────────────────────────────────────────────────────────
// Flutter app sends the device MAC address; backend returns stream credentials.
router.post('/auth', (req, res) => {
  const { mac_address } = req.body;
  if (!mac_address) return apiError(res, 400, 'mac_address is required');

  const mac = mac_address.trim().toUpperCase();

  // Check if MAC is registered
  const user = db.prepare(`
    SELECT mu.*, s.url AS server_url, s.title AS server_title
    FROM mac_users mu
    LEFT JOIN servers s ON mu.server_id = s.id
    WHERE mu.mac_address = ?
  `).get(mac);

  if (!user) {
    return apiError(res, 404, 'MAC address not registered. Please use an activation code.');
  }

  // Check trial expiry
  const trial = db.prepare('SELECT * FROM trials WHERE mac_address = ?').get(mac);
  const today = new Date().toISOString().split('T')[0];
  if (trial && trial.expire_date < today) {
    return apiError(res, 403, 'Your subscription has expired. Please contact support.');
  }

  // Get app config
  const notification = {
    title: getSetting('notification_title'),
    content: getSetting('notification_content'),
  };
  const loginText = {
    title: getSetting('login_title'),
    subtitle: getSetting('login_subtitle'),
  };

  return res.json({
    success: true,
    user: {
      id: user.id,
      title: user.title,
      username: user.username,
      password: user.password,
      server_url: user.server_url || '',
      server_title: user.server_title || '',
      m3u_url: user.m3u_address || '',
      protection: user.protection,
    },
    trial: trial ? { expire_date: trial.expire_date } : null,
    notification,
    login_text: loginText,
  });
});

// ─── POST /api/activate ────────────────────────────────────────────────────────
// Activate a device using an activation code + MAC address.
router.post('/activate', (req, res) => {
  const { mac_address, code } = req.body;
  if (!mac_address || !code) return apiError(res, 400, 'mac_address and code are required');

  const mac = mac_address.trim().toUpperCase();
  const normalizedCode = code.trim().toUpperCase().replace(/-/g, '');
  const activationCode = db.prepare(
    "SELECT * FROM activation_codes WHERE REPLACE(code, '-', '') = ?"
  ).get(normalizedCode);

  if (!activationCode) {
    return apiError(res, 400, 'Invalid activation code.');
  }

  // Check device limit — same MAC can re-activate unlimited times
  const alreadyRegistered = db.prepare(
    'SELECT id FROM code_devices WHERE code_id = ? AND mac_address = ?'
  ).get(activationCode.id, mac);

  if (!alreadyRegistered) {
    const deviceCount = db.prepare(
      'SELECT COUNT(*) as cnt FROM code_devices WHERE code_id = ?'
    ).get(activationCode.id).cnt;

    const limit = activationCode.device_limit || 5;
    if (deviceCount >= limit) {
      return apiError(res, 403, `Device limit reached. This code allows max ${limit} devices.`);
    }

    // Register this new device
    db.prepare('INSERT INTO code_devices (code_id, mac_address) VALUES (?, ?)')
      .run(activationCode.id, mac);
  }

  // Mark code as used and track last device
  db.prepare("UPDATE activation_codes SET status='used', used_by=? WHERE id=?")
    .run(mac, activationCode.id);

  // If activation code is linked to a specific mac_user, bind this MAC to that user
  let linkedUser = null;
  if (activationCode.mac_user_id) {
    linkedUser = db.prepare('SELECT * FROM mac_users WHERE id = ?').get(activationCode.mac_user_id);
    if (linkedUser) {
      db.prepare('UPDATE mac_users SET mac_address = ? WHERE id = ?')
        .run(mac, linkedUser.id);
    }
  }

  // If no linked user, create or update mac_users entry
  if (!linkedUser) {
    const existing = db.prepare('SELECT id FROM mac_users WHERE mac_address = ?').get(mac);
    if (!existing) {
      db.prepare(`
        INSERT INTO mac_users (title, mac_address, username, password, protection, m3u_address, server_id)
        VALUES (?, ?, ?, ?, 'NO', ?, ?)
      `).run(mac, mac, '', '', null, activationCode.server_id || null);
    }
  }

  return res.json({
    success: true,
    message: 'Activated successfully.',
  });
});

// ─── GET /api/notification ─────────────────────────────────────────────────────
router.get('/notification', (req, res) => {
  res.json({
    success: true,
    notification: {
      title: getSetting('notification_title'),
      content: getSetting('notification_content'),
    },
  });
});

// ─── GET /api/update ───────────────────────────────────────────────────────────
router.get('/update', (req, res) => {
  res.json({
    success: true,
    update: {
      version: getSetting('update_version'),
      url: getSetting('update_url'),
      has_update: !!(getSetting('update_version') && getSetting('update_url')),
    },
  });
});

// ─── GET /api/demo ─────────────────────────────────────────────────────────────
// Returns demo playlist credentials for unregistered users.
router.get('/demo', (req, res) => {
  const playlist_name = getSetting('demo_playlist_name');
  const dns = getSetting('demo_dns');
  const username = getSetting('demo_username');
  const password = getSetting('demo_password');

  if (!dns) return apiError(res, 404, 'No demo configured.');

  res.json({
    success: true,
    demo: { playlist_name, dns, username, password },
  });
});

// ─── GET /api/settings ─────────────────────────────────────────────────────────
// Returns all public app settings in one call.
router.get('/settings', (req, res) => {
  res.json({
    success: true,
    settings: {
      mac_length: getSetting('mac_length') || '12',
      login_title: getSetting('login_title'),
      login_subtitle: getSetting('login_subtitle'),
      notification: {
        title: getSetting('notification_title'),
        content: getSetting('notification_content'),
      },
      update: {
        version: getSetting('update_version'),
        url: getSetting('update_url'),
      },
    },
  });
});

// ─── POST /api/device/register ─────────────────────────────────────────────────
// Register or update a device MAC address (used on first launch).
router.post('/device/register', (req, res) => {
  const { mac_address } = req.body;
  if (!mac_address) return apiError(res, 400, 'mac_address is required');

  const mac = mac_address.trim().toUpperCase();
  const user = db.prepare('SELECT id FROM mac_users WHERE mac_address = ?').get(mac);
  const trial = db.prepare('SELECT * FROM trials WHERE mac_address = ?').get(mac);
  const today = new Date().toISOString().split('T')[0];

  res.json({
    success: true,
    registered: !!user,
    trial_active: trial ? trial.expire_date >= today : false,
    trial_expire: trial ? trial.expire_date : null,
  });
});

module.exports = router;
