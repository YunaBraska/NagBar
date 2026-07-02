# Release Process

Status: Defined.

Public releases are blocked until the gates in `docs/PROJECT_STATUS.md` are met.
Local/private Release artifacts are supported today.

## Pre-Release Gates

1. Full tests pass locally and on CI.
2. `./script/build_and_run.sh --acceptance` passes.
3. Dependency and notice files are current.
4. `CHANGELOG.md` contains the release notes.
5. Version metadata is updated.
6. Public releases include real signing and notarization evidence.

## Local/Private Package

For maintainers without an Apple developer account:

```sh
./script/build_and_run.sh --package
```

This path builds Release, verifies ad-hoc signing, creates
`dist/NagBar-<version>-macOS.zip`, validates the zip, verifies the extracted
app, and writes matching `.sha256` and `.manifest` files.

To package an already-built app:

```sh
./script/cicd/package_release.sh --skip-build
```

Do not publish this artifact as a public release.

## Public Signing And Notarization

The public path requires a Developer ID Application certificate, hardened
runtime, Apple notarization acceptance, and a stapled ticket before packaging.

Verify the current Release app:

```sh
./script/cicd/verify_release_signing.sh
./script/cicd/verify_release_signing.sh --developer-id
```

Sign with Developer ID:

```sh
./script/cicd/sign_release.sh --developer-id "Developer ID Application: Example (TEAMID)"
```

Notarize with a stored `notarytool` profile:

```sh
xcrun notarytool store-credentials NagBarNotary
./script/cicd/notarize_release.sh --keychain-profile NagBarNotary
```

Or notarize with explicit credentials:

```sh
NAGBAR_NOTARY_PASSWORD=app-specific-password \
  ./script/cicd/notarize_release.sh --apple-id maintainer@example.com --team-id TEAMID --password-env NAGBAR_NOTARY_PASSWORD
```

After signing and stapling:

```sh
./script/cicd/package_release.sh --developer-id --skip-build
```

Keep the verifier output, notarization evidence, `.sha256`, and `.manifest`
with the release record.

## Version And Changelog

The release workflow uses UTC date versions by default:

```sh
./script/cicd/release_version.sh
```

Manual metadata helpers:

```sh
./script/cicd/set_release_version.sh <version>
./script/cicd/prepare_changelog_release.sh <version>
./script/cicd/extract_changelog_release_notes.sh <version>
```

GitHub releases should normally use `.github/workflows/release.yml`.

## Runtime Smoke

Minimum manual verification after packaging:

1. Launch the artifact on a clean macOS user account.
2. Confirm the status item appears.
3. Confirm Preferences opens from the status item.
4. Confirm a disposable backend or local fallback loads.
5. Capture logs if anything diverges.

Useful diagnostics:

```sh
./script/build_and_run.sh --logs
./script/build_and_run.sh --telemetry
```

Do not publish screenshots that expose private infrastructure or desktop data.

## Upgrade Note

Current builds do not import or report legacy Realm data. Supported persisted
state is the active JSON and `UserDefaults` store only.
