import assert from "node:assert/strict";
import { test } from "node:test";
import { autoReplyEmail, internalEmail, LIMITS, messages, MIN_FILL_MS, parseLead, parsePhone, PHONE_RULES } from "../lib/lead.js";

const now = 1_800_000_000_000;
const valid = {
  nombre: "Laura Méndez", empresa: "Textiles Norte", correo: "Laura@Example.com", telefono: "+52 5512345678", pais: "MX", lang: "es",
  plantas: "2–3", plan: "Multiplanta", mensaje: "Hola", startedAt: now - 10_000,
};

test("accepts a valid lead and normalizes the email and phone", () => {
  const r = parseLead(valid, now);
  assert.equal(r.ok, true);
  assert.equal(r.lead.email, "laura@example.com");
  assert.equal(r.lead.plants, "2–3");
  assert.equal(r.lead.phone, "+52 5512345678");
  assert.equal(r.lead.country, "MX");
  assert.equal(r.lead.lang, "es");
});

test("rejects missing fields and bad emails with a 422", () => {
  assert.equal(parseLead({ ...valid, empresa: " " }, now).status, 422);
  assert.equal(parseLead({ ...valid, correo: "nope" }, now).status, 422);
  assert.equal(parseLead(null, now).status, 400);
});

test("bots are dropped silently (honeypot and too-fast submissions)", () => {
  assert.deepEqual([parseLead({ ...valid, website: "spam.com" }, now).silent, parseLead({ ...valid, startedAt: now - MIN_FILL_MS + 1 }, now).silent], [true, true]);
});

test("unknown select values fall back and long text is truncated", () => {
  const r = parseLead({ ...valid, plantas: "999", plan: "<script>", mensaje: "x".repeat(10_000) }, now);
  assert.equal(r.lead.plants, "—");
  assert.equal(r.lead.plan, "Aún no sé");
  assert.equal(r.lead.message.length, LIMITS.message);
});

test("the Web plan is accepted", () => {
  assert.equal(parseLead({ ...valid, plan: "Web" }, now).lead.plan, "Web");
});

test("10-digit countries require exactly 10 national digits", () => {
  for (const iso of ["MX", "US", "CA", "DO", "CO", "AR"]) {
    const dial = PHONE_RULES[iso].dial;
    assert.equal(parseLead({ ...valid, pais: iso, telefono: `+${dial} 5512345678` }, now).ok, true, iso);
    assert.equal(parseLead({ ...valid, pais: iso, telefono: `+${dial} 551234567` }, now).status, 422, iso);
    assert.equal(parseLead({ ...valid, pais: iso, telefono: `+${dial} 55123456789` }, now).status, 422, iso);
  }
});

test("Brazil accepts 10 or 11 digits; other countries use their own lengths", () => {
  assert.equal(parsePhone("+55 1123456789", "BR").phone, "+55 1123456789");
  assert.equal(parsePhone("+55 11987654321", "BR").phone, "+55 11987654321");
  assert.ok(parsePhone("+55 119876543210", "BR").error);
  assert.equal(parsePhone("+502 22345678", "GT").phone, "+502 22345678");
  assert.ok(parsePhone("+502 2234567", "GT").error);
  assert.equal(parsePhone("+56 912345678", "CL").phone, "+56 912345678");
  assert.equal(parsePhone("+507 2123456", "PA").phone, "+507 2123456");
  assert.equal(parsePhone("+351 912345678", "PT").phone, "+351 912345678");
});

test("phone accepts separators and bare national numbers, and is required with a country", () => {
  assert.equal(parsePhone("+52 55-1234 5678", "MX").phone, "+52 5512345678");
  assert.equal(parsePhone("(55) 1234-5678", "MX").phone, "+52 5512345678");
  assert.equal(parseLead({ ...valid, telefono: "" }, now).status, 422);
  assert.equal(parseLead({ ...valid, telefono: "" }, now).field, "telefono");
});

test("phone errors are localized by lang", () => {
  const bad = { ...valid, telefono: "+55 123", pais: "BR" };
  assert.match(parseLead({ ...bad, lang: "es" }, now).error, /10 u 11 dígitos/);
  assert.match(parseLead({ ...bad, lang: "en" }, now).error, /Enter 10 or 11 digits for Brazil/);
  assert.match(parseLead({ ...bad, lang: "pt" }, now).error, /Digite 10 ou 11 dígitos para Brasil/);
  assert.match(parseLead({ ...valid, empresa: "", lang: "en" }, now).error, /Please fill in/);
  assert.equal(messages("xx").method, messages("es").method);
});

test("backward compatible: without pais, any 7-15 digit phone (or none) is accepted", () => {
  const { pais, lang, ...old } = valid;
  assert.equal(parseLead({ ...old, telefono: "55 1234 5678" }, now).ok, true);
  assert.equal(parseLead({ ...old, telefono: "" }, now).ok, true);
  assert.equal(parseLead({ ...old, telefono: "+1 (555) 123-4567" }, now).lead.phone, "+15551234567");
  assert.equal(parseLead({ ...old, telefono: "55 1234" }, now).status, 422);
  assert.equal(parseLead({ ...old, telefono: "1234567890123456" }, now).status, 422);
  assert.equal(parseLead({ ...old, telefono: "5512345678", pais: "XX" }, now).lead.country, "");
  assert.equal(parseLead(old, now).lead.lang, "es");
});

test("emails escape HTML and set reply-to to the lead; internal email includes the country", () => {
  const lead = parseLead({ ...valid, mensaje: "<b>hola</b>" }, now).lead;
  const mail = internalEmail(lead);
  assert.match(mail.subject, /Textiles Norte · MX/);
  assert.equal(mail.replyTo, "Laura Méndez <laura@example.com>");
  assert.ok(mail.html.includes("&lt;b&gt;hola&lt;/b&gt;"));
  assert.ok(!mail.html.includes("<b>hola</b>"));
  assert.match(mail.text, /País: México \(MX\)/);
  assert.match(mail.text, /Teléfono: \+52 5512345678/);
  assert.match(autoReplyEmail(lead).text, /Hola Laura:/);
});

test("the auto-reply follows the page language", () => {
  const en = autoReplyEmail(parseLead({ ...valid, lang: "en", pais: "US", telefono: "+1 2125550123", plan: "Empresa", plantas: "Más de 10" }, now).lead);
  assert.match(en.subject, /We received your request/);
  assert.match(en.text, /Hi Laura,/);
  assert.match(en.text, /Plan: Enterprise/);
  assert.match(en.text, /Plants: More than 10/);
  assert.match(en.text, /\/en\/index\.html/);
  const pt = autoReplyEmail(parseLead({ ...valid, lang: "pt", pais: "BR", telefono: "+55 11987654321", plan: "Aún no sé" }, now).lead);
  assert.match(pt.subject, /Recebemos a sua solicitação/);
  assert.match(pt.text, /Olá, Laura!/);
  assert.match(pt.text, /Plano de interesse: Ainda não sei/);
  assert.match(pt.text, /\/pt\/index\.html/);
  // The internal notification stays in Spanish.
  assert.match(internalEmail(parseLead({ ...valid, lang: "pt", pais: "BR", telefono: "+55 11987654321" }, now).lead).text, /Idioma del sitio: Portugués/);
});
