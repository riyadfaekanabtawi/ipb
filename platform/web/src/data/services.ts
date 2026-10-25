// All writes go through here (ProductionService + CatalogService equivalents): validate the
// domain rules and role permissions, build the sync changes (including cascades), then commit
// them to the store, which pushes them to the server.

import { asReportKind, asRole, canEditReport, canManageOrders, isAdmin, type CutStatus, type ProjectStatus, type ReportKind, type Role } from "../domain/enums";
import { isPlausibleEmail, MIN_PASSWORD, userPolicyViolation, userViolationMessage, validateAssignment, assignmentErrorMessage, type Member, type UserChange } from "../domain/rules";
import type { AssignmentDTO, Change, ClientDTO, ContactDTO, CutOrderDTO, PlantDTO, ProjectDTO, ReportDTO, StyleDTO, TenantInfo, UserDTO } from "../domain/types";
import { fullName, parseDate } from "../lib/format";
import { hashPassword, makeSalt } from "../lib/password";
import { t, type MessageKey } from "../i18n";
import { DB } from "./db";
import { change, tombstone, type DataStore } from "./store";

export class DomainError extends Error {}

const fail = (message: string): never => {
  throw new DomainError(message);
};

const trim = (s: string | null | undefined) => (s ?? "").trim();
const orNull = (s: string | null | undefined) => trim(s) || null;
const uuid = () => crypto.randomUUID();

export interface Actor {
  me: UserDTO;
  role: Role;
  tenant: TenantInfo | null;
}

export class Services {
  constructor(private store: DataStore, private actor: () => Actor) {}

  private get db() {
    return new DB(this.store);
  }

  private get role() {
    return this.actor().role;
  }

  private get author() {
    return fullName(this.actor().me);
  }

  private async commit(changes: Change[]) {
    const result = await this.store.commit(changes);
    if (!result.ok) fail(result.message ?? t("svc.saveFailed"));
    return result;
  }

  private requireAdmin() {
    if (!isAdmin(this.role)) fail(t("svc.adminOnly"));
  }

  private requireOrders() {
    if (!canManageOrders(this.role)) fail(t("svc.notAllowed"));
  }

  // Orders ------------------------------------------------------------------------------

  async saveOrder(existing: CutOrderDTO | null, draft: {
    code: string; list: string; garment: string; quantity: number; unitPrice: number;
    clientID: string | null; styleID: string | null; internalDate: string | null; clientDate: string | null; notes: string;
  }): Promise<CutOrderDTO> {
    this.requireOrders();
    const code = trim(draft.code);
    if (!code) fail(t("svc.orderCodeRequired"));
    if (!(draft.quantity > 0) || !Number.isInteger(draft.quantity)) fail(t("svc.orderQuantityInvalid"));
    if (!(draft.unitPrice >= 0) || !Number.isFinite(draft.unitPrice)) fail(t("svc.unitPriceNegative"));
    if (existing) {
      const assigned = this.db.orderInfo(existing).assigned;
      if (draft.quantity < assigned) fail(t("svc.quantityBelowAssigned", { count: assigned }));
    }
    const order: CutOrderDTO = {
      ...(existing ?? { id: uuid() }),
      code, list: trim(draft.list), garment: trim(draft.garment), quantity: draft.quantity, unitPrice: draft.unitPrice,
      clientID: draft.clientID, styleID: draft.styleID, internalDate: draft.internalDate, clientDate: draft.clientDate,
      notes: orNull(draft.notes), editedBy: this.author,
    };
    await this.commit([change("orders", order)]);
    return order;
  }

  async deleteOrder(order: CutOrderDTO) {
    this.requireOrders();
    const db = this.db;
    const assignments = db.assignmentsByOrder.get(order.id) ?? [];
    if (assignments.some((a) => (db.reportsByAssignment.get(a.id) ?? []).length)) fail(t("svc.orderHasReports"));
    await this.commit([...assignments.map((a) => tombstone("assignments", a.id)), tombstone("orders", order.id)]);
  }

  // Assignment (DOMAIN rule 2) -----------------------------------------------------------

