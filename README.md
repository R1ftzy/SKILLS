# Claude Code skills: `/ask`, `/rewrite`, `/bridge`

Three slash commands for [Claude Code](https://claude.com/claude-code). Each one is a folder with a `SKILL.md` file.

| Command | What it does |
|---|---|
| `/ask <question>` | Answers like a search engine or Claude on the web: read-only, no file edits, and it only looks at the repo when the question is about the repo. |
| `/rewrite [notes]` | Sends the **complete** current version of the script being worked on in one code block, ready to copy-paste. No `...`, no diffs. |
| `/bridge [project] [task]` | Claude (on a server) writes the code; a local AI worker (e.g. DeepSeek in opencode on your PC) builds, runs, tests and reports back through a synced folder. First run analyses the repo and sets everything up. |

## Install

Copy the folders into your personal skills folder (all projects) or into a repo's `.claude/skills/` (that repo only):

```bash
mkdir -p ~/.claude/skills
cp -r ask rewrite bridge ~/.claude/skills/
```

Restart Claude Code (or open a new session), then type `/ask`, `/rewrite` or `/bridge`.

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

### `/bridge`

Claude works on a server but can't run your project (your GPU, your OS, files that must stay on your PC).
`/bridge` pairs it with a **local AI worker** on your PC, such as DeepSeek in opencode. Claude writes the code,
the worker builds, runs and tests it, and both talk through files in a folder synced between the two machines.

**How to use it**

1. **Sync the project folder** between your PC and the server, both ways. Mutagen is one option:
   ```
   mutagen sync create --name=myproject C:\path\to\myproject user@server:~/myproject --ignore=build --ignore=node_modules
   ```
   Keep build folders **outside** the synced folder. The sync breaks builds (lock files, git clones) and
   copies gigabytes to the server.
2. **On the server, in the project, run** `/bridge`. On the first run Claude:
   - analyses the repo: build and test commands, CI, the OS it needs, local-only data, GPU and other hardware;
   - shows a **bridge plan**: what the worker will do, the programs to install, the agent harness
     (opencode, Claude Code, Codex CLI, Gemini CLI, Antigravity), a model, and any MCP server it needs
     (usually none);
   - asks for your choices, then writes `team.md` (the worker's instructions) and the wait and watch scripts
     for your OS and harness;
   - gives you the setup steps.
3. **On your PC, follow those steps**: install the programs, allow the agent to run commands in the
   project folder, then start the worker:
   - TUI: open the agent in the project folder and send `Read team.md and follow section 7.`
   - Headless: `pwsh -File bridge\watch.ps1 -Model <model>` or `sh bridge/watch.sh <model>`.
4. **Test run:** Claude sends task `0000` (versions, paths, git state). When it passes, the bridge is ready.
5. **Work:** ask for what you want, for example `/bridge build it and capture the title screen`.
   - Claude edits code and writes numbered tasks to `bridge/tasks/`.
   - The worker runs them and writes `bridge/results/`.
   - Claude reads the results and repeats until done.

**Rules built in:**
- Each task starts with a sync guard, so the worker never builds stale code.
- The worker only reports facts. It never edits code, installs anything or runs git writes.
- Private data stays on your PC, and tests use copies of user data.
- Builds never run inside the synced folder.

Files: `bridge/SKILL.md` (Claude's side), `bridge/templates/` (`team.md`, `wait`/`watch` scripts),
`bridge/reference/harnesses.md` (harness commands, permissions and MCP suggestions).

## Notes

- `/ask` sets `disable-model-invocation: true`, so it runs only when you type it. `/rewrite` doesn't set this flag, so Claude may also use it on its own when you ask for "the full code".
- `$ARGUMENTS` in each `SKILL.md` is replaced with whatever you type after the command.
- The `s1d` branch adds `/report`, a scraper progress-report command for the s1d-labs scrape pool.
