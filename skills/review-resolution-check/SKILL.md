---
name: review-resolution-check
description: Checks whether review comments marked as resolved on a GitHub PR or GitLab MR were really resolved. Loads the comment thread with all nested replies, finds the reply that names the fixing commit (such as "Resolved in <sha>" posted by review-comment-analysis), analyzes what the comment asked for and what the commit changed, and rates the fix as Fully resolved, Partially resolved, or Not resolved. For partial or missing fixes it explains what is left and proposes concrete steps to finish. Takes one comment thread (URL or ID) or a whole PR/MR, in which case it checks every thread with such a reply. Writes an English Markdown report and posts nothing. Use when the user asks "did this commit really fix the comment", "verify the resolved review comments", "check the fixes on this PR", "was note 87130 resolved properly", "review the Resolved in replies", or invokes review-resolution-check by name.
argument-hint: <comment URL/ID | MR/PR #/URL> [output path]
---

# Review Resolution Check

Goal: tell whether a commit that claims to resolve a review comment actually does. A "Resolved in <sha>" reply is a claim, not proof: the commit may fix one of two call sites, address the symptom the reviewer mentioned but not the cause, be reverted by a later commit, or never reach the PR branch. This skill compares what the comment asked for with what the code does now and gives a clear verdict, plus the remaining steps when the fix falls short.

Scope is the comment and its fix. Don't review the rest of the PR/MR, and don't re-argue whether the comment was worth fixing; the author already decided that. If you notice something important in passing (for example, the fix introduces a bug in the lines it changed), put one line in Notes.

The report is in **English**. Quotes of the comment stay in the original language, followed by an English translation when needed.

## 1. Resolve the input

Take the comment thread or PR/MR and an optional output path from the arguments or the request.

- **GitLab note** (URL ending `#note_<id>`, or MR + note id): fetch all discussions with `glab api --paginate "projects/:id/merge_requests/<iid>/discussions?per_page=100"` and take the discussion containing that note, with every note in it.
- **GitHub review comment** (URL with `#discussion_r<id>`): fetch `gh api repos/{owner}/{repo}/pulls/<n>/comments --paginate` and collect the thread: the comment, and every comment whose `in_reply_to_id` points to it. Thread resolution state is in GraphQL (`pullRequest.reviewThreads { isResolved comments { databaseId } }`).
- **GitHub general comment or review body** (`#issuecomment-<id>`, `#pullrequestreview-<id>`): these have no threads. Look for later PR comments (`gh api repos/{owner}/{repo}/issues/<n>/comments`) that link to or quote the original and name a commit.
- **Whole PR/MR** (number or URL): check every thread, resolved or not, that contains a resolution reply (step 2). List the threads without one in a single "Skipped" line.
- Also fetch the PR/MR title, source and target branch, author, and current head commit (GitLab `sha`, GitHub `headRefOid`) for the report header and step 4.

**Mask secrets.** If a comment quotes a password, token, key, or connection string, replace the value with `***` in everything you write.

## 2. Find the resolution reply

Look through the replies in the thread for one that says the comment was resolved and references a commit:

- `Resolved in <sha>`, the format review-comment-analysis posts, or similar wording ("Fixed in", "Addressed in", "Done in", in any language).
- The commit can be a full or short hash (7–40 hex characters) or a commit URL. GitHub and GitLab render hashes as links; take the hash from the reply's raw text.

Edge cases:

- **Several resolution replies** (for example, a first fix and a follow-up): evaluate all the named commits together, oldest first, and say so.
- **A reply that claims a fix without a commit** ("fixed", "done"): there is nothing to check against. Report it as "No commit referenced" and, if the user wants, they can give the commit.
- **No resolution reply at all**: for a single thread, say so in chat and don't write a report. For a whole PR/MR, the thread goes on the Skipped line.
- Read the rest of the thread too. Later replies may narrow the request ("a log message is enough here") or reopen it ("this still fails for empty input"). An agreed narrower scope becomes the target for the evaluation; a reopened point counts against the fix.

