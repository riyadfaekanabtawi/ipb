// Shared components (the web counterparts of ios/Trama/DesignSystem/Components).

import { AlertCircle, CheckCircle2, ImagePlus, Info, Search, Shirt, Trash2, X } from "lucide-react";
import { useEffect, useId, useRef, useState, useSyncExternalStore, type ComponentType, type ReactNode } from "react";
import { createPortal } from "react-dom";
import type { Tint } from "../domain/enums";
import { capacityTint } from "../domain/rules";
import { fmtPercent, initials } from "../lib/format";
import { dismiss, toastStore } from "../lib/toast";

export type Icon = ComponentType<{ size?: number | string; className?: string; strokeWidth?: number }>;

/** Stable accent for an arbitrary string (Theme.accent(for:)), same palette and hash as iOS. */
const ACCENTS = ["#145C6E", "#E8A317", "#6E56CF", "#2E9E5B", "#D93A3F", "#3E63DD", "#C2410C", "#0E7490"];
export function accentFor(key: string): string {
  let hash = 5381;
  for (const ch of key) hash = ((hash << 5) + hash + (ch.codePointAt(0) ?? 0)) | 0;
  return ACCENTS[Math.abs(hash) % ACCENTS.length];
}

/** Categorical chart slots in fixed order (validated palette); entity color follows its index. */
export const seriesColor = (index: number) => `var(--s${(index % 8) + 1})`;

export const imageSrc = (b64: string | null | undefined) => (b64 ? (b64.startsWith("data:") ? b64 : `data:image/jpeg;base64,${b64}`) : null);

export function Card({ children, className = "", title, subtitle, action, ...rest }: { children?: ReactNode; className?: string; title?: ReactNode; subtitle?: ReactNode; action?: ReactNode } & React.HTMLAttributes<HTMLDivElement>) {
  return (
    <div className={`card ${className}`} {...rest}>
      {(title || action) && (
        <div className="card-head">
          <div>
            {title && <h3>{title}</h3>}
            {subtitle && <div className="sub">{subtitle}</div>}
          </div>
          {action}
        </div>
      )}
      {children}
    </div>
  );
}

export function PageHead({ title, subtitle, children }: { title: ReactNode; subtitle?: ReactNode; children?: ReactNode }) {
  return (
    <div className="page-head">
      <div>
        <h2>{title}</h2>
        {subtitle && <p>{subtitle}</p>}
      </div>
      {children && <div className="row wrap">{children}</div>}
    </div>
  );
}

export function KPITile({ title, value, icon: I, tint = "brand", footnote, onClick }: { title: string; value: string; icon: Icon; tint?: Tint; footnote?: string; onClick?: () => void }) {
  const body = (
    <>
      <div className={`kpi-icon tint-bg t-${tint}`}>
        <I />
      </div>
      <div>
        <div className="kpi-value">{value}</div>
        <div className="kpi-title">{title}</div>
        {footnote && <div className="kpi-foot">{footnote}</div>}
      </div>
    </>
  );
  return onClick ? (
    <button type="button" className="card kpi" onClick={onClick}>
      {body}
    </button>
  ) : (
    <div className="card kpi">{body}</div>
  );
}

export function Pill({ text, icon: I, tint = "muted", title }: { text: ReactNode; icon?: Icon; tint?: Tint; title?: string }) {
  return (
    <span className={`pill t-${tint}`} title={title}>
      {I && <I />}
      {text}
    </span>
  );
}

export function CapacityBar({ used, max, preview = 0, large }: { used: number; max: number; preview?: number; large?: boolean }) {
  const ratio = max > 0 ? used / max : 0;
  const previewRatio = max > 0 ? (used + preview) / max : 0;
  return (
    <div className={`cap ${large ? "lg" : ""}`} role="meter" aria-valuenow={Math.round(ratio * 100)} aria-valuemin={0} aria-valuemax={100} aria-label={`Capacidad usada ${fmtPercent(ratio)}`}>
      {preview > 0 && <span className={`preview t-${capacityTint(previewRatio)}`} style={{ width: `${Math.min(1, previewRatio) * 100}%` }} />}
      <span className={`used t-${capacityTint(ratio)}`} style={{ width: `${Math.min(1, ratio) * 100}%` }} />
    </div>
  );
}

export function Progress({ value, tint = "brand" }: { value: number; tint?: Tint }) {
  return (
    <div className={`progress t-${tint}`}>
      <span style={{ width: `${Math.max(0, Math.min(1, value)) * 100}%` }} />
    </div>
  );
}

