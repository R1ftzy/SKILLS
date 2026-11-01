# Claude Code skills: `/ask` and `/rewrite`

Two slash commands for [Claude Code](https://claude.com/claude-code). Each one is a folder with a `SKILL.md` file.

| Command | What it does |
|---|---|
| `/ask <question>` | Answers like a search engine or Claude on the web: read-only, no file edits, and it only looks at the repo when the question is about the repo. |
| `/rewrite [notes]` | Sends the **complete** current version of the script being worked on in one code block, ready to copy-paste. No `...`, no diffs. |

## Install

Copy the folders into your personal skills folder (all projects) or into a repo's `.claude/skills/` (that repo only):

```bash
mkdir -p ~/.claude/skills
cp -r ask rewrite ~/.claude/skills/
```

Restart Claude Code (or open a new session), then type `/ask` or `/rewrite`.

## Usage

### `/ask`
```
/ask what's the difference between a process and a thread?
/ask where is the retry logic defined in this repo?
```
- Never creates, edits or deletes files, and never runs commands that change anything.
- General questions are answered from Claude's own knowledge; it searches the web only for recent or uncertain facts.
- Repo questions get minimal read-only lookups, with `path:line` citations.
- Short answer first, then brief detail. No "shall I implement this?".

### `/rewrite`
```
/rewrite
/rewrite also rename the main function to run()
```
- Picks the most recent script in the conversation (or the one you name) and applies every change agreed so far.
- Outputs the whole file: no placeholders or "rest unchanged". It bumps the version field if there is one, e.g. a userscript `@version`.
- Adds 2–3 lines on what changed. It doesn't write to disk unless you ask.

## Notes

- `/ask` sets `disable-model-invocation: true`, so it runs only when you type it. `/rewrite` doesn't set this flag, so Claude may also use it on its own when you ask for "the full code".
- `$ARGUMENTS` in each `SKILL.md` is replaced with whatever you type after the command.
- The `s1d` branch adds `/report`, a scraper progress-report command for the s1d-labs scrape pool.
