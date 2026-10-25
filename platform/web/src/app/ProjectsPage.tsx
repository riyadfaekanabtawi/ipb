import { CalendarDays, FolderKanban, Pencil, Percent, Plus, Trash2, Banknote } from "lucide-react";
import { useState } from "react";
import { PROJECT_STATUSES, PROJECT_STATUS_TINT, PROJECT_STATUS_TITLE, asProjectStatus, type ProjectStatus } from "../domain/enums";
import type { ProjectDTO } from "../domain/types";
import { useDB } from "../data/session";
import { dateInputFromIso, fmtDate, fmtInt, fmtMoney, fmtNumber, fmtPercent, isoFromDateInput } from "../lib/format";
import { toast } from "../lib/toast";
import { Card, ConfirmModal, EmptyState, Field, FormModal, KPITile, NumberField, PageHead, PhotoField, Pill, SearchInput, Seg, SelectField, Swatch, TextField } from "../ui/kit";
import { matches, useAction, useServices, useWritable } from "./common";

export function ProjectsPage() {
  const db = useDB();
  const services = useServices();
  const writable = useWritable();
  const { run } = useAction();
  const [query, setQuery] = useState("");
  const [status, setStatus] = useState<ProjectStatus | "all">("all");
  const [view, setView] = useState<"grid" | "board">("grid");
  const [editing, setEditing] = useState<ProjectDTO | null | "new">(null);
  const [deleting, setDeleting] = useState<ProjectDTO | null>(null);
  const clientOf = (p: ProjectDTO) => db.clientById.get(p.clientID ?? "")?.name ?? p.clientName ?? "Sin cliente";
  const matching = db.projects.filter((p) => matches(query, clientOf(p), p.fabric, p.notes));
  const rows = matching.filter((p) => status === "all" || asProjectStatus(p.statusRaw) === status);
  const decided = db.projects.filter((p) => asProjectStatus(p.statusRaw) !== "pendiente");
  const accepted = decided.filter((p) => asProjectStatus(p.statusRaw) === "aceptado");
  const total = (p: ProjectDTO) => (p.quantity ?? 0) * (p.price ?? 0);

  const card = (p: ProjectDTO) => {
    const st = asProjectStatus(p.statusRaw);
    return (
      <Card key={p.id} style={{ padding: 14 }}>
        {p.photoData && <div style={{ marginBottom: 10 }}><Swatch image={p.photoData} name={clientOf(p)} /></div>}
        <div className="row" style={{ alignItems: "flex-start" }}>
          <div className="grow" style={{ minWidth: 0 }}>
            <div className="bold ellipsis">{clientOf(p)}</div>
            <div className="tiny muted">{fmtInt(p.quantity ?? 0)} prendas × {fmtMoney(p.price ?? 0)}</div>
          </div>
          <Pill text={PROJECT_STATUS_TITLE[st]} tint={PROJECT_STATUS_TINT[st]} />
        </div>
        <div className="row wrap tiny muted" style={{ marginTop: 8, gap: 12 }}>
          <span className="bold" style={{ color: "var(--text)" }}>{fmtMoney(total(p))}</span>
          {p.fabric && <span>{p.fabric}</span>}
          {(p.minutes ?? 0) > 0 && <span>{fmtNumber(p.minutes)} min</span>}
          {p.deliveryDate && <span className="row" style={{ gap: 4 }}><CalendarDays size={13} />{fmtDate(p.deliveryDate)}</span>}
        </div>
        {p.notes && <p className="tiny faint" style={{ margin: "8px 0 0", whiteSpace: "pre-wrap" }}>{p.notes}</p>}
        {writable && (
          <div className="row" style={{ marginTop: 10, gap: 4 }}>
            <select className="input grow" style={{ padding: "5px 8px", fontSize: 12 }} value={st} aria-label="Cambiar estado"
              onChange={(e) => run(() => services.setProjectStatus(p, e.target.value as ProjectStatus), `Proyecto de ${clientOf(p)}: ${PROJECT_STATUS_TITLE[e.target.value as ProjectStatus].toLowerCase()}`)}>
              {PROJECT_STATUSES.map((s) => <option key={s} value={s}>{PROJECT_STATUS_TITLE[s]}</option>)}
            </select>
            <button className="btn ghost icon sm" aria-label="Editar" onClick={() => setEditing(p)}><Pencil /></button>
            <button className="btn ghost icon sm danger" aria-label="Eliminar" onClick={() => setDeleting(p)}><Trash2 /></button>
          </div>
        )}
      </Card>
    );
  };

  return (
    <>
      <PageHead title="Proyectos" subtitle="Registra cotizaciones y prospectos para darles seguimiento hasta que se acepten.">
        {writable && <button className="btn primary" onClick={() => setEditing("new")}><Plus /> Nuevo proyecto</button>}
      </PageHead>
      <div className="grid kpis">
        <KPITile title="Proyectos" value={fmtInt(db.projects.length)} icon={FolderKanban} />
        <KPITile title="Valor cotizado" value={fmtMoney(db.projects.reduce((n, p) => n + total(p), 0), true)} icon={Banknote} tint="brand" />
        <KPITile title="Tasa de aceptación" value={decided.length ? fmtPercent(accepted.length / decided.length) : "—"} icon={Percent} tint="success" footnote="De los proyectos ya decididos" />
      </div>
      <div className="row wrap between">
        <Seg<ProjectStatus | "all"> value={status} onChange={setStatus} options={[{ value: "all", label: `Todos (${matching.length})` }, ...PROJECT_STATUSES.map((s) => ({ value: s, label: `${PROJECT_STATUS_TITLE[s]} (${matching.filter((p) => asProjectStatus(p.statusRaw) === s).length})` }))]} />
        <div className="row wrap">
          <SearchInput value={query} onChange={setQuery} placeholder="Buscar cliente, tela o notas" />
          <Seg value={view} onChange={setView} options={[{ value: "grid", label: "Cuadrícula" }, { value: "board", label: "Tablero" }]} />
        </div>
      </div>
      {db.projects.length === 0 ? (
        <Card><EmptyState icon={FolderKanban} title="Sin proyectos" message="Registra cotizaciones y prospectos para darles seguimiento hasta que se acepten." /></Card>
      ) : view === "grid" ? (
        rows.length ? <div className="grid three">{rows.map(card)}</div> : <Card><EmptyState icon={FolderKanban} title="Nada por aquí" message="No hay proyectos con este estado." /></Card>
      ) : (
        <div className="board">
          {PROJECT_STATUSES.map((s) => {
            const items = matching.filter((p) => asProjectStatus(p.statusRaw) === s);
            return (
              <div key={s} className="lane">
                <div className="lane-head"><Pill text={PROJECT_STATUS_TITLE[s]} tint={PROJECT_STATUS_TINT[s]} /><span className="count">{items.length === 1 ? "1 proyecto" : `${items.length} proyectos`}</span></div>
                {items.map(card)}
              </div>
            );
          })}
        </div>
      )}
      {editing && <ProjectForm project={editing === "new" ? null : editing} onClose={() => setEditing(null)} />}
      {deleting && <ConfirmModal title="¿Eliminar este proyecto?" onClose={() => setDeleting(null)} onConfirm={() => run(() => services.deleteProject(deleting), "Proyecto eliminado")} />}
    </>
  );
}

