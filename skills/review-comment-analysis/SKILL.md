---
name: review-comment-analysis
description: Analyzes code review comments on a GitLab MR or GitHub PR, decides whether each is worth resolving, and on request implements the chosen fix and posts the reply. Analysis reads the comment with the code it references at the commit it was written on, checks whether its claim is true, proposes fixes, and scores quality gain vs. complexity cost (0-4 each) for a Resolve / Decline verdict, with replies drafted for declines. Takes one comment (URL, ID, or pasted text) or a whole MR/PR (every unresolved thread) and writes an English Markdown report. Follow-up steps: implement a selected fix, iterate on it with the user, stage it with a "Code review <id>" commit message (never commits), then, once the user has pushed, verify the fix and post "Resolved in <sha>" with gh / glab. Use when the user asks "should I fix this comment", "go through the MR comments", "implement fix A for F1", "apply the recommended fix", "reply to the reviewer", "post the resolution", or invokes review-comment-analysis by name.
argument-hint: <comment URL/ID | MR/PR #/URL | pasted comment> [output path] | implement <finding> [fix] | post reply <finding>
---

# Review Comment Analysis

Goal: help the MR/PR author decide, for each review comment, whether resolving it **improves the code enough to justify the complexity it adds**. Comments come from colleagues and from AI reviewers; both can be right, partly right, or wrong. Resolving every comment by reflex is how code grows guards for impossible states, configuration nobody uses, and abstractions with one caller. Declining a valid, cheap fix is the opposite mistake. This skill makes that trade-off explicit and gives the author a ready answer either way.

Scope is the comment itself. Don't review the rest of the MR and don't add findings of your own; if you notice something important in passing, put one line in Notes.

The report is in **English**. Quotes of the comment stay in the original language, followed by an English translation when needed. Draft replies use the language of the thread (see step 6).

## Workflow

The skill has three phases. Each one starts only when the user asks for it, and between them the user is in control: they review the code, commit, and push.

1. **Analyze** (steps 1–8): the default when the user gives a comment or an MR/PR. Writes the report and changes nothing.
2. **Implement a fix** (step 9): when the user asks to apply a fix from the report ("implement fix A for F1", "apply the recommended fix for note 87130"). Ends with the fix staged and a commit message prepared, never committed.
3. **Post the reply** (step 10): when the user, after committing and pushing, asks to answer the comment ("post the reply for F1", "reply that it's resolved"). Verifies the pushed commit, then posts `Resolved in <sha>`.

Figure out which phase the request is for. If it is a follow-up in a new conversation, find the earlier report at the default path (step 7) instead of redoing the analysis.

## 1. Resolve the input

Take the comment or MR/PR and an optional output path from the arguments or the request.

- **GitLab note** (URL ending `#note_<id>`, or MR + note id): fetch all discussions with `glab api --paginate "projects/:id/merge_requests/<iid>/discussions?per_page=100"` and find the discussion containing that note. Use the whole discussion, so replies are included.
- **GitHub comment** (URL with `#discussion_r<id>` or `#issuecomment-<id>`): review comments come from `gh api repos/{owner}/{repo}/pulls/<n>/comments --paginate`, general comments from `gh api repos/{owner}/{repo}/issues/<n>/comments`, review bodies from `gh api repos/{owner}/{repo}/pulls/<n>/reviews`. Thread resolution state is only in GraphQL (`pullRequest.reviewThreads { isResolved comments { databaseId } }`).
- **Whole MR/PR** (number or URL): review every **unresolved** thread, meaning resolvable and not resolved, plus general (non-diff) comments from people other than the author that have no answer from the author yet. Skip system notes, resolved threads, and pure approvals or "LGTM" comments. List what you skipped in one line.
- **Pasted text**: ask for the MR/PR or the file and line if they can't be inferred. Otherwise search the code for identifiers quoted in the comment.
- Also fetch the MR/PR title, source and target branch, and the author, for the report header.

**Split comments into findings.** A single comment (AI reviewers especially) often contains several independent points under headings or bullets. Each independent point is one **finding** with ID `F1`, `F2`, …. Points that only elaborate the same issue stay together.

