const express = require('express');
const db = require('../db');
const requireAuth = require('../middleware/requireAuth');
const router = express.Router();

router.use(requireAuth);

router.get('/', (req, res) => {
  const today = new Date().toISOString().split('T')[0];

  const totalServers  = db.prepare('SELECT COUNT(*) AS c FROM servers').get().c;
  const totalUsers    = db.prepare('SELECT COUNT(*) AS c FROM mac_users').get().c;
  const protectedUsers = db.prepare("SELECT COUNT(*) AS c FROM mac_users WHERE protection='YES'").get().c;
  const totalCodes    = db.prepare('SELECT COUNT(*) AS c FROM activation_codes').get().c;
  const unusedCodes   = db.prepare("SELECT COUNT(*) AS c FROM activation_codes WHERE status='unused'").get().c;
  const totalTrials   = db.prepare('SELECT COUNT(*) AS c FROM trials').get().c;
  const activeTrials  = db.prepare('SELECT COUNT(*) AS c FROM trials WHERE expire_date >= ?').get(today).c;

  // Latest 5 users
  const recentUsers = db.prepare(`
    SELECT mu.title, mu.app_key, mu.protection, s.title AS server_title
    FROM mac_users mu
    LEFT JOIN servers s ON mu.server_id = s.id
    ORDER BY mu.id DESC LIMIT 5
  `).all();

  // Latest 5 expiring/expired trials
  const recentTrials = db.prepare(`
    SELECT app_key, expire_date FROM trials
    ORDER BY expire_date ASC LIMIT 5
  `).all();

  res.render('dashboard', {
    title: 'Dashboard', path: '/dashboard',
    stats: {
      totalServers, totalUsers, protectedUsers,
      totalCodes, unusedCodes, usedCodes: totalCodes - unusedCodes,
      totalTrials, activeTrials, expiredTrials: totalTrials - activeTrials,
    },
    recentUsers,
    recentTrials,
    today,
  });
});

module.exports = router;
