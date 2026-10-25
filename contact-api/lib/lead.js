// Pure lead-handling logic for the "Solicitar licencia" form: validation, spam checks and email
// bodies. No I/O here so it can be unit tested; api/contact.js wires it to SMTP.

export const LIMITS = { name: 120, company: 160, email: 200, phone: 40, message: 4000 };
const PLANTS = ["1", "2–3", "4–10", "Más de 10"];
const PLANS = ["Web", "Planta", "Multiplanta", "Empresa", "Aún no sé"];
const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/;
export const LANGS = ["es", "en", "pt"];

/**
 * National-number lengths (digits after the country code) per ISO country.
 * The website keeps the same table in web/src/site.json ("countries"); `python3 web/build.py`
 * parses this object and fails if the two drift, so keep the `XX: { dial: "..", lengths: [..] }` shape.
 */
export const PHONE_RULES = {
  MX: { dial: "52", lengths: [10] },
  US: { dial: "1", lengths: [10] },
  CA: { dial: "1", lengths: [10] },
  GT: { dial: "502", lengths: [8] },
  SV: { dial: "503", lengths: [8] },
  HN: { dial: "504", lengths: [8] },
  NI: { dial: "505", lengths: [8] },
  CR: { dial: "506", lengths: [8] },
  PA: { dial: "507", lengths: [7, 8] },
  DO: { dial: "1", lengths: [10] },
  CO: { dial: "57", lengths: [10] },
  VE: { dial: "58", lengths: [10] },
  EC: { dial: "593", lengths: [8, 9] },
  PE: { dial: "51", lengths: [8, 9] },
  BO: { dial: "591", lengths: [8] },
  CL: { dial: "56", lengths: [9] },
  AR: { dial: "54", lengths: [10] },
  UY: { dial: "598", lengths: [8] },
  PY: { dial: "595", lengths: [8, 9] },
  BR: { dial: "55", lengths: [10, 11] },
  ES: { dial: "34", lengths: [9] },
  PT: { dial: "351", lengths: [9] },
};
/** Without a country (older form versions) any plausible international number is accepted. */
export const LOOSE_PHONE = { min: 7, max: 15 };

/** Minimum time a human needs to fill the form; faster submissions are bots. */
export const MIN_FILL_MS = 2500;

const MESSAGES = {
  es: {
    invalid: "Solicitud inválida.",
    required: "Completa nombre, empresa y un correo válido.",
    phoneRequired: "Escribe tu teléfono.",
    phone: (digits, country) => `Escribe ${digits} dígitos para ${country}, sin el código de país.`,
    phoneLoose: "Escribe un teléfono válido, con código de país.",
    or: (n) => (/^(8|11)$/.test(String(n)) ? "u" : "o"),
    method: "Método no permitido.",
    origin: "Origen no permitido.",
    notConfigured: "El envío de correo no está configurado.",
    rateLimited: "Demasiadas solicitudes. Intenta de nuevo en unos minutos.",
    sendFailed: "No pudimos enviar tu solicitud. Intenta de nuevo o escríbenos por correo.",
  },
  en: {
    invalid: "Invalid request.",
    required: "Please fill in your name, company and a valid email.",
    phoneRequired: "Please enter your phone number.",
    phone: (digits, country) => `Enter ${digits} digits for ${country}, without the country code.`,
    phoneLoose: "Please enter a valid phone number, including the country code.",
    or: () => "or",
    method: "Method not allowed.",
    origin: "Origin not allowed.",
    notConfigured: "Email delivery is not configured.",
    rateLimited: "Too many requests. Please try again in a few minutes.",
    sendFailed: "We couldn't send your request. Please try again or email us.",
  },
  pt: {
    invalid: "Solicitação inválida.",
    required: "Preencha nome, empresa e um e-mail válido.",
    phoneRequired: "Digite o seu telefone.",
    phone: (digits, country) => `Digite ${digits} dígitos para ${country}, sem o código do país.`,
    phoneLoose: "Digite um telefone válido, com o código do país.",
    or: () => "ou",
    method: "Método não permitido.",
    origin: "Origem não permitida.",
    notConfigured: "O envio de e-mail não está configurado.",
    rateLimited: "Muitas solicitações. Tente de novo em alguns minutos.",
    sendFailed: "Não conseguimos enviar a sua solicitação. Tente de novo ou escreva para nós por e-mail.",
  },
};

