// Trama landing: loom animation, mobile menu, screenshot tabs, reveal-on-scroll, pricing toggle,
// language suggestion and the licence request form. All visible strings come from the per-page
// dictionary `window.TRAMA_I18N`, injected by web/build.py (sources in web/src/i18n/*.json).
const I18N = window.TRAMA_I18N || { lang: "es", tabs: {}, phone: {}, t: {}, suggest: {} };
const T = I18N.t;
// Only used to prefill an email when the contact API is unreachable; never shown on the page.
const CONTACT_EMAIL = "riyad.faek@gmail.com";

const reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
const fmt = (text, vars) => String(text || "").replace(/\{(\w+)\}/g, (_, k) => (k in vars ? vars[k] : `{${k}}`));
const escapeHtml = (s) => String(s).replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[c]);
const store = {
  get(key) { try { return localStorage.getItem(key); } catch { return null; } },
  set(key, value) { try { localStorage.setItem(key, value); } catch { /* private mode */ } },
};

// Animated "loom": flowing warp threads behind the hero, like the iPad app's login screen.
(function loom() {
  const canvas = document.querySelector(".hero__loom");
  if (!canvas) return;
  const ctx = canvas.getContext("2d");
  const colors = ["#F4C430", "#FFFFFF", "#3FA7BD"];
  let w = 0, h = 0, dpr = 1, raf = 0, visible = true;

  function resize() {
    dpr = Math.min(window.devicePixelRatio || 1, 2);
    w = canvas.clientWidth; h = canvas.clientHeight;
    canvas.width = w * dpr; canvas.height = h * dpr;
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
  }

  function draw(time) {
    const t = time * 0.00018;
    ctx.clearRect(0, 0, w, h);
    const count = 22;
    for (let i = 0; i < count; i++) {
      const p = i / count;
      const baseY = h * (0.06 + 0.88 * p);
      const amp = h * (0.025 + 0.05 * Math.sin(p * Math.PI));
      const freq = 1.3 + 0.9 * Math.sin(i * 1.7);
      const phase = t * (0.6 + p) * 6 + i;
      ctx.beginPath();
      for (let s = 0; s <= 60; s++) {
        const u = s / 60;
        const y = baseY + amp * Math.sin(u * Math.PI * 2 * freq + phase) + amp * 0.35 * Math.sin(u * Math.PI * 7 + phase * 1.3);
        s === 0 ? ctx.moveTo(w * u, y) : ctx.lineTo(w * u, y);
      }
      ctx.strokeStyle = colors[i % colors.length];
      ctx.globalAlpha = 0.08 + 0.18 * (0.5 + 0.5 * Math.sin(phase * 0.7));
      ctx.lineWidth = i % 5 === 0 ? 2.2 : 1;
      ctx.stroke();
    }
    ctx.globalAlpha = 1;
    if (!reduceMotion && visible) raf = requestAnimationFrame(draw);
  }

  resize();
  window.addEventListener("resize", () => { resize(); if (reduceMotion) draw(0); });
  new IntersectionObserver(([entry]) => {
    visible = entry.isIntersecting;
    cancelAnimationFrame(raf);
    if (visible) raf = requestAnimationFrame(draw);
  }).observe(canvas);
  draw(0);
})();

// Mobile menu.
(function menu() {
  const button = document.querySelector(".nav__menu");
  const panel = document.getElementById("mobile-menu");
  if (!button || !panel) return;
  const set = (open) => { button.setAttribute("aria-expanded", String(open)); panel.hidden = !open; };
  button.addEventListener("click", () => set(panel.hidden));
  panel.addEventListener("click", (e) => { if (e.target.closest("a")) set(false); });
  document.addEventListener("keydown", (e) => { if (e.key === "Escape" && !panel.hidden) { set(false); button.focus(); } });
})();

// Screenshot tabs (roving tabindex, arrow keys move between tabs).
(function tabs() {
  const tabs = [...document.querySelectorAll(".tabs [role=tab]")];
  const panel = document.getElementById("shot");
  const img = panel?.querySelector("img");
  if (!img) return;
  function select(tab) {
    tabs.forEach((t) => { const on = t === tab; t.setAttribute("aria-selected", String(on)); t.tabIndex = on ? 0 : -1; });
    panel.setAttribute("aria-labelledby", tab.id);
    const key = tab.dataset.shot;
    img.classList.add("is-swapping");
    setTimeout(() => {
      img.onload = () => img.classList.remove("is-swapping");
      img.src = img.src.replace(/[^/]+\.webp$/, `${key}.webp`);
      img.alt = tab.dataset.alt || I18N.tabs[key] || I18N.defaultAlt || "";
    }, reduceMotion ? 0 : 180);
  }
  tabs.forEach((tab, i) => {
    tab.addEventListener("click", () => select(tab));
    tab.addEventListener("keydown", (e) => {
      const step = { ArrowRight: 1, ArrowLeft: -1, Home: -i, End: tabs.length - 1 - i }[e.key];
      if (step === undefined) return;
      e.preventDefault();
      const next = tabs[(i + step + tabs.length) % tabs.length];
      next.focus();
      select(next);
    });
  });
})();

