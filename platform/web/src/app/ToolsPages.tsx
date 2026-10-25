import { Copy, Eraser, LogOut, Monitor, Moon, Settings2, Sun } from "lucide-react";
import { useState } from "react";
import { useNavigate } from "react-router-dom";
import { PLANS } from "../../../src/plans";
import { planTitle, roleTitle } from "../domain/enums";
import { computeCalculator, type CalculatorConstants, type CalculatorInput } from "../domain/rules";
import { useDB, useSession, useSyncState } from "../data/session";
import { t } from "../i18n";
import { fmtDate, fmtDateTime, fmtMoney, fmtNumber, fmtPercent, fullName } from "../lib/format";
import { applyTheme, useCalculatorConstants, useThemePref, useUrgencyWindow, type ThemePref } from "../lib/prefs";
import { toast } from "../lib/toast";
import { Avatar, Card, FormModal, InfoRow, LanguageSwitcher, NumberField, PageHead, Pill, Seg, TextField } from "../ui/kit";

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
  const garments = (v?: number) => (v == null ? "—" : t("calc.garmentsValue", { value: fmtNumber(v, 1) }));

  const results: { title: string; value: string; formula: string }[] = [
    { title: t("calc.grossIncome"), value: money(r.grossIncome), formula: t("calc.grossIncomeFormula") },
    { title: t("calc.netIncome"), value: money(r.netIncome), formula: t("calc.netIncomeFormula") },
    { title: t("calc.pricePerMinute"), value: money(r.pricePerRealMinute), formula: t("calc.pricePerMinuteFormula") },
    { title: t("calc.dailyGoal"), value: num(r.dailyGoal), formula: t("calc.dailyGoalFormula") },
    { title: t("calc.weekly"), value: num(r.weeklyProduction), formula: t("calc.weeklyFormula") },
    { title: t("calc.days"), value: num(r.estimatedDays), formula: t("calc.daysFormula") },
    { title: t("calc.months"), value: num(r.estimatedMonths, 2), formula: t("calc.monthsFormula") },
    { title: t("calc.efficiency"), value: r.minuteEfficiency == null ? "—" : fmtPercent(r.minuteEfficiency), formula: t("calc.efficiencyFormula") },
  ];

  const line = (title: string, value: string) => t("calc.summaryLine", { title, value });
  const summary = () =>
    [
      t("calc.summaryTitle"),
      client && t("calc.summaryClient", { value: client }), style && t("calc.summaryStyle", { value: style }), plant && t("calc.summaryPlant", { value: plant }),
      t("calc.summaryQuantity", { quantity: fmtNumber(input.quantity, 0), real: fmtNumber(input.realMinutes, 2), client: fmtNumber(input.clientMinutes, 2) }),
      t("calc.summaryOperators", { operators: fmtNumber(input.operators, 0), price: fmtMoney(input.pricePerStyle), expenses: fmtMoney(input.operatingExpenses) }),
      "",
      line(t("calc.grossIncome"), money(r.grossIncome)), line(t("calc.netIncome"), money(r.netIncome)), line(t("calc.pricePerMinute"), money(r.pricePerRealMinute)),
      line(t("calc.dailyGoal"), garments(r.dailyGoal)), line(t("calc.weekly"), garments(r.weeklyProduction)), line(t("calc.days"), num(r.estimatedDays)),
      line(t("calc.months"), num(r.estimatedMonths, 2)), line(t("calc.efficiency"), r.minuteEfficiency == null ? "—" : fmtPercent(r.minuteEfficiency)),
      line(t("calc.realMinute"), num(r.realProductionMinute, 2)),
    ].filter(Boolean).join("\n");

  return (
    <>
      <PageHead title={t("section.calculator")} subtitle={t("calc.subtitle")}>
        <button className="btn" onClick={() => setEditingConstants(true)}><Settings2 /> {t("calc.constants")}</button>
        <button className="btn" onClick={() => { void navigator.clipboard?.writeText(summary()).then(() => toast(t("calc.copied"))); }}><Copy /> {t("calc.copySummary")}</button>
        <button className="btn ghost" onClick={() => { setInput(EMPTY_INPUT); setClient(""); setStyle(""); setPlant(""); toast(t("calc.cleared"), "info"); }}><Eraser /> {t("calc.clear")}</button>
      </PageHead>
      {!complete && (
        <div className="banner warn" style={{ justifyContent: "space-between" }}>
          <span>{t("calc.constantsMissing")}</span>
          <button className="btn sm" onClick={() => setEditingConstants(true)}>{t("calc.configure")}</button>
        </div>
      )}
      <div className="grid split">
        <div className="col" style={{ gap: 16 }}>
          <Card title={t("common.style")}>
            <div className="form-grid">
              <TextField label={t("common.client")} value={client} onChange={setClient} list="calc-clients" />
              <TextField label={t("common.style")} value={style} onChange={setStyle} list="calc-styles" />
              <TextField label={t("common.plant")} value={plant} onChange={setPlant} list="calc-plants" />
            </div>
            <datalist id="calc-clients">{db.clients.map((c) => <option key={c.id} value={c.name ?? ""} />)}</datalist>
            <datalist id="calc-styles">{db.styles.map((c) => <option key={c.id} value={c.name ?? ""} />)}</datalist>
            <datalist id="calc-plants">{db.plants.map((c) => <option key={c.id} value={c.name ?? ""} />)}</datalist>
          </Card>
          <Card title={t("calc.productionData")}>
            <div className="form-grid">
              <NumberField label={t("calc.styleQuantity")} value={input.quantity} onChange={set("quantity")} integer />
              <NumberField label={t("calc.realMinutes")} value={input.realMinutes} onChange={set("realMinutes")} />
              <NumberField label={t("calc.clientMinutes")} value={input.clientMinutes} onChange={set("clientMinutes")} />
              <NumberField label={t("calc.operators")} value={input.operators} onChange={set("operators")} integer />
              <NumberField label={t("calc.internalUnitPrice")} value={input.internalUnitPrice} onChange={set("internalUnitPrice")} prefix="$" />
              <NumberField label={t("calc.pricePerStyle")} value={input.pricePerStyle} onChange={set("pricePerStyle")} prefix="$" />
              <NumberField label={t("calc.expenses")} value={input.operatingExpenses} onChange={set("operatingExpenses")} prefix="$" />
            </div>
          </Card>
          <Card title={t("calc.realMinute")} subtitle={t("calc.realMinuteFormula")}>
            <div className="form-grid">
              <NumberField label={t("calc.lineOperators")} value={input.lineOperators} onChange={set("lineOperators")} integer />
              <NumberField label={t("calc.realDaily")} value={input.realDailyProduction} onChange={set("realDailyProduction")} integer />
              <div className="field"><label>{t("calc.result")}</label><div className="kpi-value" style={{ fontSize: 24 }}>{num(r.realProductionMinute, 2)}</div>{constants.minutesPerDay <= 0 && <span className="hint">{t("calc.needsMinutesPerDay")}</span>}</div>
            </div>
          </Card>
        </div>
        <Card title={t("calc.results")} subtitle={t("calc.resultsSubtitle")}>
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
    <FormModal title={t("calc.constants")} size="narrow" onClose={onClose} onSave={() => { onSave(c); toast(t("calc.constantsSaved")); }}>
      <p className="small muted" style={{ margin: 0 }}>{t("calc.constantsIntro")}</p>
      <div className="form-section"><h4>{t("calc.perOperator")}</h4>
        <div className="form-grid">
          <NumberField label={t("calc.minutesPerDay")} value={c.minutesPerDay} onChange={set("minutesPerDay")} />
          <NumberField label={t("calc.minutesPerWeek")} value={c.minutesPerWeek} onChange={set("minutesPerWeek")} />
          <NumberField label={t("calc.minutesPerMonth")} value={c.minutesPerMonth} onChange={set("minutesPerMonth")} />
        </div>
      </div>
      <div className="form-section"><h4>{t("calc.calendar")}</h4>
        <div className="form-grid">
          <NumberField label={t("calc.workDaysPerWeek")} value={c.workDaysPerWeek} onChange={set("workDaysPerWeek")} />
          <NumberField label={t("calc.workDaysPerMonth")} value={c.workDaysPerMonth} onChange={set("workDaysPerMonth")} />
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
  const licenceStatus = licence ? (licence.status === "active" ? t("settings.active") : licence.status === "expired" ? t("settings.expired") : t("settings.suspended")) : "";
  const syncStatus = sync.status === "idle" ? t("settings.upToDate") : sync.status === "syncing" ? t("shell.syncing") : sync.status === "offline" ? t("settings.offline") : t("settings.error");
  const of = (a: number | string, b: number | string) => t("common.of", { a: String(a), b: String(b) });

  return (
    <>
      <PageHead title={t("section.settings")} subtitle={t("settings.subtitle")} />
      <div className="grid two">
        <Card title={t("settings.account")}>
          <div className="row" style={{ marginBottom: 12 }}>
            <Avatar name={fullName(user)} image={user.avatarData} size={52} />
            <div className="grow"><div className="bold" style={{ fontSize: 17 }}>{fullName(user)}</div><div className="small muted">{user.email}</div></div>
            <Pill text={roleTitle(role)} tint="brand" />
          </div>
          {role === "Gerente de Planta" && <InfoRow label={t("common.plant")} value={db.plantById.get(user.plantID ?? "")?.name ?? t("common.noPlantAssigned")} />}
          <button className="btn danger" style={{ marginTop: 10 }} onClick={async () => {
            if (sync.pending > 0 && !confirm(t("shell.confirmSignOut"))) return;
            await logout();
            navigate("/login");
          }}><LogOut /> {t("shell.signOut")}</button>
        </Card>
        <Card title={t("settings.licence")} subtitle={tenant.name}>
          <InfoRow label={t("settings.plan")} value={t("settings.planValue", { plan: planTitle(tenant.plan), price: plan ? String(plan.priceUsdMonthly) : "—" })} />
          <InfoRow label={t("common.status")} value={licence ? <Pill text={licenceStatus} tint={licence.status === "active" ? "success" : "danger"} /> : "—"} />
          <InfoRow label={t("settings.validUntil")} value={licence ? fmtDate(licence.expiresAt) : "—"} />
          <InfoRow label={t("settings.users")} value={of(db.users.filter((u) => u.isActive !== false).length, tenant.maxUsers ?? plan?.maxUsers ?? "—")} />
          <InfoRow label={t("settings.plants")} value={of(db.plants.length, tenant.maxPlants ?? plan?.maxPlants ?? "—")} />
          <InfoRow label={t("settings.devices")} value={plan?.nativeApps ? t("settings.upTo", { count: tenant.maxDevices ?? plan.maxDevices }) : t("settings.browserOnly")} />
        </Card>
        <Card title={t("settings.appearance")}>
          <Seg<ThemePref> value={theme} onChange={(next) => { setTheme(next); applyTheme(next); }} options={[
            { value: "auto", label: <span className="row" style={{ gap: 6 }}><Monitor size={14} />{t("settings.themeSystem")}</span> },
            { value: "light", label: <span className="row" style={{ gap: 6 }}><Sun size={14} />{t("settings.themeLight")}</span> },
            { value: "dark", label: <span className="row" style={{ gap: 6 }}><Moon size={14} />{t("settings.themeDark")}</span> },
          ]} />
        </Card>
        <Card title={t("settings.language")}>
          <div className="col" style={{ gap: 8 }}>
            <LanguageSwitcher />
            <span className="tiny faint">{t("settings.languageHint")}</span>
          </div>
        </Card>
        <Card title={t("section.shipments")} subtitle={t("settings.urgentSubtitle")}>
          <select className="input" style={{ width: "auto" }} value={urgency} onChange={(e) => setUrgency(Number(e.target.value))} aria-label={t("ship.window")}>
            {[3, 5, 7, 10, 14, 21, 30].map((d) => <option key={d} value={d}>{t("common.days", { count: d })}</option>)}
          </select>
        </Card>
        <Card title={t("settings.sync")}>
          <InfoRow label={t("common.status")} value={syncStatus} />
          <InfoRow label={t("settings.lastSync")} value={sync.lastSyncAt ? fmtDateTime(sync.lastSyncAt) : "—"} />
          <InfoRow label={t("settings.pending")} value={String(sync.pending)} />
          <button className="btn" style={{ marginTop: 10 }} onClick={() => store.sync()}>{t("shell.syncNow")}</button>
          <p className="tiny faint" style={{ marginBottom: 0 }}>{t("settings.syncNote")}</p>
        </Card>
      </div>
    </>
  );
}
