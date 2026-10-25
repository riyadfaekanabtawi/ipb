import nodemailer, { type Transporter } from "nodemailer";
import { config } from "./config.js";
import { renderEmail } from "./email-layout.js";

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
const date = (d: Date) => d.toLocaleDateString("es-MX", { day: "numeric", month: "long", year: "numeric", timeZone: "America/Mexico_City" });

export interface InviteDetails {
  plan?: string;
  expiresAt?: Date;
  email?: string;
}

export function inviteEmail(
  kind: "invite" | "reset" | "platform_admin",
  name: string,
  company: string | null,
  link: string,
  details: InviteDetails = {},
): Mail & { to: "" } {
  const first = name.split(/\s+/)[0] || name;
  const footer = { tagline: "Control de producción textil", reason: "" };
  const linkHint = "¿El botón no funciona? Copia este enlace en tu navegador:";
  let subject: string;
  let text: string[];
  let html: string;

  if (kind === "reset") {
    subject = "Restablece tu contraseña · Trama";
    text = [`Hola ${first}:`, "", "Recibimos una solicitud para restablecer tu contraseña de Trama.", `Crea una nueva aquí (válido 72 horas): ${link}`, "", "Si no fuiste tú, ignora este correo."];
    html = renderEmail({
      preheader: "Crea una nueva contraseña para tu cuenta de Trama. El enlace vale 72 horas.",
      eyebrow: "Seguridad de tu cuenta",
      title: "Restablece tu contraseña",
      intro: [`Hola ${first}, recibimos una solicitud para cambiar la contraseña de tu cuenta${company ? ` en ${company}` : ""}.`, "Crea una nueva con el botón. Por seguridad, el enlace vale 72 horas y solo se puede usar una vez."],
      button: { label: "Crear nueva contraseña", url: link },
      linkHint,
      sections: [
        { type: "notice", text: "Al cambiarla, se cerrará la sesión en tus otros dispositivos. Si no fuiste tú, ignora este correo: tu contraseña actual sigue funcionando." },
      ],
      footer: { ...footer, reason: "Recibiste este correo porque alguien pidió restablecer la contraseña de esta cuenta de Trama." },
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
    subject = `Bienvenido a Trama · Activa la cuenta de ${company ?? "tu empresa"}`;
    text = [
      `Hola ${first}:`, "",
      `${company ?? "Tu empresa"} ya tiene su licencia de Trama y eres su administrador.`,
      `Activa tu cuenta y define tu contraseña aquí (válido 72 horas): ${link}`, "",
      "Después podrás entrar desde la web o iniciar sesión en las apps de iPad y Android con el mismo correo.",
    ];
    const rows: [string, string][] = [["Empresa", company ?? "—"]];
    if (details.plan) rows.push(["Plan", PLAN_NAMES[details.plan] ?? details.plan]);
    if (details.expiresAt) rows.push(["Licencia vigente hasta", date(details.expiresAt)]);
    if (details.email) rows.push(["Tu usuario", details.email]);
    rows.push(["Tu puesto", "Administrador"]);
    html = renderEmail({
      preheader: `${company ?? "Tu empresa"} ya tiene su licencia. Activa tu cuenta de administrador.`,
      eyebrow: "Tu licencia está lista",
      title: `Bienvenido a Trama, ${first}`,
      intro: [`${company ?? "Tu empresa"} ya tiene su licencia y tú eres su administrador. Activa tu cuenta para empezar a controlar cortes, plantas y envíos desde un solo lugar.`],
      button: { label: "Activar mi cuenta", url: link },
      linkHint,
      sections: [
        { type: "details", title: "Tu licencia", rows },
        {
          type: "steps",
          title: "Para empezar",
          items: [
            { title: "Activa tu cuenta", body: "Define tu contraseña con el botón de arriba (el enlace vale 72 horas)." },
            { title: "Entra desde donde trabajes", body: `En la web, o en el iPad y Android con «Conectar con mi licencia» usando ${details.email ?? "este correo"}.` },
            { title: "Suma a tu equipo", body: "En Usuarios crea a tus gerentes de cortes, planta y envíos; cada quien ve solo lo suyo." },
          ],
        },
        { type: "notice", text: "Las apps de iPad y Android funcionan sin internet y se sincronizan solas cuando vuelve la conexión. Tus datos viajan y se guardan cifrados." },
      ],
      footer: { ...footer, reason: "Recibiste este correo porque tu empresa contrató una licencia de Trama y te registró como administrador." },
    });
  }
  return { to: "", subject, text: [...text, "", "Trama · Control de producción textil"].join("\n"), html };
}