// Reveal on scroll.
(function reveal() {
  const items = document.querySelectorAll(".section__head, .feature, .role, .steps li, .plan, details, .offline__list li, .compare__table-wrap, .compare__card, .compare__motto");
  if (reduceMotion || !("IntersectionObserver" in window)) return;
  items.forEach((el) => el.classList.add("reveal"));
  const io = new IntersectionObserver((entries) => {
    entries.forEach((entry) => {
      if (entry.isIntersecting) { entry.target.classList.add("is-visible"); io.unobserve(entry.target); }
    });
  }, { rootMargin: "0px 0px -8% 0px" });
  items.forEach((el) => io.observe(el));
})();

// Monthly / yearly pricing toggle. Both prices are in the HTML; CSS shows the active one.
(function billing() {
  const section = document.getElementById("precios");
  const group = section?.querySelector(".billing");
  if (!group) return;
  group.hidden = false;
  group.querySelectorAll("button").forEach((button) => button.addEventListener("click", () => {
    section.dataset.billing = button.dataset.billing;
    group.querySelectorAll("button").forEach((b) => b.setAttribute("aria-pressed", String(b === button)));
  }));
})();

// Plan buttons preselect the plan in the form.
document.querySelectorAll("[data-plan]").forEach((link) => {
  link.addEventListener("click", () => {
    const select = document.querySelector("#lead-form select[name=plan]");
    if (select) select.value = link.dataset.plan;
  });
});

// Language switcher keeps the current section; a manual choice silences the suggestion banner.
document.querySelectorAll(".langs a, .footer__langs a").forEach((link) => {
  link.addEventListener("click", () => {
    store.set("trama-lang", link.getAttribute("hreflang").slice(0, 2));
    if (location.hash && !link.hash) link.href = link.href.split("#")[0] + location.hash;
  });
});

// Unobtrusive "also available in your language" banner. Never redirects (crawlers must reach every URL).
(function suggest() {
  const box = document.getElementById("lang-suggest");
  if (!box || store.get("trama-lang")) return;
  const preferred = (navigator.languages || [navigator.language || ""]).map((l) => l.slice(0, 2).toLowerCase());
  const code = preferred.find((l) => l === I18N.lang || I18N.suggest[l]);
  const offer = code && code !== I18N.lang ? I18N.suggest[code] : null;
  if (!offer) return;
  box.innerHTML = `<div class="wrap suggest__inner" lang="${escapeHtml(code)}"><p>${escapeHtml(offer.text)}</p>
    <a class="btn btn--small" href="${escapeHtml(offer.href)}" hreflang="${escapeHtml(code)}">${escapeHtml(offer.cta)}</a>
    <button type="button" class="suggest__close" aria-label="${escapeHtml(offer.close)}">×</button></div>`;
  box.hidden = false;
  box.querySelector("a").addEventListener("click", () => store.set("trama-lang", code));
  box.querySelector("button").addEventListener("click", () => { store.set("trama-lang", I18N.lang); box.hidden = true; });
})();

