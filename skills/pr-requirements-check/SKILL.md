---
name: pr-requirements-check
description: Checks whether a pull request meets every requirement in its issue and decides if the PR is ready to send for review. Takes an issue (number, URL, or pasted text) and a PR (number, URL, or local branch), pulls each requirement out of the issue, finds the code and tests in the diff that address it, and writes an English Markdown report with a status table, an explanation for each requirement, and a code/test coverage analysis. Use when the user asks "can this PR go to review", "check the PR against the issue", "are all requirements resolved", "requirements review", or runs /pr-requirements-check.
argument-hint: <issue #/URL/text> <PR #/URL/branch> [output path]
---

# PR Requirements Check

Goal: decide whether a PR can be **sent to review**. A PR is ready **only if every requirement in the issue is fully satisfied**. Any other result blocks it.

The report is always written in **English**. The only non-English text allowed is **verbatim quotations from the issue**, kept in the original language (for example Czech). Each quote is followed by an English translation or paraphrase.

## 1. Resolve inputs

Arguments: `$ARGUMENTS`

- **Issue**: a GitHub issue number (`#123` / `123`), an issue URL, or issue text pasted into the conversation.
  - Number/URL → `gh issue view <ref> --json number,title,body,labels,url,comments`
  - Read the **comments** too. Requirements are often clarified, changed, or added there. A later comment from the issue author or maintainer overrides an earlier statement; note this in the report.
