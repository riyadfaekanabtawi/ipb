// Sync payloads: the same DTO shapes as the iOS/Android backup files
// (ios/Trama/Core/Services/BackupService.swift). Dates are ISO-8601 strings, images base64,
// relationships UUIDs. Every field is optional on the wire, so readers must tolerate gaps.

export const ENTITIES = ["plants", "clients", "suppliers", "contacts", "styles", "orders", "assignments", "reports", "projects", "users"] as const;
export type Entity = (typeof ENTITIES)[number];

interface Stamped {
  id: string;
  remoteID?: number | null;
  createdAt?: string | null;
  updatedAt?: string | null;
}

export interface PlantDTO extends Stamped {
  name?: string | null;
  maxCapacity?: number | null;
}

export interface ClientDTO extends Stamped {
  name?: string | null;
  address?: string | null;
}

export type SupplierDTO = ClientDTO;

export interface ContactDTO {
  id: string;
  name?: string | null;
  email?: string | null;
  phone?: string | null;
  role?: string | null;
  sortIndex?: number | null;
  clientID?: string | null;
  supplierID?: string | null;
  updatedAt?: string | null;
}

export interface StyleDTO extends Stamped {
  name?: string | null;
  imageData?: string | null;
}

export interface CutOrderDTO extends Stamped {
  code?: string | null;
  list?: string | null;
  garment?: string | null;
  quantity?: number | null;
  unitPrice?: number | null;
  internalDate?: string | null;
  clientDate?: string | null;
  editedBy?: string | null;
  notes?: string | null;
  clientID?: string | null;
  styleID?: string | null;
}

export interface AssignmentDTO extends Stamped {
  quantity?: number | null;
  unitPrice?: number | null;
  scheduledDate?: string | null;
  cuttingStatusRaw?: string | null;
  orderID?: string | null;
  plantID?: string | null;
}

export interface ReportDTO extends Stamped {
  kindRaw?: string | null;
  cutStatusRaw?: string | null;
  authorName?: string | null;
  operators?: number | null;
  absences?: number | null;
  produced?: number | null;
  ironing?: number | null;
  packing?: number | null;
  warehouse?: number | null;
  realQuantity?: number | null;
  shipmentNumber?: string | null;
  shippedQuantity?: number | null;
  assignmentID?: string | null;
}

export interface ProjectDTO extends Stamped {
  clientName?: string | null;
  quantity?: number | null;
  price?: number | null;
  minutes?: number | null;
  fabric?: string | null;
  deliveryDate?: string | null;
  notes?: string | null;
  photoData?: string | null;
  statusRaw?: string | null;
  clientID?: string | null;
}

export interface UserDTO extends Stamped {
  email?: string | null;
  firstName?: string | null;
  lastName?: string | null;
  phone?: string | null;
  roleRaw?: string | null;
  isActive?: boolean | null;
  passwordHash?: string | null;
  passwordSalt?: string | null;
  avatarData?: string | null;
  plantID?: string | null;
}

export interface EntityMap {
  plants: PlantDTO;
  clients: ClientDTO;
  suppliers: SupplierDTO;
  contacts: ContactDTO;
  styles: StyleDTO;
  orders: CutOrderDTO;
  assignments: AssignmentDTO;
  reports: ReportDTO;
  projects: ProjectDTO;
  users: UserDTO;
}

/** One change on the sync wire (push and pull). */
export interface Change<E extends Entity = Entity> {
  entity: E;
  id: string;
  updatedAt: string;
  deleted?: boolean;
  data?: EntityMap[E] | null;
}

export interface ServerChange extends Change {
  version: number;
  deleted: boolean;
}

export interface Licence {
  plan: "web" | "planta" | "multiplanta" | "empresa";
  status: "active" | "suspended" | "expired";
  expiresAt: string;
  writable: boolean;
}

export interface TenantInfo {
  id: string;
  name: string;
  plan: Licence["plan"];
  maxUsers?: number;
  maxDevices?: number;
  maxPlants?: number;
}
