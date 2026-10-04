# claude-swe-skills

Personal [Claude Code](https://docs.claude.com/en/docs/claude-code) skills for software engineering work. They aren't tied to any single repository.

## Skills

| Skill | What it does |
|---|---|
| [`pr-requirements-check`](skills/pr-requirements-check/SKILL.md) | Checks a PR against every requirement in its issue and writes an English Markdown readiness report. The PR is ready for review only if all requirements are satisfied. |

## Install

```bash
git clone git@github.com:pesikj/claude-swe-skills.git ~/repositories/claude-swe-skills
~/repositories/claude-swe-skills/install.sh
```

`install.sh` symlinks each folder in `skills/` into `~/.claude/skills/`. Because they are symlinks, edits in this repo take effect immediately.

## Adding a skill

1. Create `skills/<skill-name>/SKILL.md` with `name` and `description` frontmatter.
2. Run `./install.sh` to link it.
3. Add a row to the table above, then commit.
