// Port of ios/TramaTests/DomainTests.swift + CatalogTests (UserPolicy) for the web rules.

import { describe, expect, it } from "vitest";
import { asCutStatus, creatableReports, landingFor, sectionsFor, ALL_SECTIONS, canEditReport } from "./enums";
import {
  assignmentMetrics, CapacityLedger, computeCalculator, daysLeft, isPlausibleEmail, isUrgent, orderProgress, productionTotals,
  userPolicyViolation, USER_VIOLATION, validateAssignment, type CalculatorInput, type Member,
} from "./rules";
import type { ReportDTO } from "./types";

const t0 = new Date(1_700_000_000_000);
const at = (offsetSec: number) => new Date(t0.getTime() + offsetSec * 1000).toISOString();
const rep = (r: Partial<ReportDTO>): ReportDTO => ({ id: crypto.randomUUID(), ...r });

describe("production math", () => {
  it("uses the latest plant report and sums shipments", () => {
    const m = assignmentMetrics(500, 10, [
      rep({ kindRaw: "planta", createdAt: at(0), operators: 10, produced: 100 }),
      rep({ kindRaw: "planta", createdAt: at(60), operators: 12, produced: 250, warehouse: 40 }),
      rep({ kindRaw: "envio", createdAt: at(0), shippedQuantity: 30 }),
      rep({ kindRaw: "envio", createdAt: at(5), shippedQuantity: 20 }),
      rep({ kindRaw: "corte", createdAt: at(0), cutStatusRaw: "listo_para_confeccionar", realQuantity: 480 }),
    ]);
    expect(m.produced).toBe(250);
    expect(m.operators).toBe(12);
    expect(m.warehouse).toBe(40);
    expect(m.shipped).toBe(50);
    expect(m.realCut).toBe(480);
    expect(m.cutStatus).toBe("listo_para_confeccionar");
    expect(m.shippingBase).toBe(480);
    expect(m.toShip).toBe(430);
    expect(m.revenue).toBe(5000);
  });

  it("falls back to the planned quantity and never goes negative", () => {
    const m = assignmentMetrics(100, 1, [rep({ kindRaw: "envio", createdAt: at(0), shippedQuantity: 150 })]);
    expect(m.shippingBase).toBe(100);
    expect(m.toShip).toBe(0);
    expect(m.isComplete).toBe(true);
    expect(m.shippingProgress).toBe(1);
  });

  it("aggregates totals", () => {
    const a = assignmentMetrics(100, 2, [rep({ kindRaw: "planta", createdAt: at(0), produced: 40, ironing: 5 })]);
    const b = assignmentMetrics(50, 4, [rep({ kindRaw: "envio", createdAt: at(0), shippedQuantity: 10 })]);
    const t = productionTotals([a, b]);
    expect(t).toMatchObject({ quantity: 150, produced: 40, ironing: 5, shipped: 10, toShip: 140, revenue: 400 });
  });

  it("derives the order assignment state (rule 1)", () => {
    expect(orderProgress(100, [])).toEqual({ assigned: 0, remaining: 100, state: "unassigned" });
    expect(orderProgress(100, [30, 20])).toEqual({ assigned: 50, remaining: 50, state: "partial" });
    expect(orderProgress(100, [60, 40])).toEqual({ assigned: 100, remaining: 0, state: "assigned" });
    expect(orderProgress(100, [120]).remaining).toBe(0);
  });
});

describe("capacity and assignment rules", () => {
  const d = (y: number, m: number, day: number) => new Date(y, m - 1, day, 12);

  it("sums only the same calendar month", () => {
    const ledger = new CapacityLedger(1000, [
      { date: d(2026, 3, 2), amount: 300 },
      { date: d(2026, 3, 28), amount: 200 },
      { date: d(2026, 4, 1), amount: 999 },
    ]);
    expect(ledger.used(d(2026, 3, 15))).toBe(500);
    expect(ledger.available(d(2026, 3, 15))).toBe(500);
    expect(ledger.utilization(d(2026, 4, 10))).toBe(0.999);
    expect(ledger.monthlyUsage(2026)[2]).toBe(500);
    expect(ledger.monthlyUsage(2026)[4]).toBe(0);
  });

  it("rejects over capacity", () => {
    const ledger = new CapacityLedger(1000, [{ date: d(2026, 3, 2), amount: 900 }]);
    expect(validateAssignment({ quantity: 20, unitPrice: 10, remaining: 50, date: d(2026, 3, 9), ledger })).toEqual({ ok: false, error: { code: "exceedsCapacity", available: 100 } });
  });

  it("checks date, quantity and remaining in order", () => {
    const ledger = new CapacityLedger(1_000_000, []);
    expect(validateAssignment({ quantity: 60, unitPrice: 1, remaining: 50, date: new Date(), ledger })).toEqual({ ok: false, error: { code: "exceedsRemaining", remaining: 50 } });
    expect(validateAssignment({ quantity: 0, unitPrice: 1, remaining: 50, date: new Date(), ledger })).toEqual({ ok: false, error: { code: "invalidQuantity" } });
    expect(validateAssignment({ quantity: 0, unitPrice: 1, remaining: 50, date: null, ledger })).toEqual({ ok: false, error: { code: "missingDate" } });
  });

  it("accepts and returns the total", () => {
    const ledger = new CapacityLedger(1000, []);
    expect(validateAssignment({ quantity: 10, unitPrice: 100, remaining: 10, date: d(2026, 1, 1), ledger })).toEqual({ ok: true, total: 1000 });
  });
});

