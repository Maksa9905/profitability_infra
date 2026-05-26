#!/usr/bin/env bash
# Вызывается после успешного certbot renew (см. setup-certbot-renew.sh).
set -euo pipefail
docker exec profitability-nginx nginx -s reload