export const langOf = (value) => (LANGS.includes(value) ? value : "es");
export const messages = (lang) => MESSAGES[langOf(lang)];

const LOCALES = { es: "es-MX", en: "en", pt: "pt-BR" };
export function countryName(iso, lang = "es") {
  try {
    return new Intl.DisplayNames([LOCALES[langOf(lang)]], { type: "region" }).of(iso) ?? iso;
  } catch {
    return iso;
  }
}

const clean = (value, max) => String(value ?? "").replace(/[\u0000-\u0008\u000B-\u001F\u007F]/g, "").trim().slice(0, max);

/**
 * Validates the phone. With a known `country`, `raw` is "+52 5512345678" (or just the national
 * digits) and the national part must have one of the country's lengths. Returns
 * { phone } (normalized "+<dial> <national>", or "" when allowed empty) or { error }.
 */
export function parsePhone(raw, country, lang = "es") {
  const t = messages(lang);
  const text = clean(raw, LIMITS.phone);
  const digits = text.replace(/\D/g, "");
  const rule = PHONE_RULES[country];
  if (!rule) {
    if (!digits) return { phone: "" }; // older form versions had an optional phone
    if (digits.length < LOOSE_PHONE.min || digits.length > LOOSE_PHONE.max) return { error: t.phoneLoose };
    return { phone: text.startsWith("+") ? `+${digits}` : digits };
  }
  if (!digits) return { error: t.phoneRequired };
  const national = text.startsWith("+") && digits.startsWith(rule.dial) ? digits.slice(rule.dial.length) : digits;
  if (!rule.lengths.includes(national.length)) {
    const last = rule.lengths.at(-1);
    const list = rule.lengths.length > 1 ? `${rule.lengths.slice(0, -1).join(", ")} ${t.or(last)} ${last}` : String(last);
    return { error: t.phone(list, countryName(country, lang)) };
  }
  return { phone: `+${rule.dial} ${national}` };
}

/**
 * Returns { ok: true, lead } or { ok: false, status, error, silent }.
 * `silent` marks bot submissions: respond 200 so bots learn nothing, but send no email.
 */
export function parseLead(body, now = Date.now()) {
  if (!body || typeof body !== "object") return { ok: false, status: 400, error: MESSAGES.es.invalid };
  const lang = langOf(body.lang);
  const t = messages(lang);
  if (clean(body.website, 200)) return { ok: false, status: 200, silent: true, error: "honeypot" };
  const startedAt = Number(body.startedAt);
  if (Number.isFinite(startedAt) && now - startedAt < MIN_FILL_MS) return { ok: false, status: 200, silent: true, error: "too fast" };

  const country = clean(body.pais, 2).toUpperCase();
  const lead = {
    name: clean(body.nombre, LIMITS.name),
    company: clean(body.empresa, LIMITS.company),
    email: clean(body.correo, LIMITS.email).toLowerCase(),
    phone: "",
    country: PHONE_RULES[country] ? country : "",
    lang,
    plants: PLANTS.includes(body.plantas) ? body.plantas : "—",
    plan: PLANS.includes(body.plan) ? body.plan : "Aún no sé",
    message: clean(body.mensaje, LIMITS.message),
  };
  if (!lead.name || !lead.company || !EMAIL_RE.test(lead.email)) {
    return { ok: false, status: 422, error: t.required };
  }
  const phone = parsePhone(body.telefono, lead.country, lang);
  if (phone.error) return { ok: false, status: 422, error: phone.error, field: "telefono" };
  lead.phone = phone.phone;
  return { ok: true, lead };
}

