import { ArrowLeft, Banknote, BarChart3, Building2, Download, Factory, PackageCheck, Pencil, Plus, Scissors, Shirt, Trash2, TriangleAlert, Users } from "lucide-react";
import { useMemo, useState } from "react";
import { Link, useNavigate, useParams } from "react-router-dom";
import {
  CUT_STATUS_TINT, CUT_STATUS_TITLE, CUT_STATUSES, REPORT_SHORT, REPORT_TINT, REPORT_TITLE, asReportKind, canEditReport, canManageOrders, creatableReports,
  type CutStatus, type ReportKind,
} from "../domain/enums";
import { daysLeft, isUrgent, productionTotals } from "../domain/rules";
import type { AssignmentDTO, ReportDTO } from "../domain/types";
import type { AssignmentInfo } from "../data/db";
import { useDB, useSession } from "../data/session";
import { fmtDate, fmtDateTime, fmtInt, fmtMoney, fmtRelativeDays, fmtShortDate, parseDate } from "../lib/format";
import { useUrgencyWindow } from "../lib/prefs";
import { toast } from "../lib/toast";
import { Avatar, Card, ConfirmModal, EmptyState, FormModal, InfoRow, KPITile, NumberField, PageHead, Pill, Progress, SearchInput, Seg, SelectField, Swatch, TextField } from "../ui/kit";
import { downloadCSV, matches, useAction, useServices, useWritable } from "./common";
import { paths, SECTION_PATH } from "./nav";

/** Assignments the signed-in user can see (plant managers only their plant). */
function useVisible(): AssignmentInfo[] {
  const db = useDB();
  const { role, user } = useSession();
  return useMemo(() => db.visibleAssignments(role, user.plantID).map((a) => db.assignmentInfo(a)), [db, role, user.plantID]);
}

// Production reports list -----------------------------------------------------------------

type SortKey = "clientDate" | "internalDate" | "toShip" | "revenue";

