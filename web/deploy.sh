#!/usr/bin/env bash
# Publishes web/ to the static Hugging Face Space ranabtawi/trama
# (https://ranabtawi-trama.static.hf.space). Needs `hf auth login` once.
# CI does the same on pushes to main (.github/workflows/deploy-web.yml).
set -euo pipefail
cd "$(dirname "$0")"
space="${HF_SPACE:-ranabtawi/trama}"
host="https://$(echo "$space" | tr '/' '-').static.hf.space"
out=$(mktemp -d)
trap 'rm -rf "$out"' EXIT
cp index.html styles.css app.js README.md robots.txt sitemap.xml llms.txt llms-full.txt site.webmanifest "$out"/
cp -R assets "$out"/assets
hf repos create "$space" --type space --sdk static --exist-ok >/dev/null
hf upload "$space" "$out" . --repo-type space --delete "*" --commit-message "Publish website" >/dev/null
for path in / /styles.css /app.js /robots.txt /sitemap.xml /llms.txt /llms-full.txt /site.webmanifest /assets/og.jpg; do
  printf "%s %s\n" "$(curl -sL -o /dev/null -w '%{http_code}' "$host$path")" "$path"
done
echo "$host"
