#!/bin/sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
APP_PATH="$ROOT_DIR/build/Release/NagBar.app"
KEYCHAIN_PROFILE=
APPLE_ID=
TEAM_ID=
PASSWORD=
PASSWORD_ENV=

usage() {
  cat <<USAGE
Usage: $0 [--app APP_PATH] (--keychain-profile PROFILE | --apple-id EMAIL --team-id TEAM_ID (--password APP_PASSWORD | --password-env ENV_NAME))

Submits a Developer ID signed app to Apple notarization, waits for the result,
staples the ticket to the app bundle, and validates the stapled app.

Options:
  --app               App bundle to notarize. Default: build/Release/NagBar.app.
  --keychain-profile  notarytool keychain profile created with xcrun notarytool store-credentials.
  --apple-id          Apple ID email for notarytool.
  --team-id           Apple Developer Team ID for notarytool.
  --password          App-specific password for notarytool.
  --password-env      Environment variable containing the app-specific password.

This script intentionally does not fake notarization. Without Apple credentials
it exits with an actionable diagnostic.
USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --app)
      shift
      if [ "$#" -eq 0 ]; then
        printf 'Missing value for --app\n' >&2
        exit 2
      fi
      APP_PATH=$1
      ;;
    --keychain-profile)
      shift
      if [ "$#" -eq 0 ]; then
        printf 'Missing value for --keychain-profile\n' >&2
        exit 2
      fi
      KEYCHAIN_PROFILE=$1
      ;;
    --apple-id)
      shift
      if [ "$#" -eq 0 ]; then
        printf 'Missing value for --apple-id\n' >&2
        exit 2
      fi
      APPLE_ID=$1
      ;;
    --team-id)
      shift
      if [ "$#" -eq 0 ]; then
        printf 'Missing value for --team-id\n' >&2
        exit 2
      fi
      TEAM_ID=$1
      ;;
    --password)
      shift
      if [ "$#" -eq 0 ]; then
        printf 'Missing value for --password\n' >&2
        exit 2
      fi
      PASSWORD=$1
      ;;
    --password-env)
      shift
      if [ "$#" -eq 0 ]; then
        printf 'Missing value for --password-env\n' >&2
        exit 2
      fi
      PASSWORD_ENV=$1
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      printf 'Unknown argument: %s\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
  shift
done

if [ ! -d "$APP_PATH" ]; then
  printf 'Release app not found: %s\n' "$APP_PATH" >&2
  printf 'Build it first with: ./script/build_and_run.sh --release-build\n' >&2
  exit 1
fi

if [ -n "$PASSWORD_ENV" ]; then
  if [ -n "$PASSWORD" ]; then
    printf 'Use either --password or --password-env, not both.\n' >&2
    exit 2
  fi
  case "$PASSWORD_ENV" in
    ''|[!A-Za-z_]*|*[!A-Za-z0-9_]*)
      printf 'Password environment variable name is invalid: %s\n' "$PASSWORD_ENV" >&2
      exit 2
      ;;
  esac
  eval "PASSWORD=\${$PASSWORD_ENV:-}"
  if [ -z "$PASSWORD" ]; then
    printf 'Password environment variable is empty or unset: %s\n' "$PASSWORD_ENV" >&2
    exit 2
  fi
fi

if [ -n "$KEYCHAIN_PROFILE" ]; then
  if [ -n "$APPLE_ID$TEAM_ID$PASSWORD$PASSWORD_ENV" ]; then
    printf 'Use either --keychain-profile or --apple-id/--team-id/--password, not both.\n' >&2
    exit 2
  fi
else
  if [ -z "$APPLE_ID" ] || [ -z "$TEAM_ID" ] || [ -z "$PASSWORD" ]; then
    printf 'Apple notarization credentials are required.\n' >&2
    printf 'Use --keychain-profile PROFILE, or --apple-id EMAIL --team-id TEAM_ID with --password or --password-env.\n' >&2
    exit 2
  fi
fi

"$ROOT_DIR/script/verify_release_signing.sh" --developer-id "$APP_PATH"

TMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/nagbar-notary.XXXXXX")
ZIP_PATH="$TMP_DIR/NagBar-notary.zip"
cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT HUP INT TERM

ditto -c -k --norsrc --keepParent "$APP_PATH" "$ZIP_PATH"

if [ -n "$KEYCHAIN_PROFILE" ]; then
  xcrun notarytool submit "$ZIP_PATH" --keychain-profile "$KEYCHAIN_PROFILE" --wait
else
  xcrun notarytool submit "$ZIP_PATH" --apple-id "$APPLE_ID" --team-id "$TEAM_ID" --password "$PASSWORD" --wait
fi

xcrun stapler staple "$APP_PATH"
xcrun stapler validate "$APP_PATH"
"$ROOT_DIR/script/verify_release_signing.sh" --developer-id "$APP_PATH"
printf 'Notarization and stapling complete: %s\n' "$APP_PATH"
