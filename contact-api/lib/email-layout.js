// Branded HTML email layout shared by every Trama email (a TypeScript twin lives in
// platform/src/email-layout.ts; keep both in sync). Table-based with inline styles so it
// renders in Gmail, Outlook and Apple Mail; dark-mode overrides for clients that support them.

const C = {
  canvas: "#f4f1ea", surface: "#ffffff", ink: "#0b1f26", soft: "#3d5560", muted: "#6b7f87",
  line: "#e6e1d6", brand: "#145c6e", deep: "#0b3440", bright: "#3fa7bd", thread: "#e8b314", tint: "#eef6f8",
};
const FONT = "'Inter',-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif";
const DISPLAY = "'Bricolage Grotesque','Inter',-apple-system,BlinkMacSystemFont,'Segoe UI',Helvetica,Arial,sans-serif";
const LOGO = "https://trama-platform.vercel.app/assets/icon.png";
export const SITE_URL = "https://trama-platform.vercel.app";

export const esc = (value) =>
  String(value ?? "").replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[c]);

// A woven "thread" stripe: the brand motif, built from table cells so every client shows it.
const WEAVE = [C.bright, C.thread, C.brand, C.thread, C.bright, C.deep, C.thread, C.bright, C.brand, C.thread, C.bright, C.deep];
const weave = () =>
  `<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0"><tr>${WEAVE.map(
    (color) => `<td height="4" style="height:4px;line-height:4px;font-size:0;background:${color}">&nbsp;</td>`,
  ).join("")}</tr></table>`;

function button({ label, url }) {
  return `<table role="presentation" cellpadding="0" cellspacing="0" border="0" style="margin:28px 0 8px">
<tr><td class="btn" bgcolor="${C.brand}" style="border-radius:12px;background:${C.brand};box-shadow:0 6px 18px rgba(20,92,110,.28)">
<a href="${esc(url)}" target="_blank" style="display:inline-block;padding:15px 30px;font:600 16px/1 ${FONT};color:#ffffff;text-decoration:none;border-radius:12px;letter-spacing:.01em">${esc(label)}&nbsp;&nbsp;&rarr;</a>
</td></tr></table>`;
}

function details({ title, rows }) {
  const body = rows
    .map(
      ([key, value], i) => `<tr>
<td class="muted rule" style="padding:11px 0;${i ? `border-top:1px solid ${C.line};` : ""}font:500 13px/1.4 ${FONT};color:${C.muted};width:38%;vertical-align:top">${esc(key)}</td>
<td class="ink rule" style="padding:11px 0;${i ? `border-top:1px solid ${C.line};` : ""}font:600 14px/1.4 ${FONT};color:${C.ink};vertical-align:top">${esc(value)}</td></tr>`,
    )
    .join("");
  return `<tr><td style="padding:8px 40px 0" class="px">
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" class="card" style="background:${C.tint};border-radius:14px;border:1px solid #d7e9ee">
<tr><td style="padding:18px 22px 8px">
${title ? `<div class="eyebrow" style="font:700 11px/1 ${FONT};letter-spacing:.14em;text-transform:uppercase;color:${C.brand};padding-bottom:6px">${esc(title)}</div>` : ""}
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">${body}</table>
</td></tr></table></td></tr>`;
}

function steps({ title, items }) {
  const body = items
    .map(
      (item, i) => `<tr>
<td style="width:44px;vertical-align:top;padding:0 0 18px">
<table role="presentation" cellpadding="0" cellspacing="0" border="0"><tr><td align="center" class="num" style="width:30px;height:30px;border-radius:15px;background:${C.deep};font:700 13px/30px ${FONT};color:${C.thread}">${i + 1}</td></tr></table></td>
<td style="vertical-align:top;padding:4px 0 18px">
<div class="ink" style="font:600 15px/1.35 ${FONT};color:${C.ink}">${esc(item.title)}</div>
${item.body ? `<div class="soft" style="font:400 14px/1.55 ${FONT};color:${C.soft};padding-top:3px">${esc(item.body)}</div>` : ""}
</td></tr>`,
    )
    .join("");
  return `<tr><td style="padding:30px 40px 0" class="px">
${title ? `<div class="eyebrow" style="font:700 11px/1 ${FONT};letter-spacing:.14em;text-transform:uppercase;color:${C.brand};padding-bottom:16px">${esc(title)}</div>` : ""}
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">${body}</table></td></tr>`;
}

function quote({ title, text }) {
  return `<tr><td style="padding:22px 40px 0" class="px">
${title ? `<div class="eyebrow" style="font:700 11px/1 ${FONT};letter-spacing:.14em;text-transform:uppercase;color:${C.brand};padding-bottom:10px">${esc(title)}</div>` : ""}
<div class="ink quote" style="border-left:3px solid ${C.thread};padding:4px 0 4px 16px;font:400 15px/1.6 ${FONT};color:${C.ink};white-space:pre-wrap">${esc(text)}</div></td></tr>`;
}

