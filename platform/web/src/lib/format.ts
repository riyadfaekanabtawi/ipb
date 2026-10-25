// Spanish (Mexico) formatting, mirroring Fmt in ios/Trama/DesignSystem/Theme.swift.

const LOCALE = "es-MX";
const money = new Intl.NumberFormat(LOCALE, { style: "currency", currency: "MXN", maximumFractionDigits: 2, minimumFractionDigits: 0 });
const moneyCompact = new Intl.NumberFormat(LOCALE, { notation: "compact", maximumFractionDigits: 1 });
const int = new Intl.NumberFormat(LOCALE, { maximumFractionDigits: 0 });
const pct = new Intl.NumberFormat(LOCALE, { style: "percent", maximumFractionDigits: 0 });
const dateFmt = new Intl.DateTimeFormat(LOCALE, { day: "numeric", month: "short", year: "numeric" });
const shortDateFmt = new Intl.DateTimeFormat(LOCALE, { day: "numeric", month: "short" });
const monthYearFmt = new Intl.DateTimeFormat(LOCALE, { month: "long", year: "numeric" });
const dateTimeFmt = new Intl.DateTimeFormat(LOCALE, { day: "numeric", month: "short", hour: "2-digit", minute: "2-digit" });

export function fmtMoney(value: number, compact = false): string {
  if (!Number.isFinite(value)) return "—";
  if (compact && Math.abs(value) >= 10_000) return "$" + moneyCompact.format(value);
  return money.format(value);
}

export const fmtInt = (value: number) => (Number.isFinite(value) ? int.format(Math.round(value)) : "—");

export function fmtNumber(value: number | undefined | null, digits = 1): string {
  if (value == null || !Number.isFinite(value)) return "—";
  return new Intl.NumberFormat(LOCALE, { maximumFractionDigits: digits }).format(value);
}

export const fmtPercent = (value: number) => (Number.isFinite(value) ? pct.format(value) : "—");

const toDate = (d: Date | string | null | undefined) => (d == null ? null : typeof d === "string" ? new Date(d) : d);

export function fmtDate(d: Date | string | null | undefined): string {
  const date = toDate(d);
  return date && !Number.isNaN(date.getTime()) ? dateFmt.format(date) : "—";
}

export function fmtShortDate(d: Date | string | null | undefined): string {
  const date = toDate(d);
  return date && !Number.isNaN(date.getTime()) ? shortDateFmt.format(date) : "—";
}

export function fmtDateTime(d: Date | string | null | undefined): string {
  const date = toDate(d);
  return date && !Number.isNaN(date.getTime()) ? dateTimeFmt.format(date) : "—";
}

export const fmtMonthYear = (d: Date) => {
  const s = monthYearFmt.format(d);
  return s.charAt(0).toUpperCase() + s.slice(1);
};

export function fmtRelativeDays(days: number | null): string {
  if (days == null) return "Sin fecha";
  if (days < -1) return `Vencido hace ${-days} días`;
  if (days === -1) return "Venció ayer";
  if (days === 0) return "Vence hoy";
  if (days === 1) return "Vence mañana";
  return `En ${days} días`;
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
  if (!d || Number.isNaN(d.getTime())) return "";
  const p = (n: number) => String(n).padStart(2, "0");
  return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}`;
}

export const parseDate = (iso: string | null | undefined): Date | null => {
  const d = toDate(iso);
  return d && !Number.isNaN(d.getTime()) ? d : null;
};

/** Parses user-typed numbers ("1,250.5", "1250"). Empty or invalid → NaN. */
export function parseNumber(raw: string): number {
  const cleaned = raw.replace(/[,\s$]/g, "");
  if (!cleaned) return Number.NaN;
  return Number(cleaned);
}

export function fullName(u: { firstName?: string | null; lastName?: string | null; email?: string | null }): string {
  const name = `${u.firstName ?? ""} ${u.lastName ?? ""}`.trim();
  return name || u.email || "Usuario";
}

export function initials(name: string): string {
  const letters = name.split(/\s+/).filter(Boolean).slice(0, 2).map((p) => p[0]).join("");
  return letters ? letters.toUpperCase() : "?";
}
