const express = require('express');
const db = require('../db');
const requireAuth = require('../middleware/requireAuth');
const router = express.Router();

router.use(requireAuth);

// List
router.get('/', (req, res) => {
  const trials = db.prepare(`
    SELECT t.*, mu.title AS user_title
    FROM trials t
    LEFT JOIN mac_users mu ON mu.app_key = t.app_key
    ORDER BY t.expire_date ASC
  `).all();
  const today = new Date().toISOString().split('T')[0];
  res.render('trials/index', { title: 'Set Expiration', path: '/trials', trials, today });
});

// Create form
router.get('/create', (req, res) => {
  const mac = req.query.mac || '';
  res.render('trials/form', { title: 'Set Expiration', path: '/trials', trial: null, mac });
});

// Create submit
router.post('/', (req, res) => {
  const { app_key, expire_date } = req.body;
  if (!app_key || !expire_date) {
    req.flash('error', 'App Key and expiry date are required.');
    return res.redirect('/trials/create');
  }
  try {
    db.prepare(`
      INSERT INTO trials (app_key, expire_date) VALUES (?, ?)
      ON CONFLICT(app_key) DO UPDATE SET expire_date = excluded.expire_date
    `).run(app_key.trim().toUpperCase(), expire_date);
    req.flash('success', 'Expiry date set.');
    res.redirect('/trials');
  } catch (e) {
    req.flash('error', 'Error saving trial.');
    res.redirect('/trials/create');
  }
});

// Edit form
router.get('/:id/edit', (req, res) => {
  const trial = db.prepare('SELECT * FROM trials WHERE id = ?').get(req.params.id);
  if (!trial) { req.flash('error', 'Trial not found.'); return res.redirect('/trials'); }
  res.render('trials/form', { title: 'Edit Expiration', path: '/trials', trial, mac: trial.app_key });
});

// Edit submit
router.post('/:id', (req, res) => {
  const { app_key, expire_date } = req.body;
  if (!app_key || !expire_date) {
    req.flash('error', 'App Key and expiry date are required.');
    return res.redirect(`/trials/${req.params.id}/edit`);
  }
  db.prepare('UPDATE trials SET app_key=?, expire_date=? WHERE id=?')
    .run(app_key.trim().toUpperCase(), expire_date, req.params.id);
  req.flash('success', 'Expiry date updated.');
  res.redirect('/trials');
});

// Delete
router.delete('/:id', (req, res) => {
  db.prepare('DELETE FROM trials WHERE id = ?').run(req.params.id);
  req.flash('success', 'Trial deleted.');
  res.redirect('/trials');
});

module.exports = router;
