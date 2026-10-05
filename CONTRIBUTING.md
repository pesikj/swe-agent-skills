# Contributing

## Add a skill

1. Create `skills/<skill-name>/SKILL.md`:

   ```markdown
   ---
   name: <skill-name>
   description: <What it does. Use when the user asks "...", "...", or invokes <skill-name> by name.>
   ---

   # <Title>

   <Instructions for the agent.>
   ```

2. Follow the writing rules in [AGENTS.md](AGENTS.md) so the skill works in both Claude Code and Codex.
3. Add a row to the Skills table in [README.md](README.md) and list the skill in the plugin description in `.claude-plugin/marketplace.json`.
4. Run `./scripts/validate-skills.sh`.
5. Run `./scripts/install.sh` and try the skill in Claude Code and Codex.
6. Bump `version` in `.claude-plugin/plugin.json` so plugin users receive the update.
