import { ArrowLeft, Banknote, Building2, CalendarDays, Check, Pencil, Plus, Scissors, Shirt, Trash2, TriangleAlert, User, X } from "lucide-react";
import { useMemo, useState } from "react";
import { Link, useNavigate, useParams } from "react-router-dom";
import { ASSIGNMENT_STATE_TINT, ASSIGNMENT_STATE_TITLE, CUT_STATUS_TINT, CUT_STATUS_TITLE, canManageOrders, type AssignmentState } from "../domain/enums";
import { validateAssignment, assignmentErrorMessage } from "../domain/rules";
import type { CutOrderDTO, PlantDTO } from "../domain/types";
import { useDB, useSession } from "../data/session";
import { dateInputFromIso, fmtDate, fmtInt, fmtMoney, fmtMonthYear, fmtShortDate, isoFromDateInput, parseDate } from "../lib/format";
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
      <PageHead title="Cortes" subtitle="Registra los cortes y asígnalos a tus plantas según su capacidad mensual.">
        {canEdit && <button className="btn primary" onClick={() => setEditing("new")}><Plus /> Nuevo corte</button>}
      </PageHead>
      <div className="grid kpis">
        <KPITile title="Cortes pendientes" value={fmtInt(pending.length)} icon={Scissors} tint="thread" />
        <KPITile title="Prendas por asignar" value={fmtInt(pending.reduce((n, i) => n + i.remaining, 0))} icon={Shirt} tint="warning" />
        <KPITile title="Valor por asignar" value={fmtMoney(pending.reduce((n, i) => n + i.remaining * (i.order.unitPrice ?? 0), 0), true)} icon={Banknote} tint="brand" />
      </div>
      <div className="row wrap between">
        <Seg<Filter>
          value={filter}
          onChange={setFilter}
          options={[
            { value: "pending", label: `Por asignar (${pending.length})` },
            { value: "partial", label: "Parcial" },
            { value: "assigned", label: "Asignados" },
            { value: "all", label: `Todos (${infos.length})` },
          ]}
        />
        <SearchInput value={query} onChange={setQuery} placeholder="Código, lista, cliente, estilo…" />
      </div>
      <Card className="pad-0">
        {rows.length === 0 ? (
          query ? <EmptyState icon={Scissors} title="Sin resultados" message="Prueba con otro código, lista o cliente." />
            : <EmptyState icon={Scissors} title="No hay cortes aquí" message="Todos los cortes de este filtro están al día." action={canEdit && <button className="btn primary" onClick={() => setEditing("new")}><Plus /> Nuevo corte</button>} />
        ) : (
          <div className="table-wrap">
            <table className="table">
              <thead>
                <tr><th>Corte</th><th>Cliente</th><th>Estilo</th><th className="num">Cantidad</th><th className="num">Por asignar</th><th>Avance</th><th>Fecha cliente</th><th>Estado</th></tr>
              </thead>
              <tbody>
                {rows.map((i) => (
                  <tr key={i.order.id} className="click" onClick={() => navigate(paths.order(i.order.id))}>
                    <td><div className="bold">{i.order.code}</div><div className="tiny faint">{[i.order.list && `Lista ${i.order.list}`, i.order.garment].filter(Boolean).join(" · ")}</div></td>
                    <td>{i.clientName}</td>
                    <td>{i.styleName}</td>
                    <td className="num">{fmtInt(i.order.quantity ?? 0)}</td>
                    <td className="num bold">{fmtInt(i.remaining)}</td>
                    <td style={{ minWidth: 110 }}><Progress value={(i.order.quantity ?? 0) ? i.assigned / (i.order.quantity ?? 1) : 0} tint={ASSIGNMENT_STATE_TINT[i.state]} /></td>
                    <td>{fmtShortDate(i.order.clientDate)}</td>
                    <td><Pill text={ASSIGNMENT_STATE_TITLE[i.state]} tint={ASSIGNMENT_STATE_TINT[i.state]} /></td>
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
      title={order ? "Editar corte" : "Nuevo corte"}
      onClose={onClose}
      canSave={canSave}
      onSave={async () => {
        const saved = await services.saveOrder(order, {
          code, list, garment, quantity, unitPrice, clientID: clientID || null, styleID: styleID || null,
          internalDate: isoFromDateInput(internalDate), clientDate: isoFromDateInput(clientDate), notes,
        });
        toast(order ? `Corte ${saved.code} actualizado` : `Corte ${saved.code} creado`);
        onSaved?.(saved);
      }}
    >
      <div className="form-section">
        <h4>Identificación</h4>
        <div className="form-grid">
          <TextField label="Código de corte" value={code} onChange={setCode} autoFocus required />
          <TextField label="Lista" value={list} onChange={setList} />
          <TextField label="Prenda" value={garment} onChange={setGarment} placeholder="Prenda (ej. Falda, Jeans)" />
        </div>
      </div>
      <div className="form-section">
        <h4>Cliente y estilo</h4>
        <div className="form-grid">
          <SelectField label="Cliente" value={clientID} onChange={setClientID} placeholder="Sin cliente" options={db.clients.map((c) => ({ value: c.id, label: c.name ?? "Cliente" }))} />
          <SelectField label="Estilo" value={styleID} onChange={setStyleID} placeholder="Sin estilo" options={db.styles.map((s) => ({ value: s.id, label: s.name ?? "Estilo" }))} />
        </div>
      </div>
      <div className="form-section">
        <h4>Cantidad y precio</h4>
        <div className="form-grid">
          <NumberField label="Cantidad" value={quantity} onChange={setQuantity} integer hint={tooFew ? <span className="error-text">Ya hay {fmtInt(assigned)} prendas asignadas; la cantidad no puede ser menor.</span> : undefined} />
          <NumberField label="Precio unitario" value={unitPrice} onChange={setUnitPrice} prefix="$" />
          <Field label="Ingreso total"><div className="input num" style={{ background: "transparent" }}>{fmtMoney((quantity || 0) * (unitPrice || 0))}</div></Field>
        </div>
      </div>
      <div className="form-section">
        <h4>Fechas</h4>
        <div className="form-grid">
          <Field label="Fecha interna"><input className="input" type="date" value={internalDate} onChange={(e) => setInternalDate(e.target.value)} /></Field>
          <Field label="Fecha de entrega al cliente"><input className="input" type="date" value={clientDate} onChange={(e) => setClientDate(e.target.value)} /></Field>
        </div>
      </div>
      <Field label="Notas"><textarea className="input" value={notes} onChange={(e) => setNotes(e.target.value)} /></Field>
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
  if (!order) return <EmptyState icon={Scissors} title="Corte no encontrado" message="Quizá se eliminó en otro dispositivo." action={<Link className="btn" to={SECTION_PATH.orders}>Volver a cortes</Link>} />;

  const info = db.orderInfo(order);
  const style = db.styleById.get(order.styleID ?? "");
  const assignments = (db.assignmentsByOrder.get(order.id) ?? []).map((a) => db.assignmentInfo(a));
  const canEdit = canManageOrders(role) && writable;

  return (
    <>
      <div className="row"><Link to={SECTION_PATH.orders} className="btn ghost sm"><ArrowLeft /> Cortes</Link></div>
      <PageHead title={`Corte ${order.code}`} subtitle={[info.clientName, order.list && `Lista ${order.list}`, order.garment].filter(Boolean).join(" · ")}>
        <Pill text={ASSIGNMENT_STATE_TITLE[info.state]} tint={ASSIGNMENT_STATE_TINT[info.state]} />
        {canEdit && (
          <>
            <button className="btn" onClick={() => setEditing(true)}><Pencil /> Editar</button>
            <button className="btn danger" onClick={() => setDeleting(true)}><Trash2 /> Eliminar</button>
          </>
        )}
      </PageHead>

      <div className="grid split">
        <Card title="Asignaciones" subtitle="Dónde se está produciendo este corte" action={canEdit && info.remaining > 0 && <button className="btn primary" onClick={() => setAssigning(true)}><Building2 /> Asignar a planta</button>}>
          <div className="col" style={{ gap: 8, marginBottom: 14 }}>
            <div className="row small"><span className="grow muted">{fmtInt(info.assigned)} asignadas de {fmtInt(order.quantity ?? 0)}</span><span className="bold">{fmtInt(info.remaining)} prendas por asignar</span></div>
            <Progress value={(order.quantity ?? 0) ? info.assigned / (order.quantity ?? 1) : 0} tint={ASSIGNMENT_STATE_TINT[info.state]} />
          </div>
          {assignments.length === 0 ? (
            <EmptyState icon={Building2} title="Sin asignar" message="Asigna prendas a una planta según su capacidad mensual." />
          ) : (
            <div className="list" style={{ margin: "0 -20px -20px" }}>
              {assignments.map((a) => (
                <div key={a.assignment.id} className="list-row" onClick={() => navigate(paths.assignment(a.assignment.id))}>
                  <Avatar name={a.plantName} icon={Building2} size={38} />
                  <div className="grow">
                    <div className="bold">{a.plantName}</div>
                    <div className="tiny muted">{fmtInt(a.assignment.quantity ?? 0)} prendas · {fmtMoney(a.metrics.revenue)} · {fmtDate(a.assignment.scheduledDate)}</div>
                  </div>
                  <Pill text={CUT_STATUS_TITLE[a.cutStatus]} tint={CUT_STATUS_TINT[a.cutStatus]} />
                  {canEdit && a.reports.length === 0 && (
                    <button className="btn ghost icon sm" title="Quitar asignación" aria-label="Quitar asignación" onClick={(e) => { e.stopPropagation(); setUnassigning(a.assignment.id); }}><X /></button>
                  )}
                </div>
              ))}
            </div>
          )}
        </Card>
        <div className="col" style={{ gap: 16 }}>
          <Card title="Detalle">
            <InfoRow icon={Shirt} label="Prenda" value={order.garment || "—"} />
            <InfoRow icon={Scissors} label="Cantidad" value={fmtInt(order.quantity ?? 0)} />
            <InfoRow icon={Banknote} label="Precio unitario" value={fmtMoney(order.unitPrice ?? 0)} />
            <InfoRow icon={Banknote} label="Ingreso total" value={fmtMoney(info.revenue)} />
            <InfoRow icon={CalendarDays} label="Fecha interna" value={fmtDate(order.internalDate)} />
            <InfoRow icon={CalendarDays} label="Fecha cliente" value={fmtDate(order.clientDate)} />
            <InfoRow icon={User} label="Editado por" value={order.editedBy || "—"} />
            {order.notes && <p className="small muted" style={{ whiteSpace: "pre-wrap", marginBottom: 0 }}>{order.notes}</p>}
          </Card>
          {style && (
            <Card title={style.name ?? "Estilo"} subtitle="Estilo">
              <Swatch image={style.imageData} name={style.name ?? ""} onClick={style.imageData ? () => setZoom(true) : undefined} />
            </Card>
          )}
        </div>
      </div>

      {editing && <OrderForm order={order} onClose={() => setEditing(false)} />}
      {assigning && <AssignModal order={order} onClose={() => setAssigning(false)} />}
      {zoom && style?.imageData && <Modal title={style.name ?? "Estilo"} onClose={() => setZoom(false)} size="wide"><div className="lightbox"><img src={imageSrc(style.imageData)!} alt="" /></div></Modal>}
      {deleting && (
        <ConfirmModal
          title={`¿Eliminar el corte ${order.code}?`}
          message="Se eliminarán también sus asignaciones sin reportes."
          onClose={() => setDeleting(false)}
          onConfirm={async () => {
            if (await run(() => services.deleteOrder(order), "Corte eliminado")) navigate(SECTION_PATH.orders);
          }}
        />
      )}
      {unassigning && (
        <ConfirmModal
          title="¿Quitar esta asignación?"
          message="Las prendas vuelven a quedar por asignar."
          confirmLabel="Quitar asignación"
          onClose={() => setUnassigning(null)}
          onConfirm={() => {
            const a = db.assignmentById.get(unassigning);
            return a && run(() => services.unassign(a), "Asignación eliminada");
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
      title={`Asignar ${order.code}`}
      size="wide"
      onClose={onClose}
      canSave={!!plant && !!result?.ok}
      saveLabel="Asignar"
      onSave={async () => {
        await services.assign(order, plant!, quantity, isoFromDateInput(date));
        toast(`Asignaste ${fmtInt(quantity)} prendas a ${plant!.name}`);
      }}
    >
      <div className="form-grid">
        <div className="col">
          <NumberField label="Cantidad" value={quantity} onChange={setQuantity} integer hint={`${fmtInt(info.remaining)} prendas pendientes de ${fmtInt(order.quantity ?? 0)}`} autoFocus />
          <div className="row wrap">
            {[0.25, 0.5, 0.75, 1].map((f) => (
              <button key={f} type="button" className="btn sm" onClick={() => setQuantity(Math.max(1, Math.round(info.remaining * f)))}>{f === 1 ? "Todo" : `${f * 100}%`}</button>
            ))}
          </div>
          <InfoRow icon={Banknote} label="Valor de la asignación" value={fmtMoney(value)} />
        </div>
        <Field label="Mes de producción" hint="La capacidad de cada planta es mensual">
          <input className="input" type="date" value={date} onChange={(e) => setDate(e.target.value)} />
        </Field>
      </div>
      {styleDistribution.length > 0 && (
        <div className="col" style={{ gap: 8 }}>
          <span className="label">Este estilo ya se produce en</span>
          <div className="row wrap">{styleDistribution.map((d) => <Pill key={d.plant!.id} icon={Building2} tint="brand" text={`${d.plant!.name} · ${d.count}`} />)}</div>
        </div>
      )}
      <div className="col" style={{ gap: 10 }}>
        <span className="label">Plantas · capacidad de {monthDate ? fmtMonthYear(monthDate) : "—"}</span>
        {db.plants.length === 0 && <EmptyState icon={Building2} title="No hay plantas" message="Crea una planta en Catálogos → Plantas." />}
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
                    <div className="tiny faint">Máx. {fmtMoney(p.maxCapacity ?? 0, true)}/mes</div>
                  </div>
                  <Pill text={fits ? "Cabe" : "Excede"} icon={fits ? Check : TriangleAlert} tint={fits ? "success" : "danger"} />
                </div>
                <CapacityBar used={used} max={p.maxCapacity ?? 0} preview={selected || fits ? value : 0} />
                <div className="row tiny muted" style={{ marginTop: 6 }}>
                  <span className="grow">Usado {fmtMoney(used, true)}</span>
                  <span>Disponible {fmtMoney(Math.max(0, available), true)}</span>
                </div>
              </button>
            );
          })}
        </div>
      </div>
      <div className="banner info" style={{ justifyContent: "space-between" }}>
        {plant ? (
          <>
            <span>{fmtInt(quantity || 0)} prendas → {plant.name}</span>
            {result && !result.ok ? <span className="error-text">{assignmentErrorMessage(result.error)}</span> : <span>{fmtMoney(value)} en {monthDate ? fmtMonthYear(monthDate) : "—"}</span>}
          </>
        ) : (
          <span>Elige una planta</span>
        )}
      </div>
    </FormModal>
  );
}
