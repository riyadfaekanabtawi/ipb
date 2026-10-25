import { ArrowLeft, Eye, EyeOff, KeyRound, Mail } from "lucide-react";
import { useState, type ReactNode } from "react";
import { Link, useNavigate, useSearchParams } from "react-router-dom";
import { useAuth } from "../data/session";
import { acceptInvite, forgotPassword } from "../lib/api";
import { Threads } from "../ui/kit";

export function AuthLayout({ children, kicker = "Control de producción textil", headline, copy }: { children: ReactNode; kicker?: string; headline?: string; copy?: string }) {
  return (
    <div className="auth">
      <div className="auth-art">
        <Threads count={20} />
        <div className="row">
          <img src="/icon.png" alt="" width={42} height={42} style={{ borderRadius: 12 }} />
          <div>
            <div style={{ fontWeight: 850, fontSize: 22, letterSpacing: "-0.02em" }}>Trama</div>
            <div style={{ opacity: 0.75, fontSize: 13 }}>{kicker}</div>
          </div>
        </div>
        <div>
          <h1>{headline ?? "Del corte al envío, todo en un solo hilo."}</h1>
          <p>{copy ?? "Asigna cortes a tus plantas según su capacidad, sigue la producción en tiempo real y no pierdas de vista ningún envío urgente."}</p>
        </div>
        <div className="tiny" style={{ opacity: 0.6 }}>Tus datos viajan cifrados y se guardan cifrados por empresa.</div>
      </div>
      <div className="auth-form weave-bg">
        <div className="auth-card">{children}</div>
      </div>
    </div>
  );
}

export function PasswordInput({ value, onChange, autoComplete, placeholder, autoFocus }: { value: string; onChange: (v: string) => void; autoComplete: string; placeholder?: string; autoFocus?: boolean }) {
  const [show, setShow] = useState(false);
  return (
    <div className="input-affix">
      <KeyRound />
      <input className="input" type={show ? "text" : "password"} value={value} autoComplete={autoComplete} placeholder={placeholder} autoFocus={autoFocus} onChange={(e) => onChange(e.target.value)} style={{ paddingRight: 42 }} />
      <button type="button" className="btn ghost icon sm" style={{ position: "absolute", right: 4 }} onClick={() => setShow(!show)} aria-label={show ? "Ocultar contraseña" : "Mostrar contraseña"}>
        {show ? <EyeOff /> : <Eye />}
      </button>
    </div>
  );
}

export function LoginPage() {
  const { signIn } = useAuth();
  const navigate = useNavigate();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  return (
    <AuthLayout>
      <div>
        <h2>Inicia sesión</h2>
        <p className="muted" style={{ margin: "6px 0 0" }}>Entra con el correo y la contraseña de tu usuario de Trama.</p>
      </div>
      <form
        className="col"
        style={{ gap: 14 }}
        onSubmit={async (e) => {
          e.preventDefault();
          setBusy(true);
          setError(null);
          try {
            await signIn(email, password);
            navigate("/app", { replace: true });
          } catch (err) {
            setError(err instanceof Error ? err.message : "No se pudo iniciar sesión.");
          } finally {
            setBusy(false);
          }
        }}
      >
        <div className="field">
          <label htmlFor="email">Correo electrónico</label>
          <div className="input-affix">
            <Mail />
            <input id="email" className="input" type="email" autoComplete="username" required autoFocus value={email} onChange={(e) => setEmail(e.target.value)} placeholder="tu@empresa.com" />
          </div>
        </div>
        <div className="field">
          <label>Contraseña</label>
          <PasswordInput value={password} onChange={setPassword} autoComplete="current-password" />
        </div>
        {error && <div className="banner error">{error}</div>}
        <button className="btn primary block" disabled={busy || !email || !password}>{busy ? "Entrando…" : "Entrar"}</button>
        <Link to="/olvide" className="small" style={{ textAlign: "center" }}>¿Olvidaste tu contraseña?</Link>
      </form>
    </AuthLayout>
  );
}

