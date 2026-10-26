
exports.getHome = async (req, res) => {
  return res.json({
    success: true,
    message: "Home dashboard fetched successfully",
    data: {
      user: {
        id: req.user._id,
        name: req.user.name,
        photo: req.user.photo,
      },
      dailyPlan: null,
      streak: null,
      statistics: null,
      recommendedLessons: [],
      notifications: [],
    },
  });
};

exports.getDailyPlan = async (req, res) => {
  return res.json({
    success: true,
    message: "Daily plan fetched successfully",
    data: {
      available: false,
      message: "Daily plan has not been configured yet",
      lessons: [],
    },
  });
};

exports.getStreak = async (req, res) => {
  return res.json({
    success: true,
    message: "Streak information fetched successfully",
    data: {
      available: false,
      message: "Streak tracking has not been implemented yet",
    },
  });
};

exports.getStatistics = async (req, res) => {
  return res.json({
    success: true,
    message: "Statistics fetched successfully",
    data: {
      available: false,
      message: "Learning statistics have not been implemented yet",
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
