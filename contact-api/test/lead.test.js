import assert from "node:assert/strict";
import { test } from "node:test";
import { autoReplyEmail, internalEmail, LIMITS, MIN_FILL_MS, parseLead } from "../lib/lead.js";

const now = 1_800_000_000_000;
const valid = { nombre: "Laura Méndez", empresa: "Textiles Norte", correo: "Laura@Example.com", telefono: "55 1234", plantas: "2–3", plan: "Multiplanta", mensaje: "Hola", startedAt: now - 10_000 };

test("accepts a valid lead and normalizes the email", () => {
  const r = parseLead(valid, now);
  assert.equal(r.ok, true);
  assert.equal(r.lead.email, "laura@example.com");
  assert.equal(r.lead.plants, "2–3");
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

test("emails escape HTML and set reply-to to the lead", () => {
  const lead = parseLead({ ...valid, mensaje: "<b>hola</b>" }, now).lead;
  const mail = internalEmail(lead);
  assert.match(mail.subject, /Textiles Norte/);
  assert.equal(mail.replyTo, "Laura Méndez <laura@example.com>");
  assert.ok(mail.html.includes("&lt;b&gt;hola&lt;/b&gt;"));
  assert.ok(!mail.html.includes("<b>hola</b>"));
  assert.match(autoReplyEmail(lead).text, /Hola Laura:/);
});
