# ADR 0002: Replace Legacy Dependencies In Small Slices

Status: Accepted

Date: 2026-06-30

## Context

NagBar used several legacy dependencies through CocoaPods. Some blocked current
builds, increased release surface, or duplicated Foundation capabilities.

Already removed:

- `SAMKeychain`
- `SwiftyJSON`
- `Alamofire`
- `PromiseKit`
- `hpple`

Remaining:

- `RealmSwift`

## Decision

Replace dependencies one category at a time only after behavior tests exist for
the affected surface.

Current replacements:

| Removed dependency | Replacement |
| --- | --- |
| `SAMKeychain` | `Security.framework` adapter |
| `SwiftyJSON` | `JSONValue` backed by `JSONSerialization` |
| `Alamofire` | Foundation `URLSession` wrapper in `ConnectionManager` |
| `PromiseKit` | App-local `Promise` compatibility layer |
| `hpple` | App-local tolerant HTML row parser for Nagios/Icinga CGI tables |

## Consequences

Positive:

- Each removal has a focused blast radius.
- Regressions are easier to isolate.
- The app moves toward a smaller and more maintainable dependency surface.

Negative:

- The transition leaves mixed old/new patterns temporarily.
- Remaining dependency removals need more test coverage first.

## Required Follow-Up

Before removing `PromiseKit`, tests were added or tightened for:

- command POST request bodies;
- Icinga 2 command JSON POST behavior;
- Thruk preemptive auth behavior;
- Check_MK login/session cookie behavior.

`PromiseKit` is now removed. Keep future async work focused on public
entrypoint behavior before expanding or replacing the compatibility layer.

Before removing `RealmSwift`, add migration tests for:

- monitoring instances;
- settings;
- filters;
- password lookup behavior.
