# things

If the user pointed you at this repository to set up things in their project, follow
[INSTALL.md](INSTALL.md). The rest of this file helps you answer their questions and work on
things.

A Claude Code plugin: while the session is idle, Claude tells the user one fact about their
project. The repository is the plugin and its own marketplace (`.claude-plugin/`). The README is
for people. This file has the details.

## How it works

The plugin has a skill and three hooks.

- **The skill** (`skills/things/SKILL.md`) holds the rules: what makes a good fact (true and
  checked in the project, surprising, specific, short, not told before in the session), where to
  look for one, and the format. The user can also ask for a fact, or run `/things:things`.
- **The idle hook** runs on Claude Code's `idle_prompt` notification, with `asyncRewake`. Claude
  Code sends it about 60 seconds after Claude finishes a reply when the user has not typed, also
  while a background shell command runs. Exit 2 with a message on stderr wakes Claude: tell one
  fact, and nothing else.
- **The stop hook** runs after each reply. It notes the facts told in the session, so the next
  wake lists them and Claude does not repeat one, and it notes whether the reply was a fact.
- **The prompt hook** (`UserPromptSubmit`) cancels a waiting repeat. A wake also runs it, so it
  does nothing while a wake is pending.

### How often

1. About 60 seconds after a normal reply (the user's turn, or Claude's when a background task
   ends), if the user has not typed, Claude tells the first fact.
2. While the session stays idle, one more fact every `THINGS_REPEAT` minutes (15), at most
   `THINGS_REPEAT_MAX` (8) more facts after the first one.
3. A prompt, or a normal reply, stops the wait. The count starts again from step 1.

Claude Code has no timer that a plugin can use. For the repeat, the idle hook that fires after a
fact waits in the background (timeout 7200 seconds in `hooks.json`, wait capped at 6900 seconds
by `longest_wait` in the script, so `THINGS_REPEAT` is at most 115 minutes) and wakes Claude when
the time comes.

### Limits

- Each fact costs one model turn, with a few file reads.
- Claude Code does not send `idle_prompt` while a background agent (subagent) runs. A background
  shell command does not stop it.
- No idle wakes in `claude -p` or other headless runs.
- The facts are as good as the model's checks. The skill asks Claude to read the source of each
  fact and to give it.
- When the user types while a wake is pending, the repeat count is not reset.
- A prompt that ends before the idle hook process starts (the exact 60-second edge) does not
  cancel it. The Stop of that turn does, so a wake can come during a user turn only when that
  turn is longer than the repeat.

### State

One folder per session under `$CLAUDE_PLUGIN_DATA/sessions/<session id>/` (or
`$XDG_STATE_HOME/things`): `told` (the facts), `quiet`, `pending`, `last-fact`, `repeats`,
`generation`, and the `lock` folder. Sessions untouched for two weeks are removed.

## Install options

The usual install is a prompt to the agent, which follows [INSTALL.md](INSTALL.md). For a script
(a dotfiles setup, CI), use `install.sh`:

`install.sh [--scope local|project|user] [--source SOURCE] [--uninstall] [PROJECT]`

- `local` (the default): one project, for the user only (`.claude/settings.local.json`).
- `project`: one project, for everyone on it (`.claude/settings.json`, committed). Teammates get
  the plugin from GitHub, so install with `--source oscillatingworks/things`.
- `user`: every project (`~/.claude/settings.json`).
- `--source`: a folder, a git URL, or a GitHub `owner/repo`. The default is the script's folder,
  or `oscillatingworks/things` when the script runs from a pipe.

The script runs these commands, which also work by hand:

```sh
claude plugin marketplace add oscillatingworks/things --scope local
claude plugin install things@things --scope local
```

## Layout

- `skills/things/SKILL.md`: the rules for a fact and the format. The heading
  "Things you probably didn't know about" is a contract with `hooks/things-hook`, which finds the
  facts told by it. Change both together.
- `hooks/hooks.json`, `hooks/things-hook`: the hooks. POSIX sh and jq only. The hook must never
  fail loudly: without jq or with bad input it exits 0. The prompt hook must print nothing: its
  stdout goes to Claude. Every change to the state happens under the `lock` folder, and a wake
  happens only when the `generation` did not change since the idle hook started.
  `THINGS_REPEAT_SECONDS`, `THINGS_TICK` and `THINGS_TEST_PAUSE` exist for the tests and live
  trials.
- `install.sh`: wraps `claude plugin marketplace add` and `claude plugin install`.
- `assets/logo.svg`: the logo, a 32×32 pixel drawing in the colors of rounds.
- `tests/run`: every check. Run it before you ask for a review.

## Develop

`tests/run` checks the manifests, the skill's frontmatter, the prose rules, the hooks (with the
JSON Claude Code sends) and `install.sh` (against a temporary `CLAUDE_CONFIG_DIR` and a stub
claude). It needs `jq`, and uses `claude` and `shellcheck` when they run. To try the plugin
without installing it: `claude --plugin-dir /path/to/things`.

## Rules

- Prose: plain words, short sentences, no em-dashes, no metaphors. `tests/run` checks the
  em-dashes.
- Facts about Claude Code's hooks come from its docs or a local test. Note the test in the
  change, for example a run in a scratch project with `claude --plugin-dir`.
- Never install the plugin into the real `~/.claude` in a test: use a temporary
  `CLAUDE_CONFIG_DIR`.
