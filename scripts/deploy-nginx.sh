#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
docker compose pull
docker compose up -d
docker exec profitability-nginx nginx -t
docker exec profitability-nginx nginx -s reload
echo "nginx deployed"
