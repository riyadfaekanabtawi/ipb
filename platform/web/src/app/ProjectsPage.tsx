import { CalendarDays, FolderKanban, Pencil, Percent, Plus, Trash2, Banknote } from "lucide-react";
import { useState } from "react";
import { PROJECT_STATUSES, PROJECT_STATUS_TINT, projectStatusTitle, asProjectStatus, type ProjectStatus } from "../domain/enums";
import { t } from "../i18n";
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
  const clientOf = (p: ProjectDTO) => db.clientById.get(p.clientID ?? "")?.name ?? p.clientName ?? t("common.noClient");
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
            <div className="tiny muted">{t("parties.projectLine", { garments: t("common.garments", { count: p.quantity ?? 0 }), price: fmtMoney(p.price ?? 0) })}</div>
          </div>
          <Pill text={projectStatusTitle(st)} tint={PROJECT_STATUS_TINT[st]} />
        </div>
        <div className="row wrap tiny muted" style={{ marginTop: 8, gap: 12 }}>
          <span className="bold" style={{ color: "var(--text)" }}>{fmtMoney(total(p))}</span>
          {p.fabric && <span>{p.fabric}</span>}
          {(p.minutes ?? 0) > 0 && <span>{t("projects.minutesShort", { count: fmtNumber(p.minutes) })}</span>}
          {p.deliveryDate && <span className="row" style={{ gap: 4 }}><CalendarDays size={13} />{fmtDate(p.deliveryDate)}</span>}
        </div>
        {p.notes && <p className="tiny faint" style={{ margin: "8px 0 0", whiteSpace: "pre-wrap" }}>{p.notes}</p>}
        {writable && (
          <div className="row" style={{ marginTop: 10, gap: 4 }}>
            <select className="input grow" style={{ padding: "5px 8px", fontSize: 12 }} value={st} aria-label={t("projects.changeStatus")}
              onChange={(e) => run(() => services.setProjectStatus(p, e.target.value as ProjectStatus), t("projects.statusChanged", { client: clientOf(p), status: projectStatusTitle(e.target.value as ProjectStatus).toLocaleLowerCase() }))}>
              {PROJECT_STATUSES.map((s) => <option key={s} value={s}>{projectStatusTitle(s)}</option>)}
            </select>
            <button className="btn ghost icon sm" aria-label={t("common.edit")} onClick={() => setEditing(p)}><Pencil /></button>
            <button className="btn ghost icon sm danger" aria-label={t("common.delete")} onClick={() => setDeleting(p)}><Trash2 /></button>
          </div>
        )}
      </Card>
    );
  };

  return (
    <>
      <PageHead title={t("section.projects")} subtitle={t("projects.subtitle")}>
        {writable && <button className="btn primary" onClick={() => setEditing("new")}><Plus /> {t("projects.new")}</button>}
      </PageHead>
      <div className="grid kpis">
        <KPITile title={t("section.projects")} value={fmtInt(db.projects.length)} icon={FolderKanban} />
        <KPITile title={t("projects.kpiQuoted")} value={fmtMoney(db.projects.reduce((n, p) => n + total(p), 0), true)} icon={Banknote} tint="brand" />
        <KPITile title={t("projects.kpiAcceptance")} value={decided.length ? fmtPercent(accepted.length / decided.length) : "—"} icon={Percent} tint="success" footnote={t("projects.kpiAcceptanceFoot")} />
      </div>
      <div className="row wrap between">
        <Seg<ProjectStatus | "all"> value={status} onChange={setStatus} options={[{ value: "all", label: t("projects.filterAll", { count: matching.length }) }, ...PROJECT_STATUSES.map((s) => ({ value: s, label: t("projects.filterStatus", { status: projectStatusTitle(s), count: matching.filter((p) => asProjectStatus(p.statusRaw) === s).length }) }))]} />
        <div className="row wrap">
          <SearchInput value={query} onChange={setQuery} placeholder={t("projects.searchPlaceholder")} />
          <Seg value={view} onChange={setView} options={[{ value: "grid", label: t("projects.viewGrid") }, { value: "board", label: t("projects.viewBoard") }]} />
        </div>
      </div>
      {db.projects.length === 0 ? (
        <Card><EmptyState icon={FolderKanban} title={t("projects.empty")} message={t("projects.subtitle")} /></Card>
      ) : view === "grid" ? (
        rows.length ? <div className="grid three">{rows.map(card)}</div> : <Card><EmptyState icon={FolderKanban} title={t("projects.nothingHere")} message={t("projects.noneWithStatus")} /></Card>
      ) : (
        <div className="board">
          {PROJECT_STATUSES.map((s) => {
            const items = matching.filter((p) => asProjectStatus(p.statusRaw) === s);
            return (
              <div key={s} className="lane">
                <div className="lane-head"><Pill text={projectStatusTitle(s)} tint={PROJECT_STATUS_TINT[s]} /><span className="count">{t("projects.count", { count: items.length })}</span></div>
                {items.map(card)}
              </div>
            );
          })}
        </div>
      )}
      {editing && <ProjectForm project={editing === "new" ? null : editing} onClose={() => setEditing(null)} />}
      {deleting && <ConfirmModal title={t("projects.deleteTitle")} onClose={() => setDeleting(null)} onConfirm={() => run(() => services.deleteProject(deleting), t("projects.deleted"))} />}
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
    <FormModal title={project ? t("projects.edit") : t("projects.new")} onClose={onClose} canSave={hasClient}
      onSave={async () => {
        await services.saveProject(project, {
          clientID: clientID === OTHER ? null : clientID, clientName, quantity, price, minutes, fabric, status,
          deliveryDate: isoFromDateInput(delivery), notes, photoData: photo,
        });
        toast(project ? t("projects.updated") : t("projects.created"));
      }}>
      <div className="form-section">
        <h4>{t("common.client")}</h4>
        <div className="form-grid">
          <SelectField label={t("common.client")} value={clientID} onChange={(v) => setClientID(v || OTHER)} options={[...db.clients.map((c) => ({ value: c.id, label: c.name ?? t("common.client") })), { value: OTHER, label: t("projects.otherClient") }]} />
          {clientID === OTHER && <TextField label={t("projects.clientName")} value={clientName} onChange={setClientName} />}
        </div>
      </div>
      <div className="form-section">
        <h4>{t("projects.quote")}</h4>
        <div className="form-grid">
          <NumberField label={t("projects.quantity")} value={quantity} onChange={setQuantity} integer />
          <NumberField label={t("projects.pricePerGarment")} value={price} onChange={setPrice} prefix="$" />
          <NumberField label={t("projects.minutes")} value={minutes} onChange={setMinutes} />
          <Field label={t("projects.total")}><div className="input num" style={{ background: "transparent" }}>{fmtMoney((quantity || 0) * (price || 0))}</div></Field>
        </div>
        {minutes > 0 && quantity > 0 && <span className="tiny muted">{t("projects.estimatedLoad", { hours: fmtNumber((minutes * quantity) / 60) })}</span>}
      </div>
      <div className="form-section">
        <h4>{t("projects.production")}</h4>
        <div className="form-grid">
          <TextField label={t("projects.fabric")} value={fabric} onChange={setFabric} />
          <SelectField label={t("common.status")} value={status} onChange={(v) => v && setStatus(v)} options={PROJECT_STATUSES.map((s) => ({ value: s, label: projectStatusTitle(s) }))} />
          <Field label={t("projects.deliveryDate")}><input className="input" type="date" value={delivery} onChange={(e) => setDelivery(e.target.value)} /></Field>
        </div>
      </div>
      <Field label={t("common.notes")}><textarea className="input" value={notes} onChange={(e) => setNotes(e.target.value)} /></Field>
      <PhotoField label={t("projects.photo")} value={photo} onChange={setPhoto} />
    </FormModal>
  );
}