const notice = ({ text }) =>
  `<tr><td style="padding:22px 40px 0" class="px"><div class="soft" style="font:400 13px/1.55 ${FONT};color:${C.soft}">${esc(text)}</div></td></tr>`;

const SECTIONS = { details, steps, quote, notice };

/**
 * @param {{lang?: string, preheader: string, eyebrow?: string, title: string, intro: string[],
 *   button?: {label: string, url: string}, linkHint?: string, sections?: Array<{type: string}>,
 *   footer: {tagline: string, reason: string, siteLabel?: string, siteUrl?: string}}} email
 */
export function renderEmail(email) {
  const intro = email.intro
    .map((p) => `<p class="soft" style="margin:0 0 14px;font:400 16px/1.6 ${FONT};color:${C.soft}">${esc(p)}</p>`)
    .join("");
  const sections = (email.sections ?? []).map((s) => SECTIONS[s.type](s)).join("");
  const site = email.footer.siteUrl ?? SITE_URL;
  return `<!doctype html>
<html lang="${esc(email.lang ?? "es")}" xmlns="http://www.w3.org/1999/xhtml">
<head>
<meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<meta name="color-scheme" content="light dark"><meta name="supported-color-schemes" content="light dark">
<title>${esc(email.title)}</title>
<style>
  body{margin:0;padding:0;background:${C.canvas}}
  a{color:${C.brand}}
  @media (max-width:620px){ .px{padding-left:24px!important;padding-right:24px!important} .h1{font-size:26px!important} .wrap{border-radius:0!important} }
  @media (prefers-color-scheme:dark){
    body,.bg{background:#081418!important} .wrap{background:#10222a!important;border-color:#1d3540!important}
    .ink{color:#eef3f4!important} .soft{color:#b9c8cd!important} .muted{color:#8ea2a9!important}
    .card{background:#0c2b34!important;border-color:#1d4450!important} .eyebrow{color:#7fcbdb!important}
    .footer,.footer a{color:#8ea2a9!important} .rule{border-color:#1d3540!important}
  }
</style>
</head>
<body class="bg" style="margin:0;padding:0;background:${C.canvas}">
<div style="display:none;max-height:0;overflow:hidden;opacity:0;mso-hide:all">${esc(email.preheader)}${"&#8199;&#65279;&#847; ".repeat(40)}</div>
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" class="bg" style="background:${C.canvas}">
<tr><td align="center" style="padding:32px 12px">
<table role="presentation" width="600" cellpadding="0" cellspacing="0" border="0" class="wrap" style="width:100%;max-width:600px;background:${C.surface};border-radius:20px;overflow:hidden;border:1px solid ${C.line}">
<tr><td bgcolor="${C.deep}" style="background:${C.deep};background-image:linear-gradient(135deg,${C.deep} 0%,${C.brand} 100%);padding:26px 40px" class="px">
<table role="presentation" cellpadding="0" cellspacing="0" border="0"><tr>
<td style="vertical-align:middle"><img src="${LOGO}" width="36" height="36" alt="" style="display:block;border:0;border-radius:9px"></td>
<td style="vertical-align:middle;padding-left:12px;font:700 22px/1 ${DISPLAY};color:#ffffff;letter-spacing:-.02em">Trama</td>
</tr></table></td></tr>
<tr><td>${weave()}</td></tr>
<tr><td style="padding:40px 40px 4px" class="px">
${email.eyebrow ? `<div class="eyebrow" style="font:700 12px/1 ${FONT};letter-spacing:.16em;text-transform:uppercase;color:${C.brand};padding-bottom:14px">${esc(email.eyebrow)}</div>` : ""}
<h1 class="ink h1" style="margin:0 0 18px;font:700 30px/1.15 ${DISPLAY};color:${C.ink};letter-spacing:-.02em">${esc(email.title)}</h1>
${intro}
${email.button ? button(email.button) : ""}
${email.button && email.linkHint ? `<p class="muted" style="margin:14px 0 0;font:400 12px/1.5 ${FONT};color:${C.muted}">${esc(email.linkHint)}<br><a href="${esc(email.button.url)}" style="color:${C.brand};word-break:break-all">${esc(email.button.url)}</a></p>` : ""}
</td></tr>
${sections}
<tr><td style="padding:36px 40px 0" class="px"><div class="rule" style="border-top:1px solid ${C.line};font-size:0;line-height:0">&nbsp;</div></td></tr>
<tr><td style="padding:20px 40px 34px" class="px footer">
<div class="ink" style="font:700 14px/1.4 ${DISPLAY};color:${C.ink}">Trama</div>
<div class="footer" style="font:400 13px/1.55 ${FONT};color:${C.muted};padding-top:2px">${esc(email.footer.tagline)} · <a href="${esc(site)}" style="color:${C.muted};text-decoration:underline">${esc(email.footer.siteLabel ?? site.replace(/^https?:\/\//, ""))}</a></div>
<div class="footer" style="font:400 12px/1.55 ${FONT};color:${C.muted};padding-top:10px">${esc(email.footer.reason)}</div>
</td></tr>
</table>
</td></tr></table>
</body></html>`;
}