  async assign(order: CutOrderDTO, plant: PlantDTO, quantity: number, scheduledDate: string | null): Promise<AssignmentDTO> {
    this.requireOrders();
    const db = this.db;
    const result = validateAssignment({
      quantity, unitPrice: order.unitPrice ?? 0, remaining: db.orderInfo(order).remaining,
      date: parseDate(scheduledDate), ledger: db.ledger(plant),
    });
    if (!result.ok) fail(assignmentErrorMessage(result.error));
    const assignment: AssignmentDTO = {
      id: uuid(), quantity, unitPrice: order.unitPrice ?? 0, scheduledDate, cuttingStatusRaw: "en_espera", orderID: order.id, plantID: plant.id,
    };
    await this.commit([change("assignments", assignment), change("orders", { ...order, editedBy: this.author })]);
    return assignment;
  }

  async unassign(assignment: AssignmentDTO) {
    this.requireOrders();
    if ((this.db.reportsByAssignment.get(assignment.id) ?? []).length) fail(t("svc.assignmentHasReports"));
    await this.commit([tombstone("assignments", assignment.id)]);
  }

  // Reports (DOMAIN rule 4, 9) ------------------------------------------------------------

  private requireReport(kind: ReportKind) {
    if (!canEditReport(this.role, kind)) fail(t("svc.notAllowed"));
  }

  private newReport(kind: ReportKind, assignment: AssignmentDTO): ReportDTO {
    return { id: uuid(), kindRaw: kind, authorName: this.author, assignmentID: assignment.id };
  }

  private requireVisible(assignment: AssignmentDTO) {
    const { me, role } = this.actor();
    if (role === "Gerente de Planta" && assignment.plantID !== me.plantID) fail(t("svc.ownPlantOnly"));
  }

  async savePlantReport(assignment: AssignmentDTO, input: { operators: number; absences: number; produced: number; ironing: number; packing: number; warehouse: number }, editing?: ReportDTO) {
    this.requireReport("planta");
    this.requireVisible(assignment);
    const values = Object.values(input);
    if (values.some((v) => !Number.isInteger(v) || v < 0)) fail(t("svc.plantValuesInvalid"));
    const report: ReportDTO = { ...(editing ?? this.newReport("planta", assignment)), ...input };
    await this.commit([change("reports", report)]);
  }

  /** Exactly one cut report per assignment: creating a second fails; editing is allowed. */
  async saveCutReport(assignment: AssignmentDTO, status: CutStatus, realQuantity: number, editing?: ReportDTO) {
    this.requireReport("corte");
    this.requireOrders(); // the cut report also updates the assignment status
    const existing = (this.db.reportsByAssignment.get(assignment.id) ?? []).find((r) => asReportKind(r.kindRaw) === "corte");
    if (!editing && existing) fail(t("svc.cutReportExists"));
    if (!Number.isInteger(realQuantity) || realQuantity < 0) fail(t("svc.realQuantityNegative"));
    const report: ReportDTO = { ...(editing ?? this.newReport("corte", assignment)), cutStatusRaw: status, realQuantity: Math.max(0, realQuantity) };
    await this.commit([change("reports", report), change("assignments", { ...assignment, cuttingStatusRaw: status })]);
  }

  /** Kanban move: updates (or creates) the single cut report, keeping its real quantity. */
  async moveCut(assignment: AssignmentDTO, status: CutStatus) {
    const current = (this.db.reportsByAssignment.get(assignment.id) ?? []).find((r) => asReportKind(r.kindRaw) === "corte");
    await this.saveCutReport(assignment, status, current?.realQuantity ?? 0, current);
  }

  async saveShipmentReport(assignment: AssignmentDTO, number: string, quantity: number, editing?: ReportDTO) {
    this.requireReport("envio");
    this.requireVisible(assignment);
    if (!trim(number)) fail(t("svc.shipmentNumberRequired"));
    if (!Number.isInteger(quantity) || quantity <= 0) fail(t("svc.shippedQuantityInvalid"));
    const report: ReportDTO = { ...(editing ?? this.newReport("envio", assignment)), shipmentNumber: trim(number), shippedQuantity: quantity };
    await this.commit([change("reports", report)]);
  }

