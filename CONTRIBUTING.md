# Contributing

Thanks for working on NagBar.

## Ground Rules

- Keep behavior changes covered by tests.
- Prefer public-entrypoint tests over private-helper tests.
- Use fake local HTTP servers for backend protocol behavior.
- Update `docs/PROJECT_STATUS.md` when behavior, verification evidence, or release status changes.
- Update ADRs when architecture or long-lived tradeoffs change.
- Avoid adding dependencies without an ADR.

## Local Workflow

```sh
./script/build_and_run.sh --test
```

Before opening a pull request:

```sh
./script/build_and_run.sh --test
./script/build_and_run.sh --release-build
```

Run `./script/build_and_run.sh --acceptance` before larger UI or workflow
changes when Accessibility permission is available for the invoking terminal.
CocoaPods is no longer used; do not reintroduce `Podfile`, `Podfile.lock`, or
Pods workspace/project references.

## Pull Request Checklist

- Tests pass locally.
- New behavior has tests.
- Documentation is updated when user-visible behavior changes.
- Dependency changes include an ADR or update an existing ADR.
- Dependency changes update `docs/DEPENDENCIES.md` and `NOTICE` when relevant.
- CocoaPods files and workspace/project references were not reintroduced.
- No secrets, credentials, private monitoring URLs, or private screenshots are included.

## Backend Fixtures

When adding backend fixture data:

- sanitize hostnames, service names, URLs, tokens, and usernames;
- keep the fixture small enough to review;
- include expected parser assertions;
- prefer fake-server tests when the behavior depends on HTTP, auth, cookies, or POST bodies.