export function Avatar({ name, image, size = 40, icon: I }: { name: string; image?: string | null; size?: number; icon?: Icon }) {
  const src = imageSrc(image);
  return (
    <span className="avatar" style={{ width: size, height: size, borderRadius: size * 0.3, background: src ? undefined : `linear-gradient(160deg, ${accentFor(name)}, color-mix(in srgb, ${accentFor(name)} 70%, black))`, fontSize: size * 0.38 }}>
      {src ? <img src={src} alt="" /> : I ? <I /> : initials(name)}
    </span>
  );
}

export function Swatch({ image, name, onClick, height }: { image?: string | null; name: string; onClick?: () => void; height?: number }) {
  const src = imageSrc(image);
  return (
    <div className="swatch" onClick={onClick} style={{ background: src ? "var(--fill)" : accentFor(name), cursor: onClick ? "zoom-in" : undefined, aspectRatio: height ? "auto" : undefined, height }}>
      {src ? <img src={src} alt={name} loading="lazy" /> : (<><span className="weave-overlay" /><Shirt strokeWidth={1.4} /></>)}
    </div>
  );
}

export function EmptyState({ icon: I, title, message, action }: { icon: Icon; title: string; message?: string; action?: ReactNode }) {
  return (
    <div className="empty">
      <div className="icon">
        <I />
      </div>
      <h3>{title}</h3>
      {message && <p>{message}</p>}
      {action}
    </div>
  );
}

export function InfoRow({ label, value, icon: I }: { label: string; value: ReactNode; icon?: Icon }) {
  return (
    <div className="info-row">
      {I && <I />}
      <span className="k">{label}</span>
      <span className="v">{value}</span>
    </div>
  );
}

export function Seg<T extends string>({ value, options, onChange }: { value: T; options: { value: T; label: ReactNode }[]; onChange: (v: T) => void }) {
  return (
    <div className="seg" role="tablist">
      {options.map((o) => (
        <button key={o.value} type="button" role="tab" aria-selected={o.value === value} className={o.value === value ? "on" : ""} onClick={() => onChange(o.value)}>
          {o.label}
        </button>
      ))}
    </div>
  );
}

export function SearchInput({ value, onChange, placeholder }: { value: string; onChange: (v: string) => void; placeholder: string }) {
  return (
    <div className="input-affix" style={{ minWidth: 220, flex: "1 1 260px", maxWidth: 420 }}>
      <Search />
      <input className="input" type="search" value={value} placeholder={placeholder} onChange={(e) => onChange(e.target.value)} />
    </div>
  );
}

// Modal ---------------------------------------------------------------------------------

export function Modal({ title, onClose, children, footer, size }: { title: ReactNode; onClose: () => void; children: ReactNode; footer?: ReactNode; size?: "wide" | "narrow" }) {
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => e.key === "Escape" && onClose();
    document.addEventListener("keydown", onKey);
    const prev = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    return () => {
      document.removeEventListener("keydown", onKey);
      document.body.style.overflow = prev;
    };
  }, [onClose]);
  return createPortal(
    <div className="modal-scrim" onMouseDown={(e) => e.target === e.currentTarget && onClose()}>
      <div className={`modal ${size ?? ""}`} role="dialog" aria-modal="true">
        <div className="modal-head">
          <h3>{title}</h3>
          <button type="button" className="btn ghost icon" onClick={onClose} aria-label="Cerrar">
            <X />
          </button>
        </div>
        <div className="modal-body">{children}</div>
        {footer && <div className="modal-foot">{footer}</div>}
      </div>
    </div>,
    document.body,
  );
}

/** Form sheet: modal + Cancel/Save footer that runs an async save and closes on success. */
export function FormModal({ title, onClose, onSave, canSave = true, saveLabel = "Guardar", children, size }: {
  title: ReactNode; onClose: () => void; onSave: () => Promise<unknown> | unknown; canSave?: boolean; saveLabel?: string; children: ReactNode; size?: "wide" | "narrow";
}) {
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const formId = useId();
  const submit = async (e?: React.FormEvent) => {
    e?.preventDefault();
    if (!canSave || busy) return;
    setBusy(true);
    setError(null);
    try {
      await onSave();
      onClose();
    } catch (err) {
      setError(err instanceof Error ? err.message : String(err));
    } finally {
      setBusy(false);
    }
  };
  return (
    <Modal
      title={title}
      onClose={onClose}
      size={size}
      footer={
        <>
          {error && <span className="error-text grow">{error}</span>}
          <button type="button" className="btn" onClick={onClose}>Cancelar</button>
          <button type="submit" form={formId} className="btn primary" disabled={!canSave || busy}>
            {busy ? "Guardando…" : saveLabel}
          </button>
        </>
      }
    >
      <form id={formId} onSubmit={submit} className="col" style={{ gap: 16 }}>
        {children}
      </form>
    </Modal>
  );
}

