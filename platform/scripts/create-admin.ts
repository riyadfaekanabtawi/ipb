// Creates a platform admin and prints a one-time link to set the password (also emailed
// when GMAIL_* is configured). Usage: DATABASE_URL=... APP_URL=... npm run create-admin -- email "Name"
import { closeDb, db } from "../src/db.js";
import { inviteEmail, sendMail } from "../src/mail.js";
import { createInvite } from "../src/routes/auth.js";

const [email, name = "Administrador"] = process.argv.slice(2);
if (!email) {
  console.error('Usage: npm run create-admin -- <email> "<name>"');
  process.exit(1);
}
const { rows } = await db().query<{ id: string }>(
  "INSERT INTO platform_admins (email, name) VALUES (lower($1), $2) ON CONFLICT (email) DO UPDATE SET name = EXCLUDED.name RETURNING id",
  [email, name],
);
const link = await createInvite("platform_admin", { adminId: rows[0].id });
await sendMail({ ...inviteEmail("platform_admin", name, null, link), to: email });
console.log(`Admin ${email} ready. Set the password here (valid 72 h):\n${link}`);
await closeDb();