export function ProductionPage() {
  const db = useDB();
  const { role, user } = useSession();
  const navigate = useNavigate();
  const all = useVisible();
  const [query, setQuery] = useState("");
  const [plantId, setPlantId] = useState("");
  const [status, setStatus] = useState<CutStatus | "">("");
  const [onlyPending, setOnlyPending] = useState(false);
  const [sort, setSort] = useState<SortKey>("clientDate");

  if (role === "Gerente de Planta" && !user.plantID) {
    return <EmptyState icon={Building2} title="Sin planta asignada" message="Pide al administrador que te asigne una planta para ver su producción." />;
  }

  const rows = all
    .filter((r) => !plantId || r.assignment.plantID === plantId)
    .filter((r) => !status || r.cutStatus === status)
    .filter((r) => !onlyPending || r.metrics.toShip > 0)
    .filter((r) => matches(query, r.title, r.order?.list, r.styleName, r.clientName, r.plantName, r.order?.garment))
    .sort((a, b) => {
      switch (sort) {
        case "toShip": return b.metrics.toShip - a.metrics.toShip;
        case "revenue": return b.metrics.revenue - a.metrics.revenue;
        case "internalDate": return (parseDate(a.order?.internalDate)?.getTime() ?? Infinity) - (parseDate(b.order?.internalDate)?.getTime() ?? Infinity);
        default: return (parseDate(a.order?.clientDate)?.getTime() ?? Infinity) - (parseDate(b.order?.clientDate)?.getTime() ?? Infinity);
      }
    });
  const totals = productionTotals(rows.map((r) => r.metrics));
  const plantName = role === "Gerente de Planta" ? db.plantById.get(user.plantID ?? "")?.name : null;

  const exportCSV = () =>
    downloadCSV("Trama-produccion.csv", [
      ["Corte", "Lista", "Cliente", "Estilo", "Prenda", "Planta", "Estado", "Cantidad", "Cortadas", "Producidas", "Plancha", "Empaque", "Bodega", "Enviadas", "Por enviar", "Precio unitario", "Ingreso", "Fecha interna", "Fecha cliente"],
      ...rows.map((r) => [
        r.title, r.order?.list ?? "", r.clientName, r.styleName, r.order?.garment ?? "", r.plantName, CUT_STATUS_TITLE[r.cutStatus],
        r.metrics.quantity, r.metrics.realCut, r.metrics.produced, r.metrics.ironing, r.metrics.packing, r.metrics.warehouse, r.metrics.shipped, r.metrics.toShip,
        r.metrics.unitPrice.toFixed(2), r.metrics.revenue.toFixed(2), fmtDate(r.order?.internalDate), fmtDate(r.order?.clientDate),
      ]),
    ]);

  return (
    <>
      <PageHead title={plantName ? `Producción · ${plantName}` : "Reportes de producción"} subtitle="Avance de planta, corte real y envíos de cada asignación.">
        <button className="btn" onClick={exportCSV} disabled={!rows.length}><Download /> Exportar CSV</button>
      </PageHead>
      <div className="grid kpis">
        <KPITile title="Cantidad total" value={fmtInt(totals.quantity)} icon={Shirt} />
        <KPITile title="Producidas" value={fmtInt(totals.produced)} icon={Factory} tint="info" />
        <KPITile title="Enviadas" value={fmtInt(totals.shipped)} icon={PackageCheck} tint="success" />
        <KPITile title="Por enviar" value={fmtInt(totals.toShip)} icon={TriangleAlert} tint="warning" />
        {role === "Administrador" && <KPITile title="Ingresos" value={fmtMoney(totals.revenue, true)} icon={Banknote} tint="brand" />}
      </div>
      <div className="row wrap">
        <SearchInput value={query} onChange={setQuery} placeholder="Corte, lista, estilo, cliente…" />
        {role !== "Gerente de Planta" && (
          <select className="input" style={{ width: "auto" }} value={plantId} onChange={(e) => setPlantId(e.target.value)} aria-label="Planta">
            <option value="">Todas las plantas</option>
            {db.plants.map((p) => <option key={p.id} value={p.id}>{p.name}</option>)}
          </select>
        )}
        <select className="input" style={{ width: "auto" }} value={status} onChange={(e) => setStatus(e.target.value as CutStatus | "")} aria-label="Estado">
          <option value="">Todos los estados</option>
          {CUT_STATUSES.map((s) => <option key={s} value={s}>{CUT_STATUS_TITLE[s]}</option>)}
        </select>
        <select className="input" style={{ width: "auto" }} value={sort} onChange={(e) => setSort(e.target.value as SortKey)} aria-label="Ordenar por">
          <option value="clientDate">Fecha cliente</option>
          <option value="internalDate">Fecha interna</option>
          <option value="toShip">Por enviar</option>
          <option value="revenue">Ingreso</option>
        </select>
        <label className="check small"><input type="checkbox" checked={onlyPending} onChange={(e) => setOnlyPending(e.target.checked)} /> Con pendientes por enviar</label>
      </div>
      <Card className="pad-0">
        {rows.length === 0 ? (
          all.length === 0
            ? <EmptyState icon={BarChart3} title="Aún no hay cortes en producción" message="Asigna cortes a plantas para verlos aquí." />
            : <EmptyState icon={BarChart3} title="Sin resultados" message="Ajusta o limpia los filtros." />
        ) : (
          <div className="table-wrap">
            <table className="table">
              <thead>
                <tr>
                  <th>Corte</th><th>Planta</th><th>Estado</th><th className="num">Cantidad</th><th className="num">Cortadas</th><th className="num">Producidas</th>
                  <th className="num">Plancha</th><th className="num">Empaque</th><th className="num">Bodega</th><th className="num">Enviadas</th><th className="num">Por enviar</th>
                  {role === "Administrador" && <th className="num">Ingreso</th>}<th>Entrega</th>
                </tr>
              </thead>
              <tbody>
                {rows.map((r) => (
                  <tr key={r.assignment.id} className="click" onClick={() => navigate(paths.assignment(r.assignment.id))}>
                    <td><div className="bold">{r.title}</div><div className="tiny faint">{r.clientName}{r.order?.list ? ` · Lista ${r.order.list}` : ""}</div></td>
                    <td>{r.plantName}</td>
                    <td><Pill text={CUT_STATUS_TITLE[r.cutStatus]} tint={CUT_STATUS_TINT[r.cutStatus]} /></td>
                    <td className="num">{fmtInt(r.metrics.quantity)}</td>
                    <td className="num">{fmtInt(r.metrics.realCut)}</td>
                    <td className="num">{fmtInt(r.metrics.produced)}</td>
                    <td className="num">{fmtInt(r.metrics.ironing)}</td>
                    <td className="num">{fmtInt(r.metrics.packing)}</td>
                    <td className="num">{fmtInt(r.metrics.warehouse)}</td>
                    <td className="num">{fmtInt(r.metrics.shipped)}</td>
                    <td className="num bold">{fmtInt(r.metrics.toShip)}</td>
                    {role === "Administrador" && <td className="num">{fmtMoney(r.metrics.revenue, true)}</td>}
                    <td>{fmtShortDate(r.order?.clientDate)}</td>
                  </tr>
                ))}
              </tbody>
              <tfoot>
                <tr>
                  <td colSpan={3}>Totales · {rows.length}</td>
                  <td className="num">{fmtInt(totals.quantity)}</td><td className="num">—</td><td className="num">{fmtInt(totals.produced)}</td>
                  <td className="num">{fmtInt(totals.ironing)}</td><td className="num">{fmtInt(totals.packing)}</td><td className="num">{fmtInt(totals.warehouse)}</td>
                  <td className="num">{fmtInt(totals.shipped)}</td><td className="num">{fmtInt(totals.toShip)}</td>
                  {role === "Administrador" && <td className="num">{fmtMoney(totals.revenue, true)}</td>}<td />
                </tr>
              </tfoot>
            </table>
          </div>
        )}
      </Card>
    </>
  );
}

