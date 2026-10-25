import nodemailer, { type Transporter } from "nodemailer";
import { config } from "./config.js";
import { renderEmail } from "./email-layout.js";
import { DEFAULT_LANG, LOCALE, type Lang } from "./i18n.js";

// Transactional email through Gmail SMTP (same setup as contact-api). When credentials are
// missing (local dev, tests) messages are captured in `outbox` instead of sent.

export interface Mail {
  to: string;
  subject: string;
  text: string;
  html?: string;
}

export const outbox: Mail[] = [];

let transport: Transporter | undefined;

export async function sendMail(mail: Mail): Promise<void> {
  if (!config.gmailUser || !config.gmailPassword) {
    outbox.push(mail);
    return;
  }
  transport ??= nodemailer.createTransport({
    host: "smtp.gmail.com",
    port: 465,
    secure: true,
    auth: { user: config.gmailUser, pass: config.gmailPassword },
  });
  await transport.sendMail({ from: `Trama <${config.gmailUser}>`, ...mail });
}

const PLAN_NAMES: Record<string, string> = { web: "Web", planta: "Planta", multiplanta: "Multiplanta", empresa: "Empresa" };
const date = (d: Date, lang: Lang) => d.toLocaleDateString(LOCALE[lang], { day: "numeric", month: "long", year: "numeric", timeZone: "America/Mexico_City" });

export interface InviteDetails {
  plan?: string;
  expiresAt?: Date;
  email?: string;
}

// Copy for the customer-facing emails (company invitation and password reset), per language.
// The platform-admin email is internal and stays in Spanish.
interface Copy {
  tagline: string;
  linkHint: string;
  hello: (first: string) => string;
  reset: {
    subject: string;
    text: (link: string) => string[];
    preheader: string;
    eyebrow: string;
    title: string;
    intro: (first: string, company: string | null) => string[];
    button: string;
    notice: string;
    reason: string;
  };
  invite: {
    subject: (company: string | null) => string;
    text: (company: string | null, link: string) => string[];
    preheader: (company: string | null) => string;
    eyebrow: string;
    title: (first: string) => string;
    intro: (company: string | null) => string;
    button: string;
    rows: { company: string; plan: string; validUntil: string; user: string; role: string; admin: string };
    licenceTitle: string;
    stepsTitle: string;
    steps: (email: string | null) => { title: string; body: string }[];
    notice: string;
    reason: string;
  };
}

