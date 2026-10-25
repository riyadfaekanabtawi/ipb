import { ArrowLeft, Building2, ChevronLeft, ChevronRight, Mail, MapPin, Pencil, Phone, Plus, Scissors, Shirt, Trash2, Truck, UserPlus, Users, X } from "lucide-react";
import { useMemo, useState } from "react";
import { Link, useNavigate, useParams } from "react-router-dom";
import { ASSIGNMENT_STATE_TINT, ASSIGNMENT_STATE_TITLE, CUT_STATUS_TINT, CUT_STATUS_TITLE, PROJECT_STATUS_TINT, PROJECT_STATUS_TITLE, asProjectStatus } from "../domain/enums";
import { isPlausibleEmail } from "../domain/rules";
import type { ClientDTO, ContactDTO, PlantDTO, StyleDTO } from "../domain/types";
import { newContactDraft, type ContactDraft } from "../data/services";
import { useDB } from "../data/session";
import { fmtDate, fmtInt, fmtMoney, fmtMonthYear, fmtPercent, fullName } from "../lib/format";
import { toast } from "../lib/toast";
import { MonthlyColumns } from "../ui/charts";
import { Avatar, CapacityBar, Card, ConfirmModal, EmptyState, FormModal, KPITile, Modal, NumberField, PageHead, Pill, PhotoField, SearchInput, Seg, Swatch, TextField, imageSrc } from "../ui/kit";
import { matches, useAction, useServices, useWritable } from "./common";
import { paths, SECTION_PATH } from "./nav";

// Plants ----------------------------------------------------------------------------------

export function PlantsPage() {
  const db = useDB();
  const navigate = useNavigate();
  const writable = useWritable();
  const [query, setQuery] = useState("");
  const [editing, setEditing] = useState<PlantDTO | null | "new">(null);
  const month = new Date();
  const rows = db.plants.filter((p) => matches(query, p.name, ...(db.managersByPlant.get(p.id) ?? []).map(fullName)));
  const capacity = db.plants.reduce((n, p) => n + (p.maxCapacity ?? 0), 0);
  const used = db.plants.reduce((n, p) => n + db.ledger(p).used(month), 0);

  return (
    <>
      <PageHead title="Plantas" subtitle="La capacidad se mide en pesos por mes: cada asignación consume cantidad × precio unitario.">
        {writable && <button className="btn primary" onClick={() => setEditing("new")}><Plus /> Nueva planta</button>}
      </PageHead>
      <div className="grid kpis">
        <KPITile title="Plantas" value={fmtInt(db.plants.length)} icon={Building2} />
        <KPITile title="Capacidad mensual total" value={fmtMoney(capacity, true)} icon={Building2} tint="info" />
        <KPITile title="Usado este mes" value={fmtMoney(used, true)} icon={Building2} tint="thread" footnote={capacity ? `${fmtPercent(used / capacity)} de la capacidad` : undefined} />
      </div>
      <SearchInput value={query} onChange={setQuery} placeholder="Buscar planta o gerente" />
      {rows.length === 0 ? (
        <Card><EmptyState icon={Building2} title="Sin plantas" message="Agrega tus plantas con su capacidad mensual para empezar a asignar cortes." /></Card>
      ) : (
        <div className="grid three">
          {rows.map((p) => {
            const u = db.ledger(p).used(month);
            const managers = db.managersByPlant.get(p.id) ?? [];
            return (
              <Card key={p.id} style={{ cursor: "pointer" }} onClick={() => navigate(paths.plant(p.id))}>
                <div className="row" style={{ marginBottom: 14 }}>
                  <Avatar name={p.name ?? ""} icon={Building2} size={44} />
                  <div className="grow" style={{ minWidth: 0 }}>
                    <div className="bold ellipsis" style={{ fontSize: 16 }}>{p.name}</div>
                    <div className="tiny muted">Capacidad {fmtMoney(p.maxCapacity ?? 0, true)} al mes</div>
                  </div>
                </div>
                <CapacityBar used={u} max={p.maxCapacity ?? 0} />
                <div className="row tiny muted" style={{ marginTop: 6 }}>
                  <span className="grow">Usado {fmtMoney(u, true)}</span>
                  <span>Disponible {fmtMoney(Math.max(0, (p.maxCapacity ?? 0) - u), true)}</span>
                </div>
                <div className="row tiny faint" style={{ marginTop: 10 }}>
                  <Users size={14} /> {managers.length ? managers.map(fullName).join(", ") : "Sin gerente"}
                </div>
              </Card>
            );
          })}
        </div>
      )}
      {editing && <PlantForm plant={editing === "new" ? null : editing} onClose={() => setEditing(null)} />}
    </>
  );
}

