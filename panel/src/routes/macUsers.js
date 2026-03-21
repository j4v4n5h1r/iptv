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
      WHERE mu.title LIKE ? OR mu.mac_address LIKE ? OR mu.username LIKE ?
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
  res.render('mac-users/index', {
    title: 'MAC Users', path: '/mac-users', users, search,
  });
});

// Create form
router.get('/create', (req, res) => {
  const servers = db.prepare('SELECT * FROM servers ORDER BY title').all();
  res.render('mac-users/form', {
    title: 'Add MAC User', path: '/mac-users', user: null, servers,
  });
});

// Create submit
router.post('/', (req, res) => {
  const { title, mac_address, username, password, protection, m3u_address, server_id } = req.body;
  if (!title || !mac_address || !username || !password) {
    req.flash('error', 'Title, MAC address, username and password are required.');
    return res.redirect('/mac-users/create');
  }
  try {
    db.prepare(`
      INSERT INTO mac_users (title, mac_address, username, password, protection, m3u_address, server_id)
      VALUES (?, ?, ?, ?, ?, ?, ?)
    `).run(
      title.trim(), mac_address.trim().toUpperCase(),
      username.trim(), password.trim(),
      protection === 'YES' ? 'YES' : 'NO',
      m3u_address ? m3u_address.trim() : null,
      server_id || null,
    );
    req.flash('success', 'MAC user created successfully.');
    res.redirect('/mac-users');
  } catch (e) {
    if (e.message.includes('UNIQUE')) {
      req.flash('error', 'MAC address already exists.');
    } else {
      req.flash('error', 'Error creating user.');
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
    title: 'Edit MAC User', path: '/mac-users', user, servers,
  });
});

// Edit submit
router.post('/:id', (req, res) => {
  const { title, mac_address, username, password, protection, m3u_address, server_id } = req.body;
  if (!title || !mac_address || !username || !password) {
    req.flash('error', 'Title, MAC address, username and password are required.');
    return res.redirect(`/mac-users/${req.params.id}/edit`);
  }
  try {
    db.prepare(`
      UPDATE mac_users
      SET title=?, mac_address=?, username=?, password=?, protection=?, m3u_address=?, server_id=?
      WHERE id=?
    `).run(
      title.trim(), mac_address.trim().toUpperCase(),
      username.trim(), password.trim(),
      protection === 'YES' ? 'YES' : 'NO',
      m3u_address ? m3u_address.trim() : null,
      server_id || null,
      req.params.id,
    );
    req.flash('success', 'MAC user updated.');
    res.redirect('/mac-users');
  } catch (e) {
    if (e.message.includes('UNIQUE')) {
      req.flash('error', 'MAC address already exists.');
    } else {
      req.flash('error', 'Error updating user.');
    }
    res.redirect(`/mac-users/${req.params.id}/edit`);
  }
});

// Delete
router.delete('/:id', (req, res) => {
  db.prepare('DELETE FROM mac_users WHERE id = ?').run(req.params.id);
  req.flash('success', 'MAC user deleted.');
  res.redirect('/mac-users');
});

module.exports = router;
