# Troubleshooting

This page covers failure recovery for the most common situations where git shadow operations go wrong.

> **Quick state check** — when something feels off, start here:
> ```bash
> git status          # what branch, what is staged
> git shadow status   # shadow/public pair health
> git log --oneline -5
> ```

---

## Table of contents

1. [Cherry-pick conflict during `feature publish`](#1-cherry-pick-conflict-during-feature-publish)
2. [Merge conflict during `feature finish`](#2-merge-conflict-during-feature-finish)
3. [Nothing left to commit after `git shadow commit`](#3-nothing-left-to-commit-after-git-shadow-commit)
4. [Pre-commit hook is blocking a legitimate commit](#4-pre-commit-hook-is-blocking-a-legitimate-commit)
5. [Public branch is ahead of the shadow branch](#5-public-branch-is-ahead-of-the-shadow-branch)
6. [Shadow branch is behind after a team pull](#6-shadow-branch-is-behind-after-a-team-pull)
7. [Public branch was accidentally deleted](#7-public-branch-was-accidentally-deleted)
8. [LOCAL_COMMENT_PATTERN matches real code](#8-local_comment_pattern-matches-real-code)
9. [Removing git shadow hooks from a project](#9-removing-git-shadow-hooks-from-a-project)
10. [Adopting git shadow on an existing repo](#10-adopting-git-shadow-on-an-existing-repo)
11. [Binary not found after installation](#11-binary-not-found-after-installation)

---

## 1. Cherry-pick conflict during `feature publish`

**Symptom:** `feature publish` stops mid-run with a message like:

```
CONFLICT (content): Merge conflict in src/auth.ts
error: could not apply abc1234... feat: login function
hint: After resolving the conflicts, run:
      git cherry-pick --continue
```

**What happened:** `feature publish` cherry-picks each publishable commit from your `@local` branch to the public branch one by one. A conflict means the public branch has changes that overlap with the commit being cherry-picked.

**Where you are:** You are on the **public branch** (e.g. `feature/login`) with `CHERRY_PICK_HEAD` set.

**Recovery — option A: resolve and continue**

```bash
# 1. Open the conflicting file(s) and resolve the markers (<<<<, ====, >>>>)
# 2. Stage the resolved files
git add src/auth.ts

# 3. Continue the cherry-pick
git cherry-pick --continue

# 4. Re-run publish — it will skip already-cherry-picked commits
git checkout feature/login@local
git shadow feature publish
```

**Recovery — option B: abort and go back**

```bash
# Cancel the cherry-pick entirely — the public branch is left as it was before publish
git cherry-pick --abort

# You are back on the public branch. Return to your shadow branch to investigate.
git checkout feature/login@local
```

**Prevention:** Keep your shadow and public branches in sync. If the public branch received changes since your last publish, merge them into your shadow branch first:

```bash
git checkout feature/login@local
git merge feature/login
git shadow feature publish
```

---

## 2. Merge conflict during `feature finish`

**Symptom:** `feature finish` exits with a non-zero status mid-run. You may see:

```
Auto-merging file.txt
CONFLICT (content): Merge conflict in file.txt
Automatic merge failed; fix conflicts and then commit the result.
```

**What happened:** `feature finish` runs two merges in sequence:
1. Sync merge: `main` → `main@local` (integrates public changes into the local base)
2. Feature merge: `feature@local` → `main@local` (integrates your feature's local history)

The conflict occurred in one of those two merges.

**Where you are:** You are on **`main@local`** (the local base branch) with `MERGE_HEAD` set.

**Recovery:**

```bash
# 1. Check which files are in conflict
git status

# 2. Open each conflicting file and resolve the markers
# 3. Stage the resolved files
git add path/to/file.txt

# 4. Complete the merge
git merge --continue

# 5. If the conflict was in the sync merge, the feature merge still needs to run.
#    Return to your feature branch and re-run finish — it will skip already-merged work.
git checkout feature/login@local
git shadow feature finish --no-pull
```

**If the situation is complex and you want to start over:**

```bash
# Abort the current merge
git merge --abort

# You are back on main@local in a clean state.
# Investigate the divergence before retrying.
git log --oneline --graph main main@local feature/login@local
```

**Note:** Use `--no-pull` when retrying `feature finish` if the conflict was caused by a pull from the remote. This avoids re-triggering the same conflict before you are ready.

---

## 3. Nothing left to commit after `git shadow commit`

**Symptom:**

```
❌ After removing local comments, nothing remains to commit.
```

**What happened:** Every line in your staged files matched `LOCAL_COMMENT_PATTERN`. The git index was cleaned but the commit was aborted.

**Where you are:** Your staged files are now in the index **without** local comments (the working tree is unchanged). The working tree still has the original content.

**Recovery — option A: restore the original staged state**

```bash
# Discard the index changes and restore the staged state to what the working tree contains
git restore --staged .
# Your files are staged again with local comments, as they were before
```

**Recovery — option B: commit the local comments as a [MEMORY] commit directly**

```bash
git add .
git commit -m "[MEMORY] my local notes" --no-verify
```

This is the correct approach if the staged content was intentionally notes-only (e.g. a memory file for AI context).

---

## 4. Pre-commit hook is blocking a legitimate commit

**Symptom:** A regular `git commit` is rejected with:

```
❌ Commit blocked: local comments are still present in staged files.
```

**Cause A: you staged local comments by accident**

Run `git shadow commit` instead of `git commit` — it strips comments automatically.

```bash
git shadow commit -m "your message"
```

**Cause B: the pattern is matching code that is not a local comment**

The default `LOCAL_COMMENT_PATTERN` matches lines starting with `///`, `##`, `%%`, or `<!--`. If your code legitimately contains these patterns (e.g. a Rust doc comment `///`, or a bash case statement with `##` prefixed), you need to adjust the pattern:

```bash
# Check which lines are being flagged
git shadow check-local-comments

# Adjust the pattern for your project
git shadow config set LOCAL_COMMENT_PATTERN '^[[:space:]]*(///|%%)' --project-config
```

See [case 8](#8-local_comment_pattern-matches-real-code) for a detailed guide.

**Cause C: you want to bypass the hook for a one-off commit**

```bash
git commit --no-verify -m "your message"
```

Use this sparingly. If you use it regularly, consider adjusting `LOCAL_COMMENT_PATTERN` instead.

---

## 5. Public branch is ahead of the shadow branch

**Symptom:** `git shadow status` reports `public branch ahead`.

**What happened:** Commits were added to the public branch (e.g. by a teammate's merge, or by cherry-picks from another tool) that your shadow branch does not contain.

**Recovery:** Merge the public branch into the shadow branch to synchronize them.

```bash
git checkout feature/login@local
git merge feature/login
```

If there are conflicts (unlikely, since public commits were originally derived from your shadow commits via cherry-pick):

```bash
# Resolve conflicts, then:
git add .
git merge --continue
```

After this, `git shadow status` should report `up to date` or `ready to publish`.

---

## 6. Shadow branch is behind after a team pull

**Symptom:** Your teammates merged changes into `main`. Your `main@local` is behind.

**What happened:** `main` advanced but `main@local` did not automatically follow.

**Recovery:** Update your shadow base branch manually.

```bash
# Update the public base
git checkout main
git pull

# Sync the shadow base
git checkout main@local
git merge main
```

If you are on a feature branch:

```bash
# From feature/login@local, keep working — this will be handled at feature finish time.
# Or sync proactively:
git checkout main && git pull
git checkout main@local && git merge main
git checkout feature/login@local
```

`git shadow feature finish` performs this sync automatically when you complete a feature.

---

## 7. Public branch was accidentally deleted

**Symptom:** The public feature branch (e.g. `feature/login`) was deleted — either locally with `git branch -D` or remotely.

**Recovery:** Recreate the public branch from the shadow branch by cherry-picking the publishable commits.

```bash
# Find the base commit of the public branch (the commit in common with main)
git checkout feature/login@local
git log --oneline main..feature/login@local

# Recreate the public branch from the public base
git checkout main
git checkout -b feature/login

# Re-publish from the shadow branch — publish detects which commits are missing
git checkout feature/login@local
git shadow feature publish
```

`feature publish` uses patch-content comparison (not SHAs), so it will correctly identify which commits need to be cherry-picked, even if the branch was rebuilt from scratch.

---

## 8. LOCAL_COMMENT_PATTERN matches real code

**Symptom:** Lines of real code are being stripped by `git shadow commit`, or the pre-commit hook is blocking commits with false positives.

**Common triggers:**

| Pattern triggered | Real code causing it | Fix |
|---|---|---|
| `##` | Bash `##` comments used as section headers | Remove `##` from pattern |
| `///` | Rust doc comments (`/// Description`) | Remove `///` from pattern |
| `<!--` | Regular HTML comments | Remove `<!--` from pattern |

**Check what is being flagged:**

```bash
git shadow check-local-comments
```

**Adjust the pattern for your project:**

```bash
# Example: keep only %% as local marker, remove the others
git shadow config set LOCAL_COMMENT_PATTERN '^[[:space:]]*(%%)'  --project-config

# Verify
git shadow config get LOCAL_COMMENT_PATTERN
```

The pattern is a POSIX extended regex. Only include markers that are **never** valid syntax in your project's languages.

**Recommended single-language patterns:**

```bash
# TypeScript / JavaScript only
LOCAL_COMMENT_PATTERN='^[[:space:]]*(///)'

# Python only
LOCAL_COMMENT_PATTERN='^[[:space:]]*(##)'

# Mixed projects — use a very specific marker unlikely to appear naturally
LOCAL_COMMENT_PATTERN='^[[:space:]]*(//!|##!)'
```

---

## 9. Removing git shadow hooks from a project

**When to do this:** You want to stop using git shadow in a project, or you need to temporarily disable the hooks.

**Identify the hook files:**

```bash
git config --get core.hooksPath   # prints custom hook path if set, otherwise default is .git/hooks/
```

**Option A: remove only the git shadow block (recommended)**

The hooks installed by git shadow are delimited by a marker comment. Open the hook file and delete the git shadow section:

```bash
# pre-commit hook
nano .git/hooks/pre-commit   # or vim, or your editor
# Delete lines from "# git-shadow pre-commit hook" to "exit 0" (the git-shadow block)

# pre-push hook
nano .git/hooks/pre-push
# Delete lines from "# git-shadow pre-push hook" to "exit 0"
```

If the hook file only contained the git shadow block, you can delete it entirely:

```bash
rm .git/hooks/pre-commit
rm .git/hooks/pre-push
```

**Option B: disable hooks temporarily for one commit**

```bash
git commit --no-verify -m "your message"
git push --no-verify
```

---

## 10. Adopting git shadow on an existing repo

**Scenario:** You have an existing feature branch (`feature/login`) and want to adopt the shadow branch pattern without losing your work.

**Step 1: create the shadow branch from your existing branch**

```bash
# Make sure you are on your existing branch
git checkout feature/login

# Create the shadow branch at the same point
git checkout -b feature/login@local
```

Your `feature/login@local` and `feature/login` now share the same history. This is the expected starting state.

**Step 2: install hooks**

```bash
git shadow install-hooks
```

**Step 3: work normally from the shadow branch**

From now on, work on `feature/login@local`. Use `git shadow commit` to commit (strips local comments and separates them into a `[MEMORY]` commit), and `git shadow feature publish` to push clean commits to `feature/login`.

**Step 4: set up the base shadow branch**

If your repo has a `main` (or `develop`) branch but no `main@local`, create it once:

```bash
git checkout main
git checkout -b main@local
```

This shadow base branch is where `feature finish` will merge your local history when the feature is complete.

**Note:** Your existing commits on `feature/login` will not be retroactively split — only new commits made via `git shadow commit` will be separated.

---

## 11. Binary not found after installation

**Symptom:** `git shadow` or `git-shadow` returns `command not found`.

**Curl / manual install:**

The binary is linked to `~/.local/bin`. Check if that directory is in your `PATH`:

```bash
echo $PATH | grep -o '\.local/bin'
```

If not, add this line to your shell profile (`~/.bashrc`, `~/.zshrc`, etc.):

```bash
export PATH="$HOME/.local/bin:$PATH"
```

Then reload:

```bash
source ~/.bashrc   # or ~/.zshrc
```

**npm install:**

Check where npm places global binaries:

```bash
npm bin -g
```

Add that path to your `PATH` if it is not already there.

**Verify the installation:**

```bash
git-shadow version
git shadow help
```

If the binary exists but still fails with an error like `TOOLKIT_ROOT not found`, the symlink may be pointing to a deleted or moved installation directory. Re-run the installer:

```bash
curl -fsSL https://raw.githubusercontent.com/filozofer/git-shadow/main/install.sh | bash
```
