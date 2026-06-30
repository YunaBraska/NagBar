# ADR 0001: Revival Work Uses A Spike Branch

Status: Accepted

Date: 2026-06-30

## Context

NagBar is a legacy macOS application that needed to compile and run again before
larger modernization work could be trusted. The current branch contains build
repairs, tests, dependency replacement, and documentation changes.

The branch is explicitly a spike branch. Spike code must be reviewed and cleaned
before it is merged to a production branch.

## Decision

Perform revival and modernization work on `feature/nagbar-revive-spike`.

Do not merge the branch directly without review. Treat it as a staging area for:

- restoring compile/test/runtime evidence;
- creating behavior guardrails;
- removing dependencies one category at a time;
- documenting production and OSS gaps.

## Consequences

Positive:

- Work can move quickly while the app is being revived.
- Risky changes are isolated from production branches.
- Review can split the branch into coherent production changes later.

Negative:

- The branch may contain broad changes that need cleanup.
- Documentation must be kept clear about what is verified versus planned.
