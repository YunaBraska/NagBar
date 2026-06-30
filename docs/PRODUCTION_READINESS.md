# Production Readiness

Status: In progress.

NagBar currently builds, tests, and launches locally. It is not yet ready for a
public production release until the blocked gates below are closed.

## Current Evidence

| Gate | Status | Evidence |
| --- | --- | --- |
| Full test suite | Done | `xcodebuild test -workspace NagBar.xcworkspace -scheme NagBar -destination 'platform=macOS'` passes with 274 tests |
| Coverage gate | Partial | Current Xcode result reports 76.32% coverage for `NagBar.app`; requested production gate is about 95% |
| Release build | Done | `xcodebuild build -workspace NagBar.xcworkspace -scheme NagBar -configuration Release -destination 'platform=macOS'` passes |
| Runtime smoke | Done | `script/status_item_smoke.sh` runs with isolated app storage/defaults and verifies live status-item menu shape, Show Status panel/table, keyboard menu activation, Refresh, Apple-menu product-action removal, status-item Settings reachability to Monitoring Instances, Monitoring Instances add-row persistence, and Quit |
| Local developer acceptance | Done | `./script/build_and_run.sh --acceptance` runs full tests, Release build, and live runtime smoke through the canonical helper |
| Removed stale dependencies | Done | No `SAMKeychain`, `SwiftyJSON`, `Alamofire`, `PromiseKit`, `hpple`, `RealmSwift`, or CocoaPods references in app/test/project files |
| Fake-server HTTP test | Partial | Nagios/Icinga GET/auth/non-2xx behavior, first-run local fake Icinga fallback over loopback HTTP, Nagios/Icinga and Icinga2 command POST contracts, and Check_MK login/session behavior covered |
| Parser malformed-data and status fixtures | Done | Nagios, Icinga, Icinga2, Thruk, and Check_MK parser fixtures cover happy paths, malformed ingress, and supported status variants |
| CI workflow | Done | `.github/workflows/ci.yml` checks Xcode version, rejects CocoaPods files/references, validates helper shell syntax, runs `./script/build_and_run.sh --test`, and builds Release with `./script/build_and_run.sh --release-build`; live GitHub runner result still needs remote branch push |
| Release workflow | Partial | `.github/workflows/release.yml` generates Sentrio-style date versions, updates Xcode version and `CHANGELOG.md`, tests, builds, packages, and publishes GitHub Release assets; real Developer ID/notarization path still needs secrets and a live run |
| Local/private package | Done | `./script/build_and_run.sh --package` builds Release, verifies local/private signing, creates `dist/NagBar-1.3.7-macOS.zip`, validates the zip, writes `dist/NagBar-1.3.7-macOS.zip.sha256`, and the extracted app passes local signing verification |

## Release Blockers

| Blocker | Status | Required evidence |
| --- | --- | --- |
| Local/private signing | Done | Default Release build uses explicit manual ad-hoc signing (`CODE_SIGN_IDENTITY = "-"`, no development team) for machines without an Apple developer account; `script/verify_release_signing.sh` validates `Signature=adhoc`, hardened runtime, no debug `get-task-allow` entitlement, and `TeamIdentifier=not set` |
| Developer ID signing | Partial | `script/sign_release.sh --developer-id IDENTITY` re-signs an existing Release app when a real Developer ID Application identity is installed; `script/verify_release_signing.sh --developer-id` validates signature, TeamIdentifier, hardened runtime, and Gatekeeper acceptance without requiring the verifier machine to own the private signing identity; real Developer ID artifact evidence is still required |
| Hardened runtime | Done | Release target explicitly enables hardened runtime, disables base entitlement injection, Release build passes, and `codesign -dvvv` reports `flags=0x10002(adhoc,runtime)` with no debug entitlement output |
| Notarization | Partial | `script/notarize_release.sh` submits a Developer ID signed app with `notarytool --wait`, staples and validates the `.app`, and `script/package_release.sh --developer-id` requires stapling before the public zip is created; Apple acceptance evidence is still required |
| Packaging | Done | Local/private zip artifact, SHA-256 checksum, and manifest are produced by `script/package_release.sh`; the zip is extracted and the extracted app is rechecked for signing before checksum publication; public notarized distribution remains covered by Developer ID signing and notarization gates |
| Command POST contracts | Done | Focused fake-server suite covers acknowledge, recheck, and downtime POST requests |
| Command result handling | Done | User-visible command success/failure feedback instead of log-only failures |
| Check_MK session behavior | Done | Focused fake-server suite covers cookie login/session, Basic auth, and unauthorized connection checks |
| Check_MK command policy | Done | Unsupported command capabilities removed; unsupported POST rejects explicitly |
| Upgrade compatibility | Done | Current JSON/UserDefaults/Keychain configuration survives startup after Realm/CocoaPods removal; legacy `default.realm*` leftovers are detected and reported through `upgrade-compatibility.json` as a manual reconfiguration/cutoff path because this build no longer embeds Realm; malformed current monitoring JSON with legacy leftovers is treated as manual reconfiguration |
| Error reporting | Done | Structured `Logger` diagnostics cover startup snapshots, storage/upgrade report failures, refresh failures/completion, local fake-server startup, and maintainer log streaming through `--logs`/`--telemetry`; focused diagnostics/storage slice passes 48 tests |
| Accessibility identifiers | Done | Status item, failed status item, status panel/table, Settings About, Monitoring Instances cells, and command dialogs expose stable identifiers/labels; global menu-extra focus and AppKit cell-editor text entry remain manual QA |

## Verification Commands

Full tests:

```sh
./script/build_and_run.sh --test
```

Focused fake-server tests:

```sh
xcodebuild test -workspace NagBar.xcworkspace -scheme NagBar -destination 'platform=macOS' -only-testing:NagBarTests/LoadMonitoringDataFakeIcingaTests
```

Check_MK session fake-server tests:

```sh
xcodebuild test -workspace NagBar.xcworkspace -scheme NagBar -destination 'platform=macOS' -only-testing:NagBarTests/CheckMKHTTPClientFakeServerTests
```

Release build:

```sh
./script/build_and_run.sh --release-build
```

Release signing verification:

```sh
./script/verify_release_signing.sh
```

Developer ID signing helper:

```sh
./script/sign_release.sh --developer-id "Developer ID Application: Example (TEAMID)"
```

Notarization helper:

```sh
./script/notarize_release.sh --keychain-profile NagBarNotary
```

Public release package after signing and notarization:

```sh
./script/package_release.sh --developer-id --skip-build
```

Local/private release package:

```sh
./script/build_and_run.sh --package
```

Live runtime smoke:

```sh
./script/status_item_smoke.sh
```

Full local verification:

```sh
./script/build_and_run.sh --acceptance
```

## Production Exit Criteria

NagBar can be called production-distribution ready when:

1. Full tests pass on CI and on a maintainer macOS machine.
2. Local/private Release build passes local signing verification.
3. Hardened runtime is enabled.
4. Public release artifact is Developer ID signed, notarized, and stapled.
5. Release artifact launches on a clean macOS user account.
6. All P0/P1 items in `TEST_MAP.md` are either `Done` or explicitly deferred in release notes.
7. Upgrade cutoff behavior is documented in release notes for users with legacy Realm-only configuration.
8. Security and support policies are published.