  async deleteReport(report: ReportDTO) {
    const kind = asReportKind(report.kindRaw);
    this.requireReport(kind);
    const changes: Change[] = [tombstone("reports", report.id)];
    const assignment = this.db.assignmentById.get(report.assignmentID ?? "");
    if (kind === "corte" && assignment) {
      this.requireOrders();
      changes.push(change("assignments", { ...assignment, cuttingStatusRaw: "en_espera" }));
    }
    await this.commit(changes);
  }

  // Catalogs ----------------------------------------------------------------------------

  private uniqueName(rows: { id: string; name?: string | null }[], raw: string, exceptId: string | undefined, required: MessageKey, taken: MessageKey) {
    const name = trim(raw);
    if (!name) fail(t(required));
    if (rows.some((r) => r.id !== exceptId && trim(r.name).toLocaleLowerCase("es") === name.toLocaleLowerCase("es"))) fail(t(taken));
    return name;
  }

  async savePlant(existing: PlantDTO | null, name: string, maxCapacity: number): Promise<PlantDTO> {
    this.requireAdmin();
    const db = this.db;
    const clean = this.uniqueName(db.plants, name, existing?.id, "svc.plantNameRequired", "svc.plantNameTaken");
    if (!(maxCapacity > 0) || !Number.isFinite(maxCapacity)) fail(t("svc.capacityInvalid"));
    const limit = this.actor().tenant?.maxPlants;
    if (!existing && limit != null && db.plants.length >= limit) fail(t("svc.plantLimit", { count: limit }));
    const plant: PlantDTO = { ...(existing ?? { id: uuid() }), name: clean, maxCapacity };
    await this.commit([change("plants", plant)]);
    return plant;
  }

  async deletePlant(plant: PlantDTO) {
    this.requireAdmin();
    const db = this.db;
    if ((db.assignmentsByPlant.get(plant.id) ?? []).length) fail(t("svc.plantHasCuts"));
    const managers = db.users.filter((u) => u.plantID === plant.id);
    await this.commit([...managers.map((u) => change("users", stripSecrets({ ...u, plantID: null }))), tombstone("plants", plant.id)]);
  }

  private contactChanges(drafts: ContactDraft[], existing: ContactDTO[], owner: { clientID?: string; supplierID?: string }): Change[] {
    const cleaned = drafts
      .map((d) => ({ ...d, name: trim(d.name), role: trim(d.role), email: trim(d.email), phone: trim(d.phone) }))
      .filter((d) => d.name || d.role || d.email || d.phone);
    const bad = cleaned.find((d) => d.email && !isPlausibleEmail(d.email));
    if (bad) fail(t("svc.emailInvalid", { email: bad.email }));
    const keep = new Set(cleaned.map((d) => d.id));
    const out: Change[] = existing.filter((c) => !keep.has(c.id)).map((c) => tombstone("contacts", c.id));
    cleaned.forEach((d, index) => {
      out.push(change("contacts", {
        id: d.id, name: d.name || null, role: d.role || null, email: d.email || null, phone: d.phone || null, sortIndex: index,
        clientID: owner.clientID ?? null, supplierID: owner.supplierID ?? null,
      }));
    });
    return out;
  }

  async saveClient(existing: ClientDTO | null, name: string, address: string, contacts: ContactDraft[]): Promise<ClientDTO> {
    this.requireAdmin();
    const db = this.db;
    const client: ClientDTO = { ...(existing ?? { id: uuid() }), name: this.uniqueName(db.clients, name, existing?.id, "svc.clientNameRequired", "svc.clientNameTaken"), address: orNull(address) };
    const contactChanges = this.contactChanges(contacts, existing ? (db.contactsByClient.get(existing.id) ?? []) : [], { clientID: client.id });
    // Projects keep a copy of the client name so they read well later.
    const projects = existing ? (db.projectsByClient.get(existing.id) ?? []).filter((p) => p.clientName !== client.name).map((p) => change("projects", { ...p, clientName: client.name })) : [];
    await this.commit([change("clients", client), ...contactChanges, ...projects]);
    return client;
  }

