# ADR 0008: Replace Realm Filter Storage With JSON

Status: Accepted.

Date: 2026-06-30.

## Context

Filter rows are small local records containing:

- `host`;
- `service`;
- `status`.

Realm was used only as a local object store. The app already exposes filter
behavior through `FilterItems`, so replacing the backing store can stay narrow.

## Decision

Store filters as a Codable JSON array under Application Support:

```text
~/Library/Application Support/com.volendavidov.NagBar/filter-items.json
```

Keep the existing public behavior:

- `FilterItem` remains mutable and `initDefault` mutates and returns `self`;
- generated keys remain `host + service`;
- `getAll()` still exposes a dictionary keyed by that generated key;
- duplicate generated keys still collapse in the dictionary view;
- `insert(key:value:)` appends the stored item and keeps deriving the observable
  key from the stored `host` and `service`;
- `getKeys()` remains case-sensitive sorted;
- `getById()` and `removeById()` keep the existing case-insensitive key sort.

During the Realm transition, `InitConfig` imports legacy Realm `FilterItem` rows
into JSON when JSON storage is empty.

## Consequences

Positive:

- active filter storage no longer depends on Realm;
- tests seed filters through the same public storage boundary as production;
- filter persistence is now inspectable plain JSON.

Tradeoffs:

- the historical `host + service` key collision remains for compatibility;
- JSON writes are atomic at the file level, but higher-level read/modify/write
  filter merges are still not transactionally serialized;
- Realm remains only for temporary legacy import.

## Verification

Focused filter verification passes:

```sh
xcodebuild test -workspace NagBar.xcworkspace -scheme NagBar -destination 'platform=macOS' -only-testing:NagBarTests/FilterItemsProcessorTests
```

Result: 4 tests, 0 failures.

Full verification passes:

```sh
xcodebuild test -workspace NagBar.xcworkspace -scheme NagBar -destination 'platform=macOS'
```

Result: 97 tests, 0 failures.

Release build passes:

```sh
xcodebuild build -workspace NagBar.xcworkspace -scheme NagBar -configuration Release -destination 'platform=macOS'
```
