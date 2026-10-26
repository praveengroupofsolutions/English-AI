
const express = require("express");
const rateLimit = require("express-rate-limit");

const {
  register,
  login,
  refresh,
  logout,
  forgotPassword,
  verifyOtp,
  resetPassword,
  googleLogin,
} = require("../controllers/authController");

const router = express.Router();

const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  limit: 20,
  standardHeaders: true,
  legacyHeaders: false,
});

router.post("/register", authLimiter, register);
router.post("/login", authLimiter, login);
router.post("/refresh", authLimiter, refresh);
router.post("/logout", logout);
router.post("/forgot-password", authLimiter, forgotPassword);
router.post("/verify-otp", authLimiter, verifyOtp);
router.post("/reset-password", authLimiter, resetPassword);
router.post("/google", authLimiter, googleLogin);

module.exports = router;
