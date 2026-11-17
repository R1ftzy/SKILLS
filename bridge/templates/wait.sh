#!/bin/sh
# Blocks until an open task exists, then prints its name and exits 0.
# Exits 1 after TIMEOUT seconds (default 240) with no task; run it again.
# No model call. Usage: sh bridge/wait.sh [TIMEOUT]
dir=$(cd "$(dirname "$0")" && pwd)
end=$(( $(date +%s) + ${1:-240} ))
while [ "$(date +%s)" -lt "$end" ]; do
    for task in $(ls "$dir/tasks" 2>/dev/null | grep '\.md$' | sort); do
        if [ ! -e "$dir/results/$task" ]; then
            echo "OPEN: $task"
            exit 0
        fi
    done
    sleep 3
done
echo "NO TASK"
exit 1
