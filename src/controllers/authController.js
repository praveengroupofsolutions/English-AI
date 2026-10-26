
const crypto = require("crypto");
const jwt = require("jsonwebtoken");
const nodemailer = require("nodemailer");
const { OAuth2Client } = require("google-auth-library");

const User = require("../models/User");
const {
  hashToken,
  generateAccessToken,
  generateRefreshToken,
} = require("../utils/generateToken");

const googleClient = new OAuth2Client(
  process.env.GOOGLE_CLIENT_ID
);

const emailPattern = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

const sendAuthResponse = async (user, res) => {
  const accessToken = generateAccessToken(user._id);
  const refreshToken = generateRefreshToken(user._id);

  user.refreshTokenHash = hashToken(refreshToken);
  await user.save();

  return res.json({
    success: true,
    message: "Authentication successful",
    accessToken,
    refreshToken,
    user: {
      id: user._id,
      name: user.name,
      email: user.email,
      photo: user.photo,
      isEmailVerified: user.isEmailVerified,
    },
  });
};

exports.register = async (req, res) => {
  try {
    const { name, email, password } = req.body;

    if (
      typeof name !== "string" ||
      typeof email !== "string" ||
      typeof password !== "string"
    ) {
      return res.status(400).json({
        success: false,
        message: "Name, email and password are required",
      });
    }

    const cleanName = name.trim();
    const cleanEmail = email.trim().toLowerCase();

    if (cleanName.length < 2 || cleanName.length > 60) {
      return res.status(400).json({
        success: false,
        message: "Name must contain 2 to 60 characters",
      });
    }

    if (!emailPattern.test(cleanEmail)) {
      return res.status(400).json({
        success: false,
        message: "Enter a valid email address",
      });
    }

    if (password.length < 8 || password.length > 128) {
      return res.status(400).json({
        success: false,
        message: "Password must contain 8 to 128 characters",
      });
    }

    const existingUser = await User.findOne({
      email: cleanEmail,
    });

    if (existingUser) {
      return res.status(409).json({
        success: false,
        message: "Email is already registered",
      });
    }

    const user = await User.create({
      name: cleanName,
      email: cleanEmail,
      password,
    });

    return res.status(201).json({
      success: true,
      message: "Registration successful. Please log in.",
      user: {
        id: user._id,
        name: user.name,
        email: user.email,
        photo: user.photo,
        isEmailVerified: user.isEmailVerified,
      },
    });
  } catch (error) {
    if (error.code === 11000) {
      return res.status(409).json({
        success: false,
        message: "Email is already registered",
      });
    }

    console.error("Register error:", error.message);
    return res.status(500).json({
      success: false,
      message: "Registration failed",
    });
  }
};

exports.login = async (req, res) => {
  try {
    const { email, password } = req.body;

    if (
      typeof email !== "string" ||
      typeof password !== "string"
    ) {
      return res.status(400).json({
        success: false,
        message: "Email and password are required",
      });
    }

    const user = await User.findOne({
      email: email.trim().toLowerCase(),
    }).select("+password");

    if (!user || !(await user.comparePassword(password))) {
      return res.status(401).json({
        success: false,
        message: "Invalid email or password",
      });
    }

    return await sendAuthResponse(user, res);
  } catch (error) {
    console.error("Login error:", error.message);
    return res.status(500).json({
      success: false,
      message: "Login failed",
    });
  }
};

exports.refresh = async (req, res) => {
  try {
    const { refreshToken } = req.body;

    if (typeof refreshToken !== "string") {
      return res.status(400).json({
        success: false,
        message: "Refresh token is required",
      });
    }

    const decoded = jwt.verify(
      refreshToken,
      process.env.JWT_REFRESH_SECRET
    );

    if (decoded.type !== "refresh") {
      return res.status(401).json({
        success: false,
        message: "Invalid refresh token",
      });
    }

    const user = await User.findById(decoded.sub)
      .select("+refreshTokenHash");

    if (
      !user ||
      !user.refreshTokenHash ||
      user.refreshTokenHash !== hashToken(refreshToken)
    ) {
      return res.status(401).json({
        success: false,
        message: "Refresh token expired or revoked",
      });
    }

    // Rotate refresh token on every successful refresh.
    return await sendAuthResponse(user, res);
  } catch (error) {
    return res.status(401).json({
      success: false,
      message: "Invalid or expired refresh token",
    });
  }
};

exports.logout = async (req, res) => {
  try {
    const { refreshToken } = req.body;

    if (typeof refreshToken === "string") {
      try {
        const decoded = jwt.verify(
          refreshToken,
          process.env.JWT_REFRESH_SECRET
        );

        if (decoded.type === "refresh") {
          const user = await User.findById(decoded.sub)
            .select("+refreshTokenHash");

          if (
            user &&
            user.refreshTokenHash === hashToken(refreshToken)
          ) {
            user.refreshTokenHash = undefined;
            await user.save();
          }
        }
      } catch {
        // Invalid/expired token: still return logout success.
      }
    }

    return res.json({
      success: true,
      message: "Logged out. Discard your local tokens.",
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: "Logout failed",
    });
  }
};

const sendResetEmail = async (email, otp) => {
  const transporter = nodemailer.createTransport({
    host: process.env.SMTP_HOST,
    port: Number(process.env.SMTP_PORT || 587),
    secure: process.env.SMTP_SECURE === "true",
    auth: {
      user: process.env.SMTP_USER,
      pass: process.env.SMTP_PASS,
    },
  });

  await transporter.sendMail({
    from: process.env.SMTP_FROM || process.env.SMTP_USER,
    to: email,
    subject: "English AI password reset code",
    text: `Your password reset OTP is ${otp}. It expires in 10 minutes. If you did not request this, ignore this email.`,
  });
};