## 3. Analyze the comment

Work out what "resolved" means for this comment before you look at the fix, so the commit doesn't shape your reading of the request.

- Read the code the comment refers to at the commit it was written on (GitLab `position.head_sha` / `new_path` / `new_line`, GitHub `original_commit_id` / `path` / `original_line`) with `git show <sha>:<path>`. If the commit isn't available locally, `git fetch origin <sha>`.
- Read enough context to understand the issue: the whole function, its callers if the comment is about behavior, and related tests.
- Split the comment into **points**: each independent thing it asks for (`P1`, `P2`, …). A comment like "this crashes on empty input, and the same pattern is in `parse_header`" has two points. Points that only elaborate the same issue stay together.
- For each point, write down what a full resolution looks like in concrete terms: which code must behave differently, in which cases, and whether a test is reasonably expected (for a bug fix on a tested path, usually yes; for a rename, no).

## 4. Analyze the changes

1. **Check the commit exists and is part of the PR/MR.** `git fetch origin <source-branch>` (and `git fetch origin <sha>` if needed), then `git merge-base --is-ancestor <sha> <pr-head>`. A commit that isn't in the PR/MR head can't resolve the comment: say where it is (another branch, not found) and rate it Not resolved.
2. **Read the commit.** `git show <sha>`: which files and functions it changes, and how. Separate changes that serve the comment from unrelated changes in the same commit.
3. **Check what happened after it.** `git log --oneline <sha>..<pr-head> -- <paths>` for the files involved. If later commits changed the same code, read them and check whether the fix still stands at the current head (reverted, rewritten, partly undone). The verdict is about the code at the current head, not the commit in isolation.
4. **Check the cases the comment is about.** Walk through the scenario from the comment against the code at the current head: the failing input, the missed call site, the unhandled error. Look for other places with the same problem when the comment says or clearly implies they should be fixed too ("same pattern elsewhere", "all callers").
5. **Check tests**, where step 3 said a test is expected: did the commit add or update one that would fail without the fix? You can run the relevant tests if it is quick and doesn't change the working tree's state, but don't check out other branches to do it; say in Notes what you couldn't run.

## 5. Evaluate

Rate each point:

| Point status | Meaning |
|---|---|
| ✅ Addressed | The code at the current head does what the point asked, in all the cases it named. |
| ⚠️ Partially addressed | Some cases or places are fixed, others aren't; or the symptom is fixed but not the cause the comment pointed to; or the fix works but an expected test is missing. |
| ❌ Not addressed | The commit doesn't touch this point, its change doesn't fix it, or a later commit undid it. |

Then the overall verdict for the thread:

| Verdict | When |
|---|---|
| ✅ Fully resolved | Every point is Addressed. |
| ⚠️ Partially resolved | At least one point is Addressed or Partially addressed, and at least one is not fully Addressed. |
| ❌ Not resolved | No point is Addressed or Partially addressed, or the commit isn't in the PR/MR head. |

A missing test on its own makes a point Partially addressed only when step 3 said a test was reasonably expected. Don't downgrade a fix for style choices that differ from what you would have written, as long as it does what the comment asked.

Always write a **justification** of two to four sentences, with `path:line` and commit references: what the comment needed, what the commit does, and where the gap is, if any.

## 6. Steps to fully resolve (Partial and Not resolved only)

For every thread that isn't Fully resolved, explain **why** in plain terms (which point, which case or place, what the code does now) and propose **concrete steps** to finish:

- One step per gap, in the order they should be done: what to change, in which file and function, with a short sketch (a few lines of code or a diff) where it helps.
- Include the test to add when one is missing: what it should exercise and what it should assert.
- Keep the steps to what the comment asked. If finishing it properly would need a much bigger change than the comment justifies, say so and offer the smallest complete option.

## 7. Write the report

