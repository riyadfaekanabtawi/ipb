import { Banknote, Building2, ChevronLeft, ChevronRight, CircleCheck, Cog, Inbox, PackageCheck, RefreshCw, Scissors, TriangleAlert, Wifi, WifiOff } from "lucide-react";
import { useMemo, useState } from "react";
import { useNavigate } from "react-router-dom";
import { CUT_STATUS_TITLE, CUT_STATUSES, REPORT_SHORT, REPORT_TINT, asReportKind, type CutStatus } from "../domain/enums";
import { daysLeft, isUrgent } from "../domain/rules";
import { useDB, useSession, useSyncState } from "../data/session";
import { fmtDateTime, fmtInt, fmtMoney, fmtMonthYear, fmtPercent, fmtRelativeDays, fmtShortDate, parseDate } from "../lib/format";
import { useUrgencyWindow } from "../lib/prefs";
import { MonthlyColumns, StatusStack } from "../ui/charts";
import { Avatar, CapacityBar, Card, EmptyState, KPITile, Pill, Threads } from "../ui/kit";
import { paths, SECTION_PATH } from "./nav";

const STATUS_COLOR: Record<CutStatus, string> = { en_espera: "var(--danger)", en_mesa_de_corte: "var(--warning)", listo_para_confeccionar: "var(--success)" };

