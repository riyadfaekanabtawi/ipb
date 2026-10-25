// Pure business rules (docs/DOMAIN.md), ported 1:1 from ios/Trama/Core/Domain.
// No React, no store: everything here is unit tested in rules.test.ts.

import { asCutStatus, asReportKind, type AssignmentState, type CutStatus, type ReportKind, type Role } from "./enums";
import type { ReportDTO } from "./types";
import { fmtMoney, fmtInt } from "../lib/format";
import { t } from "../i18n";

const time = (iso: string | null | undefined) => (iso ? new Date(iso).getTime() : 0);

// Rule 1 — order assignment state ------------------------------------------------------

export function orderProgress(quantity: number, assignedQuantities: number[]) {
  const assigned = assignedQuantities.reduce((s, q) => s + q, 0);
  const remaining = Math.max(0, quantity - assigned);
  const state: AssignmentState = assigned === 0 ? "unassigned" : remaining === 0 ? "assigned" : "partial";
  return { assigned, remaining, state };
}

// Rules 4, 5 — assignment metrics from its reports --------------------------------------

export interface Metrics {
  quantity: number;
  unitPrice: number;
  realCut: number;
  cutStatus: CutStatus;
  operators: number;
  absences: number;
  produced: number;
  ironing: number;
  packing: number;
  warehouse: number;
  shipped: number;
  revenue: number;
  shippingBase: number;
  toShip: number;
  shippingProgress: number;
  productionProgress: number;
  isComplete: boolean;
}

export function assignmentMetrics(quantity: number, unitPrice: number, reports: ReportDTO[]): Metrics {
  const sorted = [...reports].sort((a, b) => time(a.createdAt) - time(b.createdAt));
  const kindOf = (r: ReportDTO): ReportKind => asReportKind(r.kindRaw);
  const cut = [...sorted].reverse().find((r) => kindOf(r) === "corte");
  const plant = [...sorted].reverse().find((r) => kindOf(r) === "planta");
  const shipped = sorted.filter((r) => kindOf(r) === "envio").reduce((s, r) => s + (r.shippedQuantity ?? 0), 0);
  const realCut = cut?.realQuantity ?? 0;
  const shippingBase = realCut > 0 ? realCut : quantity;
  const toShip = Math.max(0, shippingBase - shipped);
  const produced = plant?.produced ?? 0;
  return {
    quantity,
    unitPrice,
    realCut,
    cutStatus: cut ? asCutStatus(cut.cutStatusRaw) : "en_espera",
    operators: plant?.operators ?? 0,
    absences: plant?.absences ?? 0,
    produced,
    ironing: plant?.ironing ?? 0,
    packing: plant?.packing ?? 0,
    warehouse: plant?.warehouse ?? 0,
    shipped,
    revenue: quantity * unitPrice,
    shippingBase,
    toShip,
    shippingProgress: shippingBase > 0 ? Math.min(1, shipped / shippingBase) : 0,
    productionProgress: shippingBase > 0 ? Math.min(1, produced / shippingBase) : 0,
    isComplete: shippingBase > 0 && toShip === 0,
  };
}

// Rule 7 — totals ----------------------------------------------------------------------

export interface Totals {
  shipped: number; quantity: number; produced: number; ironing: number; packing: number; warehouse: number; toShip: number; revenue: number;
}

export function productionTotals(metrics: Metrics[]): Totals {
  const t: Totals = { shipped: 0, quantity: 0, produced: 0, ironing: 0, packing: 0, warehouse: 0, toShip: 0, revenue: 0 };
  for (const m of metrics) {
    t.shipped += m.shipped; t.quantity += m.quantity; t.produced += m.produced; t.ironing += m.ironing;
    t.packing += m.packing; t.warehouse += m.warehouse; t.toShip += m.toShip; t.revenue += m.revenue;
  }
  return t;
}

// Rule 3 — capacity (calendar months in local time) ------------------------------------

