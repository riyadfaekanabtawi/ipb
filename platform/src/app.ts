import { Hono } from "hono";
import { bodyLimit } from "hono/body-limit";
import { cors } from "hono/cors";
import { HTTPException } from "hono/http-exception";
import { secureHeaders } from "hono/secure-headers";
import { z } from "zod";
import { config } from "./config.js";
import { ApiError, body, requestLang, requireUser, type Env } from "./http.js";
import { msg } from "./i18n.js";
import { admin } from "./routes/admin.js";
import { auth } from "./routes/auth.js";
import { pull, push, pushSchema } from "./sync.js";

export const app = new Hono<Env>().basePath("/api");

app.use("*", secureHeaders());
// Native apps don't send an Origin; the web app is same-origin. Allow the configured app URL only.
app.use("*", cors({ origin: (origin) => (origin === config.appUrl ? origin : null), credentials: false, maxAge: 86400 }));
// Vercel caps request bodies at 4.5 MB; fail early with a clear message.
app.use("*", bodyLimit({ maxSize: 4 * 1024 * 1024, onError: (c) => c.json({ error: { code: "too_large", message: msg(requestLang(c), "tooLarge") } }, 413) }));

app.get("/health", (c) => c.json({ ok: true }));
app.route("/auth", auth);
app.route("/admin", admin);

app.get("/sync/pull", requireUser, async (c) => {
  const cursor = Number(c.req.query("cursor") ?? 0);
  const limit = Number(c.req.query("limit") ?? 500);
  if (!Number.isFinite(cursor) || cursor < 0) throw new ApiError(422, "invalid_cursor", "invalidCursor");
  return c.json(await pull(c.get("user"), cursor, Number.isFinite(limit) ? limit : 500));
});

app.post("/sync/push", requireUser, async (c) => {
  const { changes } = await body(c, pushSchema);
  return c.json(await push(c.get("user"), changes, requestLang(c)));
});

app.notFound((c) => c.json({ error: { code: "not_found", message: msg(requestLang(c), "routeNotFound") } }, 404));

// Messages follow the request's Accept-Language; codes are the same in every language.
app.onError((error, c) => {
  const lang = requestLang(c);
  if (error instanceof ApiError) return c.json({ error: { code: error.code, message: error.localized(lang) } }, error.status);
  if (error instanceof HTTPException) return c.json({ error: { code: "http_error", message: error.message } }, error.status);
  if (error instanceof z.ZodError) return c.json({ error: { code: "invalid_input", message: msg(lang, "invalidData") } }, 422);
  console.error("api error", error instanceof Error ? error.message : error); // never log bodies (they contain business data)
  return c.json({ error: { code: "server_error", message: msg(lang, "serverError") } }, 500);
});
