---
name: things
description: Tell the user one short, true, surprising fact about the current project, under the heading "Things you probably didn't know about <project>". Use when a "things:" message says the session is idle, when the user asks for a thing they didn't know, a fun fact, a curious detail or a gotcha about this project or codebase, or when the user runs /things:things.
---

# Things you probably didn't know

The user is waiting: for a review, a build, a teammate. While everything is on hold, you tell them
one thing about their project that they probably do not know, so they keep learning.

## When

- A `things:` message from the plugin's hook says the session is idle. Tell one fact, and only the
  fact: do not go on with the earlier task, do not ask a question, change nothing.
- The user asks for one (for example "tell me something I don't know about this repo", or
  `/things:things`). Tell one fact, or as many as they ask for.

Do not add facts to other replies on your own.

## The format

Exactly this, and nothing before or after it:

```
**Things you probably didn't know about <project>**

<One sentence with the fact.>
Source: `<path>:<line>` (or a commit, a document, a command)
```

`<project>` is the name of the repository folder, or the name the project gives itself in its
README. Keep the heading word for word: the plugin finds the facts it has told by that heading.

## A good fact

- **True and checkable.** You saw it in this project: in the code, the configuration, the docs,
  the git history, or a measurement you made in this session. Read the source before you tell it.
  Never tell a fact from memory or from a guess. Say no more than the source says: do not widen
  a claim to "all", "every", "never" or "the whole machine" when the source shows one case.
- **Surprising.** Something a person who works on the project every day could still not know:
  how a part works inside, why a decision was made, a gotcha, a setting that does not do what its
  name says, a number that is larger or smaller than expected.
- **Specific.** Name the file, the class, the setting, the number, the date.
- **Short.** One sentence, not two or three: join the parts with a colon or a comma, or leave
  a part out. At most about 50 words. Plain words. No metaphors.
- **New.** Not told before in this session. The hook's message lists the facts already told. Also
  look back in the conversation. A fact about the same subject in other words is a repeat.

Two good examples, from a search service:

> BCX's search results have a recency boost, but it never fires in production: BCX stores
> `updated_at` as epoch seconds in a date field that reads milliseconds, so every document looks as
> if it was written in January 1970 and gets the same boost.

> A Searchright index on staging is about 6 GB, but the writer node keeps only about 0.5 MB of it
> on its own disk: it is a cached node, the segments live on the object store, and the node fetches
> a block only when a search or a merge needs it.

Bad facts: "This project uses Ruby" (not surprising), "The tests might be slow" (not checked),
"There is a lot of code in app/" (not specific).

## Where to find facts

Start with what you already learned in this session: the files you read, the commands you ran, the
problem you are working on. A fact close to the current work is the most useful. When you need a
new one, look in a few places, with read-only commands only:

- Comments that explain a reason: `grep -rn -E "because|workaround|HACK|NOTE|XXX|on purpose" ...`
- Configuration with an unusual value: timeouts, limits, sizes, retries, feature flags.
- The git history: `git log --format='%h %ad %s' --date=short` for the oldest commit, a revert, a
  large rename, a file that changed many times (`git log --format= --name-only | sort | uniq -c |
  sort -rn | head`).
- Docs, architecture notes, ADRs, runbooks, CHANGELOG entries that explain a decision.
- Tests that pin an edge case: their names often say what can go wrong.
- Code paths where the name and the behavior differ.

Keep the search small: a few reads, no more than a minute. Never run a command that changes
files, starts services, or reaches production. If you find nothing that meets the rules, tell a
smaller fact that does, not a weak one.
