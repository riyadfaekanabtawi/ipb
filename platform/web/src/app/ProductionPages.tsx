import { ArrowLeft, Banknote, BarChart3, Building2, Download, Factory, PackageCheck, Pencil, Plus, Scissors, Shirt, Trash2, TriangleAlert, Users } from "lucide-react";
import { useMemo, useState } from "react";
import { Link, useNavigate, useParams } from "react-router-dom";
import {
  CUT_STATUS_TINT, cutStatusTitle, CUT_STATUSES, reportShort, REPORT_TINT, reportTitle, asReportKind, asCutStatus, canEditReport, canManageOrders, creatableReports,
  type CutStatus, type ReportKind,
} from "../domain/enums";
import { t } from "../i18n";
import { daysLeft, isUrgent, productionTotals } from "../domain/rules";
import type { AssignmentDTO, ReportDTO } from "../domain/types";
import type { AssignmentInfo } from "../data/db";
import { useDB, useSession } from "../data/session";
import { fmtDate, fmtDateTime, fmtInt, fmtMoney, fmtPercent, fmtRelativeDays, fmtShortDate, parseDate } from "../lib/format";
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
    return <EmptyState icon={Building2} title={t("prod.noPlantTitle")} message={t("prod.noPlantMessage")} />;
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
    downloadCSV(t("prod.csvFile"), [
      [
        t("common.cut"), t("prod.csvList"), t("common.client"), t("common.style"), t("prod.csvGarment"), t("common.plant"), t("common.status"), t("common.quantity"),
        t("prod.colCut"), t("prod.produced"), t("prod.colIroning"), t("prod.colPacking"), t("prod.colWarehouse"), t("prod.shipped"), t("prod.toShip"),
        t("common.unitPrice"), t("common.revenue"), t("orders.internalDate"), t("orders.clientDate"),
      ],
      ...rows.map((r) => [
        r.title, r.order?.list ?? "", r.clientName, r.styleName, r.order?.garment ?? "", r.plantName, cutStatusTitle(r.cutStatus),
        r.metrics.quantity, r.metrics.realCut, r.metrics.produced, r.metrics.ironing, r.metrics.packing, r.metrics.warehouse, r.metrics.shipped, r.metrics.toShip,
        r.metrics.unitPrice.toFixed(2), r.metrics.revenue.toFixed(2), fmtDate(r.order?.internalDate), fmtDate(r.order?.clientDate),
      ]),
    ]);

  return (
    <>
      <PageHead title={plantName ? t("prod.titleForPlant", { plant: plantName }) : t("section.production")} subtitle={t("prod.subtitle")}>
        <button className="btn" onClick={exportCSV} disabled={!rows.length}><Download /> {t("prod.exportCsv")}</button>
      </PageHead>
      <div className="grid kpis">
        <KPITile title={t("prod.totalQuantity")} value={fmtInt(totals.quantity)} icon={Shirt} />
        <KPITile title={t("prod.produced")} value={fmtInt(totals.produced)} icon={Factory} tint="info" />
        <KPITile title={t("prod.shipped")} value={fmtInt(totals.shipped)} icon={PackageCheck} tint="success" />
        <KPITile title={t("prod.toShip")} value={fmtInt(totals.toShip)} icon={TriangleAlert} tint="warning" />
        {role === "Administrador" && <KPITile title={t("prod.revenueKpi")} value={fmtMoney(totals.revenue, true)} icon={Banknote} tint="brand" />}
      </div>
      <div className="row wrap">
        <SearchInput value={query} onChange={setQuery} placeholder={t("prod.searchPlaceholder")} />
        {role !== "Gerente de Planta" && (
          <select className="input" style={{ width: "auto" }} value={plantId} onChange={(e) => setPlantId(e.target.value)} aria-label={t("common.plant")}>
            <option value="">{t("common.allPlants")}</option>
            {db.plants.map((p) => <option key={p.id} value={p.id}>{p.name}</option>)}
          </select>
        )}
        <select className="input" style={{ width: "auto" }} value={status} onChange={(e) => setStatus(e.target.value as CutStatus | "")} aria-label={t("common.status")}>
          <option value="">{t("common.allStates")}</option>
          {CUT_STATUSES.map((s) => <option key={s} value={s}>{cutStatusTitle(s)}</option>)}
        </select>
        <select className="input" style={{ width: "auto" }} value={sort} onChange={(e) => setSort(e.target.value as SortKey)} aria-label={t("prod.sortBy")}>
          <option value="clientDate">{t("orders.clientDate")}</option>
          <option value="internalDate">{t("orders.internalDate")}</option>
          <option value="toShip">{t("prod.toShip")}</option>
          <option value="revenue">{t("common.revenue")}</option>
        </select>
        <label className="check small"><input type="checkbox" checked={onlyPending} onChange={(e) => setOnlyPending(e.target.checked)} /> {t("prod.onlyPending")}</label>
      </div>
      <Card className="pad-0">
        {rows.length === 0 ? (
          all.length === 0
            ? <EmptyState icon={BarChart3} title={t("prod.emptyTitle")} message={t("prod.emptyMessage")} />
            : <EmptyState icon={BarChart3} title={t("common.noResults")} message={t("prod.adjustFilters")} />
        ) : (
          <div className="table-wrap">
            <table className="table">
              <thead>
                <tr>
                  <th>{t("common.cut")}</th><th>{t("common.plant")}</th><th>{t("common.status")}</th><th className="num">{t("common.quantity")}</th><th className="num">{t("prod.colCut")}</th><th className="num">{t("prod.produced")}</th>
                  <th className="num">{t("prod.colIroning")}</th><th className="num">{t("prod.colPacking")}</th><th className="num">{t("prod.colWarehouse")}</th><th className="num">{t("prod.shipped")}</th><th className="num">{t("prod.toShip")}</th>
                  {role === "Administrador" && <th className="num">{t("common.revenue")}</th>}<th>{t("prod.colDelivery")}</th>
                </tr>
              </thead>
              <tbody>
                {rows.map((r) => (
                  <tr key={r.assignment.id} className="click" onClick={() => navigate(paths.assignment(r.assignment.id))}>
                    <td><div className="bold">{r.title}</div><div className="tiny faint">{r.clientName}{r.order?.list ? ` · ${t("common.list", { list: r.order.list })}` : ""}</div></td>
                    <td>{r.plantName}</td>
                    <td><Pill text={cutStatusTitle(r.cutStatus)} tint={CUT_STATUS_TINT[r.cutStatus]} /></td>
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
                  <td colSpan={3}>{t("prod.totals", { count: rows.length })}</td>
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
    return <EmptyState icon={BarChart3} title={t("prod.notFound")} action={<Link className="btn" to={SECTION_PATH.production}>{t("common.back")}</Link>} />;
  }
  const info = db.assignmentInfo(a);
  const m = info.metrics;
  const style = db.styleById.get(info.order?.styleID ?? "");
  const cutReport = info.reports.find((r) => asReportKind(r.kindRaw) === "corte");
  const kinds = creatableReports(role).filter((k) => k !== "corte" || canManageOrders(role));
  const reports = info.reports.filter((r) => filter === "all" || asReportKind(r.kindRaw) === filter);

  return (
    <>
      <div className="row"><Link to={SECTION_PATH.production} className="btn ghost sm"><ArrowLeft /> {t("prod.back")}</Link></div>
      <PageHead title={t("orders.detailTitle", { code: info.title })} subtitle={t("prod.detailSubtitle", { client: info.clientName, plant: info.plantName, date: fmtDate(a.scheduledDate) })}>
        <Pill text={cutStatusTitle(info.cutStatus)} tint={CUT_STATUS_TINT[info.cutStatus]} />
        {writable && kinds.map((k) =>
          k === "corte" && cutReport ? (
            <button key={k} className="btn" onClick={() => setEditor({ kind: "corte", report: cutReport })}><Scissors /> {t("prod.editCutReport")}</button>
          ) : (
            <button key={k} className="btn primary" onClick={() => setEditor({ kind: k })}><Plus /> {reportTitle(k)}</button>
          ),
        )}
      </PageHead>

      <div className="grid kpis">
        <KPITile title={t("common.quantity")} value={fmtInt(m.quantity)} icon={Shirt} footnote={m.realCut ? t("prod.cutCount", { count: m.realCut }) : t("prod.noRealCut")} />
        <KPITile title={t("prod.produced")} value={fmtInt(m.produced)} icon={Factory} tint="info" footnote={t("prod.ironingPacking", { ironing: m.ironing, packing: m.packing })} />
        <KPITile title={t("prod.shipped")} value={fmtInt(m.shipped)} icon={PackageCheck} tint="success" footnote={t("prod.ofBase", { count: m.shippingBase })} />
        <KPITile title={t("prod.toShip")} value={fmtInt(m.toShip)} icon={TriangleAlert} tint={m.toShip ? "warning" : "success"} footnote={fmtRelativeDays(daysLeft(parseDate(info.order?.clientDate)))} />
      </div>

      <div className="grid split">
        <Card className="pad-0">
          <div className="card-head" style={{ padding: "18px 20px 0" }}>
            <div><h3>{t("prod.reports")}</h3><div className="sub">{t("common.total", { count: info.reports.length })}</div></div>
            <Seg<ReportKind | "all"> value={filter} onChange={setFilter} options={[{ value: "all", label: t("prod.filterAll") }, { value: "planta", label: reportShort("planta") }, { value: "corte", label: reportShort("corte") }, { value: "envio", label: reportShort("envio") }]} />
          </div>
          {reports.length === 0 ? (
            <EmptyState icon={BarChart3} title={t("dash.noReports")} message={t("prod.noReportsMessage")} />
          ) : (
            <div className="list">
              {reports.map((r) => {
                const kind = asReportKind(r.kindRaw);
                const editable = writable && canEditReport(role, kind) && (kind !== "corte" || canManageOrders(role));
                return (
                  <div key={r.id} className="list-row static">
                    <Pill text={reportShort(kind)} tint={REPORT_TINT[kind]} />
                    <div className="grow">
                      <div className="bold small">{reportSummary(r)}</div>
                      <div className="tiny faint">{r.authorName ?? "—"} · {fmtDateTime(r.createdAt)}</div>
                    </div>
                    {editable && (
                      <>
                        <button className="btn ghost icon sm" aria-label={t("common.edit")} onClick={() => setEditor({ kind, report: r })}><Pencil /></button>
                        <button className="btn ghost icon sm danger" aria-label={t("common.delete")} onClick={() => setDeleting(r)}><Trash2 /></button>
                      </>
                    )}
                  </div>
                );
              })}
            </div>
          )}
        </Card>
        <div className="col" style={{ gap: 16 }}>
          <Card title={t("prod.progressTitle")} subtitle={t("prod.progressSubtitle")}>
            <div className="col" style={{ gap: 12 }}>
              <div><div className="row small"><span className="grow muted">{t("prod.production")}</span><span className="bold">{fmtPercent(m.productionProgress)}</span></div><Progress value={m.productionProgress} tint="info" /></div>
              <div><div className="row small"><span className="grow muted">{t("prod.shipments")}</span><span className="bold">{fmtPercent(m.shippingProgress)}</span></div><Progress value={m.shippingProgress} tint="success" /></div>
            </div>
            <div className="divider" style={{ margin: "14px 0 6px" }} />
            <InfoRow icon={Users} label={t("prod.operators")} value={fmtInt(m.operators)} />
            <InfoRow icon={Users} label={t("prod.absences")} value={fmtInt(m.absences)} />
            <InfoRow icon={Building2} label={t("common.plant")} value={info.plantName} />
            <InfoRow icon={Banknote} label={t("common.unitPrice")} value={fmtMoney(m.unitPrice)} />
            {role === "Administrador" && <InfoRow icon={Banknote} label={t("common.revenue")} value={fmtMoney(m.revenue)} />}
            {info.order && canManageOrders(role) && <Link to={paths.order(info.order.id)} className="btn sm" style={{ marginTop: 10 }}>{t("prod.viewOrder")}</Link>}
          </Card>
          {style && <Card title={style.name ?? t("common.style")} subtitle={t("common.style")}><Swatch image={style.imageData} name={style.name ?? ""} /></Card>}
        </div>
      </div>
      {editor && <ReportEditor assignment={a} kind={editor.kind} report={editor.report} onClose={() => setEditor(null)} />}
      {deleting && <ConfirmModal title={t("prod.deleteReportTitle")} onClose={() => setDeleting(null)} onConfirm={() => run(() => services.deleteReport(deleting), t("prod.reportDeleted"))} />}
    </>
  );
}

export function reportSummary(r: ReportDTO): string {
  switch (asReportKind(r.kindRaw)) {
    case "planta": return t("prod.summaryPlant", { produced: r.produced ?? 0, operators: r.operators ?? 0, absences: r.absences ?? 0 });
    case "corte": return t("prod.summaryCut", { status: cutStatusTitle(asCutStatus(r.cutStatusRaw)), count: r.realQuantity ?? 0 });
    case "envio": return t("prod.summaryShipment", { number: r.shipmentNumber ?? "—", count: r.shippedQuantity ?? 0 });
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
      title={report ? t(`report.editTitle.${kind}`) : reportTitle(kind)}
      onClose={onClose}
      canSave={canSave}
      saveLabel={report ? t("common.save") : t("report.upload")}
      onSave={async () => {
        if (kind === "planta") await services.savePlantReport(assignment, plant, report);
        else if (kind === "corte") await services.saveCutReport(assignment, status, realQuantity, report);
        else await services.saveShipmentReport(assignment, number, shipped, report);
        toast(report ? t("report.updated") : t(`report.created.${kind}`, { cut: info.title }));
      }}
    >
      <div className="banner info">{t("report.banner", { cut: info.title, plant: info.plantName, count: assignment.quantity ?? 0 })}</div>
      {kind === "planta" && (
        <>
          <p className="small muted" style={{ margin: 0 }}>{t("report.plantIntro")}</p>
          <div className="form-section">
            <h4>{t("report.staff")}</h4>
            <div className="form-grid">
              <NumberField label={t("prod.operators")} value={plant.operators} onChange={setP("operators")} integer autoFocus />
              <NumberField label={t("prod.absences")} value={plant.absences} onChange={setP("absences")} integer />
            </div>
          </div>
          <div className="form-section">
            <h4>{t("report.progress")}</h4>
            <div className="form-grid">
              <NumberField label={t("report.producedGarments")} value={plant.produced} onChange={setP("produced")} integer />
              <NumberField label={t("report.ironing")} value={plant.ironing} onChange={setP("ironing")} integer />
              <NumberField label={t("report.packing")} value={plant.packing} onChange={setP("packing")} integer />
              <NumberField label={t("report.warehouse")} value={plant.warehouse} onChange={setP("warehouse")} integer />
            </div>
          </div>
        </>
      )}
      {kind === "corte" && (
        <>
          <SelectField label={t("report.cutStatus")} value={status} onChange={(v) => v && setStatus(v)} options={CUT_STATUSES.map((s) => ({ value: s, label: cutStatusTitle(s) }))} />
          <NumberField label={t("report.realQuantity")} value={realQuantity} onChange={setRealQuantity} integer
            hint={t("report.realQuantityHint", { count: assignment.quantity ?? 0 })} />
        </>
      )}
      {kind === "envio" && (
        <div className="form-grid">
          <TextField label={t("report.shipmentNumber")} value={number} onChange={setNumber} />
          <NumberField label={t("report.shippedQuantity")} value={shipped} onChange={setShipped} integer autoFocus hint={t("report.pendingToShip", { count: pending })} />
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
    void run(() => services.moveCut(a, status), `${db.assignmentInfo(a).title} → ${cutStatusTitle(status)}`);
  };

  return (
    <>
      <PageHead title={t("section.board")} subtitle={canMove ? t("board.subtitleCanMove") : t("board.subtitleReadOnly")} />
      <div className="row wrap">
        <SearchInput value={query} onChange={setQuery} placeholder={t("board.searchPlaceholder")} />
        <select className="input" style={{ width: "auto" }} value={plantId} onChange={(e) => setPlantId(e.target.value)} aria-label={t("common.plant")}>
          <option value="">{t("common.allPlants")}</option>
          {db.plants.map((p) => <option key={p.id} value={p.id}>{p.name}</option>)}
        </select>
        <label className="check small"><input type="checkbox" checked={hideShipped} onChange={(e) => setHideShipped(e.target.checked)} /> {t("board.hideShipped")}</label>
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
                <Pill text={cutStatusTitle(status)} tint={CUT_STATUS_TINT[status]} />
                <span className="count">{t("board.laneCount", { cuts: t("common.cuts", { count: items.length }), garments: t("common.garments", { count: garments }) })}</span>
              </div>
              {items.length === 0 && <div className="empty small" style={{ padding: 24 }}>{canMove ? t("board.dropHere") : t("board.noCuts")}</div>}
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
                    <span className="grow">{t("common.garments", { count: r.metrics.quantity })}</span>
                    <span>{t("common.delivery", { date: fmtShortDate(r.order?.clientDate) })}</span>
                  </div>
                  {canMove && (
                    <select
                      className="input"
                      style={{ padding: "5px 8px", fontSize: 12 }}
                      value={status}
                      onClick={(e) => e.stopPropagation()}
                      onChange={(e) => move(r.assignment.id, e.target.value as CutStatus)}
                      aria-label={t("board.moveTo")}
                    >
                      {CUT_STATUSES.map((s) => <option key={s} value={s}>{s === status ? cutStatusTitle(s) : t("board.moveToStatus", { status: cutStatusTitle(s) })}</option>)}
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
      <PageHead title={t("section.shipments")} subtitle={t("ship.subtitle")}>
        <label className="row small muted">{t("ship.window")}
          <select className="input" style={{ width: "auto" }} value={urgency} onChange={(e) => setUrgency(Number(e.target.value))}>
            {[3, 5, 7, 10, 14, 21, 30].map((d) => <option key={d} value={d}>{t("common.days", { count: d })}</option>)}
          </select>
        </label>
      </PageHead>
      <div className="grid kpis">
        <KPITile title={t("section.shipments")} value={fmtInt(items.length)} icon={TriangleAlert} tint={items.length ? "danger" : "success"} footnote={t("common.nextDays", { count: urgency })} />
        <KPITile title={t("ship.overdue")} value={fmtInt(overdue)} icon={TriangleAlert} tint={overdue ? "danger" : "success"} />
        <KPITile title={t("ship.garmentsToShip")} value={fmtInt(items.reduce((n, i) => n + i.r.metrics.toShip, 0))} icon={PackageCheck} tint="warning" />
      </div>
      {items.length === 0 ? (
        <Card><EmptyState icon={PackageCheck} title={t("ship.emptyTitle")} message={t("ship.emptyMessage", { count: urgency })} /></Card>
      ) : (
        <div className="grid three">
          {items.map(({ r, days }) => (
            <Card key={r.assignment.id} style={{ cursor: "pointer" }} onClick={() => navigate(paths.assignment(r.assignment.id))}>
              <div className="row" style={{ marginBottom: 12 }}>
                <div className="kpi-icon tint-bg t-danger" style={{ width: 52, height: 52, flexDirection: "column", gap: 0 }}>
                  <span style={{ fontWeight: 850, fontSize: 18, lineHeight: 1 }}>{Math.abs(days ?? 0)}</span>
                  <span style={{ fontSize: 10, fontWeight: 700 }}>{(days ?? 0) < 0 ? t("ship.daysLate", { count: Math.abs(days ?? 0) }) : t("ship.daysLeft", { count: Math.abs(days ?? 0) })}</span>
                </div>
                <div className="grow" style={{ minWidth: 0 }}>
                  <div className="bold ellipsis">{r.title}</div>
                  <div className="tiny muted ellipsis">{r.clientName} · {r.plantName}</div>
                  <div className="tiny faint">{t("common.delivery", { date: fmtShortDate(r.order?.clientDate) })}</div>
                </div>
              </div>
              <div className="row small" style={{ marginBottom: 6 }}>
                <span className="grow muted">{t("ship.shippedOf", { shipped: r.metrics.shipped, base: r.metrics.shippingBase })}</span>
                <span className="bold">{t("common.toShipCount", { count: r.metrics.toShip })}</span>
              </div>
              <Progress value={r.metrics.shippingProgress} tint="success" />
              {canShip && (
                <button className="btn sm" style={{ marginTop: 12 }} onClick={(e) => { e.stopPropagation(); setShipping(r.assignment); }}>
                  <PackageCheck /> {t("ship.register")}
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

