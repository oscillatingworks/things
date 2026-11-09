# Sourced by tests/run: the prose rules for every file of the project. No em-dashes.

em_dash="$(printf '\342\200\224')"
check "no em-dash in the project's files" sh -c '
  cd "$1" && ! git ls-files --cached --others --exclude-standard -z | xargs -0 grep -n -- "$2"' _ "$here" "$em_dash"
