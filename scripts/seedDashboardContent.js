
require("dotenv").config();

const mongoose = require("mongoose");
const connectDB = require("../src/config/db");
const Lesson = require("../src/models/Lesson");
const Notification = require("../src/models/Notification");

async function seedDashboardContent() {
  try {
    const userId = process.env.DAILY_PLAN_USER_ID;

    if (!userId || !mongoose.isValidObjectId(userId)) {
      throw new Error(
        "Set DAILY_PLAN_USER_ID to a valid MongoDB user ID."
      );
    }

    await connectDB();

    const userExists = await mongoose.connection
      .collection("users")
      .findOne({
        _id: new mongoose.Types.ObjectId(userId),
      });

    if (!userExists) {
      throw new Error(
        "User not found. Check DAILY_PLAN_USER_ID."
      );
    }

    const lessons = [
      {
        title: "English Grammar Basics",
        description: "Learn basic grammar rules and sentence structure.",
        category: "Grammar",
        level: "beginner",
        durationMinutes: 15,
        isPublished: true,
        sortOrder: 1,
      },
      {
        title: "Daily English Vocabulary",
        description: "Build vocabulary with useful everyday words.",
        category: "Vocabulary",
        level: "beginner",
        durationMinutes: 10,
        isPublished: true,
        sortOrder: 2,
      },
      {
        title: "Common English Conversations",
        description: "Practice common conversations used in daily life.",
        category: "Speaking",
        level: "beginner",
        durationMinutes: 15,
        isPublished: true,
        sortOrder: 3,
      },
      {
        title: "English Tenses Practice",
        description: "Practice present, past, and future tenses.",
        category: "Grammar",
        level: "intermediate",
        durationMinutes: 20,
        isPublished: true,
        sortOrder: 4,
      },
      {
        title: "Improve Your Pronunciation",
        description: "Practice clear pronunciation of common English words.",
        category: "Pronunciation",
        level: "beginner",
        durationMinutes: 10,
        isPublished: true,
        sortOrder: 5,
      },
    ];

    for (const lesson of lessons) {
      await Lesson.findOneAndUpdate(
        { title: lesson.title },
        { $set: lesson },
        { upsert: true, new: true, runValidators: true }
      );
    }

    await Notification.findOneAndUpdate(
      {
        user: userId,
        title: "Welcome to English AI",
      },
      {
        $setOnInsert: {
          user: userId,
          title: "Welcome to English AI",
          message:
            "Start your daily learning plan and practice English every day.",
          type: "general",
          readAt: null,
        },
      },
      {
        upsert: true,
        new: true,
        runValidators: true,
      }
    );

    console.log("Dashboard sample content seeded successfully.");
    console.log("Lessons created or updated:", lessons.length);
    console.log("Welcome notification is available for the test user.");
  } catch (error) {
    console.error("Dashboard seed failed:", error.message);
    process.exitCode = 1;
  } finally {
    if (mongoose.connection.readyState !== 0) {
      await mongoose.disconnect();
    }
  }
}

seedDashboardContent();