**Merge duplicates.** The same finding repeated across several notes (a bot re-reviewing after each push) is analyzed once. Cite all the notes that raise it ("note 87130; also notes 87117, 87122").

**Mask secrets.** If a comment quotes a password, token, key, or connection string, replace the value with `***` in everything you write.

## 2. Read the code in context

Comments refer to the code **as it was when they were written**, and that code may have moved or changed since.

- For a diff comment, take the path, line, and commit from the comment's position (GitLab `position.new_path` / `new_line` / `head_sha`, or `old_path` / `old_line` for comments on removed lines; GitHub `path` / `line` / `commit_id`, or `original_line` / `original_commit_id` when the line is outdated). Read that version with `git show <sha>:<path>`. If the commit isn't available locally, `git fetch origin <sha>` is fine because it doesn't touch the working tree.
- Read enough around the line to understand it: the whole function, its callers if the comment is about behavior, and the related test if one exists.
- Then find the same code in the **current** version of the branch (working tree included) and check `git log --oneline <sha>..HEAD -- <path>`. If the code changed since the comment, say how, and check whether the comment is already resolved. Commit messages like "Address review note 86713" are a hint, but confirm it in the code.
- For a general comment that names files or symbols, locate them in the current code the same way.
- Read the replies in the thread. A colleague or the author may already have answered, agreed on a direction, or narrowed the request.

## 3. Explain the comment and check its claim

Write a short explanation that someone who hasn't seen the code can follow:

- **Where:** `path:line` and the function or class, plus a short snippet (about 5–15 lines) of the code the comment points at, taken from the comment's commit.
- **What the reviewer says:** their point in one or two plain sentences: the problem they see and the change they ask for. Translate it if it isn't in English.
- **Is it true?** Verify the claim against the code rather than trusting it. AI reviewers often describe behavior the code doesn't have, and humans sometimes misread the diff. Pick one:
  - *Valid*: the problem exists as described.
  - *Partially valid*: the problem exists, but it is narrower or different than described. Say exactly what is true.
  - *Invalid*: the code doesn't behave that way. Show why, citing lines.
  - *Already resolved*: fixed by a later commit or elsewhere in the MR. Cite the commit or the line.

Keep this section tight: full context, no padding. The reader should understand the comment without opening the MR, and nothing more.

## 4. Propose fixes

Propose **at least one** concrete fix, even for comments you'll end up declining, because the verdict compares the gain against the cost of a real fix. Usually two or three options are useful, and one of them should be the smallest change that addresses the core of the comment. Typical spread:

- the minimal fix (a guard, a rename, a one-line change, a docstring),
- the fix the reviewer literally asked for,
- a different approach if there is a clearly better one (sometimes "delete the code" or "document the behavior" beats adding code).

For each option, give a short description, a sketch (a few lines of code or a diff, not a full implementation), the files it touches, and its quality-gain and complexity-cost scores. Then **select the recommended fix** and say in one sentence why it beats the others.

If the claim is *Invalid* or *Already resolved*, there is nothing to fix. Say so instead of inventing a fix, and go straight to the verdict.

## 5. Evaluate quality gain vs. complexity cost

Score the **recommended fix** on two scales.

**Quality gain (Q)**: how much better the code gets if the fix lands.

| Q | Level | Meaning |
|---|---|---|
| 0 | None | No real improvement: subjective preference, or it addresses something that doesn't happen. |
| 1 | Cosmetic | Naming, formatting, comment or doc wording. |
| 2 | Minor | Small readability or maintainability gain, or robustness on a rare path. |
| 3 | Significant | Fixes a bug on a plausible path, removes a real maintenance hazard, closes a realistic security gap, or gives a measurable performance win. |
| 4 | Critical | Prevents data loss or corruption, a security vulnerability, or a crash or wrong result on a main path. |

**Complexity cost (C)**: how much harder the code gets to read, change, and test.

