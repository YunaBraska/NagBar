# ADR 0011: Remove CocoaPods

Status: Accepted.

Date: 2026-06-30.

## Context

After replacing `SAMKeychain`, `SwiftyJSON`, `Alamofire`, `PromiseKit`,
`hpple`, and all active Realm-backed storage, CocoaPods only remained for the
temporary cleanup bridge.

## Decision

Remove CocoaPods from the build:

- remove `RealmSwift` from source imports;
- remove `Podfile` and `Podfile.lock`;
- remove the Pods workspace reference;
- remove Pods framework references, xcconfig references, and `[CP]` build phases
  from the Xcode project;
- remove `pod install` from CI and local docs.
- use the plain Xcode project path as the single local and CI build entrypoint.

## Consequences

Positive:

- the app builds with Xcode alone;
- no vendored CocoaPods framework is embedded;
- dependency reduction Milestone 2 can close after verification.

Tradeoffs:

- existing Realm-backed user configuration no longer has automatic in-app import.

## Verification

```sh
xcodebuild build -project NagBar.xcodeproj -scheme NagBar -destination 'platform=macOS'
xcodebuild test -project NagBar.xcodeproj -scheme NagBar -destination 'platform=macOS'
xcodebuild build -project NagBar.xcodeproj -scheme NagBar -configuration Release -destination 'platform=macOS'
```

Result: all three commands pass. Full suite result is 97 tests, 0 failures.
