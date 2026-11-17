# Run once in a second terminal, from the project folder:
#   pwsh -File bridge\watch.ps1 -Model <model>
# Checks for open tasks (no model call) and starts one agent run per open task.
# Template: /bridge replaces the __AGENT_COMMAND__ line with the chosen harness
# (see reference/harnesses.md), e.g.  opencode run -m $Model $Prompt
param(
    [Parameter(Mandatory)][string]$Model,
    [int]$MaxTries = 3,       # give up on a task after this many runs that left it open
    [int]$BackoffSec = 60     # wait after a run that left the task open
)
$root    = Split-Path -Parent $PSScriptRoot
$tasks   = Join-Path $PSScriptRoot 'tasks'
$results = Join-Path $PSScriptRoot 'results'
Set-Location $root
$tries = @{}
$Prompt = 'Read team.md and follow section 2 (TUI: section 7).'
Write-Host "watching $tasks with model $Model (Ctrl+C to stop)"
while ($true) {
    $open = Get-ChildItem $tasks -Filter '*.md' -ErrorAction SilentlyContinue |
        Where-Object { -not (Test-Path (Join-Path $results $_.Name)) -and ($tries[$_.Name] -lt $MaxTries) } |
        Sort-Object Name
    if ($open) {
        $t = $open[0].Name
        $tries[$t] = 1 + [int]$tries[$t]
        Write-Host "$(Get-Date -Format s) task $t (run $($tries[$t])/$MaxTries) with model $Model"
        __AGENT_COMMAND__
        if (-not (Test-Path (Join-Path $results $t))) {
            Write-Host "task $t still open after run; waiting $BackoffSec s"
            Start-Sleep $BackoffSec
        }
    } else {
        Start-Sleep 5
    }
}
