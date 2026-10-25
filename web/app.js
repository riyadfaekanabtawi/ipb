// Trama landing: loom animation, mobile menu, screenshot tabs, reveal-on-scroll and the
// licence request form (opens the visitor's mail app; the site is static, no backend).
const CONTACT_EMAIL = "riyad.faek@gmail.com";

const reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

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
})();

// Screenshot tabs.
(function tabs() {
  const tabs = document.querySelectorAll(".tabs [role=tab]");
  const img = document.querySelector("#shot img");
  if (!img) return;
  const alts = {
    dash: "Dashboard con KPIs, capacidad de plantas y estado de la mesa de corte",
    board: "Tablero de corte tipo kanban por estado",
    detail: "Detalle de producción de un corte con su embudo y reportes",
    cal: "Calendario de plantas con producción, entregas y capacidad",
    detaildark: "Detalle de producción en modo oscuro",
  };
  tabs.forEach((tab) => tab.addEventListener("click", () => {
    tabs.forEach((t) => t.setAttribute("aria-selected", String(t === tab)));
    const key = tab.dataset.shot;
    img.classList.add("is-swapping");
    setTimeout(() => {
      img.src = `assets/shots/${key}.webp`;
      img.alt = alts[key] || "Pantalla de Trama";
      img.onload = () => img.classList.remove("is-swapping");
    }, reduceMotion ? 0 : 180);
  }));
})();

// Reveal on scroll.
(function reveal() {
  const items = document.querySelectorAll(".section__head, .feature, .role, .steps li, .plan, details, .offline__list li");
  if (reduceMotion || !("IntersectionObserver" in window)) return;
  items.forEach((el) => el.classList.add("reveal"));
  const io = new IntersectionObserver((entries) => {
    entries.forEach((entry) => {
      if (entry.isIntersecting) { entry.target.classList.add("is-visible"); io.unobserve(entry.target); }
    });
  }, { rootMargin: "0px 0px -8% 0px" });
  items.forEach((el) => io.observe(el));
})();

// "Cotizar" buttons preselect the plan in the form.
document.querySelectorAll("[data-plan]").forEach((link) => {
  link.addEventListener("click", () => {
    const select = document.querySelector("#lead-form select[name=plan]");
    if (select) select.value = link.dataset.plan;
  });
});

// Licence request form → prefilled email.
(function form() {
  const form = document.getElementById("lead-form");
  if (!form) return;
  const hint = form.querySelector(".form__hint");
  form.addEventListener("submit", (event) => {
    event.preventDefault();
    let firstInvalid = null;
    form.querySelectorAll("[required]").forEach((field) => {
      const valid = field.value.trim() !== "" && (field.type !== "email" || /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(field.value.trim()));
      field.setAttribute("aria-invalid", String(!valid));
      if (!valid && !firstInvalid) firstInvalid = field;
    });
    if (firstInvalid) {
      hint.textContent = "Completa nombre, empresa y un correo válido.";
      firstInvalid.focus();
      return;
    }
    const data = Object.fromEntries(new FormData(form));
    const subject = `Trama · Solicitud de licencia · ${data.empresa}`;
    const body = [
      `Nombre: ${data.nombre}`,
      `Empresa: ${data.empresa}`,
      `Correo: ${data.correo}`,
      `Teléfono: ${data.telefono || "—"}`,
      `Plantas: ${data.plantas}`,
      `Plan de interés: ${data.plan}`,
      "",
      data.mensaje || "",
    ].join("\n");
    window.location.href = `mailto:${CONTACT_EMAIL}?subject=${encodeURIComponent(subject)}&body=${encodeURIComponent(body)}`;
    hint.textContent = "¡Gracias! Abrimos tu app de correo con la solicitud lista para enviar.";
  });
})();

document.getElementById("year").textContent = new Date().getFullYear();
