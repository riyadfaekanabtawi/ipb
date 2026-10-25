import { CalendarDays, ChevronLeft, ChevronRight, Truck } from "lucide-react";
import { useMemo, useState } from "react";
import { useNavigate } from "react-router-dom";
import { sameMonth } from "../domain/rules";
import { useDB } from "../data/session";
import { fmtInt, fmtMoney, fmtMonthYear, parseDate } from "../lib/format";
import { CapacityBar, Card, EmptyState, PageHead, seriesColor } from "../ui/kit";
import { paths } from "./nav";

const DOW = ["Lun", "Mar", "Mié", "Jue", "Vie", "Sáb", "Dom"];
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
      add(d, { id: `p-${a.id}`, kind: "production", label: info.title, detail: `${info.plantName} · ${fmtInt(a.quantity ?? 0)} prendas`, color: seriesColor(plantIndex.get(a.plantID ?? "") ?? 0), to: paths.assignment(a.id) });
    }
    for (const o of db.orders) {
      const d = parseDate(o.clientDate);
      if (!d) continue;
      if (plantId && !(db.assignmentsByOrder.get(o.id) ?? []).some((a) => a.plantID === plantId)) continue;
      const info = db.orderInfo(o);
      add(d, { id: `d-${o.id}`, kind: "delivery", label: o.code ?? "Corte", detail: `Entrega a ${info.clientName}`, color: "var(--danger)", to: paths.order(o.id) });
    }
    return map;
  }, [db, plantId, plantIndex]);

  const start = new Date(month);
  start.setDate(1 - ((month.getDay() + 6) % 7));
  const days = Array.from({ length: 42 }, (_, i) => new Date(start.getFullYear(), start.getMonth(), start.getDate() + i));
  const today = new Date();
  const dayEvents = events.get(dayKey(selected)) ?? [];
  const plants = plantId ? db.plants.filter((p) => p.id === plantId) : db.plants;

  return (
    <>
      <PageHead title="Calendario de plantas" subtitle="Inicio de producción (color por planta) y entregas al cliente.">
        <select className="input" style={{ width: "auto" }} value={plantId} onChange={(e) => setPlantId(e.target.value)} aria-label="Planta">
          <option value="">Todas las plantas</option>
          {db.plants.map((p) => <option key={p.id} value={p.id}>{p.name}</option>)}
        </select>
      </PageHead>
      <div className="grid split">
        <Card>
          <div className="row between" style={{ marginBottom: 12 }}>
            <h3 style={{ fontSize: 18 }}>{fmtMonthYear(month)}</h3>
            <div className="row">
              <button className="btn ghost icon sm" onClick={() => setMonth(new Date(month.getFullYear(), month.getMonth() - 1, 1))} aria-label="Mes anterior"><ChevronLeft /></button>
              <button className="btn sm" onClick={() => { const t = new Date(); setMonth(new Date(t.getFullYear(), t.getMonth(), 1)); setSelected(t); }}>Hoy</button>
              <button className="btn ghost icon sm" onClick={() => setMonth(new Date(month.getFullYear(), month.getMonth() + 1, 1))} aria-label="Mes siguiente"><ChevronRight /></button>
            </div>
          </div>
          <div className="cal">
            {DOW.map((d) => <div key={d} className="cal-dow">{d}</div>)}
            {days.map((d) => {
              const evs = events.get(dayKey(d)) ?? [];
              const cls = [!sameMonth(d, month) && "out", dayKey(d) === dayKey(today) && "today", dayKey(d) === dayKey(selected) && "sel"].filter(Boolean).join(" ");
              return (
                <button key={d.toISOString()} type="button" className={`cal-day ${cls}`} onClick={() => setSelected(d)} aria-label={`${d.toLocaleDateString("es-MX", { dateStyle: "full" })}, ${evs.length} eventos`}>
                  <span className="d">{d.getDate()}</span>
                  {evs.slice(0, 3).map((e) => <span key={e.id} className={`cal-ev ${e.kind === "delivery" ? "delivery" : ""}`} style={e.kind === "production" ? ({ "--c": e.color } as React.CSSProperties) : undefined}>{e.label}</span>)}
                  {evs.length > 3 && <span className="tiny faint">+{evs.length - 3} más</span>}
                </button>
              );
            })}
          </div>
          <div className="legend" style={{ marginTop: 12 }}>
            {db.plants.map((p, i) => <span key={p.id}><i style={{ background: seriesColor(i) }} />{p.name}</span>)}
            <span><i style={{ background: "var(--danger)" }} />Entrega al cliente</span>
          </div>
        </Card>
        <div className="col" style={{ gap: 16 }}>
          <Card title={selected.toLocaleDateString("es-MX", { weekday: "long", day: "numeric", month: "long" })} className="pad-0">
            {dayEvents.length === 0 ? (
              <EmptyState icon={CalendarDays} title="Día libre" message="Sin producción ni entregas este día." />
            ) : (
              <div className="list" style={{ marginTop: -14 }}>
                {dayEvents.map((e) => (
                  <button key={e.id} className="list-row" onClick={() => navigate(e.to)}>
                    {e.kind === "delivery" ? <Truck size={18} color="var(--danger)" /> : <span style={{ width: 12, height: 12, borderRadius: 4, background: e.color, flex: "none" }} />}
                    <div className="grow"><div className="bold">{e.label}</div><div className="tiny muted">{e.detail}</div></div>
                  </button>
                ))}
              </div>
            )}
          </Card>
          <Card title="Capacidad del mes" subtitle={fmtMonthYear(month)}>
            <div className="col" style={{ gap: 14 }}>
              {plants.map((p) => {
                const used = db.ledger(p).used(month);
                return (
                  <div key={p.id} className="col" style={{ gap: 6 }}>
                    <div className="row small"><span className="bold grow">{p.name}</span><span className="muted">Usada {fmtMoney(used, true)}</span></div>
                    <CapacityBar used={used} max={p.maxCapacity ?? 0} />
                    <span className="tiny faint">Disponible {fmtMoney(Math.max(0, (p.maxCapacity ?? 0) - used), true)}</span>
                  </div>
                );
              })}
              {plants.length === 0 && <span className="muted small">Sin plantas.</span>}
            </div>
          </Card>
        </div>
      </div>
    </>
  );
}
