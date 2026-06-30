# ADR 0011: Remove CocoaPods

Status: Accepted.

Date: 2026-06-30.

## Context

After replacing `SAMKeychain`, `SwiftyJSON`, `Alamofire`, `PromiseKit`,
`hpple`, and all active Realm-backed storage, CocoaPods only remained for the
Realm legacy import bridge.

## Decision

Remove CocoaPods from the build:

- remove `RealmSwift` from source imports;
- remove `Podfile` and `Podfile.lock`;
- remove the Pods workspace reference;
- remove Pods framework references, xcconfig references, and `[CP]` build phases
  from the Xcode project;
- remove `pod install` from CI and local docs.

Keep the existing workspace command path by retaining `NagBar.xcworkspace` with
only `NagBar.xcodeproj` inside it.

## Consequences

Positive:

- the app builds with Xcode alone;
- no vendored CocoaPods framework is embedded;
- dependency reduction Milestone 2 can close after verification.

Tradeoffs:

- existing Realm-backed user configuration no longer has automatic in-app import;
- the Realm-free release uses an explicit cutoff report for legacy-only
  `default.realm*` files instead of silently claiming migration.

## Verification

```sh
xcodebuild build -workspace NagBar.xcworkspace -scheme NagBar -destination 'platform=macOS'
xcodebuild test -workspace NagBar.xcworkspace -scheme NagBar -destination 'platform=macOS'
xcodebuild build -workspace NagBar.xcworkspace -scheme NagBar -configuration Release -destination 'platform=macOS'
```

Result: all three commands pass. Full suite result is 97 tests, 0 failures.
