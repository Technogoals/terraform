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
docker compose config --quiet
docker compose pull
docker compose up -d --remove-orphans

for attempt in {1..12}; do
  if curl --fail --silent --show-error http://127.0.0.1/healthz >/dev/null; then
    docker compose ps
    exit 0
  fi
  sleep 5
done

docker compose logs --tail=100
exit 1