/** Invitation / password reset: both consume a one-time token with /auth/accept-invite. */
export function SetPasswordPage({ mode }: { mode: "invite" | "reset" | "admin" }) {
  const [params] = useSearchParams();
  const token = params.get("token") ?? "";
  const navigate = useNavigate();
  const [password, setPassword] = useState("");
  const [confirm, setConfirm] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [done, setDone] = useState(false);
  const loginPath = mode === "admin" ? "/admin/login" : "/login";
  const title = mode === "reset" ? "Nueva contraseña" : "Activa tu cuenta";
  const intro =
    mode === "reset"
      ? "Elige una contraseña nueva. Por seguridad se cerrarán tus sesiones abiertas."
      : mode === "admin"
        ? "Define la contraseña de tu cuenta del portal de administración."
        : "Bienvenido a Trama. Define tu contraseña para entrar desde la web, el iPad o Android.";
  const mismatch = confirm.length > 0 && confirm !== password;

  return (
    <AuthLayout kicker={mode === "admin" ? "Portal de administración" : undefined}>
      <div>
        <h2>{title}</h2>
        <p className="muted" style={{ margin: "6px 0 0" }}>{intro}</p>
      </div>
      {!token ? (
        <div className="banner error">El enlace no es válido. Revisa que lo copiaste completo.</div>
      ) : done ? (
        <div className="col" style={{ gap: 14 }}>
          <div className="banner info">Listo. Ya puedes iniciar sesión con tu nueva contraseña.</div>
          <button className="btn primary block" onClick={() => navigate(loginPath)}>Ir a iniciar sesión</button>
        </div>
      ) : (
        <form
          className="col"
          style={{ gap: 14 }}
          onSubmit={async (e) => {
            e.preventDefault();
            setBusy(true);
            setError(null);
            try {
              await acceptInvite(token, password);
              setDone(true);
            } catch (err) {
              setError(err instanceof Error ? err.message : "No se pudo guardar la contraseña.");
            } finally {
              setBusy(false);
            }
          }}
        >
          <div className="field">
            <label>Contraseña</label>
            <PasswordInput value={password} onChange={setPassword} autoComplete="new-password" autoFocus />
            <span className="hint">Al menos 8 caracteres.</span>
          </div>
          <div className="field">
            <label>Confirmar contraseña</label>
            <PasswordInput value={confirm} onChange={setConfirm} autoComplete="new-password" />
            {mismatch && <span className="error-text">Las contraseñas no coinciden.</span>}
          </div>
          {error && <div className="banner error">{error}</div>}
          <button className="btn primary block" disabled={busy || password.length < 8 || password !== confirm}>{busy ? "Guardando…" : "Guardar contraseña"}</button>
        </form>
      )}
      <Link to={loginPath} className="small row" style={{ justifyContent: "center", gap: 6 }}><ArrowLeft size={14} /> Volver a iniciar sesión</Link>
    </AuthLayout>
  );
}

export function ForgotPage() {
  const [email, setEmail] = useState("");
  const [busy, setBusy] = useState(false);
  const [sent, setSent] = useState(false);
  const [error, setError] = useState<string | null>(null);
  return (
    <AuthLayout>
      <div>
        <h2>Recupera tu acceso</h2>
        <p className="muted" style={{ margin: "6px 0 0" }}>Te enviaremos un enlace para elegir una contraseña nueva.</p>
      </div>
      {sent ? (
        <div className="banner info">Si el correo está registrado, recibirás un enlace en unos minutos. Revisa también tu carpeta de spam.</div>
      ) : (
        <form
          className="col"
          style={{ gap: 14 }}
          onSubmit={async (e) => {
            e.preventDefault();
            setBusy(true);
            setError(null);
            try {
              await forgotPassword(email);
              setSent(true);
            } catch (err) {
              setError(err instanceof Error ? err.message : "Intenta de nuevo.");
            } finally {
              setBusy(false);
            }
          }}
        >
          <div className="field">
            <label>Correo electrónico</label>
            <div className="input-affix">
              <Mail />
              <input className="input" type="email" required autoFocus value={email} onChange={(e) => setEmail(e.target.value)} placeholder="tu@empresa.com" />
            </div>
          </div>
          {error && <div className="banner error">{error}</div>}
          <button className="btn primary block" disabled={busy || !email}>{busy ? "Enviando…" : "Enviar enlace"}</button>
        </form>
      )}
      <Link to="/login" className="small row" style={{ justifyContent: "center", gap: 6 }}><ArrowLeft size={14} /> Volver a iniciar sesión</Link>
    </AuthLayout>
  );
}
