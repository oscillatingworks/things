# Sourced by tests/run: the manifests and the skill's frontmatter.

for f in .claude-plugin/plugin.json .claude-plugin/marketplace.json hooks/hooks.json; do
  check "$f is valid JSON" jq -e . "$here/$f"
done

check "plugin and marketplace agree on the name and the description" sh -c '
  p="$1/.claude-plugin/plugin.json"; m="$1/.claude-plugin/marketplace.json"
  [ "$(jq -r .name "$p")" = things ] &&
  [ "$(jq -r ".plugins[0].name" "$m")" = things ] &&
  [ "$(jq -r .description "$p")" = "$(jq -r ".plugins[0].description" "$m")" ]' _ "$here"

check "the hook script is executable" test -x "$hook"

skill="$here/skills/things/SKILL.md"
frontmatter() { awk 'NR == 1 && $0 == "---" { on = 1; next } on && $0 == "---" { exit } on' "$skill"; }

check "SKILL.md starts with a frontmatter block" sh -c '[ "$(head -n 1 "$1")" = "---" ] && [ "$(grep -c "^---$" "$1")" -ge 2 ]' _ "$skill"
check "the skill's name is its folder name" test "$(frontmatter | sed -n 's/^name: //p')" = things
description="$(frontmatter | sed -n 's/^description: //p')"
check "the skill has a description" test -n "$description"
check "the description fits the listing (1536 characters)" test "${#description}" -le 1536
check "the description says when to use the skill" sh -c 'printf "%s" "$1" | grep -q "Use when"' _ "$description"
check "the skill keeps the heading the hook looks for" grep -qF "Things you probably didn't know about <project>" "$skill"

# The agent's guide, the README and the code agree.
for f in INSTALL.md install.sh; do
  check "$f installs with marketplace add and install things@things" eval '
    grep -q "claude plugin marketplace add" "$here/$f" && grep -q "claude plugin install things@things" "$here/$f"'
  check "$f removes with uninstall things@things and marketplace remove" eval '
    grep -q "claude plugin uninstall things@things" "$here/$f" && grep -q "claude plugin marketplace remove things" "$here/$f"'
done
check "AGENTS.md sends an installing agent to INSTALL.md first" eval 'head -n 5 "$here/AGENTS.md" | grep -q "(INSTALL.md)"'
check "the README gives the install prompt" grep -q "^> Set up things in this project: https://github.com/oscillatingworks/things" "$here/README.md"
for setting in THINGS_REPEAT THINGS_REPEAT_MAX THINGS_IDLE; do
  check "the hook, INSTALL.md and the README all know $setting" eval '
    grep -q "$setting" "$hook" && grep -q "| \`$setting\`" "$here/INSTALL.md" && grep -q "| \`$setting\`" "$here/README.md"'
done

if claude --version > /dev/null 2>&1; then
  check "claude plugin validate passes" claude plugin validate "$here"
else
  skip "claude plugin validate (claude is not on PATH, or it does not run)"
fi

if shellcheck --version > /dev/null 2>&1; then
  check "shellcheck finds nothing" eval 'cd "$here" && shellcheck -x hooks/things-hook install.sh tests/run'
else
  skip "shellcheck (not on PATH, or it does not run)"
fi

check "the README logo exists and is an SVG" eval '
  logo="$(sed -n "s/.*<img src=\"\([^\"]*\)\".*/\1/p" "$here/README.md" | head -n 1)" &&
  [ -n "$logo" ] && head -c 200 "$here/$logo" | grep -q "<svg "'
