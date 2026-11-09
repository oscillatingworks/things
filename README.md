<p align="center">
  <img src="assets/logo.svg" width="160" height="160" alt="things: an 8-bit speech bubble with an exclamation mark">
</p>

<h1 align="center">things</h1>

<p align="center"><b>Things you probably didn't know about your project, while Claude Code waits.</b></p>

You wait a lot: for a review, a build, a teammate. When your Claude Code session goes idle,
things has Claude tell you one short fact about your project, with its source so you can check
it. If you stay away, a new fact comes every 30 minutes.

```
Things you probably didn't know about rounds

A `review wait` that sees the machine suspend appends `<from> <to> <gap>` to a `.suspends` file,
and `review status` subtracts those gaps, so a closed laptop lid does not count as review time.
Source: src/watch.rs:8
```

## Install

Tell Claude Code, from inside your project:

> Set up things in this project: https://github.com/oscillatingworks/things

Say "for all my projects" to have it everywhere. Then run `/reload-plugins` or start a new
session. To change a setting below, ask for it in the same prompt.

Or by hand (you need `jq`):

```sh
claude plugin marketplace add oscillatingworks/things --scope local
claude plugin install things@things --scope local    # --scope user for every project
```

To remove it, ask Claude, or run `claude plugin uninstall things@things --scope local`.

## Use

Nothing to do: the first fact comes about a minute after Claude stops and you have not typed.
You can also ask for one at any time: "tell me something I don't know about this repo".

## Settings

Set these in your environment, or in the `env` block of a Claude Code settings file.

| Setting | Default | What it does |
| --- | --- | --- |
| `THINGS_REPEAT` | `30` | Minutes between facts while you stay away. `off`: one fact per break. |
| `THINGS_IDLE` | `on` | `off`: no facts on their own. You can still ask. |

Each fact costs one short Claude turn. With the defaults, an idle hour costs up to 3 turns, and
the facts go on until you come back. To pay for fewer turns, set a longer `THINGS_REPEAT`.

## More

[AGENTS.md](AGENTS.md) has the details: how it works, its limits, other install options, and how
to work on it.

## License

MIT. See [LICENSE](LICENSE).
