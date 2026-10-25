import { KeyRound, Pencil, Plus, Power, Trash2, UserCog } from "lucide-react";
import { useState } from "react";
import { ROLE_TITLE, ROLES, asRole } from "../domain/enums";
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
    .filter((u) => matches(query, fullName(u), u.email, ROLE_TITLE[asRole(u.roleRaw)]));
  const active = count("active");

  return (
    <>
      <PageHead title="Usuarios" subtitle={tenant.maxUsers ? `${active} de ${tenant.maxUsers} usuarios activos en tu plan.` : "Quién puede entrar a Trama y qué ve cada puesto."}>
        {writable && <button className="btn primary" onClick={() => setEditing("new")} disabled={!!tenant.maxUsers && active >= tenant.maxUsers}><Plus /> Nuevo usuario</button>}
      </PageHead>
      <div className="row wrap between">
        <Seg value={filter} onChange={setFilter} options={[{ value: "all", label: `Todos (${count("all")})` }, { value: "active", label: `Activos (${count("active")})` }, { value: "inactive", label: `Inactivos (${count("inactive")})` }]} />
        <SearchInput value={query} onChange={setQuery} placeholder="Buscar por nombre, correo o puesto" />
      </div>
      <Card className="pad-0">
        {rows.length === 0 ? <EmptyState icon={UserCog} title={`Sin usuarios ${filter === "active" ? "activos" : filter === "inactive" ? "inactivos" : ""}`} /> : (
          <div className="list">
            {rows.map((u) => {
              const role = asRole(u.roleRaw);
              const plant = db.plantById.get(u.plantID ?? "");
              const isMe = u.id === me.id;
              return (
                <div key={u.id} className="list-row static" style={{ opacity: u.isActive === false ? 0.6 : 1 }}>
                  <Avatar name={fullName(u)} image={u.avatarData} size={42} />
                  <div className="grow" style={{ minWidth: 0 }}>
                    <div className="bold ellipsis">{fullName(u)} {isMe && <span className="tiny faint">(tú)</span>}</div>
                    <div className="tiny muted ellipsis">{u.email}{u.phone ? ` · ${u.phone}` : ""}</div>
                  </div>
                  <Pill text={ROLE_TITLE[role]} tint={role === "Administrador" ? "thread" : "brand"} />
                  {role === "Gerente de Planta" && <Pill text={plant?.name ?? "Sin planta asignada"} tint={plant ? "muted" : "danger"} />}
                  <Pill text={u.isActive === false ? "Inactivo" : "Activo"} tint={u.isActive === false ? "muted" : "success"} />
                  {writable && (
                    <div className="row" style={{ gap: 2 }}>
                      <button className="btn ghost icon sm" title="Editar" aria-label="Editar" onClick={() => setEditing(u)}><Pencil /></button>
                      <button className="btn ghost icon sm" title="Restablecer contraseña" aria-label="Restablecer contraseña" onClick={() => setResetting(u)}><KeyRound /></button>
                      {!isMe && (
                        <>
                          <button className="btn ghost icon sm" title={u.isActive === false ? "Activar" : "Desactivar"} aria-label={u.isActive === false ? "Activar" : "Desactivar"}
                            onClick={() => run(() => services.setActive(u, u.isActive === false), u.isActive === false ? `${fullName(u)} puede volver a ingresar` : `${fullName(u)} fue desactivado`)}><Power /></button>
                          <button className="btn ghost icon sm danger" title="Eliminar" aria-label="Eliminar" onClick={() => setDeleting(u)}><Trash2 /></button>
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
      {deleting && <ConfirmModal title={`¿Eliminar a ${fullName(deleting)}?`} message="Perderá el acceso a Trama. Si solo quieres pausar su acceso, desactívalo." onClose={() => setDeleting(null)}
        onConfirm={() => run(() => services.deleteUser(deleting), `Usuario «${fullName(deleting)}» eliminado`)} />}
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
      title={user ? "Editar usuario" : "Nuevo usuario"}
      onClose={onClose}
      canSave={canSave}
      saveLabel={user ? "Guardar" : "Crear"}
      onSave={async () => {
        if (user) {
          await services.updateUser(user, draft);
          toast("Usuario actualizado");
        } else {
          const created = await services.createUser(draft, password);
          toast(`Usuario «${fullName(created)}» creado`);
        }
      }}
    >
      <div className="form-section">
        <h4>Perfil</h4>
        <div className="form-grid">
          <TextField label="Nombre" value={draft.firstName} onChange={(v) => set({ firstName: v })} autoFocus />
          <TextField label="Apellido" value={draft.lastName} onChange={(v) => set({ lastName: v })} />
        </div>
        <PhotoField label="Foto de perfil" value={draft.avatarData} onChange={(v) => set({ avatarData: v })} maxSide={384} />
      </div>
      <div className="form-section">
        <h4>Contacto</h4>
        <div className="form-grid">
          <TextField label="Correo electrónico" type="email" value={draft.email} onChange={(v) => set({ email: v })} autoComplete="off" />
          <TextField label="Teléfono" type="tel" value={draft.phone} onChange={(v) => set({ phone: v })} />
        </div>
      </div>
      <div className="form-section">
        <h4>Puesto</h4>
        <div className="form-grid">
          <SelectField label="Puesto" value={draft.role} onChange={(v) => v && set({ role: v })} options={ROLES.map((r) => ({ value: r, label: ROLE_TITLE[r] }))}
            hint={isMe ? "No puedes cambiar tu propio puesto." : undefined} />
          {draft.role === "Gerente de Planta" && (
            <SelectField label="Planta" value={draft.plantID ?? ""} onChange={(v) => set({ plantID: v || null })} placeholder="Elegir planta" options={db.plants.map((p) => ({ value: p.id, label: p.name ?? "Planta" }))}
              hint="Solo verá la producción de su planta." />
          )}
        </div>
      </div>
      {!user && (
        <div className="form-section">
          <h4>Contraseña</h4>
          <div className="form-grid">
            <Field label="Contraseña" hint={`Mínimo ${MIN_PASSWORD} caracteres. El usuario podrá ingresar sin conexión con ella.`}><PasswordInput value={password} onChange={setPassword} autoComplete="new-password" /></Field>
            <Field label="Confirmar contraseña" hint={confirm && confirm !== password ? <span className="error-text">Las contraseñas no coinciden.</span> : undefined}><PasswordInput value={confirm} onChange={setConfirm} autoComplete="new-password" /></Field>
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
    <FormModal title="Restablecer contraseña" size="narrow" saveLabel="Restablecer" onClose={onClose} canSave={password.length >= MIN_PASSWORD && password === confirm}
      onSave={async () => { await services.resetPassword(user, password); toast(`Contraseña de ${fullName(user)} restablecida`); }}>
      <p className="small muted" style={{ margin: 0 }}>Comparte la nueva contraseña con {fullName(user)} en persona.</p>
      <Field label="Nueva contraseña" hint={`Al menos ${MIN_PASSWORD} caracteres.`}><PasswordInput value={password} onChange={setPassword} autoComplete="new-password" autoFocus /></Field>
      <Field label="Confirmar contraseña" hint={confirm && confirm !== password ? <span className="error-text">Las contraseñas no coinciden.</span> : undefined}><PasswordInput value={confirm} onChange={setConfirm} autoComplete="new-password" /></Field>
    </FormModal>
  );
}
