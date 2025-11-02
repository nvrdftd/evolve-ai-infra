import { Router, Request, Response, NextFunction } from "express";
import { streamAgent } from "./graph";
import { AppError } from "./middleware";

export const apiRouter = Router();

apiRouter.post("/agent/invoke", async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { message } = req.body;

    if (!message || typeof message !== "string") {
      const error: AppError = new Error("Missing required fields");
      error.status = 400;
      throw error;
    }

    // Set headers for SSE (Server-Sent Events)
    res.setHeader("Content-Type", "text/event-stream");
    res.setHeader("Cache-Control", "no-cache");
    res.setHeader("Connection", "keep-alive");

    // Stream the agent's response
    await streamAgent(message, (chunk) => {
      res.write(`data: ${JSON.stringify(chunk)}\n\n`);
    });

    res.write("data: [DONE]\n\n");
    res.end();
  } catch (error) {
    next(error);
  }
});
