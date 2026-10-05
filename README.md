# SWE Skills

Agent skills for software engineering work. Each skill is a folder with a `SKILL.md` file in the open [Agent Skills](https://agentskills.io) format, so the same files work in **Claude Code** and **OpenAI Codex**.

## Skills

| Skill | What it does |
|---|---|
| [`pr-requirements-check`](skills/pr-requirements-check/SKILL.md) | Checks a PR against every requirement in its issue and writes an English Markdown readiness report. The PR is ready for review only if all requirements are satisfied. |

## Install

### Claude Code: plugin marketplace

```text
/plugin marketplace add pesikj/swe-agent-skills
/plugin install swe-skills@swe-skills
```

Skills from a plugin are namespaced, e.g. `/swe-skills:pr-requirements-check`. Details: [docs/INSTALL-CLAUDE-CODE.md](docs/INSTALL-CLAUDE-CODE.md).

### Codex

Clone the repo and link the skills into `~/.agents/skills`:

```bash
git clone https://github.com/pesikj/swe-agent-skills.git ~/repositories/swe-agent-skills
~/repositories/swe-agent-skills/scripts/install.sh --codex
```

Then use `$pr-requirements-check` or just describe the task. Details: [docs/INSTALL-CODEX.md](docs/INSTALL-CODEX.md).

### Both, from a local clone

```bash
git clone https://github.com/pesikj/swe-agent-skills.git ~/repositories/swe-agent-skills
~/repositories/swe-agent-skills/scripts/install.sh            # ~/.claude/skills and ~/.agents/skills
~/repositories/swe-agent-skills/scripts/install.sh --project . # only for the current repo
```

`install.sh` creates symlinks, so edits in this repo take effect immediately and `git pull` updates every agent.

## Usage

Ask in plain language and the agent picks the skill from its description:

```text
Can PR #42 go to review? It implements issue #17.
```

Or invoke it by name: `/pr-requirements-check 17 42` in Claude Code, `$pr-requirements-check 17 42` in Codex.

## Repository layout

```text
skills/<skill-name>/SKILL.md   one folder per skill (the source of truth)
.claude-plugin/                Claude Code plugin + marketplace manifests
scripts/install.sh             symlink skills into Claude Code / Codex folders
scripts/validate-skills.sh     frontmatter and portability checks (run in CI)
docs/                          install guides
AGENTS.md                      instructions for agents working on this repo
```

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

[MIT](LICENSE)
