import { Copy, Eraser, LogOut, Monitor, Moon, Settings2, Sun } from "lucide-react";
import { useState } from "react";
import { useNavigate } from "react-router-dom";
import { PLANS } from "../../../src/plans";
import { ROLE_TITLE } from "../domain/enums";
import { computeCalculator, type CalculatorConstants, type CalculatorInput } from "../domain/rules";
import { useDB, useSession, useSyncState } from "../data/session";
import { fmtDate, fmtDateTime, fmtMoney, fmtNumber, fmtPercent, fullName } from "../lib/format";
import { applyTheme, useCalculatorConstants, useThemePref, useUrgencyWindow, type ThemePref } from "../lib/prefs";
import { toast } from "../lib/toast";
import { Avatar, Card, FormModal, InfoRow, NumberField, PageHead, Pill, Seg, TextField } from "../ui/kit";

const PLAN_NAME: Record<string, string> = { web: "Web", planta: "Planta", multiplanta: "Multiplanta", empresa: "Empresa" };

// Production calculator (DOMAIN rule 12) ------------------------------------------------------

const EMPTY_INPUT: CalculatorInput = { quantity: 0, realMinutes: 0, clientMinutes: 0, operators: 0, internalUnitPrice: 0, pricePerStyle: 0, operatingExpenses: 0, lineOperators: 0, realDailyProduction: 0 };

