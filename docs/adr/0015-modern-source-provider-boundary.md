# ADR 0015: Modern Sources Use a Provider Boundary

Status: Accepted.

Date: 2026-11-10.

## Context

The revived application mixes provider selection, credentials, URL generation,
transport, parsing, persistence, and AppKit table editing. Extending that model
for Icinga 2 mTLS and source-specific trust would spread more provider and
security conditionals through legacy code.

Icinga 2 is the first required backend, while Nagios-compatible and other tools
must remain possible. There is no current requirement for third-party binary
plug-ins.

## Decision

Build the new implementation behind a small provider-neutral source model and a
single registry of built-in providers.

Shared code owns source lifecycle, persistence semantics, refresh policy,
connection results, and presentation state. Providers own endpoint constraints,
transport details, authentication challenges, response decoding, and optional
capabilities.

The new core starts as a local Swift package. Complete user journeys move from
the legacy target one at a time. The old implementation is removed only after a
replacement journey has executable evidence.

Dynamic plug-in loading is excluded until a real third-party extension
requirement exists.

## Consequences

- Icinga 2 can be implemented and tested without making it the shared data
  model.
- A second provider changes one adapter and one registration point.
- Secrets and TLS behavior have one modern boundary instead of inheriting the
  existing global connection manager.
- Both implementations temporarily coexist. The roadmap must finish vertical
  migrations and remove replaced legacy paths rather than maintaining both.
