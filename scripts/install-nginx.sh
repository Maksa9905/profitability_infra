#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SITE_NAME="profitability"
SOURCE="$REPO_ROOT/nginx/profitability.conf"

if [[ ! -f "$SOURCE" ]]; then
  echo "Config not found: $SOURCE" >&2
  exit 1
fi

if ! command -v nginx >/dev/null 2>&1; then
  echo "nginx is not installed." >&2
  echo "On Ubuntu/Debian: sudo apt update && sudo apt install -y nginx" >&2
  exit 1
fi

if [[ ! -d /etc/nginx ]]; then
  echo "/etc/nginx not found. Install nginx first." >&2
  exit 1
fi

run_as_root() {
  if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
    "$@"
  else
    sudo "$@"
  fi
}

SITES_AVAILABLE="/etc/nginx/sites-available"
SITES_ENABLED="/etc/nginx/sites-enabled"
CONF_D="/etc/nginx/conf.d"

if [[ -d "$SITES_AVAILABLE" ]] || [[ -d "$SITES_ENABLED" ]]; then
  run_as_root mkdir -p "$SITES_AVAILABLE" "$SITES_ENABLED"
  TARGET="$SITES_AVAILABLE/$SITE_NAME.conf"
  run_as_root cp "$SOURCE" "$TARGET"
  run_as_root ln -sf "$TARGET" "$SITES_ENABLED/$SITE_NAME.conf"
elif [[ -d "$CONF_D" ]]; then
  TARGET="$CONF_D/$SITE_NAME.conf"
  run_as_root cp "$SOURCE" "$TARGET"
else
  run_as_root mkdir -p "$CONF_D"
  TARGET="$CONF_D/$SITE_NAME.conf"
  run_as_root cp "$SOURCE" "$TARGET"
fi

NGINX_CONF="/etc/nginx/nginx.conf"
if [[ -d "$SITES_ENABLED" ]] && ! grep -q 'sites-enabled' "$NGINX_CONF"; then
  echo "Warning: $NGINX_CONF does not include sites-enabled/*." >&2
  echo "Add this line inside the http { ... } block:" >&2
  echo "    include /etc/nginx/sites-enabled/*;" >&2
fi

run_as_root nginx -t
run_as_root systemctl enable nginx 2>/dev/null || true
if run_as_root systemctl is-active nginx >/dev/null 2>&1; then
  run_as_root systemctl reload nginx
else
  run_as_root systemctl start nginx
fi

echo "Installed $TARGET and reloaded nginx."
