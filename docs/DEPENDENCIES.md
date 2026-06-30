# Dependency And License Inventory

Status: Maintained.

NagBar is intentionally dependency-light. CocoaPods has been removed; there is
no `Podfile`, `Podfile.lock`, or `Pods.xcodeproj` in the supported build path.

## Runtime Dependencies

| Dependency | Source | License / notice | Use |
| --- | --- | --- | --- |
| macOS AppKit/Foundation/Security/Network/os | Apple platform SDK | Apple SDK terms | Native UI, HTTP/session handling, Keychain, loopback fake server, structured logging |
| Bundled audio assets | See `NOTICE` | See `NOTICE` | Optional audible alerts |

## Removed Dependencies

| Previous dependency | Status | Replacement |
| --- | --- | --- |
| Alamofire | Removed | Foundation `URLSession` through `ConnectionManager` |
| PromiseKit | Removed | App-local `Promise` compatibility layer |
| RealmSwift | Removed | `UserDefaults` and JSON storage under Application Support |
| SAMKeychain | Removed | Local `Security.framework` wrapper |
| SwiftyJSON | Removed | `JSONSerialization` through `JSONValue` |
| hpple | Removed | App-local tolerant HTML row parser |
| CocoaPods | Removed | Xcode workspace/project build with no pod install step |

## Maintainer Checklist

Before adding a dependency:

1. Prefer Apple SDK or Swift standard-library APIs first.
2. Add or update an ADR explaining the tradeoff.
3. Add behavior tests covering the dependency boundary.
4. Update this file, `NOTICE`, `README.md`, and `docs/OSS_READINESS.md`.
5. Confirm `.github/workflows/ci.yml` still rejects CocoaPods reintroduction
   unless a future ADR explicitly reverses that policy.
