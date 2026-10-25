# contact-api

Serverless endpoint behind the website's "Solicitar licencia" form. It emails each request to the
Trama inbox through **Gmail SMTP** (same approach as CardioAlert) and sends the lead an automatic
confirmation. Runs on Vercel (Node runtime), so it never sleeps and costs nothing at this volume.

`POST /api/contact` with JSON `{ nombre, empresa, correo, telefono?, plantas, plan, mensaje?, startedAt, website }`.

Protections:
- origin allow-list;
- a honeypot field (`website`) and a 2.5 s minimum fill time, which drop bots silently;
- a per-IP rate limit (5 per 10 min);
- validation and length limits, and HTML-escaped email bodies.

## Setup (once)

1. **Gmail app password.** Turn on 2-Step Verification on the Google account, then create a password at
   <https://myaccount.google.com/apppasswords> named "Trama web". It is 16 characters.
2. **Vercel project.** Go to Vercel → Add New → Project → import this GitHub repo and set **Root Directory: `contact-api`**.
   Leave the framework as "Other".
3. **Environment variables** (Production):
   | Name | Value |
   |---|---|
   | `GMAIL_USER` | the Gmail address that sends (e.g. riyad.faek@gmail.com) |
   | `GMAIL_APP_PASSWORD` | the 16-character app password |
   | `CONTACT_TO` | where leads arrive (optional; defaults to `GMAIL_USER`) |
   | `ALLOWED_ORIGINS` | optional comma list; defaults to the Hugging Face Space origins |
4. Deploy, then put the URL into `web/index.html`:
   `<meta name="trama-contact-endpoint" content="https://<project>.vercel.app/api/contact">`
   and publish the site (`web/deploy.sh`). Until this is set, the form falls back to a prefilled email.

## Develop

```bash
cd contact-api && npm install && npm test
```
