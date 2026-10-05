#!/usr/bin/env bash
# Check that every skill in skills/ loads in both Claude Code and Codex,
# and that the README and plugin manifests are consistent with the skills folder.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
failures=0
fail() { echo "FAIL  $*"; failures=$((failures + 1)); }

# Print the value of a single-line frontmatter field.
field() {
  awk -v key="$2" '
    NR == 1 { if ($0 != "---") exit; next }
    $0 == "---" { exit }
    index($0, key ":") == 1 { sub("^" key ":[[:space:]]*", ""); print; exit }
  ' "$1"
}

count=0
for dir in "$ROOT"/skills/*/; do
  name="$(basename "$dir")"
  file="$dir/SKILL.md"
  count=$((count + 1))

  if [ ! -f "$file" ]; then fail "skills/$name: missing SKILL.md"; continue; fi
  if [ "$(head -n 1 "$file")" != "---" ]; then fail "skills/$name: SKILL.md must start with YAML frontmatter"; continue; fi

  fm_name="$(field "$file" name)"
  desc="$(field "$file" description)"

  [ -n "$fm_name" ] || fail "skills/$name: missing 'name'"
  [ -n "$desc" ] || fail "skills/$name: missing 'description'"
  [ "$fm_name" = "$name" ] || fail "skills/$name: name '$fm_name' must match the folder name"
  echo "$name" | grep -Eq '^[a-z0-9]+(-[a-z0-9]+)*$' || fail "skills/$name: folder name must be lowercase kebab-case"
  [ "${#fm_name}" -le 64 ] || fail "skills/$name: name is longer than 64 characters"
  [ "${#desc}" -le 1024 ] || fail "skills/$name: description is ${#desc} characters (max 1024)"
  # $ARGUMENTS only expands in Claude Code; Codex shows it literally.
  if grep -n '\$ARGUMENTS' "$file" >/dev/null; then fail "skills/$name: uses \$ARGUMENTS, which Codex does not expand"; fi
  grep -q "skills/$name/SKILL.md" "$ROOT/README.md" || fail "skills/$name: not listed in README.md"
done

[ "$count" -gt 0 ] || fail "no skills found in skills/"

for json in "$ROOT"/.claude-plugin/*.json; do
  python3 -m json.tool "$json" >/dev/null 2>&1 || fail "${json#$ROOT/}: invalid JSON"
done

echo "Checked $count skill(s)."
if [ "$failures" -gt 0 ]; then
  echo "$failures problem(s) found." >&2
  exit 1
fi
echo "All skills valid."
