# ADR 0012: First-Run Local Fake Icinga Fallback

Status: Accepted.

Date: 2026-06-30.

## Context

NagBar should be useful on first launch even before a real monitoring backend is
configured. The first-run experience must exercise the same Icinga URL, HTTP,
parser, and command behavior as a real backend instead of using app-side
hardcoded monitoring records.

## Decision

Add a non-persisted normal Icinga monitoring instance that appears only when
there are zero configured monitoring remotes. Its URL points at an app-local fake
Icinga HTTP server bound to `127.0.0.1`.

The local fake Icinga fallback:

- is not persisted to monitoring instance JSON;
- uses the normal Icinga URL provider, HTTP client, parser, and command
  implementation;
- returns deterministic Icinga-style `status.cgi` HTML over HTTP;
- answers Basic-auth challenges like a real Icinga/Nagios CGI endpoint;
- accepts command posts locally so command UI remains realistic without remote
  side effects;
- is excluded from password-prompt decisions;
- disappears as soon as any real monitoring instance is configured.

## Consequences

Positive:

- first-run users see useful status data instead of an empty app;
- the fallback uses the same refresh pipeline as real Icinga backends;
- production views do not branch on `Demo Mode` or carry their own sample
  monitoring records;
- command actions are safe because they terminate at localhost.

Tradeoffs:

- replacement after saving a real remote is covered through the same stored fields and AppKit table controls/delegates the Settings editor writes, and live smoke proves the status-item path reaches the Monitoring Instances editor;
- full end-to-end AX text editing inside AppKit table cells remains a manual accessibility check because System Events does not deterministically enter the table cell editor;
- Preferences should make the transition from the local fake Icinga fallback to a real backend obvious.

## Verification

```sh
xcodebuild test -workspace NagBar.xcworkspace -scheme NagBar -destination 'platform=macOS' -only-testing:NagBarTests/MonitoringInstancesTest -only-testing:NagBarTests/URLProviderTests -only-testing:NagBarTests/StatusItemViewTests
xcodebuild test -workspace NagBar.xcworkspace -scheme NagBar -destination 'platform=macOS'
xcodebuild build -workspace NagBar.xcworkspace -scheme NagBar -configuration Release -destination 'platform=macOS'
```

Result: focused monitoring-instance fallback suite passes 22 tests after the local fake-Icinga conversion;
full suite passes 274 tests, coverage reports 76.32% for `NagBar.app`, Release build
succeeds, and `script/status_item_smoke.sh` proves isolated status-item Settings reachability plus Monitoring Instances add-row persistence without publishing desktop screenshots.
