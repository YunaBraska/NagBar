#!/bin/sh
set -eu

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
  printf 'Usage: %s VERSION [YYYY-MM-DD]\n' "$0" >&2
  exit 2
fi

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
CHANGELOG="$ROOT_DIR/CHANGELOG.md"
VERSION=$("$ROOT_DIR/script/release_version.sh" "$1")
RELEASE_DATE=${2:-$(date -u '+%Y-%m-%d')}
TMP_FILE=$(mktemp "${TMPDIR:-/tmp}/nagbar-changelog.XXXXXX")

cleanup() {
  rm -f "$TMP_FILE"
}
trap cleanup EXIT HUP INT TERM

if grep -F "## [$VERSION] -" "$CHANGELOG" >/dev/null; then
  printf 'Changelog already contains release %s\n' "$VERSION"
  exit 0
fi

if ! grep -Fx '## [Unreleased]' "$CHANGELOG" >/dev/null; then
  printf 'CHANGELOG.md must contain a "## [Unreleased]" section.\n' >&2
  exit 1
fi

awk -v version="$VERSION" -v release_date="$RELEASE_DATE" '
  BEGIN {
    state = "before"
    captured = ""
  }

  state == "before" {
    print
    if ($0 == "## [Unreleased]") {
      state = "capture"
      print ""
    }
    next
  }

  state == "capture" {
    if ($0 ~ /^## \[/) {
      print_release()
      print
      state = "after"
      next
    }
    captured = captured $0 "\n"
    next
  }

  state == "after" {
    print
    next
  }

  END {
    if (state == "capture") {
      print_release()
    }
  }

  function print_release() {
    print "## [" version "] - " release_date
    if (captured ~ /^[[:space:]]*$/) {
      print ""
      print "### Changed"
      print ""
      print "- Release " version "."
    } else {
      printf "%s", captured
    }
    print ""
  }
' "$CHANGELOG" > "$TMP_FILE"

mv "$TMP_FILE" "$CHANGELOG"
trap - EXIT HUP INT TERM
printf 'Prepared changelog release: %s\n' "$VERSION"