function PlantForm({ plant, onClose }: { plant: PlantDTO | null; onClose: () => void }) {
  const db = useDB();
  const services = useServices();
  const [name, setName] = useState(plant?.name ?? "");
  const [capacity, setCapacity] = useState(plant?.maxCapacity ?? 0);
  const usedNow = plant ? db.ledger(plant).used(new Date()) : 0;
  return (
    <FormModal
      title={plant ? "Editar planta" : "Nueva planta"}
      size="narrow"
      onClose={onClose}
      canSave={name.trim().length > 0 && capacity > 0}
      onSave={async () => {
        const saved = await services.savePlant(plant, name, capacity);
        toast(plant ? "Planta actualizada" : `Planta «${saved.name}» creada`);
      }}
    >
      <TextField label="Nombre" value={name} onChange={setName} autoFocus />
      <NumberField label="Capacidad máxima mensual" value={capacity} onChange={setCapacity} prefix="$"
        hint={plant && capacity > 0 && capacity < usedNow ? <span className="error-text">La nueva capacidad es menor a lo ya asignado este mes.</span> : "En pesos (MXN) por mes."} />
    </FormModal>
  );
}

export function PlantDetailPage() {
  const { id = "" } = useParams();
  const db = useDB();
  const services = useServices();
  const writable = useWritable();
  const navigate = useNavigate();
  const { run } = useAction();
  const [editing, setEditing] = useState(false);
  const [deleting, setDeleting] = useState(false);
  const [month, setMonth] = useState(() => new Date(new Date().getFullYear(), new Date().getMonth(), 1));
  const plant = db.plantById.get(id);
  if (!plant) return <EmptyState icon={Building2} title="Planta no encontrada" action={<Link className="btn" to={SECTION_PATH.plants}>Volver</Link>} />;
  const ledger = db.ledger(plant);
  const used = ledger.used(month);
  const assignments = (db.assignmentsByPlant.get(plant.id) ?? []).map((a) => db.assignmentInfo(a))
    .sort((a, b) => new Date(b.assignment.scheduledDate ?? 0).getTime() - new Date(a.assignment.scheduledDate ?? 0).getTime());
  const managers = db.managersByPlant.get(plant.id) ?? [];
  const index = db.plants.findIndex((p) => p.id === plant.id);

  return (
    <>
      <div className="row"><Link to={SECTION_PATH.plants} className="btn ghost sm"><ArrowLeft /> Plantas</Link></div>
      <PageHead title={plant.name} subtitle={`Capacidad ${fmtMoney(plant.maxCapacity ?? 0)} al mes`}>
        {writable && (
          <>
            <button className="btn" onClick={() => setEditing(true)}><Pencil /> Editar</button>
            <button className="btn danger" onClick={() => setDeleting(true)}><Trash2 /> Eliminar</button>
          </>
        )}
      </PageHead>
      <div className="grid split">
        <Card title="Uso de capacidad" subtitle={fmtMonthYear(month)} action={
          <div className="row">
            <button className="btn ghost icon sm" onClick={() => setMonth(new Date(month.getFullYear(), month.getMonth() - 1, 1))} aria-label="Mes anterior"><ChevronLeft /></button>
            <button className="btn ghost icon sm" onClick={() => setMonth(new Date(month.getFullYear(), month.getMonth() + 1, 1))} aria-label="Mes siguiente"><ChevronRight /></button>
          </div>
        }>
          <div className="row" style={{ marginBottom: 8 }}>
            <span className="kpi-value">{fmtPercent(ledger.utilization(month))}</span>
            <span className="muted small grow">Usado {fmtMoney(used)} · Disponible {fmtMoney(Math.max(0, ledger.available(month)))}</span>
          </div>
          <CapacityBar used={used} max={plant.maxCapacity ?? 0} large />
          <div style={{ marginTop: 18 }}>
            <MonthlyColumns series={[{ name: plant.name ?? "Planta", values: ledger.monthlyUsage(month.getFullYear()), colorIndex: Math.max(0, index) }]} highlightMonth={month.getMonth()} height={180} />
          </div>
        </Card>
        <Card title="Gerentes" subtitle="Ven solo la producción de esta planta">
          {managers.length === 0 ? <p className="muted small">Sin gerente asignado. Asígnalo en Usuarios.</p> : managers.map((u) => (
            <div key={u.id} className="row" style={{ padding: "6px 0" }}>
              <Avatar name={fullName(u)} image={u.avatarData} size={34} />
              <div className="grow"><div className="bold small">{fullName(u)}</div><div className="tiny faint">{u.email}</div></div>
            </div>
          ))}
        </Card>
      </div>
      <Card className="pad-0">
        <div className="card-head" style={{ padding: "18px 20px 0" }}><div><h3>Asignaciones</h3><div className="sub">{assignments.length} en total</div></div></div>
        {assignments.length === 0 ? <EmptyState icon={Scissors} title="Sin asignaciones" message="Asigna cortes desde Cortes por asignar." /> : (
          <div className="list">
            {assignments.map((a) => (
              <button key={a.assignment.id} className="list-row" onClick={() => navigate(paths.assignment(a.assignment.id))}>
                <div className="grow"><div className="bold">{a.title}</div><div className="tiny muted">{a.clientName} · {fmtInt(a.metrics.quantity)} prendas · {fmtDate(a.assignment.scheduledDate)}</div></div>
                <span className="small num">{fmtMoney(a.metrics.revenue, true)}</span>
                <Pill text={CUT_STATUS_TITLE[a.cutStatus]} tint={CUT_STATUS_TINT[a.cutStatus]} />
              </button>
            ))}
          </div>
        )}
      </Card>
      {editing && <PlantForm plant={plant} onClose={() => setEditing(false)} />}
      {deleting && (
        <ConfirmModal title={`¿Eliminar ${plant.name}?`} message="Solo se pueden eliminar plantas sin cortes asignados." onClose={() => setDeleting(false)}
          onConfirm={async () => { if (await run(() => services.deletePlant(plant), `Planta «${plant.name}» eliminada`)) navigate(SECTION_PATH.plants); }} />
      )}
    </>
  );
}

