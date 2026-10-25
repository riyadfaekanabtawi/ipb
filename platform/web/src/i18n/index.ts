// Lightweight i18n for the customer web app: typed dictionaries (es is the source of keys; en
// and pt must define exactly the same ones), `t()` with {placeholders} and plural forms chosen
// by Intl.PluralRules, and the current language (?lang= → saved choice → browser → es).
// The admin portal (/admin) is internal and always renders in Spanish.

import { useSyncExternalStore } from "react";
import { en } from "./en";
import { es, type Message, type MessageKey, type Messages } from "./es";
import { pt } from "./pt";

export type { MessageKey } from "./es";

export const LANGS = ["es", "en", "pt"] as const;
export type Lang = (typeof LANGS)[number];
export const DEFAULT_LANG: Lang = "es";

/** Locale for Intl formatting (and `<html lang>`). Amounts stay in MXN in every language. */
export const LOCALE: Record<Lang, string> = { es: "es-MX", en: "en-US", pt: "pt-BR" };
/** Each language named in itself, for the switcher. */
export const LANG_NAME: Record<Lang, string> = { es: "Español", en: "English", pt: "Português" };

export const DICTIONARIES: Record<Lang, Messages> = { es, en, pt };

const STORAGE_KEY = "trama.lang";

export const isLang = (value: unknown): value is Lang => typeof value === "string" && (LANGS as readonly string[]).includes(value);

/** Maps "pt-BR", "en_US", "ES" … to a supported language, or null. */
export function matchLang(tag: string | null | undefined): Lang | null {
  const base = (tag ?? "").trim().toLowerCase().split(/[-_]/)[0];
  return isLang(base) ? base : null;
}

/** Resolution order: ?lang= → saved choice → browser languages → Spanish. */
export function detectLang(input: { search?: string; stored?: string | null; browser?: readonly string[] }): Lang {
  const fromQuery = matchLang(new URLSearchParams(input.search ?? "").get("lang"));
  if (fromQuery) return fromQuery;
  const fromStorage = matchLang(input.stored);
  if (fromStorage) return fromStorage;
  for (const tag of input.browser ?? []) {
    const lang = matchLang(tag);
    if (lang) return lang;
  }
  return DEFAULT_LANG;
}

function readStored(): string | null {
  try {
    return localStorage.getItem(STORAGE_KEY);
  } catch {
    return null;
  }
}

function initialLang(): Lang {
  if (typeof window === "undefined") return DEFAULT_LANG;
  if (window.location.pathname.startsWith("/admin")) return "es";
  const lang = detectLang({ search: window.location.search, stored: readStored(), browser: navigator.languages?.length ? navigator.languages : [navigator.language] });
  // A ?lang= link (from the EN/PT landing) becomes the saved choice.
  if (matchLang(new URLSearchParams(window.location.search).get("lang"))) persist(lang);
  return lang;
}

function persist(lang: Lang) {
  try {
    localStorage.setItem(STORAGE_KEY, lang);
  } catch {
    /* storage unavailable: the choice lasts for this page load */
  }
}

let current: Lang = DEFAULT_LANG;
const listeners = new Set<() => void>();

function applyDocumentLang() {
  if (typeof document !== "undefined") document.documentElement.lang = LOCALE[current];
}

/** Call once at startup, before the first render. */
export function initI18n() {
  current = initialLang();
  applyDocumentLang();
}

export const getLang = (): Lang => current;
export const getLocale = (): string => LOCALE[current];

export function setLang(lang: Lang, options: { persist?: boolean } = {}) {
  if (options.persist !== false) persist(lang);
  if (lang === current) return;
  current = lang;
  applyDocumentLang();
  listeners.forEach((fn) => fn());
}

/** Current language; re-renders the caller when it changes. */
export function useLang(): Lang {
  return useSyncExternalStore(
    (fn) => {
      listeners.add(fn);
      return () => listeners.delete(fn);
    },
    getLang,
    getLang,
  );
}

export type Params = Record<string, string | number | null | undefined>;

const pluralRules = new Map<string, Intl.PluralRules>();
const numberFormats = new Map<string, Intl.NumberFormat>();

function pick(message: Message, lang: Lang, count: unknown): string {
  if (typeof message === "string") return message;
  const n = typeof count === "number" ? count : Number(count ?? 0);
  if (n === 0 && message.zero) return message.zero;
  const locale = LOCALE[lang];
  if (!pluralRules.has(locale)) pluralRules.set(locale, new Intl.PluralRules(locale));
  return pluralRules.get(locale)!.select(n) === "one" ? message.one : message.other;
}

/** Translates `key` in `lang`. Numbers in params are formatted for the locale. */
export function translate(lang: Lang, key: MessageKey, params: Params = {}): string {
  const message = DICTIONARIES[lang][key] ?? es[key];
  const locale = LOCALE[lang];
  if (!numberFormats.has(locale)) numberFormats.set(locale, new Intl.NumberFormat(locale, { maximumFractionDigits: 2 }));
  return pick(message, lang, params.count).replace(/\{(\w+)\}/g, (match, name: string) => {
    if (!(name in params)) return match;
    const value = params[name];
    return typeof value === "number" ? numberFormats.get(locale)!.format(value) : String(value ?? "");
  });
}

/** Translates `key` in the current language. */
export const t = (key: MessageKey, params?: Params): string => translate(current, key, params);