function ProjectForm({ project, onClose }: { project: ProjectDTO | null; onClose: () => void }) {
  const db = useDB();
  const services = useServices();
  const OTHER = "__other";
  const [clientID, setClientID] = useState(project ? (project.clientID ?? OTHER) : (db.clients[0]?.id ?? OTHER));
  const [clientName, setClientName] = useState(project?.clientID ? "" : (project?.clientName ?? ""));
  const [quantity, setQuantity] = useState(project?.quantity ?? 0);
  const [price, setPrice] = useState(project?.price ?? 0);
  const [minutes, setMinutes] = useState(project?.minutes ?? 0);
  const [fabric, setFabric] = useState(project?.fabric ?? "");
  const [status, setStatus] = useState<ProjectStatus>(asProjectStatus(project?.statusRaw));
  const [delivery, setDelivery] = useState(dateInputFromIso(project?.deliveryDate));
  const [notes, setNotes] = useState(project?.notes ?? "");
  const [photo, setPhoto] = useState<string | null>(project?.photoData ?? null);
  const hasClient = clientID !== OTHER || clientName.trim().length > 0;

  return (
    <FormModal title={project ? "Editar proyecto" : "Nuevo proyecto"} onClose={onClose} canSave={hasClient}
      onSave={async () => {
        await services.saveProject(project, {
          clientID: clientID === OTHER ? null : clientID, clientName, quantity, price, minutes, fabric, status,
          deliveryDate: isoFromDateInput(delivery), notes, photoData: photo,
        });
        toast(project ? "Proyecto actualizado" : "Proyecto creado");
      }}>
      <div className="form-section">
        <h4>Cliente</h4>
        <div className="form-grid">
          <SelectField label="Cliente" value={clientID} onChange={(v) => setClientID(v || OTHER)} options={[...db.clients.map((c) => ({ value: c.id, label: c.name ?? "Cliente" })), { value: OTHER, label: "Otro (escribir nombre)" }]} />
          {clientID === OTHER && <TextField label="Nombre del cliente o prospecto" value={clientName} onChange={setClientName} />}
        </div>
      </div>
      <div className="form-section">
        <h4>Cotización</h4>
        <div className="form-grid">
          <NumberField label="Cantidad (prendas)" value={quantity} onChange={setQuantity} integer />
          <NumberField label="Precio por prenda" value={price} onChange={setPrice} prefix="$" />
          <NumberField label="Minutaje (min por prenda)" value={minutes} onChange={setMinutes} />
          <Field label="Total"><div className="input num" style={{ background: "transparent" }}>{fmtMoney((quantity || 0) * (price || 0))}</div></Field>
        </div>
        {minutes > 0 && quantity > 0 && <span className="tiny muted">Carga estimada: {fmtNumber((minutes * quantity) / 60)} horas de costura.</span>}
      </div>
      <div className="form-section">
        <h4>Producción</h4>
        <div className="form-grid">
          <TextField label="Tela" value={fabric} onChange={setFabric} />
          <SelectField label="Estado" value={status} onChange={(v) => v && setStatus(v)} options={PROJECT_STATUSES.map((s) => ({ value: s, label: PROJECT_STATUS_TITLE[s] }))} />
          <Field label="Fecha de entrega"><input className="input" type="date" value={delivery} onChange={(e) => setDelivery(e.target.value)} /></Field>
        </div>
      </div>
      <Field label="Notas"><textarea className="input" value={notes} onChange={(e) => setNotes(e.target.value)} /></Field>
      <PhotoField label="Foto o muestra" value={photo} onChange={setPhoto} />
    </FormModal>
  );
}