// Clients and suppliers ------------------------------------------------------------------------

type PartyKind = "client" | "supplier";

export function PartiesPage({ kind }: { kind: PartyKind }) {
  const db = useDB();
  const navigate = useNavigate();
  const writable = useWritable();
  const [query, setQuery] = useState("");
  const [editing, setEditing] = useState(false);
  const rows = kind === "client" ? db.clients : db.suppliers;
  const contactsOf = (id: string) => (kind === "client" ? db.contactsByClient : db.contactsBySupplier).get(id) ?? [];
  const filtered = rows.filter((r) => matches(query, r.name, r.address, ...contactsOf(r.id).flatMap((c) => [c.name, c.email])));
  const title = kind === "client" ? "Clientes" : "Proveedores";
  const Icon = kind === "client" ? Users : Truck;

  return (
    <>
      <PageHead title={title} subtitle={kind === "client" ? "Tus clientes, sus contactos y sus cortes." : "Proveedores de tela, avíos y servicios, con sus contactos."}>
        {writable && <button className="btn primary" onClick={() => setEditing(true)}><Plus /> {kind === "client" ? "Nuevo cliente" : "Nuevo proveedor"}</button>}
      </PageHead>
      <SearchInput value={query} onChange={setQuery} placeholder="Buscar por nombre, dirección o contacto" />
      <Card className="pad-0">
        {filtered.length === 0 ? <EmptyState icon={Icon} title={query ? "Sin resultados" : `Sin ${title.toLowerCase()}`} message={query ? "Prueba con otra búsqueda." : undefined} /> : (
          <div className="list">
            {filtered.map((r) => {
              const contacts = contactsOf(r.id);
              const orders = kind === "client" ? (db.ordersByClient.get(r.id) ?? []).length : null;
              return (
                <button key={r.id} className="list-row" onClick={() => navigate(kind === "client" ? paths.client(r.id) : paths.supplier(r.id))}>
                  <Avatar name={r.name ?? ""} size={42} />
                  <div className="grow" style={{ minWidth: 0 }}>
                    <div className="bold ellipsis">{r.name}</div>
                    <div className="tiny muted ellipsis">{r.address || "Sin dirección"}</div>
                  </div>
                  <Pill text={`${contacts.length} ${contacts.length === 1 ? "contacto" : "contactos"}`} tint="muted" />
                  {orders != null && <Pill text={`${orders} ${orders === 1 ? "corte" : "cortes"}`} tint="brand" />}
                </button>
              );
            })}
          </div>
        )}
      </Card>
      {editing && <PartyForm kind={kind} party={null} contacts={[]} onClose={() => setEditing(false)} onSaved={(p) => navigate(kind === "client" ? paths.client(p.id) : paths.supplier(p.id))} />}
    </>
  );
}

