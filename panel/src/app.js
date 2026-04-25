const express = require('express');
const expressLayouts = require('express-ejs-layouts');
const session = require('express-session');
const flash = require('connect-flash');
const methodOverride = require('method-override');
const path = require('path');

const app = express();

// ─── View Engine ───────────────────────────────────────────────────────────────
app.set('view engine', 'ejs');
app.set('views', path.join(__dirname, 'views'));
app.use(expressLayouts);
app.set('layout', 'layout');
app.set('layout extractScripts', true);

// ─── Middleware ────────────────────────────────────────────────────────────────
app.use(express.urlencoded({ extended: true }));
app.use(express.json());
app.use(methodOverride('_method'));
app.use(express.static(path.join(__dirname, '..', 'public')));

app.use(session({
  secret: process.env.SESSION_SECRET || 'iptv-secret-key-change-in-production',
  resave: false,
  saveUninitialized: false,
  cookie: { maxAge: 1000 * 60 * 60 * 8 }, // 8 hours
}));

app.use(flash());

// Make flash messages and session available in all views
app.use((req, res, next) => {
  res.locals.success = req.flash('success');
  res.locals.error = req.flash('error');
  res.locals.admin = req.session.adminUsername || null;
  next();
});

// ─── Routes ────────────────────────────────────────────────────────────────────
app.use('/', require('./routes/auth'));
app.use('/dashboard', require('./routes/dashboard'));
app.use('/dns', require('./routes/dns'));
app.use('/mac-users', require('./routes/macUsers'));
app.use('/activation-codes', require('./routes/activation'));
app.use('/trials', require('./routes/trials'));
app.use('/settings', require('./routes/settings'));
app.use('/api', require('./routes/api'));
app.use('/stream', require('./routes/stream'));

// Root redirect
app.get('/', (req, res) => {
  if (req.session.adminId) return res.redirect('/dashboard');
  res.redirect('/login');
});

// ─── Start ─────────────────────────────────────────────────────────────────────
const PORT = process.env.PORT || 3003;
app.listen(PORT, () => {
  console.log(`\x1b[32m[IPTV Panel] Server running on http://localhost:${PORT}\x1b[0m`);
  console.log(`\x1b[33m[IPTV Panel] Default admin: admin / admin123\x1b[0m`);
});
