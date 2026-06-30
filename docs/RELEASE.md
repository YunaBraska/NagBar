# Release Process

Status: Defined.

The current spike can build a Release configuration locally, but public releases
must not be published until production gates are met.

## Pre-Release Gates

1. Full tests pass on CI.
2. Full tests pass on a maintainer macOS machine.
3. Release build passes.
4. P0/P1 test-map gaps are closed or explicitly deferred.
5. Dependency and license notices are current.
6. `CHANGELOG.md` has an entry for the release.
7. Version number is updated in `MARKETING_VERSION` and
   `CURRENT_PROJECT_VERSION` in `NagBar.xcodeproj/project.pbxproj`.
8. Release notes list user-visible changes, fixed bugs, known issues, and
   remaining unsupported paths.

## Build

```sh
./script/build_and_run.sh --acceptance
```

## Local/Private Package

Maintainers without an Apple developer account can build a private zip package.
This uses Apple's ad-hoc signing identity (`-`) by default, so no development
team, provisioning profile, or certificate is required:

```sh
./script/build_and_run.sh --package
```

The package command builds Release, verifies local/private ad-hoc signing, creates
`dist/NagBar-<version>-macOS.zip`, validates the zip, extracts it, verifies the
extracted app signature, and writes matching `.sha256` and `.manifest` files.
This artifact is suitable for local/private testing, not public distribution.

To package an already-built app:

```sh
./script/package_release.sh --skip-build
```

Local/private provenance checklist:

1. Save the package path printed by `script/package_release.sh`.
2. Save the `.sha256` file next to the package.
3. Save the `.manifest` file next to the package.
4. Keep the signing verifier output showing `Signature=adhoc` and `runtime`.
5. Do not publish the artifact as a public release.

## Signing And Notarization

Public release requirements:

- Developer ID Application certificate;
- hardened runtime;
- notarization submission accepted by Apple;
- notarization stapled to the `.app` before the final zip is created;
- checksum published with release artifact.

Secrets and certificate material must not be committed.

Local/private release-signing verification:

```sh
./script/verify_release_signing.sh
```

This default check is for maintainers without an Apple developer account. It
expects local ad-hoc signing (`Signature=adhoc`), hardened runtime, and no debug
entitlement.

Public distribution signing verification:

```sh
./script/verify_release_signing.sh --developer-id
```

The Developer ID check validates the artifact, not the verifier keychain. It
fails unless the built app is signed with a Developer ID Application identity,
has a TeamIdentifier, is signed with hardened runtime, and passes Gatekeeper
assessment.

Developer ID signing:

```sh
./script/sign_release.sh --developer-id "Developer ID Application: Example (TEAMID)"
```

This command requires the private Developer ID Application certificate in the
local keychain. Machines without an Apple developer account should keep using
the local/private package path.

Notarization with a stored notarytool profile:

```sh
xcrun notarytool store-credentials NagBarNotary
./script/notarize_release.sh --keychain-profile NagBarNotary
```

Notarization with explicit credentials:

```sh
NAGBAR_NOTARY_PASSWORD=app-specific-password \
  ./script/notarize_release.sh --apple-id maintainer@example.com --team-id TEAMID --password-env NAGBAR_NOTARY_PASSWORD
```

The notarization helper submits a temporary zip to Apple, waits for the result,
staples the accepted ticket to the `.app`, validates the stapled app, and reruns
Developer ID signing verification. It does not fake or bypass Apple
notarization when credentials are missing.

Public packages must be created only after Developer ID signing and stapling:

```sh
./script/package_release.sh --developer-id --skip-build
```

In Developer ID mode the package script requires the stapled ticket before it
creates the final zip, then extracts the zip and verifies the extracted app
again.

Public provenance checklist:

1. Save the Developer ID verifier output.
2. Save notarization submission or history output.
3. Save stapling validation output.
4. Publish the zip and `.sha256` together.
5. Publish or retain the `.manifest`.
6. Include the verification command results in release notes.

## Version Bump

Manual releases can update both build settings before cutting a release:

- `MARKETING_VERSION`
- `CURRENT_PROJECT_VERSION`

Then verify:

```sh
./script/build_and_run.sh --test
./script/build_and_run.sh --release-build
./script/package_release.sh --skip-build
```

GitHub releases should use `.github/workflows/release.yml`. The workflow uses
the same UTC date version shape as Sentrio by default:

```sh
./script/release_version.sh
```

It promotes `CHANGELOG.md` `[Unreleased]` notes into `## [<version>] -
<date>`, updates the Xcode build settings, runs tests, builds Release, packages
with local/private signing by default, and switches to Developer ID signing plus
notarization when these secrets all exist:

- `MACOS_DEVELOPER_ID_CERTIFICATE_BASE64`
- `MACOS_DEVELOPER_ID_CERTIFICATE_PASSWORD`
- `MACOS_DEVELOPER_ID_IDENTITY`
- `APPLE_ID`
- `APPLE_TEAM_ID`
- `APPLE_APP_SPECIFIC_PASSWORD`

## Runtime Smoke

After building and packaging:

1. Launch the release artifact on a clean macOS user account.
2. Confirm the app appears in the menu bar.
3. Confirm preferences open.
4. Add a test monitoring instance against a fake or disposable backend.
5. Capture log evidence for maintainer records.

Do not publish screenshots that expose private infrastructure or desktop data.

Useful diagnostics commands:

```sh
./script/build_and_run.sh --logs
./script/build_and_run.sh --telemetry
```

## Upgrade Notes

This spike removes Realm and CocoaPods. Current JSON/UserDefaults/Keychain data
is the supported upgrade path. If the app finds old `default.realm*` files but no
valid current monitoring JSON configuration, it writes:

```text
~/Library/Application Support/com.volendavidov.NagBar/upgrade-compatibility.json
```

That report is a cutoff notice, not an automatic Realm import. Users with
Realm-only configuration must reconfigure monitoring instances in Settings or
migrate through an earlier bridge build before using this release.

## Release Notes Template

```md
# NagBar <version>

## Changes

- 

## Fixed

- 

## Verification

- Full tests:
- Release build:
- Package:
- Signing:
- Manifest:
- Runtime smoke:
- Notarization:

## Known Issues

- 

## Upgrade Notes

- 
```
