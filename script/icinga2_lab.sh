#!/bin/sh
set -eu

ROOT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
LAB_DIR="$ROOT_DIR/integration/icinga2"
ENV_FILE="$LAB_DIR/.env.local"

if [ ! -f "$ENV_FILE" ]; then
  printf 'Missing %s. Copy .env.example and set local values.\n' "$ENV_FILE" >&2
  exit 2
fi

set -a
# shellcheck source=/dev/null
. "$ENV_FILE"
set +a

: "${NAGBAR_ICINGA_BASIC_PASSWORD:?missing in .env.local}"
: "${NAGBAR_ICINGA_FORBIDDEN_PASSWORD:?missing in .env.local}"
: "${NAGBAR_ICINGA_PKCS12_PASSWORD:?missing in .env.local}"
: "${NAGBAR_ICINGA_PORT:=5665}"
: "${NAGBAR_ICINGA_ARTIFACTS_DIR:?missing in .env.local}"

compose() {
  docker compose --project-directory "$LAB_DIR" --env-file "$ENV_FILE" -f "$LAB_DIR/compose.yaml" "$@"
}

wait_for_api() {
  attempt=0
  while [ "$attempt" -lt 40 ]; do
    status=$(
      curl --silent --insecure --output /dev/null --write-out '%{http_code}' \
        --config - "https://localhost:$NAGBAR_ICINGA_PORT/v1/objects/hosts?attrs=name&limit=1" <<CURL_CONFIG || true
user = "nagbar-basic:$NAGBAR_ICINGA_BASIC_PASSWORD"
CURL_CONFIG
    )
    if [ "$status" = "200" ]; then
      return 0
    fi
    attempt=$((attempt + 1))
    sleep 1
  done

  printf 'Icinga 2 API did not become ready.\n' >&2
  compose logs --tail 100 icinga2 >&2
  return 1
}

generate_client_identity() {
  # The quoted script expands inside the container, not in this shell.
  # shellcheck disable=SC2016
  compose exec -T icinga2 sh -ceu '
    cert_dir=/data/var/lib/icinga2/certs/nagbar-client
    mkdir -p "$cert_dir"
    if [ ! -f "$cert_dir/nagbar-client.crt" ]; then
      icinga2 pki new-cert --cn nagbar-client --key "$cert_dir/nagbar-client.key" --csr "$cert_dir/nagbar-client.csr"
      icinga2 pki sign-csr --csr "$cert_dir/nagbar-client.csr" --cert "$cert_dir/nagbar-client.crt"
    fi
    openssl pkcs12 -export \
      -inkey "$cert_dir/nagbar-client.key" \
      -in "$cert_dir/nagbar-client.crt" \
      -certfile /data/var/lib/icinga2/certs/ca.crt \
      -out "$cert_dir/nagbar-client.p12" \
      -passout env:NAGBAR_ICINGA_PKCS12_PASSWORD
  '

  mkdir -p "$NAGBAR_ICINGA_ARTIFACTS_DIR"
  container_id=$(compose ps -q icinga2)
  docker cp "$container_id:/data/var/lib/icinga2/certs/ca.crt" "$NAGBAR_ICINGA_ARTIFACTS_DIR/ca.crt" >/dev/null
  docker cp "$container_id:/data/var/lib/icinga2/certs/nagbar-client/nagbar-client.p12" "$NAGBAR_ICINGA_ARTIFACTS_DIR/nagbar-client.p12" >/dev/null
  chmod 600 "$NAGBAR_ICINGA_ARTIFACTS_DIR/nagbar-client.p12"
}

request_status() {
  account=$1
  password=$2
  curl --silent --show-error --insecure --output /dev/null --write-out '%{http_code}' \
    --config - "https://localhost:$NAGBAR_ICINGA_PORT/v1/objects/hosts?attrs=name&limit=1" <<CURL_CONFIG
user = "$account:$password"
CURL_CONFIG
}

expect_status() {
  expected=$1
  actual=$2
  label=$3
  if [ "$actual" != "$expected" ]; then
    printf '%s: expected HTTP %s, got %s\n' "$label" "$expected" "$actual" >&2
    return 1
  fi
  printf '%s: HTTP %s\n' "$label" "$actual"
}

verify_matrix() {
  wait_for_api

  if curl --silent --output /dev/null \
    "http://localhost:$NAGBAR_ICINGA_PORT/v1/objects/hosts?attrs=name&limit=1" 2>/dev/null; then
    printf 'plain HTTP: expected transport rejection\n' >&2
    return 1
  fi
  printf 'plain HTTP: rejected\n'

  no_auth=$(curl --silent --show-error --insecure --output /dev/null --write-out '%{http_code}' \
    "https://localhost:$NAGBAR_ICINGA_PORT/v1/objects/hosts?attrs=name&limit=1")
  expect_status 401 "$no_auth" "no authentication"

  basic=$(request_status nagbar-basic "$NAGBAR_ICINGA_BASIC_PASSWORD")
  expect_status 200 "$basic" "basic authentication"

  wrong=$(request_status nagbar-basic wrong-local-password)
  expect_status 401 "$wrong" "wrong password"

  forbidden=$(request_status nagbar-forbidden "$NAGBAR_ICINGA_FORBIDDEN_PASSWORD")
  expect_status 403 "$forbidden" "missing permission"

  if curl --silent --output /dev/null --config - \
    "https://localhost:$NAGBAR_ICINGA_PORT/v1/objects/hosts?attrs=name&limit=1" 2>/dev/null <<CURL_CONFIG
user = "nagbar-basic:$NAGBAR_ICINGA_BASIC_PASSWORD"
CURL_CONFIG
  then
    printf 'untrusted private CA: expected TLS rejection\n' >&2
    return 1
  fi
  printf 'untrusted private CA: rejected\n'

  trusted=$(curl --silent --show-error --cacert "$NAGBAR_ICINGA_ARTIFACTS_DIR/ca.crt" \
    --output /dev/null --write-out '%{http_code}' --config - \
    "https://localhost:$NAGBAR_ICINGA_PORT/v1/objects/hosts?attrs=name&limit=1" <<CURL_CONFIG
user = "nagbar-basic:$NAGBAR_ICINGA_BASIC_PASSWORD"
CURL_CONFIG
  )
  expect_status 200 "$trusted" "private CA trust"

  mtls=$(curl --silent --show-error --insecure --output /dev/null --write-out '%{http_code}' \
    --cert-type P12 --cert "$NAGBAR_ICINGA_ARTIFACTS_DIR/nagbar-client.p12:$NAGBAR_ICINGA_PKCS12_PASSWORD" \
    "https://localhost:$NAGBAR_ICINGA_PORT/v1/objects/hosts?attrs=name&limit=1")
  expect_status 200 "$mtls" "client certificate"

  printf 'Icinga 2 integration matrix passed.\n'
}

case "${1:-}" in
  start)
    compose up -d
    wait_for_api
    generate_client_identity
    printf 'Icinga 2 lab is ready on https://localhost:%s.\n' "$NAGBAR_ICINGA_PORT"
    ;;
  verify)
    verify_matrix
    ;;
  status)
    compose ps
    ;;
  stop)
    compose down
    ;;
  clean)
    compose down --volumes
    ;;
  *)
    printf 'Usage: %s {start|verify|status|stop|clean}\n' "$0" >&2
    exit 2
    ;;
esac