const escapeHtml = (s) => s.replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[c]);
const LANG_NAMES = { es: "Español", en: "Inglés", pt: "Portugués" };

/** Notification sent to the Trama inbox (always Spanish). Reply-To is the lead, so answering goes straight to them. */
export function internalEmail(lead) {
  const rows = [
    ["Nombre", lead.name], ["Empresa", lead.company], ["Correo", lead.email], ["Teléfono", lead.phone || "—"],
    ["País", lead.country ? `${countryName(lead.country, "es")} (${lead.country})` : "—"],
    ["Idioma del sitio", LANG_NAMES[lead.lang] ?? "Español"],
    ["Plantas", lead.plants], ["Plan de interés", lead.plan],
  ];
  const text = rows.map(([k, v]) => `${k}: ${v}`).join("\n") + `\n\n${lead.message || "(sin mensaje)"}\n`;
  const html = `<h2 style="font-family:system-ui">Nueva solicitud de licencia</h2>
<table style="font-family:system-ui;border-collapse:collapse">${rows.map(([k, v]) =>
    `<tr><td style="padding:4px 12px 4px 0;color:#5e7178">${k}</td><td style="padding:4px 0"><b>${escapeHtml(v)}</b></td></tr>`).join("")}</table>
<p style="font-family:system-ui;white-space:pre-wrap">${escapeHtml(lead.message || "(sin mensaje)")}</p>`;
  const where = lead.country ? ` · ${lead.country}` : "";
  return { subject: `Trama · Solicitud de licencia · ${lead.company}${where}`, text, html, replyTo: `${lead.name} <${lead.email}>` };
}

const SITE = "https://ranabtawi-trama.static.hf.space";
const SITE_PATH = { es: "/index.html", en: "/en/index.html", pt: "/pt/index.html" };
const PLAN_LABELS = {
  en: { Planta: "Plant", Multiplanta: "Multi-plant", Empresa: "Enterprise", "Aún no sé": "Not sure yet" },
  pt: { "Aún no sé": "Ainda não sei" },
};
const PLANT_LABELS = { en: { "Más de 10": "More than 10" }, pt: { "Más de 10": "Mais de 10" } };

/** Confirmation sent to the lead, in the language of the page they used. */
export function autoReplyEmail(lead) {
  const lang = langOf(lead.lang);
  const first = lead.name.split(/\s+/)[0];
  const plan = PLAN_LABELS[lang]?.[lead.plan] ?? lead.plan;
  const plants = PLANT_LABELS[lang]?.[lead.plants] ?? lead.plants;
  const url = SITE + SITE_PATH[lang];
  const texts = {
    es: {
      subject: "Recibimos tu solicitud · Trama",
      text: `Hola ${first}:

Gracias por tu interés en Trama. Recibimos tu solicitud de licencia para ${lead.company} y te contactaremos en menos de un día hábil para agendar una demo con información parecida a la de tu fábrica.

Resumen de tu solicitud:
- Plantas: ${plants}
- Plan de interés: ${plan}

Si quieres agregar algo, responde a este correo.

Trama · Control de producción textil
${url}
`,
    },
    en: {
      subject: "We received your request · Trama",
      text: `Hi ${first},

Thanks for your interest in Trama. We've received your licence request for ${lead.company} and will get in touch within one business day to schedule a demo with data that looks like your factory's.

Your request:
- Plants: ${plants}
- Plan: ${plan}

If you'd like to add anything, just reply to this email.

Trama · Garment production control
${url}
`,
    },
    pt: {
      subject: "Recebemos a sua solicitação · Trama",
      text: `Olá, ${first}!

Obrigado pelo interesse no Trama. Recebemos a sua solicitação de licença para ${lead.company} e entraremos em contato em até um dia útil para agendar uma demonstração com informações parecidas com as da sua confecção.

Resumo da solicitação:
- Unidades: ${plants}
- Plano de interesse: ${plan}

Se quiser acrescentar algo, é só responder este e-mail.

Trama · Controle de produção têxtil
${url}
`,
    },
  };
  return texts[lang];
}