describe("urgency", () => {
  const now = new Date(1_700_000_000_000);
  const day = 86_400_000;
  it("is urgent when pending and due soon or overdue", () => {
    expect(isUrgent(10, new Date(now.getTime() + 3 * day), 7, now)).toBe(true);
    expect(isUrgent(10, new Date(now.getTime() - day), 7, now)).toBe(true);
    expect(isUrgent(10, new Date(now.getTime() + 30 * day), 7, now)).toBe(false);
    expect(isUrgent(0, new Date(now.getTime() + 3 * day), 7, now)).toBe(false);
    expect(isUrgent(10, null, 7, now)).toBe(false);
  });
  it("counts calendar days", () => {
    expect(daysLeft(new Date(now.getTime() + 2 * day), now)).toBe(2);
    expect(daysLeft(now, now)).toBe(0);
    expect(daysLeft(null, now)).toBeNull();
  });
});

describe("calculator", () => {
  const constants = { minutesPerDay: 480, minutesPerWeek: 2400, minutesPerMonth: 9600, workDaysPerWeek: 5, workDaysPerMonth: 20 };
  const empty: CalculatorInput = { quantity: 0, realMinutes: 0, clientMinutes: 0, operators: 0, internalUnitPrice: 0, pricePerStyle: 0, operatingExpenses: 0, lineOperators: 0, realDailyProduction: 0 };

  it("computes everything", () => {
    const r = computeCalculator({ ...empty, quantity: 4000, realMinutes: 12, clientMinutes: 15, operators: 30, pricePerStyle: 60, operatingExpenses: 40_000 }, constants);
    expect(r.grossIncome).toBe(240_000);
    expect(r.netIncome).toBe(200_000);
    expect(r.pricePerRealMinute).toBe(5);
    expect(r.dailyGoal).toBe(1200);
    expect(r.weeklyProduction).toBe(6000);
    expect(r.estimatedDays).toBeCloseTo(3.333, 2);
    expect(r.estimatedMonths).toBeCloseTo(0.1667, 3);
    expect(r.minuteEfficiency).toBe(1.25);
  });

  it("yields no values for missing inputs", () => {
    expect(computeCalculator(empty, { minutesPerDay: 0, minutesPerWeek: 0, minutesPerMonth: 0, workDaysPerWeek: 0, workDaysPerMonth: 0 })).toEqual({});
  });

  it("computes the real production minute", () => {
    expect(computeCalculator({ ...empty, lineOperators: 20, realDailyProduction: 800 }, constants).realProductionMinute).toBe(12);
  });
});

describe("enums and permissions", () => {
  it("reads legacy cut statuses", () => {
    expect(asCutStatus("En Mesa de Corte")).toBe("en_mesa_de_corte");
    expect(asCutStatus("listo para confeccionar")).toBe("listo_para_confeccionar");
    expect(asCutStatus("en espera")).toBe("en_espera");
    expect(asCutStatus(null)).toBe("en_espera");
  });

  it("mirrors the role table", () => {
    expect(sectionsFor("Administrador")).toEqual(ALL_SECTIONS);
    expect(creatableReports("Gerente de Planta")).toEqual(["planta"]);
    expect(sectionsFor("Gerente de Envios")).toContain("shipments");
    expect(sectionsFor("Gerente de Planta")).not.toContain("orders");
    expect(sectionsFor("Gerente de Cortes")).toEqual(["orders", "board", "production", "calendar", "settings"]);
    expect(landingFor("Gerente de Cortes")).toBe("orders");
    expect(canEditReport("Gerente de Envios", "planta")).toBe(false);
    expect(canEditReport("Administrador", "corte")).toBe(true);
  });
});

describe("user policy (rule 10)", () => {
  const admin: Member = { id: "a", role: "Administrador", isActive: true };
  const admin2: Member = { id: "b", role: "Administrador", isActive: true };
  const plant: Member = { id: "c", role: "Gerente de Planta", isActive: true };

  it("an admin can't delete, deactivate or demote themselves", () => {
    expect(userPolicyViolation({ kind: "delete" }, admin, "a", [admin, admin2])).toBe(USER_VIOLATION.cannotDeleteSelf);
    expect(userPolicyViolation({ kind: "deactivate" }, admin, "a", [admin, admin2])).toBe(USER_VIOLATION.cannotDeactivateSelf);
    expect(userPolicyViolation({ kind: "changeRole", role: "Gerente de Cortes" }, admin, "a", [admin, admin2])).toBe(USER_VIOLATION.cannotChangeOwnRole);
    expect(userPolicyViolation({ kind: "changeRole", role: "Administrador" }, admin, "a", [admin, admin2])).toBeNull();
  });

  it("keeps at least one active admin", () => {
    expect(userPolicyViolation({ kind: "delete" }, admin, "c", [admin, plant])).toBe(USER_VIOLATION.lastAdmin);
    expect(userPolicyViolation({ kind: "changeRole", role: "Gerente de Planta" }, admin, "c", [admin, plant])).toBe(USER_VIOLATION.lastAdmin);
  });

  it("other admins can be managed while one remains", () => {
    expect(userPolicyViolation({ kind: "deactivate" }, admin2, "a", [admin, admin2, plant])).toBeNull();
    expect(userPolicyViolation({ kind: "delete" }, plant, "a", [admin, admin2, plant])).toBeNull();
  });

  it("checks emails like ContactLinks.isPlausibleEmail", () => {
    expect(isPlausibleEmail("ana@ipb.mx")).toBe(true);
    expect(isPlausibleEmail("ana@ipb")).toBe(false);
    expect(isPlausibleEmail("a na@ipb.mx")).toBe(false);
    expect(isPlausibleEmail("@ipb.mx")).toBe(false);
    expect(isPlausibleEmail("ana@.mx")).toBe(false);
  });
});
