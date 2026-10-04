#!/usr/bin/env bash
# Symlink every skill in skills/ into ~/.claude/skills. Safe to re-run after adding new skills.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="${CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}"
mkdir -p "$TARGET_DIR"

for skill in "$REPO_DIR"/skills/*/; do
  name="$(basename "$skill")"
  link="$TARGET_DIR/$name"
  if [ -L "$link" ]; then
    ln -sfn "${skill%/}" "$link"
    echo "updated  $name"
  elif [ -e "$link" ]; then
    echo "skipped  $name ($link exists and is not a symlink)" >&2
  else
    ln -s "${skill%/}" "$link"
    echo "linked   $name"
  fi
done