function PartyForm({ kind, party, contacts, onClose, onSaved }: { kind: PartyKind; party: ClientDTO | null; contacts: ContactDTO[]; onClose: () => void; onSaved?: (p: ClientDTO) => void }) {
  const services = useServices();
  const [name, setName] = useState(party?.name ?? "");
  const [address, setAddress] = useState(party?.address ?? "");
  const [drafts, setDrafts] = useState<ContactDraft[]>(() =>
    contacts.map((c) => ({ id: c.id, name: c.name ?? "", role: c.role ?? "", email: c.email ?? "", phone: c.phone ?? "" })),
  );
  const update = (i: number, patch: Partial<ContactDraft>) => setDrafts(drafts.map((d, j) => (j === i ? { ...d, ...patch } : d)));
  const label = kind === "client" ? "cliente" : "proveedor";

  return (
    <FormModal
      title={party ? `Editar ${label}` : `Nuevo ${label}`}
      onClose={onClose}
      canSave={name.trim().length > 0}
      onSave={async () => {
        const saved = kind === "client" ? await services.saveClient(party, name, address, drafts) : await services.saveSupplier(party, name, address, drafts);
        toast(party ? `${kind === "client" ? "Cliente" : "Proveedor"} actualizado` : `${kind === "client" ? "Cliente" : "Proveedor"} «${saved.name}» creado`);
        onSaved?.(saved);
      }}
    >
      <div className="form-grid">
        <TextField label="Nombre" value={name} onChange={setName} autoFocus />
        <TextField label="Dirección" value={address} onChange={setAddress} />
      </div>
      <div className="form-section">
        <div className="row between"><h4 style={{ margin: 0, fontSize: 13, textTransform: "uppercase", letterSpacing: "0.06em", color: "var(--text-3)" }}>Contactos</h4>
          <button type="button" className="btn sm" onClick={() => setDrafts([...drafts, newContactDraft()])}><UserPlus /> Agregar contacto</button></div>
        {drafts.length === 0 && <p className="small muted" style={{ margin: 0 }}>Sin contactos. Agrega a las personas con quienes tratas.</p>}
        {drafts.map((d, i) => (
          <div key={d.id} className="card flat" style={{ padding: 14 }}>
            <div className="row" style={{ alignItems: "flex-start" }}>
              <div className="form-grid grow">
                <TextField label="Nombre" value={d.name} onChange={(v) => update(i, { name: v })} />
                <TextField label="Puesto" value={d.role} onChange={(v) => update(i, { role: v })} />
                <TextField label="Correo" type="email" value={d.email} onChange={(v) => update(i, { email: v })} hint={d.email && !isPlausibleEmail(d.email.trim()) ? <span className="error-text">Correo no válido</span> : undefined} />
                <TextField label="Teléfono" type="tel" value={d.phone} onChange={(v) => update(i, { phone: v })} />
              </div>
              <button type="button" className="btn ghost icon sm" aria-label="Quitar contacto" onClick={() => setDrafts(drafts.filter((_, j) => j !== i))}><X /></button>
            </div>
          </div>
        ))}
      </div>
    </FormModal>
  );
}