Save the report to `~/swe-skill-reports/<repo-name>/<file-name>`, where `<repo-name>` is the reviewed repository's name (from its remote URL, or its top-level directory name), and create the directory if it doesn't exist. Reports always go outside the reviewed repository: if the user gives an output path, use it only if it is outside the repository; otherwise use the default path and tell the user why. File name: `review-resolution-check_<mr-or-pr-number>-<note-id>.md` for a single thread, `review-resolution-check_<mr-or-pr-number>-all.md` for a whole PR/MR.

For a **single thread**, use this structure (for a whole PR/MR, see below):

````markdown
# Review Resolution Check: <PR/MR title> — <note/comment id>

- **PR/MR:** [!N <title>](url) — `<source>` → `<target>`, head `<short sha>`
- **Comment:** [note <id>](url) by @<author>, <date>
- **Resolution:** [reply](url) by @<author>, <date> — commit `<short sha>` (<in PR head / not in PR head>)
- **Date:** YYYY-MM-DD

## The Comment

> <verbatim comment, original language, secrets masked>

**Translation:** <only if not English>

**Where:** `path:line`, `function_name` at `<short sha>`

```<lang>
<5–15 lines of the referenced code at the comment's commit>
```

**What it asks for:**

| Point | Request | Full resolution means |
|---|---|---|
| P1 | <one line> | <concrete expected behavior or change> |
| P2 | <one line> | <…> |

<one line on thread replies that changed the scope, if any>

## The Changes

**Commit:** `<short sha>` <subject> — <files changed>

```diff
<the relevant part of the diff, trimmed to what concerns the comment>
```

**Since then:** <later commits touching the same code and their effect, or "No later changes to these lines.">

## Evaluation

| Point | Status | Evidence |
|---|---|---|
| P1 | ✅ Addressed | <`path:line` and what the code does now> |
| P2 | ❌ Not addressed | <…> |

| Verdict |
|---|
| ✅ Fully resolved / ⚠️ Partially resolved / ❌ Not resolved |

**Justification:** <two to four sentences>

## Steps to Fully Resolve

<only for Partial / Not resolved>

**Why it falls short:** <plain explanation>

1. <step, with file, function and a short sketch>
2. <test to add, if missing>

## Notes

- <what you couldn't verify (tests not run, commit not fetchable), anything important noticed in passing; omit if none>

---

Generated by [review-resolution-check](https://github.com/pesikj/swe-agent-skills)
````

For a **whole PR/MR**, start with the same header (without the Comment and Resolution lines) and a summary, then one section per thread:

````markdown
## Summary

| ✅ Fully | ⚠️ Partially | ❌ Not resolved | Total |
|---|---|---|---|
| x | x | x | x |

| # | Comment | Location | Commit | Verdict |
|---|---|---|---|---|
| T1 | [note 87130](url): <short title> | `path:line` | `abc1234` | ✅ Fully resolved |
| T2 | [note 86713](url): <short title> | `path:line` | `def5678` | ⚠️ Partially resolved |

Skipped: <threads without a resolution reply, replies without a commit — one line>
````

After the summary, give each thread the single-thread sections (The Comment, The Changes, Evaluation, Steps to Fully Resolve) one heading level lower, under `## T1 — <short title>`. Then add Notes and the `Generated by` line.

The `Generated by …` line must always be the last line of the report.

## 8. Reply to the user

After writing the file, reply in chat with a short summary only: one line per thread (ID, short title, commit, verdict) and the report path. For anything not fully resolved, add the main gap in a few words. Don't paste the whole report into the chat.

## Rules

- Base every verdict on code you actually read: the comment's commit, the fix commit, and the current PR/MR head. Cite `path:line` and commits.
- Don't take the resolution reply's word for it, and don't take the commit message's either. Verify against the code.
- Read-only: don't modify code, post replies, or resolve or reopen threads. Don't change git state (no checkout, stash, reset, commit, or push); `git fetch`, `git show`, `git diff`, and `git log` are fine.
- Evaluate against what the comment asked (narrowed by agreement in the thread), not against your own idea of the ideal fix.
- Don't add review findings of your own beyond a one-line note.
- Mask any credential that appears in a comment.
