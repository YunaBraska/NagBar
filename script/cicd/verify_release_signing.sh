#!/bin/sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
MODE=local
REQUIRE_STAPLED=0
APP_PATH="$ROOT_DIR/build/Release/NagBar.app"

usage() {
  printf 'Usage: %s [--local|--developer-id] [--require-stapled] [APP_PATH]\n' "$0"
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --local)
      MODE=local
      ;;
    --developer-id)
      MODE=developer-id
      ;;
    --require-stapled)
      REQUIRE_STAPLED=1
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    -*)
      usage >&2
      exit 2
      ;;
    *)
      APP_PATH=$1
      ;;
  esac
  shift
done

if [ ! -d "$APP_PATH" ]; then
  printf 'Release app not found: %s\n' "$APP_PATH" >&2
  printf 'Build it first with: ./script/build_and_run.sh --release-build\n' >&2
  exit 1
fi

SIGNING_DETAILS=$(codesign -dvvv --entitlements :- "$APP_PATH" 2>&1 || true)
printf '%s\n' "$SIGNING_DETAILS"

if printf '%s\n' "$SIGNING_DETAILS" | grep -q "code object is not signed"; then
  printf 'Release app is not signed.\n' >&2
  exit 1
fi

if ! printf '%s\n' "$SIGNING_DETAILS" | grep -q "Executable="; then
  printf 'Unable to inspect release app signing details.\n' >&2
  printf 'codesign output did not contain a signed app report for: %s\n' "$APP_PATH" >&2
  exit 1
fi

if ! printf '%s\n' "$SIGNING_DETAILS" | grep -q "runtime"; then
  printf 'Release app is not signed with hardened runtime.\n' >&2
  exit 1
fi

if printf '%s\n' "$SIGNING_DETAILS" | grep -q "get-task-allow"; then
  printf 'Release app contains debug get-task-allow entitlement.\n' >&2
  exit 1
fi

if [ "$MODE" = "developer-id" ]; then
  if printf '%s\n' "$SIGNING_DETAILS" | grep -q "Signature=adhoc"; then
    printf 'Release app is locally/ad-hoc signed, not Developer ID signed.\n' >&2
    exit 1
  fi

  if ! printf '%s\n' "$SIGNING_DETAILS" | grep -q "Authority=Developer ID Application"; then
    printf 'Release app is not signed with a Developer ID Application identity.\n' >&2
    exit 1
  fi

  if printf '%s\n' "$SIGNING_DETAILS" | grep -q "TeamIdentifier=not set"; then
    printf 'Release app has no TeamIdentifier.\n' >&2
    exit 1
  fi

  spctl -a -vv "$APP_PATH"
  if [ "$REQUIRE_STAPLED" -eq 1 ]; then
    if ! xcrun stapler validate "$APP_PATH"; then
      printf 'Release app does not have a valid stapled notarization ticket.\n' >&2
      printf 'Run notarization first with: ./script/cicd/notarize_release.sh --keychain-profile PROFILE\n' >&2
      exit 1
    fi
  fi
else
  if [ "$REQUIRE_STAPLED" -eq 1 ]; then
    printf '%s\n' '--require-stapled is only valid with --developer-id.' >&2
    exit 2
  fi

  if ! printf '%s\n' "$SIGNING_DETAILS" | grep -q "Signature=adhoc"; then
    printf 'Release app is not using the expected local ad-hoc signing mode.\n' >&2
    exit 1
  fi

  printf 'Local release signing verification passed. This is suitable for local/private builds, not public distribution.\n'
fi