// Assignment detail -----------------------------------------------------------------------

export function AssignmentPage() {
  const { id = "" } = useParams();
  const db = useDB();
  const { role, user } = useSession();
  const services = useServices();
  const writable = useWritable();
  const { run } = useAction();
  const [editor, setEditor] = useState<{ kind: ReportKind; report?: ReportDTO } | null>(null);
  const [deleting, setDeleting] = useState<ReportDTO | null>(null);
  const [filter, setFilter] = useState<ReportKind | "all">("all");
  const a = db.assignmentById.get(id);
  if (!a || (role === "Gerente de Planta" && a.plantID !== user.plantID)) {
    return <EmptyState icon={BarChart3} title="Asignación no encontrada" action={<Link className="btn" to={SECTION_PATH.production}>Volver</Link>} />;
  }
  const info = db.assignmentInfo(a);
  const m = info.metrics;
  const style = db.styleById.get(info.order?.styleID ?? "");
  const cutReport = info.reports.find((r) => asReportKind(r.kindRaw) === "corte");
  const kinds = creatableReports(role).filter((k) => k !== "corte" || canManageOrders(role));
  const reports = info.reports.filter((r) => filter === "all" || asReportKind(r.kindRaw) === filter);

  return (
    <>
      <div className="row"><Link to={SECTION_PATH.production} className="btn ghost sm"><ArrowLeft /> Producción</Link></div>
      <PageHead title={`Corte ${info.title}`} subtitle={`${info.clientName} · ${info.plantName} · Producción ${fmtDate(a.scheduledDate)}`}>
        <Pill text={CUT_STATUS_TITLE[info.cutStatus]} tint={CUT_STATUS_TINT[info.cutStatus]} />
        {writable && kinds.map((k) =>
          k === "corte" && cutReport ? (
            <button key={k} className="btn" onClick={() => setEditor({ kind: "corte", report: cutReport })}><Scissors /> Editar reporte de corte</button>
          ) : (
            <button key={k} className="btn primary" onClick={() => setEditor({ kind: k })}><Plus /> {REPORT_TITLE[k]}</button>
          ),
        )}
      </PageHead>

      <div className="grid kpis">
        <KPITile title="Cantidad" value={fmtInt(m.quantity)} icon={Shirt} footnote={m.realCut ? `${fmtInt(m.realCut)} cortadas` : "Sin corte real"} />
        <KPITile title="Producidas" value={fmtInt(m.produced)} icon={Factory} tint="info" footnote={`Plancha ${fmtInt(m.ironing)} · Empaque ${fmtInt(m.packing)}`} />
        <KPITile title="Enviadas" value={fmtInt(m.shipped)} icon={PackageCheck} tint="success" footnote={`de ${fmtInt(m.shippingBase)}`} />
        <KPITile title="Por enviar" value={fmtInt(m.toShip)} icon={TriangleAlert} tint={m.toShip ? "warning" : "success"} footnote={fmtRelativeDays(daysLeft(parseDate(info.order?.clientDate)))} />
      </div>

      <div className="grid split">
        <Card className="pad-0">
          <div className="card-head" style={{ padding: "18px 20px 0" }}>
            <div><h3>Reportes</h3><div className="sub">{info.reports.length} en total</div></div>
            <Seg<ReportKind | "all"> value={filter} onChange={setFilter} options={[{ value: "all", label: "Todos" }, { value: "planta", label: "Planta" }, { value: "corte", label: "Corte" }, { value: "envio", label: "Envío" }]} />
          </div>
          {reports.length === 0 ? (
            <EmptyState icon={BarChart3} title="Sin reportes" message="Los gerentes cargan aquí el avance de planta, el corte real y los envíos." />
          ) : (
            <div className="list">
              {reports.map((r) => {
                const kind = asReportKind(r.kindRaw);
                const editable = writable && canEditReport(role, kind) && (kind !== "corte" || canManageOrders(role));
                return (
                  <div key={r.id} className="list-row static">
                    <Pill text={REPORT_SHORT[kind]} tint={REPORT_TINT[kind]} />
                    <div className="grow">
                      <div className="bold small">{reportSummary(r)}</div>
                      <div className="tiny faint">{r.authorName ?? "—"} · {fmtDateTime(r.createdAt)}</div>
                    </div>
                    {editable && (
                      <>
                        <button className="btn ghost icon sm" aria-label="Editar" onClick={() => setEditor({ kind, report: r })}><Pencil /></button>
                        <button className="btn ghost icon sm danger" aria-label="Eliminar" onClick={() => setDeleting(r)}><Trash2 /></button>
                      </>
                    )}
                  </div>
                );
              })}
            </div>
          )}
        </Card>
        <div className="col" style={{ gap: 16 }}>
          <Card title="Avance de producción" subtitle="Último reporte de planta, corte real y envíos acumulados">
            <div className="col" style={{ gap: 12 }}>
              <div><div className="row small"><span className="grow muted">Producción</span><span className="bold">{Math.round(m.productionProgress * 100)}%</span></div><Progress value={m.productionProgress} tint="info" /></div>
              <div><div className="row small"><span className="grow muted">Envíos</span><span className="bold">{Math.round(m.shippingProgress * 100)}%</span></div><Progress value={m.shippingProgress} tint="success" /></div>
            </div>
            <div className="divider" style={{ margin: "14px 0 6px" }} />
            <InfoRow icon={Users} label="Operarios" value={fmtInt(m.operators)} />
            <InfoRow icon={Users} label="Faltas" value={fmtInt(m.absences)} />
            <InfoRow icon={Building2} label="Planta" value={info.plantName} />
            <InfoRow icon={Banknote} label="Precio unitario" value={fmtMoney(m.unitPrice)} />
            {role === "Administrador" && <InfoRow icon={Banknote} label="Ingreso" value={fmtMoney(m.revenue)} />}
            {info.order && canManageOrders(role) && <Link to={paths.order(info.order.id)} className="btn sm" style={{ marginTop: 10 }}>Ver corte completo</Link>}
          </Card>
          {style && <Card title={style.name ?? "Estilo"} subtitle="Estilo"><Swatch image={style.imageData} name={style.name ?? ""} /></Card>}
        </div>
      </div>
      {editor && <ReportEditor assignment={a} kind={editor.kind} report={editor.report} onClose={() => setEditor(null)} />}
      {deleting && <ConfirmModal title="¿Eliminar este reporte?" onClose={() => setDeleting(null)} onConfirm={() => run(() => services.deleteReport(deleting), "Reporte eliminado")} />}
    </>
  );
}