export function ConfirmModal({ title, message, confirmLabel = "Eliminar", onConfirm, onClose }: { title: string; message?: string; confirmLabel?: string; onConfirm: () => Promise<unknown> | unknown; onClose: () => void }) {
  const [busy, setBusy] = useState(false);
  return (
    <Modal
      title={title}
      onClose={onClose}
      size="narrow"
      footer={
        <>
          <button type="button" className="btn" onClick={onClose}>Cancelar</button>
          <button
            type="button"
            className="btn danger solid"
            disabled={busy}
            onClick={async () => {
              setBusy(true);
              try {
                await onConfirm();
              } finally {
                setBusy(false);
                onClose();
              }
            }}
          >
            <Trash2 /> {confirmLabel}
          </button>
        </>
      }
    >
      <p className="muted" style={{ margin: 0 }}>{message ?? "Esta acción no se puede deshacer."}</p>
    </Modal>
  );
}

// Fields --------------------------------------------------------------------------------

export function Field({ label, hint, children }: { label: ReactNode; hint?: ReactNode; children: ReactNode }) {
  return (
    <div className="field">
      <label>{label}</label>
      {children}
      {hint && <span className="hint">{hint}</span>}
    </div>
  );
}

export function TextField({ label, value, onChange, hint, ...rest }: { label: string; value: string; onChange: (v: string) => void; hint?: ReactNode } & Omit<React.InputHTMLAttributes<HTMLInputElement>, "value" | "onChange">) {
  return (
    <Field label={label} hint={hint}>
      <input className="input" value={value} onChange={(e) => onChange(e.target.value)} {...rest} />
    </Field>
  );
}

/** Numeric field that keeps the raw text while typing (IntField / DecimalField). */
export function NumberField({ label, value, onChange, hint, integer, prefix, placeholder, autoFocus }: {
  label: string; value: number; onChange: (v: number) => void; hint?: ReactNode; integer?: boolean; prefix?: string; placeholder?: string; autoFocus?: boolean;
}) {
  const [text, setText] = useState(Number.isFinite(value) && value !== 0 ? String(value) : "");
  const last = useRef(value);
  useEffect(() => {
    if (value !== last.current) {
      last.current = value;
      setText(Number.isFinite(value) && value !== 0 ? String(value) : "");
    }
  }, [value]);
  return (
    <Field label={label} hint={hint}>
      <div className={prefix ? "input-affix" : undefined}>
        {prefix && <span style={{ position: "absolute", left: 12, color: "var(--text-3)", fontWeight: 600 }}>{prefix}</span>}
        <input
          className="input num"
          style={prefix ? { paddingLeft: 28 } : undefined}
          inputMode={integer ? "numeric" : "decimal"}
          value={text}
          placeholder={placeholder ?? "0"}
          autoFocus={autoFocus}
          onChange={(e) => {
            const raw = e.target.value;
            setText(raw);
            const n = Number(raw.replace(/[,\s$]/g, ""));
            const v = raw.trim() === "" ? 0 : Number.isFinite(n) ? (integer ? Math.trunc(n) : n) : Number.NaN;
            last.current = v;
            onChange(v);
          }}
        />
      </div>
    </Field>
  );
}

export function SelectField<T extends string>({ label, value, onChange, options, hint, placeholder }: {
  label: string; value: T | ""; onChange: (v: T | "") => void; options: { value: T; label: string }[]; hint?: ReactNode; placeholder?: string;
}) {
  return (
    <Field label={label} hint={hint}>
      <select className="input" value={value} onChange={(e) => onChange(e.target.value as T | "")}>
        {placeholder !== undefined && <option value="">{placeholder}</option>}
        {options.map((o) => (
          <option key={o.value} value={o.value}>{o.label}</option>
        ))}
      </select>
    </Field>
  );
}

