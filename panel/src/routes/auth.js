const express = require('express');
const bcrypt = require('bcryptjs');
const db = require('../db');
const router = express.Router();

router.get('/login', (req, res) => {
  if (req.session.adminId) return res.redirect('/dashboard');
  res.render('login', { title: 'Login' });
});

router.post('/login', (req, res) => {
  const { username, password } = req.body;
  const admin = db.prepare('SELECT * FROM admin WHERE username = ?').get(username);

  if (!admin || !bcrypt.compareSync(password, admin.password)) {
    req.flash('error', 'Invalid username or password.');
    return res.redirect('/login');
  }

  req.session.adminId = admin.id;
  req.session.adminUsername = admin.username;
  res.redirect('/dashboard');
});

router.get('/logout', (req, res) => {
  req.session.destroy();
  res.redirect('/login');
});

module.exports = router;
