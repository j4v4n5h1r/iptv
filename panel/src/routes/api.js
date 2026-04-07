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
// Flutter app sends app_key; backend returns stream credentials.
router.post('/auth', (req, res) => {
  const { app_key } = req.body;
  if (!app_key) return apiError(res, 400, 'app_key is required');

  const key = app_key.trim().toUpperCase();

  const user = db.prepare(`
    SELECT mu.*, s.url AS server_url, s.title AS server_title
    FROM mac_users mu
    LEFT JOIN servers s ON mu.server_id = s.id
    WHERE mu.app_key = ?
  `).get(key);

  if (!user) {
    return apiError(res, 404, 'App Key not registered. Please use an activation code.');
  }

  const trial = db.prepare('SELECT * FROM trials WHERE app_key = ?').get(key);
  const today = new Date().toISOString().split('T')[0];
  if (trial && trial.expire_date < today) {
    return apiError(res, 403, 'Your subscription has expired. Please contact support.');
  }

  const notification = {
    title: getSetting('notification_title'),
    content: getSetting('notification_content'),
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
  });
});

// ─── POST /api/activate ────────────────────────────────────────────────────────
// Activate a device using an activation code + app_key.
router.post('/activate', (req, res) => {
  const { app_key, code } = req.body;
  if (!app_key || !code) return apiError(res, 400, 'app_key and code are required');

  const key = app_key.trim().toUpperCase();
  const normalizedCode = code.trim().toUpperCase().replace(/-/g, '');

  const activationCode = db.prepare(
    "SELECT * FROM activation_codes WHERE REPLACE(code, '-', '') = ?"
  ).get(normalizedCode);

  if (!activationCode) {
    return apiError(res, 400, 'Invalid activation code.');
  }

  // Check if this app_key already used this code
  const alreadyRegistered = db.prepare(
    'SELECT id FROM code_devices WHERE code_id = ? AND app_key = ?'
  ).get(activationCode.id, key);

  if (!alreadyRegistered) {
    const deviceCount = db.prepare(
      'SELECT COUNT(*) as cnt FROM code_devices WHERE code_id = ?'
    ).get(activationCode.id).cnt;

    const limit = activationCode.device_limit || 5;
    if (deviceCount >= limit) {
      return apiError(res, 403, `Device limit reached. This code allows max ${limit} devices.`);
    }

    db.prepare('INSERT INTO code_devices (code_id, app_key) VALUES (?, ?)')
      .run(activationCode.id, key);
  }

  // Track last used app_key on code
  db.prepare("UPDATE activation_codes SET status='used', used_by=? WHERE id=?")
    .run(key, activationCode.id);

  // If code is linked to a specific mac_user, bind this app_key to that user
  let linkedUser = null;
  if (activationCode.mac_user_id) {
    linkedUser = db.prepare('SELECT * FROM mac_users WHERE id = ?').get(activationCode.mac_user_id);
    if (linkedUser) {
      db.prepare('UPDATE mac_users SET app_key = ? WHERE id = ?')
        .run(key, linkedUser.id);
    }
  }

  // If no linked user, auto-create a mac_users entry for this app_key
  if (!linkedUser) {
    const existing = db.prepare('SELECT id FROM mac_users WHERE app_key = ?').get(key);
    if (!existing) {
      db.prepare(`
        INSERT INTO mac_users (title, app_key, username, password, protection, m3u_address, server_id)
        VALUES (?, ?, '', '', 'NO', NULL, ?)
      `).run(key, key, activationCode.server_id || null);
    }
  }

  return res.json({ success: true, message: 'Activated successfully.' });
});

// ─── POST /api/device/register ─────────────────────────────────────────────────
router.post('/device/register', (req, res) => {
  const { app_key } = req.body;
  if (!app_key) return apiError(res, 400, 'app_key is required');

  const key = app_key.trim().toUpperCase();
  const user = db.prepare('SELECT id FROM mac_users WHERE app_key = ?').get(key);
  const trial = db.prepare('SELECT * FROM trials WHERE app_key = ?').get(key);
  const today = new Date().toISOString().split('T')[0];

  res.json({
    success: true,
    registered: !!user,
    trial_active: trial ? trial.expire_date >= today : false,
    trial_expire: trial ? trial.expire_date : null,
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
router.get('/demo', (req, res) => {
  const dns = getSetting('demo_dns');
  if (!dns) return apiError(res, 404, 'No demo configured.');
  res.json({
    success: true,
    demo: {
      playlist_name: getSetting('demo_playlist_name'),
      dns,
      username: getSetting('demo_username'),
      password: getSetting('demo_password'),
    },
  });
});

// ─── GET /api/settings ─────────────────────────────────────────────────────────
router.get('/settings', (req, res) => {
  res.json({
    success: true,
    settings: {
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

module.exports = router;
