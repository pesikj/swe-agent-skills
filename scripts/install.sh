#!/usr/bin/env bash
# Symlink every skill in skills/ into the skill folders that Claude Code and Codex read.
# Safe to re-run after adding new skills. Edits in this repo take effect immediately.
#
# Usage: scripts/install.sh [--claude] [--codex] [--project <dir>]
#   --claude         link into ~/.claude/skills   (or $CLAUDE_SKILLS_DIR)
#   --codex          link into ~/.agents/skills   (or $CODEX_SKILLS_DIR)
#   --project <dir>  link into <dir>/.claude/skills and <dir>/.agents/skills instead of your home folder
# With no target flag, links for both Claude Code and Codex.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
claude=false
codex=false
project=""

while [ $# -gt 0 ]; do
  case "$1" in
    --claude) claude=true ;;
    --codex) codex=true ;;
    --project) project="${2:?--project needs a directory}"; shift ;;
    -h|--help) sed -n '2,10p' "$0"; exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 1 ;;
  esac
  shift
done

if [ "$claude" = false ] && [ "$codex" = false ]; then
  claude=true
  codex=true
fi

if [ -n "$project" ]; then
  project="$(cd "$project" && pwd)"
  claude_dir="$project/.claude/skills"
  codex_dir="$project/.agents/skills"
else
  claude_dir="${CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}"
  codex_dir="${CODEX_SKILLS_DIR:-$HOME/.agents/skills}"
fi

link_all() {
  local target_dir="$1"
  echo "→ $target_dir"
  mkdir -p "$target_dir"
  for skill in "$REPO_DIR"/skills/*/; do
    local name link
    name="$(basename "$skill")"
    link="$target_dir/$name"
    if [ -L "$link" ]; then
      ln -sfn "${skill%/}" "$link"
      echo "  updated  $name"
    elif [ -e "$link" ]; then
      echo "  skipped  $name ($link exists and is not a symlink)" >&2
    else
      ln -s "${skill%/}" "$link"
      echo "  linked   $name"
    fi
  done
}

[ "$claude" = true ] && link_all "$claude_dir"
[ "$codex" = true ] && link_all "$codex_dir"
exit 0
