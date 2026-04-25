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

  // Attach allowed_keys list to each code
  const getAllowed = db.prepare('SELECT app_key FROM allowed_app_keys WHERE code_id = ? ORDER BY id');
  codes = codes.map(c => ({
    ...c,
    allowed_keys: getAllowed.all(c.id).map(r => r.app_key),
  }));

  const servers = db.prepare('SELECT * FROM servers ORDER BY title').all();
  const macUsersRaw = db.prepare('SELECT * FROM mac_users ORDER BY title').all();
  const getKeys = db.prepare('SELECT app_key FROM user_app_keys WHERE mac_user_id = ? ORDER BY id');
  const macUsers = macUsersRaw.map(u => {
    const keys = getKeys.all(u.id).map(r => r.app_key);
    if (keys.length === 0 && u.app_key) keys.push(u.app_key);
    return { ...u, all_app_keys: keys };
  });
  res.render('activation/index', {
    title: 'Activation Codes', path: '/activation-codes', codes, servers, macUsers, search,
  });
});

// Create
router.post('/', (req, res) => {
  const { server_id, mac_user_id } = req.body;

  if (!mac_user_id) {
    req.flash('error', 'Kullanıcı seçmeden aktivasyon kodu oluşturulamaz.');
    return res.redirect('/activation-codes');
  }

  const chars = '0123456789';
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
    do { code = genCode(); attempts++; } while (check.get(code) && attempts < 20);
    return code;
  }

  const insertCode = db.prepare(
    'INSERT INTO activation_codes (code, status, server_id, mac_user_id) VALUES (?, ?, ?, ?)'
  );
  const insertAllowed = db.prepare(
    'INSERT OR IGNORE INTO allowed_app_keys (code_id, app_key) VALUES (?, ?)'
  );

  db.transaction(() => {
    const info = insertCode.run(uniqueCode(), 'unused', server_id || null, mac_user_id || null);
    const codeId = info.lastInsertRowid;

    // If a user is selected, auto-add their app keys as allowed keys
    if (mac_user_id) {
      const userKeys = db.prepare('SELECT app_key FROM user_app_keys WHERE mac_user_id = ?').all(mac_user_id);
      // Also include primary app_key from mac_users
      const primaryKey = db.prepare('SELECT app_key FROM mac_users WHERE id = ?').get(mac_user_id);
      const allUserKeys = new Set(userKeys.map(r => r.app_key));
      if (primaryKey) allUserKeys.add(primaryKey.app_key);
      for (const k of allUserKeys) {
        insertAllowed.run(codeId, k);
      }
    } else {
      // Manual keys if no user selected
      for (const key of allowedKeys) {
        insertAllowed.run(codeId, key);
      }
    }
  })();

  req.flash('success', 'Activation code generated.');
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
