# NagBar Roadmap

Status: In progress.

Roadmap statuses use:

- `Done`: implemented and verified with evidence.
- `Partial`: implemented in part, or covered only by compile/parser evidence.
- `In progress`: active work in this spike.
- `Planned`: accepted direction, not yet implemented.
- `Blocked`: cannot proceed without an external decision or resource.
- `Dismissed`: intentionally not pursuing.

## Milestone 0: Revival Baseline

Status: Done.

| Item | Status | Evidence |
| --- | --- | --- |
| Project builds with current Xcode | Done | Debug and Release `xcodebuild build` pass |
| Test target runs | Done | Full suite passes; current suite is 274 tests |
| Shared scheme exists for CI/CLI | Done | `NagBar.xcodeproj/xcshareddata/xcschemes/NagBar.xcscheme` |
| Runtime smoke launches release app | Done | Process confirmed; status-item, status-panel, About, Preferences, Monitoring Instances, Refresh, and Quit paths are verified without publishing screenshots |
| Test map exists | Done | `TEST_MAP.md` |

## Milestone 1: Behavior Guardrails

Status: Done.

| Item | Status | Evidence |
| --- | --- | --- |
| Parser fixtures for supported backends | Done | Nagios, Icinga, Icinga2, Thruk, and Check_MK parser tests cover happy paths, malformed ingress, and supported status variants; focused parser suite passes 34 tests |
| URL provider contracts | Done | `URLProviderTests` |
| Monitoring type persistence regression | Done | `MonitoringInstancesTest.testInitDefaultStoresMonitoringType` |
| Password persistence behavior | Done | Save/delete tests with fake keychain client |
| Fake Icinga/Nagios HTTP server | Done | `FakeIcingaServer` and load/auth tests |
| Command POST fake-server tests | Done | `LoadMonitoringDataFakeIcingaTests` covers Nagios/Icinga form commands and Icinga2 JSON commands; focused suite passes 13 tests |
| Check_MK login/session fake-server test | Done | `CheckMKHTTPClientFakeServerTests` covers cookie login, wrong password, unrelated cookies, Basic auth, and unauthorized connection checks; focused suite passes 6 tests |
| Check_MK command policy | Done | Check_MK now exposes only open-in-browser command capability; unsupported POST rejects explicitly |
| Error and malformed-data tests | Done | Check_MK empty/malformed rows and root-site URL handling, Icinga2 malformed JSON/missing host attrs/missing service state, Thruk malformed JSON/missing host state and unauthorized HTTP behavior, Nagios/Icinga malformed HTML/time fields, Nagios/Icinga non-2xx GET handling, malformed current monitoring JSON during Realm cutoff, invalid stored monitoring backend type rejection, server-login import/no-overwrite/malformed-storage recovery, status-panel right-click row/no-row behavior, monitoring-status-cell unreachable-remote error rendering, version-check malformed/missing-field handling, and audible-alarm no-op/ignored-status behavior covered; full suite passes 274 tests |

## Milestone 2: Dependency Reduction

Status: Done.

| Dependency | Status | Replacement |
| --- | --- | --- |
| SAMKeychain | Done | `Security.framework` adapter |
| SwiftyJSON | Done | `JSONValue` backed by `JSONSerialization` |
| Alamofire | Done | Foundation `URLSession` wrapper |
| PromiseKit | Done | Replaced by app-local `Promise` compatibility layer; no `PromiseKit` references remain, focused async/fake-server tests pass, full suite passes 274 tests, Release build passes |
| hpple | Done | Replaced by app-local tolerant HTML row parser for Nagios/Icinga CGI tables; no Hpple/hpple/TFHpple/XPath references remain, 23 focused Nagios/Icinga parser tests pass, full suite passes 274 tests, Release build passes |
| RealmSwift active storage | Done | Scalar settings moved to `UserDefaults`; filters, server login settings, and monitoring instances moved to Application Support JSON; focused monitoring suite passes 56 tests, full suite passes 274 tests, Release build passes |
| RealmSwift legacy import bridge | Done | Removed with CocoaPods; production upgrade compatibility moved to the Milestone 3 upgrade-path gate |
| CocoaPods | Done | `Podfile`, `Podfile.lock`, Pods workspace reference, Pods project wiring, and CI `pod install` step removed; Debug build, full suite, and Release build pass without Pods |

## Milestone 3: Production Release Pipeline

Status: In progress.

