// Vercel serverless function (Node runtime, SMTP needs raw sockets): POST /api/contact.
// Sends the licence request to CONTACT_TO through Gmail SMTP and an auto-reply to the lead.
// Env: GMAIL_USER, GMAIL_APP_PASSWORD, CONTACT_TO (defaults to GMAIL_USER), ALLOWED_ORIGINS (comma list).
import nodemailer from "nodemailer";
import { autoReplyEmail, internalEmail, messages, parseLead } from "../lib/lead.js";

export const config = { runtime: "nodejs", maxDuration: 15 };

const DEFAULT_ORIGINS = ["https://ranabtawi-trama.static.hf.space", "https://ranabtawi-trama.hf.space", "https://huggingface.co"];
const WINDOW_MS = 10 * 60 * 1000;
const MAX_PER_WINDOW = 5;
const hits = new Map(); // best-effort per-instance rate limit; honeypot + timing stop most bots anyway

function allowedOrigins() {
  const extra = (process.env.ALLOWED_ORIGINS ?? "").split(",").map((s) => s.trim()).filter(Boolean);
  return extra.length ? extra : DEFAULT_ORIGINS;
}

function cors(res, origin) {
  if (origin && allowedOrigins().includes(origin)) res.setHeader("Access-Control-Allow-Origin", origin);
  res.setHeader("Vary", "Origin");
  res.setHeader("Access-Control-Allow-Methods", "POST, OPTIONS");
  res.setHeader("Access-Control-Allow-Headers", "Content-Type");
  res.setHeader("Access-Control-Max-Age", "86400");
}

function rateLimited(ip, now = Date.now()) {
  const recent = (hits.get(ip) ?? []).filter((t) => now - t < WINDOW_MS);
  recent.push(now);
  hits.set(ip, recent);
  return recent.length > MAX_PER_WINDOW;
}

let transport;
function mailer() {
  transport ??= nodemailer.createTransport({
    host: "smtp.gmail.com",
    port: 465,
    secure: true,
    auth: { user: process.env.GMAIL_USER, pass: process.env.GMAIL_APP_PASSWORD },
  });
  return transport;
}

export default async function handler(req, res) {
  const origin = req.headers.origin;
  cors(res, origin);
  if (req.method === "OPTIONS") return res.status(204).end();
  const body = typeof req.body === "string" ? safeJson(req.body) : req.body;
  const t = messages(body?.lang); // error messages follow the page language (es/en/pt)
  if (req.method !== "POST") return res.status(405).json({ error: t.method });
  if (!origin || !allowedOrigins().includes(origin)) return res.status(403).json({ error: t.origin });
  if (!process.env.GMAIL_USER || !process.env.GMAIL_APP_PASSWORD) {
    return res.status(503).json({ error: t.notConfigured });
  }

  const ip = String(req.headers["x-forwarded-for"] ?? "").split(",")[0].trim() || "unknown";
  if (rateLimited(ip)) return res.status(429).json({ error: t.rateLimited });

  const parsed = parseLead(body);
  if (!parsed.ok) return res.status(parsed.status).json(parsed.silent ? { ok: true } : { error: parsed.error, field: parsed.field });

  const from = `Trama <${process.env.GMAIL_USER}>`;
  const to = process.env.CONTACT_TO || process.env.GMAIL_USER;
  const internal = internalEmail(parsed.lead);
  try {
    await mailer().sendMail({ from, to, replyTo: internal.replyTo, subject: internal.subject, text: internal.text, html: internal.html });
  } catch (error) {
    console.error("contact: notification failed", error?.code ?? error?.message);
    return res.status(502).json({ error: t.sendFailed });
  }
  // The auto-reply is a courtesy; the lead is already delivered, so its failure doesn't fail the request.
  const reply = autoReplyEmail(parsed.lead);
  await mailer().sendMail({ from, to: parsed.lead.email, replyTo: to, subject: reply.subject, text: reply.text })
    .catch((error) => console.error("contact: auto-reply failed", error?.code ?? error?.message));
  return res.status(200).json({ ok: true });
}

function safeJson(text) {
  try { return JSON.parse(text); } catch { return null; }
}