| C | Level | Meaning |
|---|---|---|
| 0 | None | The code gets simpler or shorter (deletion, simplification, clearer name). |
| 1 | Trivial | A few lines in one place, no new concepts. |
| 2 | Small | One function changes: a new branch, parameter, or helper, plus small test updates. |
| 3 | Moderate | Several files, a new abstraction, setting, or dependency, or a behavior change callers can notice. |
| 4 | Large | A redesign, a cross-module refactor, new infrastructure, a migration, or a breaking API change. |

When scoring, think about the likely scenario rather than the worst imaginable one. Also count costs the comment doesn't mention: new tests needed, new failure modes, new configuration to document, and how much of a hot or untested path the change touches.

**Verdict** (the final decision is always Resolve or Decline):

| Situation | Verdict |
|---|---|
| Claim is *Invalid* or *Already resolved* | ❌ Decline |
| Q = 0 | ❌ Decline |
| Q > C | ✅ Resolve |
| Q = 4, whatever C is | ✅ Resolve, or, if it is outside this MR's scope, ❌ Decline here and recommend a separate issue or MR |
| Q = C | Judgment call. Lean ✅ Resolve when Q ≥ 3, or when the fix is local and covered by existing tests. Lean ❌ Decline when it touches untested or rarely run code. Explain the tie-break. |
| Q < C | ❌ Decline |

A finding about **pre-existing code the MR doesn't change** is out of scope for this MR. Score it anyway, so the author knows whether a follow-up is worth it, but decline it here.

Always write a **justification** of two to four sentences: what the gain concretely is, what the cost concretely is, and why the balance tips the way it does. "Improves robustness" isn't a justification; "a `None` here comes only from `load_config()` which already raises on a missing key (`config.py:42`), so the guard protects a state that can't occur" is.

For every ❌ Decline, assign exactly one **decline reason**:

| Reason | Use when |
|---|---|
| Corner case | The scenario is possible but rare, and its impact is low. |
| Cannot happen | Types, validation, or the only callers already prevent the scenario. Cite where. |
| Too complex for the gain | The issue is real, but the fix costs more than it gives (Q ≤ C). |
| Already resolved | Fixed by a later commit, or handled elsewhere in the MR. Cite it. |
| Out of scope | Pre-existing code or a separate concern; belongs in its own MR or issue. |
| Incorrect | The comment misreads the code; the claimed behavior doesn't exist. |
| Preference | Subjective style, with no project convention behind it. |
| Intended behavior | The behavior is a deliberate design decision. Cite where it is documented or explain the reason. |

## 6. Draft a reply (Decline only)

For every declined finding, draft a reply the author can paste into the thread. For resolved findings, don't draft a reply; the answer is posted after the fix is pushed (step 10). If the author has already answered the point in the thread and the answer holds up against the code, don't draft a new reply; recommend resolving the thread instead.

Style, following how engineers answer reviews when they're declining for a good reason:

- First line: a short verdict, for example "Not in this change.", "No change.", "Already handled.", or "This can't happen here."
- Then two to four plain, factual sentences giving the reason, with concrete references (function names, `path:line`, commit, test name). Explain the trade-off honestly; if the point is valid but not worth it, say that.
- If the finding deserves a follow-up (out of scope, Q ≥ 3), say where it belongs: a separate MR or issue.
- No thanks, apologies, or praise ("Great catch!"), no hedging, no restating the comment.
- Use the language of the thread: reply in Czech to a Czech comment, in English to an English one. If the user asks for a specific language, use that.
- Mask secrets here too.

## 7. Write the report

Default output path: `~/review-comment-reports/<repo-name>/<mr-or-pr-number>-<note-id>.md` for a single comment, `~/review-comment-reports/<repo-name>/<mr-or-pr-number>-all.md` for a whole MR/PR (create the directory). If the user gives a path, use it. Don't write into the reviewed repository unless the user explicitly asks.

For a **single comment**, use this structure (for a whole MR/PR, see below):

````markdown
# Review Comment Analysis: <MR/PR title> — <note/comment id>