const COPY: Record<Lang, Copy> = {
  es: {
    tagline: "Control de producción textil",
    linkHint: "¿El botón no funciona? Copia este enlace en tu navegador:",
    hello: (first) => `Hola ${first}:`,
    reset: {
      subject: "Restablece tu contraseña · Trama",
      text: (link) => ["Recibimos una solicitud para restablecer tu contraseña de Trama.", `Crea una nueva aquí (válido 72 horas): ${link}`, "", "Si no fuiste tú, ignora este correo."],
      preheader: "Crea una nueva contraseña para tu cuenta de Trama. El enlace vale 72 horas.",
      eyebrow: "Seguridad de tu cuenta",
      title: "Restablece tu contraseña",
      intro: (first, company) => [`Hola ${first}, recibimos una solicitud para cambiar la contraseña de tu cuenta${company ? ` en ${company}` : ""}.`, "Crea una nueva con el botón. Por seguridad, el enlace vale 72 horas y solo se puede usar una vez."],
      button: "Crear nueva contraseña",
      notice: "Al cambiarla, se cerrará la sesión en tus otros dispositivos. Si no fuiste tú, ignora este correo: tu contraseña actual sigue funcionando.",
      reason: "Recibiste este correo porque alguien pidió restablecer la contraseña de esta cuenta de Trama.",
    },
    invite: {
      subject: (company) => `Bienvenido a Trama · Activa la cuenta de ${company ?? "tu empresa"}`,
      text: (company, link) => [
        `${company ?? "Tu empresa"} ya tiene su licencia de Trama y eres su administrador.`,
        `Activa tu cuenta y define tu contraseña aquí (válido 72 horas): ${link}`, "",
        "Después podrás entrar desde la web o iniciar sesión en las apps de iPad y Android con el mismo correo.",
      ],
      preheader: (company) => `${company ?? "Tu empresa"} ya tiene su licencia. Activa tu cuenta de administrador.`,
      eyebrow: "Tu licencia está lista",
      title: (first) => `Bienvenido a Trama, ${first}`,
      intro: (company) => `${company ?? "Tu empresa"} ya tiene su licencia y tú eres su administrador. Activa tu cuenta para empezar a controlar cortes, plantas y envíos desde un solo lugar.`,
      button: "Activar mi cuenta",
      rows: { company: "Empresa", plan: "Plan", validUntil: "Licencia vigente hasta", user: "Tu usuario", role: "Tu puesto", admin: "Administrador" },
      licenceTitle: "Tu licencia",
      stepsTitle: "Para empezar",
      steps: (email) => [
        { title: "Activa tu cuenta", body: "Define tu contraseña con el botón de arriba (el enlace vale 72 horas)." },
        { title: "Entra desde donde trabajes", body: `En la web, o en el iPad y Android con «Conectar con mi licencia» usando ${email ?? "este correo"}.` },
        { title: "Suma a tu equipo", body: "En Usuarios crea a tus gerentes de cortes, planta y envíos; cada quien ve solo lo suyo." },
      ],
      notice: "Las apps de iPad y Android funcionan sin internet y se sincronizan solas cuando vuelve la conexión. Tus datos viajan y se guardan cifrados.",
      reason: "Recibiste este correo porque tu empresa contrató una licencia de Trama y te registró como administrador.",
    },
  },
  en: {
    tagline: "Apparel production control",
    linkHint: "Button not working? Paste this link into your browser:",
    hello: (first) => `Hi ${first},`,
    reset: {
      subject: "Reset your password · Trama",
      text: (link) => ["We received a request to reset your Trama password.", `Create a new one here (valid for 72 hours): ${link}`, "", "If this wasn't you, ignore this email."],
      preheader: "Create a new password for your Trama account. The link is valid for 72 hours.",
      eyebrow: "Account security",
      title: "Reset your password",
      intro: (first, company) => [`Hi ${first}, we received a request to change the password of your account${company ? ` at ${company}` : ""}.`, "Use the button to create a new one. For your security, the link is valid for 72 hours and works only once."],
      button: "Create a new password",
      notice: "Changing it signs you out of your other devices. If this wasn't you, ignore this email: your current password still works.",
      reason: "You received this email because someone asked to reset the password of this Trama account.",
    },
    invite: {
      subject: (company) => `Welcome to Trama · Activate the ${company ?? "company"} account`,
      text: (company, link) => [
        `${company ?? "Your company"} now has a Trama license and you are its administrator.`,
        `Activate your account and set your password here (valid for 72 hours): ${link}`, "",
        "Then sign in on the web, or in the iPad and Android apps with the same email.",
      ],
      preheader: (company) => `${company ?? "Your company"} now has its license. Activate your administrator account.`,
      eyebrow: "Your license is ready",
      title: (first) => `Welcome to Trama, ${first}`,
      intro: (company) => `${company ?? "Your company"} now has its license and you are its administrator. Activate your account to start managing cuts, plants and shipments in one place.`,
      button: "Activate my account",
      rows: { company: "Company", plan: "Plan", validUntil: "License valid until", user: "Your user", role: "Your role", admin: "Administrator" },
      licenceTitle: "Your license",
      stepsTitle: "Getting started",
      steps: (email) => [
        { title: "Activate your account", body: "Set your password with the button above (the link is valid for 72 hours)." },
        { title: "Sign in wherever you work", body: `On the web, or on iPad and Android with “Connect with my license” using ${email ?? "this email"}.` },
        { title: "Bring in your team", body: "In Users, add your cutting, plant and shipping managers; each one sees only their own work." },
      ],
      notice: "The iPad and Android apps work offline and sync on their own when the connection is back. Your data is encrypted in transit and at rest.",
      reason: "You received this email because your company purchased a Trama license and registered you as its administrator.",
    },
  },
  pt: {
    tagline: "Controle de produção de confecção",
    linkHint: "O botão não funciona? Copie este link no seu navegador:",
    hello: (first) => `Olá, ${first}!`,
    reset: {
      subject: "Redefina sua senha · Trama",
      text: (link) => ["Recebemos um pedido para redefinir sua senha do Trama.", `Crie uma nova aqui (válido por 72 horas): ${link}`, "", "Se não foi você, ignore este e-mail."],
      preheader: "Crie uma nova senha para sua conta do Trama. O link vale por 72 horas.",
      eyebrow: "Segurança da sua conta",
      title: "Redefina sua senha",
      intro: (first, company) => [`Olá, ${first}. Recebemos um pedido para alterar a senha da sua conta${company ? ` na ${company}` : ""}.`, "Crie uma nova pelo botão. Por segurança, o link vale por 72 horas e só pode ser usado uma vez."],
      button: "Criar nova senha",
      notice: "Ao alterá-la, a sessão será encerrada nos seus outros dispositivos. Se não foi você, ignore este e-mail: sua senha atual continua valendo.",
      reason: "Você recebeu este e-mail porque alguém pediu para redefinir a senha desta conta do Trama.",
    },
    invite: {
      subject: (company) => `Bem-vindo ao Trama · Ative a conta da ${company ?? "sua empresa"}`,
      text: (company, link) => [
        `${company ?? "Sua empresa"} já tem a licença do Trama e você é o administrador.`,
        `Ative sua conta e defina sua senha aqui (válido por 72 horas): ${link}`, "",
        "Depois, entre pela web ou nos apps para iPad e Android com o mesmo e-mail.",
      ],
      preheader: (company) => `${company ?? "Sua empresa"} já tem a licença. Ative sua conta de administrador.`,
      eyebrow: "Sua licença está pronta",
      title: (first) => `Bem-vindo ao Trama, ${first}`,
      intro: (company) => `${company ?? "Sua empresa"} já tem a licença e você é o administrador. Ative sua conta para começar a controlar cortes, unidades e expedições em um só lugar.`,
      button: "Ativar minha conta",
      rows: { company: "Empresa", plan: "Plano", validUntil: "Licença válida até", user: "Seu usuário", role: "Seu cargo", admin: "Administrador" },
      licenceTitle: "Sua licença",
      stepsTitle: "Para começar",
      steps: (email) => [
        { title: "Ative sua conta", body: "Defina sua senha com o botão acima (o link vale por 72 horas)." },
        { title: "Entre de onde você trabalha", body: `Na web, ou no iPad e Android com “Conectar com minha licença” usando ${email ?? "este e-mail"}.` },
        { title: "Traga sua equipe", body: "Em Usuários, cadastre os gerentes de corte, de unidade e de expedição; cada um vê só o que é seu." },
      ],
      notice: "Os apps para iPad e Android funcionam sem internet e sincronizam sozinhos quando a conexão volta. Seus dados trafegam e ficam guardados criptografados.",
      reason: "Você recebeu este e-mail porque sua empresa contratou uma licença do Trama e cadastrou você como administrador.",
    },
  },
};