/** Picks an image, downsizes it (max 1280 px, JPEG) and returns bare base64 like the apps store. */
export async function readImage(file: File, maxSide = 1280): Promise<string> {
  const url = URL.createObjectURL(file);
  try {
    const img = await new Promise<HTMLImageElement>((resolve, reject) => {
      const el = new Image();
      el.onload = () => resolve(el);
      el.onerror = () => reject(new Error("No se pudo leer la imagen."));
      el.src = url;
    });
    const scale = Math.min(1, maxSide / Math.max(img.width, img.height));
    const canvas = document.createElement("canvas");
    canvas.width = Math.round(img.width * scale);
    canvas.height = Math.round(img.height * scale);
    canvas.getContext("2d")!.drawImage(img, 0, 0, canvas.width, canvas.height);
    return canvas.toDataURL("image/jpeg", 0.82).split(",")[1];
  } finally {
    URL.revokeObjectURL(url);
  }
}

export function PhotoField({ label, value, onChange, maxSide }: { label: string; value: string | null; onChange: (v: string | null) => void; maxSide?: number }) {
  const input = useRef<HTMLInputElement>(null);
  const src = imageSrc(value);
  const [error, setError] = useState<string | null>(null);
  return (
    <Field label={label}>
      <div className="photo-drop">
        <div className="thumb">{src ? <img src={src} alt="" /> : <ImagePlus color="var(--text-3)" />}</div>
        <div className="col" style={{ gap: 6 }}>
          <div className="row wrap">
            <button type="button" className="btn sm" onClick={() => input.current?.click()}>{src ? "Cambiar" : "Elegir imagen"}</button>
            {src && <button type="button" className="btn sm ghost danger" onClick={() => onChange(null)}>Quitar</button>}
          </div>
          <span className="tiny faint">JPG o PNG; se optimiza antes de sincronizar.</span>
          {error && <span className="error-text">{error}</span>}
        </div>
        <input
          ref={input}
          type="file"
          accept="image/*"
          hidden
          onChange={async (e) => {
            const file = e.target.files?.[0];
            e.target.value = "";
            if (!file) return;
            try {
              setError(null);
              onChange(await readImage(file, maxSide));
            } catch (err) {
              setError(err instanceof Error ? err.message : "No se pudo leer la imagen.");
            }
          }}
        />
      </div>
    </Field>
  );
}

// Toasts --------------------------------------------------------------------------------

export function Toaster() {
  const toasts = useSyncExternalStore(toastStore.subscribe, toastStore.get);
  return (
    <div className="toaster" aria-live="polite">
      {toasts.map((t) => {
        const I = t.kind === "success" ? CheckCircle2 : t.kind === "error" ? AlertCircle : Info;
        return (
          <div key={t.id} className={`toast ${t.kind}`} onClick={() => dismiss(t.id)} role="status">
            <I />
            <span>{t.message}</span>
          </div>
        );
      })}
    </div>
  );
}

// Brand art -------------------------------------------------------------------------------

/** Flowing threads (ThreadField), rendered once as static SVG with a slow CSS drift. */
export function Threads({ count = 16 }: { count?: number }) {
  const paths = Array.from({ length: count }, (_, i) => {
    const p = i / count;
    const baseY = 8 + 84 * p;
    const amp = 3 + 5 * Math.sin(p * Math.PI);
    const freq = 1.4 + 0.9 * Math.sin(i * 1.7);
    const phase = i;
    let d = "";
    for (let s = 0; s <= 40; s++) {
      const u = s / 40;
      const y = baseY + amp * Math.sin(u * Math.PI * 2 * freq + phase) + amp * 0.35 * Math.sin(u * Math.PI * 7 + phase * 1.3);
      d += `${s ? "L" : "M"}${(u * 100).toFixed(2)},${y.toFixed(2)}`;
    }
    const color = ["#F4C430", "#ffffff", "#3FA7BD"][i % 3];
    return <path key={i} d={d} fill="none" stroke={color} strokeOpacity={0.12 + 0.2 * ((i * 7) % 5) / 5} strokeWidth={i % 5 === 0 ? 2.2 : 1} vectorEffect="non-scaling-stroke" />;
  });
  return (
    <svg className="threads" viewBox="0 0 100 100" preserveAspectRatio="none" aria-hidden="true">
      {paths}
    </svg>
  );
}

export function Spinner() {
  return <div className="spinner" aria-label="Cargando" />;
}
