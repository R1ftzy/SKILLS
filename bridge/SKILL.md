---
name: bridge
description: Lead/worker loop between Claude (the lead, on a server) and a local AI worker (for example DeepSeek in opencode on the user's PC) through a two-way synced folder. Claude writes code and task files; the worker builds, runs, tests, captures and writes result files. On first use in a project it analyses the repo, shows the user what the worker needs (programs, agent harness, model, MCP), generates team.md and the worker scripts from the user's choices, and runs a test task. Use when the user types /bridge, asks to get a local worker (e.g. deepseek) to build/run/test, or asks to set the bridge up for a project.
---

# /bridge: Claude writes, the local worker runs

Claude (the **lead**) runs on a server. It cannot run what needs the user's machine: their GPU, OS,
devices, local-only data, or a toolchain that is not installed here. A **worker** (a local agent, for
example DeepSeek in opencode) runs in the same project folder, which a sync tool (for example Mutagen)
keeps **in sync both ways**. The folder is the channel: there is no git step, no branch and no network call.

Arguments: `/bridge [project folder] [what to do]`. With no folder, use the current project.
If `bridge/` and `team.md` already exist, skip to §2. Otherwise run the onboarding in §1 first.

## 1. Onboarding (first run in a project)

### 1a. Analyse the repo (read-only, no questions yet)

Find out what the worker will have to do and what it needs. Look at:
- **Build and test entry points:** `package.json` scripts, `Cargo.toml`, `pyproject.toml`, `go.mod`,
  `CMakeLists.txt`/`CMakePresets.json`, `Makefile`, `*.sln`, Gradle files, launcher scripts, TUIs.
  Prefer the project's own launchers over raw commands.
- **CI workflows** (`.github/workflows/*`, other CI files): they show exact commands, OS and toolchain versions.
- **Docs:** `README`, `BUILDING`, `CONTRIBUTING`, `AGENTS.md`, `CLAUDE.md` (rules about data and commits).
- **The worker's OS:** `.ps1` vs `.sh` scripts, Windows-only APIs, presets named `windows-*`.
- **Local-only data:** `.gitignore` entries such as `data/`, `roms/`, `*.sav`, `.env`, `models/`, and anything
  the docs say must not be committed or shared.
- **Hardware and runtime needs:** GPU (Vulkan, CUDA, Metal), display or window, audio, devices, browsers.
- **What the server can already do:** try the toolchain here. Then only the remaining steps go to the worker.
- **Visual checks:** for a web UI, a desktop app or a game, find out how the worker can capture
  screenshots (the project's own tool, a test framework, or an MCP server).

### 1b. Show the bridge plan

Show a short plan before you ask anything. Use these headings:

```
Bridge plan for <project>
What the worker will do:  <build / test / run / capture / measure: the concrete commands>
Worker machine:           <OS>, needs: <programs + versions, from CI/docs>, hardware: <GPU, ...>
Local-only data:          <folders that stay on the worker machine, or "none">
Sync:                     <tool>, synced folder <path>, ignore: <build/output folders, caches>
Agent harness:            <recommended> (alternatives: ...), see reference/harnesses.md
Model:                    <suggestion; the user decides>
MCP on the worker:        <needed / optional / none, and why>
Permissions:              <what the agent must be allowed to run without asking>
```

Pick the harness and MCP from `reference/harnesses.md`. Say "none needed" when the shell is enough.
Most projects need no MCP, because the worker only runs commands and reads and writes files.

### 1c. Ask for the choices

Ask with AskUserQuestion. Put the recommended option first. Ask only what the analysis did not answer:
- the agent harness (opencode, Claude Code, Codex CLI, Gemini CLI, Antigravity, other);
- the model (free text is fine, for example `opencode-go/deepseek-v4.1-flash`);
- TUI loop or headless watcher;
- the worker OS, if it is still unclear.

Then ask in plain text for the paths: the synced project folder on the worker machine, local-only data folders,
and a build folder outside the synced folder.

### 1d. Generate the files

1. Create `bridge/tasks/` and `bridge/results/`. Add `bridge/` to `.git/info/exclude`.
2. Write `team.md` from `templates/team.md`:
   - Fill every `<…>` and delete lines that do not apply.
   - §5b lists the real project commands from 1a.
   - §5 holds the project's data rules.
   - Check that no `<` placeholder is left.
   - Add `team.md` to `.gitignore` only if the user wants that.
3. Copy the wait script for the worker OS: `templates/wait.ps1` or `templates/wait.sh`.
4. Headless watcher only: copy `templates/watch.ps1` or `templates/watch.sh`, and replace the
   `__AGENT_COMMAND__` line with the chosen harness's one-shot command from `reference/harnesses.md`.
   The command must pass the model and the prompt variable.
5. **Hard rule: build folders stay outside the synced folder.**
   - The sync tool races the lock and temp files that git, compilers and package managers write. CMake
     FetchContent clones, for example, fail with "Permission denied" in a synced folder.
   - Build trees are also large, and the sync would copy them to the server.
   - Use the project's build-root option. If it has none, add one (an env var or a launcher setting)
     **before** the first build task.
   - Every task's `setup:` sets it. In the plan, list the build folder on the worker and the sync-tool ignores
     (`build/`, `node_modules/`, `target/`, `.venv/`, `dist/` ...) as a safety net.

### 1e. Tell the user the steps

Give numbered steps, adapted to the user's choices:
1. Install the programs from the plan, with the toolchain versions CI uses.
2. Set up the sync and ignore the build folders. Mutagen example:
   `mutagen sync create --name=<project> <local folder> <server>:<path> --ignore=build --ignore=node_modules`.
   Skip this step if the folder is already synced.
3. Set up the harness:
   - Choose the model.
   - Allow shell commands without prompts, inside the project folder only (reference/harnesses.md has a section per harness).
   - Add any MCP server from the plan.
4. Start the worker:
   - **TUI:** open the agent in the project folder and send `Read team.md and follow section 7.`
   - **Headless:** run the watch script with the model.
5. Claude sends the test task (0000). After it passes, the bridge is ready.

### 1f. Test run, then start

- Write `bridge/tasks/0000-hello.md` (the template is in `team.md` §8) and wait for it as in §2.
- On PASS: confirm the host line, tool versions and data paths, then record the bridge facts (§5).
- On BLOCKED or FAIL: tell the user exactly what is missing. Fix the plan or `team.md`, and send `0001`.
- Then start on the user's request.

## 2. The loop (every task)

1. **Code first.** Make the source edits on the server. Check everything you can here, for example
   syntax-only compiles, unit tests, shader compiles and dry runs. Only the run itself needs the worker.
2. **Write the task.**
   - Path: `bridge/tasks/NNNN-slug.md`. NNNN is 4 digits: the highest number in `tasks/` or `results/` plus 1.
   - Format: see §3.
   - **Step 0 is always a sync guard:** a string that only exists in your newest edit. The worker
     waits (30 s × 5) until the file contains it, because the sync tool can deliver the task before the source.
   - The last line is `END`. The worker also waits until the file is 20 s old. Write the task in one Write call.
3. **Never edit a task the worker may have picked up** (`bridge/status.txt` says `running NNNN`).
   The worker can read it half-synced. Queue a new number instead.
4. **Wait without polling.** Run one background Bash command and continue other work. You are notified when it ends:
   `until [ -f bridge/results/NNNN-slug.md ]; do sleep 10; done; sleep 3; cat bridge/results/NNNN-slug.md`
   The worker writes `NNNN-slug.md.tmp` and then renames it, so the file is complete when it appears.
5. **Read the result as data.**
   - Check `status:` and the `sync-check` line (commit and dirty state).
   - Check that the guard passed. Read the exit codes and quoted lines, and open attached images with Read.
   - The worker reports facts only, and you diagnose. If it says a build "did nothing", check timestamps before you believe it.
6. Fix, then queue the next number. Repeat. Tell the user the outcome in plain words, with the numbers.

## 3. Task file

```
# NNNN slug
timeout: <seconds per step>
stop-on-fail: yes|no
setup (every step; each step may be its own shell, so prefix if needed):
  cd <worker project path>
  <env vars the steps need, e.g. a build-root variable pointing outside the synced folder>
  NAME = <value or how to find it>     (shorthands the steps reuse)
steps:
0. Sync guard: <file> must contain '<newest-edit string>' (pwsh: Select-String -Quiet; sh: grep -q). If not, wait 30 s and retry up to 5 times, then BLOCKED.
1. <exact command, through the project's own tooling>
2. ...
capture:
- <exactly what to report: exit codes, which log lines, which JSON fields, which files to attach>
notes:
- <what to skip, known failures that are not regressions, where attachments go>
END
```

Rules that came out of real failures:
- **Say what PASS means.** List known failures that already existed under `notes`, so the worker does not stop on them.
- **Ask for narrow captures,** such as search patterns (`Select-String` / `grep`), named JSON fields, and the
  first `error` line plus the last 60 lines. A whole log floods the result.
- **Private data stays local.** Ask the worker to write sensitive file names as placeholders in results
  (for example `data/<private-file>`).
  - Steps that write user data (saves, configs, databases) run on a **temporary copy**, never the original.
  - Attachments go only to `bridge/results/NNNN.files/`, which is git-excluded.
  - Never ask for actions that destroy user state (overwriting saves, wiping caches, hitting production).
- **Git:** the worker only reads git. The lead commits only when the user asks. If the user asks the worker
  to commit:
  - The task states the exact authorization and the exact `git add -- <paths>`.
  - The worker checks `git diff --cached --name-only` before the commit.
  - Never `add -A`. Never force-push.
- **Shell:** write commands in the worker's shell (PowerShell on Windows), or tell the worker to translate.
- **Tools:** if a capability is missing (screenshots, input driving, probes), add it to the project's
  tooling on the server and have the worker run it. The worker never writes code.

## 4. Worker side (`templates/team.md`)

The worker side has the mailbox, the loop, and the result format: `status: PASS|FAIL|BLOCKED`, `sync-check`,
each step's exit code and last 60 lines, `captured` and `notes`. It also has the safety rules, the sync caveat,
and the TUI loop that uses the wait script (it blocks for up to 4 min and prints `OPEN: <file>` or `NO TASK`).
The worker never edits code, never installs anything and never runs git writes. It reports `BLOCKED` with the exact need.

## 5. Memory

Record the bridge facts for a project in the project's memory (its CLAUDE.md, MEMORY.md or auto-memory), so
the next session can pick the loop up. Include the paths, harness, model, build folder and quirks.
