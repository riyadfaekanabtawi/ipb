import { afterEach, describe, expect, it } from "vitest";
import { fmtDate, fmtInt, fmtMoney, fmtMonthYear, fmtPercent, fmtRelativeDays, monthNames, weekdayNames } from "../lib/format";
import { cutStatusTitle, roleTitle, sectionTitle } from "../domain/enums";
import { assignmentErrorMessage } from "../domain/rules";
import { detectLang, DICTIONARIES, LANGS, matchLang, setLang, t, translate, type Lang } from ".";
import type { Message } from "./es";

const placeholders = (m: Message) => {
  const texts = typeof m === "string" ? [m] : [m.one, m.other, ...(m.zero ? [m.zero] : [])];
  return [...new Set(texts.flatMap((s) => [...s.matchAll(/\{(\w+)\}/g)].map((x) => x[1])))].sort();
};

afterEach(() => setLang("es", { persist: false }));

describe("dictionaries", () => {
  it("have exactly the same keys in es, en and pt", () => {
    const keys = Object.keys(DICTIONARIES.es).sort();
    for (const lang of LANGS) expect(Object.keys(DICTIONARIES[lang]).sort()).toEqual(keys);
  });

  it("use the same placeholders and plural shape in every language, with no empty strings", () => {
    for (const [key, source] of Object.entries(DICTIONARIES.es)) {
      for (const lang of LANGS) {
        const m = DICTIONARIES[lang][key as keyof typeof DICTIONARIES.es];
        expect(typeof m, `${lang}:${key}`).toBe(typeof source);
        expect(placeholders(m), `${lang}:${key}`).toEqual(placeholders(source));
        const texts = typeof m === "string" ? [m] : [m.one, m.other];
        for (const text of texts) expect(text.trim().length, `${lang}:${key}`).toBeGreaterThan(0);
      }
    }
  });
});

describe("t()", () => {
  it("interpolates, pluralizes and formats numbers per locale", () => {
    expect(translate("es", "common.garments", { count: 1 })).toBe("1 prenda");
    expect(translate("es", "common.garments", { count: 1250 })).toBe("1,250 prendas");
    expect(translate("en", "common.garments", { count: 1 })).toBe("1 garment");
    expect(translate("en", "common.garments", { count: 2 })).toBe("2 garments");
    expect(translate("pt", "common.garments", { count: 1250 })).toBe("1.250 peças");
    expect(translate("pt", "assign.done", { count: 3, plant: "Norte" })).toBe("Você alocou 3 peças em Norte");
    expect(translate("en", "orders.updated", { code: "C-12" })).toBe("Cut C-12 updated");
  });

  it("follows the current language, including enum labels and domain messages", () => {
    setLang("en", { persist: false });
    expect(t("section.orders")).toBe("Cuts to assign");
    expect(roleTitle("Gerente de Cortes")).toBe("Cutting Manager");
    expect(cutStatusTitle("listo_para_confeccionar")).toBe("Ready to sew");
    expect(assignmentErrorMessage({ code: "missingDate" })).toBe("Pick a date on the calendar.");
    setLang("pt", { persist: false });
    expect(sectionTitle("shipments")).toBe("Expedições urgentes");
    expect(roleTitle("Gerente de Planta")).toBe("Gerente de Unidade");
    expect(t("section.settings")).toBe("Configurações");
  });
});

describe("language detection", () => {
  it("prefers ?lang=, then the saved choice, then the browser, then Spanish", () => {
    expect(detectLang({ search: "?lang=en", stored: "pt", browser: ["es-MX"] })).toBe("en");
    expect(detectLang({ search: "?lang=xx", stored: "pt", browser: ["en-US"] })).toBe("pt");
    expect(detectLang({ stored: null, browser: ["fr-FR", "pt-BR", "en"] })).toBe("pt");
    expect(detectLang({ browser: ["de-DE"] })).toBe("es");
    expect(detectLang({})).toBe("es");
    expect(matchLang("EN_us")).toBe("en");
  });
});

describe("formatting per locale", () => {
  const date = new Date(2026, 2, 5, 12); // 5 March 2026
  const inLang = <T,>(lang: Lang, fn: () => T) => {
    setLang(lang, { persist: false });
    return fn();
  };

  it("formats MXN amounts in every locale", () => {
    expect(inLang("es", () => fmtMoney(1250.5))).toBe("$1,250.5");
    expect(inLang("en", () => fmtMoney(1250.5))).toBe("MX$1,250.5");
    expect(inLang("pt", () => fmtMoney(1250.5)).replace(/\s/g, " ")).toBe("MX$ 1.250,5");
    expect(inLang("es", () => fmtMoney(1_300_000, true)).replace(/\s/g, " ")).toBe("$1.3 M");
    expect(inLang("en", () => fmtMoney(1_300_000, true))).toBe("MX$1.3M");
  });

  it("formats numbers, percentages, dates and month names", () => {
    expect(inLang("pt", () => fmtInt(1234567))).toBe("1.234.567");
    expect(inLang("en", () => fmtInt(1234567))).toBe("1,234,567");
    expect(inLang("en", () => fmtPercent(0.42))).toBe("42%");
    expect(inLang("en", () => fmtDate(date))).toBe("Mar 5, 2026");
    expect(inLang("es", () => fmtDate(date))).toBe("5 mar 2026");
    expect(inLang("pt", () => fmtMonthYear(date))).toBe("Março de 2026");
    expect(inLang("en", () => monthNames())[0]).toBe("Jan");
    expect(inLang("es", () => monthNames())[0]).toBe("Ene");
    expect(inLang("en", () => weekdayNames())).toEqual(["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]);
    expect(inLang("pt", () => weekdayNames())[0]).toBe("Seg");
  });

  it("describes relative due dates", () => {
    expect(inLang("en", () => fmtRelativeDays(-3))).toBe("Overdue by 3 days");
    expect(inLang("pt", () => fmtRelativeDays(1))).toBe("Vence amanhã");
    expect(inLang("es", () => fmtRelativeDays(5))).toBe("En 5 días");
  });
});
