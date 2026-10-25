// Vendor admin portal: companies, licences, devices and invitations (/api/admin/*).

import { ArrowLeft, Ban, Building2, CalendarClock, Check, Copy, DollarSign, KeyRound, LogOut, Mail, Monitor, Plus, RotateCcw, Search, Smartphone, Tablet } from "lucide-react";
import { useCallback, useEffect, useMemo, useState, useSyncExternalStore } from "react";
import { Link, Navigate, Route, Routes, useNavigate, useParams } from "react-router-dom";
import { PLAN_IDS, PLANS, type Plan } from "../../../src/plans";
import { AuthLayout, PasswordInput } from "../app/AuthPages";
import { ROLE_TITLE, asRole } from "../domain/enums";
import { adminLogin, adminLogout, adminName, adminRequest, adminToken, ApiError, onAdminChange } from "../lib/api";
import { fmtDate, fmtDateTime, fmtInt } from "../lib/format";
import { toast, toastError } from "../lib/toast";
import { Card, EmptyState, Field, FormModal, InfoRow, KPITile, Modal, NumberField, PageHead, Pill, Seg, SelectField, Spinner, TextField } from "../ui/kit";
import { SetPasswordPage } from "../app/AuthPages";

const PLAN_NAME: Record<Plan, string> = { web: "Web", planta: "Planta", multiplanta: "Multiplanta", empresa: "Empresa" };
const STATUS_LABEL = { active: "Activa", expired: "Vencida", suspended: "Suspendida" } as const;
const STATUS_TINT = { active: "success", expired: "warning", suspended: "danger" } as const;

interface TenantSummary {
  id: string; name: string; plan: Plan; status: "active" | "suspended";
  licence: { status: "active" | "expired" | "suspended"; expiresAt: string; writable: boolean };
  limits: { maxUsers: number; maxDevices: number; maxPlants: number };
  usage: { users: number; devices: number; lastSeenAt: string | null };
  contactEmail: string | null; notes: string | null; priceUsdMonthly: number; createdAt: string;
}
interface Stats { tenants: number; active: number; byPlan: Record<Plan, number>; mrrUsd: number; expiringSoon: number }
interface Detail {
  tenant: TenantSummary;
  users: { id: string; email: string; name: string; role: string; isActive: boolean; hasPassword: boolean }[];
  devices: { id: string; userId: string; platform: "ios" | "android" | "web"; name: string | null; createdAt: string; lastSeenAt: string; active: boolean }[];
  audit: { at: string; actor: string; action: string; detail: Record<string, unknown> | null }[];
}

const usd = (n: number) => new Intl.NumberFormat("es-MX", { style: "currency", currency: "USD", maximumFractionDigits: 0 }).format(n);
const daysUntil = (iso: string) => Math.ceil((new Date(iso).getTime() - Date.now()) / 86_400_000);

function useAdminAuthed() {
  return useSyncExternalStore(onAdminChange, () => !!adminToken());
}

export default function AdminApp() {
  useEffect(() => {
    document.title = "Admin · Trama";
  }, []);
  return (
    <Routes>
      <Route path="login" element={<AdminLogin />} />
      <Route path="activar" element={<SetPasswordPage mode="admin" />} />
      <Route path="*" element={<AdminGuard />} />
    </Routes>
  );
}

function AdminGuard() {
  const authed = useAdminAuthed();
  if (!authed) return <Navigate to="/admin/login" replace />;
  return (
    <div className="weave-bg" style={{ minHeight: "100vh" }}>
      <header className="topbar" style={{ padding: "12px 24px" }}>
        <Link to="/admin" className="row" style={{ textDecoration: "none", color: "inherit" }}>
          <img src="/icon.png" alt="" width={32} height={32} style={{ borderRadius: 9 }} />
          <span className="bold" style={{ fontSize: 17 }}>Trama</span>
          <Pill text="Admin" tint="thread" />
        </Link>
        <div className="spacer" />
        <span className="small muted">{adminName()}</span>
        <button className="btn ghost sm" onClick={() => adminLogout()}><LogOut /> Salir</button>
      </header>
      <main className="content">
        <Routes>
          <Route index element={<AdminHome />} />
          <Route path="empresas/:id" element={<CompanyPage />} />
          <Route path="*" element={<Navigate to="/admin" replace />} />
        </Routes>
      </main>
    </div>
  );
}

