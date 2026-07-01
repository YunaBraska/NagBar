# User Guide

Status: Maintained.

This guide covers the supported user workflow for the current branch. Release
readiness and remaining gaps live in `docs/PROJECT_STATUS.md`.

## Install

Download the latest release from the project releases page when a production
release is available.

Current spike builds are for development verification only.

## Add A Monitoring Instance

1. Open NagBar from the macOS menu bar status item.
2. Open preferences.
3. Add a monitoring instance.
4. Choose the backend type:
   - Nagios
   - Icinga
   - Icinga 2
   - Thruk
   - Check_MK
5. Enter the base URL, username, and password.
6. Enable the instance.

Password persistence follows the app setting for saving passwords. When enabled,
passwords are stored with the macOS Keychain.

## First Run With Local Fake Icinga

If no monitoring instance is configured, NagBar starts a local fake Icinga
server and connects to it as a normal Icinga remote.
The sample states come from that HTTP server, not hardcoded UI data, and are
replaced automatically after the first real monitoring remote is saved.

## Status Bar

NagBar runs in the macOS menu bar and shows current monitoring state. Opening
the menu reveals parsed host and service items. Status, Settings, About,
refresh, and quit are all reachable from the status item, and Settings also
contains version, license, and support information.

## Filters

Filters can hide known host/service/status combinations. Use filters for noisy
or intentionally ignored checks, not for acknowledgement workflows.

## Commands

Supported backends expose acknowledge, recheck, and schedule downtime actions
from the status UI. Check_MK remains open-in-browser only.

## Troubleshooting

| Problem | Suggested action |
| --- | --- |
| App does not launch | Run the latest signed/notarized release; development builds are local-sign only |
| Backend shows no data | Check base URL, backend type, username, password, and network access |
| Password prompt repeats | Verify credentials in the monitoring backend |
| TLS/certificate failures | Use valid server certificates where possible; invalid-certificate bypass is intended only for configured monitoring hosts |
| Items look wrong | Open an issue with backend type, sanitized fixture data, and expected status |

## Privacy

NagBar stores monitoring configuration locally. Passwords are stored in memory
for the app session and in Keychain only when password saving is enabled.
