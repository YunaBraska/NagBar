#!/bin/sh
set -eu

if [ "$#" -ne 1 ]; then
  printf 'Usage: %s VERSION\n' "$0" >&2
  exit 2
fi

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
PROJECT_FILE="$ROOT_DIR/NagBar.xcodeproj/project.pbxproj"
VERSION=$("$ROOT_DIR/script/cicd/release_version.sh" "$1")
TMP_FILE=$(mktemp "${TMPDIR:-/tmp}/nagbar-project.XXXXXX")

cleanup() {
  rm -f "$TMP_FILE"
}
trap cleanup EXIT HUP INT TERM

awk -v version="$VERSION" '
  {
    sub(/MARKETING_VERSION = [^;]+;/, "MARKETING_VERSION = " version ";")
    sub(/CURRENT_PROJECT_VERSION = [^;]+;/, "CURRENT_PROJECT_VERSION = " version ";")
    print
  }
' "$PROJECT_FILE" > "$TMP_FILE"

mv "$TMP_FILE" "$PROJECT_FILE"
trap - EXIT HUP INT TERM

if ! grep -F "MARKETING_VERSION = $VERSION;" "$PROJECT_FILE" >/dev/null; then
  printf 'Failed to set MARKETING_VERSION to %s\n' "$VERSION" >&2
  exit 1
fi

if ! grep -F "CURRENT_PROJECT_VERSION = $VERSION;" "$PROJECT_FILE" >/dev/null; then
  printf 'Failed to set CURRENT_PROJECT_VERSION to %s\n' "$VERSION" >&2
  exit 1
fi

printf 'Set NagBar release version: %s\n' "$VERSION"