- **PR**: a PR number, a PR URL, or a local branch name.
  - Number/URL → `gh pr view <ref> --json number,title,body,url,baseRefName,headRefName,files,commits` and `gh pr diff <ref>`
  - Branch → find the base (the PR base if a PR exists, otherwise ask, or use the repo's default integration branch, e.g. `test`/`develop`/`main`), then `git diff <base>...<branch>` and `git log <base>..<branch> --oneline`
  - If no PR is given, use the current branch against its base.
- If an input is missing or ambiguous, ask once and do not guess. If the issue links other issues or a spec, read them only if they hold requirements this issue relies on.

## 2. Extract requirements

Break the issue into **atomic, testable requirements**, each with ID `R1`, `R2`, …

- Sources: explicit lists or checkboxes, acceptance criteria, "should / must / má / musí" statements, described bugs (the fix is the requirement), expected-behavior sections, mockups, and requirements added in comments.
- Split compound statements ("A and B") into separate requirements.
- Keep the **verbatim quote** (original language) for each requirement and give its source (issue body / comment by @user, date).
- Mark **implicit** requirements that clearly follow from the issue (e.g. "no regression in X", migrations for a new field, translations for new UI strings) as `implicit`. They count toward the verdict only when the issue really implies them, so don't invent scope.
- Items the issue marks out of scope, optional, or "nice to have" go in a separate list and **do not block**.

## 3. Map requirements to code

For each requirement, read the diff **and the surrounding code** (open the changed files, not only the hunks) to judge whether the behavior is actually implemented end to end:

- Find the specific changes that implement it: `path/to/file.py:L10-L42`, plus the function/class/template name.
- Follow the full path: model → form/serializer → view/API → template/JS → permissions → translations → migrations, whichever apply. Missing a layer makes the requirement **Partial**.
- Look for edge cases the issue mentions (empty values, permissions/roles, states, error messages) and check each one.
- Don't trust the PR description or commit messages without checking the code.

Assign one status:

| Status | Meaning |
|---|---|
| ✅ Satisfied | Fully implemented; behavior matches the issue, including the edge cases it mentions. |
| ⚠️ Partial | Some of it is implemented, but a piece, layer, or stated edge case is missing or wrong. |
| ❌ Not satisfied | No implementation found, or the implementation contradicts the requirement. |
| ❓ Unverifiable | Can't be confirmed from code alone (needs runtime, data, or external config, or the requirement is ambiguous). State exactly what is needed to confirm it. |

## 4. Coverage analysis

Report two kinds of coverage for each requirement:

1. **Implementation coverage**: which code changes cover it (from step 3), and what share of the requirement they cover.
2. **Test coverage**: which tests in the PR (or existing tests the PR touches) exercise it.
   - Name the test file and test function, and say what it asserts.
   - Classify it as `Tested` (a test asserts this behavior), `Indirect` (it is exercised but not asserted), or `Untested`.
   - Don't run the test suite unless the user asks or the repo's instructions (CLAUDE.md / AGENTS.md / memory) say how to and it is cheap. If you do run it, use the repo's documented command and report the real output.

Also list **changes not linked to any requirement** (scope creep, unrelated refactors, leftover debug code). These don't change the verdict on their own, but they belong in the report.

## 5. Verdict

- **✅ READY FOR REVIEW**: every blocking requirement is ✅ Satisfied.
- **❌ NOT READY**: any blocking requirement is ⚠️, ❌, or ❓. List exactly what must be done to unblock it.

Missing tests don't block by themselves unless the issue or the repo's contribution rules require them. Always flag them as a recommendation.

## 6. Write the report

Default output path: `~/pr-readiness-reports/<repo-name>/issue-<N>_pr-<M>.md` (create the directory; use `pasted` / `<branch>` when there's no number). If the user gives a path, use it instead. **Never write the report into the reviewed repository** unless the user explicitly asks.

Use this structure:

````markdown
# PR Readiness Report: <PR title> (#<M>) vs. Issue #<N>

- **Issue:** [#N <title>](url)
- **PR:** [#M <title>](url) — `<head>` → `<base>`
- **Reviewed commit:** `<short sha>`
- **Date:** YYYY-MM-DD

## Verdict

**✅ READY FOR REVIEW** / **❌ NOT READY**: one-sentence reason.

| Satisfied | Partial | Not satisfied | Unverifiable | Total |
|---|---|---|---|---|
| x | x | x | x | x |

## Requirements Review

| ID | Requirement (English summary) | Status | Implementation | Tests |
|---|---|---|---|---|
| R1 | … | ✅ Satisfied | `app/views.py:120-158` | Tested |
| R2 | … | ⚠️ Partial | `app/forms.py:40` | Untested |

## Detailed Analysis

### R1 — <short English title>

> <verbatim quote from the issue, original language>
>
> — source: issue body / comment by @user (date)

**Translation:** <English meaning, if the quote is not in English>

**Status:** ✅ Satisfied

**How it is resolved:** <explanation of the behavior the code implements and why that meets the requirement>

**Code covering this requirement:**
- `path/file.py:L10-L42` — `function_name`: <what it does for this requirement>
- `templates/x.html:L5` — <…>

**Test coverage:** Tested / Indirect / Untested — `tests/test_x.py::TestY::test_z` asserts <…>

**Gaps / notes:** <missing parts, edge cases, risks; "None" if fully done>

(repeat for every requirement)

## Coverage Summary

- Implementation coverage: X / Y requirements fully implemented.
- Test coverage: X tested, X indirect, X untested.
- <short paragraph on how well the tests protect the requirements and which areas are riskiest>

## Out-of-scope / Optional Items
- … (non-blocking)

## Changes Not Linked to Any Requirement
- `path/file.py` — <description> (scope creep / refactor / leftover)

## Required Actions Before Review
1. … (only if NOT READY; concrete and actionable, tied to requirement IDs)

## Recommendations (non-blocking)
- …
````

## 7. Reply to the user

After writing the file, reply with a short summary only: the verdict, the counts line, any blocking items (one line each), and the report path. Don't paste the whole report into the chat.

## Rules

- Base every status on code you actually read. Cite file and line numbers for every claim.
- Be strict: if you're unsure whether something is satisfied, it's ❓ or ⚠️, not ✅.
- Don't modify the PR's code. This skill only analyzes and reports.
- Keep all prose, headings, and table text in English. Only `>` quotations from the issue may use the original language.
