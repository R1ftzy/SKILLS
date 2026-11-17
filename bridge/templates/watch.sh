#!/bin/sh
# Run once in a second terminal, from the project folder:
#   sh bridge/watch.sh <provider/model> [MAX_TRIES] [BACKOFF_SEC]
# Checks for open tasks (no model call) and starts one agent run per open task.
# Find model names with: opencode models. Edit AGENT to use another CLI agent.
model=${1:?usage: sh bridge/watch.sh <provider/model> [MAX_TRIES] [BACKOFF_SEC]}
max_tries=${2:-3}
backoff=${3:-60}
dir=$(cd "$(dirname "$0")" && pwd)
cd "$dir/.." || exit 1
tries_file=$(mktemp)
trap 'rm -f "$tries_file"' EXIT
echo "watching $dir/tasks with model $model (Ctrl+C to stop)"
while :; do
    next=""
    for task in $(ls "$dir/tasks" 2>/dev/null | grep '\.md$' | sort); do
        [ -e "$dir/results/$task" ] && continue
        n=$(grep -c "^$task\$" "$tries_file")
        [ "$n" -ge "$max_tries" ] && continue
        next=$task
        break
    done
    if [ -n "$next" ]; then
        echo "$next" >> "$tries_file"
        echo "$(date -Iseconds) task $next -> opencode -m $model"
        opencode run -m "$model" "Read team.md and follow section 2 (TUI: section 7)."
        if [ ! -e "$dir/results/$next" ]; then
            echo "task $next still open after run; waiting $backoff s"
            sleep "$backoff"
        fi
    else
        sleep 5
    fi
done