  async deleteClient(client: ClientDTO) {
    this.requireAdmin();
    const db = this.db;
    if ((db.ordersByClient.get(client.id) ?? []).length) fail(t("svc.clientHasCuts"));
    await this.commit([
      ...(db.contactsByClient.get(client.id) ?? []).map((c) => tombstone("contacts", c.id)),
      ...(db.projectsByClient.get(client.id) ?? []).map((p) => change("projects", { ...p, clientID: null, clientName: p.clientName ?? client.name })),
      tombstone("clients", client.id),
    ]);
  }

  async saveSupplier(existing: ClientDTO | null, name: string, address: string, contacts: ContactDraft[]): Promise<ClientDTO> {
    this.requireAdmin();
    const db = this.db;
    const supplier: ClientDTO = { ...(existing ?? { id: uuid() }), name: this.uniqueName(db.suppliers, name, existing?.id, "svc.supplierNameRequired", "svc.supplierNameTaken"), address: orNull(address) };
    const contactChanges = this.contactChanges(contacts, existing ? (db.contactsBySupplier.get(existing.id) ?? []) : [], { supplierID: supplier.id });
    await this.commit([change("suppliers", supplier), ...contactChanges]);
    return supplier;
  }

  async deleteSupplier(supplier: ClientDTO) {
    this.requireAdmin();
    await this.commit([...(this.db.contactsBySupplier.get(supplier.id) ?? []).map((c) => tombstone("contacts", c.id)), tombstone("suppliers", supplier.id)]);
  }

  async saveStyle(existing: StyleDTO | null, name: string, imageData: string | null): Promise<StyleDTO> {
    this.requireAdmin();
    const style: StyleDTO = { ...(existing ?? { id: uuid() }), name: this.uniqueName(this.db.styles, name, existing?.id, "svc.styleNameRequired", "svc.styleNameTaken"), imageData };
    await this.commit([change("styles", style)]);
    return style;
  }

  async deleteStyle(style: StyleDTO) {
    this.requireAdmin();
    const orders = this.db.ordersByStyle.get(style.id) ?? [];
    await this.commit([...orders.map((o) => change("orders", { ...o, styleID: null })), tombstone("styles", style.id)]);
  }

  async saveProject(existing: ProjectDTO | null, draft: {
    clientID: string | null; clientName: string; quantity: number; price: number; minutes: number; fabric: string;
    status: ProjectStatus; deliveryDate: string | null; notes: string; photoData: string | null;
  }): Promise<ProjectDTO> {
    this.requireAdmin();
    const client = this.db.clientById.get(draft.clientID ?? "");
    const freeName = trim(draft.clientName);
    if (!client && !freeName) fail(t("svc.projectClientRequired"));
    if ([draft.quantity, draft.price, draft.minutes].some((n) => !Number.isFinite(n) || n < 0)) fail(t("svc.projectNumbersNegative"));
    const project: ProjectDTO = {
      ...(existing ?? { id: uuid() }),
      clientID: client?.id ?? null, clientName: client?.name ?? freeName, quantity: Math.round(draft.quantity), price: draft.price, minutes: draft.minutes,
      fabric: orNull(draft.fabric), statusRaw: draft.status, deliveryDate: draft.deliveryDate, notes: orNull(draft.notes), photoData: draft.photoData,
    };
    await this.commit([change("projects", project)]);
    return project;
  }

  async setProjectStatus(project: ProjectDTO, status: ProjectStatus) {
    this.requireAdmin();
    await this.commit([change("projects", { ...project, statusRaw: status })]);
  }

  async deleteProject(project: ProjectDTO) {
    this.requireAdmin();
    await this.commit([tombstone("projects", project.id)]);
  }

  // Users (DOMAIN rule 10) ----------------------------------------------------------------

  private members(): Member[] {
    return this.db.users.map((u) => ({ id: u.id, role: asRole(u.roleRaw), isActive: u.isActive !== false }));
  }

