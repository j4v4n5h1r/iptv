const express = require('express');
const db = require('../db');
const requireAuth = require('../middleware/requireAuth');
const router = express.Router();

router.use(requireAuth);

// List
router.get('/', (req, res) => {
  const search = req.query.search || '';
  let codes;
  if (search) {
    codes = db.prepare(`
      SELECT ac.*, s.title AS server_title
      FROM activation_codes ac
      LEFT JOIN servers s ON ac.server_id = s.id
      WHERE ac.code LIKE ? OR ac.status LIKE ? OR ac.used_by LIKE ?
      ORDER BY ac.id DESC
    `).all(`%${search}%`, `%${search}%`, `%${search}%`);
  } else {
    codes = db.prepare(`
      SELECT ac.*, s.title AS server_title
      FROM activation_codes ac
      LEFT JOIN servers s ON ac.server_id = s.id
      ORDER BY ac.id DESC
    `).all();
  }
  const servers = db.prepare('SELECT * FROM servers ORDER BY title').all();
  const macUsers = db.prepare('SELECT * FROM mac_users ORDER BY title').all();
  res.render('activation/index', {
    title: 'Activation Codes', path: '/activation-codes', codes, servers, macUsers, search,
  });
});

// Create
router.post('/', (req, res) => {
  const { server_id, mac_user_id, count = 1 } = req.body;
  const num = Math.min(parseInt(count) || 1, 50);

  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  function genCode() {
    let code = '';
    for (let i = 0; i < 16; i++) {
      if (i > 0 && i % 4 === 0) code += '-';
      code += chars[Math.floor(Math.random() * chars.length)];
    }
    return code;
  }

  function uniqueCode() {
    const check = db.prepare('SELECT id FROM activation_codes WHERE code = ?');
    let code, attempts = 0;
    do {
      code = genCode();
      attempts++;
    } while (check.get(code) && attempts < 20);
    return code;
  }

  const insert = db.prepare(
    'INSERT INTO activation_codes (code, status, server_id, mac_user_id) VALUES (?, ?, ?, ?)'
  );
  const insertMany = db.transaction(() => {
    for (let i = 0; i < num; i++) {
      insert.run(uniqueCode(), 'unused', server_id || null, mac_user_id || null);
    }
  });
  insertMany();

  req.flash('success', `${num} activation code(s) generated.`);
  res.redirect('/activation-codes');
});

// Delete
router.delete('/:id', (req, res) => {
  db.prepare('DELETE FROM activation_codes WHERE id = ?').run(req.params.id);
  req.flash('success', 'Activation code deleted.');
  res.redirect('/activation-codes');
});

// Reset (mark as unused)
router.post('/:id/reset', (req, res) => {
  db.prepare("UPDATE activation_codes SET status='unused', used_by=NULL WHERE id=?").run(req.params.id);
  req.flash('success', 'Code reset to unused.');
  res.redirect('/activation-codes');
});

module.exports = router;
