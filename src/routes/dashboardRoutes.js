
const express = require("express");
const protect = require("../middleware/authMiddleware");

const {
  getHome,
  getDailyPlan,
  updateDailyPlanTask,
  getStreak,
  getStatistics,
  getRecommendedLessons,
  getNotifications,
} = require("../controllers/dashboardController");

const router = express.Router();

router.get("/home", protect, getHome);

router.get(
  "/learning/daily-plan",
  protect,
  getDailyPlan
);

router.patch(
  "/learning/daily-plan/tasks/:taskId",
  protect,
  updateDailyPlanTask
);

router.get(
  "/users/me/streak",
  protect,
  getStreak
);

router.get(
  "/users/me/statistics",
  protect,
  getStatistics
);

router.get(
  "/lessons/recommended",
  protect,
  getRecommendedLessons
);

router.get(
  "/notifications",
  protect,
  getNotifications
);

module.exports = router;
