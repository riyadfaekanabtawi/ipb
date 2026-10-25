import {
  BarChart3, Building2, Calculator, CalendarDays, Columns3, FolderKanban, LayoutGrid, Scissors, Settings, Shirt, Truck, TriangleAlert, UserCog, Users,
} from "lucide-react";
import type { Section } from "../domain/enums";
import type { Icon } from "../ui/kit";

export const SECTION_PATH: Record<Section, string> = {
  dashboard: "/app/dashboard",
  orders: "/app/cortes",
  board: "/app/tablero",
  production: "/app/produccion",
  shipments: "/app/envios",
  calendar: "/app/calendario",
  plants: "/app/plantas",
  clients: "/app/clientes",
  suppliers: "/app/proveedores",
  styles: "/app/estilos",
  projects: "/app/proyectos",
  users: "/app/usuarios",
  calculator: "/app/calculadora",
  settings: "/app/ajustes",
};

export const SECTION_ICON: Record<Section, Icon> = {
  dashboard: LayoutGrid,
  orders: Scissors,
  board: Columns3,
  production: BarChart3,
  shipments: TriangleAlert,
  calendar: CalendarDays,
  plants: Building2,
  clients: Users,
  suppliers: Truck,
  styles: Shirt,
  projects: FolderKanban,
  users: UserCog,
  calculator: Calculator,
  settings: Settings,
};

export function sectionForPath(pathname: string): Section | null {
  const entry = (Object.entries(SECTION_PATH) as [Section, string][]).find(([, p]) => pathname === p || pathname.startsWith(p + "/"));
  return entry ? entry[0] : null;
}

export const paths = {
  order: (id: string) => `/app/cortes/${id}`,
  assignment: (id: string) => `/app/produccion/${id}`,
  plant: (id: string) => `/app/plantas/${id}`,
  client: (id: string) => `/app/clientes/${id}`,
  supplier: (id: string) => `/app/proveedores/${id}`,
};
