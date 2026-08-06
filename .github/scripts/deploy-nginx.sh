#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${NGINX_ARCHIVE:-}" ]]; then
  echo "NGINX_ARCHIVE is required" >&2
  exit 2
fi

deployment_directory=/opt/aiinc/nginx
install -d -m 0755 "$deployment_directory"
printf '%s' "$NGINX_ARCHIVE" | base64 --decode | tar -xz -C "$deployment_directory"

cd "$deployment_directory"

umask 077
if [[ ! -f .env ]]; then
  grafana_password="$(openssl rand -hex 16)"
  prometheus_password="$(openssl rand -hex 16)"
  printf 'GRAFANA_ADMIN_PASSWORD=%s\nPROMETHEUS_PASSWORD=%s\n' \
    "$grafana_password" "$prometheus_password" > .env
fi

set -a
# shellcheck disable=SC1091
source .env
set +a

if [[ -z "${GRAFANA_ADMIN_PASSWORD:-}" || -z "${PROMETHEUS_PASSWORD:-}" ]]; then
  echo "The deployment credential file is incomplete" >&2
  exit 2
fi

printf 'admin:%s\n' "$(openssl passwd -apr1 "$PROMETHEUS_PASSWORD")" \
  > prometheus.htpasswd

docker compose config --quiet
docker compose pull
docker compose up -d --remove-orphans

for attempt in {1..12}; do
  if curl --fail --silent http://127.0.0.1/healthz >/dev/null \
    && curl --fail --silent http://127.0.0.1/grafana/api/health >/dev/null \
    && curl --fail --silent --user "admin:$PROMETHEUS_PASSWORD" \
      http://127.0.0.1/prometheus/-/healthy >/dev/null; then
    docker compose ps
    exit 0
  fi
  sleep 5
done

docker compose logs --tail=100
exit 1
