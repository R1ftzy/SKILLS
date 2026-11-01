# Claude Code skills: `/ask`, `/rewrite`, `/report`

Three slash commands for [Claude Code](https://claude.com/claude-code). Each one is a folder with a `SKILL.md` file.

| Command | What it does | Works anywhere? |
|---|---|---|
| `/ask <question>` | Answers like a search engine or Claude on the web: read-only, no file edits, and it only looks at the repo when the question is about the repo. | Yes |
| `/rewrite [notes]` | Sends the **complete** current version of the script being worked on in one code block, ready to copy-paste. No `...`, no diffs. | Yes |
| `/report [ID \| family \| project] [notes]` | Writes a scraper progress report (`report-<ID>.md`) from live scrape-hub numbers and the repo state. | Only on an s1d-labs box with `scrape_hub` access |

## Install

Copy the folders you want into your personal skills folder (all projects) or into a repo's `.claude/skills/` (that repo only):

```bash
mkdir -p ~/.claude/skills
cp -r ask rewrite report ~/.claude/skills/
```

Restart Claude Code (or open a new session), then type `/ask`, `/rewrite` or `/report`.

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

### `/report` (s1d-labs scrapers only)
```
/report G04
/report budget-pfms focus on the failures
```
- Run it inside a family repo. `G04` → writes `report-G04.md`. If that report already exists, the new version gets a "Changes since last report" section.
- Collects live data with `report/hub_snapshot.sh`, which is read-only `psql` against `scrape_hub`. It also gathers git state, tests and CI runs (`gh run list`).
- Writes a fixed-format report with status, TL;DR, pick-up-here, findings, data, gaps, risks and next steps. Numbers come from live queries only, and it never includes secrets.
- **Requirements:** `psql` access to the `scrape_hub` database, plus `gh` and `git`. The skill calls the script at `~/.claude/skills/report/hub_snapshot.sh`, so install it in your personal skills folder or change that path in `report/SKILL.md`.

## Notes

- `/ask` and `/report` set `disable-model-invocation: true`, so they run only when you type them. `/rewrite` doesn't set this flag, so Claude may also use it on its own when you ask for "the full code".
- `$ARGUMENTS` in each `SKILL.md` is replaced with whatever you type after the command.
