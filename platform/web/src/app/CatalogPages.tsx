import { ArrowLeft, Building2, ChevronLeft, ChevronRight, Mail, MapPin, Pencil, Phone, Plus, Scissors, Shirt, Trash2, Truck, UserPlus, Users, X } from "lucide-react";
import { useMemo, useState } from "react";
import { Link, useNavigate, useParams } from "react-router-dom";
import { ASSIGNMENT_STATE_TINT, assignmentStateTitle, CUT_STATUS_TINT, cutStatusTitle, PROJECT_STATUS_TINT, projectStatusTitle, asProjectStatus } from "../domain/enums";
import { t } from "../i18n";
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
      <PageHead title={t("section.plants")} subtitle={t("plants.subtitle")}>
        {writable && <button className="btn primary" onClick={() => setEditing("new")}><Plus /> {t("plants.new")}</button>}
      </PageHead>
      <div className="grid kpis">
        <KPITile title={t("section.plants")} value={fmtInt(db.plants.length)} icon={Building2} />
        <KPITile title={t("plants.kpiCapacity")} value={fmtMoney(capacity, true)} icon={Building2} tint="info" />
        <KPITile title={t("plants.kpiUsed")} value={fmtMoney(used, true)} icon={Building2} tint="thread" footnote={capacity ? t("plants.ofCapacity", { percent: fmtPercent(used / capacity) }) : undefined} />
      </div>
      <SearchInput value={query} onChange={setQuery} placeholder={t("plants.searchPlaceholder")} />
      {rows.length === 0 ? (
        <Card><EmptyState icon={Building2} title={t("dash.noPlants")} message={t("dash.noPlantsMessage")} /></Card>
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
                    <div className="tiny muted">{t("plants.capacityPerMonth", { amount: fmtMoney(p.maxCapacity ?? 0, true) })}</div>
                  </div>
                </div>
                <CapacityBar used={u} max={p.maxCapacity ?? 0} />
                <div className="row tiny muted" style={{ marginTop: 6 }}>
                  <span className="grow">{t("common.usedAmount", { amount: fmtMoney(u, true) })}</span>
                  <span>{t("common.availableAmount", { amount: fmtMoney(Math.max(0, (p.maxCapacity ?? 0) - u), true) })}</span>
                </div>
                <div className="row tiny faint" style={{ marginTop: 10 }}>
                  <Users size={14} /> {managers.length ? managers.map(fullName).join(", ") : t("plants.noManager")}
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
      title={plant ? t("plants.edit") : t("plants.new")}
      size="narrow"
      onClose={onClose}
      canSave={name.trim().length > 0 && capacity > 0}
      onSave={async () => {
        const saved = await services.savePlant(plant, name, capacity);
        toast(plant ? t("plants.updated") : t("plants.created", { name: saved.name ?? "" }));
      }}
    >
      <TextField label={t("common.name")} value={name} onChange={setName} autoFocus />
      <NumberField label={t("plants.maxCapacity")} value={capacity} onChange={setCapacity} prefix="$"
        hint={plant && capacity > 0 && capacity < usedNow ? <span className="error-text">{t("plants.capacityBelowUsed")}</span> : t("plants.capacityHint")} />
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
  if (!plant) return <EmptyState icon={Building2} title={t("plants.notFound")} action={<Link className="btn" to={SECTION_PATH.plants}>{t("common.back")}</Link>} />;
  const ledger = db.ledger(plant);
  const used = ledger.used(month);
  const assignments = (db.assignmentsByPlant.get(plant.id) ?? []).map((a) => db.assignmentInfo(a))
    .sort((a, b) => new Date(b.assignment.scheduledDate ?? 0).getTime() - new Date(a.assignment.scheduledDate ?? 0).getTime());
  const managers = db.managersByPlant.get(plant.id) ?? [];
  const index = db.plants.findIndex((p) => p.id === plant.id);

  return (
    <>
      <div className="row"><Link to={SECTION_PATH.plants} className="btn ghost sm"><ArrowLeft /> {t("section.plants")}</Link></div>
      <PageHead title={plant.name} subtitle={t("plants.capacityPerMonth", { amount: fmtMoney(plant.maxCapacity ?? 0) })}>
        {writable && (
          <>
            <button className="btn" onClick={() => setEditing(true)}><Pencil /> {t("common.edit")}</button>
            <button className="btn danger" onClick={() => setDeleting(true)}><Trash2 /> {t("common.delete")}</button>
          </>
        )}
      </PageHead>
      <div className="grid split">
        <Card title={t("plants.capacityUsage")} subtitle={fmtMonthYear(month)} action={
          <div className="row">
            <button className="btn ghost icon sm" onClick={() => setMonth(new Date(month.getFullYear(), month.getMonth() - 1, 1))} aria-label={t("common.prevMonth")}><ChevronLeft /></button>
            <button className="btn ghost icon sm" onClick={() => setMonth(new Date(month.getFullYear(), month.getMonth() + 1, 1))} aria-label={t("common.nextMonth")}><ChevronRight /></button>
          </div>
        }>
          <div className="row" style={{ marginBottom: 8 }}>
            <span className="kpi-value">{fmtPercent(ledger.utilization(month))}</span>
            <span className="muted small grow">{t("plants.usedAvailable", { used: fmtMoney(used), available: fmtMoney(Math.max(0, ledger.available(month))) })}</span>
          </div>
          <CapacityBar used={used} max={plant.maxCapacity ?? 0} large />
          <div style={{ marginTop: 18 }}>
            <MonthlyColumns series={[{ name: plant.name ?? t("common.plant"), values: ledger.monthlyUsage(month.getFullYear()), colorIndex: Math.max(0, index) }]} highlightMonth={month.getMonth()} height={180} />
          </div>
        </Card>
        <Card title={t("plants.managers")} subtitle={t("plants.managersSubtitle")}>
          {managers.length === 0 ? <p className="muted small">{t("plants.noManagerAssigned")}</p> : managers.map((u) => (
            <div key={u.id} className="row" style={{ padding: "6px 0" }}>
              <Avatar name={fullName(u)} image={u.avatarData} size={34} />
              <div className="grow"><div className="bold small">{fullName(u)}</div><div className="tiny faint">{u.email}</div></div>
            </div>
          ))}
        </Card>
      </div>
      <Card className="pad-0">
        <div className="card-head" style={{ padding: "18px 20px 0" }}><div><h3>{t("orders.assignments")}</h3><div className="sub">{t("common.total", { count: assignments.length })}</div></div></div>
        {assignments.length === 0 ? <EmptyState icon={Scissors} title={t("plants.noAssignments")} message={t("plants.noAssignmentsMessage")} /> : (
          <div className="list">
            {assignments.map((a) => (
              <button key={a.assignment.id} className="list-row" onClick={() => navigate(paths.assignment(a.assignment.id))}>
                <div className="grow"><div className="bold">{a.title}</div><div className="tiny muted">{a.clientName} · {t("common.garments", { count: a.metrics.quantity })} · {fmtDate(a.assignment.scheduledDate)}</div></div>
                <span className="small num">{fmtMoney(a.metrics.revenue, true)}</span>
                <Pill text={cutStatusTitle(a.cutStatus)} tint={CUT_STATUS_TINT[a.cutStatus]} />
              </button>
            ))}
          </div>
        )}
      </Card>
      {editing && <PlantForm plant={plant} onClose={() => setEditing(false)} />}
      {deleting && (
        <ConfirmModal title={t("plants.deleteTitle", { name: plant.name ?? "" })} message={t("plants.deleteMessage")} onClose={() => setDeleting(false)}
          onConfirm={async () => { if (await run(() => services.deletePlant(plant), t("plants.deleted", { name: plant.name ?? "" }))) navigate(SECTION_PATH.plants); }} />
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
  const title = kind === "client" ? t("section.clients") : t("section.suppliers");
  const Icon = kind === "client" ? Users : Truck;

  return (
    <>
      <PageHead title={title} subtitle={kind === "client" ? t("parties.clientsSubtitle") : t("parties.suppliersSubtitle")}>
        {writable && <button className="btn primary" onClick={() => setEditing(true)}><Plus /> {kind === "client" ? t("parties.newClient") : t("parties.newSupplier")}</button>}
      </PageHead>
      <SearchInput value={query} onChange={setQuery} placeholder={t("parties.searchPlaceholder")} />
      <Card className="pad-0">
        {filtered.length === 0 ? <EmptyState icon={Icon} title={query ? t("common.noResults") : kind === "client" ? t("parties.noClients") : t("parties.noSuppliers")} message={query ? t("parties.tryAnother") : undefined} /> : (
          <div className="list">
            {filtered.map((r) => {
              const contacts = contactsOf(r.id);
              const orders = kind === "client" ? (db.ordersByClient.get(r.id) ?? []).length : null;
              return (
                <button key={r.id} className="list-row" onClick={() => navigate(kind === "client" ? paths.client(r.id) : paths.supplier(r.id))}>
                  <Avatar name={r.name ?? ""} size={42} />
                  <div className="grow" style={{ minWidth: 0 }}>
                    <div className="bold ellipsis">{r.name}</div>
                    <div className="tiny muted ellipsis">{r.address || t("parties.noAddress")}</div>
                  </div>
                  <Pill text={t("parties.contactsCount", { count: contacts.length })} tint="muted" />
                  {orders != null && <Pill text={t("common.cuts", { count: orders })} tint="brand" />}
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

  return (
    <FormModal
      title={party ? (kind === "client" ? t("parties.editClient") : t("parties.editSupplier")) : kind === "client" ? t("parties.newClient") : t("parties.newSupplier")}
      onClose={onClose}
      canSave={name.trim().length > 0}
      onSave={async () => {
        const saved = kind === "client" ? await services.saveClient(party, name, address, drafts) : await services.saveSupplier(party, name, address, drafts);
        toast(party ? t(kind === "client" ? "parties.clientUpdated" : "parties.supplierUpdated") : t(kind === "client" ? "parties.clientCreated" : "parties.supplierCreated", { name: saved.name ?? "" }));
        onSaved?.(saved);
      }}
    >
      <div className="form-grid">
        <TextField label={t("common.name")} value={name} onChange={setName} autoFocus />
        <TextField label={t("parties.address")} value={address} onChange={setAddress} />
      </div>
      <div className="form-section">
        <div className="row between"><h4 style={{ margin: 0, fontSize: 13, textTransform: "uppercase", letterSpacing: "0.06em", color: "var(--text-3)" }}>{t("parties.contacts")}</h4>
          <button type="button" className="btn sm" onClick={() => setDrafts([...drafts, newContactDraft()])}><UserPlus /> {t("parties.addContact")}</button></div>
        {drafts.length === 0 && <p className="small muted" style={{ margin: 0 }}>{t("parties.noContactsHint")}</p>}
        {drafts.map((d, i) => (
          <div key={d.id} className="card flat" style={{ padding: 14 }}>
            <div className="row" style={{ alignItems: "flex-start" }}>
              <div className="form-grid grow">
                <TextField label={t("common.name")} value={d.name} onChange={(v) => update(i, { name: v })} />
                <TextField label={t("parties.contactRole")} value={d.role} onChange={(v) => update(i, { role: v })} />
                <TextField label={t("parties.contactEmail")} type="email" value={d.email} onChange={(v) => update(i, { email: v })} hint={d.email && !isPlausibleEmail(d.email.trim()) ? <span className="error-text">{t("parties.invalidEmail")}</span> : undefined} />
                <TextField label={t("common.phone")} type="tel" value={d.phone} onChange={(v) => update(i, { phone: v })} />
              </div>
              <button type="button" className="btn ghost icon sm" aria-label={t("parties.removeContact")} onClick={() => setDrafts(drafts.filter((_, j) => j !== i))}><X /></button>
            </div>
          </div>
        ))}
      </div>
    </FormModal>
  );
}

function ContactCards({ contacts }: { contacts: ContactDTO[] }) {
  if (!contacts.length) return <p className="small muted" style={{ margin: 0 }}>{t("parties.noContacts")}</p>;
  const emails = contacts.map((c) => c.email).filter((e): e is string => !!e && isPlausibleEmail(e));
  return (
    <div className="col" style={{ gap: 10 }}>
      {emails.length > 1 && <a className="btn sm" href={`mailto:${[...new Set(emails)].join(",")}`}><Mail /> {t("parties.emailAll")}</a>}
      {contacts.map((c) => (
        <div key={c.id} className="row" style={{ alignItems: "flex-start" }}>
          <Avatar name={c.name || c.email || "?"} size={36} />
          <div className="grow" style={{ minWidth: 0 }}>
            <div className="bold small">{c.name || t("parties.noName")}</div>
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
  if (!party) return <EmptyState icon={Users} title={t("parties.notFound")} action={<Link className="btn" to={back}>{t("common.back")}</Link>} />;
  const contacts = (kind === "client" ? db.contactsByClient : db.contactsBySupplier).get(party.id) ?? [];
  const orders = kind === "client" ? (db.ordersByClient.get(party.id) ?? []).map((o) => db.orderInfo(o)) : [];
  const projects = kind === "client" ? (db.projectsByClient.get(party.id) ?? []) : [];

  return (
    <>
      <div className="row"><Link to={back} className="btn ghost sm"><ArrowLeft /> {kind === "client" ? t("section.clients") : t("section.suppliers")}</Link></div>
      <PageHead title={party.name} subtitle={party.address ? <span className="row" style={{ gap: 6 }}><MapPin size={15} />{party.address}</span> : undefined}>
        {writable && (
          <>
            <button className="btn" onClick={() => setEditing(true)}><Pencil /> {t("common.edit")}</button>
            <button className="btn danger" onClick={() => setDeleting(true)}><Trash2 /> {t("common.delete")}</button>
          </>
        )}
      </PageHead>
      {kind === "client" && (
        <div className="grid kpis">
          <KPITile title={t("parties.kpiCuts")} value={fmtInt(orders.length)} icon={Scissors} />
          <KPITile title={t("parties.kpiGarments")} value={fmtInt(orders.reduce((n, o) => n + (o.order.quantity ?? 0), 0))} icon={Shirt} tint="info" />
          <KPITile title={t("common.totalRevenue")} value={fmtMoney(orders.reduce((n, o) => n + o.revenue, 0), true)} icon={Scissors} tint="brand" />
        </div>
      )}
      <div className="grid split">
        {kind === "client" ? (
          <Card className="pad-0">
            <div className="card-head" style={{ padding: "18px 20px 0" }}><div><h3>{t("parties.kpiCuts")}</h3></div></div>
            {orders.length === 0 ? <EmptyState icon={Scissors} title={t("parties.noCuts")} /> : (
              <div className="list">
                {orders.map((o) => (
                  <button key={o.order.id} className="list-row" onClick={() => navigate(paths.order(o.order.id))}>
                    <div className="grow"><div className="bold">{o.order.code}</div><div className="tiny muted">{t("parties.orderLine", { style: o.styleName, garments: t("common.garments", { count: o.order.quantity ?? 0 }), date: fmtDate(o.order.clientDate) })}</div></div>
                    <Pill text={assignmentStateTitle(o.state)} tint={ASSIGNMENT_STATE_TINT[o.state]} />
                  </button>
                ))}
              </div>
            )}
          </Card>
        ) : (
          <Card title={t("parties.contacts")}><ContactCards contacts={contacts} /></Card>
        )}
        <div className="col" style={{ gap: 16 }}>
          {kind === "client" && <Card title={t("parties.contacts")}><ContactCards contacts={contacts} /></Card>}
          {kind === "client" && projects.length > 0 && (
            <Card title={t("section.projects")}>
              {projects.map((p) => {
                const st = asProjectStatus(p.statusRaw);
                return (
                  <div key={p.id} className="row" style={{ padding: "6px 0" }}>
                    <div className="grow small"><div className="bold">{t("parties.projectLine", { garments: t("common.garments", { count: p.quantity ?? 0 }), price: fmtMoney(p.price ?? 0) })}</div><div className="tiny faint">{p.fabric ?? "—"}</div></div>
                    <Pill text={projectStatusTitle(st)} tint={PROJECT_STATUS_TINT[st]} />
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
          title={t("parties.deleteTitle", { name: party.name ?? "" })}
          message={kind === "client" ? t("parties.deleteClientMessage") : t("parties.deleteSupplierMessage")}
          onClose={() => setDeleting(false)}
          onConfirm={async () => {
            const ok = await run(() => (kind === "client" ? services.deleteClient(party) : services.deleteSupplier(party)), t("parties.deleted", { name: party.name ?? "" }));
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
      return { style: s, orders: orders.length, plants: [...plants.entries()].map(([id, n]) => ({ name: db.plantById.get(id)?.name ?? t("common.plant"), n })) };
    }).filter((r) => matches(query, r.style.name, ...r.plants.map((p) => p.name)));
    if (sort === "orders") list.sort((a, b) => b.orders - a.orders);
    if (sort === "recent") list.sort((a, b) => new Date(b.style.createdAt ?? 0).getTime() - new Date(a.style.createdAt ?? 0).getTime());
    return list;
  }, [db, query, sort]);

  return (
    <>
      <PageHead title={t("section.styles")} subtitle={t("styles.subtitle")}>
        {writable && <button className="btn primary" onClick={() => setEditing("new")}><Plus /> {t("styles.new")}</button>}
      </PageHead>
      <div className="row wrap between">
        <SearchInput value={query} onChange={setQuery} placeholder={t("styles.searchPlaceholder")} />
        <Seg value={sort} onChange={setSort} options={[{ value: "name", label: t("styles.sortName") }, { value: "recent", label: t("styles.sortRecent") }, { value: "orders", label: t("styles.sortOrders") }]} />
      </div>
      {rows.length === 0 ? <Card><EmptyState icon={Shirt} title={t("styles.empty")} message={t("styles.subtitle")} /></Card> : (
        <div className="grid tiles">
          {rows.map(({ style, orders, plants }) => (
            <Card key={style.id} style={{ padding: 12 }}>
              <Swatch image={style.imageData} name={style.name ?? ""} onClick={style.imageData ? () => setZoom(style) : undefined} />
              <div className="row" style={{ marginTop: 10, alignItems: "flex-start" }}>
                <div className="grow" style={{ minWidth: 0 }}>
                  <div className="bold ellipsis">{style.name}</div>
                  <div className="tiny muted">{t("common.cuts", { count: orders })}</div>
                </div>
                {writable && (
                  <>
                    <button className="btn ghost icon sm" aria-label={t("common.edit")} onClick={() => setEditing(style)}><Pencil /></button>
                    <button className="btn ghost icon sm danger" aria-label={t("common.delete")} onClick={() => setDeleting(style)}><Trash2 /></button>
                  </>
                )}
              </div>
              <div className="row wrap" style={{ marginTop: 8, gap: 6 }}>
                {plants.length ? plants.map((p) => <Pill key={p.name} icon={Building2} tint="brand" text={`${p.name}: ${p.n}`} />) : <span className="tiny faint">{t("styles.notInPlants")}</span>}
              </div>
            </Card>
          ))}
        </div>
      )}
      {editing && <StyleForm style={editing === "new" ? null : editing} onClose={() => setEditing(null)} />}
      {deleting && <ConfirmModal title={t("plants.deleteTitle", { name: deleting.name ?? "" })} message={t("styles.deleteMessage")} onClose={() => setDeleting(null)} onConfirm={() => run(() => services.deleteStyle(deleting), t("styles.deleted", { name: deleting.name ?? "" }))} />}
      {zoom && <Modal title={zoom.name ?? t("common.style")} size="wide" onClose={() => setZoom(null)}><div className="lightbox"><img src={imageSrc(zoom.imageData)!} alt="" /></div></Modal>}
    </>
  );
}

function StyleForm({ style, onClose }: { style: StyleDTO | null; onClose: () => void }) {
  const services = useServices();
  const [name, setName] = useState(style?.name ?? "");
  const [image, setImage] = useState<string | null>(style?.imageData ?? null);
  return (
    <FormModal title={style ? t("styles.edit") : t("styles.new")} size="narrow" onClose={onClose} canSave={name.trim().length > 0}
      onSave={async () => { const s = await services.saveStyle(style, name, image); toast(style ? t("styles.updated") : t("styles.created", { name: s.name ?? "" })); }}>
      <TextField label={t("common.name")} value={name} onChange={setName} autoFocus placeholder={t("styles.namePlaceholder")} />
      <PhotoField label={t("styles.photo")} value={image} onChange={setImage} />
    </FormModal>
  );
}
