const express = require('express');
const bcrypt = require('bcryptjs');
const db = require('../db');
const requireAuth = require('../middleware/requireAuth');
const router = express.Router();

router.use(requireAuth);

function getSetting(key) {
  const row = db.prepare('SELECT value FROM settings WHERE key = ?').get(key);
  return row ? row.value : '';
}

function setSetting(key, value) {
  db.prepare('INSERT OR REPLACE INTO settings (key, value) VALUES (?, ?)').run(key, value);
}

// ─── Set Demo ──────────────────────────────────────────────────────────────────
router.get('/demo', (req, res) => {
  res.render('settings/demo', {
    title: 'Set Demo', path: '/settings/demo',
    demo: {
      playlist_name: getSetting('demo_playlist_name'),
      dns: getSetting('demo_dns'),
      username: getSetting('demo_username'),
      password: getSetting('demo_password'),
    },
  });
});

router.post('/demo', (req, res) => {
  const { playlist_name, dns, username, password } = req.body;
  setSetting('demo_playlist_name', playlist_name || '');
  setSetting('demo_dns', dns || '');
  setSetting('demo_username', username || '');
  setSetting('demo_password', password || '');
  req.flash('success', 'Demo settings saved.');
  res.redirect('/settings/demo');
});

// ─── Notification ──────────────────────────────────────────────────────────────
router.get('/notification', (req, res) => {
  res.render('settings/notification', {
    title: 'Notification', path: '/settings/notification',
    notif: {
      title: getSetting('notification_title'),
      content: getSetting('notification_content'),
    },
  });
});

router.post('/notification', (req, res) => {
  setSetting('notification_title', req.body.notif_title || '');
  setSetting('notification_content', req.body.notif_content || '');
  req.flash('success', 'Notification updated.');
  res.redirect('/settings/notification');
});

// ─── MAC Length ────────────────────────────────────────────────────────────────
router.get('/mac-length', (req, res) => {
  res.render('settings/mac-length', {
    title: 'MAC Length', path: '/settings/mac-length',
    current: getSetting('mac_length') || '12',
  });
});

router.post('/mac-length', (req, res) => {
  const allowed = ['4', '6', '8', '10', '12'];
  const val = allowed.includes(req.body.mac_length) ? req.body.mac_length : '12';
  setSetting('mac_length', val);
  req.flash('success', 'MAC address length updated.');
  res.redirect('/settings/mac-length');
});

// ─── Login Page Text ───────────────────────────────────────────────────────────
router.get('/login-text', (req, res) => {
  res.render('settings/login-text', {
    title: 'Login Page Text', path: '/settings/login-text',
    loginText: {
      title: getSetting('login_title'),
      subtitle: getSetting('login_subtitle'),
    },
  });
});

router.post('/login-text', (req, res) => {
  setSetting('login_title', req.body.login_title || '');
  setSetting('login_subtitle', req.body.login_subtitle || '');
  req.flash('success', 'Login text updated.');
  res.redirect('/settings/login-text');
});

// ─── Remote Update ─────────────────────────────────────────────────────────────
router.get('/update', (req, res) => {
  res.render('settings/update', {
    title: 'Remote Update', path: '/settings/update',
    update: {
      version: getSetting('update_version'),
      url: getSetting('update_url'),
    },
  });
});

router.post('/update', (req, res) => {
  setSetting('update_version', req.body.version || '');
  setSetting('update_url', req.body.url || '');
  req.flash('success', 'Update info saved.');
  res.redirect('/settings/update');
});

// ─── License Key ───────────────────────────────────────────────────────────────
router.get('/license', (req, res) => {
  const key = getSetting('license_key');
  res.render('settings/license', {
    title: 'License Key', path: '/settings/license',
    hasKey: !!key,
  });
});

router.post('/license', (req, res) => {
  setSetting('license_key', req.body.license_key || '');
  req.flash('success', 'License key saved.');
  res.redirect('/settings/license');
});

// ─── Update Credentials ────────────────────────────────────────────────────────
router.get('/credentials', (req, res) => {
  const admin = db.prepare('SELECT username FROM admin WHERE id = 1').get();
  res.render('settings/credentials', {
    title: 'Credentials', path: '/settings/credentials',
    username: admin ? admin.username : 'admin',
  });
});

router.post('/credentials', (req, res) => {
  const { current_password, new_password, confirm_password } = req.body;
  const admin = db.prepare('SELECT * FROM admin WHERE id = 1').get();

  if (!bcrypt.compareSync(current_password, admin.password)) {
    req.flash('error', 'Current password is incorrect.');
    return res.redirect('/settings/credentials');
  }
  if (new_password !== confirm_password) {
    req.flash('error', 'New passwords do not match.');
    return res.redirect('/settings/credentials');
  }
  if (new_password.length < 6) {
    req.flash('error', 'Password must be at least 6 characters.');
    return res.redirect('/settings/credentials');
  }

  const hash = bcrypt.hashSync(new_password, 10);
  db.prepare('UPDATE admin SET password = ? WHERE id = 1').run(hash);
  req.flash('success', 'Password updated successfully.');
  res.redirect('/settings/credentials');
});

module.exports = router;
