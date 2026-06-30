# ADR 0010: Replace Realm Monitoring Instance Storage With JSON

Status: Accepted.

Date: 2026-06-30.

## Context

Monitoring instances are the core user configuration records. The persisted
fields are:

- `name`;
- `url`;
- `privateType`;
- `username`;
- `enabled`.

Passwords are intentionally runtime/keychain data and must not be written into
JSON.

## Decision

Store monitoring instances as a Codable JSON array under Application Support:

```text
~/Library/Application Support/com.volendavidov.NagBar/monitoring-instances.json
```

Keep existing public behavior:

- `MonitoringInstance` remains a mutable reference type;
- `MonitoringInstanceType` raw values stay unchanged;
- `password` remains excluded from persisted storage;
- passwords are rehydrated by instance name from `PasswordStore` first, then
  Keychain when `savePassword` is enabled;
- `getAll()` returns a dictionary keyed by instance name;
- duplicate names collapse to the last stored row in the dictionary view;
- `getKeyById(_:)` keeps case-insensitive sorted row ordering;
- `getAllEnabled()` includes only rows with `enabled == 1`;
- `MonitoringInstance` remains hashable by object identity for refresh failure
  tracking.

During the Realm transition, `InitConfig` imports legacy Realm
`MonitoringInstance` rows into JSON when JSON storage is empty.

## Consequences

Positive:

- active monitoring-instance storage no longer depends on Realm;
- the main user configuration is now inspectable JSON;
- tests cover password exclusion, duplicate-name collapse, enabled filtering,
  and sorted row behavior;
- all active persistence categories are now off Realm.

Tradeoffs:

- Realm and CocoaPods were removed after active storage moved to JSON;
- old Realm-backed user configuration is covered by the explicit cutoff report
  policy in ADR 0013 rather than an in-app Realm import bridge;
- malformed JSON currently falls back to an empty collection, matching the
  previous fail-soft direction but still needing visible diagnostics.

## Verification

Focused monitoring-instance verification passes:

```sh
xcodebuild test -workspace NagBar.xcworkspace -scheme NagBar -destination 'platform=macOS' -only-testing:NagBarTests/MonitoringInstancesTest
```

Result: 11 tests, 0 failures.

Full verification passes:

```sh
xcodebuild test -workspace NagBar.xcworkspace -scheme NagBar -destination 'platform=macOS'
```

Result: 97 tests, 0 failures.

Release build passes:

```sh
xcodebuild build -workspace NagBar.xcworkspace -scheme NagBar -configuration Release -destination 'platform=macOS'
```
