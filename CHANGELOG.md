# Changelog

All notable NagBar changes should be recorded here before a release tag is cut.

This project uses human-readable release notes rather than generated commit
summaries. Keep entries focused on user-visible behavior, compatibility,
security, upgrade notes, and verification evidence.

## [Unreleased]

## [2026.07.1820815] - 2026-07-01

This is the first stable release of the revived fork. It consolidates the
reactivation work since the fork into one release; earlier test releases and
tags were removed.

### Changed

- Revived the macOS app for current Xcode and restored the build, test, smoke,
  package, and release workflows.
- Removed CocoaPods and legacy third-party runtime dependencies.
- Replaced active Realm storage with `UserDefaults`, JSON files under
  Application Support, and Keychain-backed password storage.
- Added a first-run local loopback fake Icinga server when no real monitoring
  remote is configured, using the normal Icinga stack instead of hardcoded app
  demo branches.
- Moved About, Settings, status, refresh, and quit access into the status-item
  entrypoint.
- Added local/private release packaging with ad-hoc signing, hardened runtime
  verification, zip/checksum/manifest output, and Developer ID notarization when
  Apple signing secrets are configured.
- Added Sentrio-style date versions and automated changelog/version metadata in
  the GitHub Actions release flow.
- Consolidated roadmap, specs, support status, and production-readiness notes
  into `docs/PROJECT_STATUS.md`.
- Moved release helper scripts under `script/cicd/`.
- Replaced deprecated macOS notification and sound-file picker APIs with
  `UserNotifications` and `allowedContentTypes`.
- Enriched the first-run fake Icinga sample data and README screenshot so the
  demo looks closer to the original NagBar status panel.
- Updated project status evidence to the current 450-test, 95.01%-coverage
  verification run.

### Fixed

- Added fake-server coverage for Nagios/Icinga, Icinga 2, Thruk, and Check_MK
  HTTP behavior, including auth, refresh, command, downtime, and session paths.
- Added explicit command-result feedback instead of log-only command failures.
- Added structured diagnostics for startup, storage, refresh, and local
  fake-server events.
- Hardened AppKit callback, status-panel, URLSession lifecycle, storage, and
  malformed-input edges found during runtime review.
- Replaced leaked screenshot history with a sanitized fake-Icinga demo image.
- Raised app coverage above the 95% release gate with focused fake-server,
  settings, status item, diagnostics, command, and server-login coverage.
- Added safe test seams for alerts, browser opening, file picking, status-item
  refresh/menu entrypoints, and login launchers so tests do not open external
  apps or modal UI during automation.
- Preserved notification click-through URL behavior with deterministic tests for
  authorization, delivery errors, missing URLs, malformed URLs, and valid URLs.
- Display custom audible alarm filenames with unescaped file names.

### Upgrade Notes

- Current JSON/UserDefaults/Keychain configuration is preserved.
- Legacy Realm-only `default.realm*` configuration is detected and reported in
  `upgrade-compatibility.json`, but it is not imported by this Realm-free build.
- Users upgrading directly from a Realm-only build must reconfigure monitoring
  instances in Settings or migrate through an earlier bridge build.

### Verification

- Full tests: `./script/build_and_run.sh --test`
- Release build: `./script/build_and_run.sh --release-build`
- Local/private package: `./script/build_and_run.sh --package`
- Runtime smoke: `./script/build_and_run.sh --smoke`
- GitHub Actions CI and release workflow completed for the stable release.

### Known Limits

- Public distribution still requires Developer ID signing and notarization.
- Local/private ad-hoc builds are not public release artifacts.
- Broader real-version backend compatibility and clean-account public release
  evidence remain tracked in `docs/PROJECT_STATUS.md`.
