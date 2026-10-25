// Local API server for development: npm run dev:api (reads DATABASE_URL etc. from env).
import { serve } from "@hono/node-server";
import { app } from "../src/app.js";

const port = Number(process.env.PORT ?? 8787);
serve({ fetch: app.fetch, port });
console.log(`Trama API on http://localhost:${port}/api`);
