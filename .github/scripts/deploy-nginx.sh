#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${SOURCE_ARCHIVE_URL:-}" && -z "${NGINX_ARCHIVE:-}" ]]; then
  echo "SOURCE_ARCHIVE_URL or NGINX_ARCHIVE is required" >&2
  exit 2
fi

if ! command -v docker >/dev/null 2>&1 || ! docker compose version >/dev/null 2>&1; then
  echo "Docker Engine and the Compose plugin must be installed before deployment" >&2
  exit 2
fi

deployment_directory=/opt/aiinc/nginx
install -d -m 0755 "$deployment_directory"

if [[ -n "${SOURCE_ARCHIVE_URL:-}" ]]; then
  case "$SOURCE_ARCHIVE_URL" in
    https://github.com/Technogoals/terraform/archive/*.tar.gz) ;;
    *)
      echo "SOURCE_ARCHIVE_URL is not an approved repository archive" >&2
      exit 2
      ;;
  esac

  source_archive="$(mktemp)"
  trap 'rm -f "$source_archive"' EXIT
  curl --fail --silent --show-error --location \
    "$SOURCE_ARCHIVE_URL" --output "$source_archive"
  archive_root="$(tar -tzf "$source_archive" | sed -n '1p')"
  if [[ ! "$archive_root" =~ ^terraform-[0-9a-f]+/$ ]]; then
    echo "The repository archive has an unexpected root directory" >&2
    exit 2
  fi
  tar -xzf "$source_archive" --strip-components=2 \
    -C "$deployment_directory" "${archive_root}nginx"
else
  printf '%s' "$NGINX_ARCHIVE" | base64 --decode \
    | tar -xz -C "$deployment_directory"
fi

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