| Item | Status | Acceptance gate |
| --- | --- | --- |
| CI build/test | Done | GitHub Actions uses the project helper for full tests and Release build, validates helper shell syntax, and rejects reintroduced CocoaPods files or workspace/project references; local helper acceptance passes, but live GitHub runner evidence still requires pushing the branch |
| Local/private signing | Done | Default Release build uses explicit manual ad-hoc signing (`CODE_SIGN_IDENTITY = "-"`, no development team) for machines without an Apple developer account; `script/verify_release_signing.sh` defaults to local mode and now verifies `Signature=adhoc`, hardened runtime, no debug `get-task-allow` entitlement, and no TeamIdentifier |
| Developer ID signing | Partial | `script/sign_release.sh --developer-id IDENTITY` re-signs an existing Release app when a real Developer ID Application identity is installed; `script/verify_release_signing.sh --developer-id` validates signature, TeamIdentifier, hardened runtime, and Gatekeeper acceptance without requiring the verifier machine to own the private signing identity; final Done status still needs evidence from a real Developer ID artifact |
| Hardened runtime | Done | Release target explicitly enables hardened runtime and disables base entitlement injection; local Release build passes and `codesign -dvvv` reports `flags=0x10002(adhoc,runtime)` with no debug entitlement output |
| Notarization | Partial | `script/notarize_release.sh` submits a Developer ID signed app with `notarytool --wait`, staples and validates the `.app`, and `script/package_release.sh --developer-id` requires a stapled app before creating the public zip; final Done status still needs Apple acceptance evidence |
| Release packaging | Done | `script/package_release.sh` and `./script/build_and_run.sh --package` build Release, verify local/private signing, create `dist/NagBar-<version>-macOS.zip`, test the zip, and write a SHA-256 checksum; `.github/workflows/release.yml` creates date-versioned GitHub Releases, updates version/changelog metadata, uses local/private signing by default, and switches to Developer ID signing plus notarization when secrets are present |
| Upgrade path | Done | Current JSON/UserDefaults/Keychain configuration survives startup after the Realm/CocoaPods removal; legacy `default.realm*` leftovers are detected in both supported candidate locations and produce `upgrade-compatibility.json` with an explicit manual reconfiguration/cutoff message instead of silently claiming import; malformed current monitoring JSON with legacy leftovers is treated as manual reconfiguration |
| Crash/log diagnostics | Done | Structured `Logger` diagnostics cover startup snapshots, upgrade cutoff reports, storage write failures, refresh failures/completion, and local fake-server startup; focused diagnostics/storage slice passes 48 tests |
| Production readiness coverage gate | In progress | `NagBar.app` coverage is 76.32% from Xcode result metrics after 274 passing tests; `StatusBarAnimationTrigger.swift` is 100% covered, `MenuAction.swift` is 82.43% covered with `AddToFilterAction.addToFilter(_:)` at 100%, and `CheckNewVersion.swift` is 65.71% covered through injected request/alert/log boundaries; remaining high-yield gaps are AppKit-heavy `StatusBar.swift`, `PasswordPromptController.swift`, `AnimateStatusBar.swift`, `StatusPanelTableDelegate.swift` drawing/optional columns, and thin wrapper/default-init paths |

## Milestone 4: OSS Readiness

Status: Done.

| Item | Status | Evidence |
| --- | --- | --- |
| Open-source license | Done | Apache License 2.0 |
| README build/test docs | Done | `README.md` |
| Contribution guide | Done | `CONTRIBUTING.md` includes local workflow, test expectations, dependency policy, fixture hygiene, and PR checklist |
| Security policy | Done | `SECURITY.md` documents supported versions, private vulnerability reporting, sensitive areas, and disclosure expectations |
| Support policy | Done | `SUPPORT.md` documents supported issue types, useful diagnostics, and unsupported public-support data |
| Issue and PR templates | Done | `.github` templates cover bug reports, feature requests, PR verification, dependency updates, CocoaPods guardrails, and private-data hygiene; blank issues are disabled |
| ADRs | Done | `docs/adr` records dependency removal, fake-server, upgrade cutoff, local ad-hoc signing, package, and storage decisions |
| Release notes process | Done | `CHANGELOG.md` is the release-note source; `docs/RELEASE.md` defines pre-release gates, version bump fields, package/signing provenance, diagnostics commands, upgrade notes, and release-note template; `script/package_release.sh` writes a package manifest |

## Milestone 5: UX/DX Polish

Status: Done.