export function reportSummary(r: ReportDTO): string {
  switch (asReportKind(r.kindRaw)) {
    case "planta": return `${fmtInt(r.produced ?? 0)} producidas · ${fmtInt(r.operators ?? 0)} operarios · ${fmtInt(r.absences ?? 0)} faltas`;
    case "corte": return `${CUT_STATUS_TITLE[(r.cutStatusRaw as CutStatus) ?? "en_espera"] ?? "En espera"} · ${fmtInt(r.realQuantity ?? 0)} cortadas`;
    case "envio": return `Envío ${r.shipmentNumber ?? "—"} · ${fmtInt(r.shippedQuantity ?? 0)} prendas`;
  }
}

export function ReportEditor({ assignment, kind, report, onClose }: { assignment: AssignmentDTO; kind: ReportKind; report?: ReportDTO; onClose: () => void }) {
  const db = useDB();
  const services = useServices();
  const info = db.assignmentInfo(assignment);
  const [plant, setPlant] = useState({
    operators: report?.operators ?? 0, absences: report?.absences ?? 0, produced: report?.produced ?? 0,
    ironing: report?.ironing ?? 0, packing: report?.packing ?? 0, warehouse: report?.warehouse ?? 0,
  });
  const [status, setStatus] = useState<CutStatus>((report?.cutStatusRaw as CutStatus) ?? info.cutStatus);
  const [realQuantity, setRealQuantity] = useState(report?.realQuantity ?? (assignment.quantity ?? 0));
  const shipments = info.reports.filter((r) => asReportKind(r.kindRaw) === "envio").length;
  const [number, setNumber] = useState(report?.shipmentNumber ?? String(shipments + 1));
  const [shipped, setShipped] = useState(report?.shippedQuantity ?? 0);
  const pending = info.metrics.toShip + (report?.shippedQuantity ?? 0);
  const canSave =
    kind === "planta" ? Object.values(plant).every((v) => Number.isInteger(v) && v >= 0)
      : kind === "corte" ? Number.isInteger(realQuantity) && realQuantity >= 0
        : number.trim().length > 0 && shipped > 0 && Number.isInteger(shipped);
  const setP = (k: keyof typeof plant) => (v: number) => setPlant({ ...plant, [k]: v });

  return (
    <FormModal
      title={report ? `Editar ${REPORT_TITLE[kind].toLowerCase()}` : REPORT_TITLE[kind]}
      onClose={onClose}
      canSave={canSave}
      saveLabel={report ? "Guardar" : "Cargar"}
      onSave={async () => {
        if (kind === "planta") await services.savePlantReport(assignment, plant, report);
        else if (kind === "corte") await services.saveCutReport(assignment, status, realQuantity, report);
        else await services.saveShipmentReport(assignment, number, shipped, report);
        toast(report ? "Reporte actualizado" : `Cargaste el ${REPORT_TITLE[kind].toLowerCase()} de ${info.title}`);
      }}
    >
      <div className="banner info">Corte {info.title} · {info.plantName} · {fmtInt(assignment.quantity ?? 0)} prendas</div>
      {kind === "planta" && (
        <>
          <p className="small muted" style={{ margin: 0 }}>Captura el estado actual de la planta. El último reporte reemplaza a los anteriores en los totales.</p>
          <div className="form-section">
            <h4>Personal</h4>
            <div className="form-grid">
              <NumberField label="Operarios" value={plant.operators} onChange={setP("operators")} integer autoFocus />
              <NumberField label="Faltas" value={plant.absences} onChange={setP("absences")} integer />
            </div>
          </div>
          <div className="form-section">
            <h4>Avance</h4>
            <div className="form-grid">
              <NumberField label="Prendas producidas" value={plant.produced} onChange={setP("produced")} integer />
              <NumberField label="En plancha" value={plant.ironing} onChange={setP("ironing")} integer />
              <NumberField label="En empaque" value={plant.packing} onChange={setP("packing")} integer />
              <NumberField label="En bodega" value={plant.warehouse} onChange={setP("warehouse")} integer />
            </div>
          </div>
        </>
      )}
      {kind === "corte" && (
        <>
          <SelectField label="Estado del corte" value={status} onChange={(v) => v && setStatus(v)} options={CUT_STATUSES.map((s) => ({ value: s, label: CUT_STATUS_TITLE[s] }))} />
          <NumberField label="Cantidad real cortada" value={realQuantity} onChange={setRealQuantity} integer
            hint={`Solo hay un reporte de corte por asignación. Si la cantidad real difiere de las ${fmtInt(assignment.quantity ?? 0)} planeadas, los envíos se miden contra la real.`} />
        </>
      )}
      {kind === "envio" && (
        <div className="form-grid">
          <TextField label="Número de envío" value={number} onChange={setNumber} />
          <NumberField label="Cantidad enviada" value={shipped} onChange={setShipped} integer autoFocus hint={`Pendientes por enviar: ${fmtInt(pending)}.`} />
        </div>
      )}
    </FormModal>
  );
}

