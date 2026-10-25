// Pure lead-handling logic for the "Solicitar licencia" form: validation, spam checks and email
// bodies. No I/O here so it can be unit tested; api/contact.js wires it to SMTP.

export const LIMITS = { name: 120, company: 160, email: 200, phone: 40, message: 4000 };
const PLANTS = ["1", "2–3", "4–10", "Más de 10"];
const PLANS = ["Planta", "Multiplanta", "Empresa", "Aún no sé"];
const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/;

/** Minimum time a human needs to fill the form; faster submissions are bots. */
export const MIN_FILL_MS = 2500;

const clean = (value, max) => String(value ?? "").replace(/[\u0000-\u0008\u000B-\u001F\u007F]/g, "").trim().slice(0, max);

/**
 * Returns { ok: true, lead } or { ok: false, status, error, silent }.
 * `silent` marks bot submissions: respond 200 so bots learn nothing, but send no email.
 */
export function parseLead(body, now = Date.now()) {
  if (!body || typeof body !== "object") return { ok: false, status: 400, error: "Solicitud inválida." };
  if (clean(body.website, 200)) return { ok: false, status: 200, silent: true, error: "honeypot" };
  const startedAt = Number(body.startedAt);
  if (Number.isFinite(startedAt) && now - startedAt < MIN_FILL_MS) return { ok: false, status: 200, silent: true, error: "too fast" };

  const lead = {
    name: clean(body.nombre, LIMITS.name),
    company: clean(body.empresa, LIMITS.company),
    email: clean(body.correo, LIMITS.email).toLowerCase(),
    phone: clean(body.telefono, LIMITS.phone),
    plants: PLANTS.includes(body.plantas) ? body.plantas : "—",
    plan: PLANS.includes(body.plan) ? body.plan : "Aún no sé",
    message: clean(body.mensaje, LIMITS.message),
  };
  if (!lead.name || !lead.company || !EMAIL_RE.test(lead.email)) {
    return { ok: false, status: 422, error: "Completa nombre, empresa y un correo válido." };
  }
  return { ok: true, lead };
}

const escapeHtml = (s) => s.replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[c]);

/** Notification sent to the Trama inbox. Reply-To is the lead, so answering goes straight to them. */
export function internalEmail(lead) {
  const rows = [
    ["Nombre", lead.name], ["Empresa", lead.company], ["Correo", lead.email], ["Teléfono", lead.phone || "—"],
    ["Plantas", lead.plants], ["Plan de interés", lead.plan],
  ];
  const text = rows.map(([k, v]) => `${k}: ${v}`).join("\n") + `\n\n${lead.message || "(sin mensaje)"}\n`;
  const html = `<h2 style="font-family:system-ui">Nueva solicitud de licencia</h2>
<table style="font-family:system-ui;border-collapse:collapse">${rows.map(([k, v]) =>
    `<tr><td style="padding:4px 12px 4px 0;color:#5e7178">${k}</td><td style="padding:4px 0"><b>${escapeHtml(v)}</b></td></tr>`).join("")}</table>
<p style="font-family:system-ui;white-space:pre-wrap">${escapeHtml(lead.message || "(sin mensaje)")}</p>`;
  return { subject: `Trama · Solicitud de licencia · ${lead.company}`, text, html, replyTo: `${lead.name} <${lead.email}>` };
}

/** Confirmation sent to the lead. */
export function autoReplyEmail(lead) {
  const first = lead.name.split(/\s+/)[0];
  const text = `Hola ${first}:

Gracias por tu interés en Trama. Recibimos tu solicitud de licencia para ${lead.company} y te contactaremos en menos de un día hábil para agendar una demo con información parecida a la de tu fábrica.

Resumen de tu solicitud:
- Plantas: ${lead.plants}
- Plan de interés: ${lead.plan}

Si quieres agregar algo, responde a este correo.

Trama · Control de producción textil
https://ranabtawi-trama.static.hf.space/index.html
`;
  return { subject: "Recibimos tu solicitud · Trama", text };
}
