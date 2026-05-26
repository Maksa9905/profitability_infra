#!/usr/bin/env bash
# Настраивает автообновление Let's Encrypt на VPS (один раз, с sudo).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOK_DIR="/etc/letsencrypt/renewal-hooks/deploy"
HOOK_SCRIPT="$REPO_ROOT/scripts/certbot-deploy-hook.sh"
RENEW_CONF="/etc/letsencrypt/renewal/profit.hakolr.dev.conf"

if [[ ! -f "$RENEW_CONF" ]]; then
  echo "Сначала выполните init-letsencrypt.sh" >&2
  exit 1
fi

chmod +x "$HOOK_SCRIPT"

sudo mkdir -p "$HOOK_DIR"
sudo cp "$HOOK_SCRIPT" "$HOOK_DIR/reload-nginx.sh"
sudo chmod +x "$HOOK_DIR/reload-nginx.sh"

# webroot — продление без остановки nginx
if ! sudo grep -q 'webroot_path' "$RENEW_CONF" 2>/dev/null; then
  echo "Добавьте в renewal-конфиг certbot webroot (или перевыпустите с --webroot)." >&2
  echo "Рекомендуемый renew на VPS (cron/timer уже есть у certbot):" >&2
  echo "  sudo certbot renew --webroot -w $REPO_ROOT/certbot/www" >&2
fi

sudo systemctl enable certbot.timer 2>/dev/null || true
sudo systemctl start certbot.timer 2>/dev/null || true

echo "Timer certbot:"
systemctl status certbot.timer --no-pager 2>/dev/null || sudo certbot renew --dry-run
