# AGENTS.md

This repository uses **git shadow**.

If you are an AI coding agent, assistant, or automated contributor, you must follow the workflow described below.

---

## Core principle

```text
code for thinking  ≠  code for collaboration
```

This repository separates development into two layers:

feature/x@local   → thinking workspace
feature/x         → published branch

The @local branch is for exploration, reasoning, debug code, pseudo-code, and local-only comments.
The public branch is for clean, reviewable, shareable code.

## Agent behavior rules

1. Default to the shadow branch

Always prefer working in the @local branch when available.
Example: feature/login@local
Do not treat the public branch as the primary workspace for iterative reasoning.

2. Use @local as a cognitive workspace

In the shadow branch, you are encouraged to write and preserve:
- reasoning comments
- implementation plans
- pseudo-code
- temporary debug code
- intermediate refactors
- local-only TODO notes
- hypotheses and exploration artifacts

Examples:
```ts
/// plan:
/// 1. validate token
/// 2. retry on 429
/// 3. persist refreshed token

/// @local debug
console.log('SSO profile', profile)
```

These artifacts are useful in @local and should not be removed prematurely.

3. Do not prematurely optimize for cleanliness in @local

When working in the shadow branch:
- prefer explicit reasoning over premature cleanup
- keep useful comments if they help thinking
- keep exploratory code while a task is still in progress
- do not erase cognitive context too early

In @local, clarity of thought is more important than polish.

4. Publish only clean code

Before publishing to the public branch, choose what to keep as local-only artifacts such as:
- /// comments
- // @local comments
- debug logs
- temporary probes
- unfinished pseudo-code
- local-only planning notes

What will be usefull to keep for later usage as a memory ? 
These things must be commited inside a separate commits prefixed by "[MEMORY] " in order to allow git shadow to filter them during the publish process.

Published code must be:
- readable
- minimal
- production-ready
- suitable for code review

5. Preferred workflow

```bash
git shadow feature start <branch-name>
# THEN WORK
# Clean code as explain in "4. Publish only clean code"
git shadow commit
git shadow feature publish
git push origin <branch-name>
```

If you are asked to finalize work, prefer publication through git shadow rather than manually copying noisy changes to the public branch.

6. Git shadow configuration

Use this command to retrieve all the git shadow config :
```bash
git shadow config show --json
```

7. Separation of responsibilities
Layer	Purpose
@local	think, explore, debug, iterate
public branch	publish, review, share
Agent decision rule

Use this rule at all times:

If a change helps thinking, it belongs in @local.
If a change is ready to be shared, it belongs in the public branch.

## Intent

The goal is not only to keep the repository clean.

The goal is to preserve a valuable truth:
how code is produced ≠ how code is shared

git shadow exists to protect both.

Short reminder
Use @local to think.
Use publish to share.