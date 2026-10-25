import { CloudOff, LogOut, Menu, Lock, RefreshCw } from "lucide-react";
import { useEffect, useMemo, useState } from "react";
import { NavLink, Navigate, Outlet, useLocation, useNavigate } from "react-router-dom";
import { groupTitle, landingFor, roleTitle, SECTION_GROUPS, sectionTitle, sectionsFor } from "../domain/enums";
import { t } from "../i18n";
import { isUrgent } from "../domain/rules";
import { useDB, useSession, useSyncState } from "../data/session";
import { fmtDate, fmtDateTime, fullName, parseDate } from "../lib/format";
import { useUrgencyWindow } from "../lib/prefs";
import { Avatar, Spinner } from "../ui/kit";
import { SECTION_ICON, SECTION_PATH, sectionForPath } from "./nav";

export function Shell() {
  const { user, role, tenant, logout, store } = useSession();
  const sync = useSyncState();
  const db = useDB();
  const [urgency] = useUrgencyWindow();
  const location = useLocation();
  const navigate = useNavigate();
  const [open, setOpen] = useState(false);
  const allowed = sectionsFor(role);
  const section = sectionForPath(location.pathname);

  useEffect(() => setOpen(false), [location.pathname]);
  useEffect(() => {
    document.title = section ? `${sectionTitle(section)} · Trama` : "Trama";
  }, [section]);

  const urgentCount = useMemo(() => {
    if (!allowed.includes("shipments")) return 0;
    return db.visibleAssignments(role, user.plantID).filter((a) => {
      const info = db.assignmentInfo(a);
      return isUrgent(info.metrics.toShip, parseDate(info.order?.clientDate), urgency);
    }).length;
  }, [db, role, user.plantID, urgency, allowed]);

  if (!section || !allowed.includes(section)) return <Navigate to={SECTION_PATH[landingFor(role)]} replace />;

  const licence = sync.licence;
  return (
    <div className={`shell ${open ? "nav-open" : ""}`}>
      <div className="scrim" onClick={() => setOpen(false)} />
      <aside className="sidebar">
        <div className="brand-row">
          <img className="brand-mark" src="/icon.png" alt="" />
          <div style={{ minWidth: 0 }}>
            <div className="brand-name">Trama</div>
            <div className="brand-sub" title={tenant.name}>{tenant.name}</div>
          </div>
        </div>
        {SECTION_GROUPS.map((g) => {
          const items = g.sections.filter((s) => allowed.includes(s));
          if (!items.length) return null;
          return (
            <div key={g.key}>
              <div className="nav-group">{groupTitle(g.key)}</div>
              {items.map((s) => {
                const I = SECTION_ICON[s];
                return (
                  <NavLink key={s} to={SECTION_PATH[s]} className={({ isActive }) => `nav-link ${isActive ? "active" : ""}`}>
                    <I />
                    <span>{sectionTitle(s)}</span>
                    {s === "shipments" && urgentCount > 0 && <span className="nav-badge">{urgentCount}</span>}
                  </NavLink>
                );
              })}
            </div>
          );
        })}
        <div className="sidebar-foot">
          <div className="row small muted" style={{ padding: "0 8px" }} title={sync.lastSyncAt ? t("shell.lastSync", { date: fmtDateTime(sync.lastSyncAt) }) : undefined}>
            <span className={`sync-dot ${sync.status}`} />
            <span className="grow">
              {sync.status === "syncing" ? t("shell.syncing") : sync.status === "offline" ? t("shell.offlinePending") : sync.status === "error" ? t("shell.syncError") : t("shell.synced")}
              {sync.pending > 0 && ` (${sync.pending})`}
            </span>
          </div>
          <div className="me-row">
            <Avatar name={fullName(user)} image={user.avatarData} size={36} />
            <div className="meta">
              <div className="name">{fullName(user)}</div>
              <div className="role">{roleTitle(role)}</div>
            </div>
            <button
              type="button"
              className="btn ghost icon"
              title={t("shell.signOut")}
              aria-label={t("shell.signOut")}
              onClick={async () => {
                if (sync.pending > 0 && !confirm(t("shell.confirmSignOut"))) return;
                await logout();
                navigate("/login");
              }}
            >
              <LogOut />
            </button>
          </div>
        </div>
      </aside>
      <div className="main">
        <header className="topbar">
          <button type="button" className="btn ghost icon menu-btn" onClick={() => setOpen(true)} aria-label={t("shell.menu")}>
            <Menu />
          </button>
          <h1>{sectionTitle(section)}</h1>
          <div className="spacer" />
          <button type="button" className="btn ghost sm" onClick={() => void store.sync().catch(() => {})} title={t("shell.syncNow")} aria-label={t("shell.syncNow")}>
            <RefreshCw /> <span className="tiny faint">{sync.lastSyncAt ? fmtDateTime(sync.lastSyncAt) : "—"}</span>
          </button>
        </header>
        <div className="content">
          {licence && !licence.writable && (
            <div className="banner warn">
              <Lock />
              <span>
                {licence.status === "suspended"
                  ? t("shell.licenceSuspended")
                  : t("shell.licenceExpired", { date: fmtDate(licence.expiresAt) })}{" "}
                {t("shell.contactSupport")}
              </span>
            </div>
          )}
          {sync.status === "offline" && (
            <div className="banner info">
              <CloudOff />
              <span>{t("shell.offlineBanner")}</span>
            </div>
          )}
          {!sync.loaded ? (
            <div className="empty"><Spinner /><p>{t("shell.downloading")}</p></div>
          ) : (
            <Outlet />
          )}
        </div>
      </div>
    </div>
  );
}

