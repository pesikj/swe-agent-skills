# Install in Claude Code

## Option 1: Plugin marketplace (recommended)

```text
/plugin marketplace add pesikj/swe-agent-skills
/plugin install swe-skills@swe-skills
/reload-plugins
```

The plugin installs every skill in `skills/`. Plugin skills are namespaced, so you invoke them as `/swe-skills:<skill-name>`. Claude also loads them automatically when your request matches a skill's description.

Update later with:

```text
/plugin marketplace update swe-skills
```

## Option 2: Symlink from a clone

Use this if you edit the skills yourself and want changes to apply immediately.

```bash
git clone https://github.com/pesikj/swe-agent-skills.git ~/repositories/swe-agent-skills
~/repositories/swe-agent-skills/scripts/install.sh --claude
```

This links each skill into `~/.claude/skills/`. Skills installed this way are not namespaced: `/pr-requirements-check`.

To install for a single project instead (committed with that repo):

```bash
~/repositories/swe-agent-skills/scripts/install.sh --claude --project path/to/repo
```

Set `CLAUDE_SKILLS_DIR` to link somewhere other than `~/.claude/skills`.
