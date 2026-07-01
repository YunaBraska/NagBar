#!/bin/sh
set -eu

CONFIGURATION=Debug
MODE=run
VERIFY=0

usage() {
  cat <<USAGE
Usage: $0 [--release] [--verify] [--test|--release-build|--package|--smoke|--acceptance|--all|--debug|--logs|--telemetry]

Default: stop any running NagBar, build Debug, and launch the app.

Options:
  --release        Use Release configuration for run/debug/log modes.
  --verify         After launch, confirm the NagBar process is running.
  --test           Run the full macOS test suite. With --verify, test then run.
  --release-build  Build Release without launching.
  --package        Build Release and create a local/private zip package.
  --smoke          Run the live status-item smoke.
  --acceptance     Run full tests, Release build, and live smoke.
  --all            Alias for --acceptance.
  --debug          Build, then launch the app binary under lldb.
  --logs           Build, launch, then stream NagBar process logs.
  --telemetry      Build, launch, then stream logs for the NagBar bundle id.
USAGE
}

for arg in "$@"; do
  case "$arg" in
    --release)
      CONFIGURATION=Release
      ;;
    --verify)
      VERIFY=1
      ;;
    --test)
      MODE=test
      ;;
    --release-build)
      MODE=release-build
      CONFIGURATION=Release
      ;;
    --package)
      MODE=package
      CONFIGURATION=Release
      ;;
    --smoke)
      MODE=smoke
      ;;
    --acceptance)
      MODE=acceptance
      ;;
    --all)
      MODE=acceptance
      ;;
    --debug)
      MODE=debug
      ;;
    --logs)
      MODE=logs
      ;;
    --telemetry)
      MODE=telemetry
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      printf 'Unknown argument: %s\n' "$arg" >&2
      usage >&2
      exit 2
      ;;
  esac
done

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
APP_NAME=NagBar
BUNDLE_ID=com.volendavidov.NagBar
APP_PATH="$ROOT_DIR/build/$CONFIGURATION/$APP_NAME.app"
APP_BINARY="$APP_PATH/Contents/MacOS/$APP_NAME"

build_app() {
  xcodebuild build \
    -workspace "$ROOT_DIR/NagBar.xcworkspace" \
    -scheme "$APP_NAME" \
    -configuration "$CONFIGURATION" \
    -destination 'platform=macOS' \
    SYMROOT="$ROOT_DIR/build"
}

test_app() {
  xcodebuild test \
    -workspace "$ROOT_DIR/NagBar.xcworkspace" \
    -scheme "$APP_NAME" \
    -destination 'platform=macOS'
}

stop_app() {
  if pgrep -x "$APP_NAME" >/dev/null 2>&1; then
    pkill -x "$APP_NAME" || true
    sleep 1
  fi
}

open_app() {
  /usr/bin/open -n "$APP_PATH"
}

verify_app() {
  i=0
  while [ "$i" -lt 20 ]; do
    if pgrep -x "$APP_NAME" >/dev/null 2>&1; then
      printf '%s is running\n' "$APP_NAME"
      return 0
    fi
    i=$((i + 1))
    sleep 0.5
  done

  printf '%s did not start\n' "$APP_NAME" >&2
  return 1
}

run_app() {
  stop_app
  build_app
  open_app
  if [ "$VERIFY" -eq 1 ]; then
    verify_app
  fi
}

case "$MODE" in
  run)
    run_app
    ;;
  test)
    test_app
    if [ "$VERIFY" -eq 1 ]; then
      run_app
    fi
    ;;
  release-build)
    build_app
    ;;
  package)
    "$ROOT_DIR/script/cicd/package_release.sh"
    ;;
  smoke)
    "$ROOT_DIR/script/status_item_smoke.sh"
    ;;
  acceptance)
    test_app
    CONFIGURATION=Release
    APP_PATH="$ROOT_DIR/build/$CONFIGURATION/$APP_NAME.app"
    APP_BINARY="$APP_PATH/Contents/MacOS/$APP_NAME"
    build_app
    "$ROOT_DIR/script/status_item_smoke.sh"
    ;;
  debug)
    stop_app
    build_app
    exec lldb -- "$APP_BINARY"
    ;;
  logs)
    stop_app
    build_app
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  telemetry)
    stop_app
    build_app
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  *)
    printf 'Unknown mode: %s\n' "$MODE" >&2
    usage >&2
    exit 2
    ;;
esac
