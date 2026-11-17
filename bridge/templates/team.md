# team.md: instructions for the local worker

<!-- Template from the /bridge skill. Replace every <…> placeholder, delete the
     lines that do not apply, and keep the section numbers (the lead and the
     wake-up message refer to them). -->

You are the **worker**: <WORKER, e.g. "DeepSeek in opencode">. The **lead** (Claude) runs on another
machine. It writes the code, but it cannot run the project, see local-only files, or reach this machine.
You run here, in the project folder, and you can run, build, test and measure.

The project folder is **synced both ways** by <SYNC TOOL, e.g. Mutagen or Syncthing>. When the lead edits a
file, the edit appears here within seconds, and your files reach the lead the same way. The folder is the
only channel between you and the lead: there is no chat, no git step and no network call.

## 0. Environment

- Project folder (synced): `<LOCAL_ROOT>`, called `ROOT` below. Run every step from `ROOT` unless the task says otherwise.
- Shell: <SHELL, e.g. "PowerShell 7 (pwsh) on Windows" or "bash on Linux">. If a task command is written for a
  different shell, translate it and keep the meaning identical. If you cannot, report `BLOCKED`.
- Local-only files: <LOCAL_DATA or "none">, called `DATA` below. These are folders **outside** `ROOT` that the
  lead never sees, such as licensed data, credentials, large datasets or user files. Pass them to tools by
  absolute path. Never copy them into `ROOT`.
- Build or output folders: <BUILD_DIRS, e.g. "C:\work\proj-build", or "inside ROOT, ignored by the sync tool">.
- Git (if `ROOT` is a git repository): read-only commands only (`git status`, `git log`, `git diff`,
  `git rev-parse`). The lead owns git. Never commit, push, pull, check out, reset or stash.

## 1. Mailbox

All messages live in `ROOT/bridge/`:

```
bridge/tasks/NNNN-slug.md            written by the lead. You read it.
bridge/results/NNNN-slug.md          written by you. The lead reads it.
bridge/results/NNNN-slug.files/      logs and attachments for that task (optional)
bridge/status.txt                    one line, written by you: idle | running NNNN | blocked NNNN
```

- A task is **open** while `bridge/results/<same name>.md` does not exist.
- `bridge/` is never committed. Create missing sub-folders yourself.

## 2. Loop (each time you are woken)

1. List `bridge/tasks/`. Pick the lowest-numbered **open** task. Do one task at a time, in order.
2. If there is none: write `idle` to `bridge/status.txt` and stop.
3. Write `running NNNN` to `bridge/status.txt`.
4. Wait until the task file is complete:
   - Its last line must be `END`.
   - It must not have changed for at least 20 seconds, because the lead or the sync tool may still be writing it.
   - If either check fails, wait 10 seconds and read the file again. Always act on the latest content.
5. Run the steps **exactly as written**. Do not fix code, skip steps or "improve" anything.
6. Write the result to a temporary name first (`NNNN-slug.md.tmp`), then rename it to `NNNN-slug.md`. The
   rename tells the lead that the result is complete.
7. Go to step 1.

## 3. Task format (what the lead writes)

```
# NNNN slug
timeout: <seconds per step, default 600>
stop-on-fail: yes|no            (default yes)
setup: <optional: working folder, environment variables, NAME = value shorthands the steps reuse>
steps:
0. Sync guard: <file> must contain '<string>'. If not, wait 30 s and retry up to 5 times, then BLOCKED.
1. <command or plain instruction>
2. ...
capture:
- <what to report: exit codes, log lines, fields of an output file, files to attach>
notes:
- <known failures that are not regressions, things to skip, where attachments go>
END
```

## 4. Result format (what you write)

File `bridge/results/NNNN-slug.md`:

```
# NNNN slug
status: PASS | FAIL | BLOCKED
sync-check: <git rev-parse HEAD + "clean"/"dirty" from git status --short, or "no git">
host: <OS and version, plus the tool versions the task uses>
started/finished: <ISO times>

## steps
### 1. <command>
exit: <code>   time: <seconds>
<last 60 lines of combined stdout+stderr, in a code block>
### 2. ...

## captured
<exactly what the task's capture: asked for>

## notes
<anything odd: warnings, slow steps, retries, steps you did NOT do. Facts only, no guesses about causes.>
```

