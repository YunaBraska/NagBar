# ADR 0014: Default To Local Ad-Hoc Signing

Status: Accepted.

## Context

NagBar must build and package on maintainer machines that do not have an Apple
developer account. Public macOS distribution still requires a Developer ID
Application certificate and Apple notarization, but those credentials are not
needed for local development, tests, or private smoke artifacts.

Xcode can silently drift toward automatic signing when a project has no explicit
target-level signing settings. That makes local builds depend on a development
team and creates avoidable setup failure.

## Decision

The project defaults to manual ad-hoc signing:

- `CODE_SIGN_IDENTITY = "-"`
- `CODE_SIGN_STYLE = Manual`
- empty `DEVELOPMENT_TEAM`
- hardened runtime enabled for the app target

The local/private package path is:

```sh
./script/build_and_run.sh --package
```

That path builds Release, verifies local ad-hoc signing, validates the zip,
extracts the zip, and verifies the extracted app again.

Real Developer ID signing remains explicit and opt-in:

```sh
./script/cicd/sign_release.sh --developer-id "Developer ID Application: Example (TEAMID)"
./script/cicd/notarize_release.sh --keychain-profile NagBarNotary
./script/cicd/package_release.sh --developer-id --skip-build
```

## Consequences

Local/private artifacts can be built without an Apple developer account. They
are suitable for maintainer testing and private verification.

Ad-hoc signed artifacts are not public releases. Public release artifacts must
be Developer ID signed, notarized, stapled, and verified before publication.

The explicit project settings make accidental automatic-signing regressions easy
to spot in review and in `xcodebuild -showBuildSettings` output.
