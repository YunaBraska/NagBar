# Security Policy

## Supported Versions

Status: In progress.

Until a new production release is cut, security support applies to the active
development branch and the latest public release only.

| Version | Supported |
| --- | --- |
| Active development branch | Yes |
| Latest public release | Best effort |
| Older releases | No |

## Reporting A Vulnerability

Do not open a public issue for vulnerabilities.

Report privately through GitHub security advisories for the repository. Public
issues are not an acceptable vulnerability reporting path.

Include:

- affected version or commit;
- macOS version;
- backend type;
- reproduction steps;
- expected impact;
- sanitized logs or fixture data if relevant.

Do not include real monitoring credentials, tokens, private URLs, or screenshots
with private infrastructure names.

## Security-Sensitive Areas

- macOS Keychain password storage
- in-memory password cache
- backend Basic auth and cookie sessions
- invalid TLS certificate bypass
- release signing and notarization
- user-provided backend URLs and parser data

## Disclosure

The maintainer should acknowledge confirmed reports, fix privately when needed,
and publish release notes that describe impact without exposing exploit details.