export function inviteEmail(
  kind: "invite" | "reset" | "platform_admin",
  name: string,
  company: string | null,
  link: string,
  details: InviteDetails = {},
  lang: Lang = DEFAULT_LANG,
): Mail & { to: "" } {
  const first = name.split(/\s+/)[0] || name;
  // The platform-admin email is internal: always Spanish.
  const l: Lang = kind === "platform_admin" ? "es" : lang;
  const copy = COPY[l];
  const footer = { tagline: copy.tagline, reason: "" };
  const linkHint = copy.linkHint;
  let subject: string;
  let text: string[];
  let html: string;

  if (kind === "reset") {
    const c = copy.reset;
    subject = c.subject;
    text = [copy.hello(first), "", ...c.text(link)];
    html = renderEmail({
      lang: l,
      preheader: c.preheader,
      eyebrow: c.eyebrow,
      title: c.title,
      intro: c.intro(first, company),
      button: { label: c.button, url: link },
      linkHint,
      sections: [{ type: "notice", text: c.notice }],
      footer: { ...footer, reason: c.reason },
    });
  } else if (kind === "platform_admin") {
    subject = "Tu acceso de administrador · Trama";
    text = [`Hola ${first}:`, "", "Se creó tu acceso al portal de administración de Trama.", `Define tu contraseña aquí (válido 72 horas): ${link}`];
    html = renderEmail({
      preheader: "Define tu contraseña para entrar al portal de administración de Trama.",
      eyebrow: "Portal de administración",
      title: `Bienvenido al panel, ${first}`,
      intro: ["Se creó tu acceso al portal de administración de Trama. Desde ahí das de alta empresas, asignas planes y licencias, y controlas usuarios y dispositivos."],
      button: { label: "Definir mi contraseña", url: link },
      linkHint,
      sections: [
        {
          type: "steps",
          title: "Desde el portal puedes",
          items: [
            { title: "Dar de alta empresas", body: "Elige el plan y la vigencia; su administrador recibe la invitación al instante." },
            { title: "Renovar, cambiar plan o suspender", body: "Los límites de usuarios, dispositivos y plantas se aplican en todas las apps." },
            { title: "Liberar dispositivos", body: "Revoca un iPad o Android perdido y libera su lugar en la licencia." },
          ],
        },
        { type: "notice", text: "El enlace vale 72 horas y solo se puede usar una vez." },
      ],
      footer: { ...footer, reason: "Recibiste este correo porque se creó un acceso de administrador de Trama con esta dirección." },
    });
  } else {
    const c = copy.invite;
    subject = c.subject(company);
    text = [copy.hello(first), "", ...c.text(company, link)];
    const rows: [string, string][] = [[c.rows.company, company ?? "—"]];
    if (details.plan) rows.push([c.rows.plan, PLAN_NAMES[details.plan] ?? details.plan]);
    if (details.expiresAt) rows.push([c.rows.validUntil, date(details.expiresAt, l)]);
    if (details.email) rows.push([c.rows.user, details.email]);
    rows.push([c.rows.role, c.rows.admin]);
    html = renderEmail({
      lang: l,
      preheader: c.preheader(company),
      eyebrow: c.eyebrow,
      title: c.title(first),
      intro: [c.intro(company)],
      button: { label: c.button, url: link },
      linkHint,
      sections: [
        { type: "details", title: c.licenceTitle, rows },
        { type: "steps", title: c.stepsTitle, items: c.steps(details.email ?? null) },
        { type: "notice", text: c.notice },
      ],
      footer: { ...footer, reason: c.reason },
    });
  }
  return { to: "", subject, text: [...text, "", `Trama · ${copy.tagline}`].join("\n"), html };
}
