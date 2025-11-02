import express, { Application } from "express";
import cors from "cors";
import { apiRouter } from "./routes";
import { errorHandler, notFoundHandler } from "./middleware";

const app: Application = express();
const PORT = process.env.PORT || 3000;

app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

app.get("/health", (_req, res) => {
  res.json({
    status: "ok",
    version: "1.0.0",
    timestamp: new Date().toISOString()
  });
});

app.use("/api/v1", apiRouter);
app.use(notFoundHandler);
app.use(errorHandler);

app.listen(PORT, () => {
  console.log(`Agent server running on port ${PORT}`);
});

export default app;