export function DashboardPage() {
  const db = useDB();
  const { user } = useSession();
  const sync = useSyncState();
  const [urgency] = useUrgencyWindow();
  const navigate = useNavigate();
  const [month, setMonth] = useState(() => new Date(new Date().getFullYear(), new Date().getMonth(), 1));

  const s = useMemo(() => {
    let revenue = 0, toShip = 0, inProduction = 0;
    const statusCounts: Record<CutStatus, number> = { en_espera: 0, en_mesa_de_corte: 0, listo_para_confeccionar: 0 };
    const urgent: { id: string; title: string; plant: string; client: string; toShip: number; days: number | null }[] = [];
    for (const a of db.assignments) {
      const info = db.assignmentInfo(a);
      revenue += info.metrics.revenue;
      toShip += info.metrics.toShip;
      if (!info.metrics.isComplete) inProduction++;
      statusCounts[info.cutStatus]++;
      const clientDate = parseDate(info.order?.clientDate);
      if (isUrgent(info.metrics.toShip, clientDate, urgency)) urgent.push({ id: a.id, title: info.title, plant: info.plantName, client: info.clientName, toShip: info.metrics.toShip, days: daysLeft(clientDate) });
    }
    urgent.sort((x, y) => (x.days ?? Infinity) - (y.days ?? Infinity));
    const pending = db.orders.map((o) => db.orderInfo(o)).filter((o) => o.remaining > 0)
      .sort((x, y) => (parseDate(x.order.clientDate)?.getTime() ?? Infinity) - (parseDate(y.order.clientDate)?.getTime() ?? Infinity));
    const capacity = db.plants.map((p, i) => ({ plant: p, used: db.ledger(p).used(month), max: p.maxCapacity ?? 0, index: i }));
    const yearly = db.plants.map((p, i) => ({ name: p.name ?? "Planta", values: db.ledger(p).monthlyUsage(month.getFullYear()), colorIndex: i }));
    return { revenue, toShip, inProduction, statusCounts, urgent, pending, unassigned: pending.reduce((n, o) => n + o.remaining, 0), capacity, yearly };
  }, [db, urgency, month]);

  const hour = new Date().getHours();
  const salute = hour >= 5 && hour < 12 ? "Buenos días" : hour < 19 && hour >= 12 ? "Buenas tardes" : "Buenas noches";
  const shift = (n: number) => setMonth(new Date(month.getFullYear(), month.getMonth() + n, 1));
  const online = sync.status !== "offline";

  return (
    <>
      <div className="hero">
        <Threads />
        <div className="hero-top">
          <span className="hero-chip">{online ? <Wifi /> : <WifiOff />}{online ? "En línea" : "Sin conexión · modo local"}</span>
          <span className="hero-chip"><RefreshCw />Actualizado {sync.lastSyncAt ? fmtDateTime(sync.lastSyncAt) : "—"}</span>
        </div>
        <h2>{user.firstName ? `${salute}, ${user.firstName}` : salute}</h2>
        <p>
          {s.urgent.length === 0 ? "Sin envíos urgentes" : `${s.urgent.length} ${s.urgent.length === 1 ? "envío urgente" : "envíos urgentes"}`} ·{" "}
          {s.unassigned === 0 ? "todo asignado" : `${fmtInt(s.unassigned)} prendas por asignar`}
        </p>
      </div>

      <div className="grid kpis">
        <KPITile title="Ingresos en producción" value={fmtMoney(s.revenue, true)} icon={Banknote} tint="brand" footnote={`${fmtInt(db.assignments.length)} asignaciones`} onClick={() => navigate(SECTION_PATH.production)} />
        <KPITile title="Prendas por asignar" value={fmtInt(s.unassigned)} icon={Scissors} tint="thread" footnote={`${fmtInt(s.pending.length)} cortes pendientes`} onClick={() => navigate(SECTION_PATH.orders)} />
        <KPITile title="En producción" value={fmtInt(s.inProduction)} icon={Cog} tint="info" footnote="Cortes sin terminar" onClick={() => navigate(SECTION_PATH.production)} />
        <KPITile title="Envíos urgentes" value={fmtInt(s.urgent.length)} icon={TriangleAlert} tint={s.urgent.length ? "danger" : "success"} footnote={`Próximos ${urgency} días`} onClick={() => navigate(SECTION_PATH.shipments)} />
        <KPITile title="Por enviar" value={fmtInt(s.toShip)} icon={PackageCheck} tint="success" footnote="Prendas" onClick={() => navigate(SECTION_PATH.shipments)} />
      </div>

      <div className="grid split">
        <Card
          title="Capacidad por planta"
          subtitle={fmtMonthYear(month)}
          action={
            <div className="row">
              <button className="btn ghost icon sm" onClick={() => shift(-1)} aria-label="Mes anterior"><ChevronLeft /></button>
              <button className="btn ghost icon sm" onClick={() => shift(1)} aria-label="Mes siguiente"><ChevronRight /></button>
            </div>
          }
        >
          {s.capacity.length === 0 ? (
            <EmptyState icon={Building2} title="Sin plantas" message="Agrega tus plantas con su capacidad mensual para empezar a asignar cortes." />
          ) : (
            <div className="col" style={{ gap: 16 }}>
              {s.capacity.map((c) => (
                <button key={c.plant.id} className="list-row" style={{ padding: 0, border: 0, flexDirection: "column", alignItems: "stretch", gap: 7, background: "transparent" }} onClick={() => navigate(paths.plant(c.plant.id))}>
                  <div className="row small">
                    <span className="bold grow ellipsis">{c.plant.name}</span>
                    <span className="muted num">{fmtMoney(c.used, true)} / {fmtMoney(c.max, true)}</span>
                    <span className="bold num" style={{ width: 48, textAlign: "right" }}>{fmtPercent(c.max ? c.used / c.max : 0)}</span>
                  </div>
                  <CapacityBar used={c.used} max={c.max} />
                </button>
              ))}
            </div>
          )}
        </Card>
        <Card title="Tablero de corte" subtitle="Estado de las asignaciones" action={<button className="btn ghost sm" onClick={() => navigate(SECTION_PATH.board)}>Abrir</button>}>
          <StatusStack items={CUT_STATUSES.map((st) => ({ label: CUT_STATUS_TITLE[st], value: s.statusCounts[st], color: STATUS_COLOR[st] }))} />
        </Card>
      </div>

      <Card title="Ingresos programados" subtitle={`Valor asignado por mes de producción · ${month.getFullYear()}`}>
        {db.plants.length ? <MonthlyColumns series={s.yearly} highlightMonth={month.getMonth()} /> : <p className="muted">Sin plantas todavía.</p>}
      </Card>

      <div className="grid two">
        <Card className="pad-0" title={undefined}>
          <div className="card-head" style={{ padding: "18px 20px 0" }}>
            <div><h3>Envíos urgentes</h3><div className="sub">Por fecha de cliente</div></div>
            <button className="btn ghost sm" onClick={() => navigate(SECTION_PATH.shipments)}>Ver todos</button>
          </div>
          {s.urgent.length === 0 ? (
            <EmptyState icon={CircleCheck} title="Sin envíos urgentes" message={`Todo va a tiempo en los próximos ${urgency} días.`} />
          ) : (
            <div className="list">
              {s.urgent.slice(0, 5).map((u) => (
                <button key={u.id} className="list-row" onClick={() => navigate(paths.assignment(u.id))}>
                  <Avatar name={u.plant} icon={Building2} size={38} />
                  <div className="grow">
                    <div className="bold ellipsis">{u.title}</div>
                    <div className="tiny muted ellipsis">{u.client} · {u.plant}</div>
                  </div>
                  <div className="right">
                    <Pill text={fmtRelativeDays(u.days)} tint={(u.days ?? 0) < 0 ? "danger" : "warning"} />
                    <div className="tiny faint num" style={{ marginTop: 3 }}>{fmtInt(u.toShip)} por enviar</div>
                  </div>
                </button>
              ))}
            </div>
          )}
        </Card>
        <Card className="pad-0">
          <div className="card-head" style={{ padding: "18px 20px 0" }}>
            <div><h3>Cortes por asignar</h3><div className="sub">Más próximos a entregar</div></div>
            <button className="btn ghost sm" onClick={() => navigate(SECTION_PATH.orders)}>Ver todos</button>
          </div>
          {s.pending.length === 0 ? (
            <EmptyState icon={Inbox} title="Todo asignado" message="No hay prendas pendientes de asignar a planta." />
          ) : (
            <div className="list">
              {s.pending.slice(0, 5).map((o) => (
                <button key={o.order.id} className="list-row" onClick={() => navigate(paths.order(o.order.id))}>
                  <Avatar name={o.clientName} icon={Scissors} size={38} />
                  <div className="grow">
                    <div className="bold ellipsis">{o.order.code}</div>
                    <div className="tiny muted ellipsis">{o.clientName} · {o.styleName}</div>
                  </div>
                  <div className="right">
                    <div className="bold num">{fmtInt(o.remaining)}</div>
                    <div className="tiny faint">Entrega {fmtShortDate(o.order.clientDate)}</div>
                  </div>
                </button>
              ))}
            </div>
          )}
        </Card>
      </div>

      <Card className="pad-0">
        <div className="card-head" style={{ padding: "18px 20px 0" }}>
          <div><h3>Últimos reportes</h3><div className="sub">Lo que han cargado los gerentes</div></div>
        </div>
        {db.reports.length === 0 ? (
          <EmptyState icon={Inbox} title="Sin reportes" message="Los reportes de planta, corte y envío aparecerán aquí." />
        ) : (
          <div className="list">
            {db.reports.slice(0, 8).map((r) => {
              const a = db.assignmentById.get(r.assignmentID ?? "");
              const info = a ? db.assignmentInfo(a) : null;
              const kind = asReportKind(r.kindRaw);
              return (
                <button key={r.id} className="list-row" onClick={() => a && navigate(paths.assignment(a.id))}>
                  <Pill text={REPORT_SHORT[kind]} tint={REPORT_TINT[kind]} />
                  <div className="grow">
                    <div className="bold ellipsis">{info?.title ?? "Corte"} · {info?.plantName ?? ""}</div>
                    <div className="tiny muted ellipsis">{r.authorName ?? "—"}</div>
                  </div>
                  <span className="tiny faint">{fmtDateTime(r.createdAt)}</span>
                </button>
              );
            })}
          </div>
        )}
      </Card>
    </>
  );
}
