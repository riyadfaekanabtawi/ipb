// Server-side messages in Spanish (default), English and Portuguese (Brazil). The language
// comes from the request's Accept-Language header; error `code` values never change, so clients
// that branch on codes keep working whatever the language.

export const LANGS = ["es", "en", "pt"] as const;
export type Lang = (typeof LANGS)[number];
export const DEFAULT_LANG: Lang = "es";

/** BCP 47 locale used for dates and numbers in each language. */
export const LOCALE: Record<Lang, string> = { es: "es-MX", en: "en-US", pt: "pt-BR" };

type Message = string | { one: string; other: string };

const es = {
  unauthenticated: "Inicia sesión para continuar.",
  sessionExpired: "Tu sesión expiró. Vuelve a iniciar sesión.",
  invalidJson: "Solicitud inválida.",
  invalidInput: "Dato inválido: {field}.",
  invalidData: "Datos inválidos.",
  rateLimited: "Demasiados intentos. Espera unos minutos e inténtalo de nuevo.",
  tooLarge: "El envío es demasiado grande; sincroniza en partes.",
  invalidCursor: "Cursor inválido.",
  routeNotFound: "Ruta no encontrada.",
  serverError: "Ocurrió un error. Intenta de nuevo.",
  planWebOnly: "Tu plan es Web: entra desde el navegador o cambia a un plan con apps.",
  deviceLimit: { one: "Tu licencia permite {count} dispositivo. Libera uno desde la web o contacta a soporte.", other: "Tu licencia permite {count} dispositivos. Libera uno desde la web o contacta a soporte." },
  deviceConflict: "Este dispositivo está registrado en otra empresa.",
  badCredentials: "Correo o contraseña incorrectos.",
  userInactive: "Tu usuario está desactivado. Comunícate con tu administrador.",
  tenantNotFound: "La empresa ya no existe.",
  licenceSuspendedLogin: "La licencia de tu empresa está suspendida. Contacta a soporte.",
  inviteInvalid: "El enlace ya se usó o expiró. Pide uno nuevo.",
  emailTaken: "Ya existe un usuario con ese correo.",
  companyNotFound: "Empresa no encontrada.",
  deviceNotFound: "Dispositivo no encontrado o ya liberado.",
  userNotFound: "Usuario no encontrado.",
  licenceExpiredReadOnly: "Tu licencia venció: los datos son de solo lectura.",
  licenceSuspended: "Tu licencia está suspendida.",
  roleForbidden: "Tu puesto no permite este cambio.",
  changeWithoutData: "Cambio sin datos.",
  stale: "Hay una versión más reciente.",
  plantLimit: { one: "Tu plan permite {count} planta.", other: "Tu plan permite {count} plantas." },
  userOtherCompany: "Ese usuario pertenece a otra empresa.",
  cannotRemoveSelf: "No puedes desactivar ni eliminar tu propio usuario.",
  invalidUserData: "Datos de usuario inválidos.",
  userLimit: { one: "Tu plan permite {count} usuario activo.", other: "Tu plan permite {count} usuarios activos." },
} satisfies Record<string, Message>;

export type MessageKey = keyof typeof es;
type Dictionary = Record<MessageKey, Message>;

const en: Dictionary = {
  unauthenticated: "Sign in to continue.",
  sessionExpired: "Your session expired. Please sign in again.",
  invalidJson: "Invalid request.",
  invalidInput: "Invalid value: {field}.",
  invalidData: "Invalid data.",
  rateLimited: "Too many attempts. Wait a few minutes and try again.",
  tooLarge: "This upload is too large; sync in smaller batches.",
  invalidCursor: "Invalid cursor.",
  routeNotFound: "Route not found.",
  serverError: "Something went wrong. Please try again.",
  planWebOnly: "Your plan is Web only: sign in from a browser or switch to a plan that includes the apps.",
  deviceLimit: { one: "Your license allows {count} device. Free one up from the web app or contact support.", other: "Your license allows {count} devices. Free one up from the web app or contact support." },
  deviceConflict: "This device is registered to another company.",
  badCredentials: "Incorrect email or password.",
  userInactive: "Your user is deactivated. Contact your administrator.",
  tenantNotFound: "This company no longer exists.",
  licenceSuspendedLogin: "Your company's license is suspended. Contact support.",
  inviteInvalid: "This link was already used or has expired. Request a new one.",
  emailTaken: "A user with that email already exists.",
  companyNotFound: "Company not found.",
  deviceNotFound: "Device not found or already released.",
  userNotFound: "User not found.",
  licenceExpiredReadOnly: "Your license has expired: data is read-only.",
  licenceSuspended: "Your license is suspended.",
  roleForbidden: "Your role doesn't allow this change.",
  changeWithoutData: "The change has no data.",
  stale: "A newer version exists.",
  plantLimit: { one: "Your plan allows {count} plant.", other: "Your plan allows {count} plants." },
  userOtherCompany: "That user belongs to another company.",
  cannotRemoveSelf: "You can't deactivate or delete your own user.",
  invalidUserData: "Invalid user data.",
  userLimit: { one: "Your plan allows {count} active user.", other: "Your plan allows {count} active users." },
};