| Item | Status | Acceptance gate |
| --- | --- | --- |
| First-run setup path | Done | New user starts against a local fake Icinga HTTP server when no real backend exists, can open Settings from the status item, can reach Monitoring Instances from Settings, and can replace the fallback by saving a real Icinga-compatible remote without reading docs; replacement is covered through the same AppKit table controls/delegates used by the Settings editor, and live smoke proves isolated status-item Settings reachability plus add-row persistence |
| Single status-item entrypoint | Done | Status-item menu exposes Show Status, About, Preferences, Refresh, and Quit with stable accessibility identifiers; status-item refresh uses an injected entrypoint; status-panel opening guards missing first-refresh data; Release smoke opens the live status-item menu with AXPress, verifies Show Status opens `nagbar.statusPanel` with `nagbar.statusPanel.table`, verifies keyboard Down/Return activates Show Status, verifies Refresh keeps the status item alive, and quits through the same menu with keyboard navigation. Global keyboard focus into macOS menu extras is system-setting dependent and remains a manual accessibility check |
| Settings-owned About surface | Done | Preferences injects an About tab with version, build, bundle, license, and support information; status-item About routes into Preferences instead of the standard About panel; content, AppKit tab-builder, XIB-backed controller smoke tests, and Release UI smoke pass |
| Apple-menu product dependency removal | Done | Runtime policy removes intentional About and Preferences product routes from `NSApp.mainMenu`; AppKit may still keep a minimal system application menu and Quit/system behavior. Component coverage and `script/status_item_smoke.sh` live inspection prove About/Preferences product actions are stripped |
| Local fake Icinga fallback | Done | Implemented as a non-persisted normal Icinga instance pointed at an app-local loopback fake Icinga HTTP server when no configured remotes exist; deterministic host/service data is served by that server as Icinga-style HTML and parsed through the standard Icinga processor; production code contains no `Demo Mode` branch or string; a regression test keeps sample status strings fenced inside `LocalIcingaFallback.swift`; first-run status data is not hardcoded in views or status-panel code |
| Local fake Icinga safety | Done | Tests prove the fallback is local, loopback-bound, non-persisted, not named/credentialed as demo mode, connected through the normal Icinga HTTP client, replaced by configured remotes, excluded from password-prompt decisions, and uses the normal Icinga URL/client/parser/command surface against localhost; live smoke runs in isolated storage and proves the Settings path to Monitoring Instances plus add-row persistence |
| Preferences clarity | Done | Filter regex validation rejects empty/invalid host or service filters before save; runtime filtering ignores already-stored invalid regex safely; filter editor new/edit/cancel paths, host/service status mode toggling, selected persisted statuses, and host/service JSON writes are covered; backend selector lists every supported backend including Check_MK; monitoring URL validation rejects unsafe or incomplete remotes before they can suppress the local fallback; invalid stored backend types are ignored instead of crashing or silently downgrading; Monitoring Instances now labels Base URL, Auth Username, and Auth Password, explains per-instance authentication and Keychain storage, loads through the real XIB, persists edited name/type/url/auth fields through table controls, covers delegate view creation, enabled-checkbox disabling, async OK/error status rendering, rename nil-guard and notification behavior, opens through the Preferences data-feed bridge, covers server-login import/no-overwrite/malformed-storage recovery, passes the 56-test monitoring/preferences slice and the 251-test full suite, and survives the Release runtime smoke |
| Action feedback | Done | Command methods now return explicit `CommandResult` promises instead of logging failures only; status-menu recheck, acknowledge, schedule downtime, add-to-filter storage mutation, unsupported backend get-time/acknowledge/recheck/downtime rejection, stable command action labels, accepted fake-server commands, rejected fake-server auth, XIB-backed acknowledge/schedule submit paths, menu-action windows for selected status-panel items, and success/failure feedback presenter paths are covered; focused command/filter slices pass and full suite passes 274 tests |
| Accessibility pass | Done | Stable accessibility identifiers/labels exist for status-item main and failed buttons, status menu actions, status panel/table, Settings About content, Monitoring Instances table/status cells, and acknowledge/downtime command dialogs; Schedule Downtime formatter and fixed/flexible duration switching behavior are covered through XIB-backed tests; `StatusItemViewTests` passes 29 tests including animation trigger decisions, short/tall StatusPanel loading, accessible panel/table identifiers, capped height, scroll arrow behavior, status-panel context-menu command availability for single/multiple/mixed-instance selections, saved-login actions, unsupported-backend open-in-browser-only behavior, right-click row hit testing, outside-row nil handling, and SSH/RDP login submenu wiring; full suite passes 274 tests. Global macOS menu-extra focus and AppKit table-cell AX text editing remain manual QA |
| Developer one-command workflow | Done | `script/build_and_run.sh` is the canonical local helper: `--verify` builds, launches, and verifies the app; `--test` runs the full suite; `--release-build` builds Release; `--package` builds and packages a local/private Release zip; `--smoke` runs the live status-item smoke; `--acceptance` runs full tests, Release build, and live smoke. The configured local run action uses `./script/build_and_run.sh --verify`; shell syntax, help output, full tests, package creation, and `--acceptance` all pass |

## Backlog

| Item | Status | Acceptance gate |
| --- | --- | --- |
| Weekly update indicator | Planned | App checks GitHub Releases no more than weekly, avoids startup blocking, and informs the user when a newer released version exists |
| UI/UX/DX redesign with dark/light mode | Planned | Redesign keeps the status-item workflow fast, supports system light/dark appearance, improves Settings ergonomics, and preserves existing accessibility identifiers or migrates them with tests |
