
require("dotenv").config();

const express = require("express");
const cors = require("cors");
const cookieParser = require("cookie-parser");
const connectDB = require("./config/db");

const authRoutes = require("./routes/authRoutes");
const userRoutes = require("./routes/userRoutes");
const dashboardRoutes = require("./routes/dashboardRoutes");
const app = express();

app.use(cors());
app.use(express.json({ limit: "100kb" }));
app.use(cookieParser());

app.get("/", (req, res) => {
  res.json({
    success: true,
    message: "English AI Backend is running",
  });
});

app.use("/api/v1/auth", authRoutes);
app.use("/api/v1/users", userRoutes);
app.use("/api/v1", dashboardRoutes);
app.use((req, res) => {
  res.status(404).json({
    success: false,
    message: "API route not found",
  });
});

const startServer = async () => {
  await connectDB();

  const PORT = process.env.PORT || 5000;

  app.listen(PORT, () => {
    console.log(`Server running on port ${PORT}`);
  });
};

startServer().catch((error) => {
  console.error("Server startup failed:", error.message);
  process.exit(1);
});
