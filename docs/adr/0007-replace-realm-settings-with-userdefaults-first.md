# ADR 0007: Replace Realm Settings With UserDefaults First

Status: Accepted.

Date: 2026-06-30.

## Context

At the start of this migration, `RealmSwift` remained the last CocoaPods
dependency. It stored four small data groups:

- scalar settings;
- monitoring instances;
- filter rows;
- server login preferences.

The scalar settings are key/value strings and map directly to `UserDefaults`.
They are the smallest safe slice to remove from active Realm usage before the
larger collection migration.

## Decision

Move `Settings` reads and writes to `UserDefaults`.

Keep the legacy Realm `Setting` model temporarily in `InitConfig` so existing
Realm setting rows can be imported on launch while Realm is still present for
the remaining collections.

Default values live in `SettingDefaults` and are seeded through `Settings`.
Missing scalar settings return deterministic defaults instead of crashing on a
forced Realm lookup.

## Consequences

Positive:

- settings no longer create Realm objects during normal app use;
- tests can seed settings through the same public boundary as production code;
- missing settings fail soft with defaults instead of crashing;
- the remaining Realm migration is narrower.

Tradeoffs:

- Realm remains required for monitoring instances and one-release import of
  legacy scalar settings;
- `UserDefaults` is process-global, so tests must reset known setting keys
  before scenario-specific seeding;
- full Realm removal still needs JSON or property-list collection storage plus
  compatibility tests for existing user data.

## Verification

Focused persistence/settings verification passes:

```sh
xcodebuild test -workspace NagBar.xcworkspace -scheme NagBar -destination 'platform=macOS' -only-testing:NagBarTests/NagiosSettingsTests -only-testing:NagBarTests/MonitoringInstancesTest -only-testing:NagBarTests/FilterItemsProcessorTests -only-testing:NagBarTests/URLProviderTests -only-testing:NagBarTests/Icinga2ParserTests
```

Result: 30 tests, 0 failures.

## Next Steps

1. Done: replace `FilterItem`/`FilterItems` with Codable array storage under
   Application Support.
2. Done: replace `ServerLoginItem` with Codable storage keyed by host.
3. Done: replace `MonitoringInstance` storage with Codable array storage while keeping
   passwords in the existing keychain adapter.
4. Remove `RealmSwift`, `Realm`, CocoaPods integration, and legacy migration
   code after migration tests are green.