- **MR/PR:** [!N <title>](url) — `<source>` → `<target>`
- **Comment:** [note <id>](url) by @<author>, <date>
- **Location:** `path:line` at `<short sha>` (now `path:line` / unchanged / removed)
- **Date:** YYYY-MM-DD

## Verdict

**✅ Resolve with Fix A** / **❌ Decline — <reason>**: one-sentence summary. Quality gain Q=<x>/4 (<level>), complexity cost C=<y>/4 (<level>).

## The Comment

> <verbatim comment or the relevant part of it, original language, secrets masked>

**Translation:** <only if not English>

## Context

**Where:** `path:line`, `function_name`

```<lang>
<5–15 lines of the referenced code at the comment's commit>
```

**What the reviewer says:** <one or two sentences>

**Is it true?** Valid / Partially valid / Invalid / Already resolved: <evidence with file:line>

## Fix Options

| Fix | Change | Q | C |
|---|---|---|---|
| **A (recommended)** | <one line> | x | y |
| B | <one line> | x | y |

### Fix A — <title> (recommended)

<what changes and where>

```<lang or diff>
<short sketch>
```

**Why this one:** <one sentence>

### Fix B — <title>

<…>

## Evaluation

| Quality gain | Complexity cost | Verdict |
|---|---|---|
| <x> — <level> | <y> — <level> | ✅ Resolve / ❌ Decline — <reason> |

**Justification:** <two to four sentences>

## Draft Reply

<only for Decline; ready to paste>

> <reply text>

## Notes

- <thread replies that matter, things that need running code to confirm, anything important noticed in passing; omit if none>

---