exports.forgotPassword = async (req, res) => {
  try {
    const { email } = req.body;

    if (typeof email !== "string" || !emailPattern.test(email.trim())) {
      return res.status(400).json({
        success: false,
        message: "Enter a valid email address",
      });
    }

    const user = await User.findOne({
      email: email.trim().toLowerCase(),
    });

    const response = {
      success: true,
      message: "If the account exists, a reset code will be sent",
    };

    if (!user) return res.json(response);

    const otp = crypto.randomInt(100000, 1000000).toString();

    user.resetOtpHash = hashToken(otp);
    user.resetOtpExpires = new Date(Date.now() + 10 * 60 * 1000);

    await user.save();

    try {
      await sendResetEmail(user.email, otp);
    } catch (mailError) {
      user.resetOtpHash = undefined;
      user.resetOtpExpires = undefined;
      await user.save();

      console.error("Email delivery failed:", mailError.message);

      return res.status(503).json({
        success: false,
        message: "Email service unavailable. Try again later.",
      });
    }

    return res.json(response);
  } catch (error) {
    console.error("Forgot password error:", error.message);
    return res.status(500).json({
      success: false,
      message: "Could not process password reset",
    });
  }
};

exports.verifyOtp = async (req, res) => {
  try {
    const { email, otp } = req.body;

    if (
      typeof email !== "string" ||
      typeof otp !== "string" ||
      !/^\d{6}$/.test(otp)
    ) {
      return res.status(400).json({
        success: false,
        message: "Valid email and six-digit OTP are required",
      });
    }

    const user = await User.findOne({
      email: email.trim().toLowerCase(),
    }).select("+resetOtpHash +resetOtpExpires");

    if (
      !user ||
      !user.resetOtpHash ||
      !user.resetOtpExpires ||
      user.resetOtpExpires < new Date() ||
      user.resetOtpHash !== hashToken(otp)
    ) {
      return res.status(400).json({
        success: false,
        message: "Invalid or expired OTP",
      });
    }

    const resetToken = crypto.randomBytes(32).toString("hex");

    user.resetOtpHash = undefined;
    user.resetOtpExpires = undefined;
    user.passwordResetTokenHash = hashToken(resetToken);
    user.passwordResetTokenExpires =
      new Date(Date.now() + 10 * 60 * 1000);

    await user.save();

    return res.json({
      success: true,
      message: "OTP verified",
      resetToken,
    });
  } catch (error) {
    console.error("OTP verification error:", error.message);
    return res.status(500).json({
      success: false,
      message: "OTP verification failed",
    });
  }
};

exports.resetPassword = async (req, res) => {
  try {
    const { resetToken, newPassword } = req.body;

    if (
      typeof resetToken !== "string" ||
      typeof newPassword !== "string" ||
      newPassword.length < 8 ||
      newPassword.length > 128
    ) {
      return res.status(400).json({
        success: false,
        message: "A valid reset token and password (8-128 characters) are required",
      });
    }

    const user = await User.findOne({
      passwordResetTokenHash: hashToken(resetToken),
      passwordResetTokenExpires: { $gt: new Date() },
    }).select("+passwordResetTokenHash +passwordResetTokenExpires");

    if (!user) {
      return res.status(400).json({
        success: false,
        message: "Invalid or expired reset token",
      });
    }

    user.password = newPassword;
    user.passwordResetTokenHash = undefined;
    user.passwordResetTokenExpires = undefined;
    user.refreshTokenHash = undefined;

    await user.save();

    return res.json({
      success: true,
      message: "Password reset successful. Please log in again.",
    });
  } catch (error) {
    console.error("Reset password error:", error.message);
    return res.status(500).json({
      success: false,
      message: "Password reset failed",
    });
  }
};

exports.googleLogin = async (req, res) => {
  try {
    const { idToken } = req.body;

    if (!process.env.GOOGLE_CLIENT_ID) {
      return res.status(503).json({
        success: false,
        message: "Google sign-in is not configured",
      });
    }

    if (typeof idToken !== "string") {
      return res.status(400).json({
        success: false,
        message: "Google ID token is required",
      });
    }

    const ticket = await googleClient.verifyIdToken({
      idToken,
      audience: process.env.GOOGLE_CLIENT_ID,
    });

    const payload = ticket.getPayload();

    if (!payload || !payload.sub || !payload.email) {
      return res.status(401).json({
        success: false,
        message: "Invalid Google account",
      });
    }

    if (payload.email_verified !== true) {
      return res.status(401).json({
        success: false,
        message: "Google email is not verified",
      });
    }

    let user = await User.findOne({ googleId: payload.sub });

    if (!user) {
      user = await User.findOne({
        email: payload.email.toLowerCase(),
      });

      if (user) {
        // Never silently link an existing password account.
        return res.status(409).json({
          success: false,
          message: "An account with this email already exists. Sign in with its existing method.",
        });
      }

      user = await User.create({
        name: payload.name || payload.email.split("@")[0],
        email: payload.email.toLowerCase(),
        googleId: payload.sub,
        photo: payload.picture || "",
        isEmailVerified: true,
      });
    }

    return await sendAuthResponse(user, res);
  } catch (error) {
    console.error("Google login error:", error.message);
    return res.status(401).json({
      success: false,
      message: "Google sign-in failed",
    });
  }
};
