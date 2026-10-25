import { ArrowLeft, Eye, EyeOff, KeyRound, Mail } from "lucide-react";
import { useState, type ReactNode } from "react";
import { Link, useNavigate, useSearchParams } from "react-router-dom";
import { useAuth } from "../data/session";
import { t } from "../i18n";
import { acceptInvite, forgotPassword } from "../lib/api";
import { LanguageSwitcher, Threads } from "../ui/kit";

/** Company sign-in layout. The admin portal passes its own copy and hides the language picker. */
export function AuthLayout({ children, kicker, headline, copy, languagePicker = true }: { children: ReactNode; kicker?: string; headline?: string; copy?: string; languagePicker?: boolean }) {
  return (
    <div className="auth">
      <div className="auth-art">
        <Threads count={20} />
        <div className="row">
          <img src="/icon.png" alt="" width={42} height={42} style={{ borderRadius: 12 }} />
          <div>
            <div style={{ fontWeight: 850, fontSize: 22, letterSpacing: "-0.02em" }}>Trama</div>
            <div style={{ opacity: 0.75, fontSize: 13 }}>{kicker ?? t("auth.kicker")}</div>
          </div>
        </div>
        <div>
          <h1>{headline ?? t("auth.headline")}</h1>
          <p>{copy ?? t("auth.copy")}</p>
        </div>
        <div className="tiny" style={{ opacity: 0.6 }}>{t("auth.encrypted")}</div>
      </div>
      <div className="auth-form weave-bg">
        {languagePicker && <LanguageSwitcher className="auth-lang" />}
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
      <button type="button" className="btn ghost icon sm" style={{ position: "absolute", right: 4 }} onClick={() => setShow(!show)} aria-label={show ? t("auth.hidePassword") : t("auth.showPassword")}>
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
        <h2>{t("auth.signInTitle")}</h2>
        <p className="muted" style={{ margin: "6px 0 0" }}>{t("auth.signInIntro")}</p>
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
            setError(err instanceof Error ? err.message : t("auth.signInFailed"));
          } finally {
            setBusy(false);
          }
        }}
      >
        <div className="field">
          <label htmlFor="email">{t("common.email")}</label>
          <div className="input-affix">
            <Mail />
            <input id="email" className="input" type="email" autoComplete="username" required autoFocus value={email} onChange={(e) => setEmail(e.target.value)} placeholder={t("auth.emailPlaceholder")} />
          </div>
        </div>
        <div className="field">
          <label>{t("auth.password")}</label>
          <PasswordInput value={password} onChange={setPassword} autoComplete="current-password" />
        </div>
        {error && <div className="banner error">{error}</div>}
        <button className="btn primary block" disabled={busy || !email || !password}>{busy ? t("auth.signingIn") : t("auth.signIn")}</button>
        <Link to="/olvide" className="small" style={{ textAlign: "center" }}>{t("auth.forgotLink")}</Link>
      </form>
    </AuthLayout>
  );
}

const MIN_INVITE_PASSWORD = 8;

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
  const title = mode === "reset" ? t("auth.newPasswordTitle") : t("auth.activateTitle");
  const intro = mode === "reset" ? t("auth.resetIntro") : mode === "admin" ? t("auth.adminIntro") : t("auth.inviteIntro");
  const mismatch = confirm.length > 0 && confirm !== password;

  return (
    <AuthLayout kicker={mode === "admin" ? t("auth.adminKicker") : undefined} languagePicker={mode !== "admin"}>
      <div>
        <h2>{title}</h2>
        <p className="muted" style={{ margin: "6px 0 0" }}>{intro}</p>
      </div>
      {!token ? (
        <div className="banner error">{t("auth.invalidLink")}</div>
      ) : done ? (
        <div className="col" style={{ gap: 14 }}>
          <div className="banner info">{t("auth.passwordSaved")}</div>
          <button className="btn primary block" onClick={() => navigate(loginPath)}>{t("auth.goToSignIn")}</button>
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
              setError(err instanceof Error ? err.message : t("auth.savePasswordFailed"));
            } finally {
              setBusy(false);
            }
          }}
        >
          <div className="field">
            <label>{t("auth.password")}</label>
            <PasswordInput value={password} onChange={setPassword} autoComplete="new-password" autoFocus />
            <span className="hint">{t("auth.minChars", { count: MIN_INVITE_PASSWORD })}</span>
          </div>
          <div className="field">
            <label>{t("auth.confirmPassword")}</label>
            <PasswordInput value={confirm} onChange={setConfirm} autoComplete="new-password" />
            {mismatch && <span className="error-text">{t("auth.passwordMismatch")}</span>}
          </div>
          {error && <div className="banner error">{error}</div>}
          <button className="btn primary block" disabled={busy || password.length < MIN_INVITE_PASSWORD || password !== confirm}>{busy ? t("common.saving") : t("auth.savePassword")}</button>
        </form>
      )}
      <Link to={loginPath} className="small row" style={{ justifyContent: "center", gap: 6 }}><ArrowLeft size={14} /> {t("auth.backToSignIn")}</Link>
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
        <h2>{t("auth.forgotTitle")}</h2>
        <p className="muted" style={{ margin: "6px 0 0" }}>{t("auth.forgotIntro")}</p>
      </div>
      {sent ? (
        <div className="banner info">{t("auth.forgotSent")}</div>
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
              setError(err instanceof Error ? err.message : t("auth.tryAgain"));
            } finally {
              setBusy(false);
            }
          }}
        >
          <div className="field">
            <label>{t("common.email")}</label>
            <div className="input-affix">
              <Mail />
              <input className="input" type="email" required autoFocus value={email} onChange={(e) => setEmail(e.target.value)} placeholder={t("auth.emailPlaceholder")} />
            </div>
          </div>
          {error && <div className="banner error">{error}</div>}
          <button className="btn primary block" disabled={busy || !email}>{busy ? t("auth.sending") : t("auth.sendLink")}</button>
        </form>
      )}
      <Link to="/login" className="small row" style={{ justifyContent: "center", gap: 6 }}><ArrowLeft size={14} /> {t("auth.backToSignIn")}</Link>
    </AuthLayout>
  );
}
