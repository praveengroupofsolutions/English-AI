
const mongoose = require("mongoose");

const dailyPlanTaskSchema = new mongoose.Schema(
  {
    title: {
      type: String,
      required: true,
      trim: true,
    },
    description: {
      type: String,
      default: "",
      trim: true,
    },
    durationMinutes: {
      type: Number,
      default: 10,
      min: 1,
    },
    status: {
      type: String,
      enum: ["pending", "in_progress", "completed"],
      default: "pending",
    },
  },
  { _id: true }
);

const dailyPlanSchema = new mongoose.Schema(
  {
    user: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
      index: true,
    },
    date: {
      type: String,
      required: true,
    },
    tasks: {
      type: [dailyPlanTaskSchema],
      default: [],
    },
  },
  { timestamps: true }
);

dailyPlanSchema.index({ user: 1, date: 1 }, { unique: true });

module.exports = mongoose.model("DailyPlan", dailyPlanSchema);