const pt: Dictionary = {
  unauthenticated: "Entre para continuar.",
  sessionExpired: "Sua sessão expirou. Entre novamente.",
  invalidJson: "Solicitação inválida.",
  invalidInput: "Dado inválido: {field}.",
  invalidData: "Dados inválidos.",
  rateLimited: "Muitas tentativas. Aguarde alguns minutos e tente novamente.",
  tooLarge: "O envio é grande demais; sincronize em partes.",
  invalidCursor: "Cursor inválido.",
  routeNotFound: "Rota não encontrada.",
  serverError: "Ocorreu um erro. Tente novamente.",
  planWebOnly: "Seu plano é Web: entre pelo navegador ou mude para um plano com os apps.",
  deviceLimit: { one: "Sua licença permite {count} dispositivo. Libere um pela web ou fale com o suporte.", other: "Sua licença permite {count} dispositivos. Libere um pela web ou fale com o suporte." },
  deviceConflict: "Este dispositivo está registrado em outra empresa.",
  badCredentials: "E-mail ou senha incorretos.",
  userInactive: "Seu usuário está desativado. Fale com o administrador.",
  tenantNotFound: "A empresa não existe mais.",
  licenceSuspendedLogin: "A licença da sua empresa está suspensa. Fale com o suporte.",
  inviteInvalid: "Este link já foi usado ou expirou. Peça um novo.",
  emailTaken: "Já existe um usuário com esse e-mail.",
  companyNotFound: "Empresa não encontrada.",
  deviceNotFound: "Dispositivo não encontrado ou já liberado.",
  userNotFound: "Usuário não encontrado.",
  licenceExpiredReadOnly: "Sua licença venceu: os dados estão somente para leitura.",
  licenceSuspended: "Sua licença está suspensa.",
  roleForbidden: "Seu cargo não permite esta alteração.",
  changeWithoutData: "Alteração sem dados.",
  stale: "Existe uma versão mais recente.",
  plantLimit: { one: "Seu plano permite {count} unidade.", other: "Seu plano permite {count} unidades." },
  userOtherCompany: "Esse usuário pertence a outra empresa.",
  cannotRemoveSelf: "Você não pode desativar nem excluir o seu próprio usuário.",
  invalidUserData: "Dados de usuário inválidos.",
  userLimit: { one: "Seu plano permite {count} usuário ativo.", other: "Seu plano permite {count} usuários ativos." },
};

export const MESSAGES: Record<Lang, Dictionary> = { es, en, pt };

export type Params = Record<string, string | number>;

export const isLang = (value: unknown): value is Lang => typeof value === "string" && (LANGS as readonly string[]).includes(value);

/** Picks es/en/pt from an Accept-Language header (honoring q-values); Spanish otherwise. */
export function langFrom(header: string | null | undefined): Lang {
  if (!header) return DEFAULT_LANG;
  const ranked = header
    .split(",")
    .map((part, index) => {
      const [tag, ...attrs] = part.trim().split(";");
      const q = attrs.map((a) => /^\s*q=([\d.]+)\s*$/.exec(a)).find(Boolean);
      return { base: tag.trim().toLowerCase().split("-")[0], q: q ? Number(q[1]) : 1, index };
    })
    .filter((x) => x.base && x.q > 0)
    .sort((a, b) => b.q - a.q || a.index - b.index);
  const match = ranked.find((x) => isLang(x.base));
  return match ? (match.base as Lang) : DEFAULT_LANG;
}

/** Translates a message key, choosing the plural form from `params.count`. */
export function msg(lang: Lang, key: MessageKey, params: Params = {}): string {
  const entry = MESSAGES[lang][key] ?? MESSAGES[DEFAULT_LANG][key];
  const text = typeof entry === "string" ? entry : new Intl.PluralRules(LOCALE[lang]).select(Number(params.count ?? 0)) === "one" ? entry.one : entry.other;
  return text.replace(/\{(\w+)\}/g, (match, name: string) => (name in params ? String(params[name]) : match));
}
