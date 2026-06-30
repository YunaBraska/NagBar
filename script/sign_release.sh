#!/bin/sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
APP_PATH="$ROOT_DIR/build/Release/NagBar.app"
IDENTITY=

usage() {
  cat <<USAGE
Usage: $0 --developer-id IDENTITY [--app APP_PATH]

Re-signs a built Release app with a Developer ID Application identity.

Options:
  --developer-id  Developer ID Application signing identity name or hash.
  --identity      Alias for --developer-id.
  --app           App bundle to sign. Default: build/Release/NagBar.app.

Local/private ad-hoc signing is the default Xcode Release path and does not use
this script. Build that path with: ./script/build_and_run.sh --package
USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --developer-id|--identity)
      shift
      if [ "$#" -eq 0 ]; then
        printf 'Missing value for --developer-id\n' >&2
        exit 2
      fi
      IDENTITY=$1
      ;;
    --app)
      shift
      if [ "$#" -eq 0 ]; then
        printf 'Missing value for --app\n' >&2
        exit 2
      fi
      APP_PATH=$1
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

if [ -z "$IDENTITY" ]; then
  printf 'Developer ID identity is required for public signing.\n' >&2
  printf 'Private/local packages do not need an Apple developer account: ./script/build_and_run.sh --package\n' >&2
  exit 2
fi

if [ ! -d "$APP_PATH" ]; then
  printf 'Release app not found: %s\n' "$APP_PATH" >&2
  printf 'Build it first with: ./script/build_and_run.sh --release-build\n' >&2
  exit 1
fi

if ! security find-identity -v -p codesigning | grep -F "$IDENTITY" >/dev/null 2>&1; then
  printf 'Developer ID identity not found in the local keychain: %s\n' "$IDENTITY" >&2
  printf 'Install a Developer ID Application certificate, or use the default local/private package path.\n' >&2
  exit 1
fi

sign_target() {
  target=$1
  printf 'Signing: %s\n' "$target"
  codesign --force --timestamp --options runtime --sign "$IDENTITY" "$target"
}

find "$APP_PATH/Contents" \
  \( -name '*.framework' -o -name '*.dylib' -o -name '*.appex' -o -name '*.xpc' -o -name '*.bundle' \) \
  -print | while IFS= read -r nested; do
    sign_target "$nested"
  done

sign_target "$APP_PATH"
"$ROOT_DIR/script/verify_release_signing.sh" --developer-id "$APP_PATH"
printf 'Developer ID signing complete: %s\n' "$APP_PATH"
