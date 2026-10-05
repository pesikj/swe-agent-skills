# Install in Codex

Codex loads skills from `~/.agents/skills` (all projects) and `.agents/skills` inside a repo (that repo only). Each skill is the same `SKILL.md` folder Claude Code uses.

## Option 1: Symlink from a clone (recommended)

```bash
git clone https://github.com/pesikj/swe-agent-skills.git ~/repositories/swe-agent-skills
~/repositories/swe-agent-skills/scripts/install.sh --codex
```

For a single project:

```bash
~/repositories/swe-agent-skills/scripts/install.sh --codex --project path/to/repo
```

Set `CODEX_SKILLS_DIR` to link somewhere other than `~/.agents/skills`. Restart Codex after installing new skills.

## Option 2: Copy one skill

```bash
mkdir -p ~/.agents/skills
cp -R skills/pr-requirements-check ~/.agents/skills/
```

Copies don't update when you `git pull`, so prefer symlinks.

## Use

- Mention it: `$pr-requirements-check 17 42`
- Or pick it from `/skills`
- Or describe the task; Codex selects skills by their `description`.
