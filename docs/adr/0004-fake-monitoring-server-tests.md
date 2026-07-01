# ADR 0004: Use Fake Monitoring Servers For Protocol Tests

Status: Accepted

Date: 2026-06-30

## Context

NagBar integrates with external monitoring systems that are difficult to run in
CI for every backend and every edge case. Parser fixtures cover data format
behavior, but they do not prove HTTP behavior such as authentication retries,
headers, cookies, or POST bodies.

## Decision

Use small local fake servers in tests for backend protocol behavior.

The fake server should:

- listen on localhost;
- handle real HTTP requests;
- record method, path, query, auth header, and body;
- simulate normal backend auth/status behavior;
- return fixture-backed host/service data.

## Consequences

Positive:

- Tests cover real network boundaries without depending on external systems.
- Dependency migrations can preserve protocol behavior.
- CI can run tests deterministically.

Negative:

- Fake servers must be kept close enough to real backend behavior.
- They do not replace compatibility tests against real Nagios/Icinga/Thruk/Check_MK installations.

## Required Follow-Up

Current fake-server coverage includes Nagios/Icinga load/auth tests,
Nagios/Icinga form command POSTs, Icinga 2 JSON command POSTs, Thruk
preemptive Basic authentication with curl user-agent behavior, and Check_MK
cookie/basic-auth session behavior.

Remaining fake-server coverage:

- optional local TLS invalid-certificate behavior.
