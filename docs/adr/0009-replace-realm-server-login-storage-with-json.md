# ADR 0009: Replace Realm Server Login Storage With JSON

Status: Accepted.

Date: 2026-06-30.

## Context

Server login preferences are small local records keyed by monitoring host:

- `host`;
- `username`;
- `loginType`.

Realm was used only as a local object store for these rows. The menu action
surface already goes through `ServerLogin`, so the storage replacement can stay
behind that boundary.

## Decision

Store server login preferences as a Codable JSON array under Application
Support:

```text
~/Library/Application Support/com.volendavidov.NagBar/server-login.json
```

Keep the existing public behavior:

- menu actions remain `@objc` for AppKit target/action wiring;
- hosts remain keyed from `MonitoringItem.host`;
- `LoginType` raw values stay `ssh = 0`, `sshiTerm = 1`, and `rdp = 2`;
- a missing row returns no username and no login type;
- an empty username returns no username;
- an invalid login type raw value returns no login type;
- username-only legacy rows still imply `.ssh` because the historical default
  login type is `0`;
- updating username or login type preserves the other field;
- removing settings is idempotent.

During the Realm transition, `InitConfig` imports legacy Realm
`ServerLoginItem` rows into JSON when JSON storage is empty.

## Consequences

Positive:

- active server login preference storage no longer depends on Realm;
- tests seed the same storage boundary as production;
- storage is inspectable plain JSON;
- app-process read/modify/write operations are serialized with a lock and file
  writes are atomic.

Tradeoffs:

- there is no cross-process merge lock; NagBar is expected to be the only writer;
- legacy rows remain import-only until the Realm import bridge can be removed.

## Verification

Focused server-login verification passes:

```sh
xcodebuild test -project NagBar.xcodeproj -scheme NagBar -destination 'platform=macOS' -only-testing:NagBarTests/MonitoringInstancesTest/testServerLoginSettingsPersistUpdateAndRemoveByHost
```

Result: 1 test, 0 failures.

Focused monitoring-instance verification passes:

```sh
xcodebuild test -project NagBar.xcodeproj -scheme NagBar -destination 'platform=macOS' -only-testing:NagBarTests/MonitoringInstancesTest
```

Result: 8 tests, 0 failures.

Full verification passes:

```sh
xcodebuild test -project NagBar.xcodeproj -scheme NagBar -destination 'platform=macOS'
```

Result: 97 tests, 0 failures.

Release build passes:

```sh
xcodebuild build -project NagBar.xcodeproj -scheme NagBar -configuration Release -destination 'platform=macOS'
```
