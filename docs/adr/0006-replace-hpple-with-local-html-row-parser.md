# ADR 0006: Replace hpple With Local HTML Row Parser

Status: Accepted

Date: 2026-06-30

## Context

NagBar used `hpple` and XPath to parse legacy Nagios and Icinga `status.cgi`
HTML. The parser only needs a narrow subset of HTML behavior: table rows,
cells, anchors, images, input values, attributes, and common HTML entities.

Foundation `XMLParser` is not a safe replacement because the supported fixtures
are old HTML, not guaranteed XML. Keeping a full XPath dependency for this small
surface kept CocoaPods alive for behavior that NagBar can own directly.

## Decision

Replace `hpple`, `TFHpple`, and the XPath provider files with an app-local
tolerant HTML row parser inside `NagiosParser`.

The parser is intentionally scoped to current public behavior:

- Nagios/Icinga host rows;
- Nagios/Icinga service rows;
- grouped service host carry-forward;
- acknowledged and downtime icon detection;
- `start_time` and `end_time` input extraction;
- common named and numeric HTML entity decoding.

It is not a browser engine and should not grow into one. New backend formats
need public parser tests before parser behavior changes.

## Consequences

Positive:

- `hpple` is removed from CocoaPods, project references, app imports, tests, and
  built app frameworks.
- The Nagios/Icinga parser surface is now Swift-only and covered by focused
  fixture and parity tests.
- The dependency graph drops to Realm-only CocoaPods targets.

Negative:

- The local parser supports Nagios/Icinga CGI table shapes, not arbitrary HTML.
- Broader real-version samples are still useful before claiming exhaustive
  parser compatibility.

## Verification

- `xcodebuild test -workspace NagBar.xcworkspace -scheme NagBar -destination 'platform=macOS' -only-testing:NagBarTests/NagiosParserTests -only-testing:NagBarTests/IcingaParserTests` passes with 21 tests.
- Full suite passes with 89 tests.
- Release build passes.
- Search finds no Hpple/hpple/TFHpple/XPath references in app, tests, project,
  Podfile, lockfile, or CocoaPods support files.
