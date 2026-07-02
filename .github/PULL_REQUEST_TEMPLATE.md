## Summary

- 

## Verification

- [ ] `./script/build_and_run.sh --test`
- [ ] `./script/build_and_run.sh --release-build`
- [ ] `./script/build_and_run.sh --acceptance` when UI smoke is relevant and Accessibility permission is available

## Checklist

- [ ] Behavior changes have tests.
- [ ] Backend protocol changes use fake-server coverage where practical.
- [ ] Docs are updated when user-visible behavior changes.
- [ ] Dependency changes include an ADR.
- [ ] Dependency changes update `docs/DEPENDENCIES.md` and `NOTICE` when relevant.
- [ ] CocoaPods files or pod-era project wiring were not reintroduced.
- [ ] No secrets, credentials, private URLs, or private screenshots are included.
