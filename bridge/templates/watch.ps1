# Run once in a second terminal, from the project folder:
#   pwsh -File bridge\watch.ps1 -Model <provider/model>
# Find the exact name with:  opencode models
# Checks for open tasks (no model call). Starts opencode only when one exists.
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
Write-Host "watching $tasks with model $Model (Ctrl+C to stop)"
while ($true) {
    $open = Get-ChildItem $tasks -Filter '*.md' -ErrorAction SilentlyContinue |
        Where-Object { -not (Test-Path (Join-Path $results $_.Name)) -and ($tries[$_.Name] -lt $MaxTries) } |
        Sort-Object Name
    if ($open) {
        $t = $open[0].Name
        $tries[$t] = 1 + [int]$tries[$t]
        Write-Host "$(Get-Date -Format s) task $t (run $($tries[$t])/$MaxTries) -> opencode -m $Model"
        opencode run -m $Model "Read team.md and follow section 2 (TUI: section 7)."
        if (-not (Test-Path (Join-Path $results $t))) {
            Write-Host "task $t still open after run; waiting $BackoffSec s"
            Start-Sleep $BackoffSec
        }
    } else {
        Start-Sleep 5
    }
}