// Cutting board (kanban) ---------------------------------------------------------------------

export function BoardPage() {
  const db = useDB();
  const { role } = useSession();
  const services = useServices();
  const writable = useWritable();
  const { run } = useAction();
  const navigate = useNavigate();
  const all = useVisible();
  const [query, setQuery] = useState("");
  const [plantId, setPlantId] = useState("");
  const [hideShipped, setHideShipped] = useState(true);
  const [dragId, setDragId] = useState<string | null>(null);
  const [over, setOver] = useState<CutStatus | null>(null);
  const canMove = canManageOrders(role) && writable;

  const rows = all
    .filter((r) => !plantId || r.assignment.plantID === plantId)
    .filter((r) => !hideShipped || !r.metrics.isComplete)
    .filter((r) => matches(query, r.title, r.clientName, r.plantName, r.styleName));

  const move = (id: string, status: CutStatus) => {
    const a = db.assignmentById.get(id);
    if (!a || db.assignmentInfo(a).cutStatus === status) return;
    void run(() => services.moveCut(a, status), `${db.assignmentInfo(a).title} → ${CUT_STATUS_TITLE[status]}`);
  };

  return (
    <>
      <PageHead title="Tablero de corte" subtitle={canMove ? "Arrastra los cortes entre columnas para actualizar su estado." : "Solo administradores y gerentes de cortes pueden mover cortes."} />
      <div className="row wrap">
        <SearchInput value={query} onChange={setQuery} placeholder="Buscar corte, cliente, planta…" />
        <select className="input" style={{ width: "auto" }} value={plantId} onChange={(e) => setPlantId(e.target.value)} aria-label="Planta">
          <option value="">Todas las plantas</option>
          {db.plants.map((p) => <option key={p.id} value={p.id}>{p.name}</option>)}
        </select>
        <label className="check small"><input type="checkbox" checked={hideShipped} onChange={(e) => setHideShipped(e.target.checked)} /> Ocultar enviados</label>
      </div>
      <div className="board">
        {CUT_STATUSES.map((status) => {
          const items = rows.filter((r) => r.cutStatus === status);
          const garments = items.reduce((n, r) => n + r.metrics.quantity, 0);
          return (
            <div
              key={status}
              className={`lane ${over === status ? "over" : ""}`}
              onDragOver={(e) => { if (canMove && dragId) { e.preventDefault(); setOver(status); } }}
              onDragLeave={() => setOver((o) => (o === status ? null : o))}
              onDrop={(e) => { e.preventDefault(); setOver(null); const id = e.dataTransfer.getData("text/plain") || dragId; if (id) move(id, status); setDragId(null); }}
            >
              <div className="lane-head">
                <Pill text={CUT_STATUS_TITLE[status]} tint={CUT_STATUS_TINT[status]} />
                <span className="count">{items.length} {items.length === 1 ? "corte" : "cortes"} · {fmtInt(garments)} prendas</span>
              </div>
              {items.length === 0 && <div className="empty small" style={{ padding: 24 }}>{canMove ? "Arrastra cortes aquí" : "Sin cortes"}</div>}
              {items.map((r) => (
                <div
                  key={r.assignment.id}
                  className={`task ${dragId === r.assignment.id ? "dragging" : ""}`}
                  draggable={canMove}
                  onDragStart={(e) => { e.dataTransfer.setData("text/plain", r.assignment.id); e.dataTransfer.effectAllowed = "move"; setDragId(r.assignment.id); }}
                  onDragEnd={() => { setDragId(null); setOver(null); }}
                  onClick={() => navigate(paths.assignment(r.assignment.id))}
                >
                  <div className="row">
                    <Avatar name={r.plantName} icon={Building2} size={30} />
                    <div className="grow" style={{ minWidth: 0 }}>
                      <div className="bold ellipsis">{r.title}</div>
                      <div className="tiny faint ellipsis">{r.clientName} · {r.plantName}</div>
                    </div>
                  </div>
                  <div className="row tiny muted">
                    <span className="grow">{fmtInt(r.metrics.quantity)} prendas</span>
                    <span>Entrega {fmtShortDate(r.order?.clientDate)}</span>
                  </div>
                  {canMove && (
                    <select
                      className="input"
                      style={{ padding: "5px 8px", fontSize: 12 }}
                      value={status}
                      onClick={(e) => e.stopPropagation()}
                      onChange={(e) => move(r.assignment.id, e.target.value as CutStatus)}
                      aria-label="Mover a"
                    >
                      {CUT_STATUSES.map((s) => <option key={s} value={s}>{s === status ? CUT_STATUS_TITLE[s] : `Mover a ${CUT_STATUS_TITLE[s]}`}</option>)}
                    </select>
                  )}
                </div>
              ))}
            </div>
          );
        })}
      </div>
    </>
  );
}

