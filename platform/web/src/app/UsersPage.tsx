import { KeyRound, Pencil, Plus, Power, Trash2, UserCog } from "lucide-react";
import { useState } from "react";
import { roleTitle, ROLES, asRole } from "../domain/enums";
import { t } from "../i18n";
import { MIN_PASSWORD } from "../domain/rules";
import type { UserDTO } from "../domain/types";
import type { UserDraft } from "../data/services";
import { useDB, useSession } from "../data/session";
import { fullName } from "../lib/format";
import { toast } from "../lib/toast";
import { Avatar, Card, ConfirmModal, EmptyState, Field, FormModal, PageHead, PhotoField, Pill, SearchInput, Seg, SelectField, TextField } from "../ui/kit";
import { PasswordInput } from "./AuthPages";
import { matches, useAction, useServices, useWritable } from "./common";

type Filter = "all" | "active" | "inactive";

export function UsersPage() {
  const db = useDB();
  const { user: me, tenant } = useSession();
  const services = useServices();
  const writable = useWritable();
  const { run } = useAction();
  const [query, setQuery] = useState("");
  const [filter, setFilter] = useState<Filter>("all");
  const [editing, setEditing] = useState<UserDTO | null | "new">(null);
  const [resetting, setResetting] = useState<UserDTO | null>(null);
  const [deleting, setDeleting] = useState<UserDTO | null>(null);
  const count = (f: Filter) => db.users.filter((u) => f === "all" || (f === "active") === (u.isActive !== false)).length;
  const rows = db.users
    .filter((u) => filter === "all" || (filter === "active") === (u.isActive !== false))
    .filter((u) => matches(query, fullName(u), u.email, roleTitle(asRole(u.roleRaw))));
  const active = count("active");

  return (
    <>
      <PageHead title={t("section.users")} subtitle={tenant.maxUsers ? t("users.subtitleLimit", { active, max: tenant.maxUsers }) : t("users.subtitle")}>
        {writable && <button className="btn primary" onClick={() => setEditing("new")} disabled={!!tenant.maxUsers && active >= tenant.maxUsers}><Plus /> {t("users.new")}</button>}
      </PageHead>
      <div className="row wrap between">
        <Seg value={filter} onChange={setFilter} options={[{ value: "all", label: t("users.filterAll", { count: count("all") }) }, { value: "active", label: t("users.filterActive", { count: count("active") }) }, { value: "inactive", label: t("users.filterInactive", { count: count("inactive") }) }]} />
        <SearchInput value={query} onChange={setQuery} placeholder={t("users.searchPlaceholder")} />
      </div>
      <Card className="pad-0">
        {rows.length === 0 ? <EmptyState icon={UserCog} title={filter === "active" ? t("users.emptyActive") : filter === "inactive" ? t("users.emptyInactive") : t("users.empty")} /> : (
          <div className="list">
            {rows.map((u) => {
              const role = asRole(u.roleRaw);
              const plant = db.plantById.get(u.plantID ?? "");
              const isMe = u.id === me.id;
              return (
                <div key={u.id} className="list-row static" style={{ opacity: u.isActive === false ? 0.6 : 1 }}>
                  <Avatar name={fullName(u)} image={u.avatarData} size={42} />
                  <div className="grow" style={{ minWidth: 0 }}>
                    <div className="bold ellipsis">{fullName(u)} {isMe && <span className="tiny faint">{t("users.you")}</span>}</div>
                    <div className="tiny muted ellipsis">{u.email}{u.phone ? ` · ${u.phone}` : ""}</div>
                  </div>
                  <Pill text={roleTitle(role)} tint={role === "Administrador" ? "thread" : "brand"} />
                  {role === "Gerente de Planta" && <Pill text={plant?.name ?? t("common.noPlantAssigned")} tint={plant ? "muted" : "danger"} />}
                  <Pill text={u.isActive === false ? t("users.inactive") : t("users.active")} tint={u.isActive === false ? "muted" : "success"} />
                  {writable && (
                    <div className="row" style={{ gap: 2 }}>
                      <button className="btn ghost icon sm" title={t("common.edit")} aria-label={t("common.edit")} onClick={() => setEditing(u)}><Pencil /></button>
                      <button className="btn ghost icon sm" title={t("users.resetPassword")} aria-label={t("users.resetPassword")} onClick={() => setResetting(u)}><KeyRound /></button>
                      {!isMe && (
                        <>
                          <button className="btn ghost icon sm" title={u.isActive === false ? t("users.activate") : t("users.deactivate")} aria-label={u.isActive === false ? t("users.activate") : t("users.deactivate")}
                            onClick={() => run(() => services.setActive(u, u.isActive === false), u.isActive === false ? t("users.reactivated", { name: fullName(u) }) : t("users.deactivated", { name: fullName(u) }))}><Power /></button>
                          <button className="btn ghost icon sm danger" title={t("common.delete")} aria-label={t("common.delete")} onClick={() => setDeleting(u)}><Trash2 /></button>
                        </>
                      )}
                    </div>
                  )}
                </div>
              );
            })}
          </div>
        )}
      </Card>
      {editing && <UserForm user={editing === "new" ? null : editing} onClose={() => setEditing(null)} />}
      {resetting && <ResetPasswordForm user={resetting} onClose={() => setResetting(null)} />}
      {deleting && <ConfirmModal title={t("users.deleteTitle", { name: fullName(deleting) })} message={t("users.deleteMessage")} onClose={() => setDeleting(null)}
        onConfirm={() => run(() => services.deleteUser(deleting), t("users.deleted", { name: fullName(deleting) }))} />}
    </>
  );
}

