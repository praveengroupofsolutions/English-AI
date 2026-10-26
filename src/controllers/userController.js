
const User = require("../models/User");

exports.getProfile = async (req, res) => {
  return res.json({
    success: true,
    user: {
      id: req.user._id,
      name: req.user.name,
      email: req.user.email,
      photo: req.user.photo,
      isEmailVerified: req.user.isEmailVerified,
      createdAt: req.user.createdAt,
      updatedAt: req.user.updatedAt,
    },
  });
};

exports.updateProfile = async (req, res) => {
  try {
    const { name, photo } = req.body;

    // Do not permit clients to change email, password,
    // Google ID, verification status or token fields here.
    if (name === undefined && photo === undefined) {
      return res.status(400).json({
        success: false,
        message: "Provide name or photo to update",
      });
    }

    if (name !== undefined) {
      if (
        typeof name !== "string" ||
        name.trim().length < 2 ||
        name.trim().length > 60
      ) {
        return res.status(400).json({
          success: false,
          message: "Name must contain 2 to 60 characters",
        });
      }

      req.user.name = name.trim();
    }

    if (photo !== undefined) {
      if (
        typeof photo !== "string" ||
        photo.length > 2048 ||
        (photo !== "" && !/^https?:\/\/\S+$/i.test(photo))
      ) {
        return res.status(400).json({
          success: false,
          message: "Photo must be a valid HTTP(S) URL or empty",
        });
      }

      req.user.photo = photo;
    }

    await req.user.save();

    return res.json({
      success: true,
      message: "Profile updated successfully",
      user: {
        id: req.user._id,
        name: req.user.name,
        email: req.user.email,
        photo: req.user.photo,
        isEmailVerified: req.user.isEmailVerified,
        updatedAt: req.user.updatedAt,
      },
    });
  } catch (error) {
    console.error("Update profile error:", error.message);
    return res.status(500).json({
      success: false,
      message: "Profile update failed",
    });
  }
};

exports.deleteAccount = async (req, res) => {
  try {
    await User.findByIdAndDelete(req.user._id);

    return res.json({
      success: true,
      message: "Account deleted successfully",
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: "Account deletion failed",
    });
  }
};
