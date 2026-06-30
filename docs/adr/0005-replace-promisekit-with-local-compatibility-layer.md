# ADR 0005: Replace PromiseKit With Local Compatibility Layer

Status: Accepted

Date: 2026-06-30

## Context

NagBar used `PromiseKit` for HTTP, command, and monitoring refresh flows. A
full async/await rewrite would touch a large part of the legacy AppKit code at
once. The immediate modernization goal is to shrink the CocoaPods surface while
keeping existing public behavior stable.

## Decision

Replace `PromiseKit` with an app-local `Promise<Value>` compatibility layer
backed by `Result`, callback lists, and a serial dispatch queue.

The compatibility layer supports only the API shape currently used by NagBar:

- immediate fulfilled values;
- asynchronous fulfill/reject;
- `then`;
- `done`;
- `recover`;
- `catch`.

It is not a new general-purpose async abstraction. New behavior should prefer a
small public-entrypoint test first, then either existing callback boundaries or
a deliberate Swift concurrency migration.

## Consequences

Positive:

- `PromiseKit` is removed from `Podfile`, `Podfile.lock`, project embed phases,
  app imports, and test imports.
- Existing call sites can compile with small, reviewable changes.
- Fake-server HTTP and command tests continue to exercise the real async paths.

Negative:

- The app still has promise-style control flow until a larger async migration is
  planned.
- The compatibility layer must stay intentionally small; expanding it would
  recreate a dependency in local form.

## Verification

- Focused async/fake-server suite passes with 25 tests.
- Full suite passed when this ADR was accepted; the current suite is tracked in `TEST_MAP.md`.
- Release build passes.
- `rg "PromiseKit"` returns no matches in app, tests, project, Podfile, lockfile,
  or CocoaPods support files.
