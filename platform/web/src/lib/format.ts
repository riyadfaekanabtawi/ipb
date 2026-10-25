// Locale-aware formatting (dates, numbers, percentages) for the current language, mirroring Fmt in
// ios/Trama/DesignSystem/Theme.swift. Amounts are always MXN; only their presentation follows the
// locale (es-MX "$1,250", en-US "MX$1,250", pt-BR "MX$ 1.250").

import { getLang, LOCALE, t, type Lang } from "../i18n";

interface Formatters {
  money: Intl.NumberFormat;
  moneyCompact: Intl.NumberFormat;
  int: Intl.NumberFormat;
  pct: Intl.NumberFormat;
  date: Intl.DateTimeFormat;
  shortDate: Intl.DateTimeFormat;
  monthYear: Intl.DateTimeFormat;
  dateTime: Intl.DateTimeFormat;
  monthShort: Intl.DateTimeFormat;
  weekdayShort: Intl.DateTimeFormat;
  dayLong: Intl.DateTimeFormat;
  dayFull: Intl.DateTimeFormat;
}

const cache = new Map<Lang, Formatters>();

/** Cached Intl formatters for a language (the current one by default). */
export function formatters(lang: Lang = getLang()): Formatters {
  let f = cache.get(lang);
  if (!f) {
    const locale = LOCALE[lang];
    f = {
      money: new Intl.NumberFormat(locale, { style: "currency", currency: "MXN", maximumFractionDigits: 2, minimumFractionDigits: 0 }),
      moneyCompact: new Intl.NumberFormat(locale, { style: "currency", currency: "MXN", notation: "compact", maximumFractionDigits: 1, minimumFractionDigits: 0 }),
      int: new Intl.NumberFormat(locale, { maximumFractionDigits: 0 }),
      pct: new Intl.NumberFormat(locale, { style: "percent", maximumFractionDigits: 0 }),
      date: new Intl.DateTimeFormat(locale, { day: "numeric", month: "short", year: "numeric" }),
      shortDate: new Intl.DateTimeFormat(locale, { day: "numeric", month: "short" }),
      monthYear: new Intl.DateTimeFormat(locale, { month: "long", year: "numeric" }),
      dateTime: new Intl.DateTimeFormat(locale, { day: "numeric", month: "short", hour: "2-digit", minute: "2-digit" }),
      monthShort: new Intl.DateTimeFormat(locale, { month: "short" }),
      weekdayShort: new Intl.DateTimeFormat(locale, { weekday: "short" }),
      dayLong: new Intl.DateTimeFormat(locale, { weekday: "long", day: "numeric", month: "long" }),
      dayFull: new Intl.DateTimeFormat(locale, { dateStyle: "full" }),
    };
    cache.set(lang, f);
  }
  return f;
}

const capitalize = (s: string) => s.charAt(0).toLocaleUpperCase(LOCALE[getLang()]) + s.slice(1);

export function fmtMoney(value: number, compact = false): string {
  if (!Number.isFinite(value)) return "—";
  const f = formatters();
  return compact && Math.abs(value) >= 10_000 ? f.moneyCompact.format(value) : f.money.format(value);
}

export const fmtInt = (value: number) => (Number.isFinite(value) ? formatters().int.format(Math.round(value)) : "—");

export function fmtNumber(value: number | undefined | null, digits = 1): string {
  if (value == null || !Number.isFinite(value)) return "—";
  return new Intl.NumberFormat(LOCALE[getLang()], { maximumFractionDigits: digits }).format(value);
}

export const fmtPercent = (value: number) => (Number.isFinite(value) ? formatters().pct.format(value) : "—");

const toDate = (d: Date | string | null | undefined) => (d == null ? null : typeof d === "string" ? new Date(d) : d);
const valid = (d: Date | null): d is Date => !!d && !Number.isNaN(d.getTime());

export function fmtDate(d: Date | string | null | undefined): string {
  const date = toDate(d);
  return valid(date) ? formatters().date.format(date) : "—";
}

export function fmtShortDate(d: Date | string | null | undefined): string {
  const date = toDate(d);
  return valid(date) ? formatters().shortDate.format(date) : "—";
}

export function fmtDateTime(d: Date | string | null | undefined): string {
  const date = toDate(d);
  return valid(date) ? formatters().dateTime.format(date) : "—";
}

export const fmtMonthYear = (d: Date) => capitalize(formatters().monthYear.format(d));

/** "Monday, 3 March" style heading for a calendar day. */
export const fmtDayLong = (d: Date) => capitalize(formatters().dayLong.format(d));

/** Full date for screen readers. */
export const fmtDayFull = (d: Date) => formatters().dayFull.format(d);

/** Short month names Jan…Dec (capitalized, no trailing period). */
export function monthNames(): string[] {
  const f = formatters().monthShort;
  return Array.from({ length: 12 }, (_, m) => capitalize(f.format(new Date(2024, m, 1)).replace(/\.$/, "")));
}

/** Short weekday names starting on Monday (capitalized, no trailing period). */
export function weekdayNames(): string[] {
  const f = formatters().weekdayShort;
  // 2024-01-01 was a Monday.
  return Array.from({ length: 7 }, (_, i) => capitalize(f.format(new Date(2024, 0, 1 + i)).replace(/\.$/, "")));
}

export function fmtRelativeDays(days: number | null): string {
  if (days == null) return t("fmt.noDate");
  if (days < -1) return t("fmt.overdue", { count: -days });
  if (days === -1) return t("fmt.dueYesterday");
  if (days === 0) return t("fmt.dueToday");
  if (days === 1) return t("fmt.dueTomorrow");
  return t("fmt.inDays", { count: days });
}

// Date-only fields ----------------------------------------------------------------------
// The apps store calendar dates as full timestamps. The web stores them at local noon so the
// calendar day and month survive small time-zone differences between devices.

export function isoFromDateInput(value: string): string | null {
  const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(value);
  if (!m) return null;
  return new Date(Number(m[1]), Number(m[2]) - 1, Number(m[3]), 12, 0, 0).toISOString();
}

export function dateInputFromIso(iso: string | null | undefined): string {
  const d = toDate(iso);
  if (!valid(d)) return "";
  const p = (n: number) => String(n).padStart(2, "0");
  return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}`;
}

export const parseDate = (iso: string | null | undefined): Date | null => {
  const d = toDate(iso);
  return valid(d) ? d : null;
};

/** Parses user-typed numbers ("1,250.5", "1250"). Empty or invalid → NaN. */
export function parseNumber(raw: string): number {
  const cleaned = raw.replace(/[,\s$]/g, "");
  if (!cleaned) return Number.NaN;
  return Number(cleaned);
}

export function fullName(u: { firstName?: string | null; lastName?: string | null; email?: string | null }): string {
  const name = `${u.firstName ?? ""} ${u.lastName ?? ""}`.trim();
  return name || u.email || t("common.userFallback");
}

export function initials(name: string): string {
  const letters = name.split(/\s+/).filter(Boolean).slice(0, 2).map((p) => p[0]).join("");
  return letters ? letters.toUpperCase() : "?";
}