export function CalculatorPage() {
  const db = useDB();
  const [constants, setConstants] = useCalculatorConstants();
  const [input, setInput] = useState<CalculatorInput>(EMPTY_INPUT);
  const [client, setClient] = useState("");
  const [style, setStyle] = useState("");
  const [plant, setPlant] = useState("");
  const [editingConstants, setEditingConstants] = useState(false);
  const r = computeCalculator(input, constants);
  const set = (k: keyof CalculatorInput) => (v: number) => setInput({ ...input, [k]: Number.isFinite(v) ? v : 0 });
  const complete = [constants.minutesPerDay, constants.minutesPerWeek, constants.minutesPerMonth, constants.workDaysPerWeek, constants.workDaysPerMonth].every((v) => v > 0);
  const money = (v?: number) => (v == null ? "—" : fmtMoney(v));
  const num = (v?: number, digits = 1) => (v == null ? "—" : fmtNumber(v, digits));

  const summary = () =>
    [
      "Cálculo de producción · Trama",
      client && `Cliente: ${client}`, style && `Estilo: ${style}`, plant && `Planta: ${plant}`,
      `Cantidad: ${fmtNumber(input.quantity, 0)} prendas · Minutaje real ${fmtNumber(input.realMinutes, 2)} · cliente ${fmtNumber(input.clientMinutes, 2)}`,
      `Operarios: ${fmtNumber(input.operators, 0)} · Precio por estilo ${fmtMoney(input.pricePerStyle)} · Gastos ${fmtMoney(input.operatingExpenses)}`,
      "",
      `Ingreso bruto: ${money(r.grossIncome)}`, `Ingreso neto: ${money(r.netIncome)}`, `Precio por minuto real: ${money(r.pricePerRealMinute)}`,
      `Meta diaria: ${num(r.dailyGoal)} prendas`, `Producción semanal: ${num(r.weeklyProduction)} prendas`, `Días estimados: ${num(r.estimatedDays)}`,
      `Meses estimados: ${num(r.estimatedMonths, 2)}`, `Eficiencia de minutaje: ${r.minuteEfficiency == null ? "—" : fmtPercent(r.minuteEfficiency)}`,
      `Minuto real de producción: ${num(r.realProductionMinute, 2)}`,
    ].filter(Boolean).join("\n");

  const results: { title: string; value: string; formula: string }[] = [
    { title: "Ingreso bruto", value: money(r.grossIncome), formula: "Cantidad × precio por estilo" },
    { title: "Ingreso neto", value: money(r.netIncome), formula: "Bruto − gastos operativos" },
    { title: "Precio por minuto real", value: money(r.pricePerRealMinute), formula: "Precio por estilo ÷ minutaje real" },
    { title: "Meta diaria", value: num(r.dailyGoal), formula: "Operarios × minutos día ÷ minutaje" },
    { title: "Producción semanal", value: num(r.weeklyProduction), formula: "Meta diaria × días por semana" },
    { title: "Días estimados", value: num(r.estimatedDays), formula: "Cantidad ÷ meta diaria" },
    { title: "Meses estimados", value: num(r.estimatedMonths, 2), formula: "Días ÷ días por mes" },
    { title: "Eficiencia de minutaje", value: r.minuteEfficiency == null ? "—" : fmtPercent(r.minuteEfficiency), formula: "Minutaje cliente ÷ real" },
  ];

  return (
    <>
      <PageHead title="Calculadora" subtitle="Estima ingresos, metas y tiempos de producción de un estilo.">
        <button className="btn" onClick={() => setEditingConstants(true)}><Settings2 /> Constantes</button>
        <button className="btn" onClick={() => { void navigator.clipboard?.writeText(summary()).then(() => toast("Resumen copiado")); }}><Copy /> Copiar resumen</button>
        <button className="btn ghost" onClick={() => { setInput(EMPTY_INPUT); setClient(""); setStyle(""); setPlant(""); toast("Calculadora limpia", "info"); }}><Eraser /> Limpiar</button>
      </PageHead>
      {!complete && (
        <div className="banner warn" style={{ justifyContent: "space-between" }}>
          <span>Configura las constantes de planta: minutos por operario y días de trabajo son necesarios para la meta diaria, la producción semanal y los tiempos estimados.</span>
          <button className="btn sm" onClick={() => setEditingConstants(true)}>Configurar</button>
        </div>
      )}
      <div className="grid split">
        <div className="col" style={{ gap: 16 }}>
          <Card title="Estilo">
            <div className="form-grid">
              <TextField label="Cliente" value={client} onChange={setClient} list="calc-clients" />
              <TextField label="Estilo" value={style} onChange={setStyle} list="calc-styles" />
              <TextField label="Planta" value={plant} onChange={setPlant} list="calc-plants" />
            </div>
            <datalist id="calc-clients">{db.clients.map((c) => <option key={c.id} value={c.name ?? ""} />)}</datalist>
            <datalist id="calc-styles">{db.styles.map((c) => <option key={c.id} value={c.name ?? ""} />)}</datalist>
            <datalist id="calc-plants">{db.plants.map((c) => <option key={c.id} value={c.name ?? ""} />)}</datalist>
          </Card>
          <Card title="Datos de producción">
            <div className="form-grid">
              <NumberField label="Cantidad del estilo" value={input.quantity} onChange={set("quantity")} integer />
              <NumberField label="Minutaje real" value={input.realMinutes} onChange={set("realMinutes")} />
              <NumberField label="Minutaje cliente" value={input.clientMinutes} onChange={set("clientMinutes")} />
              <NumberField label="Operarios" value={input.operators} onChange={set("operators")} integer />
              <NumberField label="Precio unitario interno" value={input.internalUnitPrice} onChange={set("internalUnitPrice")} prefix="$" />
              <NumberField label="Precio por estilo" value={input.pricePerStyle} onChange={set("pricePerStyle")} prefix="$" />
              <NumberField label="Gastos operativos" value={input.operatingExpenses} onChange={set("operatingExpenses")} prefix="$" />
            </div>
          </Card>
          <Card title="Minuto real de producción" subtitle="Minutos día × operarios ÷ producción diaria">
            <div className="form-grid">
              <NumberField label="Operarios de línea" value={input.lineOperators} onChange={set("lineOperators")} integer />
              <NumberField label="Producción real diaria" value={input.realDailyProduction} onChange={set("realDailyProduction")} integer />
              <div className="field"><label>Resultado</label><div className="kpi-value" style={{ fontSize: 24 }}>{num(r.realProductionMinute, 2)}</div>{constants.minutesPerDay <= 0 && <span className="hint">Requiere minutos por día</span>}</div>
            </div>
          </Card>
        </div>
        <Card title="Resultados" subtitle="Se calculan al momento">
          <div className="col" style={{ gap: 4 }}>
            {results.map((x) => (
              <div key={x.title} className="row" style={{ padding: "9px 0", borderBottom: "1px solid var(--stroke)" }}>
                <div className="grow"><div className="bold small">{x.title}</div><div className="tiny faint">{x.formula}</div></div>
                <div className="kpi-value" style={{ fontSize: 20, color: x.value === "—" ? "var(--text-3)" : undefined }}>{x.value}</div>
              </div>
            ))}
          </div>
        </Card>
      </div>
      {editingConstants && <ConstantsForm value={constants} onSave={setConstants} onClose={() => setEditingConstants(false)} />}
    </>
  );
}

function ConstantsForm({ value, onSave, onClose }: { value: CalculatorConstants; onSave: (c: CalculatorConstants) => void; onClose: () => void }) {
  const [c, setC] = useState(value);
  const set = (k: keyof CalculatorConstants) => (v: number) => setC({ ...c, [k]: Number.isFinite(v) ? v : 0 });
  return (
    <FormModal title="Constantes" size="narrow" onClose={onClose} onSave={() => { onSave(c); toast("Constantes guardadas"); }}>
      <p className="small muted" style={{ margin: 0 }}>Se guardan en este navegador y se usan en todos los cálculos.</p>
      <div className="form-section"><h4>Por operario</h4>
        <div className="form-grid">
          <NumberField label="Minutos por día" value={c.minutesPerDay} onChange={set("minutesPerDay")} />
          <NumberField label="Minutos por semana" value={c.minutesPerWeek} onChange={set("minutesPerWeek")} />
          <NumberField label="Minutos por mes" value={c.minutesPerMonth} onChange={set("minutesPerMonth")} />
        </div>
      </div>
      <div className="form-section"><h4>Calendario</h4>
        <div className="form-grid">
          <NumberField label="Días de trabajo por semana" value={c.workDaysPerWeek} onChange={set("workDaysPerWeek")} />
          <NumberField label="Días de trabajo por mes" value={c.workDaysPerMonth} onChange={set("workDaysPerMonth")} />
        </div>
      </div>
    </FormModal>
  );
}

