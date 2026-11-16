---
name: bridge
description: Lead/worker loop between Claude (lead, on this VPS) and a local DeepSeek worker (opencode on the user's Windows PC) through a Mutagen-synced folder. Claude writes code and task files; the worker builds, runs, tests, captures and writes result files. Use when the user types /bridge, asks to "get deepseek to build/run/test", or asks to set the bridge up for a project.
---

# /bridge: Claude writes, the local worker runs

Claude (the **lead**) runs on the VPS and cannot build or run the program, see local-only data
(ROMs, saves, hardware), or reach the user's PC. A **worker** (DeepSeek in opencode, on Windows) runs
in the same project folder, which **Mutagen syncs both ways** (for example `C:\Users\<you>\PROJECTS\VPS-synced` ⇄
`~/sync` on the server). The folder is the channel: there is no git step, no branch and no network call.

Arguments: `/bridge [project folder] [what to do]`. With no folder, use the current project.

## 1. Setup (once per project; skip if `bridge/` and `team.md` exist)

1. Ask the user only what is not on disk:
   - the local Windows path of the synced project (for example `C:\Users\<you>\PROJECTS\VPS-synced\<project>`);
   - local-only data folders (ROMs, saves, datasets) that must never enter the synced folder;
   - the worker model (for example `opencode-go/deepseek-v4.1-flash`).
2. Create `bridge/tasks/` and `bridge/results/`, and copy `templates/wait.ps1` and `templates/watch.ps1`
   from this skill into `bridge/`.
3. Write `team.md` from `templates/team.md`. Fill every `<…>` placeholder. Add a "Tools" section that
   names the project's own build/run commands. The worker uses those, never hand-written commands.
4. Keep the bridge out of git:
   - add `bridge/` to `.git/info/exclude`;
   - add `team.md` to `.gitignore` only if the user wants it there.
5. Build trees must be **outside** the synced folder. Mutagen races git and CMake lock files, so
   FetchContent clones fail in a synced folder. Use the project's build-root override; add one if it is missing.
   Tell the user to add Mutagen ignores for build folders.
6. Send task `0000-hello` (template in `team.md` §8). Then tell the user how to start the worker:
   - **TUI (preferred):** start opencode in the project folder and type `Read team.md and follow section 7.`
   - **Headless:** `pwsh -File bridge\watch.ps1 -Model <model>`. Always pass `-Model`: a default model once hit its usage limit and stalled the loop.

## 2. The loop (every task)

1. **Code first.** Make the source edits on the VPS. Check what you can here (syntax-only compiles,
   unit tests, shader compiles, `--print` dry runs). Only the run itself needs the worker.
2. **Write the task.**
   - Path: `bridge/tasks/NNNN-slug.md`. NNNN is 4 digits: the highest number in `tasks/` or `results/` plus 1.
   - Format: see §3.
   - **Step 0 is always a sync guard:** a string that only exists in your newest edit. The worker
     waits (30 s × 5) until the file contains it. Mutagen can deliver the task before the source.
   - The last line is `END`. The worker also waits until the file is 20 s old. Write the task in one Write call.
3. **Never edit a task the worker may have picked up** (`bridge/status.txt` says `running NNNN`).
   The worker can read it half-synced. Queue a new number instead.
4. **Wait without polling.** Run one background Bash command and continue other work; you are notified when it ends:
   `until [ -f bridge/results/NNNN-slug.md ]; do sleep 10; done; sleep 3; cat bridge/results/NNNN-slug.md`
   The worker writes `NNNN-slug.md.tmp`, then renames it, so the file is complete when it appears.
5. **Read the result as data.**
   - Check `status:` and the `sync-check` line (commit + dirty).
   - Check the guard passed. Read exit codes and quoted lines, and open attached PNGs with Read.
   - The worker reports facts only, and you diagnose. If it says a build "did nothing", check timestamps before you believe it.
6. Fix, then queue the next number. Repeat. Tell the user the outcome in plain words, with the numbers.

## 3. Task file

```
# NNNN slug
timeout: <seconds per step>
stop-on-fail: yes|no
setup (every step; each step may be its own shell, so prefix if needed):
  cd <local project path>
  $env:<BUILD_ROOT_VAR> = '<local build root outside the synced folder>'
  NAME = <value or how to find it>     (shorthands the steps reuse)
steps:
0. Sync guard: Select-String <file> -Pattern '<newest-edit string>' -Quiet must print True. If False, wait 30 s and retry up to 5 times, then BLOCKED.
1. <exact command, through the project's own tooling>
2. ...
capture:
- <exactly what to report: exit codes, which log lines, which JSON fields, which files to attach>
notes:
- <what to skip, known failures that are not regressions, where attachments go>
END
```

Rules that came out of real failures:
- **Say what PASS means.** List known pre-existing failures under `notes`, so the worker does not stop on them.
- **Ask for narrow captures,** such as `Select-String` patterns, named JSON fields, and the first `error` line plus the last 60 lines. A whole log floods the result.
- **Private data stays local.** In results, ROM and save names are written as placeholders, for example `roms\<black-rom>.nds`.
  - Tests run on a **temporary copy** of a save, never the original.
  - Captures go only to `bridge/results/NNNN.files/`, which is git-excluded.
  - Never ask the worker to press keys that overwrite savestates.
- **Git:** the worker only reads git. The lead commits only when the user asks.
  If the user ever asks the worker to commit, the task must state the exact authorization and the exact
  `git add -- <paths>`, and verify `git diff --cached --name-only` before the commit. Never `add -A`; never force-push.
- **Windows:** the worker runs PowerShell. Write commands in pwsh, or say "translate to pwsh".
- **Tools:** if a capability is missing (screenshots, input driving, register probes), add it to the
  project's tooling on the VPS and have the worker run it. Example: a capture tool that
  drives a game session through the TUI, presses keys, probes registers and saves PNGs.

## 4. Worker side (in `templates/team.md`)

Mailbox, loop, result format (`status: PASS|FAIL|BLOCKED`, `sync-check`, per-step exit code and
last 60 lines, `captured`, `notes`), safety rules, the sync caveat, and the TUI loop that uses
`bridge\wait.ps1` (it blocks up to 4 min and prints `OPEN: <file>` or `NO TASK`). The worker never edits code,
never installs anything and never runs git writes. It reports `BLOCKED` with the exact need.

## 5. Memory

Record bridge facts for a project (paths, model, preset, quirks) in the project's memory
(its CLAUDE.md / MEMORY.md or auto-memory), so the next session can pick the loop up.