  private checkPolicy(change: UserChange, user: UserDTO) {
    const violation = userPolicyViolation(change, { id: user.id, role: asRole(user.roleRaw), isActive: user.isActive !== false }, this.actor().me.id, this.members());
    if (violation) fail(userViolationMessage(violation));
  }

  private validUser(draft: UserDraft, exceptId?: string): UserDraft {
    const d = { ...draft, firstName: trim(draft.firstName), lastName: trim(draft.lastName), email: trim(draft.email).toLowerCase(), phone: trim(draft.phone) };
    if (!d.firstName || !d.email) fail(t("svc.userNameEmailRequired"));
    if (!isPlausibleEmail(d.email)) fail(t("svc.emailInvalid", { email: d.email }));
    if (d.role === "Gerente de Planta" && !d.plantID) fail(t("svc.plantManagerNeedsPlant"));
    if (this.db.users.some((u) => u.id !== exceptId && (u.email ?? "").toLowerCase() === d.email)) fail(t("svc.userEmailTaken"));
    return d;
  }

  async createUser(draft: UserDraft, password: string): Promise<UserDTO> {
    this.requireAdmin();
    const d = this.validUser(draft);
    if (password.length < MIN_PASSWORD) fail(t("svc.passwordTooShort", { count: MIN_PASSWORD }));
    const limit = this.actor().tenant?.maxUsers;
    if (limit != null && this.db.users.filter((u) => u.isActive !== false).length >= limit) fail(t("svc.userLimit", { count: limit }));
    const salt = makeSalt();
    const user: UserDTO = {
      id: uuid(), email: d.email, firstName: d.firstName, lastName: d.lastName || null, phone: d.phone || null, roleRaw: d.role,
      isActive: true, plantID: d.role === "Gerente de Planta" ? d.plantID : null, avatarData: d.avatarData,
      passwordSalt: salt, passwordHash: await hashPassword(password, salt),
    };
    await this.commit([change("users", user)]);
    return user;
  }

  async updateUser(user: UserDTO, draft: UserDraft) {
    this.requireAdmin();
    const d = this.validUser(draft, user.id);
    this.checkPolicy({ kind: "changeRole", role: d.role }, user);
    await this.commit([change("users", stripSecrets({
      ...user, email: d.email, firstName: d.firstName, lastName: d.lastName || null, phone: d.phone || null, roleRaw: d.role,
      plantID: d.role === "Gerente de Planta" ? d.plantID : null, avatarData: d.avatarData,
    }))]);
  }

  async setActive(user: UserDTO, active: boolean) {
    this.requireAdmin();
    if (!active) this.checkPolicy({ kind: "deactivate" }, user);
    if (active && user.isActive === false) {
      const limit = this.actor().tenant?.maxUsers;
      if (limit != null && this.db.users.filter((u) => u.isActive !== false).length >= limit) fail(t("svc.userLimit", { count: limit }));
    }
    await this.commit([change("users", stripSecrets({ ...user, isActive: active }))]);
  }

  async resetPassword(user: UserDTO, password: string) {
    this.requireAdmin();
    if (password.length < MIN_PASSWORD) fail(t("svc.passwordTooShort", { count: MIN_PASSWORD }));
    const salt = makeSalt();
    await this.commit([change("users", { ...user, passwordSalt: salt, passwordHash: await hashPassword(password, salt) })]);
  }

  async deleteUser(user: UserDTO) {
    this.requireAdmin();
    this.checkPolicy({ kind: "delete" }, user);
    await this.commit([tombstone("users", user.id)]);
  }
}

/**
 * Never echo a stored password hash back: the server keeps the current one when the field is
 * absent, and an old local copy must not undo a reset made elsewhere.
 */
function stripSecrets(user: UserDTO): UserDTO & { id: string } {
  const { passwordHash: _h, passwordSalt: _s, ...rest } = user;
  return rest;
}

export interface ContactDraft { id: string; name: string; role: string; email: string; phone: string }
export const newContactDraft = (): ContactDraft => ({ id: uuid(), name: "", role: "", email: "", phone: "" });

export interface UserDraft {
  firstName: string; lastName: string; email: string; phone: string; role: Role; plantID: string | null; avatarData: string | null;
}