// Settings --------------------------------------------------------------------------------------

export function SettingsPage() {
  const { user, role, tenant, logout, store } = useSession();
  const db = useDB();
  const sync = useSyncState();
  const navigate = useNavigate();
  const [theme, setTheme] = useThemePref();
  const [urgency, setUrgency] = useUrgencyWindow();
  const plan = PLANS[tenant.plan];
  const licence = sync.licence;

  return (
    <>
      <PageHead title="Ajustes" subtitle="Tu cuenta, la licencia de tu empresa y las preferencias de este navegador." />
      <div className="grid two">
        <Card title="Tu cuenta">
          <div className="row" style={{ marginBottom: 12 }}>
            <Avatar name={fullName(user)} image={user.avatarData} size={52} />
            <div className="grow"><div className="bold" style={{ fontSize: 17 }}>{fullName(user)}</div><div className="small muted">{user.email}</div></div>
            <Pill text={ROLE_TITLE[role]} tint="brand" />
          </div>
          {role === "Gerente de Planta" && <InfoRow label="Planta" value={db.plantById.get(user.plantID ?? "")?.name ?? "Sin planta asignada"} />}
          <button className="btn danger" style={{ marginTop: 10 }} onClick={async () => {
            if (sync.pending > 0 && !confirm("Hay cambios sin sincronizar que se perderán. ¿Cerrar sesión?")) return;
            await logout();
            navigate("/login");
          }}><LogOut /> Cerrar sesión</button>
        </Card>
        <Card title="Licencia" subtitle={tenant.name}>
          <InfoRow label="Plan" value={`${PLAN_NAME[tenant.plan] ?? tenant.plan} · US$${plan?.priceUsdMonthly ?? "—"}/mes`} />
          <InfoRow label="Estado" value={licence ? <Pill text={licence.status === "active" ? "Activa" : licence.status === "expired" ? "Vencida" : "Suspendida"} tint={licence.status === "active" ? "success" : "danger"} /> : "—"} />
          <InfoRow label="Vigencia" value={licence ? fmtDate(licence.expiresAt) : "—"} />
          <InfoRow label="Usuarios" value={`${db.users.filter((u) => u.isActive !== false).length} de ${tenant.maxUsers ?? plan?.maxUsers ?? "—"}`} />
          <InfoRow label="Plantas" value={`${db.plants.length} de ${tenant.maxPlants ?? plan?.maxPlants ?? "—"}`} />
          <InfoRow label="Dispositivos (iPad / Android)" value={plan?.nativeApps ? `Hasta ${tenant.maxDevices ?? plan.maxDevices}` : "Solo navegador"} />
        </Card>
        <Card title="Apariencia">
          <Seg<ThemePref> value={theme} onChange={(t) => { setTheme(t); applyTheme(t); }} options={[
            { value: "auto", label: <span className="row" style={{ gap: 6 }}><Monitor size={14} />Sistema</span> },
            { value: "light", label: <span className="row" style={{ gap: 6 }}><Sun size={14} />Claro</span> },
            { value: "dark", label: <span className="row" style={{ gap: 6 }}><Moon size={14} />Oscuro</span> },
          ]} />
        </Card>
        <Card title="Envíos urgentes" subtitle="Entregas dentro de este plazo o vencidas se consideran urgentes">
          <select className="input" style={{ width: "auto" }} value={urgency} onChange={(e) => setUrgency(Number(e.target.value))}>
            {[3, 5, 7, 10, 14, 21, 30].map((d) => <option key={d} value={d}>{d} días</option>)}
          </select>
        </Card>
        <Card title="Sincronización">
          <InfoRow label="Estado" value={sync.status === "idle" ? "Al día" : sync.status === "syncing" ? "Sincronizando…" : sync.status === "offline" ? "Sin conexión" : "Error"} />
          <InfoRow label="Última sincronización" value={sync.lastSyncAt ? fmtDateTime(sync.lastSyncAt) : "—"} />
          <InfoRow label="Cambios en espera" value={String(sync.pending)} />
          <button className="btn" style={{ marginTop: 10 }} onClick={() => store.sync()}>Sincronizar ahora</button>
          <p className="tiny faint" style={{ marginBottom: 0 }}>Tus datos se guardan cifrados en el servidor y en caché en este navegador para abrir rápido. Al cerrar sesión se borra la caché.</p>
        </Card>
      </div>
    </>
  );
}
