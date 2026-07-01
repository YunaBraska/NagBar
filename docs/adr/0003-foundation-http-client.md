# ADR 0003: Use Foundation URLSession For HTTP

Status: Accepted

Date: 2026-06-30

## Context

NagBar previously used Alamofire for all backend HTTP requests, version checks,
and password prompt connection checks. The app only needs a small subset of that
surface:

- GET, HEAD, and POST;
- shared cookies;
- Basic auth retry for Nagios/Icinga/Check_MK;
- preemptive Basic auth for Thruk;
- JSON and form request bodies;
- optional invalid-certificate handling scoped to configured hosts.

## Decision

Use Foundation `URLSession` through `ConnectionManager` and keep the existing
`HTTPClient` Promise-based boundary for now.

`ConnectionManager` owns:

- shared `HTTPCookieStorage`;
- session configuration;
- per-host invalid certificate bypass;
- form encoding;
- JSON body encoding;
- Basic auth header generation;
- one retry after a `401` response when credentials are supplied.

## Consequences

Positive:

- Removes Alamofire from source and CocoaPods.
- Keeps current HTTP client public contracts intact.
- Reduces release bundle size and maintenance surface.

Negative:

- The wrapper must preserve legacy status-code behavior until tests allow
  tightening it.
- Invalid certificate handling still needs a local TLS test.
- Check_MK cookie login needs stronger fake-server coverage.

## Evidence

- Fake-server Nagios/Icinga load/auth tests pass.
- Full test suite passed when this ADR was accepted; the current suite is tracked in `docs/PROJECT_STATUS.md`.
- Release build passes without Alamofire.
- Dependency search finds no Alamofire references in app/test/project files.
