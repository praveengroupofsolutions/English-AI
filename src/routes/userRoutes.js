
const express = require("express");
const protect = require("../middleware/authMiddleware");

const {
  getProfile,
  updateProfile,
  deleteAccount,
} = require("../controllers/userController");

const router = express.Router();

router.get("/me", protect, getProfile);
router.patch("/me", protect, updateProfile);
router.delete("/me", protect, deleteAccount);

module.exports = router;