function ContactCards({ contacts }: { contacts: ContactDTO[] }) {
  if (!contacts.length) return <p className="small muted" style={{ margin: 0 }}>Sin contactos.</p>;
  const emails = contacts.map((c) => c.email).filter((e): e is string => !!e && isPlausibleEmail(e));
  return (
    <div className="col" style={{ gap: 10 }}>
      {emails.length > 1 && <a className="btn sm" href={`mailto:${[...new Set(emails)].join(",")}`}><Mail /> Escribir a todos</a>}
      {contacts.map((c) => (
        <div key={c.id} className="row" style={{ alignItems: "flex-start" }}>
          <Avatar name={c.name || c.email || "?"} size={36} />
          <div className="grow" style={{ minWidth: 0 }}>
            <div className="bold small">{c.name || "Sin nombre"}</div>
            {c.role && <div className="tiny faint">{c.role}</div>}
            <div className="row wrap tiny" style={{ marginTop: 4, gap: 12 }}>
              {c.email && <a href={`mailto:${c.email}`} className="row" style={{ gap: 4 }}><Mail size={13} />{c.email}</a>}
              {c.phone && <a href={`tel:${c.phone.replace(/[^\d+]/g, "")}`} className="row" style={{ gap: 4 }}><Phone size={13} />{c.phone}</a>}
            </div>
          </div>
        </div>
      ))}
    </div>
  );
}

