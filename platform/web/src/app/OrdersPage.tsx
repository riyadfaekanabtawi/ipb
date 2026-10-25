import { ArrowLeft, Banknote, Building2, CalendarDays, Check, Pencil, Plus, Scissors, Shirt, Trash2, TriangleAlert, User, X } from "lucide-react";
import { useMemo, useState } from "react";
import { Link, useNavigate, useParams } from "react-router-dom";
import { ASSIGNMENT_STATE_TINT, assignmentStateTitle, CUT_STATUS_TINT, cutStatusTitle, canManageOrders, type AssignmentState } from "../domain/enums";
import { t } from "../i18n";
import { validateAssignment, assignmentErrorMessage } from "../domain/rules";
import type { CutOrderDTO, PlantDTO } from "../domain/types";
import { useDB, useSession } from "../data/session";
import { dateInputFromIso, fmtDate, fmtInt, fmtMoney, fmtMonthYear, fmtPercent, fmtShortDate, isoFromDateInput, parseDate } from "../lib/format";
import { Avatar, CapacityBar, Card, ConfirmModal, EmptyState, Field, FormModal, InfoRow, KPITile, Modal, NumberField, PageHead, Pill, Progress, SearchInput, Seg, SelectField, Swatch, TextField, imageSrc } from "../ui/kit";
import { toast } from "../lib/toast";
import { matches, useAction, useServices, useWritable } from "./common";
import { paths, SECTION_PATH } from "./nav";

type Filter = "pending" | "all" | AssignmentState;