function UserForm({ user, onClose }: { user: UserDTO | null; onClose: () => void }) {
  const db = useDB();
  const { user: me } = useSession();
  const services = useServices();
  const [draft, setDraft] = useState<UserDraft>({
    firstName: user?.firstName ?? "", lastName: user?.lastName ?? "", email: user?.email ?? "", phone: user?.phone ?? "",
    role: user ? asRole(user.roleRaw) : "Gerente de Planta", plantID: user?.plantID ?? null, avatarData: user?.avatarData ?? null,
  });
  const [password, setPassword] = useState("");
  const [confirm, setConfirm] = useState("");
  const set = (patch: Partial<UserDraft>) => setDraft({ ...draft, ...patch });
  const isMe = user?.id === me.id;
  const passwordOk = !!user || (password.length >= MIN_PASSWORD && password === confirm);
  const canSave = draft.firstName.trim().length > 0 && draft.email.trim().length > 0 && passwordOk && (draft.role !== "Gerente de Planta" || !!draft.plantID);

  return (
    <FormModal
      title={user ? t("users.edit") : t("users.new")}
      onClose={onClose}
      canSave={canSave}
      saveLabel={user ? t("common.save") : t("common.create")}
      onSave={async () => {
        if (user) {
          await services.updateUser(user, draft);
          toast(t("users.updated"));
        } else {
          const created = await services.createUser(draft, password);
          toast(t("users.created", { name: fullName(created) }));
        }
      }}
    >
      <div className="form-section">
        <h4>{t("users.profile")}</h4>
        <div className="form-grid">
          <TextField label={t("users.firstName")} value={draft.firstName} onChange={(v) => set({ firstName: v })} autoFocus />
          <TextField label={t("users.lastName")} value={draft.lastName} onChange={(v) => set({ lastName: v })} />
        </div>
        <PhotoField label={t("users.avatar")} value={draft.avatarData} onChange={(v) => set({ avatarData: v })} maxSide={384} />
      </div>
      <div className="form-section">
        <h4>{t("users.contact")}</h4>
        <div className="form-grid">
          <TextField label={t("common.email")} type="email" value={draft.email} onChange={(v) => set({ email: v })} autoComplete="off" />
          <TextField label={t("common.phone")} type="tel" value={draft.phone} onChange={(v) => set({ phone: v })} />
        </div>
      </div>
      <div className="form-section">
        <h4>{t("users.role")}</h4>
        <div className="form-grid">
          <SelectField label={t("users.role")} value={draft.role} onChange={(v) => v && set({ role: v })} options={ROLES.map((r) => ({ value: r, label: roleTitle(r) }))}
            hint={isMe ? t("users.ownRoleHint") : undefined} />
          {draft.role === "Gerente de Planta" && (
            <SelectField label={t("common.plant")} value={draft.plantID ?? ""} onChange={(v) => set({ plantID: v || null })} placeholder={t("users.pickPlant")} options={db.plants.map((p) => ({ value: p.id, label: p.name ?? t("common.plant") }))}
              hint={t("users.plantHint")} />
          )}
        </div>
      </div>
      {!user && (
        <div className="form-section">
          <h4>{t("users.password")}</h4>
          <div className="form-grid">
            <Field label={t("users.password")} hint={t("users.passwordHint", { count: MIN_PASSWORD })}><PasswordInput value={password} onChange={setPassword} autoComplete="new-password" /></Field>
            <Field label={t("auth.confirmPassword")} hint={confirm && confirm !== password ? <span className="error-text">{t("auth.passwordMismatch")}</span> : undefined}><PasswordInput value={confirm} onChange={setConfirm} autoComplete="new-password" /></Field>
          </div>
        </div>
      )}
    </FormModal>
  );
}

function ResetPasswordForm({ user, onClose }: { user: UserDTO; onClose: () => void }) {
  const services = useServices();
  const [password, setPassword] = useState("");
  const [confirm, setConfirm] = useState("");
  return (
    <FormModal title={t("users.resetTitle")} size="narrow" saveLabel={t("users.reset")} onClose={onClose} canSave={password.length >= MIN_PASSWORD && password === confirm}
      onSave={async () => { await services.resetPassword(user, password); toast(t("users.resetDone", { name: fullName(user) })); }}>
      <p className="small muted" style={{ margin: 0 }}>{t("users.resetIntro", { name: fullName(user) })}</p>
      <Field label={t("users.newPassword")} hint={t("auth.minChars", { count: MIN_PASSWORD })}><PasswordInput value={password} onChange={setPassword} autoComplete="new-password" autoFocus /></Field>
      <Field label={t("auth.confirmPassword")} hint={confirm && confirm !== password ? <span className="error-text">{t("auth.passwordMismatch")}</span> : undefined}><PasswordInput value={confirm} onChange={setConfirm} autoComplete="new-password" /></Field>
    </FormModal>
  );
}
