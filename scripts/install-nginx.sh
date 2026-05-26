#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SITE_NAME="profitability"
SOURCE="$REPO_ROOT/nginx/profitability.conf"
TARGET="/etc/nginx/sites-available/$SITE_NAME.conf"

if [[ ! -f "$SOURCE" ]]; then
  echo "Config not found: $SOURCE" >&2
  exit 1
fi

sudo cp "$SOURCE" "$TARGET"
sudo ln -sf "$TARGET" "/etc/nginx/sites-enabled/$SITE_NAME.conf"
sudo nginx -t
sudo systemctl reload nginx

echo "Installed $TARGET and reloaded nginx."
