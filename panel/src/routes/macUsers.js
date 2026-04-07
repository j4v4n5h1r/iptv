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
  const { title, app_key, username, password, protection, m3u_address, server_url } = req.body;
  if (!title || !app_key || !username || !password) {
    req.flash('error', 'Title, App Key, username and password are required.');
    return res.redirect('/mac-users/create');
  }
  try {
    const sid = resolveServerId(server_url);
    const key = app_key.trim().toUpperCase();
    db.prepare(`
      INSERT INTO mac_users (title, app_key, username, password, protection, m3u_address, server_id)
      VALUES (?, ?, ?, ?, ?, ?, ?)
    `).run(
      title.trim(), key,
      username.trim(), password.trim(),
      protection === 'YES' ? 'YES' : 'NO',
      m3u_address ? m3u_address.trim() : null,
      sid,
    );
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
  res.render('mac-users/form', {
    title: 'Edit App User', path: '/mac-users', user, servers,
  });
});

// Edit submit
router.post('/:id', (req, res) => {
  const { title, app_key, username, password, protection, m3u_address, server_url } = req.body;
  if (!title || !username || !password) {
    req.flash('error', 'Title, username and password are required.');
    return res.redirect(`/mac-users/${req.params.id}/edit`);
  }
  try {
    const sid = resolveServerId(server_url);
    const existing = db.prepare('SELECT app_key FROM mac_users WHERE id = ?').get(req.params.id);
    const key = (app_key && app_key.trim()) ? app_key.trim().toUpperCase() : (existing ? existing.app_key : 'PENDING-' + Date.now());
    db.prepare(`
      UPDATE mac_users
      SET title=?, app_key=?, username=?, password=?, protection=?, m3u_address=?, server_id=?
      WHERE id=?
    `).run(
      title.trim(), key,
      username.trim(), password.trim(),
      protection === 'YES' ? 'YES' : 'NO',
      m3u_address ? m3u_address.trim() : null,
      sid,
      req.params.id,
    );
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