export function PartyDetailPage({ kind }: { kind: PartyKind }) {
  const { id = "" } = useParams();
  const db = useDB();
  const services = useServices();
  const writable = useWritable();
  const navigate = useNavigate();
  const { run } = useAction();
  const [editing, setEditing] = useState(false);
  const [deleting, setDeleting] = useState(false);
  const party = (kind === "client" ? db.clientById : db.supplierById).get(id);
  const back = kind === "client" ? SECTION_PATH.clients : SECTION_PATH.suppliers;
  if (!party) return <EmptyState icon={Users} title="No encontrado" action={<Link className="btn" to={back}>Volver</Link>} />;
  const contacts = (kind === "client" ? db.contactsByClient : db.contactsBySupplier).get(party.id) ?? [];
  const orders = kind === "client" ? (db.ordersByClient.get(party.id) ?? []).map((o) => db.orderInfo(o)) : [];
  const projects = kind === "client" ? (db.projectsByClient.get(party.id) ?? []) : [];

  return (
    <>
      <div className="row"><Link to={back} className="btn ghost sm"><ArrowLeft /> {kind === "client" ? "Clientes" : "Proveedores"}</Link></div>
      <PageHead title={party.name} subtitle={party.address ? <span className="row" style={{ gap: 6 }}><MapPin size={15} />{party.address}</span> : undefined}>
        {writable && (
          <>
            <button className="btn" onClick={() => setEditing(true)}><Pencil /> Editar</button>
            <button className="btn danger" onClick={() => setDeleting(true)}><Trash2 /> Eliminar</button>
          </>
        )}
      </PageHead>
      {kind === "client" && (
        <div className="grid kpis">
          <KPITile title="Cortes" value={fmtInt(orders.length)} icon={Scissors} />
          <KPITile title="Prendas" value={fmtInt(orders.reduce((n, o) => n + (o.order.quantity ?? 0), 0))} icon={Shirt} tint="info" />
          <KPITile title="Ingreso total" value={fmtMoney(orders.reduce((n, o) => n + o.revenue, 0), true)} icon={Scissors} tint="brand" />
        </div>
      )}
      <div className="grid split">
        {kind === "client" ? (
          <Card className="pad-0">
            <div className="card-head" style={{ padding: "18px 20px 0" }}><div><h3>Cortes</h3></div></div>
            {orders.length === 0 ? <EmptyState icon={Scissors} title="Sin cortes" /> : (
              <div className="list">
                {orders.map((o) => (
                  <button key={o.order.id} className="list-row" onClick={() => navigate(paths.order(o.order.id))}>
                    <div className="grow"><div className="bold">{o.order.code}</div><div className="tiny muted">{o.styleName} · {fmtInt(o.order.quantity ?? 0)} prendas · Entrega {fmtDate(o.order.clientDate)}</div></div>
                    <Pill text={ASSIGNMENT_STATE_TITLE[o.state]} tint={ASSIGNMENT_STATE_TINT[o.state]} />
                  </button>
                ))}
              </div>
            )}
          </Card>
        ) : (
          <Card title="Contactos"><ContactCards contacts={contacts} /></Card>
        )}
        <div className="col" style={{ gap: 16 }}>
          {kind === "client" && <Card title="Contactos"><ContactCards contacts={contacts} /></Card>}
          {kind === "client" && projects.length > 0 && (
            <Card title="Proyectos">
              {projects.map((p) => {
                const st = asProjectStatus(p.statusRaw);
                return (
                  <div key={p.id} className="row" style={{ padding: "6px 0" }}>
                    <div className="grow small"><div className="bold">{fmtInt(p.quantity ?? 0)} prendas × {fmtMoney(p.price ?? 0)}</div><div className="tiny faint">{p.fabric ?? "—"}</div></div>
                    <Pill text={PROJECT_STATUS_TITLE[st]} tint={PROJECT_STATUS_TINT[st]} />
                  </div>
                );
              })}
            </Card>
          )}
        </div>
      </div>
      {editing && <PartyForm kind={kind} party={party} contacts={contacts} onClose={() => setEditing(false)} />}
      {deleting && (
        <ConfirmModal
          title={`¿Eliminar ${party.name}?`}
          message={kind === "client" ? "Solo se pueden eliminar clientes sin cortes. Se eliminarán también sus contactos." : "Se eliminarán también sus contactos."}
          onClose={() => setDeleting(false)}
          onConfirm={async () => {
            const ok = await run(() => (kind === "client" ? services.deleteClient(party) : services.deleteSupplier(party)), `«${party.name}» eliminado`);
            if (ok) navigate(back);
          }}
        />
      )}
    </>
  );
}

// Styles -------------------------------------------------------------------------------------

