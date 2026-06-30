![](NagBar/Images.xcassets/AppIcon.appiconset/nagbarpng128.png)

# NagBar

NagBar is a native macOS status bar client for Nagios-compatible monitoring
systems. It reads host and service status from Nagios, Icinga, Icinga 2, Thruk,
and Check_MK, then shows the current problem state from the menu bar.

This fork exists to reactivate and modernize the project while preserving
credit to the original creator, Volen Davidov. The revival work should not erase
that authorship trail.

![](screenshot.png)

The first-run view is backed by a loopback fake Icinga HTTP server and the
normal Icinga URL/client/parser path. It is not a hardcoded `Demo Mode` branch.

## Project Status

Status: In progress revival spike.

Current evidence:

- `xcodebuild test -workspace NagBar.xcworkspace -scheme NagBar -destination 'platform=macOS'` passes with 324 tests.
- `xcodebuild build -workspace NagBar.xcworkspace -scheme NagBar -configuration Release -destination 'platform=macOS'` passes.
- `./script/build_and_run.sh --acceptance` passes full tests, Release build, and live runtime smoke through one local helper.
- `./script/build_and_run.sh --package` creates a local/private Release zip, SHA-256 checksum, and manifest under `dist/`.
- `.github/workflows/release.yml` can create date-versioned GitHub Releases,
  updates the changelog/version metadata, packages with local/private signing by
  default, and switches to Developer ID signing plus notarization when the
  required secrets are present.
- Release runtime smoke passes on the maintainer machine; `script/status_item_smoke.sh` runs with isolated app storage/defaults, verifies the status-item menu, Show Status onscreen panel, keyboard menu activation, Refresh, Apple-menu product-action removal, onscreen Preferences, and Quit.
- Public docs keep only app-owned image assets. Smoke screenshots are opt-in local artifacts because full-screen captures can expose private desktop data.
- Removed dependencies: `SAMKeychain`, `SwiftyJSON`, `Alamofire`, `PromiseKit`, `hpple`, `RealmSwift`, and CocoaPods.
- Remaining CocoaPods: none. Active scalar settings are on `UserDefaults`;
  filters, server login preferences, and monitoring instances are stored as JSON.
- Upgrade cutoff: current JSON/UserDefaults/Keychain configuration is preserved.
  Legacy Realm-only `default.realm*` configuration is detected and reported in
  `upgrade-compatibility.json`, but is not imported by this Realm-free build.
  Malformed current monitoring JSON plus legacy Realm leftovers is treated as a
  manual reconfiguration case.
- Structured diagnostics use the `com.volendavidov.NagBar` log subsystem for
  startup, storage, refresh, and local fake-server events. Use
  `./script/build_and_run.sh --telemetry` or `--logs` for maintainer triage.

Not production-distribution ready yet:

- The current release build is signed with local/private ad-hoc signing by
  default (`CODE_SIGN_IDENTITY = "-"`), so an Apple developer account is not
  required for local builds.
- Hardened runtime is enabled for Release; public distribution still requires a
  real Developer ID certificate and Apple notarization evidence.
- `./script/verify_release_signing.sh` verifies the local/private signing path.
  `./script/sign_release.sh`, `./script/notarize_release.sh`, and
  `./script/package_release.sh --developer-id` provide the explicit public
  release path for maintainers with a Developer ID Application certificate.
- Coverage is currently 83.17% for `NagBar.app` from Xcode result metrics; the production target
  remains about 95%.
- Users upgrading directly from a Realm-only build need release-note guidance to
  reconfigure or migrate through an earlier bridge build.

## Supported Monitoring Backends

| Backend | Status | Evidence |
| --- | --- | --- |
| Nagios HTML status CGI | Partial | Parser tests and URL provider tests |
| Icinga HTML status CGI | Partial | Parser tests plus fake-server HTTP load test |
| Icinga 2 API | Partial | Parser and URL provider tests |
| Thruk JSON API | Partial | Parser and URL provider tests |
| Check_MK | Partial | Parser and URL provider tests |

See [TEST_MAP.md](TEST_MAP.md) for the current behavior map and gaps.

Release and maintenance docs:

- [Roadmap](ROADMAP.md)
- [Test map](TEST_MAP.md)
- [Changelog](CHANGELOG.md)
- [Release process](docs/RELEASE.md)
- [Production readiness](docs/PRODUCTION_READINESS.md)
- [Dependency inventory](docs/DEPENDENCIES.md)
- [OSS readiness](docs/OSS_READINESS.md)

## Build

Requirements:

- macOS 12.4 or newer build target
- Xcode installed

Commands:

```sh
./script/build_and_run.sh --release-build
```

Build and launch locally:

```sh
./script/build_and_run.sh --verify
```

Run the live status-item smoke:

```sh
./script/status_item_smoke.sh
```

Open in Xcode:

```sh
open NagBar.xcworkspace
```

## Test

```sh
./script/build_and_run.sh --test
```

## Diagnostics

Maintainer triage logs:

```sh
./script/build_and_run.sh --logs
./script/build_and_run.sh --telemetry
```

Do not share credentials, tokens, private hostnames, private monitoring URLs, or
uncropped screenshots in public issues.

Focused fake-server HTTP test:

```sh
xcodebuild test -workspace NagBar.xcworkspace -scheme NagBar -destination 'platform=macOS' -only-testing:NagBarTests/LoadMonitoringDataFakeIcingaTests
```

Release build:

```sh
./script/build_and_run.sh --release-build
```

Full local milestone verification:

```sh
./script/build_and_run.sh --acceptance
```

## Documentation

- [SPEC.md](SPEC.md): product behavior and acceptance boundaries
- [ROADMAP.md](ROADMAP.md): milestone plan and status
- [TEST_MAP.md](TEST_MAP.md): current tests, gaps, and verification commands
- [docs/PRODUCTION_READINESS.md](docs/PRODUCTION_READINESS.md): release gates
- [docs/DEPENDENCIES.md](docs/DEPENDENCIES.md): dependency and license inventory
- [CHANGELOG.md](CHANGELOG.md): release-note source
- [docs/OSS_READINESS.md](docs/OSS_READINESS.md): open-source readiness checklist
- [docs/DEVELOPER_GUIDE.md](docs/DEVELOPER_GUIDE.md): local development workflow
- [docs/USER_GUIDE.md](docs/USER_GUIDE.md): user-facing workflows
- [docs/adr](docs/adr): architecture decisions

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## Security

See [SECURITY.md](SECURITY.md).

## License

NagBar is licensed under the Apache License 2.0. See [LICENSE](LICENSE).
Third-party asset notices are listed in [NOTICE](NOTICE).
