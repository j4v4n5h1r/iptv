const express = require('express');
const db = require('../db');
const requireAuth = require('../middleware/requireAuth');
const router = express.Router();

router.use(requireAuth);

// List
router.get('/', (req, res) => {
  const trials = db.prepare('SELECT * FROM trials ORDER BY expire_date ASC').all();
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
  const { mac_address, expire_date } = req.body;
  if (!mac_address || !expire_date) {
    req.flash('error', 'MAC address and expiry date are required.');
    return res.redirect('/trials/create');
  }
  try {
    db.prepare(`
      INSERT INTO trials (mac_address, expire_date) VALUES (?, ?)
      ON CONFLICT(mac_address) DO UPDATE SET expire_date = excluded.expire_date
    `).run(mac_address.trim().toUpperCase(), expire_date);
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
  res.render('trials/form', { title: 'Edit Expiration', path: '/trials', trial, mac: trial.mac_address });
});

// Edit submit
router.post('/:id', (req, res) => {
  const { mac_address, expire_date } = req.body;
  if (!mac_address || !expire_date) {
    req.flash('error', 'MAC address and expiry date are required.');
    return res.redirect(`/trials/${req.params.id}/edit`);
  }
  db.prepare('UPDATE trials SET mac_address=?, expire_date=? WHERE id=?')
    .run(mac_address.trim().toUpperCase(), expire_date, req.params.id);
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