function AdminLogin() {
  const navigate = useNavigate();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  if (adminToken()) return <Navigate to="/admin" replace />;
  return (
    <AuthLayout kicker="Portal de administración" headline="Licencias y empresas, en un solo lugar." copy="Crea empresas, envía invitaciones, ajusta planes y libera dispositivos.">
      <div><h2>Portal de administración</h2><p className="muted" style={{ margin: "6px 0 0" }}>Solo para el equipo de Trama.</p></div>
      <form className="col" style={{ gap: 14 }} onSubmit={async (e) => {
        e.preventDefault();
        setBusy(true);
        setError(null);
        try {
          await adminLogin(email, password);
          navigate("/admin", { replace: true });
        } catch (err) {
          setError(err instanceof Error ? err.message : "No se pudo iniciar sesión.");
        } finally {
          setBusy(false);
        }
      }}>
        <TextField label="Correo electrónico" type="email" value={email} onChange={setEmail} autoComplete="username" autoFocus required />
        <Field label="Contraseña"><PasswordInput value={password} onChange={setPassword} autoComplete="current-password" /></Field>
        {error && <div className="banner error">{error}</div>}
        <button className="btn primary block" disabled={busy || !email || !password}>{busy ? "Entrando…" : "Entrar"}</button>
      </form>
    </AuthLayout>
  );
}

function useLoad<T>(fn: () => Promise<T>, deps: unknown[]) {
  const [data, setData] = useState<T | null>(null);
  const [error, setError] = useState<string | null>(null);
  // eslint-disable-next-line react-hooks/exhaustive-deps
  const load = useCallback(() => fn().then(setData).catch((e) => { if (!(e instanceof ApiError && e.status === 401)) setError(e.message); }), deps);
  useEffect(() => { void load(); }, [load]);
  return { data, error, reload: load };
}

// Home: stats + companies -----------------------------------------------------------------------

