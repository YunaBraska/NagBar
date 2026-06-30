# OSS Readiness

Status: In progress.

## Checklist

| Area | Status | Evidence / next action |
| --- | --- | --- |
| License | Done | Apache License 2.0 in `LICENSE` |
| Third-party notices | Done | Sound attribution is in `NOTICE`; dependency inventory is in `docs/DEPENDENCIES.md` |
| README | Done | Build, test, status, and docs links added |
| Contributing guide | Done | `CONTRIBUTING.md` |
| Security policy | Done | `SECURITY.md` |
| Support policy | Done | `SUPPORT.md` |
| Code of conduct | Done | `CODE_OF_CONDUCT.md` |
| Issue templates | Done | `.github/ISSUE_TEMPLATE` |
| PR template | Done | `.github/PULL_REQUEST_TEMPLATE.md` |
| CI | Done | `.github/workflows/ci.yml` defines build/test gates; live GitHub runner evidence still requires branch push |
| Roadmap | Done | `ROADMAP.md` |
| Specs | Done | `SPEC.md` |
| ADRs | Done | `docs/adr` |
| Release process | Done | `docs/RELEASE.md` plus `CHANGELOG.md`; public signing/notarization remains a production-release blocker |
| Dependency policy | Done | CocoaPods removed; remaining dependency and upgrade constraints are documented |

## Repository Defaults

Recommended GitHub settings:

| Setting | Recommendation |
| --- | --- |
| Default branch protection | Require CI before merge |
| Pull requests | Require review before merge |
| Issues | Enable bug and feature templates |
| Discussions | Optional; useful if project receives support requests |
| Security advisories | Enable private vulnerability reporting if available |
| Releases | Use signed/notarized artifacts only |

## Contributor Expectations

Contributions should:

1. Include behavior tests when behavior changes.
2. Preserve supported backend compatibility unless the change is explicitly documented.
3. Update `TEST_MAP.md`, `SPEC.md`, or `ROADMAP.md` when scope/status changes.
4. Avoid adding dependencies unless an ADR explains the tradeoff.
5. Keep release claims tied to passing verification.

## Remaining OSS Gaps

| Gap | Priority | Notes |
| --- | --- | --- |
| Dependency license inventory | Done | `docs/DEPENDENCIES.md` documents current Apple SDK usage, bundled assets, and removed dependencies |
| Release artifact provenance | Done | `script/package_release.sh` writes checksum and manifest files; `docs/RELEASE.md` documents local/private package checksums, extracted-app verification, Developer ID artifact validation, and notarization evidence requirements |
| Clean clone verification | P1 | Validate setup from a fresh checkout on a clean macOS account before public release |
| Maintainer triage labels | P2 | Suggested labels: `bug`, `backend`, `parser`, `ui`, `dx`, `security`, `release` |
