# Repository Guidelines

This repo is a library of agent skills that must work in both Claude Code and Codex.

## Layout

- `skills/<skill-name>/SKILL.md` is the source of truth. Supporting files (templates, `references/`, `scripts/`, `examples/`) go in the same folder and are referenced by relative path.
- `.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json` publish the repo as a Claude Code plugin. Skills are discovered from `skills/` automatically; you don't list them in the manifests.
- `scripts/install.sh` symlinks skills into `~/.claude/skills` and `~/.agents/skills`.
- `scripts/validate-skills.sh` runs in CI and must pass.

## Writing skills

- Frontmatter must contain `name` and `description`. `name` matches the folder name, is lowercase kebab-case, and is at most 64 characters. `description` is at most 1024 characters and says both what the skill does and when to use it, with example trigger phrases.
- Keep the body agent-neutral so it reads correctly in both tools:
  - Don't use `$ARGUMENTS` or other Claude Code template variables; Codex doesn't expand them. Say "take X from the arguments or the request" instead.
  - Don't name tools that only one agent has (`AskUserQuestion`, `TodoWrite`, …). Describe the action ("ask the user").
  - Refer to repo instructions as "CLAUDE.md / AGENTS.md".
- Optional Claude Code-only frontmatter (`argument-hint`, `allowed-tools`) is fine; Codex ignores it.
- Keep `SKILL.md` under about 500 lines. Move long reference material into separate files the skill loads when needed.

## Checks

```bash
./scripts/validate-skills.sh
```

When adding a skill, also add a row to the Skills table in `README.md` (the validator checks this) and update the plugin description in `.claude-plugin/marketplace.json`.
