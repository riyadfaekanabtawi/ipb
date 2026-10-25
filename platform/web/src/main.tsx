import { lazy, StrictMode, Suspense } from "react";
import { createRoot } from "react-dom/client";
import { BrowserRouter, Navigate, Route, Routes } from "react-router-dom";
import { ForgotPage, LoginPage, SetPasswordPage } from "./app/AuthPages";
import { BoardPage, AssignmentPage, ProductionPage, ShipmentsPage } from "./app/ProductionPages";
import { CalendarPage } from "./app/CalendarPage";
import { PartiesPage, PartyDetailPage, PlantDetailPage, PlantsPage, StylesPage } from "./app/CatalogPages";
import { DashboardPage } from "./app/DashboardPage";
import { OrderDetailPage, OrdersPage } from "./app/OrdersPage";
import { ProjectsPage } from "./app/ProjectsPage";
import { Shell } from "./app/Shell";
import { CalculatorPage, SettingsPage } from "./app/ToolsPages";
import { UsersPage } from "./app/UsersPage";
import { landingFor } from "./domain/enums";
import { SessionProvider, useAuth, useSession } from "./data/session";
import { SECTION_PATH } from "./app/nav";
import { applyTheme, initialTheme } from "./lib/prefs";
import { Spinner, Toaster } from "./ui/kit";
import "./styles.css";

const AdminApp = lazy(() => import("./admin/AdminApp"));

applyTheme(initialTheme());

function RequireSession({ children }: { children: React.ReactNode }) {
  const { phase } = useAuth();
  if (phase === "loading") return <div className="center-screen"><Spinner /></div>;
  if (phase === "anon") return <Navigate to="/login" replace />;
  return <>{children}</>;
}

function GuestOnly({ children }: { children: React.ReactNode }) {
  const { phase } = useAuth();
  if (phase === "loading") return <div className="center-screen"><Spinner /></div>;
  if (phase === "ready") return <Navigate to="/app" replace />;
  return <>{children}</>;
}

function Landing() {
  const { role } = useSession();
  return <Navigate to={SECTION_PATH[landingFor(role)]} replace />;
}

function App() {
  return (
    <Routes>
      <Route path="/login" element={<GuestOnly><LoginPage /></GuestOnly>} />
      <Route path="/olvide" element={<ForgotPage />} />
      <Route path="/activar" element={<SetPasswordPage mode="invite" />} />
      <Route path="/restablecer" element={<SetPasswordPage mode="reset" />} />
      <Route path="/admin/*" element={<Suspense fallback={<div className="center-screen"><Spinner /></div>}><AdminApp /></Suspense>} />
      <Route path="/app" element={<RequireSession><Landing /></RequireSession>} />
      <Route path="/app/*" element={<RequireSession><Shell /></RequireSession>}>
        <Route path="dashboard" element={<DashboardPage />} />
        <Route path="cortes" element={<OrdersPage />} />
        <Route path="cortes/:id" element={<OrderDetailPage />} />
        <Route path="tablero" element={<BoardPage />} />
        <Route path="produccion" element={<ProductionPage />} />
        <Route path="produccion/:id" element={<AssignmentPage />} />
        <Route path="envios" element={<ShipmentsPage />} />
        <Route path="calendario" element={<CalendarPage />} />
        <Route path="plantas" element={<PlantsPage />} />
        <Route path="plantas/:id" element={<PlantDetailPage />} />
        <Route path="clientes" element={<PartiesPage kind="client" />} />
        <Route path="clientes/:id" element={<PartyDetailPage kind="client" />} />
        <Route path="proveedores" element={<PartiesPage kind="supplier" />} />
        <Route path="proveedores/:id" element={<PartyDetailPage kind="supplier" />} />
        <Route path="estilos" element={<StylesPage />} />
        <Route path="proyectos" element={<ProjectsPage />} />
        <Route path="usuarios" element={<UsersPage />} />
        <Route path="calculadora" element={<CalculatorPage />} />
        <Route path="ajustes" element={<SettingsPage />} />
      </Route>
      <Route path="*" element={<Navigate to="/app" replace />} />
    </Routes>
  );
}

createRoot(document.getElementById("root")!).render(
  <StrictMode>
    <BrowserRouter>
      <SessionProvider>
        <App />
        <Toaster />
      </SessionProvider>
    </BrowserRouter>
  </StrictMode>,
);
