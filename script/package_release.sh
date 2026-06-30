#!/bin/sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
APP_NAME=NagBar
APP_PATH="$ROOT_DIR/build/Release/$APP_NAME.app"
DIST_DIR="$ROOT_DIR/dist"
SIGNING_MODE=local
SKIP_BUILD=0

usage() {
  cat <<USAGE
Usage: $0 [--local|--developer-id] [--skip-build] [--output-dir DIR]

Builds and packages the Release app as a zip plus SHA-256 checksum.

Options:
  --local         Verify local/private ad-hoc signing. Default.
  --developer-id  Verify Developer ID signing and stapled notarization for public distribution.
  --skip-build    Package the existing build/Release/NagBar.app.
  --output-dir    Directory for release artifacts. Default: dist.
USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --local)
      SIGNING_MODE=local
      ;;
    --developer-id)
      SIGNING_MODE=developer-id
      ;;
    --skip-build)
      SKIP_BUILD=1
      ;;
    --output-dir)
      shift
      if [ "$#" -eq 0 ]; then
        printf 'Missing value for --output-dir\n' >&2
        exit 2
      fi
      DIST_DIR=$1
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

if [ "$SKIP_BUILD" -eq 0 ]; then
  "$ROOT_DIR/script/build_and_run.sh" --release-build
fi

verify_app() {
  app_path=$1
  if [ "$SIGNING_MODE" = "developer-id" ]; then
    "$ROOT_DIR/script/verify_release_signing.sh" --developer-id --require-stapled "$app_path"
  else
    "$ROOT_DIR/script/verify_release_signing.sh" --local "$app_path"
  fi
}

verify_app "$APP_PATH"

if [ ! -d "$APP_PATH" ]; then
  printf 'Release app not found: %s\n' "$APP_PATH" >&2
  exit 1
fi

VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_PATH/Contents/Info.plist" 2>/dev/null || printf 'unknown')
if [ -z "$VERSION" ]; then
  VERSION=unknown
fi

ARTIFACT_BASENAME="$APP_NAME-$VERSION-macOS"
ZIP_PATH="$DIST_DIR/$ARTIFACT_BASENAME.zip"
CHECKSUM_PATH="$ZIP_PATH.sha256"
MANIFEST_PATH="$ZIP_PATH.manifest"
EXTRACT_DIR="$DIST_DIR/$ARTIFACT_BASENAME.verify"

mkdir -p "$DIST_DIR"
rm -f "$ZIP_PATH" "$CHECKSUM_PATH" "$MANIFEST_PATH"
rm -rf "$EXTRACT_DIR"

ditto -c -k --norsrc --keepParent "$APP_PATH" "$ZIP_PATH"
unzip -t "$ZIP_PATH" >/dev/null
mkdir -p "$EXTRACT_DIR"
ditto -x -k "$ZIP_PATH" "$EXTRACT_DIR"
verify_app "$EXTRACT_DIR/$APP_NAME.app"
rm -rf "$EXTRACT_DIR"
shasum -a 256 "$ZIP_PATH" > "$CHECKSUM_PATH"
ZIP_SHA256=$(awk '{print $1}' "$CHECKSUM_PATH")
GIT_REF=$(git -C "$ROOT_DIR" rev-parse --short=12 HEAD 2>/dev/null || printf 'unknown')
GIT_BRANCH=$(git -C "$ROOT_DIR" branch --show-current 2>/dev/null || printf 'unknown')
GIT_DIRTY=false
if ! git -C "$ROOT_DIR" diff --quiet --ignore-submodules -- 2>/dev/null || [ -n "$(git -C "$ROOT_DIR" ls-files --others --exclude-standard 2>/dev/null)" ]; then
  GIT_DIRTY=true
fi
XCODE_VERSION=$(xcodebuild -version 2>/dev/null | tr '\n' ';' | sed 's/;$//')
APP_BUNDLE_ID=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP_PATH/Contents/Info.plist" 2>/dev/null || printf 'unknown')
APP_BUILD=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$APP_PATH/Contents/Info.plist" 2>/dev/null || printf 'unknown')

cat > "$MANIFEST_PATH" <<MANIFEST
artifact=$ZIP_PATH
checksum=$CHECKSUM_PATH
sha256=$ZIP_SHA256
app=$APP_NAME
bundle_id=$APP_BUNDLE_ID
version=$VERSION
build=$APP_BUILD
signing_mode=$SIGNING_MODE
git_branch=$GIT_BRANCH
git_ref=$GIT_REF
git_dirty=$GIT_DIRTY
xcode=$XCODE_VERSION
created_utc=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
MANIFEST

printf 'Packaged release artifact: %s\n' "$ZIP_PATH"
printf 'Checksum: %s\n' "$CHECKSUM_PATH"
printf 'Manifest: %s\n' "$MANIFEST_PATH"