Generated by [review-comment-analysis](https://github.com/pesikj/swe-agent-skills)
````

For a **whole MR/PR**, the report starts with the same header (without the Comment and Location lines) and a summary, then one section per finding:

````markdown
## Summary

| ✅ Resolve | ❌ Decline | Total |
|---|---|---|
| x | x | x |

| ID | Finding | Source | Location | Claim | Q | C | Verdict |
|---|---|---|---|---|---|---|---|
| F1 | <short title> | [note 87130](url), also 87117 | `path:line` | Valid | 3 | 1 | ✅ Resolve (Fix A) |
| F2 | <short title> | [note 86713](url) | `path:line` | Partially valid | 1 | 3 | ❌ Too complex for the gain |

Skipped: <resolved threads, approvals, system notes — one line>
````

After the summary, give each finding the single-comment sections (The Comment, Context, Fix Options, Evaluation, Draft Reply) one heading level lower, under `## F1 — <short title>`. End with an **All Draft Replies** section that collects every decline reply in order (`### F2 — <title>` followed by the quote of the original point and the reply), so the author can answer every declined point in one place. Then add Notes and the `Generated by` line.

The `Generated by …` line must always be the last line of the report.

## 8. Reply to the user

After writing the file, reply in chat with a short summary only: one line per finding (ID, short title, verdict, Q/C) and the report path. Don't paste the whole report into the chat. End with one line saying the user can ask to implement any of the fixes.

Phase 1 ends here. Don't start implementing until the user asks.

## 9. Implement a fix (on request)

The user picks a finding and a fix. They may pick the recommended fix, another option, or a fix for a finding the report declined; that is their call. If they name a finding without a fix, use the recommended one. If the report or the finding can't be found, run steps 1–5 for that comment first.

**Check the working tree before editing.**

- The current branch must be the MR/PR source branch, up to date enough to contain the code the fix touches. If it isn't, stop and tell the user; don't check out, pull, or rebase on your own.
- Note what `git status` shows now. Changes that are already there belong to the user. Keep them out of the fix, and if they touch the same files as the fix, tell the user before editing, because staging those files would mix both changes into the commit.

**Implement.** Make the change the chosen fix describes, matching the surrounding code's style, and nothing more: no extra refactors, and no fixes for other findings. If implementing shows that the fix doesn't work as sketched (the sketch missed a caller, a test breaks for a real reason), stop and explain instead of quietly growing the change. Update or add tests only where the fix needs them. Run the tests and linters that cover the changed code, and report their results honestly.

**Hand over for review.** Summarize what changed (files, a short diff or the key lines, test results) and ask the user to review. Then stay in this phase: the user may ask questions about the change or ask for modifications. Answer and apply them, and run the relevant tests again after each modification.

**Stage and prepare the commit message.** When the user says the change is ready:

- Stage only the files the fix changed: `git add <file> …`. Never `git add -A` or `git add .`, which would sweep in unrelated work. If a file contains both the fix and the user's earlier changes, say so instead of staging it whole.
- Prepare the commit message `Code review <id>`, where `<id>` is the comment's ID: the GitLab note ID, or the GitHub comment ID. For a finding merged from duplicate notes, use the note the report lists first. If the user asked to fix several comments together, list them: `Code review 87130, 86713`.
- Show `git diff --cached --stat` and the message, ready to use, e.g. `git commit -m "Code review 87130"`.

**Don't commit and don't push.** The user commits and pushes themselves. Tell them that once it's pushed, they can ask you to post the reply.

## 10. Post the reply (on request)

The user asks to reply to a resolved comment. Before posting anything, check that the reply would be true.

1. **Find the fix commit.** Use the hash the user gives. Otherwise search the source branch: `git log --format='%H %s' --grep='Code review <id>' origin/<source-branch>`. If there is no match, or several that aren't clearly one fix, ask the user for the hash.
2. **Check it was pushed.** Run `git fetch origin <source-branch>` (it doesn't touch the working tree) and `git merge-base --is-ancestor <sha> origin/<source-branch>`. Also confirm the MR/PR's current head contains it (GitLab `sha`, GitHub `headRefOid`), since the MR may track a different remote. If the commit isn't there, stop: tell the user it hasn't been pushed and post nothing.
3. **Check the fix fully resolves the comment.** Read `git show <sha>` and the affected code at `origin/<source-branch>`, then go through every point of the finding (re-read the comment and the thread, not only the report). Check that the change does what the comment asked or what the chosen fix described, and that no later commit reverted or broke it. If something is only partly addressed, list exactly what is missing and don't post. The user decides whether to extend the fix or post anyway.
4. **Check the thread.** If it is already resolved or already has an answer saying it's fixed, tell the user instead of posting a duplicate.
5. **Post** exactly this text, with the full 40-character hash (both GitHub and GitLab turn it into a commit link):

   ```text
   Resolved in <sha>
   ```

   - GitLab, reply in the comment's discussion: `glab api -X POST "projects/:id/merge_requests/<iid>/discussions/<discussion_id>/notes" -f body="Resolved in <sha>"`.
   - GitHub review (diff) comment, reply in its thread: `gh api -X POST repos/{owner}/{repo}/pulls/<n>/comments/<comment_id>/replies -f body="Resolved in <sha>"`. Reply to the thread's first comment.
   - GitHub general comment or review body: these have no threads, so a bare "Resolved in …" would be ambiguous. Post `gh pr comment <n> --body "<link to the comment>"$'\n\n'"Resolved in <sha>"` and tell the user you added the link.

6. **Report back** with a link to the posted reply. Don't resolve the thread; leave that to the reviewer or the user.

If several findings were fixed, handle each one separately: each gets its own checks and its own reply.

## Rules

- Base the explanation and the verdict on code you actually read at the comment's commit and at the current head. Cite `path:line`.
- Don't trust the comment's description of the code. Verify it.
- During analysis (steps 1–8), don't modify code and don't change git state (no checkout, stash, reset, or commit). Use `git show` and `git diff` to read other revisions.
- Modify code only in step 9, only for the fix the user chose, and only after they ask.
- Never commit, push, amend, stash, reset, or check out a branch. The only write to git you make is staging the fix's files in step 9; `git fetch` is fine.
- Post only in step 10, only `Resolved in <sha>`, and only after the checks pass. Never resolve threads. Other replies (such as decline replies) are drafts for the user to post.
- Don't add review findings of your own beyond a one-line note.
- Mask any credential that appears in a comment.
