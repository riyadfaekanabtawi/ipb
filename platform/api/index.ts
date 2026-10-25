// Vercel entry: every /api/* request is rewritten here (vercel.json) and served by Hono.
import { handle } from "hono/vercel";
import { app } from "../src/app.js";

export const config = { runtime: "nodejs", maxDuration: 30 };

const handler = handle(app);
export const GET = handler;
export const POST = handler;
export const PATCH = handler;
export const PUT = handler;
export const DELETE = handler;
export const OPTIONS = handler;
