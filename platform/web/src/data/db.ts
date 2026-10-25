// Read model: relationship indexes and derived metrics computed once per store version.

import { asCutStatus, asRole, type CutStatus, type Role } from "../domain/enums";
import { assignmentMetrics, CapacityLedger, orderProgress, type Metrics } from "../domain/rules";
import type { AssignmentDTO, ClientDTO, ContactDTO, CutOrderDTO, PlantDTO, ProjectDTO, ReportDTO, StyleDTO, SupplierDTO, UserDTO } from "../domain/types";
import { fullName, parseDate } from "../lib/format";
import type { DataStore } from "./store";

const byName = <T extends { name?: string | null }>(a: T, b: T) => (a.name ?? "").localeCompare(b.name ?? "", "es", { sensitivity: "base" });
const time = (iso: string | null | undefined) => (iso ? new Date(iso).getTime() : 0);

function group<T>(rows: T[], keyOf: (r: T) => string | null | undefined): Map<string, T[]> {
  const out = new Map<string, T[]>();
  for (const r of rows) {
    const k = keyOf(r);
    if (!k) continue;
    const list = out.get(k);
    if (list) list.push(r);
    else out.set(k, [r]);
  }
  return out;
}

export interface OrderInfo {
  order: CutOrderDTO;
  assigned: number;
  remaining: number;
  state: "unassigned" | "partial" | "assigned";
  revenue: number;
  clientName: string;
  styleName: string;
}

export interface AssignmentInfo {
  assignment: AssignmentDTO;
  order?: CutOrderDTO;
  plant?: PlantDTO;
  metrics: Metrics;
  cutStatus: CutStatus;
  reports: ReportDTO[];
  title: string;
  plantName: string;
  clientName: string;
  styleName: string;
}

export class DB {
  plants: PlantDTO[];
  clients: ClientDTO[];
  suppliers: SupplierDTO[];
  contacts: ContactDTO[];
  styles: StyleDTO[];
  orders: CutOrderDTO[];
  assignments: AssignmentDTO[];
  reports: ReportDTO[];
  projects: ProjectDTO[];
  users: UserDTO[];

  plantById: Map<string, PlantDTO>;
  clientById: Map<string, ClientDTO>;
  supplierById: Map<string, SupplierDTO>;
  styleById: Map<string, StyleDTO>;
  orderById: Map<string, CutOrderDTO>;
  assignmentById: Map<string, AssignmentDTO>;
  userById: Map<string, UserDTO>;

  contactsByClient: Map<string, ContactDTO[]>;
  contactsBySupplier: Map<string, ContactDTO[]>;
  ordersByClient: Map<string, CutOrderDTO[]>;
  ordersByStyle: Map<string, CutOrderDTO[]>;
  assignmentsByOrder: Map<string, AssignmentDTO[]>;
  assignmentsByPlant: Map<string, AssignmentDTO[]>;
  reportsByAssignment: Map<string, ReportDTO[]>;
  projectsByClient: Map<string, ProjectDTO[]>;
  managersByPlant: Map<string, UserDTO[]>;

  private orderInfos = new Map<string, OrderInfo>();
  private assignmentInfos = new Map<string, AssignmentInfo>();
  private ledgers = new Map<string, CapacityLedger>();

