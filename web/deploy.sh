#!/usr/bin/env bash
# Builds the site (web/build.py -> web/public/) and publishes web/public/ to the static
# Hugging Face Space ranabtawi/trama (https://ranabtawi-trama.static.hf.space). Needs `hf auth login` once.
# CI does the same on pushes to main (.github/workflows/deploy-web.yml).
# Only web/public/ is uploaded; web/src/, build.py and this script never reach the Space.
set -euo pipefail
cd "$(dirname "$0")"
python3 build.py
space="${HF_SPACE:-ranabtawi/trama}"
host="https://$(echo "$space" | tr '/' '-').static.hf.space"
hf repos create "$space" --type space --sdk static --exist-ok >/dev/null
hf upload "$space" public . --repo-type space --delete "*" --commit-message "Publish website" >/dev/null
for path in /index.html /en/index.html /pt/index.html /styles.css /app.js /robots.txt /sitemap.xml /llms.txt /llms-full.txt /site.webmanifest /assets/og.jpg; do
  printf "%s %s\n" "$(curl -sL -o /dev/null -w '%{http_code}' "$host$path")" "$path"
done
echo "$host"
