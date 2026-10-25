import react from "@vitejs/plugin-react";
import { defineConfig } from "vite";

// Web app + admin portal SPA. The Vite root is web/; the build lands in platform/dist, which
// Vercel serves as static output next to the api/ function (see vercel.json).
export default defineConfig({
  root: "web",
  publicDir: "public",
  plugins: [react()],
  build: { outDir: "../dist", emptyOutDir: true, sourcemap: false, chunkSizeWarningLimit: 900 },
  server: {
    port: Number(process.env.WEB_PORT ?? 5173),
    proxy: { "/api": { target: process.env.API_PROXY ?? "http://localhost:8787", changeOrigin: false } },
  },
  preview: {
    proxy: { "/api": { target: process.env.API_PROXY ?? "http://localhost:8787", changeOrigin: false } },
  },
});
