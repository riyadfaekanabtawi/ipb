// Licence tiers, mirroring the prices on the website. Limits are defaults; the admin portal
// can override them per company (e.g. a negotiated Empresa deal).

export type Plan = "web" | "planta" | "multiplanta" | "empresa";

export interface PlanLimits {
  maxUsers: number;
  maxDevices: number;
  maxPlants: number;
  /** Whether the iPad/Android apps may be activated (Web plan is browser-only). */
  nativeApps: boolean;
  priceUsdMonthly: number;
}

export const PLANS: Record<Plan, PlanLimits> = {
  web: { maxUsers: 5, maxDevices: 0, maxPlants: 1, nativeApps: false, priceUsdMonthly: 49 },
  planta: { maxUsers: 10, maxDevices: 10, maxPlants: 1, nativeApps: true, priceUsdMonthly: 99 },
  multiplanta: { maxUsers: 30, maxDevices: 30, maxPlants: 5, nativeApps: true, priceUsdMonthly: 249 },
  empresa: { maxUsers: 1000, maxDevices: 1000, maxPlants: 1000, nativeApps: true, priceUsdMonthly: 590 },
};

export const PLAN_IDS = Object.keys(PLANS) as Plan[];

export interface LicenceState {
  plan: Plan;
  status: "active" | "suspended" | "expired";
  expiresAt: string;
  /** Writes (sync push) are allowed only while active; data stays readable otherwise. */
  writable: boolean;
}

export function licenceState(tenant: { plan: Plan; status: string; expires_at: Date }, now = new Date()): LicenceState {
  const status = tenant.status === "suspended" ? "suspended" : tenant.expires_at.getTime() < now.getTime() ? "expired" : "active";
  return { plan: tenant.plan, status, expiresAt: tenant.expires_at.toISOString(), writable: status === "active" };
}
