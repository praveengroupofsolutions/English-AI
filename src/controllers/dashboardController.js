
const mongoose = require("mongoose");
const DailyPlan = require("../models/DailyPlan");
const Lesson = require("../models/Lesson");
const Notification = require("../models/Notification");

function getUTCDateString(date) {
  return date.toISOString().slice(0, 10);
}

function shiftUTCDate(dateString, days) {
  const date = new Date(`${dateString}T00:00:00.000Z`);
  date.setUTCDate(date.getUTCDate() + days);
  return getUTCDateString(date);
}

function calculateStreak(dailyPlans) {
  const activeDates = [
    ...new Set(
      dailyPlans
        .filter((plan) =>
          plan.tasks.some((task) => task.status === "completed")
        )
        .map((plan) => plan.date)
    ),
  ].sort();

  const today = getUTCDateString(new Date());
  const yesterday = shiftUTCDate(today, -1);

  const activeDateSet = new Set(activeDates);

  let currentStreak = 0;
  let checkDate = activeDateSet.has(today) ? today : yesterday;

  if (activeDateSet.has(checkDate)) {
    while (activeDateSet.has(checkDate)) {
      currentStreak += 1;
      checkDate = shiftUTCDate(checkDate, -1);
    }
  }

  let longestStreak = 0;
  let runningStreak = 0;
  let previousDate = null;

  for (const date of activeDates) {
    if (
      previousDate &&
      shiftUTCDate(previousDate, 1) === date
    ) {
      runningStreak += 1;
    } else {
      runningStreak = 1;
    }

    longestStreak = Math.max(longestStreak, runningStreak);
    previousDate = date;
  }

  return {
    currentStreak,
    longestStreak,
    activeDays: activeDates.length,
    lastActiveDate: activeDates.length
      ? activeDates[activeDates.length - 1]
      : null,
  };
}

function calculateStatistics(dailyPlans) {
  let totalTasks = 0;
  let completedTasks = 0;
  let totalMinutesLearned = 0;

  for (const plan of dailyPlans) {
    for (const task of plan.tasks) {
      totalTasks += 1;

      if (task.status === "completed") {
        completedTasks += 1;
        totalMinutesLearned += task.durationMinutes || 0;
      }
    }
  }

  return {
    totalTasks,
    completedTasks,
    pendingTasks: totalTasks - completedTasks,
    completionRate:
      totalTasks === 0
        ? 0
        : Math.round((completedTasks / totalTasks) * 100),
    totalMinutesLearned,
    activeDays: calculateStreak(dailyPlans).activeDays,
  };
}

async function fetchStreak(userId) {
  const dailyPlans = await DailyPlan.find({ user: userId })
    .select("date tasks")
    .lean();

  return calculateStreak(dailyPlans);
}

async function fetchStatistics(userId) {
  const dailyPlans = await DailyPlan.find({ user: userId })
    .select("date tasks")
    .lean();

  return calculateStatistics(dailyPlans);
}

async function fetchRecommendedLessons() {
  return Lesson.find({ isPublished: true })
    .select("title description category level durationMinutes")
    .sort({ sortOrder: 1, createdAt: -1 })
    .limit(10)
    .lean();
}

async function fetchNotifications(userId) {
  return Notification.find({ user: userId })
    .select("title message type readAt createdAt")
    .sort({ createdAt: -1 })
    .limit(20)
    .lean();
}

exports.getHome = async (req, res) => {
  try {
    const today = getUTCDateString(new Date());

    const [
      dailyPlan,
      streak,
      statistics,
      recommendedLessons,
      notifications,
    ] = await Promise.all([
      DailyPlan.findOne({
        user: req.user._id,
        date: today,
      }).lean(),
      fetchStreak(req.user._id),
      fetchStatistics(req.user._id),
      fetchRecommendedLessons(),
      fetchNotifications(req.user._id),
    ]);

    return res.status(200).json({
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
        streak,
        statistics,
        recommendedLessons,
        notifications,
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
    const today = getUTCDateString(new Date());

    const dailyPlan = await DailyPlan.findOne({
      user: req.user._id,
      date: today,
    }).lean();

    if (!dailyPlan) {
      return res.status(200).json({
        success: true,
        message: "No daily plan found for today",
        data: {
          available: false,
          date: today,
          tasks: [],
        },
      });
    }

    return res.status(200).json({
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

exports.updateDailyPlanTask = async (req, res) => {
  try {
    const { taskId } = req.params;
    const { status } = req.body;

    if (!mongoose.isValidObjectId(taskId)) {
      return res.status(400).json({
        success: false,
        message: "Invalid task ID",
      });
    }

    const allowedStatuses = [
      "pending",
      "in_progress",
      "completed",
    ];

    if (!allowedStatuses.includes(status)) {
      return res.status(400).json({
        success: false,
        message:
          "Invalid status. Use pending, in_progress, or completed.",
      });
    }

    const today = getUTCDateString(new Date());

    const dailyPlan = await DailyPlan.findOne({
      user: req.user._id,
      date: today,
    });

    if (!dailyPlan) {
      return res.status(404).json({
        success: false,
        message: "Today's daily plan was not found",
      });
    }

    const task = dailyPlan.tasks.id(taskId);

    if (!task) {
      return res.status(404).json({
        success: false,
        message: "Task not found in today's daily plan",
      });
    }

    task.status = status;
    await dailyPlan.save();

    return res.status(200).json({
      success: true,
      message: "Daily plan task status updated successfully",
      data: {
        date: dailyPlan.date,
        task: {
          id: task._id,
          title: task.title,
          description: task.description,
          durationMinutes: task.durationMinutes,
          status: task.status,
        },
      },
    });
  } catch (error) {
    console.error("updateDailyPlanTask error:", error.message);

    return res.status(500).json({
      success: false,
      message: "Failed to update daily plan task",
    });
  }
};

exports.getStreak = async (req, res) => {
  try {
    const streak = await fetchStreak(req.user._id);

    return res.status(200).json({
      success: true,
      message: "Learning streak fetched successfully",
      data: streak,
    });
  } catch (error) {
    console.error("getStreak error:", error.message);

    return res.status(500).json({
      success: false,
      message: "Failed to fetch learning streak",
    });
  }
};

exports.getStatistics = async (req, res) => {
  try {
    const statistics = await fetchStatistics(req.user._id);

    return res.status(200).json({
      success: true,
      message: "Learning statistics fetched successfully",
      data: statistics,
    });
  } catch (error) {
    console.error("getStatistics error:", error.message);

    return res.status(500).json({
      success: false,
      message: "Failed to fetch learning statistics",
    });
  }
};

exports.getRecommendedLessons = async (req, res) => {
  try {
    const lessons = await fetchRecommendedLessons();

    return res.status(200).json({
      success: true,
      message: "Recommended lessons fetched successfully",
      data: { lessons },
    });
  } catch (error) {
    console.error("getRecommendedLessons error:", error.message);

    return res.status(500).json({
      success: false,
      message: "Failed to fetch recommended lessons",
    });
  }
};

exports.getNotifications = async (req, res) => {
  try {
    const notifications = await fetchNotifications(req.user._id);

    return res.status(200).json({
      success: true,
      message: "Notifications fetched successfully",
      data: { notifications },
    });
  } catch (error) {
    console.error("getNotifications error:", error.message);

    return res.status(500).json({
      success: false,
      message: "Failed to fetch notifications",
    });
  }
};
