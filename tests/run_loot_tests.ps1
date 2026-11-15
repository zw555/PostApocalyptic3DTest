param(
    [string]$GodotPath = 'E:\Godot_v4.5.2-stable_win64.exe\Godot_v4.5.2-stable_win64_console.exe',
    [switch]$Capture
)
$ErrorActionPreference = 'Stop'
$projectPath = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$resultsPath = Join-Path $PSScriptRoot 'results'
& (Join-Path $PSScriptRoot 'run_cad_tests.ps1') -GodotPath $GodotPath
if ($LASTEXITCODE -ne 0) { throw 'Pre-existing regression failed.' }
function Invoke-Loot([string]$Name, [string[]]$EngineArguments) {
    $logPath = Join-Path $resultsPath ($Name+'.log')
    & $GodotPath --path $projectPath --log-file $logPath @EngineArguments
    if ($LASTEXITCODE -ne 0 -or (Select-String -LiteralPath $logPath -Pattern '^(ERROR:|SCRIPT ERROR:)' -Quiet)) { throw "$Name failed: $logPath" }
}
Invoke-Loot 'loot_smoke' @('--headless','--quit-after','60','res://scenes/looted_convenience_store.tscn')
Invoke-Loot 'loot_validation' @('--headless','--fixed-fps','60','--script','res://tests/validate_loot_visual.gd')
if ($Capture) {
    Invoke-Loot 'loot_capture' @('--script','res://tests/loot_capture.gd')
    Invoke-Loot 'loot_render_validation' @('--headless','--script','res://tests/verify_loot_render.gd')
}
Write-Output 'PASS: Stage 4-A regression + loot/visual transactions. Human acceptance remains pending.'
