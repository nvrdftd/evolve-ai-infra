import { Request, Response, NextFunction } from "express";

export interface AppError extends Error {
  status?: number;
  statusCode?: number;
  isOperational?: boolean; // Flag for expected/safe errors
}

// Safe error messages that can be exposed to clients
const SAFE_ERROR_MESSAGES = new Set([
  "Route not found",
  "Invalid request body",
  "Missing required fields",
  "Invalid agent input",
  "Agent invocation failed",
  "Bad request",
  "Unauthorized",
  "Forbidden",
  "Not found",
]);

const sanitizeErrorMessage = (message: string, status: number): string => {
  // For 4xx client errors, allow more specific messages if they're in the safe list
  if (status >= 400 && status < 500 && SAFE_ERROR_MESSAGES.has(message)) {
    return message;
  }

  // For 5xx server errors, return a generic message
  if (status >= 500) {
    return "Internal server error";
  }

  // For other cases, return a generic message
  return "An error occurred";
};

export const errorHandler = (
  err: AppError,
  req: Request,
  res: Response,
  _next: NextFunction
) => {
  const status = err.status || err.statusCode || 500;
  const safeMessage = sanitizeErrorMessage(err.message, status);

  console.error("Error:", {
    message: err.message,
    status,
    path: req.path,
    method: req.method,
    timestamp: new Date().toISOString(),
  });

  // Send sanitized response to client
  res.status(status).json({
    error: safeMessage,
    status,
    timestamp: new Date().toISOString(),
  });
};

export const notFoundHandler = (_req: Request, res: Response) => {
  res.status(404).json({
    error: "Route not found",
    status: 404,
    timestamp: new Date().toISOString(),
  });
};
