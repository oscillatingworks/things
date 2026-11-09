#!/bin/sh
# Installs the things plugin into Claude Code.
#
#   ./install.sh [--scope local|project|user] [--source SOURCE] [--uninstall] [PROJECT]
#
#   --scope local    this project, for you only: .claude/settings.local.json (the default)
#   --scope project  this project, for everyone who works on it: .claude/settings.json (commit it)
#   --scope user     every project, for you only: ~/.claude/settings.json
#   --source         where the plugin comes from: a folder, a git URL, or a GitHub owner/repo.
#                    The default is the folder of this script, or oscillatingworks/things when
#                    the script runs from a pipe.
#   --uninstall      remove the plugin and its marketplace from that scope
#   PROJECT          the project folder for local and project scope (default: the current folder)
#
# It runs `claude plugin marketplace add` and `claude plugin install`, which you can also run by hand.
# Running it again changes nothing. The hooks need jq.
set -eu

fail() {
  echo "things: $*" >&2
  exit 1
}

scope="local"
source=""
uninstall=""
project="."
while [ $# -gt 0 ]; do
  case "$1" in
    --scope)
      [ $# -ge 2 ] || fail "--scope needs a value"
      scope="$2"
      shift 2
      ;;
    --source)
      [ $# -ge 2 ] || fail "--source needs a value"
      source="$2"
      shift 2
      ;;
    --uninstall)
      uninstall=1
      shift
      ;;
    -h | --help)
      sed -n '2,17p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    -*) fail "unknown option $1 (see --help)" ;;
    *)
      project="$1"
      shift
      ;;
  esac
done

case "$scope" in
  local | project | user) ;;
  *) fail "unknown scope $scope: use local, project or user" ;;
esac

command -v claude > /dev/null 2>&1 || fail "the claude CLI is not on PATH: install Claude Code first"
command -v jq > /dev/null 2>&1 || echo "things: warning: jq is not on PATH, and the hooks do nothing without it" >&2

if [ -z "$source" ]; then
  here="$(cd "$(dirname "$0")" 2> /dev/null && pwd || true)"
  if [ -n "$here" ] && [ -f "$here/.claude-plugin/marketplace.json" ]; then
    source="$here"
  else
    source="oscillatingworks/things"
  fi
fi

# A folder source is read from the folder you run the script in, before the cd below.
if [ -d "$source" ]; then
  source="$(cd "$source" && pwd)"
fi

if [ "$scope" != "user" ]; then
  [ -d "$project" ] || fail "no project folder $project"
  cd "$project"
fi

# remove CODE COMMAND...: runs a claude command with --json. A failure with the failureCode CODE
# means it was not there, which is fine. Any other failure stops the script.
remove() {
  absent="$1"
  shift
  if out="$("$@" --json 2>&1)"; then
    return 0
  fi
  if printf '%s' "$out" | grep -q "\"failureCode\":\"$absent\""; then
    return 0
  fi
  printf '%s\n' "$out" >&2
  fail "could not run: $*"
}

if [ -n "$uninstall" ]; then
  remove not_installed claude plugin uninstall things@things --scope "$scope"
  remove not_configured claude plugin marketplace remove things --scope "$scope"
  echo "things: removed from $scope scope"
  exit 0
fi

claude plugin marketplace add "$source" --scope "$scope"
claude plugin install things@things --scope "$scope"
echo "things: installed in $scope scope from $source. Start a new Claude Code session (or run /reload-plugins) to load it."
