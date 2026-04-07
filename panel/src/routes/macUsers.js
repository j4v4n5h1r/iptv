const express = require('express');
const db = require('../db');
const requireAuth = require('../middleware/requireAuth');
const router = express.Router();

router.use(requireAuth);

// List
router.get('/', (req, res) => {
  const search = req.query.search || '';
  let users;
  if (search) {
    users = db.prepare(`
      SELECT mu.*, s.title AS server_title, s.url AS server_url
      FROM mac_users mu
      LEFT JOIN servers s ON mu.server_id = s.id
      WHERE mu.title LIKE ? OR mu.app_key LIKE ? OR mu.username LIKE ?
      ORDER BY mu.id DESC
    `).all(`%${search}%`, `%${search}%`, `%${search}%`);
  } else {
    users = db.prepare(`
      SELECT mu.*, s.title AS server_title, s.url AS server_url
      FROM mac_users mu
      LEFT JOIN servers s ON mu.server_id = s.id
      ORDER BY mu.id DESC
    `).all();
  }
  // Attach all app keys to each user
  const getKeys = db.prepare('SELECT app_key FROM user_app_keys WHERE mac_user_id = ? ORDER BY id');
  users = users.map(u => ({
    ...u,
    all_app_keys: getKeys.all(u.id).map(r => r.app_key),
  }));

  const codes = db.prepare(`
    SELECT ac.*, s.title AS server_title
    FROM activation_codes ac
    LEFT JOIN servers s ON ac.server_id = s.id
    ORDER BY ac.id DESC
  `).all();
  const servers = db.prepare('SELECT * FROM servers ORDER BY title').all();
  const macUsers2 = db.prepare('SELECT * FROM mac_users ORDER BY title').all();
  res.render('mac-users/index', {
    title: 'App Users', path: '/mac-users', users, search, codes, servers, macUsers: macUsers2,
  });
});

// Create form
router.get('/create', (req, res) => {
  const servers = db.prepare('SELECT * FROM servers ORDER BY title').all();
  res.render('mac-users/form', {
    title: 'Add App User', path: '/mac-users', user: null, servers,
  });
});

function resolveServerId(serverUrl) {
  if (!serverUrl) return null;
  let url = serverUrl.trim();
  if (url && !url.startsWith('http://') && !url.startsWith('https://')) {
    url = 'http://' + url;
  }
  const existing = db.prepare('SELECT id FROM servers WHERE url = ?').get(url);
  if (existing) return existing.id;
  const info = db.prepare('INSERT INTO servers (title, url, username, password) VALUES (?, ?, ?, ?)').run(
    url.replace(/^https?:\/\//, '').split('/')[0], url, '', ''
  );
  return info.lastInsertRowid;
}

// Create submit
router.post('/', (req, res) => {
  const { title, username, password, protection, m3u_address, server_url } = req.body;
  let appKeys = req.body['app_keys[]'] || [];
  if (!Array.isArray(appKeys)) appKeys = [appKeys];
  appKeys = appKeys.map(k => k.trim().toUpperCase()).filter(k => k.length > 0);

  if (!title || !username || !password) {
    req.flash('error', 'Title, username and password are required.');
    return res.redirect('/mac-users/create');
  }
  if (appKeys.length === 0) {
    req.flash('error', 'En az bir App Key gerekli.');
    return res.redirect('/mac-users/create');
  }
  try {
    const sid = resolveServerId(server_url);
    const primaryKey = appKeys[0];
    const userId = db.prepare(`
      INSERT INTO mac_users (title, app_key, username, password, protection, m3u_address, server_id)
      VALUES (?, ?, ?, ?, ?, ?, ?)
    `).run(
      title.trim(), primaryKey,
      username.trim(), password.trim(),
      protection === 'YES' ? 'YES' : 'NO',
      m3u_address ? m3u_address.trim() : null,
      sid,
    ).lastInsertRowid;

    // Save all app keys to user_app_keys
    const insertKey = db.prepare('INSERT OR IGNORE INTO user_app_keys (mac_user_id, app_key) VALUES (?, ?)');
    for (const k of appKeys) {
      insertKey.run(userId, k);
    }

    req.flash('success', 'App user created successfully.');
    res.redirect('/mac-users');
  } catch (e) {
    if (e.message.includes('UNIQUE')) {
      req.flash('error', 'App Key already exists.');
    } else {
      req.flash('error', 'Error creating user: ' + e.message);
    }
    res.redirect('/mac-users/create');
  }
});

// Edit form
router.get('/:id/edit', (req, res) => {
  const user = db.prepare('SELECT * FROM mac_users WHERE id = ?').get(req.params.id);
  if (!user) { req.flash('error', 'User not found.'); return res.redirect('/mac-users'); }
  const servers = db.prepare('SELECT * FROM servers ORDER BY title').all();
  const userAppKeys = db.prepare('SELECT app_key FROM user_app_keys WHERE mac_user_id = ? ORDER BY id').all(req.params.id).map(r => r.app_key);
  // Include primary key if not already in user_app_keys
  const allKeys = userAppKeys.length > 0 ? userAppKeys : [user.app_key];
  res.render('mac-users/form', {
    title: 'Edit App User', path: '/mac-users', user, servers, userAppKeys: allKeys,
  });
});

// Edit submit
router.post('/:id', (req, res) => {
  const { title, username, password, protection, m3u_address, server_url } = req.body;
  let appKeys = req.body['app_keys[]'] || [];
  if (!Array.isArray(appKeys)) appKeys = [appKeys];
  appKeys = appKeys.map(k => k.trim().toUpperCase()).filter(k => k.length > 0);

  if (!title || !username || !password) {
    req.flash('error', 'Title, username and password are required.');
    return res.redirect(`/mac-users/${req.params.id}/edit`);
  }
  try {
    const sid = resolveServerId(server_url);
    const primaryKey = appKeys.length > 0 ? appKeys[0] : db.prepare('SELECT app_key FROM mac_users WHERE id = ?').get(req.params.id)?.app_key;
    db.prepare(`
      UPDATE mac_users
      SET title=?, app_key=?, username=?, password=?, protection=?, m3u_address=?, server_id=?
      WHERE id=?
    `).run(
      title.trim(), primaryKey,
      username.trim(), password.trim(),
      protection === 'YES' ? 'YES' : 'NO',
      m3u_address ? m3u_address.trim() : null,
      sid,
      req.params.id,
    );

    // Replace user_app_keys for this user
    db.prepare('DELETE FROM user_app_keys WHERE mac_user_id = ?').run(req.params.id);
    const insertKey = db.prepare('INSERT OR IGNORE INTO user_app_keys (mac_user_id, app_key) VALUES (?, ?)');
    for (const k of appKeys) {
      insertKey.run(req.params.id, k);
    }

    req.flash('success', 'App user updated.');
    res.redirect('/mac-users');
  } catch (e) {
    if (e.message.includes('UNIQUE')) {
      req.flash('error', 'App Key already exists.');
    } else {
      req.flash('error', 'Error updating user: ' + e.message);
    }
    res.redirect(`/mac-users/${req.params.id}/edit`);
  }
});

// Delete
router.delete('/:id', (req, res) => {
  db.prepare('DELETE FROM mac_users WHERE id = ?').run(req.params.id);
  req.flash('success', 'App user deleted.');
  res.redirect('/mac-users');
});

module.exports = router;
