# Modernization Roadmap

Status: Active.

| Milestone | Outcome | Dependencies | Exit evidence | Status |
| --- | --- | --- | --- | --- |
| M0 | Preserve a known-good legacy baseline | none | Existing macOS suite passes | Done, 457 tests |
| M1 | Define provider-neutral sources, Icinga 2 endpoint rules, and real Keychain password storage | M0 | Swift package tests and legacy suite | Done, 19 package tests plus 457 legacy tests |
| M2 | Probe the real Icinga 2 API with Basic auth and all source trust modes | M1 | Public connection-result tests plus real TLS endpoints | In progress, Basic and per-source unchecked TLS work; custom CA and pinning remain |
| M3 | Select or import a Keychain identity and connect with mTLS | M2 | Real client-certificate success and failure tests | In progress, Keychain identity path and lab mTLS work; app-level mTLS proof remains |
| M4 | Replace the source editor with a native SwiftUI setup journey | M2, M3 | Running app journey for normal, empty, loading, and failure states | In progress, first-source setup is rendered and exercised |
| M5 | Run a reproducible Icinga 2 compatibility matrix | M2, M3 | Container tests for auth, TLS, permissions, rotation, and failure recovery | In progress, auth, authorization, private CA, and mTLS matrix passes |
| M6 | Present an attention-first monitoring snapshot in the menu bar | M4, M5 | Running product tests with realistic problem volume and hierarchy | Planned |
| M7 | Add supported actions and notifications without duplicating provider state | M6 | End-to-end acknowledge, downtime, refresh, and notification evidence | Planned |
| M8 | Remove replaced legacy UI, transport, fake first-run behavior, and duplicate settings | M4..M7 | Final diff, migration evidence, release build, smoke, and coverage review | Planned |
