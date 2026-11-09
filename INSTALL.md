# Installing things (for the agent)

The user pointed you at this repository to set up things. Do the whole setup in one go, without
stopping for confirmation, except where a step says to ask. Run the commands from the root of the
user's project. At the end, report what you did.

## 1. Check the prerequisites

```sh
claude --version     # the Claude Code CLI
jq --version         # the hooks need jq
```

- No `claude` on PATH: tell the user that things is a Claude Code plugin and needs the Claude
  Code CLI, and stop.
- No `jq`: ask the user whether to install it (for example `brew install jq`, `apt install jq`
  or `pacman -S jq`). Install it on a yes. Without jq the plugin installs, but the idle facts do
  not come.

## 2. Pick the scope

Pick it from the user's words. Do not ask when the words are clear.

- **local** (the default): this project, for this user only. "Set up things in this project."
- **user**: every project of this user. "For all my projects", "everywhere", "globally".
- **project**: this project, for everyone who works on it. "For the team", "for everyone". This
  writes `.claude/settings.json`, which the team shares. Do not commit it: tell the user that a
  commit makes the plugin active for the whole team.

## 3. Install it

```sh
claude plugin marketplace add oscillatingworks/things --scope <scope>
claude plugin install things@things --scope <scope>
```

Both commands are safe to run again. When the user gave a local folder or another source
instead of the GitHub repository, pass it to `marketplace add`.

## 4. Check it

```sh
claude plugin list
```

`things@things` must show `Status: ✔ enabled` with the scope you picked.

## 5. Settings (only when the user asks)

The defaults: a fact about a minute after Claude stops and the user has not typed, then one more
every 30 minutes while the user stays away, with no limit. When the user asks for other values,
add them to the `env` block of the settings file of the same scope
(`.claude/settings.local.json`, `~/.claude/settings.json` or `.claude/settings.json`). Keep the
other keys of that file:

| Setting | Default | What it does |
| --- | --- | --- |
| `THINGS_REPEAT` | `30` | Minutes between facts while the user stays away (at most 115). `off`: one fact per break. |
| `THINGS_IDLE` | `on` | `off`: no facts on their own. The user can still ask. |

## 6. Report

Tell the user, briefly:

- the scope, and the settings file it changed;
- to run `/reload-plugins` or start a new session, because the plugin loads at session start.
  You cannot run a slash command for the user;
- what comes next: about a minute after Claude stops and they have not typed, Claude tells one
  fact about the project, with its source. They can also ask for one at any time: "tell me
  something I don't know about this repo";
- that each fact costs one short Claude turn, that the facts go on every 30 minutes until they
  come back, and the settings that change it (`THINGS_REPEAT=60`, or `THINGS_REPEAT=off`);
- how to remove it:
  `claude plugin uninstall things@things --scope <scope>` and
  `claude plugin marketplace remove things --scope <scope>`.

Do not commit anything unless the user asks.
