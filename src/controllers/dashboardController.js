
const DailyPlan = require("../models/DailyPlan");

exports.getHome = async (req, res) => {
  try {
    const today = new Date().toISOString().slice(0, 10);

    const dailyPlan = await DailyPlan.findOne({
      user: req.user._id,
      date: today,
    }).lean();

    return res.json({
      success: true,
      message: "Home dashboard fetched successfully",
      data: {
        user: {
          id: req.user._id,
          name: req.user.name,
          photo: req.user.photo,
        },
        dailyPlan: dailyPlan
          ? {
              date: dailyPlan.date,
              tasks: dailyPlan.tasks,
            }
          : null,
        streak: null,
        statistics: null,
        recommendedLessons: [],
        notifications: [],
      },
    });
  } catch (error) {
    console.error("getHome error:", error.message);

    return res.status(500).json({
      success: false,
      message: "Failed to fetch home dashboard",
    });
  }
};

exports.getDailyPlan = async (req, res) => {
  try {
    const today = new Date().toISOString().slice(0, 10);

    const dailyPlan = await DailyPlan.findOne({
      user: req.user._id,
      date: today,
    }).lean();

    if (!dailyPlan) {
      return res.json({
        success: true,
        message: "No daily plan found for today",
        data: {
          available: false,
          date: today,
          tasks: [],
        },
      });
    }

    return res.json({
      success: true,
      message: "Daily plan fetched successfully",
      data: {
        available: true,
        date: dailyPlan.date,
        tasks: dailyPlan.tasks,
      },
    });
  } catch (error) {
    console.error("getDailyPlan error:", error.message);

    return res.status(500).json({
      success: false,
      message: "Failed to fetch daily plan",
    });
  }
};

exports.getStreak = async (req, res) => {
  return res.json({
    success: true,
    message: "Streak tracking has not been implemented yet",
    data: {
      available: false,
    },
  });
};

exports.getStatistics = async (req, res) => {
  return res.json({
    success: true,
    message: "Learning statistics have not been implemented yet",
    data: {
      available: false,
    },
  });
};

exports.getRecommendedLessons = async (req, res) => {
  return res.json({
    success: true,
    message: "Recommended lessons fetched successfully",
    data: {
      lessons: [],
    },
  });
};

exports.getNotifications = async (req, res) => {
  return res.json({
    success: true,
    message: "Notifications fetched successfully",
    data: {
      notifications: [],
    },
  });
};
