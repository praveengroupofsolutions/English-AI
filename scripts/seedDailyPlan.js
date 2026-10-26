
require("dotenv").config();

const mongoose = require("mongoose");
const connectDB = require("../src/config/db");
const DailyPlan = require("../src/models/DailyPlan");

async function seedDailyPlan() {
  try {
    const userId = process.env.DAILY_PLAN_USER_ID;

    if (!userId || !mongoose.isValidObjectId(userId)) {
      throw new Error(
        "Set DAILY_PLAN_USER_ID to a valid MongoDB user ID in the terminal."
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

    const today = new Date().toISOString().slice(0, 10);

    const tasks = [
      {
        title: "Learn 5 English vocabulary words",
        description:
          "Learn five new words and write one example sentence for each.",
        durationMinutes: 10,
        status: "pending",
      },
      {
        title: "Practice English grammar",
        description:
          "Practice basic tenses using example sentences.",
        durationMinutes: 15,
        status: "pending",
      },
      {
        title: "Practice speaking in English",
        description:
          "Speak about your daily routine for two minutes.",
        durationMinutes: 10,
        status: "pending",
      },
    ];

    const plan = await DailyPlan.findOneAndUpdate(
      {
        user: userId,
        date: today,
      },
      {
        $set: {
          tasks,
        },
      },
      {
        new: true,
        upsert: true,
        runValidators: true,
      }
    );

    console.log("Daily plan saved successfully.");
    console.log(JSON.stringify(plan, null, 2));
  } catch (error) {
    console.error("Seed failed:", error.message);
    process.exitCode = 1;
  } finally {
    if (mongoose.connection.readyState !== 0) {
      await mongoose.disconnect();
    }
  }
}

seedDailyPlan();
