# Sourced by tests/run: install.sh, against a temporary Claude Code config folder and project.

installer="$here/install.sh"

check "install.sh refuses an unknown scope" eval '! "$installer" --scope team "$work" 2> /dev/null'
check "install.sh refuses an unknown option" eval '! "$installer" --nope 2> /dev/null'
check "install.sh --help prints the usage" eval '"$installer" --help | grep -q -- "--scope local"'

# A stub claude: --version works, every other command fails with exit $STUB_RC and prints
# {"failureCode": ...}: the code claude gives when the thing is absent, or $STUB_CODE when set.
mkdir -p "$work/stub"
cat > "$work/stub/claude" << 'STUB'
#!/bin/sh
[ "$1" = "--version" ] && exit 0
case "$2" in
  uninstall) code="${STUB_CODE:-not_installed}" ;;
  *) code="${STUB_CODE:-not_configured}" ;;
esac
echo "{\"outcome\":\"failed\",\"failureCode\":\"$code\"}"
exit "$STUB_RC"
STUB
chmod +x "$work/stub/claude"
stub_uninstall() { # stub_uninstall RC [CODE]
  STUB_RC="$1" STUB_CODE="${2:-}" PATH="$work/stub:$PATH" "$installer" --uninstall "$work" > "$work/stub.out" 2>&1
}
check "--uninstall when nothing is installed succeeds" stub_uninstall 1
check "--uninstall fails when claude fails for another reason" eval '! stub_uninstall 17 disk_full'
check "a failed --uninstall does not say it removed the plugin" eval '! grep -q removed "$work/stub.out"'

if claude --version > /dev/null 2>&1; then
  project_dir="$work/project"
  mkdir -p "$project_dir" "$work/config"
  git -C "$project_dir" init -q
  local_settings="$project_dir/.claude/settings.local.json"
  run_installer() { CLAUDE_CONFIG_DIR="$work/config" "$installer" "$@" > "$work/install.out" 2>&1; }

  check "install.sh installs in local scope" run_installer "$project_dir"
  check "local scope enables the plugin in settings.local.json" \
    jq -e '.enabledPlugins["things@things"] == true' "$local_settings"
  check "local scope adds this folder as the marketplace" \
    jq -e --arg p "$here" '.extraKnownMarketplaces.things.source.path == $p' "$local_settings"
  check "install.sh runs again without a change" run_installer "$project_dir"
  check "install.sh --uninstall removes it" run_installer --uninstall "$project_dir"
  check "after --uninstall the plugin is not enabled" \
    jq -e '(.enabledPlugins["things@things"] // false) == false' "$local_settings"
  check "install.sh --uninstall runs again without an error" run_installer --uninstall "$project_dir"

  # A relative --source is read from the caller's folder, not from the project folder.
  ln -s "$here" "$work/source"
  mkdir -p "$work/project2"
  check "a relative --source works with a project in another folder" \
    eval '(cd "$work" && run_installer --source ./source "$work/project2")'
  check "the marketplace path is the absolute source folder" \
    jq -e --arg p "$work/source" '.extraKnownMarketplaces.things.source.path == $p' "$work/project2/.claude/settings.local.json"

  # The commands of INSTALL.md, as an agent runs them from the project root (here with this folder
  # as the source, and a config folder of their own).
  mkdir -p "$work/project3" "$work/config3"
  git -C "$work/project3" init -q
  agent_step() { (cd "$work/project3" && CLAUDE_CONFIG_DIR="$work/config3" "$@") > "$work/agent.out" 2>&1; }
  check "INSTALL.md step 3: marketplace add" agent_step claude plugin marketplace add "$here" --scope local
  check "INSTALL.md step 3: install" agent_step claude plugin install things@things --scope local
  check "INSTALL.md step 4: the list shows things enabled" eval '
    agent_step claude plugin list && grep -q "things@things" "$work/agent.out" && grep -q "enabled" "$work/agent.out"'
  check "INSTALL.md step 6: uninstall" agent_step claude plugin uninstall things@things --scope local
  check "INSTALL.md step 6: marketplace remove" agent_step claude plugin marketplace remove things --scope local

  check "install.sh installs in user scope (a temporary config folder)" run_installer --scope user
  check "user scope enables the plugin in the config folder" \
    jq -e '.enabledPlugins["things@things"] == true' "$work/config/settings.json"
else
  skip "install.sh against claude (claude is not on PATH, or it does not run)"
fi
