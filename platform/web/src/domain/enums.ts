// Enumerations with stable raw values (docs/DOMAIN.md), mirroring ios/Trama/Core/Domain/Enums.swift.
// Raw values never change; the *Title functions return display text in the current language.

import { t, type MessageKey } from "../i18n";

export type Tint = "brand" | "thread" | "success" | "warning" | "danger" | "info" | "muted";

export const ROLES = ["Administrador", "Gerente de Planta", "Gerente de Cortes", "Gerente de Envios"] as const;
export type Role = (typeof ROLES)[number];

const ROLE_KEY: Record<Role, MessageKey> = {
  Administrador: "role.admin",
  "Gerente de Planta": "role.plant",
  "Gerente de Cortes": "role.cuts",
  "Gerente de Envios": "role.shipping",
};
export const roleTitle = (role: Role) => t(ROLE_KEY[role]);

export const asRole = (raw: string | null | undefined): Role => (ROLES as readonly string[]).includes(raw ?? "") ? (raw as Role) : "Gerente de Planta";

export type ReportKind = "planta" | "corte" | "envio";
export const REPORT_KINDS: ReportKind[] = ["planta", "corte", "envio"];
export const reportTitle = (kind: ReportKind) => t(`report.${kind}`);
export const reportShort = (kind: ReportKind) => t(`reportShort.${kind}`);
export const REPORT_TINT: Record<ReportKind, Tint> = { planta: "brand", corte: "warning", envio: "info" };
export const asReportKind = (raw: string | null | undefined): ReportKind => (raw === "corte" || raw === "envio" ? raw : "planta");

export type CutStatus = "en_espera" | "en_mesa_de_corte" | "listo_para_confeccionar";
export const CUT_STATUSES: CutStatus[] = ["en_espera", "en_mesa_de_corte", "listo_para_confeccionar"];
export const cutStatusTitle = (status: CutStatus) => t(`cutStatus.${status}`);
export const CUT_STATUS_TINT: Record<CutStatus, Tint> = { en_espera: "danger", en_mesa_de_corte: "warning", listo_para_confeccionar: "success" };

/** Accepts new raw values and the legacy free-text statuses (CutStatus(legacy:)). */
export function asCutStatus(raw: string | null | undefined): CutStatus {
  const v = (raw ?? "").trim().toLowerCase();
  if (v === "en mesa de corte" || v === "en_mesa_de_corte") return "en_mesa_de_corte";
  if (v === "listo para confeccionar" || v === "listo_para_confeccionar") return "listo_para_confeccionar";
  return "en_espera";
}

export type ProjectStatus = "pendiente" | "aceptado" | "declinado";
export const PROJECT_STATUSES: ProjectStatus[] = ["pendiente", "aceptado", "declinado"];
export const projectStatusTitle = (status: ProjectStatus) => t(`projectStatus.${status}`);
export const PROJECT_STATUS_TINT: Record<ProjectStatus, Tint> = { pendiente: "muted", aceptado: "success", declinado: "danger" };
export const asProjectStatus = (raw: string | null | undefined): ProjectStatus => (raw === "aceptado" || raw === "declinado" ? raw : "pendiente");

export type AssignmentState = "unassigned" | "partial" | "assigned";
export const assignmentStateTitle = (state: AssignmentState) => t(`assignState.${state}`);
export const ASSIGNMENT_STATE_TINT: Record<AssignmentState, Tint> = { unassigned: "danger", partial: "warning", assigned: "success" };

export type Section =
  | "dashboard" | "orders" | "board" | "production" | "shipments" | "calendar"
  | "plants" | "clients" | "suppliers" | "styles" | "projects" | "users"
  | "calculator" | "settings";

export const ALL_SECTIONS: Section[] = [
  "dashboard", "orders", "board", "production", "shipments", "calendar",
  "plants", "clients", "suppliers", "styles", "projects", "users", "calculator", "settings",
];

export const sectionTitle = (section: Section) => t(`section.${section}`);

export const SECTION_GROUPS: { key: "operations" | "catalogs" | "tools"; sections: Section[] }[] = [
  { key: "operations", sections: ["dashboard", "orders", "board", "production", "shipments", "calendar"] },
  { key: "catalogs", sections: ["plants", "clients", "suppliers", "styles", "projects", "users"] },
  { key: "tools", sections: ["calculator", "settings"] },
];
export const groupTitle = (key: (typeof SECTION_GROUPS)[number]["key"]) => t(`group.${key}`);

/** Display name of a licence plan id (web, planta, multiplanta, empresa). */
export const planTitle = (plan: string) => (plan === "web" || plan === "planta" || plan === "multiplanta" || plan === "empresa" ? t(`plan.${plan}`) : plan);

/** Sections visible per role (DOMAIN rule 8, Role.sections). */
export function sectionsFor(role: Role): Section[] {
  switch (role) {
    case "Administrador": return ALL_SECTIONS;
    case "Gerente de Cortes": return ["orders", "board", "production", "calendar", "settings"];
    case "Gerente de Planta": return ["production", "settings"];
    case "Gerente de Envios": return ["production", "shipments", "settings"];
  }
}

export function landingFor(role: Role): Section {
  switch (role) {
    case "Administrador": return "dashboard";
    case "Gerente de Cortes": return "orders";
    default: return "production";
  }
}

/** Report kinds a role may create and edit (DOMAIN rule 9). */
export function creatableReports(role: Role): ReportKind[] {
  switch (role) {
    case "Administrador": return REPORT_KINDS;
    case "Gerente de Planta": return ["planta"];
    case "Gerente de Cortes": return ["corte"];
    case "Gerente de Envios": return ["envio"];
  }
}

export const canEditReport = (role: Role, kind: ReportKind) => creatableReports(role).includes(kind);

/** Who may write orders and assignments (server mirror in platform/src/sync.ts canWrite). */
export const canManageOrders = (role: Role) => role === "Administrador" || role === "Gerente de Cortes";
export const isAdmin = (role: Role) => role === "Administrador";
