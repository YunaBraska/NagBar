# ADR 0013: Realm Upgrade Cutoff Policy

Status: Accepted.

Date: 2026-06-30.

## Context

NagBar no longer embeds Realm or CocoaPods. Current configuration is stored in
`UserDefaults`, JSON files under Application Support, and Keychain.

Old public builds may leave `default.realm*` files behind. Reading their
contents inside the current app would require reintroducing Realm or shipping a
separate migration tool with a real previous-release Realm fixture.

## Decision

Do not silently ignore old Realm files and do not claim automatic import.

On startup, NagBar detects legacy `default.realm*` files in the known candidate
locations. If valid current monitoring JSON configuration is missing or
malformed, it writes:

```text
~/Library/Application Support/com.volendavidov.NagBar/upgrade-compatibility.json
```

The report states that this Realm-free build cannot import Realm contents and
that users must reconfigure monitoring instances or migrate through an earlier
bridge build.

If valid current monitoring JSON configuration exists, NagBar uses that
configuration and still reports the old Realm leftovers for maintainer
visibility.

## Consequences

Positive:

- no Realm dependency returns to the app;
- legacy-only users get an explicit diagnostic instead of a silent fake import;
- current JSON/UserDefaults/Keychain users keep their configuration.

Tradeoffs:

- direct automatic migration from Realm-only builds is unsupported in this
  release;
- release notes must call out the cutoff behavior.

## Verification

Focused storage verification:

```sh
xcodebuild test -workspace NagBar.xcworkspace -scheme NagBar -destination 'platform=macOS' -only-testing:NagBarTests/MonitoringInstancesTest
```

Result: 44 storage tests plus 4 diagnostics tests, 0 failures.
