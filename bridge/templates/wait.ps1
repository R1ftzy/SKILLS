# Blocks until an open task exists, then prints its name and exits 0.
# Exits 1 after -TimeoutSec with no task (run it again). No model call.
param([int]$TimeoutSec = 240)
$tasks   = Join-Path $PSScriptRoot 'tasks'
$results = Join-Path $PSScriptRoot 'results'
$end = (Get-Date).AddSeconds($TimeoutSec)
while ((Get-Date) -lt $end) {
    $open = Get-ChildItem $tasks -Filter '*.md' -ErrorAction SilentlyContinue |
        Where-Object { -not (Test-Path (Join-Path $results $_.Name)) } | Sort-Object Name
    if ($open) { Write-Output "OPEN: $($open[0].Name)"; exit 0 }
    Start-Sleep 3
}
Write-Output "NO TASK"; exit 1