  constructor(store: DataStore) {
    this.plants = store.all("plants").sort(byName);
    this.clients = store.all("clients").sort(byName);
    this.suppliers = store.all("suppliers").sort(byName);
    this.contacts = store.all("contacts").sort((a, b) => (a.sortIndex ?? 0) - (b.sortIndex ?? 0));
    this.styles = store.all("styles").sort(byName);
    this.orders = store.all("orders").sort((a, b) => time(b.createdAt) - time(a.createdAt));
    this.assignments = store.all("assignments");
    this.reports = store.all("reports").sort((a, b) => time(b.createdAt) - time(a.createdAt));
    this.projects = store.all("projects").sort((a, b) => time(b.createdAt) - time(a.createdAt));
    this.users = store.all("users").sort((a, b) => fullName(a).localeCompare(fullName(b), "es"));

    const index = <T extends { id: string }>(rows: T[]) => new Map(rows.map((r) => [r.id, r]));
    this.plantById = index(this.plants);
    this.clientById = index(this.clients);
    this.supplierById = index(this.suppliers);
    this.styleById = index(this.styles);
    this.orderById = index(this.orders);
    this.assignmentById = index(this.assignments);
    this.userById = index(this.users);

    this.contactsByClient = group(this.contacts, (c) => c.clientID);
    this.contactsBySupplier = group(this.contacts, (c) => c.supplierID);
    this.ordersByClient = group(this.orders, (o) => o.clientID);
    this.ordersByStyle = group(this.orders, (o) => o.styleID);
    this.assignmentsByOrder = group(this.assignments, (a) => a.orderID);
    this.assignmentsByPlant = group(this.assignments, (a) => a.plantID);
    this.reportsByAssignment = group(this.reports, (r) => r.assignmentID);
    this.projectsByClient = group(this.projects, (p) => p.clientID);
    this.managersByPlant = group(this.users.filter((u) => asRole(u.roleRaw) === "Gerente de Planta"), (u) => u.plantID);
  }

  orderInfo(order: CutOrderDTO): OrderInfo {
    let info = this.orderInfos.get(order.id);
    if (!info) {
      const p = orderProgress(order.quantity ?? 0, (this.assignmentsByOrder.get(order.id) ?? []).map((a) => a.quantity ?? 0));
      info = {
        order, ...p,
        revenue: (order.quantity ?? 0) * (order.unitPrice ?? 0),
        clientName: this.clientById.get(order.clientID ?? "")?.name ?? "Sin cliente",
        styleName: this.styleById.get(order.styleID ?? "")?.name ?? "Sin estilo",
      };
      this.orderInfos.set(order.id, info);
    }
    return info;
  }

  assignmentInfo(a: AssignmentDTO): AssignmentInfo {
    let info = this.assignmentInfos.get(a.id);
    if (!info) {
      const reports = this.reportsByAssignment.get(a.id) ?? [];
      const order = this.orderById.get(a.orderID ?? "");
      const plant = this.plantById.get(a.plantID ?? "");
      const metrics = assignmentMetrics(a.quantity ?? 0, a.unitPrice ?? 0, reports);
      info = {
        assignment: a, order, plant, metrics, reports,
        cutStatus: asCutStatus(a.cuttingStatusRaw),
        title: order?.code?.trim() || "Corte",
        plantName: plant?.name ?? "Sin planta",
        clientName: this.clientById.get(order?.clientID ?? "")?.name ?? "Sin cliente",
        styleName: this.styleById.get(order?.styleID ?? "")?.name ?? "Sin estilo",
      };
      this.assignmentInfos.set(a.id, info);
    }
    return info;
  }

  ledger(plant: PlantDTO): CapacityLedger {
    let l = this.ledgers.get(plant.id);
    if (!l) {
      const bookings = (this.assignmentsByPlant.get(plant.id) ?? []).flatMap((a) => {
        const date = parseDate(a.scheduledDate);
        return date ? [{ date, amount: (a.quantity ?? 0) * (a.unitPrice ?? 0) }] : [];
      });
      l = new CapacityLedger(plant.maxCapacity ?? 0, bookings);
      this.ledgers.set(plant.id, l);
    }
    return l;
  }

  /** Assignments the user may see (plant managers: only their plant — DOMAIN rule 8). */
  visibleAssignments(role: Role, plantId: string | null | undefined): AssignmentDTO[] {
    if (role === "Gerente de Planta") return plantId ? (this.assignmentsByPlant.get(plantId) ?? []) : [];
    return this.assignments;
  }
}
