#!/bin/sh
set -eu

if [ "$#" -ne 1 ]; then
  printf 'Usage: %s VERSION\n' "$0" >&2
  exit 2
fi

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
CHANGELOG="$ROOT_DIR/CHANGELOG.md"
VERSION=$("$ROOT_DIR/script/release_version.sh" "$1")

awk -v version="$VERSION" '
  $0 ~ "^## \\[" version "\\] -" {
    found = 1
    next
  }

  found && /^## \[/ {
    exit
  }

  found {
    print
  }

  END {
    if (!found) {
      exit 1
    }
  }
' "$CHANGELOG"