export interface Booking { date: Date; amount: number }

export const sameMonth = (a: Date, b: Date) => a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth();

export class CapacityLedger {
  constructor(readonly maxCapacity: number, readonly bookings: Booking[]) {}

  used(monthOf: Date) {
    return this.bookings.filter((b) => sameMonth(b.date, monthOf)).reduce((s, b) => s + b.amount, 0);
  }

  available(monthOf: Date) {
    return this.maxCapacity - this.used(monthOf);
  }

  utilization(monthOf: Date) {
    return this.maxCapacity > 0 ? this.used(monthOf) / this.maxCapacity : 0;
  }

  /** Used capacity per month index 0…11 of a year. */
  monthlyUsage(year: number): number[] {
    const out = Array.from({ length: 12 }, () => 0);
    for (const b of this.bookings) if (b.date.getFullYear() === year) out[b.date.getMonth()] += b.amount;
    return out;
  }
}

// Rule 2 — assignment validation (order of checks matters) ------------------------------

export type AssignmentError =
  | { code: "missingDate" }
  | { code: "invalidQuantity" }
  | { code: "exceedsRemaining"; remaining: number }
  | { code: "exceedsCapacity"; available: number };

export function assignmentErrorMessage(e: AssignmentError): string {
  switch (e.code) {
    case "missingDate": return t("rule.missingDate");
    case "invalidQuantity": return t("rule.invalidQuantity");
    case "exceedsRemaining": return t("rule.exceedsRemaining", { remaining: fmtInt(e.remaining) });
    case "exceedsCapacity": return t("rule.exceedsCapacity", { available: fmtMoney(e.available) });
  }
}

export function validateAssignment(input: { quantity: number; unitPrice: number; remaining: number; date: Date | null; ledger: CapacityLedger }):
  { ok: true; total: number } | { ok: false; error: AssignmentError } {
  const { quantity, unitPrice, remaining, date, ledger } = input;
  if (!date) return { ok: false, error: { code: "missingDate" } };
  if (!(quantity > 0) || !Number.isInteger(quantity)) return { ok: false, error: { code: "invalidQuantity" } };
  if (quantity > remaining) return { ok: false, error: { code: "exceedsRemaining", remaining } };
  const total = quantity * unitPrice;
  const available = ledger.available(date);
  if (total > available + 0.0001) return { ok: false, error: { code: "exceedsCapacity", available: Math.max(0, available) } };
  return { ok: true, total };
}

// Rule 6 — urgency ---------------------------------------------------------------------

export const startOfDay = (d: Date) => new Date(d.getFullYear(), d.getMonth(), d.getDate());

export function isUrgent(toShip: number, clientDate: Date | null, windowDays: number, now = new Date()): boolean {
  if (toShip <= 0 || !clientDate) return false;
  const limit = startOfDay(now);
  limit.setDate(limit.getDate() + windowDays);
  return clientDate.getTime() < limit.getTime();
}

export function daysLeft(date: Date | null, now = new Date()): number | null {
  if (!date) return null;
  return Math.round((startOfDay(date).getTime() - startOfDay(now).getTime()) / 86_400_000);
}

// Rule 10 — users ----------------------------------------------------------------------

export interface Member { id: string; role: Role; isActive: boolean }
export type UserChange = { kind: "delete" } | { kind: "deactivate" } | { kind: "changeRole"; role: Role };

export const USER_VIOLATION = {
  cannotDeleteSelf: "cannotDeleteSelf",
  cannotDeactivateSelf: "cannotDeactivateSelf",
  cannotChangeOwnRole: "cannotChangeOwnRole",
  lastAdmin: "lastAdmin",
} as const;
export type UserViolation = keyof typeof USER_VIOLATION;

/** Display message of a user-policy violation, in the current language. */
export const userViolationMessage = (v: UserViolation) => t(`policy.${v}`);