function AdminHome() {
  const navigate = useNavigate();
  const stats = useLoad(() => adminRequest<Stats>("GET", "/stats"), []);
  const list = useLoad(() => adminRequest<{ tenants: TenantSummary[] }>("GET", "/tenants"), []);
  const [query, setQuery] = useState("");
  const [plan, setPlan] = useState<Plan | "all">("all");
  const [status, setStatus] = useState<"all" | "active" | "expired" | "suspended" | "expiring">("all");
  const [creating, setCreating] = useState(false);
  const [invite, setInvite] = useState<{ link: string; name: string } | null>(null);

  const rows = useMemo(() => (list.data?.tenants ?? []).filter((t) => {
    const q = query.trim().toLowerCase();
    if (q && !t.name.toLowerCase().includes(q) && !(t.contactEmail ?? "").toLowerCase().includes(q)) return false;
    if (plan !== "all" && t.plan !== plan) return false;
    if (status === "expiring") return t.licence.status === "active" && daysUntil(t.licence.expiresAt) <= 30;
    if (status !== "all" && t.licence.status !== status) return false;
    return true;
  }), [list.data, query, plan, status]);

  const s = stats.data;
  return (
    <>
      <PageHead title="Empresas" subtitle="Clientes de Trama, sus licencias y su uso.">
        <button className="btn primary" onClick={() => setCreating(true)}><Plus /> Nueva empresa</button>
      </PageHead>
      <div className="grid kpis">
        <KPITile title="MRR" value={s ? usd(s.mrrUsd) : "—"} icon={DollarSign} tint="success" footnote="Licencias activas" />
        <KPITile title="Empresas activas" value={s ? `${s.active} / ${s.tenants}` : "—"} icon={Building2} />
        <KPITile title="Vencen en 30 días" value={s ? fmtInt(s.expiringSoon) : "—"} icon={CalendarClock} tint={s?.expiringSoon ? "warning" : "success"} onClick={() => setStatus("expiring")} />
        {PLAN_IDS.map((p) => <KPITile key={p} title={`Plan ${PLAN_NAME[p]}`} value={s ? fmtInt(s.byPlan[p] ?? 0) : "—"} icon={Building2} tint="info" footnote={`US$${PLANS[p].priceUsdMonthly}/mes`} onClick={() => setPlan(p)} />)}
      </div>
      <div className="row wrap">
        <div className="input-affix" style={{ flex: "1 1 260px", maxWidth: 420 }}><Search /><input className="input" type="search" placeholder="Buscar empresa o correo" value={query} onChange={(e) => setQuery(e.target.value)} /></div>
        <select className="input" style={{ width: "auto" }} value={plan} onChange={(e) => setPlan(e.target.value as Plan | "all")} aria-label="Plan">
          <option value="all">Todos los planes</option>
          {PLAN_IDS.map((p) => <option key={p} value={p}>{PLAN_NAME[p]}</option>)}
        </select>
        <Seg value={status} onChange={setStatus} options={[{ value: "all", label: "Todas" }, { value: "active", label: "Activas" }, { value: "expiring", label: "Por vencer" }, { value: "expired", label: "Vencidas" }, { value: "suspended", label: "Suspendidas" }]} />
      </div>
      <Card className="pad-0">
        {list.error ? <div className="banner error" style={{ margin: 16 }}>{list.error}</div> : !list.data ? <div className="empty"><Spinner /></div> : rows.length === 0 ? (
          <EmptyState icon={Building2} title="Sin empresas" message="Crea la primera empresa para enviar la invitación a su administrador." />
        ) : (
          <div className="table-wrap">
            <table className="table">
              <thead><tr><th>Empresa</th><th>Plan</th><th>Licencia</th><th>Vence</th><th className="num">Usuarios</th><th className="num">Dispositivos</th><th>Última actividad</th><th className="num">USD/mes</th></tr></thead>
              <tbody>
                {rows.map((t) => {
                  const days = daysUntil(t.licence.expiresAt);
                  return (
                    <tr key={t.id} className="click" onClick={() => navigate(`/admin/empresas/${t.id}`)}>
                      <td><div className="bold">{t.name}</div><div className="tiny faint">{t.contactEmail ?? "—"}</div></td>
                      <td><Pill text={PLAN_NAME[t.plan]} tint="brand" /></td>
                      <td><Pill text={STATUS_LABEL[t.licence.status]} tint={STATUS_TINT[t.licence.status]} /></td>
                      <td>{fmtDate(t.licence.expiresAt)}{t.licence.status === "active" && days <= 30 && <div className="tiny" style={{ color: "var(--warning)" }}>en {days} días</div>}</td>
                      <td className="num">{t.usage.users} / {t.limits.maxUsers}</td>
                      <td className="num">{t.usage.devices} / {t.limits.maxDevices}</td>
                      <td className="small muted">{t.usage.lastSeenAt ? fmtDateTime(t.usage.lastSeenAt) : "Nunca"}</td>
                      <td className="num">{usd(t.priceUsdMonthly)}</td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        )}
      </Card>
      {creating && <CreateCompany onClose={() => setCreating(false)} onCreated={(link, name) => { setInvite({ link, name }); void list.reload(); void stats.reload(); }} />}
      {invite && <InviteLinkModal title={`${invite.name} creada`} link={invite.link} onClose={() => setInvite(null)} />}
    </>
  );
}

function InviteLinkModal({ title, link, onClose }: { title: string; link: string; onClose: () => void }) {
  const [copied, setCopied] = useState(false);
  return (
    <Modal title={title} onClose={onClose} size="narrow" footer={<button className="btn primary" onClick={onClose}>Listo</button>}>
      <p className="small muted" style={{ margin: 0 }}>Enviamos la invitación por correo (si está configurado). También puedes compartir este enlace; vence en 72 horas y solo se puede usar una vez.</p>
      <div className="row">
        <input className="input grow" readOnly value={link} onFocus={(e) => e.target.select()} />
        <button className="btn" onClick={async () => { await navigator.clipboard?.writeText(link); setCopied(true); toast("Enlace copiado"); }}>{copied ? <Check /> : <Copy />} {copied ? "Copiado" : "Copiar"}</button>
      </div>
    </Modal>
  );
}

function CreateCompany({ onClose, onCreated }: { onClose: () => void; onCreated: (link: string, name: string) => void }) {
  const [name, setName] = useState("");
  const [plan, setPlan] = useState<Plan>("planta");
  const [months, setMonths] = useState(12);
  const [contactEmail, setContactEmail] = useState("");
  const [first, setFirst] = useState("");
  const [last, setLast] = useState("");
  const [email, setEmail] = useState("");
  const [notes, setNotes] = useState("");
  const [override, setOverride] = useState(false);
  const [limits, setLimits] = useState({ maxUsers: PLANS.planta.maxUsers, maxDevices: PLANS.planta.maxDevices, maxPlants: PLANS.planta.maxPlants });
  const choosePlan = (p: Plan) => { setPlan(p); setLimits({ maxUsers: PLANS[p].maxUsers, maxDevices: PLANS[p].maxDevices, maxPlants: PLANS[p].maxPlants }); };
  const canSave = name.trim().length >= 2 && first.trim().length > 0 && /.+@.+\..+/.test(email) && months >= 1 && months <= 60;

  return (
    <FormModal title="Nueva empresa" onClose={onClose} canSave={canSave} saveLabel="Crear y enviar invitación"
      onSave={async () => {
        const out = await adminRequest<{ tenant: TenantSummary; inviteLink: string }>("POST", "/tenants", {
          name: name.trim(), plan, months, contactEmail: contactEmail.trim() || undefined, notes: notes.trim() || undefined,
          ...(override ? limits : {}),
          admin: { firstName: first.trim(), lastName: last.trim(), email: email.trim() },
        });
        onCreated(out.inviteLink, out.tenant.name);
      }}>
      <div className="form-section"><h4>Empresa</h4>
        <div className="form-grid">
          <TextField label="Nombre" value={name} onChange={setName} autoFocus />
          <TextField label="Correo de contacto (facturación)" type="email" value={contactEmail} onChange={setContactEmail} placeholder="Opcional" />
        </div>
      </div>
      <div className="form-section"><h4>Licencia</h4>
        <div className="form-grid">
          <SelectField label="Plan" value={plan} onChange={(v) => v && choosePlan(v)} options={PLAN_IDS.map((p) => ({ value: p, label: `${PLAN_NAME[p]} · US$${PLANS[p].priceUsdMonthly}/mes` }))} />
          <NumberField label="Meses" value={months} onChange={setMonths} integer hint="De 1 a 60" />
        </div>
        <label className="check small"><input type="checkbox" checked={override} onChange={(e) => setOverride(e.target.checked)} /> Ajustar límites del plan</label>
        {override ? (
          <div className="form-grid">
            <NumberField label="Usuarios" value={limits.maxUsers} onChange={(v) => setLimits({ ...limits, maxUsers: v })} integer />
            <NumberField label="Dispositivos" value={limits.maxDevices} onChange={(v) => setLimits({ ...limits, maxDevices: v })} integer />
            <NumberField label="Plantas" value={limits.maxPlants} onChange={(v) => setLimits({ ...limits, maxPlants: v })} integer />
          </div>
        ) : <span className="tiny faint">{PLANS[plan].maxUsers} usuarios · {PLANS[plan].maxDevices} dispositivos · {PLANS[plan].maxPlants} planta(s){PLANS[plan].nativeApps ? "" : " · solo navegador"}</span>}
      </div>
      <div className="form-section"><h4>Administrador de la empresa</h4>
        <div className="form-grid">
          <TextField label="Nombre" value={first} onChange={setFirst} />
          <TextField label="Apellido" value={last} onChange={setLast} />
          <TextField label="Correo" type="email" value={email} onChange={setEmail} />
        </div>
      </div>
      <Field label="Notas internas"><textarea className="input" value={notes} onChange={(e) => setNotes(e.target.value)} placeholder="Condiciones, contacto comercial…" /></Field>
    </FormModal>
  );
}

// Company detail ------------------------------------------------------------------------------------

function CompanyPage() {
  const { id = "" } = useParams();
  const { data, error, reload } = useLoad(() => adminRequest<Detail>("GET", `/tenants/${id}`), [id]);
  const [editingLimits, setEditingLimits] = useState(false);
  const [changingPlan, setChangingPlan] = useState(false);
  const [invite, setInvite] = useState<{ link: string; name: string } | null>(null);
  const [busy, setBusy] = useState(false);

  if (error) return <div className="banner error">{error}</div>;
  if (!data) return <div className="empty"><Spinner /></div>;
  const t = data.tenant;
  const userName = (uid: string) => data.users.find((u) => u.id === uid)?.name || data.users.find((u) => u.id === uid)?.email || "—";

  const patch = async (body: Record<string, unknown>, message: string) => {
    setBusy(true);
    try {
      await adminRequest("PATCH", `/tenants/${t.id}`, body);
      toast(message);
      await reload();
    } catch (e) {
      toastError(e);
    } finally {
      setBusy(false);
    }
  };

  return (
    <>
      <div className="row"><Link to="/admin" className="btn ghost sm"><ArrowLeft /> Empresas</Link></div>
      <PageHead title={t.name} subtitle={`Cliente desde ${fmtDate(t.createdAt)}${t.contactEmail ? ` · ${t.contactEmail}` : ""}`}>
        <Pill text={STATUS_LABEL[t.licence.status]} tint={STATUS_TINT[t.licence.status]} />
        {t.status === "suspended"
          ? <button className="btn" disabled={busy} onClick={() => patch({ status: "active" }, "Licencia reactivada")}><RotateCcw /> Reactivar</button>
          : <button className="btn danger" disabled={busy} onClick={() => confirm(`¿Suspender ${t.name}? Sus usuarios no podrán iniciar sesión y los datos quedarán en solo lectura.`) && patch({ status: "suspended" }, "Licencia suspendida")}><Ban /> Suspender</button>}
      </PageHead>
      <div className="grid kpis">
        <KPITile title="Plan" value={PLAN_NAME[t.plan]} icon={Building2} footnote={`US$${t.priceUsdMonthly}/mes`} onClick={() => setChangingPlan(true)} />
        <KPITile title="Vence" value={fmtDate(t.licence.expiresAt)} icon={CalendarClock} tint={t.licence.status === "active" ? (daysUntil(t.licence.expiresAt) <= 30 ? "warning" : "success") : "danger"} footnote={t.licence.status === "active" ? `En ${daysUntil(t.licence.expiresAt)} días` : "Solo lectura"} />
        <KPITile title="Usuarios activos" value={`${t.usage.users} / ${t.limits.maxUsers}`} icon={KeyRound} tint="info" onClick={() => setEditingLimits(true)} />
        <KPITile title="Plantas permitidas" value={fmtInt(t.limits.maxPlants)} icon={Building2} tint="thread" onClick={() => setEditingLimits(true)} />
        <KPITile title="Dispositivos" value={`${data.devices.filter((d) => d.active && d.platform !== "web").length} / ${t.limits.maxDevices}`} icon={Tablet} tint="brand" onClick={() => setEditingLimits(true)} />
      </div>
      <div className="grid two">
        <Card title="Licencia">
          <InfoRow label="Estado" value={STATUS_LABEL[t.licence.status]} />
          <InfoRow label="Vigente hasta" value={fmtDate(t.licence.expiresAt)} />
          <div className="row wrap" style={{ marginTop: 12 }}>
            <span className="small muted">Extender:</span>
            {[1, 3, 6, 12].map((m) => <button key={m} className="btn sm" disabled={busy} onClick={() => patch({ extendMonths: m }, `Licencia extendida ${m} ${m === 1 ? "mes" : "meses"}`)}>+{m} {m === 1 ? "mes" : "meses"}</button>)}
          </div>
          <div className="row wrap" style={{ marginTop: 12 }}>
            <button className="btn sm" onClick={() => setChangingPlan(true)}>Cambiar plan</button>
            <button className="btn sm" onClick={() => setEditingLimits(true)}>Editar límites y notas</button>
          </div>
          {t.notes && <p className="small muted" style={{ whiteSpace: "pre-wrap", marginBottom: 0 }}>{t.notes}</p>}
        </Card>
        <Card className="pad-0">
          <div className="card-head" style={{ padding: "18px 20px 0" }}><div><h3>Usuarios</h3><div className="sub">{data.users.length} registrados</div></div></div>
          <div className="list">
            {data.users.map((u) => (
              <div key={u.id} className="list-row static">
                <div className="grow" style={{ minWidth: 0 }}>
                  <div className="bold ellipsis">{u.name || u.email}</div>
                  <div className="tiny muted ellipsis">{u.email} · {ROLE_TITLE[asRole(u.role)]}</div>
                </div>
                {!u.isActive && <Pill text="Inactivo" tint="muted" />}
                {!u.hasPassword && <Pill text="Invitación pendiente" tint="warning" />}
                <button className="btn sm" title={u.hasPassword ? "Enviar enlace para restablecer contraseña" : "Reenviar invitación"} onClick={async () => {
                  try {
                    const out = await adminRequest<{ inviteLink: string }>("POST", `/tenants/${t.id}/users/${u.id}/invite`, {});
                    setInvite({ link: out.inviteLink, name: u.hasPassword ? "Enlace para restablecer" : "Invitación reenviada" });
                  } catch (e) { toastError(e); }
                }}><Mail /> {u.hasPassword ? "Restablecer" : "Reenviar"}</button>
              </div>
            ))}
          </div>
        </Card>
      </div>
      <Card className="pad-0">
        <div className="card-head" style={{ padding: "18px 20px 0" }}><div><h3>Dispositivos y sesiones</h3><div className="sub">Libera un dispositivo para que la empresa pueda activar otro</div></div></div>
        {data.devices.length === 0 ? <EmptyState icon={Tablet} title="Sin dispositivos" message="Aparecerán cuando los usuarios inicien sesión." /> : (
          <div className="table-wrap">
            <table className="table">
              <thead><tr><th>Dispositivo</th><th>Usuario</th><th>Activado</th><th>Última vez</th><th>Estado</th><th /></tr></thead>
              <tbody>
                {data.devices.map((d) => {
                  const I = d.platform === "web" ? Monitor : d.platform === "ios" ? Tablet : Smartphone;
                  return (
                    <tr key={d.id}>
                      <td><span className="row"><I size={16} /> {d.name || (d.platform === "web" ? "Navegador" : d.platform === "ios" ? "iPad" : "Android")}</span></td>
                      <td>{userName(d.userId)}</td>
                      <td>{fmtDate(d.createdAt)}</td>
                      <td>{fmtDateTime(d.lastSeenAt)}</td>
                      <td><Pill text={d.active ? "Activo" : "Liberado"} tint={d.active ? "success" : "muted"} /></td>
                      <td className="right">{d.active && <button className="btn sm danger" onClick={async () => {
                        if (!confirm("¿Liberar este dispositivo? Su sesión se cerrará.")) return;
                        try { await adminRequest("POST", `/tenants/${t.id}/devices/${d.id}/revoke`, {}); toast("Dispositivo liberado"); await reload(); } catch (e) { toastError(e); }
                      }}>Liberar</button>}</td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        )}
      </Card>
      <Card className="pad-0">
        <div className="card-head" style={{ padding: "18px 20px 0" }}><div><h3>Bitácora</h3><div className="sub">Últimos 50 movimientos</div></div></div>
        {data.audit.length === 0 ? <p className="muted small" style={{ padding: "0 20px 20px" }}>Sin movimientos.</p> : (
          <div className="table-wrap">
            <table className="table">
              <thead><tr><th>Fecha</th><th>Acción</th><th>Actor</th><th>Detalle</th></tr></thead>
              <tbody>
                {data.audit.map((a, i) => (
                  <tr key={i}><td>{fmtDateTime(a.at)}</td><td><code>{a.action}</code></td><td className="small muted">{a.actor}</td><td className="small muted" style={{ whiteSpace: "normal", maxWidth: 420 }}>{a.detail && Object.keys(a.detail).length ? JSON.stringify(a.detail) : "—"}</td></tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </Card>
      {changingPlan && <PlanModal tenant={t} onClose={() => setChangingPlan(false)} onSave={(body) => patch(body, "Plan actualizado")} />}
      {editingLimits && <LimitsModal tenant={t} onClose={() => setEditingLimits(false)} onSave={(body) => patch(body, "Empresa actualizada")} />}
      {invite && <InviteLinkModal title={invite.name} link={invite.link} onClose={() => setInvite(null)} />}
    </>
  );
}

function PlanModal({ tenant, onClose, onSave }: { tenant: TenantSummary; onClose: () => void; onSave: (body: Record<string, unknown>) => Promise<void> }) {
  const [plan, setPlan] = useState<Plan>(tenant.plan);
  const [defaults, setDefaults] = useState(true);
  return (
    <FormModal title="Cambiar plan" size="narrow" onClose={onClose} onSave={() => onSave({ plan, applyPlanDefaults: defaults })}>
      <SelectField label="Plan" value={plan} onChange={(v) => v && setPlan(v)} options={PLAN_IDS.map((p) => ({ value: p, label: `${PLAN_NAME[p]} · US$${PLANS[p].priceUsdMonthly}/mes` }))} />
      <label className="check small"><input type="checkbox" checked={defaults} onChange={(e) => setDefaults(e.target.checked)} /> Aplicar los límites del plan ({PLANS[plan].maxUsers} usuarios · {PLANS[plan].maxDevices} dispositivos · {PLANS[plan].maxPlants} plantas)</label>
      {!PLANS[plan].nativeApps && <div className="banner warn">El plan Web no permite las apps de iPad/Android: los dispositivos ya activados no podrán renovar su sesión.</div>}
    </FormModal>
  );
}

function LimitsModal({ tenant, onClose, onSave }: { tenant: TenantSummary; onClose: () => void; onSave: (body: Record<string, unknown>) => Promise<void> }) {
  const [name, setName] = useState(tenant.name);
  const [limits, setLimits] = useState(tenant.limits);
  const [contactEmail, setContactEmail] = useState(tenant.contactEmail ?? "");
  const [notes, setNotes] = useState(tenant.notes ?? "");
  return (
    <FormModal title="Editar empresa" onClose={onClose} canSave={name.trim().length >= 2 && limits.maxUsers >= 1 && limits.maxPlants >= 1 && limits.maxDevices >= 0}
      onSave={() => onSave({ name: name.trim(), ...limits, contactEmail: contactEmail.trim() || null, notes: notes.trim() || null })}>
      <div className="form-grid">
        <TextField label="Nombre" value={name} onChange={setName} />
        <TextField label="Correo de contacto" type="email" value={contactEmail} onChange={setContactEmail} />
      </div>
      <div className="form-grid">
        <NumberField label="Usuarios" value={limits.maxUsers} onChange={(v) => setLimits({ ...limits, maxUsers: v })} integer />
        <NumberField label="Dispositivos" value={limits.maxDevices} onChange={(v) => setLimits({ ...limits, maxDevices: v })} integer />
        <NumberField label="Plantas" value={limits.maxPlants} onChange={(v) => setLimits({ ...limits, maxPlants: v })} integer />
      </div>
      <Field label="Notas internas"><textarea className="input" value={notes} onChange={(e) => setNotes(e.target.value)} /></Field>
    </FormModal>
  );
}
