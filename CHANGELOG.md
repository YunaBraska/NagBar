# Changelog

All notable NagBar changes should be recorded here before a release tag is cut.

This project uses human-readable release notes rather than generated commit
summaries. Keep entries focused on user-visible behavior, compatibility,
security, upgrade notes, and verification evidence.

## [Unreleased]

## [2026.07.1820632] - 2026-07-01

### Changed

- Release 2026.07.1820632.

## [2026.07.1820613] - 2026-07-01

### Changed

- Release 2026.07.1820613.

## [2026.07.1820540] - 2026-07-01

### Changed

- Consolidated roadmap, spec, and readiness notes into `docs/PROJECT_STATUS.md`.
- Moved release helper scripts under `script/cicd/`.

### Fixed

- Kept local packaging and release helper paths working after the `script/cicd/`
  move, with CI coverage for the nested release-note helper path.
- Added fake-server and storage regression coverage for mixed Icinga refresh
  failures, Thruk command posts, multi-item Nagios rechecks, fixed Icinga 2
  service downtime, and malformed filter storage recovery.


## [2026.06.1812002] - 2026-06-30

### Changed

- Release 2026.06.1812002.

## [2026.06.1811748] - 2026-06-30

### Changed

- Revived the macOS build and test workflow for current Xcode.
- Removed CocoaPods and legacy third-party runtime dependencies.
- Replaced active Realm storage with `UserDefaults`, JSON files under
  Application Support, and Keychain-backed password storage.
- Added a first-run local loopback fake Icinga server when no real monitoring
  remote is configured.
- Moved About and Settings into the status-item entrypoint.
- Added local/private release packaging with ad-hoc signing and hardened
  runtime verification.
- Added a GitHub Actions release workflow with Sentrio-style date versions,
  automatic changelog/version metadata updates, local/private signing by
  default, and Developer ID notarization when secrets are configured.

### Fixed

- Added fake-server coverage for Nagios/Icinga, Icinga 2, and Check_MK HTTP
  behavior.
- Added explicit command-result feedback instead of log-only command failures.
- Added structured diagnostics for startup, storage, refresh, and local
  fake-server events.
- Hardened several AppKit callback, status-panel, and URLSession lifecycle
  edges found during runtime review.

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

### Known Limits

- Public distribution still requires Developer ID signing and notarization.
- Local/private ad-hoc builds are not public release artifacts.
- Coverage remains below the production target documented in
  `docs/PROJECT_STATUS.md`.
