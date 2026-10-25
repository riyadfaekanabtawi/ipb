import nodemailer, { type Transporter } from "nodemailer";
import { config } from "./config.js";

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

export function inviteEmail(kind: "invite" | "reset" | "platform_admin", name: string, company: string | null, link: string): Mail & { to: "" } {
  const first = name.split(/\s+/)[0] || name;
  const lines =
    kind === "reset"
      ? [`Hola ${first}:`, "", "Recibimos una solicitud para restablecer tu contraseña de Trama.", `Crea una nueva aquí (válido 72 horas): ${link}`, "", "Si no fuiste tú, ignora este correo."]
      : kind === "platform_admin"
        ? [`Hola ${first}:`, "", "Se creó tu acceso al portal de administración de Trama.", `Define tu contraseña aquí (válido 72 horas): ${link}`]
        : [
            `Hola ${first}:`,
            "",
            `${company ?? "Tu empresa"} ya tiene su licencia de Trama y eres su administrador.`,
            `Activa tu cuenta y define tu contraseña aquí (válido 72 horas): ${link}`,
            "",
            "Después podrás entrar desde la web o iniciar sesión en las apps de iPad y Android con el mismo correo.",
          ];
  return {
    to: "",
    subject: kind === "reset" ? "Restablece tu contraseña · Trama" : kind === "platform_admin" ? "Tu acceso de administrador · Trama" : "Bienvenido a Trama · Activa tu cuenta",
    text: [...lines, "", "Trama · Control de producción textil"].join("\n"),
  };
}
