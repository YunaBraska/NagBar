# Developer Guide

Status: Active.

## Local Setup

Requirements:

- macOS 12.4 or newer
- Xcode
- Docker Desktop for the real Icinga 2 integration lab

Open the workspace:

```sh
open NagBar.xcworkspace
```

## Daily Commands

| Task | Command |
| --- | --- |
| Build and launch | `./script/build_and_run.sh --verify` |
| Full test suite | `./script/build_and_run.sh --test` |
| Release build | `./script/build_and_run.sh --release-build` |
| Runtime smoke | `./script/build_and_run.sh --smoke` |
| Local acceptance | `./script/build_and_run.sh --acceptance` |
| Local/private package | `./script/build_and_run.sh --package` |
| Logs | `./script/build_and_run.sh --logs` |
| Telemetry | `./script/build_and_run.sh --telemetry` |
| Debug under lldb | `./script/build_and_run.sh --debug` |

Release-only helpers live under `script/cicd/`.

## Modern Preview

The new source journey is a separate macOS 14 preview target in the existing
workspace. It uses the local `NagBarCore` Swift package and does not replace the
legacy app yet.

```sh
swift test --package-path Packages/NagBarCore
xcodebuild build -workspace NagBar.xcworkspace -scheme NagBarModern \
  -configuration Debug -destination 'platform=macOS' \
  SYMROOT="$PWD/build-modern"
open build-modern/Debug/NagBarModern.app
```

Regenerate `ModernNagBar/NagBarModern.xcodeproj` after changing
`ModernNagBar/project.yml`:

```sh
cd ModernNagBar
xcodegen generate
```

Run the real Icinga 2 compatibility lab after creating the ignored
`integration/icinga2/.env.local` from `.env.example`:

```sh
./script/icinga2_lab.sh start
./script/icinga2_lab.sh verify
./script/icinga2_lab.sh stop
```

Generated CA and PKCS#12 files are written to the external directory selected
by `NAGBAR_ICINGA_ARTIFACTS_DIR`. No integration password is committed.

Focused fake-server coverage:

```sh
xcodebuild test -workspace NagBar.xcworkspace -scheme NagBar -destination 'platform=macOS' -only-testing:NagBarTests/LoadMonitoringDataFakeIcingaTests
xcodebuild test -workspace NagBar.xcworkspace -scheme NagBar -destination 'platform=macOS' -only-testing:NagBarTests/CheckMKHTTPClientFakeServerTests
xcodebuild test -workspace NagBar.xcworkspace -scheme NagBar -destination 'platform=macOS' -only-testing:NagBarTests/URLProviderTests
xcodebuild test -workspace NagBar.xcworkspace -scheme NagBar -destination 'platform=macOS' -only-testing:NagBarTests/StatusItemViewTests
```

## Testing Priorities

Preferred order:

1. Public entrypoints.
2. Fake local HTTP servers for backend protocol behavior.
3. Parser fixtures for backend data shapes.
4. Persistence tests with isolated storage or fake Keychain boundaries.
5. Live runtime smoke for Release builds.

Avoid private-helper tests unless there is no practical public boundary.

## Documentation Ownership

- Update `docs/PROJECT_STATUS.md` when behavior, verification evidence, or release gates change.
- Update `docs/USER_GUIDE.md` when user workflow changes.
- Update `docs/RELEASE.md` when packaging, signing, or release automation changes.
- Update `docs/DEPENDENCIES.md` and `NOTICE` when dependency or asset provenance changes.
- Update ADRs for architecture decisions or long-lived tradeoffs.

## Smoke Notes

The live smoke requires Accessibility permission for the invoking terminal or
runner process. It launches the Release app with isolated storage and defaults,
verifies the status-item menu through System Events, opens the status panel,
opens Preferences through the status item, and quits through the same menu.

Automated smoke and tests use `AXPress` on the menu extra and validate named
menu items after the menu opens. Full global keyboard focus into macOS menu
extras is still a manual accessibility check because system settings control
that path.

Do not publish full-screen screenshots without checking for private desktop
contents first.