export function OrdersPage() {
  const db = useDB();
  const { role } = useSession();
  const navigate = useNavigate();
  const writable = useWritable();
  const [filter, setFilter] = useState<Filter>("pending");
  const [query, setQuery] = useState("");
  const [editing, setEditing] = useState<CutOrderDTO | null | "new">(null);

  const infos = useMemo(() => db.orders.map((o) => db.orderInfo(o)), [db]);
  const rows = infos
    .filter((i) => (filter === "all" ? true : filter === "pending" ? i.remaining > 0 : i.state === filter))
    .filter((i) => matches(query, i.order.code, i.order.list, i.order.garment, i.clientName, i.styleName));
  const pending = infos.filter((i) => i.remaining > 0);
  const canEdit = canManageOrders(role) && writable;

  return (
    <>
      <PageHead title={t("orders.title")} subtitle={t("orders.subtitle")}>
        {canEdit && <button className="btn primary" onClick={() => setEditing("new")}><Plus /> {t("orders.new")}</button>}
      </PageHead>
      <div className="grid kpis">
        <KPITile title={t("orders.kpiPending")} value={fmtInt(pending.length)} icon={Scissors} tint="thread" />
        <KPITile title={t("dash.kpiToAssign")} value={fmtInt(pending.reduce((n, i) => n + i.remaining, 0))} icon={Shirt} tint="warning" />
        <KPITile title={t("orders.kpiValue")} value={fmtMoney(pending.reduce((n, i) => n + i.remaining * (i.order.unitPrice ?? 0), 0), true)} icon={Banknote} tint="brand" />
      </div>
      <div className="row wrap between">
        <Seg<Filter>
          value={filter}
          onChange={setFilter}
          options={[
            { value: "pending", label: t("orders.filterPending", { count: pending.length }) },
            { value: "partial", label: t("orders.filterPartial") },
            { value: "assigned", label: t("orders.filterAssigned") },
            { value: "all", label: t("orders.filterAll", { count: infos.length }) },
          ]}
        />
        <SearchInput value={query} onChange={setQuery} placeholder={t("orders.searchPlaceholder")} />
      </div>
      <Card className="pad-0">
        {rows.length === 0 ? (
          query ? <EmptyState icon={Scissors} title={t("common.noResults")} message={t("orders.noResultsMessage")} />
            : <EmptyState icon={Scissors} title={t("orders.emptyTitle")} message={t("orders.emptyMessage")} action={canEdit && <button className="btn primary" onClick={() => setEditing("new")}><Plus /> {t("orders.new")}</button>} />
        ) : (
          <div className="table-wrap">
            <table className="table">
              <thead>
                <tr><th>{t("common.cut")}</th><th>{t("common.client")}</th><th>{t("common.style")}</th><th className="num">{t("common.quantity")}</th><th className="num">{t("orders.colToAssign")}</th><th>{t("orders.colProgress")}</th><th>{t("orders.colClientDate")}</th><th>{t("common.status")}</th></tr>
              </thead>
              <tbody>
                {rows.map((i) => (
                  <tr key={i.order.id} className="click" onClick={() => navigate(paths.order(i.order.id))}>
                    <td><div className="bold">{i.order.code}</div><div className="tiny faint">{[i.order.list && t("common.list", { list: i.order.list }), i.order.garment].filter(Boolean).join(" · ")}</div></td>
                    <td>{i.clientName}</td>
                    <td>{i.styleName}</td>
                    <td className="num">{fmtInt(i.order.quantity ?? 0)}</td>
                    <td className="num bold">{fmtInt(i.remaining)}</td>
                    <td style={{ minWidth: 110 }}><Progress value={(i.order.quantity ?? 0) ? i.assigned / (i.order.quantity ?? 1) : 0} tint={ASSIGNMENT_STATE_TINT[i.state]} /></td>
                    <td>{fmtShortDate(i.order.clientDate)}</td>
                    <td><Pill text={assignmentStateTitle(i.state)} tint={ASSIGNMENT_STATE_TINT[i.state]} /></td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </Card>
      {editing && <OrderForm order={editing === "new" ? null : editing} onClose={() => setEditing(null)} onSaved={(o) => editing === "new" && navigate(paths.order(o.id))} />}
    </>
  );
}

export function OrderForm({ order, onClose, onSaved }: { order: CutOrderDTO | null; onClose: () => void; onSaved?: (o: CutOrderDTO) => void }) {
  const db = useDB();
  const services = useServices();
  const assigned = order ? db.orderInfo(order).assigned : 0;
  const [code, setCode] = useState(order?.code ?? "");
  const [list, setList] = useState(order?.list ?? "");
  const [garment, setGarment] = useState(order?.garment ?? "");
  const [quantity, setQuantity] = useState(order?.quantity ?? 0);
  const [unitPrice, setUnitPrice] = useState(order?.unitPrice ?? 0);
  const [clientID, setClientID] = useState(order?.clientID ?? "");
  const [styleID, setStyleID] = useState(order?.styleID ?? "");
  const defaultClientDate = new Date();
  defaultClientDate.setDate(defaultClientDate.getDate() + 30);
  const [internalDate, setInternalDate] = useState(dateInputFromIso(order?.internalDate));
  const [clientDate, setClientDate] = useState(order ? dateInputFromIso(order.clientDate) : dateInputFromIso(defaultClientDate.toISOString()));
  const [notes, setNotes] = useState(order?.notes ?? "");
  const tooFew = quantity < assigned;
  const canSave = code.trim().length > 0 && quantity > 0 && Number.isInteger(quantity) && unitPrice >= 0 && !tooFew;

  return (
    <FormModal
      title={order ? t("orders.editTitle") : t("orders.new")}
      onClose={onClose}
      canSave={canSave}
      onSave={async () => {
        const saved = await services.saveOrder(order, {
          code, list, garment, quantity, unitPrice, clientID: clientID || null, styleID: styleID || null,
          internalDate: isoFromDateInput(internalDate), clientDate: isoFromDateInput(clientDate), notes,
        });
        toast(order ? t("orders.updated", { code: saved.code ?? "" }) : t("orders.created", { code: saved.code ?? "" }));
        onSaved?.(saved);
      }}
    >
      <div className="form-section">
        <h4>{t("orders.sectionId")}</h4>
        <div className="form-grid">
          <TextField label={t("orders.code")} value={code} onChange={setCode} autoFocus required />
          <TextField label={t("orders.listLabel")} value={list} onChange={setList} />
          <TextField label={t("orders.garment")} value={garment} onChange={setGarment} placeholder={t("orders.garmentPlaceholder")} />
        </div>
      </div>
      <div className="form-section">
        <h4>{t("orders.sectionClientStyle")}</h4>
        <div className="form-grid">
          <SelectField label={t("common.client")} value={clientID} onChange={setClientID} placeholder={t("common.noClient")} options={db.clients.map((c) => ({ value: c.id, label: c.name ?? t("common.client") }))} />
          <SelectField label={t("common.style")} value={styleID} onChange={setStyleID} placeholder={t("common.noStyle")} options={db.styles.map((s) => ({ value: s.id, label: s.name ?? t("common.style") }))} />
        </div>
      </div>
      <div className="form-section">
        <h4>{t("orders.sectionQuantity")}</h4>
        <div className="form-grid">
          <NumberField label={t("common.quantity")} value={quantity} onChange={setQuantity} integer hint={tooFew ? <span className="error-text">{t("svc.quantityBelowAssigned", { count: assigned })}</span> : undefined} />
          <NumberField label={t("common.unitPrice")} value={unitPrice} onChange={setUnitPrice} prefix="$" />
          <Field label={t("common.totalRevenue")}><div className="input num" style={{ background: "transparent" }}>{fmtMoney((quantity || 0) * (unitPrice || 0))}</div></Field>
        </div>
      </div>
      <div className="form-section">
        <h4>{t("orders.sectionDates")}</h4>
        <div className="form-grid">
          <Field label={t("orders.internalDate")}><input className="input" type="date" value={internalDate} onChange={(e) => setInternalDate(e.target.value)} /></Field>
          <Field label={t("orders.clientDeliveryDate")}><input className="input" type="date" value={clientDate} onChange={(e) => setClientDate(e.target.value)} /></Field>
        </div>
      </div>
      <Field label={t("common.notes")}><textarea className="input" value={notes} onChange={(e) => setNotes(e.target.value)} /></Field>
    </FormModal>
  );
}

export function OrderDetailPage() {
  const { id = "" } = useParams();
  const db = useDB();
  const { role } = useSession();
  const services = useServices();
  const navigate = useNavigate();
  const writable = useWritable();
  const { run } = useAction();
  const [editing, setEditing] = useState(false);
  const [assigning, setAssigning] = useState(false);
  const [deleting, setDeleting] = useState(false);
  const [unassigning, setUnassigning] = useState<string | null>(null);
  const [zoom, setZoom] = useState(false);
  const order = db.orderById.get(id);
  if (!order) return <EmptyState icon={Scissors} title={t("orders.notFound")} message={t("orders.notFoundMessage")} action={<Link className="btn" to={SECTION_PATH.orders}>{t("orders.backToCuts")}</Link>} />;

  const info = db.orderInfo(order);
  const style = db.styleById.get(order.styleID ?? "");
  const assignments = (db.assignmentsByOrder.get(order.id) ?? []).map((a) => db.assignmentInfo(a));
  const canEdit = canManageOrders(role) && writable;

  return (
    <>
      <div className="row"><Link to={SECTION_PATH.orders} className="btn ghost sm"><ArrowLeft /> {t("orders.title")}</Link></div>
      <PageHead title={t("orders.detailTitle", { code: order.code ?? "" })} subtitle={[info.clientName, order.list && t("common.list", { list: order.list }), order.garment].filter(Boolean).join(" · ")}>
        <Pill text={assignmentStateTitle(info.state)} tint={ASSIGNMENT_STATE_TINT[info.state]} />
        {canEdit && (
          <>
            <button className="btn" onClick={() => setEditing(true)}><Pencil /> {t("common.edit")}</button>
            <button className="btn danger" onClick={() => setDeleting(true)}><Trash2 /> {t("common.delete")}</button>
          </>
        )}
      </PageHead>

      <div className="grid split">
        <Card title={t("orders.assignments")} subtitle={t("orders.assignmentsSubtitle")} action={canEdit && info.remaining > 0 && <button className="btn primary" onClick={() => setAssigning(true)}><Building2 /> {t("orders.assignToPlant")}</button>}>
          <div className="col" style={{ gap: 8, marginBottom: 14 }}>
            <div className="row small"><span className="grow muted">{t("orders.assignedOf", { assigned: info.assigned, total: order.quantity ?? 0 })}</span><span className="bold">{t("dash.toAssign", { count: info.remaining })}</span></div>
            <Progress value={(order.quantity ?? 0) ? info.assigned / (order.quantity ?? 1) : 0} tint={ASSIGNMENT_STATE_TINT[info.state]} />
          </div>
          {assignments.length === 0 ? (
            <EmptyState icon={Building2} title={t("orders.unassignedTitle")} message={t("orders.unassignedMessage")} />
          ) : (
            <div className="list" style={{ margin: "0 -20px -20px" }}>
              {assignments.map((a) => (
                <div key={a.assignment.id} className="list-row" onClick={() => navigate(paths.assignment(a.assignment.id))}>
                  <Avatar name={a.plantName} icon={Building2} size={38} />
                  <div className="grow">
                    <div className="bold">{a.plantName}</div>
                    <div className="tiny muted">{t("common.garments", { count: a.assignment.quantity ?? 0 })} · {fmtMoney(a.metrics.revenue)} · {fmtDate(a.assignment.scheduledDate)}</div>
                  </div>
                  <Pill text={cutStatusTitle(a.cutStatus)} tint={CUT_STATUS_TINT[a.cutStatus]} />
                  {canEdit && a.reports.length === 0 && (
                    <button className="btn ghost icon sm" title={t("orders.removeAssignment")} aria-label={t("orders.removeAssignment")} onClick={(e) => { e.stopPropagation(); setUnassigning(a.assignment.id); }}><X /></button>
                  )}
                </div>
              ))}
            </div>
          )}
        </Card>
        <div className="col" style={{ gap: 16 }}>
          <Card title={t("orders.detail")}>
            <InfoRow icon={Shirt} label={t("orders.garment")} value={order.garment || "—"} />
            <InfoRow icon={Scissors} label={t("common.quantity")} value={fmtInt(order.quantity ?? 0)} />
            <InfoRow icon={Banknote} label={t("common.unitPrice")} value={fmtMoney(order.unitPrice ?? 0)} />
            <InfoRow icon={Banknote} label={t("common.totalRevenue")} value={fmtMoney(info.revenue)} />
            <InfoRow icon={CalendarDays} label={t("orders.internalDate")} value={fmtDate(order.internalDate)} />
            <InfoRow icon={CalendarDays} label={t("orders.clientDate")} value={fmtDate(order.clientDate)} />
            <InfoRow icon={User} label={t("orders.editedBy")} value={order.editedBy || "—"} />
            {order.notes && <p className="small muted" style={{ whiteSpace: "pre-wrap", marginBottom: 0 }}>{order.notes}</p>}
          </Card>
          {style && (
            <Card title={style.name ?? t("common.style")} subtitle={t("common.style")}>
              <Swatch image={style.imageData} name={style.name ?? ""} onClick={style.imageData ? () => setZoom(true) : undefined} />
            </Card>
          )}
        </div>
      </div>

      {editing && <OrderForm order={order} onClose={() => setEditing(false)} />}
      {assigning && <AssignModal order={order} onClose={() => setAssigning(false)} />}
      {zoom && style?.imageData && <Modal title={style.name ?? t("common.style")} onClose={() => setZoom(false)} size="wide"><div className="lightbox"><img src={imageSrc(style.imageData)!} alt="" /></div></Modal>}
      {deleting && (
        <ConfirmModal
          title={t("orders.deleteTitle", { code: order.code ?? "" })}
          message={t("orders.deleteMessage")}
          onClose={() => setDeleting(false)}
          onConfirm={async () => {
            if (await run(() => services.deleteOrder(order), t("orders.deleted"))) navigate(SECTION_PATH.orders);
          }}
        />
      )}
      {unassigning && (
        <ConfirmModal
          title={t("orders.unassignTitle")}
          message={t("orders.unassignMessage")}
          confirmLabel={t("orders.removeAssignment")}
          onClose={() => setUnassigning(null)}
          onConfirm={() => {
            const a = db.assignmentById.get(unassigning);
            return a && run(() => services.unassign(a), t("orders.unassigned"));
          }}
        />
      )}
    </>
  );
}

export function AssignModal({ order, onClose }: { order: CutOrderDTO; onClose: () => void }) {
  const db = useDB();
  const services = useServices();
  const info = db.orderInfo(order);
  const [quantity, setQuantity] = useState(info.remaining);
  const today = new Date();
  const [date, setDate] = useState(dateInputFromIso(new Date(today.getFullYear(), today.getMonth(), today.getDate(), 12).toISOString()));
  const [plantId, setPlantId] = useState<string | null>(null);
  const monthDate = parseDate(isoFromDateInput(date));
  const value = (quantity || 0) * (order.unitPrice ?? 0);
  const plant = db.plantById.get(plantId ?? "");

  // Where this style is already produced (helps keep a style in the same plant).
  const styleDistribution = useMemo(() => {
    if (!order.styleID) return [];
    const counts = new Map<string, number>();
    for (const o of db.ordersByStyle.get(order.styleID) ?? []) for (const a of db.assignmentsByOrder.get(o.id) ?? []) if (a.plantID) counts.set(a.plantID, (counts.get(a.plantID) ?? 0) + 1);
    return [...counts.entries()].map(([id, count]) => ({ plant: db.plantById.get(id), count })).filter((x) => x.plant).sort((a, b) => b.count - a.count);
  }, [db, order.styleID]);

  const check = (p: PlantDTO) => validateAssignment({ quantity, unitPrice: order.unitPrice ?? 0, remaining: info.remaining, date: monthDate, ledger: db.ledger(p) });
  const result = plant ? check(plant) : null;

  return (
    <FormModal
      title={t("assign.title", { code: order.code ?? "" })}
      size="wide"
      onClose={onClose}
      canSave={!!plant && !!result?.ok}
      saveLabel={t("assign.save")}
      onSave={async () => {
        await services.assign(order, plant!, quantity, isoFromDateInput(date));
        toast(t("assign.done", { count: quantity, plant: plant!.name ?? "" }));
      }}
    >
      <div className="form-grid">
        <div className="col">
          <NumberField label={t("common.quantity")} value={quantity} onChange={setQuantity} integer hint={t("assign.pendingOf", { remaining: info.remaining, total: order.quantity ?? 0 })} autoFocus />
          <div className="row wrap">
            {[0.25, 0.5, 0.75, 1].map((f) => (
              <button key={f} type="button" className="btn sm" onClick={() => setQuantity(Math.max(1, Math.round(info.remaining * f)))}>{f === 1 ? t("assign.all") : fmtPercent(f)}</button>
            ))}
          </div>
          <InfoRow icon={Banknote} label={t("assign.value")} value={fmtMoney(value)} />
        </div>
        <Field label={t("assign.month")} hint={t("assign.monthHint")}>
          <input className="input" type="date" value={date} onChange={(e) => setDate(e.target.value)} />
        </Field>
      </div>
      {styleDistribution.length > 0 && (
        <div className="col" style={{ gap: 8 }}>
          <span className="label">{t("assign.styleIn")}</span>
          <div className="row wrap">{styleDistribution.map((d) => <Pill key={d.plant!.id} icon={Building2} tint="brand" text={`${d.plant!.name} · ${d.count}`} />)}</div>
        </div>
      )}
      <div className="col" style={{ gap: 10 }}>
        <span className="label">{t("assign.plantsCapacity", { month: monthDate ? fmtMonthYear(monthDate) : "—" })}</span>
        {db.plants.length === 0 && <EmptyState icon={Building2} title={t("assign.noPlants")} message={t("assign.noPlantsMessage")} />}
        <div className="grid three">
          {db.plants.map((p) => {
            const ledger = db.ledger(p);
            const used = monthDate ? ledger.used(monthDate) : 0;
            const available = (p.maxCapacity ?? 0) - used;
            const fits = check(p).ok;
            const selected = p.id === plantId;
            return (
              <button
                type="button"
                key={p.id}
                className="card flat"
                style={{ textAlign: "left", cursor: "pointer", padding: 14, borderColor: selected ? "var(--brand)" : undefined, boxShadow: selected ? "0 0 0 2px color-mix(in srgb, var(--brand) 30%, transparent)" : undefined }}
                onClick={() => setPlantId(p.id)}
              >
                <div className="row" style={{ marginBottom: 10 }}>
                  <Avatar name={p.name ?? ""} icon={Building2} size={36} />
                  <div className="grow" style={{ minWidth: 0 }}>
                    <div className="bold ellipsis">{p.name}</div>
                    <div className="tiny faint">{t("assign.maxPerMonth", { amount: fmtMoney(p.maxCapacity ?? 0, true) })}</div>
                  </div>
                  <Pill text={fits ? t("assign.fits") : t("assign.exceeds")} icon={fits ? Check : TriangleAlert} tint={fits ? "success" : "danger"} />
                </div>
                <CapacityBar used={used} max={p.maxCapacity ?? 0} preview={selected || fits ? value : 0} />
                <div className="row tiny muted" style={{ marginTop: 6 }}>
                  <span className="grow">{t("common.usedAmount", { amount: fmtMoney(used, true) })}</span>
                  <span>{t("common.availableAmount", { amount: fmtMoney(Math.max(0, available), true) })}</span>
                </div>
              </button>
            );
          })}
        </div>
      </div>
      <div className="banner info" style={{ justifyContent: "space-between" }}>
        {plant ? (
          <>
            <span>{t("assign.summary", { count: quantity || 0, plant: plant.name ?? "" })}</span>
            {result && !result.ok ? <span className="error-text">{assignmentErrorMessage(result.error)}</span> : <span>{t("assign.valueIn", { amount: fmtMoney(value), month: monthDate ? fmtMonthYear(monthDate) : "—" })}</span>}
          </>
        ) : (
          <span>{t("assign.pickPlant")}</span>
        )}
      </div>
    </FormModal>
  );
}
