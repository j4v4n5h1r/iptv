module.exports = function requireAuth(req, res, next) {
  if (req.session && req.session.adminId) {
    return next();
  }
  req.flash('error', 'Please login to continue.');
  res.redirect('/login');
};
