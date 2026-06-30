# NagBar Specification

Status: In progress.

This document defines the intended product behavior. `TEST_MAP.md` records
which parts are currently verified.

## Product Goal

NagBar provides a native macOS menu bar view of Nagios-compatible monitoring
state. It should make active problems visible, let users inspect affected hosts
and services quickly, and expose common operational actions without requiring a
browser-first workflow.

## Users

| User | Goal |
| --- | --- |
| Operator | See current monitoring problems from the menu bar |
| On-call engineer | Open a problem in the monitoring system and take action |
| Maintainer | Build, test, package, and release the app reproducibly |
| Contributor | Add backend support or fix parser behavior safely |

## Supported Backends

| Backend | Status | Notes |
| --- | --- | --- |
| Nagios | Partial | HTML `status.cgi` parsing, URL generation, HTTP auth behavior, and form command POSTs covered |
| Icinga | Partial | HTML `status.cgi` parsing, fake-server load, and form command POSTs covered |
| Icinga 2 | Partial | API URL generation, JSON parser, and JSON command POSTs covered |
| Thruk | Partial | JSON parser and URL generation covered |
| Check_MK | Partial | Parser, URL generation, and fake-server login/session behavior covered |

## Core Use Cases

| Use case | Acceptance criteria | Status |
| --- | --- | --- |
| Add monitoring instance | User can configure name, URL, backend type, username, password, and enabled flag | Partial |
| Use app from status item | User can open status, Settings, About, refresh, and quit from the menu bar status item without needing the Dock/application menu or Apple-logo app menu | Partial |
| Use Settings as product home | Settings includes backend setup, filters, commands, alarms, About/version/license/support information, and the path to leave the local fake Icinga fallback by adding a real backend | Partial |
| First-run local fake Icinga fallback | If no monitoring remote is configured, the app starts a local fake Icinga HTTP server and connects to it through a normal non-persisted `.Icinga` monitoring instance; the fallback is not a hardcoded `Demo Mode` data branch and disappears after any real remote is saved | Partial |
| Persist monitoring instance | Instance survives app restart and selects the configured backend type | Done |
| Store password securely | Password persists only when user settings allow it | Done |
| Fetch monitoring data | App requests backend host/service URLs and parses status items | Partial |
| Show status in menu bar | Current status is visible from the menu bar | Partial |
| Open item in browser | User can open a monitoring item URL | Partial |
| Filter hidden items | User filters host/service/status combinations | Partial |
| Respect scheduled downtime | Services can be filtered when their host is in scheduled downtime | Partial |
| Run commands | Acknowledge, recheck, and downtime commands should submit backend-specific requests | Partial |
| Notify user | User can receive configured notifications/audible alarms | Partial |

## HTTP Behavior

| Behavior | Requirement |
| --- | --- |
| Cookies | Use shared cookie storage for backend sessions |
| Invalid certificates | If enabled, bypass TLS trust only for configured monitoring instance hosts |
| Nagios/Icinga auth | Send initial unauthenticated request, then retry with Basic auth on `401` |
| Thruk auth | Send Basic auth preemptively and set `User-agent: curl` |
| Icinga 2 POST | Send JSON request body and `Accept: application/json` |
| Form POST | Encode command/login form bodies as `application/x-www-form-urlencoded; charset=utf-8` |
| Status codes | Preserve current behavior first: non-401 responses usually return body data; password prompt validates 2xx |

## UX Requirements

| Area | Requirement | Status |
| --- | --- | --- |
| Menu bar | Must be readable at a glance, avoid blocking the main thread, and serve as the primary product entrypoint | Partial |
| Settings | Must make backend setup, filters, commands, alarms, About/version/license/support information, and local-fallback-to-real setup discoverable | Partial |
| macOS application menu | Must not be required for product navigation; any remaining Apple-logo menu exists only for AppKit/system convention | Done |
| Local fake Icinga fallback | Must be local, deterministic, non-persisted, visibly labeled, and routed through the same Icinga URL/client/parser/command path used by real Icinga remotes; production views must not branch on `Demo Mode` or carry app-side hardcoded sample status data | Done |
| Password prompt | Must show clear retry/skip flow for failed credentials | Partial |
| Errors | Must avoid silent failures for auth, network, parser, and persistence errors | Planned |
| Accessibility | Controls and status changes should be keyboard/screen-reader friendly | Partial |

## DX Requirements

| Area | Requirement | Status |
| --- | --- | --- |
| Build | One documented Xcode build path without CocoaPods | Done |
| Tests | One documented full-suite command | Done |
| CI | GitHub Actions build/test workflow | In progress |
| Fake servers | Real local HTTP tests for network behavior, including the first-run local fake Icinga server path | Partial |
| Release | Documented signing, notarization, and packaging gates | In progress |

## Non-Goals For Current Spike

| Non-goal | Reason |
| --- | --- |
| Merge spike branch directly | Spike work needs review and cleanup before production merge |
| Rewrite all UI in SwiftUI | The immediate priority is compile, behavior coverage, and dependency removal |
| Replace all persistence in one pass | Realm removal needs a separate migration plan and data compatibility tests |
| Tighten every HTTP status behavior immediately | Current behavior must be preserved before stricter semantics are introduced |
