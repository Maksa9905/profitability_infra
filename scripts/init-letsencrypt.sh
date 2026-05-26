#!/usr/bin/env bash
# Первый выпуск сертификата Let's Encrypt (один раз на VPS).
# Требования: DNS A-записи profit и api.profit -> IP VPS; порт 80 свободен на время certbot.
#
# Использование (на VPS, нужен root — deploy без sudo не подойдёт):
#   export CERTBOT_EMAIL=you@example.com
#   ./scripts/init-letsencrypt.sh
#
# Под root: ssh root@VPS → cd .../profitability_infra → тот же export и скрипт.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

: "${CERTBOT_EMAIL:?Укажите email: export CERTBOT_EMAIL=you@example.com}"

run_as_root() {
  if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
    "$@"
  elif sudo -n true 2>/dev/null; then
    sudo "$@"
  else
    echo "Нужны права root (certbot пишет в /etc/letsencrypt)." >&2
    echo "Пользователь $(whoami) не в sudoers. Запустите под root:" >&2
    echo "  ssh root@<VPS>" >&2
    echo "  cd $REPO_ROOT" >&2
    echo "  export CERTBOT_EMAIL=$CERTBOT_EMAIL" >&2
    echo "  ./scripts/init-letsencrypt.sh" >&2
    exit 1
  fi
}

if ! command -v certbot >/dev/null 2>&1; then
  echo "Установите certbot (под root): apt update && apt install -y certbot" >&2
  exit 1
fi

mkdir -p certbot/www

echo "Останавливаем nginx (освобождаем порт 80 для standalone)..."
docker compose stop nginx 2>/dev/null || true

echo "Запрашиваем сертификат для profit.hakolr.dev и api.profit.hakolr.dev..."
run_as_root certbot certonly --standalone \
  -d profit.hakolr.dev \
  -d api.profit.hakolr.dev \
  --email "$CERTBOT_EMAIL" \
  --agree-tos \
  --no-eff-email \
  --non-interactive

echo "Запускаем nginx с Let's Encrypt..."
chmod +x scripts/deploy-nginx.sh scripts/setup-certbot-renew.sh
./scripts/deploy-nginx.sh

WEBROOT="$REPO_ROOT/certbot/www"
RENEW_CONF="/etc/letsencrypt/renewal/profit.hakolr.dev.conf"
echo "Переключаем продление на webroot (nginx не нужно останавливать)..."
run_as_root sed -i 's/^authenticator = standalone/authenticator = webroot/' "$RENEW_CONF"
if ! run_as_root grep -q '^webroot_path' "$RENEW_CONF"; then
  run_as_root sed -i "/^authenticator = webroot/a webroot_path = $WEBROOT," "$RENEW_CONF"
fi

./scripts/setup-certbot-renew.sh

echo "Готово. Проверка:"
echo "  curl -I https://profit.hakolr.dev"
echo "  certbot certificates   # под root"
echo "  certbot renew --dry-run"
