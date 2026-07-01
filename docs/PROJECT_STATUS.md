# Project Status

Status: Reactivation milestone complete; production-hardening work remains.

This is the canonical status, scope, and verification document for NagBar.
Keep ADRs for decisions, `CHANGELOG.md` for release notes, and this file for the
current truth about behavior and readiness.

## Product Scope

NagBar provides a native macOS status-item view of Nagios-compatible monitoring
state. The maintained product surface is:

- configure monitoring instances for Nagios, Icinga, Icinga 2, Thruk, and Check_MK;
- fetch host and service state through the real backend protocol for each type;
- expose status, Settings, About, refresh, and quit from the status-item entrypoint;
- support filtering, browser-open actions, and supported backend commands;
- package local/private Release artifacts and keep a documented public release path.

## Verified Snapshot

Snapshot date: 2026-07-01.

| Area | Status | Evidence |
| --- | --- | --- |
| Full macOS test suite | Done | `xcodebuild test -workspace NagBar.xcworkspace -scheme NagBar -destination 'platform=macOS'` passes with 450 tests |
| Release build | Done | `xcodebuild build -workspace NagBar.xcworkspace -scheme NagBar -configuration Release -destination 'platform=macOS'` passes |
| Local acceptance | Done | `./script/build_and_run.sh --acceptance` runs full tests, Release build, and live runtime smoke |
| Runtime smoke | Done | `./script/build_and_run.sh --smoke` verifies the status-item menu, Show Status, keyboard activation, Refresh, Preferences, and Quit in isolated storage |
| Local/private packaging | Done | `./script/build_and_run.sh --package` creates a zip, checksum, and manifest under `dist/`, then verifies the packaged app signature |
| CI workflow | Done | `.github/workflows/ci.yml` runs helper syntax checks, release helper path smoke, tests, Release build, and CocoaPods guardrails |
| GitHub release automation | Done | Release `2026.07.1820737` completed through `.github/workflows/release.yml` with local/private signing; Developer ID notarization remains secret-dependent |
| Coverage gate | Done | Xcode result metrics report 95.01% coverage for `NagBar.app`, above the 95% gate |
| Status-panel command hardening | Done | Public menu/action regressions cover malformed or empty command input, nil monitoring instances, unsupported filter statuses, and pre-assignment command window loading |

## Supported Backends

| Backend | Status | Current evidence | Current gap |
| --- | --- | --- | --- |
| Nagios HTML CGI | Partial | Parser coverage, URL provider coverage, fake-server HTTP auth, mixed host/service recheck, and command POST tests | Broader real-version compatibility smoke |
| Icinga HTML CGI | Partial | Parser coverage, fake-server load/auth/command tests, mixed successful/failed refresh path, first-run local fallback path | Broader real-version compatibility smoke |
| Icinga 2 API | Partial | URL provider, JSON parser, JSON command POST coverage, flexible host downtime, and fixed service downtime | Broader API error and real-server compatibility smoke |
| Thruk JSON API | Partial | URL provider, JSON parser, HTTP behavior coverage, and inherited command POST coverage through Thruk HTTP semantics | Broader command and real-server compatibility smoke |
| Check_MK | Partial | URL provider, parser, cookie-login, Basic auth, and session coverage | Real-server compatibility smoke and unsupported command expansion only if intentionally added |

## Simplification Status

| Area | Status | Notes |
| --- | --- | --- |
| CocoaPods removal | Done | No `Podfile`, `Podfile.lock`, or Pods workspace/project wiring remain |
| Active Realm storage removal | Done | Scalar settings live in `UserDefaults`; filters, server logins, and monitoring instances live in JSON/Application Support |
| Legacy Realm import | Dismissed | Legacy-only installs now receive `upgrade-compatibility.json`; this branch does not import Realm data |
| Local fake first-run path | Done | Uses a loopback fake Icinga server through the normal Icinga stack; no app-side demo branch |
| Status-item product entrypoint | Done | Status, About, Preferences, refresh, and quit are reachable from the menu bar entrypoint |
| Local/private release path | Done | Ad-hoc signing, hardened runtime verification, packaging, checksum, and manifest are in place |
| Public release path | Partial | Helper scripts exist; final evidence still requires real Developer ID signing and Apple notarization |

## Verification Commands

Daily maintainer commands:

```sh
./script/build_and_run.sh --verify
./script/build_and_run.sh --test
./script/build_and_run.sh --release-build
./script/build_and_run.sh --smoke
./script/build_and_run.sh --acceptance
./script/build_and_run.sh --package
```

Focused fake-server coverage:

```sh
xcodebuild test -workspace NagBar.xcworkspace -scheme NagBar -destination 'platform=macOS' -only-testing:NagBarTests/LoadMonitoringDataFakeIcingaTests
xcodebuild test -workspace NagBar.xcworkspace -scheme NagBar -destination 'platform=macOS' -only-testing:NagBarTests/CheckMKHTTPClientFakeServerTests
```

Release-only helpers:

```sh
./script/cicd/verify_release_signing.sh
./script/cicd/package_release.sh --skip-build
./script/cicd/sign_release.sh --developer-id "<identity>"
./script/cicd/notarize_release.sh --keychain-profile <profile>
```

## Remaining Gates

- Public Release evidence is still incomplete without a real Developer ID-signed, notarized, stapled artifact.
- Signed artifact launch on a clean macOS account still needs recorded evidence.
- Some global accessibility checks remain manual because macOS menu-extra focus depends on system settings.

## Remaining Work

These items are intentionally parked here so the long reactivation run can stop
without losing the next useful slices.

| Area | Priority | Remaining work |
| --- | --- | --- |
| Public release proof | High | Run and record a Developer ID-signed, notarized, stapled release when Apple signing secrets are available. |
| Clean-account smoke | High | Install the packaged app in a fresh macOS user account and record launch, status-item, Preferences, fake Icinga fallback, and Quit evidence. |
| Backend compatibility | High | Add real-version smoke evidence for Nagios HTML CGI, Icinga HTML CGI, Icinga 2 API, Thruk JSON API, and Check_MK. Fake-server coverage exists, but real-version compatibility is still broader than the local stub can prove. |
| Update indicator | Medium | Add a weekly release-check indicator that informs the user when a newer GitHub release exists. |
| UI/UX/DX redesign | Medium | Redesign Preferences, status details, and empty/error states with verified light and dark mode screenshots. |
| Accessibility evidence | Medium | Replace remaining manual menu-extra accessibility checks with repeatable evidence where macOS automation allows it. |

## Documentation Map

- `README.md`: short overview and entrypoints.
- `docs/DEVELOPER_GUIDE.md`: local development workflow.
- `docs/RELEASE.md`: release packaging, signing, notarization, and metadata.
- `docs/USER_GUIDE.md`: user-facing setup and troubleshooting.
- `docs/DEPENDENCIES.md`: dependency and provenance inventory.
- `docs/adr/`: architecture decisions and rationale.
