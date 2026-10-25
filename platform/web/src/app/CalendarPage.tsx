import { CalendarDays, ChevronLeft, ChevronRight, Truck } from "lucide-react";
import { useMemo, useState } from "react";
import { useNavigate } from "react-router-dom";
import { sameMonth } from "../domain/rules";
import { useDB } from "../data/session";
import { fmtDayFull, fmtDayLong, fmtMoney, fmtMonthYear, parseDate, weekdayNames } from "../lib/format";
import { t } from "../i18n";
import { CapacityBar, Card, EmptyState, PageHead, seriesColor } from "../ui/kit";
import { paths } from "./nav";

const dayKey = (d: Date) => `${d.getFullYear()}-${d.getMonth()}-${d.getDate()}`;

interface Ev { id: string; kind: "production" | "delivery"; label: string; detail: string; color: string; to: string }

export function CalendarPage() {
  const db = useDB();
  const navigate = useNavigate();
  const [month, setMonth] = useState(() => new Date(new Date().getFullYear(), new Date().getMonth(), 1));
  const [plantId, setPlantId] = useState("");
  const [selected, setSelected] = useState<Date>(() => new Date());

  const plantIndex = useMemo(() => new Map(db.plants.map((p, i) => [p.id, i])), [db]);

  const events = useMemo(() => {
    const map = new Map<string, Ev[]>();
    const add = (d: Date, e: Ev) => {
      const k = dayKey(d);
      map.set(k, [...(map.get(k) ?? []), e]);
    };
    for (const a of db.assignments) {
      if (plantId && a.plantID !== plantId) continue;
      const d = parseDate(a.scheduledDate);
      if (!d) continue;
      const info = db.assignmentInfo(a);
      add(d, { id: `p-${a.id}`, kind: "production", label: info.title, detail: `${info.plantName} · ${t("common.garments", { count: a.quantity ?? 0 })}`, color: seriesColor(plantIndex.get(a.plantID ?? "") ?? 0), to: paths.assignment(a.id) });
    }
    for (const o of db.orders) {
      const d = parseDate(o.clientDate);
      if (!d) continue;
      if (plantId && !(db.assignmentsByOrder.get(o.id) ?? []).some((a) => a.plantID === plantId)) continue;
      const info = db.orderInfo(o);
      add(d, { id: `d-${o.id}`, kind: "delivery", label: o.code ?? t("common.cut"), detail: t("cal.deliveryTo", { client: info.clientName }), color: "var(--danger)", to: paths.order(o.id) });
    }
    return map;
  }, [db, plantId, plantIndex]);

  const start = new Date(month);
  start.setDate(1 - ((month.getDay() + 6) % 7));
  const days = Array.from({ length: 42 }, (_, i) => new Date(start.getFullYear(), start.getMonth(), start.getDate() + i));
  const today = new Date();
  const dayEvents = events.get(dayKey(selected)) ?? [];
  const plants = plantId ? db.plants.filter((p) => p.id === plantId) : db.plants;
  const dow = weekdayNames();

  return (
    <>
      <PageHead title={t("section.calendar")} subtitle={t("cal.subtitle")}>
        <select className="input" style={{ width: "auto" }} value={plantId} onChange={(e) => setPlantId(e.target.value)} aria-label={t("common.plant")}>
          <option value="">{t("common.allPlants")}</option>
          {db.plants.map((p) => <option key={p.id} value={p.id}>{p.name}</option>)}
        </select>
      </PageHead>
      <div className="grid split">
        <Card>
          <div className="row between" style={{ marginBottom: 12 }}>
            <h3 style={{ fontSize: 18 }}>{fmtMonthYear(month)}</h3>
            <div className="row">
              <button className="btn ghost icon sm" onClick={() => setMonth(new Date(month.getFullYear(), month.getMonth() - 1, 1))} aria-label={t("common.prevMonth")}><ChevronLeft /></button>
              <button className="btn sm" onClick={() => { const now = new Date(); setMonth(new Date(now.getFullYear(), now.getMonth(), 1)); setSelected(now); }}>{t("common.today")}</button>
              <button className="btn ghost icon sm" onClick={() => setMonth(new Date(month.getFullYear(), month.getMonth() + 1, 1))} aria-label={t("common.nextMonth")}><ChevronRight /></button>
            </div>
          </div>
          <div className="cal">
            {dow.map((d) => <div key={d} className="cal-dow">{d}</div>)}
            {days.map((d) => {
              const evs = events.get(dayKey(d)) ?? [];
              const cls = [!sameMonth(d, month) && "out", dayKey(d) === dayKey(today) && "today", dayKey(d) === dayKey(selected) && "sel"].filter(Boolean).join(" ");
              return (
                <button key={d.toISOString()} type="button" className={`cal-day ${cls}`} onClick={() => setSelected(d)} aria-label={t("cal.dayAria", { date: fmtDayFull(d), count: evs.length })}>
                  <span className="d">{d.getDate()}</span>
                  {evs.slice(0, 3).map((e) => <span key={e.id} className={`cal-ev ${e.kind === "delivery" ? "delivery" : ""}`} style={e.kind === "production" ? ({ "--c": e.color } as React.CSSProperties) : undefined}>{e.label}</span>)}
                  {evs.length > 3 && <span className="tiny faint">{t("cal.more", { count: evs.length - 3 })}</span>}
                </button>
              );
            })}
          </div>
          <div className="legend" style={{ marginTop: 12 }}>
            {db.plants.map((p, i) => <span key={p.id}><i style={{ background: seriesColor(i) }} />{p.name}</span>)}
            <span><i style={{ background: "var(--danger)" }} />{t("cal.clientDelivery")}</span>
          </div>
        </Card>
        <div className="col" style={{ gap: 16 }}>
          <Card title={fmtDayLong(selected)} className="pad-0">
            {dayEvents.length === 0 ? (
              <EmptyState icon={CalendarDays} title={t("cal.freeDay")} message={t("cal.freeDayMessage")} />
            ) : (
              <div className="list">
                {dayEvents.map((e) => (
                  <button key={e.id} className="list-row" onClick={() => navigate(e.to)}>
                    {e.kind === "delivery" ? <Truck size={18} color="var(--danger)" /> : <span style={{ width: 12, height: 12, borderRadius: 4, background: e.color, flex: "none" }} />}
                    <div className="grow"><div className="bold">{e.label}</div><div className="tiny muted">{e.detail}</div></div>
                  </button>
                ))}
              </div>
            )}
          </Card>
          <Card title={t("cal.monthCapacity")} subtitle={fmtMonthYear(month)}>
            <div className="col" style={{ gap: 14 }}>
              {plants.map((p) => {
                const used = db.ledger(p).used(month);
                return (
                  <div key={p.id} className="col" style={{ gap: 6 }}>
                    <div className="row small"><span className="bold grow">{p.name}</span><span className="muted">{t("cal.usedAmount", { amount: fmtMoney(used, true) })}</span></div>
                    <CapacityBar used={used} max={p.maxCapacity ?? 0} />
                    <span className="tiny faint">{t("common.availableAmount", { amount: fmtMoney(Math.max(0, (p.maxCapacity ?? 0) - used), true) })}</span>
                  </div>
                );
              })}
              {plants.length === 0 && <span className="muted small">{t("cal.noPlants")}</span>}
            </div>
          </Card>
        </div>
      </div>
    </>
  );
}