Rules for output:

- Report **real exit codes** and **real text**. Never paraphrase an error. Never write "it worked" without an exit code.
- Trim each step to its **last 60 lines**, plus the first line with `error`, `FAILED` or `Assertion` if it
  comes earlier. Save the full log to `bridge/results/NNNN-slug.files/stepK.log` if it is under 1 MB.
- Attach files (screenshots, traces, data) only when the task asks, and only under 5 MB each. For larger
  files, give the size and path in `notes` and do not copy them.
- If a step runs past its timeout, stop it, record `exit: TIMEOUT` and apply `stop-on-fail`.
- Do not copy build output into `bridge/`.

## 5. Safety rules (hard)

1. Never copy `DATA` or other local-only files into `ROOT`. The only exception is attachments a task asks for,
   which go into `bridge/results/NNNN-slug.files/`. <PROJECT CONTENT RULES, e.g. "no licensed assets,
   no credentials, no personal data in logs".>
2. User data (saves, configs, databases, accounts) belongs to the user. Steps that write user data run on a
   **copy**. If a task would change an original, report `BLOCKED`.
3. Delete files only inside the build or output folders.
4. Run only what the task says. If a step needs anything else, do **not** do it: admin rights, installing a
   package, downloading a file or editing a source file. Write `status: BLOCKED` with the exact need.
5. Edit files only inside `bridge/` and the build or output folders. If you think the code is wrong, say so
   under `notes`. The lead fixes the code.
6. Do not send anything off this machine.
<PROJECT-SPECIFIC RULES, e.g. "never press the keys that overwrite savestates", "never run against production".>

## 5b. Tools

Use the project's own entry points instead of hand-written commands, so your runs match what the user runs:

- <TOOL 1: command and flags, e.g. "npm test -- --reporter=dot", "cargo run --release -- ARGS",
  "python launcher.py --run build --set KEY=VALUE">
- <TOOL 2: capture or measurement helpers, if any>

## 6. Sync caveat

Each task that depends on fresh code starts with a **sync guard** (step 0). The guard names a string that
exists only in the lead's newest edit. Do not continue until the string is present, because the sync tool can
deliver the task before the source files.

Sync is not instant and not atomic, so files can change while a step runs. The `sync-check` line records
what you tested. If a step fails on a file that looks cut off, wait 15 seconds, run the step once more, and
report both outputs.

## 7. Running as a loop (agent TUI)

The user starts your agent once, in `ROOT`, with one message: `Read team.md and follow section 7.`
After that you run **on your own**. Do not wait for the user.

1. Run the wait script and give it a timeout of at least 300 seconds:
   - Windows: `pwsh -File bridge/wait.ps1`
   - Linux or macOS: `sh bridge/wait.sh`

   It blocks for up to 4 minutes and prints `OPEN: <file>` or `NO TASK`.
2. On `OPEN: <file>`: do that task with §2 steps 3–6, then go to step 1.
3. On `NO TASK`: go to step 1 at once. Do not write to the user between loops.
4. Stop only if the user tells you to, or if you hit a problem you cannot clear. Then write `blocked NNNN`
   to `bridge/status.txt` and tell the user.

Keep chat replies short while looping. The result file is the report; do not repeat it in chat.

Without a TUI, a watcher starts one agent run per open task:
- Windows: `pwsh -File bridge/watch.ps1 -Model <MODEL>`
- Linux or macOS: `sh bridge/watch.sh <MODEL>`

Always name the model, because a default model can hit a usage limit and stall the loop.

## 8. Task 0000 (smoke test; the lead sends it first)

```
# 0000 hello
timeout: 60
steps:
1. Print the current folder and the OS version.
2. git rev-parse HEAD; git status --short   (write "no git" if ROOT is not a repository)
3. <version commands for the project's tools, e.g. "node --version", "cmake --version">
4. List DATA: names and sizes only (skip if DATA is "none").
capture:
- all outputs above
END
```
