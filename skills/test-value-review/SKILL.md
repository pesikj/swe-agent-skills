---
name: test-value-review
description: Reviews tests added or modified in a branch, PR/MR, commit range, or set of files and decides whether each test earns its place. For every test it explains what behavior the test protects, what concrete change would make it fail (logic change, library upgrade, changed constant, refactor), and how likely that change is. It assigns a category (Real danger, Low-probability danger, Corner case, No real value, Duplicate) and a recommendation (Keep, Remove, or Merge/simplify), then writes an English Markdown report. The goal is to stop low-value or AI-generated test bloat that raises coverage without adding safety; it never proposes new tests. Use when the user asks to "review the added tests", "are these tests worth keeping", "check for AI slop tests", "which tests can I delete", "is this test justified", "too many tests in this PR", reviews AI-written tests or a test-heavy PR/MR, or invokes test-value-review by name.
argument-hint: [PR/MR #/URL | commit range | test file paths] [output path]
---

# Test Value Review

Goal: for every test added or changed in the scope, decide whether keeping it is **justified**. A test is code that someone must read, maintain, and fix when it goes red. It earns its place only if a realistic future change could break the behavior it guards **and** that breakage would matter. "It raises coverage" is not a justification on its own.

The question to keep asking for each test: *if this test fails six months from now, will the person who sees it learn about a real bug, or will they just update the test to make it pass?*

Out of scope: proposing new tests, pointing out missing coverage, or reviewing production code. Mention a production bug only if you happen to notice one while reading, in a short note at the end.

The report is always in **English**.

## 1. Resolve the scope

Take the scope and an optional output path from the arguments or the request.

- **Default (nothing given)**: the current branch against its base. Find the base as the target branch of the open PR/MR for this branch if one exists (`gh pr view --json baseRefName` / `glab mr view`), otherwise the remote default branch (`git symbolic-ref refs/remotes/origin/HEAD`). Diff from the merge base to the working tree (`git diff $(git merge-base <base> HEAD)`) so committed and uncommitted work on the branch are both included. State in the report whether uncommitted changes were included.
- **PR/MR number or URL**: `gh pr diff <ref>` / `glab mr diff <ref>`, plus the PR/MR description for context.
- **Commit range** (`A..B`, a single commit): `git diff A..B` / `git show <sha>`.
- **File paths**: review the tests in those files that differ from the base; if the user explicitly asks for whole files, review every test in them.
- If the base or scope is ambiguous, ask once instead of guessing.

From the diff, list every **test unit** that was added or modified:

- Test files follow the repo's conventions (`tests/`, `test_*.py`, `*_test.go`, `*.spec.ts`, `*Test.java`, …).
- A unit is one test function or method. A parametrized test is one unit; comment on individual cases only when some cases differ in value from the rest.
- New fixtures, helpers, and `conftest`-style support code are not units. Look at them only to report support code that becomes unused if your recommended removals are applied.
- For **modified** tests, evaluate the test as it is after the change, and also say what changed. Treat weakened assertions, a removed check, or an expected value edited to match new output without a matching production change as red flags; call them out explicitly.
- Tests that were only **moved or renamed** with an unchanged body aren't new code. List them in one line in the report and don't review them, unless the user asks for it.

Review every unit, even when there are many. With more than about 30, work file by file and keep each test's write-up short, but don't skip any.

## 2. Read the test and the code it exercises

Judge each test from what it actually does, not from its name or docstring.

- Read the whole test, its fixtures, its mocks, and the production code it calls. Follow the call into the real implementation far enough to know which branches it actually reaches.
- Check what production code changed in the same scope. A test that pins down behavior introduced or fixed in this branch is usually more justified than one that pokes at old, stable code.
- Search the existing test suite for other tests of the same function or behavior (grep for the function name, the class, the key constant) to detect duplicates, both against existing tests and against other tests in the diff.
- If useful, look at `git log` for the production file: frequent churn or past bug fixes in that area make regressions more plausible.

Don't run the tests and don't modify any code to check a claim (no mutation testing). Reason from the code. If a claim can only be settled by running something, say so in the write-up.

## 3. Analyze each test

Answer four things for every test.

**a. What it tests.** One or two sentences describing the behavior or contract being protected, in terms a maintainer cares about ("retries the upload up to three times on 503 and then raises `UploadError`"), not a narration of the code ("calls `upload()` with a mock and asserts `call_count == 3`"). If you can't state a behavior, that is already a strong signal for *No real value*.

**b. What makes it fail.** List the concrete changes that would turn it red. Be specific: name the function, condition, constant, or dependency. Typical kinds:

- *Logic change*: removing a guard, flipping a condition, changing an order, an off-by-one, dropping an error path.
- *Library or platform change*: a dependency upgrade that changes defaults, formats, or exceptions; a Python/Node/runtime version difference.
- *Constant or configuration change*: a timeout, limit, URL, env var name, default value.
- *Data or contract change*: an upstream API response shape, a DB schema, a file format.
- *Harmless refactor*: renaming a private attribute, splitting a function, changing the log message text, reordering dict keys, swapping an internal helper. The test fails, but nothing is actually broken.

Then judge the failure modes. Failures from the first four kinds are **true alarms** (the test catches a real problem). Failures from harmless refactors are **false alarms**: they cost maintenance and teach people to "just fix the test". A test that fails *only* on harmless refactors is a liability. A test where you can't name any realistic change that makes it fail (it asserts what its own mock returns, it restates a constant, it checks that Python can build a dataclass) protects nothing.

**c. How likely the breaking change is.** Use evidence rather than intuition: how complex and how central the code is, how often it changes, whether it touches an external system, whether the behavior was just fixed (a regression test for a fresh bug is valuable), whether someone could plausibly edit it while doing something else. Also ask whether the scenario can happen at all: if upstream validation, types, or the only caller already make the input impossible, the test guards a situation that can't occur.

**d. What it costs.** Length, setup, depth of mocking, readability (would a new team member understand why it exists?), coupling to internals, flakiness risk (real time, sleeps, network, ordering, randomness), and runtime.

## 4. Assign a category

Pick exactly one. The category describes the **risk the test guards against**, not its quality.

| Category | Use when |
|---|---|
| 🔴 Real danger | A plausible future change would break this behavior, and the breakage would matter (wrong data or money, security, lost data, a broken public API or integration contract, a crash on a normal path, or a regression of a bug fixed in this scope). |
| 🟠 Low-probability danger | Breaking the behavior would matter, but it takes an unusual or deliberate change, e.g. code that is stable and simple, or a failure that someone would notice immediately anyway. |
| 🟡 Corner case | Exotic input or state that is rare or practically impossible in real use (already prevented upstream, a theoretical combination, a defensive branch nobody reaches). |
| ⚪ No real value | It can't fail for a meaningful reason: it asserts mock return values, tests the language, framework, or a library instead of this code, restates a constant or default, tests trivial plumbing (getters, dataclass fields, `__repr__`), only checks "no exception was raised" with nothing else asserted, or fails only on harmless refactors. |
| 🔁 Duplicate | The same behavior is already asserted by another test, in the diff or in the existing suite. Name that test. |

When a test sits between two categories, pick the lower-risk one and explain why. Over-rating tests is the failure mode this skill exists to prevent.

## 5. Recommend

Pick exactly one recommendation per test. **Keep** means keep it *as it is*. If a test is worth having but needs changes, that is Merge/simplify.

| Recommendation | Typical use |
|---|---|
| ✅ Keep | 🔴 Real danger tests that are readable and not brittle. 🟠 Low-probability danger tests that are cheap and clear. 🟡 Corner cases only when the impact would be severe (security, data loss, money) or the case is an explicit requirement or a reported bug. |
| 🗑️ Remove | ⚪ No real value. 🟡 Corner cases without severe impact. 🟠 tests whose cost (setup, mocking, brittleness, flakiness) outweighs the small risk. 🔁 Duplicates that add nothing over the test they duplicate. |
| 🔀 Merge/simplify | Several tests that differ only in input data → one parametrized test. A 🔁 Duplicate that covers one extra case → move that case into the other test. A valuable test buried under brittle assertions on internals → keep the behavioral assertion, drop the rest. A test with heavy setup that can reuse an existing fixture. |

For each **Merge/simplify**, say concretely what goes where ("fold `test_parse_empty` and `test_parse_blank` into `test_parse_invalid` as parametrized cases"; "keep the `assert result.status == 'failed'` line, drop the three assertions on `_internal_cache`"). Merge/simplify must reduce or keep the amount of test code; it can't turn into adding new tests or new assertions.

Don't aim for a quota in either direction. If every test is justified, say so; if most are slop, say that plainly.

## 6. Write the report

Default output path: `~/test-value-reports/<repo-name>/<branch-or-pr>.md` (create the directory; replace `/` in branch names with `-`). If the user gives a path, use it. Don't write the report into the reviewed repository unless the user explicitly asks.

Use this structure:

````markdown
# Test Value Review: <branch / PR title>

- **Repository:** <name>
- **Scope:** `<head>` vs. `<base>` (merge base `<short sha>`), uncommitted changes included: yes/no
- **Reviewed:** <N> tests in <M> files (<A> added, <B> modified)
- **Date:** YYYY-MM-DD

## Verdict

<One or two sentences: how much of the added test code is justified, and the headline problem if there is one (e.g. "most tests assert mock return values").>

| ✅ Keep | 🗑️ Remove | 🔀 Merge/simplify |
|---|---|---|
| x | x | x |

| 🔴 Real danger | 🟠 Low-probability | 🟡 Corner case | ⚪ No real value | 🔁 Duplicate |
|---|---|---|---|---|
| x | x | x | x | x |

If all recommendations are applied: about <X> of <Y> added test lines removed, <N> → <N'> tests.

## Summary

| # | Test | Category | Recommendation | Reason (one line) |
|---|---|---|---|---|
| T1 | `tests/test_x.py::test_retry_on_503` | 🔴 Real danger | ✅ Keep | Guards retry limit on a flaky upstream API. |
| T2 | `tests/test_x.py::test_config_default` | ⚪ No real value | 🗑️ Remove | Restates the default constant. |

## Detailed Review

### T1 — `tests/test_x.py::test_retry_on_503` (added, `tests/test_x.py:L40-L72`)

**What it tests:** <behavior in one or two sentences>

**What makes it fail:**
- <concrete change> — true alarm / false alarm
- …

**Likelihood:** <how plausible those changes are, with evidence>

**Cost:** <length, mocking, brittleness, flakiness, readability>

**Category:** 🔴 Real danger — <why this category and not the neighboring one>

**Recommendation:** ✅ Keep — <reason>. For Merge/simplify: <exactly what to merge or drop>.

(repeat for every test)

## Support Code Left Unused

- `tests/conftest.py::fake_client` — only used by T2 and T5 (both Remove).
(Omit this section if nothing becomes unused.)

## Notes

- <red flags in modified tests, production bugs noticed in passing, or claims that need running code to confirm; omit if none>

---

Generated by [test-value-review](https://github.com/pesikj/swe-agent-skills)
````

The `Generated by …` line must always be the last line of the report.

Keep each test's write-up tight: a few lines per heading. The point of the report is to make a cleanup decision easy, not to add more text nobody reads.

## 7. Reply to the user

After writing the file, reply with a short summary only: the verdict sentence, the recommendation counts, the tests to remove or merge (one line each, grouped), and the report path. Don't paste the whole report into the chat.

## Rules

- Base every judgment on code you actually read, and cite `file:line` for the test and for the production code it depends on.
- Don't propose new tests or flag missing coverage. That is outside this skill's job.
- Don't modify, delete, or run tests unless the user explicitly asks after reading the report. This skill only analyzes and reports.
- Don't change git state (no checkout, stash, reset, or commit). The user may have uncommitted work; use `git diff` and `git show` to read other revisions.
- Be honest in both directions: a small, readable test guarding a real behavior is a Keep even if it looks trivial, and a long, impressive-looking test is a Remove if nothing realistic makes it fail.