/** Returns the rule a change would break, or null when allowed (UserPolicy). */
export function userPolicyViolation(change: UserChange, target: Member, actingUserId: string | null, members: Member[]): UserViolation | null {
  const isSelf = target.id === actingUserId;
  if (change.kind === "delete" && isSelf) return USER_VIOLATION.cannotDeleteSelf;
  if (change.kind === "deactivate" && isSelf) return USER_VIOLATION.cannotDeactivateSelf;
  if (change.kind === "changeRole" && isSelf && change.role !== target.role) return USER_VIOLATION.cannotChangeOwnRole;
  const after = members.flatMap((m): Member[] => {
    if (m.id !== target.id) return [m];
    if (change.kind === "delete") return [];
    if (change.kind === "deactivate") return [{ ...m, isActive: false }];
    return [{ ...m, role: change.role }];
  });
  const hadAdmin = members.some((m) => m.role === "Administrador" && m.isActive);
  const hasAdmin = after.some((m) => m.role === "Administrador" && m.isActive);
  return hadAdmin && !hasAdmin ? USER_VIOLATION.lastAdmin : null;
}

export const MIN_PASSWORD = 6;

/** ContactLinks.isPlausibleEmail */
export function isPlausibleEmail(email: string): boolean {
  const parts = email.split("@");
  if (parts.length !== 2 || !parts[0] || /\s/.test(email)) return false;
  const domain = parts[1];
  return domain.includes(".") && !domain.startsWith(".") && !domain.endsWith(".");
}

// Rule 12 — calculator -----------------------------------------------------------------

export interface CalculatorConstants { minutesPerDay: number; minutesPerWeek: number; minutesPerMonth: number; workDaysPerWeek: number; workDaysPerMonth: number }
export interface CalculatorInput {
  quantity: number; realMinutes: number; clientMinutes: number; operators: number; internalUnitPrice: number;
  pricePerStyle: number; operatingExpenses: number; lineOperators: number; realDailyProduction: number;
}
export interface CalculatorResult {
  grossIncome?: number; netIncome?: number; pricePerRealMinute?: number; dailyGoal?: number; estimatedDays?: number;
  estimatedMonths?: number; weeklyProduction?: number; minuteEfficiency?: number; realProductionMinute?: number;
}

export function computeCalculator(i: CalculatorInput, c: CalculatorConstants): CalculatorResult {
  const r: CalculatorResult = {};
  if (i.quantity > 0 && i.pricePerStyle > 0) {
    r.grossIncome = i.quantity * i.pricePerStyle;
    r.netIncome = r.grossIncome - i.operatingExpenses;
  }
  if (i.pricePerStyle > 0 && i.realMinutes > 0) r.pricePerRealMinute = i.pricePerStyle / i.realMinutes;
  if (i.operators > 0 && c.minutesPerDay > 0 && i.realMinutes > 0) {
    const goal = (i.operators * c.minutesPerDay) / i.realMinutes;
    r.dailyGoal = goal;
    if (c.workDaysPerWeek > 0) r.weeklyProduction = goal * c.workDaysPerWeek;
    if (i.quantity > 0 && goal > 0) {
      r.estimatedDays = i.quantity / goal;
      if (c.workDaysPerMonth > 0) r.estimatedMonths = r.estimatedDays / c.workDaysPerMonth;
    }
  }
  if (i.clientMinutes > 0 && i.realMinutes > 0) r.minuteEfficiency = i.clientMinutes / i.realMinutes;
  if (c.minutesPerDay > 0 && i.lineOperators > 0 && i.realDailyProduction > 0) r.realProductionMinute = (c.minutesPerDay * i.lineOperators) / i.realDailyProduction;
  return r;
}

/** Capacity bar color thresholds (CapacityBar.tint). */
export const capacityTint = (ratio: number) => (ratio < 0.7 ? "success" : ratio < 0.95 ? "warning" : "danger");