// Licence request form: POSTs to the contact API (Gmail SMTP on Vercel) and shows the result
// inline. Falls back to a prefilled email only when no endpoint is configured or it is down.
(function form() {
  const form = document.getElementById("lead-form");
  if (!form) return;
  const hint = form.querySelector(".form__hint");
  const button = form.querySelector("button[type=submit]");
  const country = form.querySelector("select[name=pais]");
  const national = form.querySelector("input[name=telefono_nacional]");
  const phoneError = document.getElementById("tel-error");
  const endpoint = document.querySelector('meta[name="trama-contact-endpoint"]')?.content.trim();
  const startedAt = Date.now();

  // Phone rules come from web/src/site.json ("countries"); the API keeps the same table in
  // contact-api/lib/lead.js (PHONE_RULES).
  const rule = () => I18N.phone[country.value];
  const digitsOf = (value) => {
    let digits = value.replace(/\D/g, "");
    const r = rule();
    if (r && value.trim().startsWith("+") && digits.startsWith(r.dial)) digits = digits.slice(r.dial.length);
    return digits;
  };
  function phoneMessage() {
    const r = rule();
    if (!r) return T.required;
    const last = r.lengths[r.lengths.length - 1];
    const or = (T.or_alt && T.or_alt[last]) || T.or;
    const digits = r.lengths.length > 1 ? `${r.lengths.slice(0, -1).join(", ")} ${or} ${last}` : String(last);
    return fmt(T.phone, { digits, country: r.name });
  }
  function checkPhone(show) {
    const r = rule();
    const n = digitsOf(national.value).length;
    const ok = r ? r.lengths.includes(n) : n >= 7 && n <= 15;
    national.setAttribute("aria-invalid", String(!ok));
    phoneError.textContent = ok || !show ? "" : phoneMessage();
    return ok;
  }
  national.addEventListener("input", () => {
    const digits = digitsOf(national.value);
    if (digits !== national.value) national.value = digits;
    if (national.getAttribute("aria-invalid") === "true") checkPhone(true);
  });
  national.addEventListener("blur", () => { if (national.value) checkPhone(true); });
  country.addEventListener("change", () => { if (national.value) checkPhone(true); });

  function validate() {
    let firstInvalid = null;
    form.querySelectorAll("[required]").forEach((field) => {
      if (field === national) return;
      const value = field.value.trim();
      const valid = value !== "" && (field.type !== "email" || /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value));
      field.setAttribute("aria-invalid", String(!valid));
      if (!valid && !firstInvalid) firstInvalid = field;
    });
    if (!checkPhone(true) && !firstInvalid) firstInvalid = national;
    return firstInvalid;
  }

  function payload() {
    const data = Object.fromEntries(new FormData(form));
    const r = rule();
    delete data.telefono_nacional;
    return { ...data, telefono: r ? `+${r.dial} ${digitsOf(national.value)}` : digitsOf(national.value), pais: country.value, lang: I18N.lang };
  }

  function mailtoFallback(data) {
    const L = T.mail_labels || {};
    const countryName = I18N.phone[data.pais]?.name || data.pais;
    const subject = fmt(T.mail_subject, { company: data.empresa });
    const body = [`${L.name}: ${data.nombre}`, `${L.company}: ${data.empresa}`, `${L.email}: ${data.correo}`,
      `${L.phone}: ${data.telefono || "—"}`, `${L.country}: ${countryName}`, `${L.plants}: ${data.plantas}`,
      `${L.plan}: ${data.plan}`, "", data.mensaje || ""].join("\n");
    window.location.href = `mailto:${CONTACT_EMAIL}?subject=${encodeURIComponent(subject)}&body=${encodeURIComponent(body)}`;
  }

  function showSent(name) {
    form.innerHTML = `<div class="form__done" role="status" tabindex="-1">
      <svg class="ico" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M20 6 9 17l-5-5"/></svg>
      <h3>${escapeHtml(fmt(T.sent_title, { name }))}</h3>
      <p>${escapeHtml(T.sent_body)}</p></div>`;
    form.querySelector(".form__done").focus();
  }

  form.addEventListener("submit", async (event) => {
    event.preventDefault();
    const invalid = validate();
    if (invalid) {
      hint.textContent = invalid === national ? phoneMessage() : T.required;
      invalid.focus();
      return;
    }
    const data = payload();
    if (!endpoint) return mailtoFallback(data);

    button.disabled = true;
    button.textContent = T.sending;
    hint.textContent = "";
    try {
      const response = await fetch(endpoint, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ ...data, startedAt }),
      });
      const result = await response.json().catch(() => ({}));
      if (response.ok) return showSent(data.nombre.split(" ")[0]);
      hint.textContent = result.error || T.generic_error;
      if (result.field === "telefono") { phoneError.textContent = result.error; national.setAttribute("aria-invalid", "true"); national.focus(); }
    } catch {
      hint.innerHTML = `${escapeHtml(T.network_error)} <a href="#" id="mail-fallback">${escapeHtml(T.network_link)}</a>.`;
      document.getElementById("mail-fallback").addEventListener("click", (e) => { e.preventDefault(); mailtoFallback(data); });
    }
    button.disabled = false;
    button.textContent = T.submit;
  });
})();

document.getElementById("year").textContent = new Date().getFullYear();
