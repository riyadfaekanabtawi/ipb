// Post-build step: the platform domain also serves the sales landing. Moves the SPA entry to
// dist/app.html (vercel.json rewrites the app routes to it) and copies web/public into dist so
// "/" is the landing. Fails loudly if the landing is missing or a file would be overwritten.
import { cpSync, existsSync, readdirSync, renameSync, statSync } from "node:fs";
import { dirname, join, relative } from "node:path";
import { fileURLToPath } from "node:url";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const dist = join(root, "dist");
const landing = join(root, "..", "web", "public");
const SKIP = new Set(["README.md"]); // Hugging Face Space card

if (!existsSync(join(landing, "index.html"))) {
  console.error(`merge-landing: ${landing}/index.html not found (is the repo root available to the build?)`);
  process.exit(1);
}
renameSync(join(dist, "index.html"), join(dist, "app.html"));

function copy(dir) {
  for (const name of readdirSync(dir)) {
    const src = join(dir, name);
    const rel = relative(landing, src);
    if (SKIP.has(rel)) continue;
    const dest = join(dist, rel);
    if (statSync(src).isDirectory()) {
      copy(src);
    } else if (existsSync(dest)) {
      console.error(`merge-landing: ${rel} exists in both the web app and the landing`);
      process.exit(1);
    } else {
      cpSync(src, dest);
    }
  }
}
copy(landing);
console.log("merge-landing: landing copied into dist, web app entry at dist/app.html");
