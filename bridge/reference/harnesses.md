# Worker harnesses, permissions and MCP

The worker needs three things: a shell, file read and write, and a model that follows `team.md`. Any
agent harness with those works. CLI flags change between versions, so check them with `<cli> --help`
and correct this file if one is wrong.

## Choosing

| Harness | Loop mode | Headless one-shot (for the watch script) | Good for |
|---|---|---|---|
| **opencode** | TUI | `opencode run -m <provider/model> "<prompt>"` | Any provider, including cheap models such as DeepSeek. The default choice. |
| **Claude Code** | TUI | `claude -p "<prompt>" --model <model>` | Strong instruction following. Costs the same as the lead. |
| **Codex CLI** | TUI | `codex exec -m <model> "<prompt>"` | OpenAI models. |
| **Gemini CLI** | TUI | `gemini -m <model> -p "<prompt>"` | Google models with a large context. |
| **Antigravity** (agent IDE) | Agent panel only | none: use the TUI-style loop in the IDE | Users who already work in it. There is no watch script. |
| Aider | not a good fit | n/a | Aider is built for editing code, not for an unattended command loop. |

Recommendation: **opencode + a cheap, fast model** for build/run/report work. The worker only runs steps and
reports facts, so it does not need the strongest model. Always name the model explicitly, because a default
model can hit a usage limit and stall the loop.

**Loop mode vs headless:**
- **TUI loop (recommended):** the user opens the agent once and sends `Read team.md and follow section 7.`
  The agent then loops on the wait script. Start-up costs nothing, and you can watch it work.
- **Headless watcher:** `watch.ps1` / `watch.sh` start one agent run per open task. Use it when no window
  may stay open. Each run reads `team.md` again.

## Watch-script command line

Replace the `__AGENT_COMMAND__` line in the watch template with the harness's command. The variables are
`$Model` / `$Prompt` in PowerShell and `"$model"` / `"$prompt"` in sh.

| Harness | PowerShell (`watch.ps1`) | sh (`watch.sh`) |
|---|---|---|
| opencode | `opencode run -m $Model $Prompt` | `opencode run -m "$model" "$prompt"` |
| Claude Code | `claude -p $Prompt --model $Model` | `claude -p "$prompt" --model "$model"` |
| Codex CLI | `codex exec -m $Model $Prompt` | `codex exec -m "$model" "$prompt"` |
| Gemini CLI | `gemini -m $Model -p $Prompt` | `gemini -m "$model" -p "$prompt"` |

## Permissions (unattended runs)

The worker must run shell commands without asking each time, because nobody is watching. Allow this
**inside the project folder only**. The real limits are the rules in `team.md` §5, which the worker follows.
- **opencode:** allow `bash` and `edit` in the project's `opencode.json` (the `permission` section).
  Keep `webfetch` off unless a task needs it.
- **Claude Code:** an allow list in `.claude/settings.local.json` on the worker (`permissions.allow`, for
  example `Bash(*)`, `Read`, `Write`, `Edit`), or `--allowedTools` on the headless command.
  Avoid `--dangerously-skip-permissions`.
- **Codex CLI:** a sandbox mode that allows commands and writes in the workspace (see `codex --help`,
  for example the `--full-auto` preset). Do not turn the sandbox off completely.
- **Gemini CLI:** approve shell commands for the session, or use its auto-approve option only in a folder
  you are happy to let it run in.
- **Antigravity:** set terminal command execution to auto in the agent settings, and keep its deny list
  for destructive commands.

## MCP on the worker

Most bridges need **no MCP**: the worker runs the project's commands and writes files. Suggest one only
when the analysis shows a need that the project's own tooling cannot meet:

| Need found in the repo | Suggest |
|---|---|
| Web UI to check visually (React/Vue/Svelte app, browser extension, site) | **Playwright MCP**: the worker opens the page, clicks and saves screenshots. Or a Playwright test script in the repo, which is often better because the lead can change it. |
| Desktop app or game window | No MCP. Prefer a capture hook in the project (an env var that dumps frames) driven by a script, as in the example below. A screenshot MCP is the fallback. |
| Local database the worker must inspect | Usually no MCP: give the worker `psql` / `sqlite3` commands in `team.md` §5b. |
| Local hardware (serial, USB, GPU counters) | No MCP: give the vendor CLI in §5b (for example `nvidia-smi`). |

If you add an MCP server, name it in `team.md` §5b and in the plan. The user installs it in the
harness config.

## Example: a C++/Vulkan game port on Windows

- Plan: the worker builds through the project's TUI launcher (`launcher.py --run build`).
  It plays through `--run play` and captures frames with a script that drives the game over a debug socket
  and saves PNGs. Licensed game data stays in a local folder outside the synced folder.
- Harness: opencode with `opencode-go/deepseek-v4.1-flash`, in the TUI loop. No MCP.
- Build folder outside the synced folder, set by a build-root env var: a synced build folder broke
  CMake's git clones.
