const express = require('express');
const db = require('../db');
const requireAuth = require('../middleware/requireAuth');
const router = express.Router();

router.use(requireAuth);

// List
router.get('/', (req, res) => {
  const servers = db.prepare('SELECT * FROM servers ORDER BY id DESC').all();
  res.render('dns/index', { title: 'DNS Settings', path: '/dns', servers });
});

// Create form
router.get('/create', (req, res) => {
  res.render('dns/form', { title: 'Add DNS', path: '/dns', server: null });
});

// Create submit
router.post('/', (req, res) => {
  const { title, url } = req.body;
  if (!title || !url) {
    req.flash('error', 'Title and DNS URL are required.');
    return res.redirect('/dns/create');
  }
  db.prepare('INSERT INTO servers (title, url) VALUES (?, ?)').run(title.trim(), url.trim());
  req.flash('success', 'Server added successfully.');
  res.redirect('/dns');
});

// Edit form
router.get('/:id/edit', (req, res) => {
  const server = db.prepare('SELECT * FROM servers WHERE id = ?').get(req.params.id);
  if (!server) { req.flash('error', 'Server not found.'); return res.redirect('/dns'); }
  res.render('dns/form', { title: 'Edit DNS', path: '/dns', server });
});

// Edit submit
router.post('/:id', (req, res) => {
  const { title, url } = req.body;
  if (!title || !url) {
    req.flash('error', 'Title and DNS URL are required.');
    return res.redirect(`/dns/${req.params.id}/edit`);
  }
  db.prepare('UPDATE servers SET title = ?, url = ? WHERE id = ?')
    .run(title.trim(), url.trim(), req.params.id);
  req.flash('success', 'Server updated.');
  res.redirect('/dns');
});

// Delete
router.delete('/:id', (req, res) => {
  db.prepare('DELETE FROM servers WHERE id = ?').run(req.params.id);
  req.flash('success', 'Server deleted.');
  res.redirect('/dns');
});

module.exports = router;