export function StylesPage() {
  const db = useDB();
  const services = useServices();
  const writable = useWritable();
  const { run } = useAction();
  const [query, setQuery] = useState("");
  const [sort, setSort] = useState<"name" | "recent" | "orders">("name");
  const [editing, setEditing] = useState<StyleDTO | null | "new">(null);
  const [deleting, setDeleting] = useState<StyleDTO | null>(null);
  const [zoom, setZoom] = useState<StyleDTO | null>(null);

  const rows = useMemo(() => {
    const list = db.styles.map((s) => {
      const orders = db.ordersByStyle.get(s.id) ?? [];
      const plants = new Map<string, number>();
      for (const o of orders) for (const a of db.assignmentsByOrder.get(o.id) ?? []) if (a.plantID) plants.set(a.plantID, (plants.get(a.plantID) ?? 0) + 1);
      return { style: s, orders: orders.length, plants: [...plants.entries()].map(([id, n]) => ({ name: db.plantById.get(id)?.name ?? "Planta", n })) };
    }).filter((r) => matches(query, r.style.name, ...r.plants.map((p) => p.name)));
    if (sort === "orders") list.sort((a, b) => b.orders - a.orders);
    if (sort === "recent") list.sort((a, b) => new Date(b.style.createdAt ?? 0).getTime() - new Date(a.style.createdAt ?? 0).getTime());
    return list;
  }, [db, query, sort]);

  return (
    <>
      <PageHead title="Estilos" subtitle="Fotografía tus estilos para reconocerlos al instante en cortes y producción.">
        {writable && <button className="btn primary" onClick={() => setEditing("new")}><Plus /> Nuevo estilo</button>}
      </PageHead>
      <div className="row wrap between">
        <SearchInput value={query} onChange={setQuery} placeholder="Buscar estilo o planta" />
        <Seg value={sort} onChange={setSort} options={[{ value: "name", label: "Nombre" }, { value: "recent", label: "Recientes" }, { value: "orders", label: "Más cortes" }]} />
      </div>
      {rows.length === 0 ? <Card><EmptyState icon={Shirt} title="Sin estilos" message="Fotografía tus estilos para reconocerlos al instante en cortes y producción." /></Card> : (
        <div className="grid tiles">
          {rows.map(({ style, orders, plants }) => (
            <Card key={style.id} style={{ padding: 12 }}>
              <Swatch image={style.imageData} name={style.name ?? ""} onClick={style.imageData ? () => setZoom(style) : undefined} />
              <div className="row" style={{ marginTop: 10, alignItems: "flex-start" }}>
                <div className="grow" style={{ minWidth: 0 }}>
                  <div className="bold ellipsis">{style.name}</div>
                  <div className="tiny muted">{orders === 1 ? "1 corte" : `${orders} cortes`}</div>
                </div>
                {writable && (
                  <>
                    <button className="btn ghost icon sm" aria-label="Editar" onClick={() => setEditing(style)}><Pencil /></button>
                    <button className="btn ghost icon sm danger" aria-label="Eliminar" onClick={() => setDeleting(style)}><Trash2 /></button>
                  </>
                )}
              </div>
              <div className="row wrap" style={{ marginTop: 8, gap: 6 }}>
                {plants.length ? plants.map((p) => <Pill key={p.name} icon={Building2} tint="brand" text={`${p.name}: ${p.n}`} />) : <span className="tiny faint">Sin asignar a plantas</span>}
              </div>
            </Card>
          ))}
        </div>
      )}
      {editing && <StyleForm style={editing === "new" ? null : editing} onClose={() => setEditing(null)} />}
      {deleting && <ConfirmModal title={`¿Eliminar ${deleting.name}?`} message="Los cortes que lo usan quedarán sin estilo." onClose={() => setDeleting(null)} onConfirm={() => run(() => services.deleteStyle(deleting), `Estilo «${deleting.name}» eliminado`)} />}
      {zoom && <Modal title={zoom.name ?? "Estilo"} size="wide" onClose={() => setZoom(null)}><div className="lightbox"><img src={imageSrc(zoom.imageData)!} alt="" /></div></Modal>}
    </>
  );
}

function StyleForm({ style, onClose }: { style: StyleDTO | null; onClose: () => void }) {
  const services = useServices();
  const [name, setName] = useState(style?.name ?? "");
  const [image, setImage] = useState<string | null>(style?.imageData ?? null);
  return (
    <FormModal title={style ? "Editar estilo" : "Nuevo estilo"} size="narrow" onClose={onClose} canSave={name.trim().length > 0}
      onSave={async () => { const s = await services.saveStyle(style, name, image); toast(style ? "Estilo actualizado" : `Estilo «${s.name}» creado`); }}>
      <TextField label="Nombre" value={name} onChange={setName} autoFocus placeholder="Nombre o clave (p. ej. Falda plisada SK-210)" />
      <PhotoField label="Foto" value={image} onChange={setImage} />
    </FormModal>
  );
}