// Urgent shipments ----------------------------------------------------------------------------

export function ShipmentsPage() {
  const { role } = useSession();
  const navigate = useNavigate();
  const writable = useWritable();
  const all = useVisible();
  const [urgency, setUrgency] = useUrgencyWindow();
  const [shipping, setShipping] = useState<AssignmentDTO | null>(null);

  const items = all
    .map((r) => ({ r, clientDate: parseDate(r.order?.clientDate) }))
    .filter(({ r, clientDate }) => isUrgent(r.metrics.toShip, clientDate, urgency))
    .map(({ r, clientDate }) => ({ r, days: daysLeft(clientDate) }))
    .sort((a, b) => (a.days ?? Infinity) - (b.days ?? Infinity));
  const overdue = items.filter((i) => (i.days ?? 0) < 0).length;
  const canShip = writable && canEditReport(role, "envio");

  return (
    <>
      <PageHead title="Envíos urgentes" subtitle="Entregas dentro de este plazo o vencidas se consideran urgentes.">
        <label className="row small muted">Ventana
          <select className="input" style={{ width: "auto" }} value={urgency} onChange={(e) => setUrgency(Number(e.target.value))}>
            {[3, 5, 7, 10, 14, 21, 30].map((d) => <option key={d} value={d}>{d} días</option>)}
          </select>
        </label>
      </PageHead>
      <div className="grid kpis">
        <KPITile title="Envíos urgentes" value={fmtInt(items.length)} icon={TriangleAlert} tint={items.length ? "danger" : "success"} footnote={`Próximos ${urgency} días`} />
        <KPITile title="Vencidos" value={fmtInt(overdue)} icon={TriangleAlert} tint={overdue ? "danger" : "success"} />
        <KPITile title="Prendas por enviar" value={fmtInt(items.reduce((n, i) => n + i.r.metrics.toShip, 0))} icon={PackageCheck} tint="warning" />
      </div>
      {items.length === 0 ? (
        <Card><EmptyState icon={PackageCheck} title="No hay envíos urgentes" message={`Ningún corte con prendas pendientes vence en los próximos ${urgency} días.`} /></Card>
      ) : (
        <div className="grid three">
          {items.map(({ r, days }) => (
            <Card key={r.assignment.id} style={{ cursor: "pointer" }} onClick={() => navigate(paths.assignment(r.assignment.id))}>
              <div className="row" style={{ marginBottom: 12 }}>
                <div className="kpi-icon tint-bg t-danger" style={{ width: 52, height: 52, flexDirection: "column", gap: 0 }}>
                  <span style={{ fontWeight: 850, fontSize: 18, lineHeight: 1 }}>{Math.abs(days ?? 0)}</span>
                  <span style={{ fontSize: 10, fontWeight: 700 }}>{(days ?? 0) < 0 ? "días tarde" : "días"}</span>
                </div>
                <div className="grow" style={{ minWidth: 0 }}>
                  <div className="bold ellipsis">{r.title}</div>
                  <div className="tiny muted ellipsis">{r.clientName} · {r.plantName}</div>
                  <div className="tiny faint">Entrega {fmtShortDate(r.order?.clientDate)}</div>
                </div>
              </div>
              <div className="row small" style={{ marginBottom: 6 }}>
                <span className="grow muted">{fmtInt(r.metrics.shipped)} de {fmtInt(r.metrics.shippingBase)} enviadas</span>
                <span className="bold">{fmtInt(r.metrics.toShip)} por enviar</span>
              </div>
              <Progress value={r.metrics.shippingProgress} tint="success" />
              {canShip && (
                <button className="btn sm" style={{ marginTop: 12 }} onClick={(e) => { e.stopPropagation(); setShipping(r.assignment); }}>
                  <PackageCheck /> Registrar envío
                </button>
              )}
            </Card>
          ))}
        </div>
      )}
      {shipping && <ReportEditor assignment={shipping} kind="envio" onClose={() => setShipping(null)} />}
    </>
  );
}

