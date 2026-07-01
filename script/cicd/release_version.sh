#!/bin/sh
set -eu

if [ "$#" -gt 1 ]; then
  printf 'Usage: %s [VERSION]\n' "$0" >&2
  exit 2
fi

VERSION=${1:-}
if [ -z "$VERSION" ]; then
  VERSION=$(date -u '+%Y.%m.%j%H%M')
fi

case "$VERSION" in
  *[!0-9.]*|.*|*..*|*.)
    printf 'Release version must contain only dot-separated digits: %s\n' "$VERSION" >&2
    exit 2
    ;;
  *.*)
    ;;
  *)
    printf 'Release version must contain at least one dot: %s\n' "$VERSION" >&2
    exit 2
    ;;
esac

printf '%s\n' "$VERSION"
