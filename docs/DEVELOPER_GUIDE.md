# Developer Guide

Status: In progress.

## Local Setup

Install:

- macOS 12.4 or newer build target
- Xcode

Then run:

```sh
open NagBar.xcworkspace
```

## Build

```sh
./script/build_and_run.sh --release-build
```

## Build And Run

```sh
./script/build_and_run.sh --verify
```

The Codex desktop Run action points at the same command through
`.codex/environments/environment.toml`.

## Test

```sh
./script/build_and_run.sh --test
```

Focused fake-server tests:

```sh
xcodebuild test -workspace NagBar.xcworkspace -scheme NagBar -destination 'platform=macOS' -only-testing:NagBarTests/LoadMonitoringDataFakeIcingaTests
```

## Release Build

```sh
./script/build_and_run.sh --release-build
```

The current release build is local-sign only. Do not treat it as a public
distribution artifact until `docs/PRODUCTION_READINESS.md` gates are met.

## Test Strategy

Preferred order:

1. Public-entrypoint tests.
2. Fake local HTTP servers for backend protocol behavior.
3. Parser fixture tests for backend data formats.
4. Persistence tests with isolated in-memory stores.
5. UI/runtime smoke for release builds.

Avoid private-helper tests unless there is no practical public boundary.

## Dependency Strategy

Current remaining pods: none.

The maintained dependency inventory lives in `docs/DEPENDENCIES.md`.

Replacement rules:

1. Add or tighten behavior tests first.
2. Replace one dependency category at a time.
3. Run focused tests, full tests, and release build after each replacement.
4. Update `ROADMAP.md`, `TEST_MAP.md`, and ADRs with the result.

## Runtime Smoke

```sh
./script/status_item_smoke.sh
```

## One-Command Verification

```sh
./script/build_and_run.sh --acceptance
```

This runs the full macOS test suite, builds Release, then runs the live
status-item smoke. Use it before handing a milestone to review.

Additional workflow modes:

```sh
./script/build_and_run.sh --logs
./script/build_and_run.sh --telemetry
./script/build_and_run.sh --debug
```

The live smoke requires Accessibility permission for the invoking terminal or
runner process. It builds and launches the Release app with isolated storage
and defaults, verifies the menu-bar status item through System Events, opens
the status panel, reaches the Monitoring Instances editor from status-item
Settings, proves add-row persistence in disposable JSON storage, captures
screenshots, and quits through the status-item menu.

Automated smoke opens the menu extra with Accessibility `AXPress`, then verifies
keyboard navigation inside the opened menu. Full global keyboard focus into
macOS menu extras is controlled by system keyboard settings and belongs in
manual accessibility QA.

Do not publish screenshots without checking for private desktop contents; crop
screenshots before using them in README material.
