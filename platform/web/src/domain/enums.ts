// Enumerations with stable raw values (docs/DOMAIN.md), mirroring ios/Trama/Core/Domain/Enums.swift.

export type Tint = "brand" | "thread" | "success" | "warning" | "danger" | "info" | "muted";

export const ROLES = ["Administrador", "Gerente de Planta", "Gerente de Cortes", "Gerente de Envios"] as const;
export type Role = (typeof ROLES)[number];

export const ROLE_TITLE: Record<Role, string> = {
  Administrador: "Administrador",
  "Gerente de Planta": "Gerente de planta",
  "Gerente de Cortes": "Gerente de cortes",
  "Gerente de Envios": "Gerente de envíos",
};

export const asRole = (raw: string | null | undefined): Role => (ROLES as readonly string[]).includes(raw ?? "") ? (raw as Role) : "Gerente de Planta";

export type ReportKind = "planta" | "corte" | "envio";
export const REPORT_KINDS: ReportKind[] = ["planta", "corte", "envio"];
export const REPORT_TITLE: Record<ReportKind, string> = { planta: "Reporte de planta", corte: "Reporte de corte", envio: "Reporte de envío" };
export const REPORT_SHORT: Record<ReportKind, string> = { planta: "Planta", corte: "Corte", envio: "Envío" };
export const REPORT_TINT: Record<ReportKind, Tint> = { planta: "brand", corte: "warning", envio: "info" };
export const asReportKind = (raw: string | null | undefined): ReportKind => (raw === "corte" || raw === "envio" ? raw : "planta");

export type CutStatus = "en_espera" | "en_mesa_de_corte" | "listo_para_confeccionar";
export const CUT_STATUSES: CutStatus[] = ["en_espera", "en_mesa_de_corte", "listo_para_confeccionar"];
export const CUT_STATUS_TITLE: Record<CutStatus, string> = {
  en_espera: "En espera",
  en_mesa_de_corte: "En mesa de corte",
  listo_para_confeccionar: "Listo para confeccionar",
};
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
export const PROJECT_STATUS_TITLE: Record<ProjectStatus, string> = { pendiente: "Pendiente", aceptado: "Aceptado", declinado: "Declinado" };
export const PROJECT_STATUS_TINT: Record<ProjectStatus, Tint> = { pendiente: "muted", aceptado: "success", declinado: "danger" };
export const asProjectStatus = (raw: string | null | undefined): ProjectStatus => (raw === "aceptado" || raw === "declinado" ? raw : "pendiente");

export type AssignmentState = "unassigned" | "partial" | "assigned";
export const ASSIGNMENT_STATE_TITLE: Record<AssignmentState, string> = { unassigned: "Por asignar", partial: "Parcial", assigned: "Asignado" };
export const ASSIGNMENT_STATE_TINT: Record<AssignmentState, Tint> = { unassigned: "danger", partial: "warning", assigned: "success" };

export type Section =
  | "dashboard" | "orders" | "board" | "production" | "shipments" | "calendar"
  | "plants" | "clients" | "suppliers" | "styles" | "projects" | "users"
  | "calculator" | "settings";

export const ALL_SECTIONS: Section[] = [
  "dashboard", "orders", "board", "production", "shipments", "calendar",
  "plants", "clients", "suppliers", "styles", "projects", "users", "calculator", "settings",
];

export const SECTION_TITLE: Record<Section, string> = {
  dashboard: "Dashboard",
  orders: "Cortes por asignar",
  board: "Tablero de corte",
  production: "Reportes de producción",
  shipments: "Envíos urgentes",
  calendar: "Calendario de plantas",
  plants: "Plantas",
  clients: "Clientes",
  suppliers: "Proveedores",
  styles: "Estilos",
  projects: "Proyectos",
  users: "Usuarios",
  calculator: "Calculadora",
  settings: "Ajustes",
};

export const SECTION_GROUPS: { title: string; sections: Section[] }[] = [
  { title: "Operación", sections: ["dashboard", "orders", "board", "production", "shipments", "calendar"] },
  { title: "Catálogos", sections: ["plants", "clients", "suppliers", "styles", "projects", "users"] },
  { title: "Herramientas", sections: ["calculator", "settings"] },
];

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
